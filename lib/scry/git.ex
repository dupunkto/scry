defmodule Scry.Git do
  @moduledoc false

  defp root, do: Application.fetch_env!(:scry, :root)

  def commit_all(message) do
    repo = root()

    with {_, 0} <- System.cmd("git", ["add", "."], cd: repo),
         {_, 0} <- System.cmd("git", ["commit", "-m", message], cd: repo) do
      :ok
    else
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commit_file(message, file) do
    case System.cmd("git", ["commit", "-m", message, "--", file], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def reset_hard(sha) do
    case System.cmd("git", ["reset", "--hard", sha], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def head_ref do
    case System.cmd("git", ["symbolic-ref", "HEAD"], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def update_ref(ref, sha) do
    case System.cmd("git", ["update-ref", ref, sha], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commits_since(nil) do
    case System.cmd("git", ["log", "--reverse", "--format=%H", "HEAD"], cd: root()) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def commits_since(boundary) do
    case System.cmd("git", ["log", "--reverse", "--format=%H", "#{boundary}..HEAD"], cd: root()) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def changed_files(sha) do
    case System.cmd("git", ["diff-tree", "--root", "--no-commit-id", "--name-status", "-r", sha], cd: root()) do
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
    case System.cmd("git", ["ls-tree", sha, "--", file], cd: root()) do
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
      case System.cmd("git", ["hash-object", "-w", path], cd: root()) do
        {output, 0} -> {:ok, String.trim(output)}
        {output, _} -> {:error, String.trim(output)}
      end
    after
      File.rm(path)
    end
  end

  def commit_tree(tree, parent, subject) do
    args = ["commit-tree", tree, "-m", subject] ++ if(parent, do: ["-p", parent], else: [])

    case System.cmd("git", args, cd: root()) do
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
    case System.cmd("git", ["read-tree", "--empty"], env: [{"GIT_INDEX_FILE", index}], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_read_tree(index, sha) do
    case System.cmd("git", ["read-tree", sha], env: [{"GIT_INDEX_FILE", index}], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_add(index, file, blob, mode) do
    args = ["update-index", "--add", "--cacheinfo", "#{mode},#{blob},#{file}"]

    case System.cmd("git", args, env: [{"GIT_INDEX_FILE", index}], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_remove(index, file) do
    args = ["update-index", "--remove", "--", file]

    case System.cmd("git", args, env: [{"GIT_INDEX_FILE", index}], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def index_write_tree(index) do
    case System.cmd("git", ["write-tree"], env: [{"GIT_INDEX_FILE", index}], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def find_last_commit(pattern, file) do
    case System.cmd("git", ["log", "--grep=#{pattern}", "--format=%H", "-n1", "--", file], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def rev_parse(ref) do
    case System.cmd("git", ["rev-parse", ref], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def log_subjects(file) do
    case System.cmd("git", ["log", "--format=%s", "--", file], cd: root()) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def log_entries(file) do
    case System.cmd("git", ["log", "--format=%H%x00%ct%x00%s", "--", file], cd: root()) do
      {output, 0} ->
        entries =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&parse_entry/1)

        {:ok, entries}

      {output, _} ->
        {:error, String.trim(output)}
    end
  end

  def show_info(sha) do
    case System.cmd("git", ["show", "--no-patch", "--format=%H%x00%ct%x00%s", sha], cd: root()) do
      {output, 0} -> {:ok, output |> String.trim() |> parse_entry()}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def show_diff(sha) do
    case System.cmd("git", ["show", "--format=", sha], cd: root()) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def list_files do
    case System.cmd("git", ["ls-files"], cd: root()) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def remove_file(file) do
    case System.cmd("git", ["rm", "--", file], cd: root()) do
      {_, 0} -> :ok
      {output, _} -> {:error, String.trim(output)}
    end
  end

  def find_initial_commit do
    case System.cmd("git", ["rev-list", "--max-parents=0", "HEAD"], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  # Helpers

  defp parse_entry(line) do
    [sha, ts, subject] = String.split(line, "\x00", parts: 3)
    %{sha: sha, timestamp: String.to_integer(ts), subject: subject}
  end
end
