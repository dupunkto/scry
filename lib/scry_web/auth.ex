defmodule ScryWeb.Auth do
  @moduledoc false
  use ScryWeb, :plug

  @realm "Scry"

  import Plug.Crypto, only: [secure_compare: 2]
  import Plug.BasicAuth, only: [parse_basic_auth: 1, request_basic_auth: 2]

  def fetch_current_user(conn, opts) do
    case Application.fetch_env!(:scry, :auth) do
      :nym -> Nym.fetch_current_user(conn, opts)
      :basic -> fetch_basic_auth(conn, opts)
    end
  end

  def require_auth(conn, opts) do
    case Application.fetch_env!(:scry, :auth) do
      :nym -> Nym.require_auth(conn, opts)
      :basic -> require_basic_auth(conn, opts)
    end
  end

  @spec fetch_basic_auth(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  defp fetch_basic_auth(conn, _opts) do
    case validate_credentials(conn) do
      {:ok, username} -> log_in(conn, username)
      :error -> conn |> renew_session() |> log_in(nil)
    end
  end

  @spec require_basic_auth(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  defp require_basic_auth(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn |> request_basic_auth(realm: @realm) |> halt()
    end
  end

  defp validate_credentials(conn) do
    app_password = Application.fetch_env!(:scry, :password)

    with {username, password} <- parse_basic_auth(conn) do
      if secure_compare(password, app_password) do
        {:ok, username}
      else
        :error
      end
    end
  end

  defp log_in(conn, username) do
    conn
    |> assign(:current_user, username)
    |> put_session(:current_user, username)
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing.
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end