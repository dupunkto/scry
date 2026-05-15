defmodule ScryWeb.Router do
  @moduledoc false
  use ScryWeb, :router

  import ScryWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_current_user
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

  # Here for legacy reasons (backward-compatibility, yay!)
  scope "/", ScryWeb do
    pipe_through :api

    post "/webhook/:token", APIController, :webhook
  end

  scope "/api", ScryWeb do
    pipe_through :api

    post "/track/:object", APIController, :track
    post "/squash/:object", APIController, :squash
    get "/history/:object", APIController, :history
  end

  scope "/", ScryWeb do
    pipe_through [:browser, :require_auth]

    get "/login", DashboardController, :login
    get "/browse", DashboardController, :browse
    get "/add", DashboardController, :add

    # Objects
    get "/object/:object", DashboardController, :summary
    get "/object/:object/source", DashboardController, :source
    get "/object/:object/log", DashboardController, :log
    post "/object/:object/delete", DashboardController, :delete

    # Revisions
    get "/rev/:sha", DashboardController, :revision
    get "/rev/:sha/source", DashboardController, :source
  end
end
