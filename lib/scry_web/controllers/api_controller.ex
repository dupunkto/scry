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

  # The webhook endpoint exists to be backward-compatible with earlier versions
  # of Scry (that have not been published) and the version control system used
  # in Vik before that. Prefer to use the /track endpoint if possible.

  def webhook(conn, %{"content" => %{"slug" => object, "source_code" => source}}) do
    case Scry.track(object, source) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def webhook(conn, _params) do
    serve_error(conn, :bad_request)
  end

  def track(conn, %{"object" => object, "source_code" => source}) do
    case Scry.track(object, source) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def track(conn, _params) do
    serve_error(conn, :bad_request)
  end

  def squash(conn, %{"object" => object, "message" => message}) do
    case Scry.squash(object, message) do
      {:ok, status} -> serve_status(conn, status)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def squash(conn, _params) do
    serve_error(conn, :bad_request)
  end

  def history(conn, %{"object" => object}) do
    case Scry.history(object) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> serve_error(conn, reason)
    end
  end

  def history(conn, _params) do
    serve_error(conn, :bad_request)
  end

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
