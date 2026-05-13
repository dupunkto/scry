defmodule ScryWeb.Router do
  @moduledoc false
  use ScryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ScryWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ScryWeb do
    pipe_through :browser

    get "/", LandingController, :landing
  end

  scope "/api", ScryWeb do
    pipe_through :api

    post "/track/:object", APIController, :track
    post "/merge/:object", APIController, :merge
    get "/history/:object", APIController, :history

    # Here for legacy reasons (backward-compatibility, yay!)
    post "/webhook/:token", APIController, :webhook
  end
end
