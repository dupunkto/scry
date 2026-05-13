defmodule ScryWeb.LandingController do
  @moduledoc false
  use ScryWeb, :controller

  def landing(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/list")
    else
      render(conn, :landing)
    end
  end
end
