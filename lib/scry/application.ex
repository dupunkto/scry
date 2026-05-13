defmodule Scry.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ScryWeb.Telemetry,
      {Phoenix.PubSub, name: Scry.PubSub},
      ScryWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Scry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ScryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
