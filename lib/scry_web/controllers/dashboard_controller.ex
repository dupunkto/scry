defmodule ScryWeb.DashboardController do
  @moduledoc false
  use ScryWeb, :controller

  def login(conn, _params) do
    redirect(conn, to: ~p"/")
  end

  def browse(conn, _params) do
    case Scry.list() do
      {:ok, objects} -> render(conn, :browse, objects: objects)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def add(conn, _params) do
    render(conn, :add)
  end

  def summary(conn, %{"object" => object}) do
    case Scry.history(object) do
      {:ok, history} -> render(conn, :object_summary, object: object, history: history)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def source(conn, %{"object" => object}) do
    case Scry.source(object) do
      {:ok, source} -> render(conn, :object_source, object: object, source: source)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def source(conn, %{"sha" => sha}) do
    case Scry.revision(sha) do
      {:ok, revision} -> render(conn, :revision_source, revision: revision)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def log(conn, %{"object" => object}) do
    case Scry.history(object) do
      {:ok, history} -> render(conn, :object_log, object: object, history: history)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def revision(conn, %{"sha" => sha}) do
    case Scry.revision(sha) do
      {:ok, revision} -> render(conn, :revision_diff, revision: revision)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def delete(conn, %{"object" => object}) do
    case Scry.delete(object) do
      {:ok, :deleted} -> redirect(conn, to: ~p"/browse")
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  defp serve_error(conn, reason) do
    case reason do
      :illegal -> conn |> put_status(:bad_request) |> text("Illegal path.")
      :enoent -> conn |> put_status(:not_found) |> text("Not found.")
      _ -> conn |> put_status(:internal_server_error) |> text("Crashed.")
    end
  end
end
