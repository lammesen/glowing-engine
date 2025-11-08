defmodule NetAuto.Repo do
  use Ecto.Repo,
    otp_app: :net_auto,
    adapter: Ecto.Adapters.Postgres
end
