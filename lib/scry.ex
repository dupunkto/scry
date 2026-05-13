defmodule Scry do
  @moduledoc """
  Scry is the version control system used in many {du}punkto projects,
  most notably being the primary version control system used in
  [Vik](https://docs.dupunkto.org/vik) (which is not a {du}punkto project, oops).

  ## Usage

  Scry is a thin wrapper around `git`. It has the following concepts:

  - A **ref**, which is a file that is versioned.
  - A **commit**, which is a change to a ref.

  Changes to refs are tracked by calling `track/2` with the current state
  of the ref. If this state is different from the previous state known by
  Scry, a new commit will be created.
  
  Commits can be *incremental* or *squashed*. Scry is designed to
  'fire-and-forget'. An example use-case would be a text editor that
  sends its contents on every save, or on a debounce. This naturally
  results in many small commits to a ref, all named `(inc) ref`.
  At the end of an edit session, `squash/2` can be called with a descriptive
  message. This will collect all commits to the given ref, from the previous
  squashed commit on, and replace them with a single commit named
  `(squash) ref <message>`.

  ## Architecture

  Scry tracks version changes in a single monolithic git repository,
  where each tracked ref is represented as a file.
  Every commit in Scry is analogous to one commit in git. Each git commit
  thus only modifies a single file.
  """

  alias Scry.Git

  defp root, do: Application.fetch_env!(:scry, :root)

  @doc """
  Track a new change to `ref` with content `source`.

  The diff between the current state and new state is automatically
  calculated. If the files differ, a new commit will be created.
  """
  @spec track(Path.t(), binary()) :: {:ok, :committed | :unchanged} | {:error, term()}
  def track(ref, source) when is_binary(ref) and is_binary(source) do
    with :ok <- validate_path(ref),
         path = Path.join(root(), ref),
         :ok <- validate_changed(path, source),
         :ok <- File.write(path, source),
         :ok <- Git.commit_all("(inc) #{ref}") do
      {:ok, :committed}
    else
      {:error, :unchanged} -> {:ok, :unchanged}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Squash automatic commits for `ref` into a single named commit.

  Finds the last named commit to touch `ref`, and squashes all commits
  after into a single named commit with description `message`.

  ## Example

  Suppose the following commit history with three files
  (`hello.ex`, `other.ex`, and `world.ex`):

      (inc) hello.ex
      (inc) other.ex
      (squash) world.ex Initial version of world editor.
      (inc) other.ex
      (inc) hello.ex
      (inc) world.ex
      (inc) other.ex
      (inc) world.ex

  Calling `squash("world.ex", "Minor changes")` would produce the
  following history:

      (inc) hello.ex
      (inc) other.ex
      (squash) <world.ex> Initial version of world editor.
      (inc) other.ex
      (inc) hello.ex
      (inc) other.ex
      (squash) <world.ex> Minor changes

  Calling `squash("hello.ex", "Major changes")`, instead, would produce:

      (inc) other.ex
      (squash) <world.ex> Initial version of world editor.
      (inc) other.ex
      (inc) world.ex
      (inc) other.ex
      (inc) world.ex
      (squash) <hello.ex> Major changes.

  """
  @spec squash(Path.t(), String.t()) :: {:ok, :squashed} | {:error, term()}
  def squash(ref, message) when is_binary(ref) and is_binary(message) do
    with :ok <- validate_path(ref),
         {:ok, target} <- resolve_squash_target(ref),
         :ok <- Git.reset_soft(target, ref),
         :ok <- Git.commit_file("(squash) <#{ref}> #{message}", ref) do
      {:ok, :squashed}
    end
  end

  defp resolve_squash_target(ref) do
    case Git.find_last_commit("squash", ref) do
      {:ok, ""} ->
        with {:ok, initial} <- Git.find_initial_commit(), do: {:ok, "#{initial}^"}

      {:ok, sha} ->
        Git.rev_parse("#{sha}^")

      err ->
        err
    end
  end

  defp validate_path(ref) do
    cond do
      String.contains?(ref, "..") -> {:error, :illegal}
      String.contains?(ref, "'") -> {:error, :illegal}
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
