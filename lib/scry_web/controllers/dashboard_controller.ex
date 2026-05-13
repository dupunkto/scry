defmodule ScryWeb.DashboardController do
  @moduledoc false
  use ScryWeb, :controller

  def login(conn, _params) do
    redirect(conn, to: ~p"/")
  end

  def list(conn, _params) do
    case Scry.list() do
      {:ok, objects} -> render(conn, :list, objects: objects)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def add(conn, _params) do
    render(conn, :add)
  end

  def object(conn, %{"object" => object}) do
    with {:ok, source} <- Scry.source(object),
         {:ok, history} <- Scry.history(object) do
      render(conn, :object, object: object, source: source, history: history)
    else
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def revision(conn, %{"sha" => sha}) do
    case Scry.revision(sha) do
      {:ok, revision} -> render(conn, :revision, revision: revision)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def delete(conn, %{"object" => object}) do
    case Scry.delete(object) do
      {:ok, :deleted} -> redirect(conn, to: ~p"/list")
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
