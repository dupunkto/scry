defmodule ScryWeb.DashboardHTML do
  @moduledoc false
  use ScryWeb, :html

  embed_templates "dashboard_html/*"

  def date(timestamp) do
    timestamp |> DateTime.from_unix!() |> Calendar.strftime("%Y-%m-%d")
  end
end
