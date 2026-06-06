defmodule Scry do
  @readme Path.expand("../README.md", __DIR__)
  @external_resource @readme
  @moduledoc @readme
             |> File.read!()
             |> String.split("<!-- DOCS HERE -->")
             |> List.last()
             |> String.trim()

  alias Scry.Git

  defp root, do: Application.fetch_env!(:scry, :root)

  import Structo

  @typedoc """
  Slug uniquely identifying a tracked file.
  """
  @type object :: String.t()

  @doc """
  Track a new change to `object` with content `source`.
  
  Calculates the diff between the current state and new source. If
  states differ, a new edit will be created.
  """
  @doc group: "Version control"
  @spec track(object(), binary()) :: {:ok, :edited | :unchanged} | {:error, term()}
  def track(object, source) when is_binary(object) and is_binary(source) do
    with :ok <- validate_path(object),
         path = Path.join(root(), object),
         :ok <- validate_changed(path, source),
         :ok <- File.write(path, source),
         :ok <- Git.commit_all("(edit) #{object}") do
      {:ok, :edited}
    else
      {:error, :unchanged} -> {:ok, :unchanged}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_path(object) do
    cond do
      String.contains?(object, "..") -> {:error, :illegal}
      String.contains?(object, "'") -> {:error, :illegal}
      true -> :ok
    end
  end

  defp validate_changed(path, patch) do
    if File.exists?(path) do
      with {:ok, contents} <- File.read(path) do
        if String.trim(contents) == String.trim(patch) do
          {:error, :unchanged}
        else
          :ok
        end
      end
    else
      :ok
    end
  end

  @doc """
  Squash pending edits to `object` into a single revision.

  Finds the last revision to touch `object`, and squashes all edits
  after that into a single revision with description `message`.

  ## Example

  Suppose the following git history with three objects
  (`hello.ex`, `other.ex`, and `world.ex`):

      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) hello.ex
      (edit) world.ex
      (edit) other.ex
      (edit) world.ex

  Calling `squash("world.ex", "Minor changes")` would produce the
  following history:

      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Minor changes

  Calling `squash("hello.ex", "Major changes")`, instead, would produce:

      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) world.ex
      (edit) other.ex
      (edit) world.ex
      (revision) <hello.ex> Major changes.

  """
  @doc group: "Version control"
  @spec squash(object(), String.t()) :: {:ok, :squashed} | {:error, term()}
  def squash(object, message) when is_binary(object) and is_binary(message) do
    with :ok <- validate_path(object),
         {:ok, saved} <- File.read(Path.join(root(), object)),
         {:ok, boundary} <- find_boundary(object),
         {:ok, head_ref} <- Git.head_ref(),
         {:ok, revision} <- rewrite(object, message, saved, boundary),
         :ok <- Git.update_ref(head_ref, revision),
         :ok <- Git.reset_hard(revision) do
      {:ok, :squashed}
    end
  end

  defp find_boundary(object) do
    case Git.find_last_commit("revision", object) do
      {:ok, ""} -> {:ok, nil}
      {:ok, sha} -> {:ok, sha}
      err -> err
    end
  end

  defp rewrite(object, message, saved, boundary) do
    Git.with_index(fn index ->
      with :ok <- Git.index_read_tree(index, boundary),
           {:ok, commits} <- Git.commits_since(boundary),
           {:ok, head} <- replay(index, commits, object, boundary),
           {:ok, blob} <- Git.hash_blob(saved),
           :ok <- Git.index_add(index, object, blob, "100644"),
           {:ok, tree} <- Git.index_write_tree(index) do
        Git.commit_tree(tree, head, "(revision) <#{object}> #{message}")
      end
    end)
  end

  defp replay(index, commits, object, boundary) do
    Enum.reduce_while(commits, {:ok, boundary}, fn sha, {:ok, parent} ->
      case copy_commit(index, sha, object, parent) do
        {:ok, new_head} -> {:cont, {:ok, new_head}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp copy_commit(index, sha, object, parent) do
    with {:ok, files} <- Git.changed_files(sha) do
      if Enum.any?(files, fn {_status, f} -> f == object end) do
        {:ok, parent}
      else
        with :ok <- apply_to_index(index, sha, files),
             {:ok, tree} <- Git.index_write_tree(index),
             {:ok, info} <- Git.show_info(sha) do
          Git.commit_tree(tree, parent, info.subject)
        end
      end
    end
  end

  defp apply_to_index(index, sha, files) do
    Enum.reduce_while(files, :ok, fn entry, _acc ->
      case apply_entry(index, sha, entry) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp apply_entry(index, _sha, {"D", file}), do: Git.index_remove(index, file)

  defp apply_entry(index, sha, {_status, file}) do
    with {:ok, %{mode: mode, blob: blob}} <- Git.tree_entry(sha, file) do
      Git.index_add(index, file, blob, mode)
    end
  end

  @doc """
  Delete tracking history for `object`.

  The object is removed from listings and `source/1` and `history/1` will
  return errors, as if the object has never existed. When tracked again using
  `track/2`, older history will not resurface.

  > #### However: {: .neutral}
  >
  > Internally, prior history of the file is preserved and a commit
  > titled '(delete) object' is created. Therefore, this function is unfit
  > for deleting sensitive information. Consider manually editing git
  > history instead.
  """
  @doc group: "Version control"
  @spec delete(object()) :: {:ok, :deleted} | {:error, term()}
  def delete(object) when is_binary(object) do
    with :ok <- validate_path(object),
         :ok <- Git.remove_file(object),
         :ok <- Git.commit_file("(delete) #{object}", object) do
      {:ok, :deleted}
    end
  end

  @doc """
  Return a listing of all tracked objects.
  """
  @doc group: "Querying"
  @spec list() :: {:ok, [object()]} | {:error, term()}
  def list do
    Git.list_files()
  end

  @doc """
  Return the current source for `object`.
  """
  @doc group: "Querying"
  @spec source(object()) :: {:ok, binary()} | {:error, term()}
  def source(object) when is_binary(object) do
    with :ok <- validate_path(object) do
      File.read(Path.join(root(), object))
    end
  end

  @typedoc """
  A map representing the revision history for an object.

  Has two keys:

    - `:revisions`: all revisions to `object` in reverse chronological order,
      each as `%{sha, timestamp, message, diff}` (see `t:revision/0`).

    - `:pending`: the number of edits made since the last revision (i.e.
      pending changes that have not been squashed into a revision yet).

  """
  @type history :: %{revisions: [revision()], pending: non_neg_integer()}

  @typedoc """
  A map representing a single revision for an object.
  """
  @type revision :: %{
          required(:sha) => String.t(),
          required(:timestamp) => integer(),
          required(:message) => String.t(),
          optional(:diff) => String.t(),
          optional(:source) => String.t()
        }

  @doc """
  Return the revision history for `object`.

  See `t:history/0` for the return type.
  """
  @doc group: "Querying"
  @spec history(object()) :: {:ok, history()} | {:error, term()}
  def history(object) when is_binary(object) do
    with :ok <- validate_path(object),
         {:ok, entries} <- Git.log_entries(object) do
      entries = Enum.take_while(entries, &(not delete?(&1, object)))

      revisions =
        entries
        |> Enum.filter(&revision?/1)
        |> Enum.map(fn entry ->
          %{sha:
            entry.sha,
            timestamp: entry.timestamp,
            message: extract_message(entry.subject)
          }
        end)

      {:ok, ~m{revisions, pending: count_pending(entries)}}
    end
  end

  defp count_pending(entries) do
    Enum.reduce_while(entries, 0, fn entry, acc ->
      cond do
        revision?(entry) -> {:halt, acc}
        edit?(entry) -> {:cont, acc + 1}
        true -> {:cont, acc}
      end
    end)
  end

  defp edit?(~m{subject}), do: String.starts_with?(subject, "(edit) ")
  defp revision?(~m{subject}), do: String.starts_with?(subject, "(revision) ")
  defp delete?(~m{subject}, object), do: subject == "(delete) #{object}"

  defp extract_message(subject) do
    subject |> String.split(" ", parts: 3) |> Enum.at(2, "")
  end

  @typedoc """
  Hash uniquely identifying a single edit or revision.
  """
  @type sha :: String.t()

  @doc """
  Return the revision details identified by `sha`,
  including the diff and source code.
  """
  @doc group: "Querying"
  @spec revision(sha()) :: {:ok, revision()} | {:error, term()}
  def revision(sha) when is_binary(sha) do
    with {:ok, info} <- Git.show_info(sha),
         {:ok, diff} <- Git.show_diff(sha),
         {:ok, [{_status, file} | _]} <- Git.changed_files(sha),
         {:ok, source} <- Git.show_file(sha, file) do
      {:ok,
       %{
         sha: info.sha,
         timestamp: info.timestamp,
         message: extract_message(info.subject),
         diff: diff,
         source: source
       }}
    end
  end
end
