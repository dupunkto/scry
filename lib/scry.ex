defmodule Scry do
  @moduledoc """
  Scry is the version control system used in many {du}punkto projects,
  most notably being the primary version control system used in
  [Vik](https://docs.dupunkto.org/vik) (which is not a {du}punkto project, oops).

  ## Architecture

  Scry is a thin wrapper around `git`, but uses different concepts:

  - An **object**, which is a file that is versioned.
  - An **edit**, which is a change to an object.
  - A **revision**, which is combines multiple edits into a single change record.

  Changes to objects are tracked by calling `track/2` with the current state
  of the object. If this state is different from the previous state known by
  Scry, a new edit will be created.

  Changes are tracked in a single monolithic git repository, where each Scry object
  is represented as a file in the root folder. Every edit or revision in Scry is
  analogous to one commit in git. Each git commit thus only modifies a single file.

  Scry is designed to 'fire-and-forget'. An example use-case would be a text editor
  that sends its contents over the wirte on every save, or on a debounce. This naturally
  results in many small edits to an object, which are internally represented as commits
  titled `(edit) object` (incremental commits). At the end of an edit session, `merge/2`
  can be called to merge all pending edits into a revision, which is internally
  represented by squashing the relevant commits into a single commit titled
  `(revision) object <message>` (squashed commits).
  
  ## Deployment

  Configure the following environment variables:

      - `ROOT`: a path to a writable bare repo that has already been created.
      - `TOKEN`: the token to be passed as `Authorization` header for API calls,
      or as path segment in webhook requests.

  A prebuilt docker image is available at
  [ghcr.io/dupunkto/scry](https://github.com/dupunkto/scry/pkgs/container/scry).
  """

  alias Scry.Git

  defp root, do: Application.fetch_env!(:scry, :root)

  @doc """
  Track a new change to `object` with content `source`.

  The diff between the current state and new state is automatically
  calculated. If the files differ, a new edit will be created.
  """
  @spec track(Path.t(), binary()) :: {:ok, :edited | :unchanged} | {:error, term()}
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

  @doc """
  Merge pending edits to `object` into a single revision.

  Finds the last revision to touch `object`, and merges all edits
  after into a single revision with description `message`.

  ## Example

  Suppose the following history with three objects
  (`hello.ex`, `other.ex`, and `world.ex`):

      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) hello.ex
      (edit) world.ex
      (edit) other.ex
      (edit) world.ex

  Calling `merge("world.ex", "Minor changes")` would produce the
  following history:

      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) hello.ex
      (edit) other.ex
      (revision) <world.ex> Minor changes

  Calling `merge("hello.ex", "Major changes")`, instead, would produce:

      (edit) other.ex
      (revision) <world.ex> Initial version of world editor.
      (edit) other.ex
      (edit) world.ex
      (edit) other.ex
      (edit) world.ex
      (revision) <hello.ex> Major changes.

  """
  @spec merge(Path.t(), String.t()) :: {:ok, :merged} | {:error, term()}
  def merge(object, message) when is_binary(object) and is_binary(message) do
    with :ok <- validate_path(object),
         {:ok, target} <- resolve_merge_target(object),
         :ok <- Git.reset_soft(target, object),
         :ok <- Git.commit_file("(revision) <#{object}> #{message}", object) do
      {:ok, :merged}
    end
  end
    end
  end

  defp resolve_merge_target(object) do
    case Git.find_last_commit("revision", object) do
      {:ok, ""} ->
        with {:ok, initial} <- Git.find_initial_commit(), do: {:ok, "#{initial}^"}

      {:ok, sha} ->
        Git.rev_parse("#{sha}^")

      err ->
        err
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
end
