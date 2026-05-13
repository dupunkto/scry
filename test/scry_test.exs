defmodule ScryTest do
  use ExUnit.Case, async: false

  setup do
    root = Path.join(System.tmp_dir!(), "scry-test-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(root)

    {_, 0} = System.cmd("git", ["init", "-q", "-b", "trunk", root])
    {_, 0} = System.cmd("git", ["config", "user.email", "scry@dupunkto.org"], cd: root)
    {_, 0} = System.cmd("git", ["config", "user.name", "Scry"], cd: root)

    prev = Application.get_env(:scry, :root)
    Application.put_env(:scry, :root, root)

    on_exit(fn ->
      if prev, do: Application.put_env(:scry, :root, prev), else: Application.delete_env(:scry, :root)
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  defp subjects(root) do
    {out, 0} = System.cmd("git", ["log", "--format=%s"], cd: root)
    String.split(out, "\n", trim: true)
  end

  describe "path validation" do
    test "rejects '..' across functions" do
      assert {:error, :illegal} = Scry.track("../escape.ex", "x")
      assert {:error, :illegal} = Scry.squash("../escape.ex", "msg")
      assert {:error, :illegal} = Scry.delete("../escape.ex")
      assert {:error, :illegal} = Scry.source("../escape.ex")
      assert {:error, :illegal} = Scry.history("../escape.ex")
    end

    test "rejects single quote across functions" do
      assert {:error, :illegal} = Scry.track("evil'.ex", "x")
      assert {:error, :illegal} = Scry.squash("evil'.ex", "msg")
      assert {:error, :illegal} = Scry.delete("evil'.ex")
      assert {:error, :illegal} = Scry.source("evil'.ex")
      assert {:error, :illegal} = Scry.history("evil'.ex")
    end
  end

  describe "track/2" do
    test "first track creates an (edit) commit and writes the file", %{root: root} do
      assert {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert File.read!(Path.join(root, "hello.ex")) == "v1"
      assert subjects(root) == ["(edit) hello.ex"]
    end

    test "tracking identical content returns :unchanged and creates no commit", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert {:ok, :unchanged} = Scry.track("hello.ex", "v1")
      assert subjects(root) == ["(edit) hello.ex"]
    end

    test "tracking trimmed-equivalent content returns :unchanged" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert {:ok, :unchanged} = Scry.track("hello.ex", "  v1\n")
    end

    test "tracking different content appends a new commit and writes the latest", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert {:ok, :edited} = Scry.track("hello.ex", "v2")
      assert File.read!(Path.join(root, "hello.ex")) == "v2"
      assert subjects(root) == ["(edit) hello.ex", "(edit) hello.ex"]
    end
  end

  describe "squash/2" do
    test "with no prior revision, collapses all edits into one revision", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :edited} = Scry.track("hello.ex", "v3")

      assert {:ok, :squashed} = Scry.squash("hello.ex", "First.")

      assert subjects(root) == ["(revision) <hello.ex> First."]
      assert File.read!(Path.join(root, "hello.ex")) == "v3"
    end

    test "second squash preserves the first revision and appends another", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :squashed} = Scry.squash("hello.ex", "First.")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :squashed} = Scry.squash("hello.ex", "Second.")

      assert subjects(root) == [
               "(revision) <hello.ex> Second.",
               "(revision) <hello.ex> First."
             ]

      assert File.read!(Path.join(root, "hello.ex")) == "v2"
    end

    test "preserves inter-revision commits to other files", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :edited} = Scry.track("other.ex", "o1")
      {:ok, :edited} = Scry.track("hello.ex", "v3")

      {:ok, :squashed} = Scry.squash("hello.ex", "First.")

      assert subjects(root) == [
               "(revision) <hello.ex> First.",
               "(edit) other.ex"
             ]

      assert File.read!(Path.join(root, "hello.ex")) == "v3"
      assert File.read!(Path.join(root, "other.ex")) == "o1"
    end

    test "squashing one object doesn't disturb another's pending edits", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("other.ex", "o1")
      {:ok, :edited} = Scry.track("other.ex", "o2")

      {:ok, :squashed} = Scry.squash("hello.ex", "Done.")

      assert File.read!(Path.join(root, "other.ex")) == "o2"
      assert {:ok, %{pending: 2, revisions: []}} = Scry.history("other.ex")
    end
  end

  describe "delete/1" do
    test "removes the object from the working tree and from list/0" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert {:ok, ["hello.ex"]} = Scry.list()

      assert {:ok, :deleted} = Scry.delete("hello.ex")
      assert {:ok, []} = Scry.list()
    end

    test "creates a (delete) commit", %{root: root} do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :deleted} = Scry.delete("hello.ex")

      assert subjects(root) == ["(delete) hello.ex", "(edit) hello.ex"]
    end

    test "track after delete re-adds the object" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :deleted} = Scry.delete("hello.ex")
      assert {:ok, :edited} = Scry.track("hello.ex", "v2")
      assert {:ok, ["hello.ex"]} = Scry.list()
      assert {:ok, "v2"} = Scry.source("hello.ex")
    end
  end

  describe "list/0" do
    test "empty repo returns no objects" do
      assert {:ok, []} = Scry.list()
    end

    test "lists tracked objects" do
      {:ok, :edited} = Scry.track("a.ex", "1")
      {:ok, :edited} = Scry.track("b.ex", "2")
      assert {:ok, slugs} = Scry.list()
      assert Enum.sort(slugs) == ["a.ex", "b.ex"]
    end

    test "excludes deleted objects" do
      {:ok, :edited} = Scry.track("a.ex", "1")
      {:ok, :edited} = Scry.track("b.ex", "2")
      {:ok, :deleted} = Scry.delete("a.ex")
      assert {:ok, ["b.ex"]} = Scry.list()
    end
  end

  describe "source/1" do
    test "returns the current content" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      assert {:ok, "v1"} = Scry.source("hello.ex")
    end

    test "returns the latest content after multiple tracks" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :edited} = Scry.track("hello.ex", "v3")
      assert {:ok, "v3"} = Scry.source("hello.ex")
    end

    test "returns :enoent for an unknown object" do
      assert {:error, :enoent} = Scry.source("missing.ex")
    end
  end

  describe "history/1" do
    test "empty for an untracked object" do
      assert {:ok, %{revisions: [], pending: 0}} = Scry.history("missing.ex")
    end

    test "counts pending edits with no revisions" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :edited} = Scry.track("hello.ex", "v3")

      assert {:ok, %{revisions: [], pending: 3}} = Scry.history("hello.ex")
    end

    test "after squash, revisions populated and pending zero" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :squashed} = Scry.squash("hello.ex", "First.")

      assert {:ok, %{revisions: [r], pending: 0}} = Scry.history("hello.ex")
      assert r.message == "First."
      assert is_integer(r.timestamp)
      assert String.length(r.sha) == 40
    end

    test "new edits after squash show up as pending" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :squashed} = Scry.squash("hello.ex", "First.")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :edited} = Scry.track("hello.ex", "v3")

      assert {:ok, %{revisions: [_], pending: 2}} = Scry.history("hello.ex")
    end

    test "revisions in reverse chronological order" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :squashed} = Scry.squash("hello.ex", "First.")
      {:ok, :edited} = Scry.track("hello.ex", "v2")
      {:ok, :squashed} = Scry.squash("hello.ex", "Second.")
      {:ok, :edited} = Scry.track("hello.ex", "v3")
      {:ok, :squashed} = Scry.squash("hello.ex", "Third.")

      {:ok, %{revisions: revisions}} = Scry.history("hello.ex")
      assert Enum.map(revisions, & &1.message) == ["Third.", "Second.", "First."]
    end

    test "ignores commits touching other files" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :edited} = Scry.track("other.ex", "o1")
      {:ok, :edited} = Scry.track("other.ex", "o2")
      {:ok, :edited} = Scry.track("hello.ex", "v2")

      assert {:ok, %{revisions: [], pending: 2}} = Scry.history("hello.ex")
      assert {:ok, %{revisions: [], pending: 2}} = Scry.history("other.ex")
    end
  end

  describe "revision/1" do
    test "returns metadata and diff for a revision commit" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {:ok, :squashed} = Scry.squash("hello.ex", "First.")
      {:ok, %{revisions: [%{sha: sha}]}} = Scry.history("hello.ex")

      assert {:ok, rev} = Scry.revision(sha)
      assert rev.sha == sha
      assert rev.message == "First."
      assert is_integer(rev.timestamp)
      assert rev.diff =~ "hello.ex"
      assert rev.diff =~ "v1"
    end

    test "returns empty message for an (edit) commit" do
      {:ok, :edited} = Scry.track("hello.ex", "v1")
      {out, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: Application.get_env(:scry, :root))
      sha = String.trim(out)

      assert {:ok, rev} = Scry.revision(sha)
      assert rev.message == ""
      assert rev.diff =~ "hello.ex"
    end

    test "returns error for an unknown sha" do
      assert {:error, _} = Scry.revision("0000000000000000000000000000000000000000")
    end
  end
end
