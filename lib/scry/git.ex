defmodule Scry.Git do
  @moduledoc false

  defp root, do: Application.fetch_env!(:scry, :root)

  def commit_all(message) do
    with {_, 0} <- git(["add", "."]),
         {_, 0} <- git(["commit", "-m", message]) do
      :ok
    else
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commit_file(message, file) do
    case git(["commit", "-m", message, "--", file]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def reset_hard(sha) do
    case git(["reset", "--hard", sha]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def head_ref do
    case git(["symbolic-ref", "HEAD"]) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def update_ref(ref, sha) do
    case git(["update-ref", ref, sha]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commits_since(nil) do
    case git(["log", "--reverse", "--format=%H", "HEAD"]) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commits_since(boundary) do
    case git(["log", "--reverse", "--format=%H", "#{boundary}..HEAD"]) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def changed_files(sha) do
    case git(["diff-tree", "--root", "--no-commit-id", "--name-status", "-r", sha]) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            [status, file] = String.split(line, "\t", parts: 2)
            {status, file}
          end)

        {:ok, files}

      {output, _} ->
        {:error, String.trim(output)}
    end
  end

  def tree_entry(sha, file) do
    case git(["ls-tree", sha, "--", file]) do
      {"", 0} ->
        {:ok, nil}

      {output, 0} ->
        [meta, _file] = String.split(String.trim(output), "\t", parts: 2)
        [mode, _type, blob] = String.split(meta, " ")
        {:ok, %{mode: mode, blob: blob}}

      {output, _} ->
        {:error, String.trim(output)}
    end
  end

  def hash_blob(content) do
    path = Path.join(System.tmp_dir!(), "scry-blob-#{:erlang.unique_integer([:positive])}")
    File.write!(path, content)

    try do
      case git(["hash-object", "-w", path]) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, _} -> {:error, String.trim(output)}
      end
    after
      File.rm(path)
    end
  end

  def commit_tree(tree, parent, subject) do
    args = ["commit-tree", tree, "-m", subject] ++ if(parent, do: ["-p", parent], else: [])

    case git(args) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def with_index(callback) do
    path = Path.join(System.tmp_dir!(), "scry-index-#{:erlang.unique_integer([:positive])}")

    try do
      callback.(path)
    after
      File.rm(path)
    end
  end

  def index_read_tree(index, nil) do
    case git(["read-tree", "--empty"], env: [{"GIT_INDEX_FILE", index}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_read_tree(index, sha) do
    case git(["read-tree", sha], env: [{"GIT_INDEX_FILE", index}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_add(index, file, blob, mode) do
    case git(["update-index", "--add", "--cacheinfo", "#{mode},#{blob},#{file}"], env: [{"GIT_INDEX_FILE", index}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_remove(index, file) do
    case git(["update-index", "--remove", "--", file], env: [{"GIT_INDEX_FILE", index}]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_write_tree(index) do
    case git(["write-tree"], env: [{"GIT_INDEX_FILE", index}]) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def find_last_commit(pattern, file) do
    case git(["log", "--grep=#{pattern}", "--format=%H", "-n1", "--", file]) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def rev_parse(ref) do
    case git(["rev-parse", ref]) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def log_subjects(file) do
    case git(["log", "--format=%s", "--", file]) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def log_entries(file) do
    if has_head?() do
      case git(["log", "--format=%H%x00%ct%x00%s", "--", file]) do
        {output, 0} ->
          entries =
            output
            |> String.split("\n", trim: true)
            |> Enum.map(&parse_entry/1)

          {:ok, entries}

        {output, _} ->
          {:error, String.trim(output)}
      end
    else
      {:ok, []}
    end
  end

  defp has_head? do
    case git(["rev-parse", "--verify", "--quiet", "HEAD"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  def show_info(sha) do
    case git(["show", "--no-patch", "--format=%H%x00%ct%x00%s", sha]) do
      {output, 0} -> {:ok, output |> String.trim() |> parse_entry()}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def show_diff(sha) do
    case git(["show", "--format=", sha]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def show_file(sha, file) do
    case git(["show", "#{sha}:#{file}"]) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def list_files do
    case git(["ls-files"]) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def last_modified(file) do
    case git(["log", "-1", "--format=%ct", "--", file]) do
      {output, 0} -> {:ok, String.to_integer(String.trim(output))}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def remove_file(file) do
    case git(["rm", "--", file]) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def find_initial_commit do
    case git(["rev-list", "--max-parents=0", "HEAD"]) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  # Helpers

  @silence_stderr Mix.env() == :test

  defp git(args, opts \\ []) do
    System.cmd("git", args, Keyword.merge([cd: root(), stderr_to_stdout: @silence_stderr], opts))
  end

  defp parse_entry(line) do
    [sha, ts, subject] = String.split(line, "\x00", parts: 3)
    %{sha: sha, timestamp: String.to_integer(ts), subject: subject}
  end
end
