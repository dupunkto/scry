defmodule ScryWeb.APIController do
  @moduledoc false
  use ScryWeb, :controller

  plug :authenticate

  defp authenticate(conn, _opts) do
    if conn.params["token"] == Application.fetch_env!(:scry, :token) do
      conn
    else
      conn |> serve_error(:unauthorized) |> halt()
    end
  end

  def webhook(conn, %{"content" => %{"slug" => ref, "source_code" => source}}) do
    case Scry.track(ref, source) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def webhook(conn, _params), do: serve_error(conn, :bad_request)

  def track(conn, %{"ref" => ref, "source_code" => source}) do
    case Scry.track(ref, source) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def track(conn, _params), do: serve_error(conn, :bad_request)

  def squash(conn, %{"ref" => ref, "message" => message}) do
    case Scry.squash(ref, message) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def squash(conn, _params), do: serve_error(conn, :bad_request)

  # Helpers

  defp serve_status(conn, status) do
    json(conn, %{status: "#{status |> Atom.to_string() |> String.capitalize()}."})
  end

  defp serve_error(conn, reason) do
    case reason do
      :unauthorized -> conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized."})
      :illegal -> conn |> put_status(:bad_request) |> json(%{error: "Illegal path."})
      :bad_request -> conn |> put_status(:bad_request) |> json(%{error: "Bad request."})
      _ -> conn |> put_status(:internal_server_error) |> json(%{error: "Crashed."})
    end
  end
end
