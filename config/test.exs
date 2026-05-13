import Config

config :scry, ScryWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "XnH1mA6Or82SEGMsgdUHm3OW2VaAi3kW678PR+NPPuHIbv4Ig6vooryyQytHU27I",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
