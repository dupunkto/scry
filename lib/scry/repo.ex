defmodule Scry.Repo do
  use Ecto.Repo,
    otp_app: :scry,
    adapter: Ecto.Adapters.Postgres
end
