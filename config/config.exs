import Config

config :scry, ScryWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ScryWeb.ErrorHTML, json: ScryWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Scry.PubSub,
  live_view: [signing_salt: "FdK/blNJ"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
