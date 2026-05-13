defmodule ScryWeb.LandingController do
  @moduledoc false
  use ScryWeb, :controller

  def landing(conn, _params) do
    render(conn, :landing)
  end
end
