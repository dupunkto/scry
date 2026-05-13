defmodule Scry.Git do
  @moduledoc false

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

  def reset_soft(target, file) do
    case System.cmd("git", ["reset", "--soft", target, "--", file], cd: root()) do
      {_, 0} -> :ok
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

  def find_initial_commit do
    case System.cmd("git", ["rev-list", "--max-parents=0", "HEAD"], cd: root()) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  end

  defp root, do: Application.fetch_env!(:scry, :root)
end
