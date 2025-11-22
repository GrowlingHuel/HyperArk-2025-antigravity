defmodule GreenManTavern.Repo do
  use Ecto.Repo,
    otp_app: :green_man_tavern,
    adapter: Ecto.Adapters.Postgres

  # Note: We exclude description_embedding (vector type) from queries that don't need it
  # to avoid Postgrex type handling issues. Vector operations use raw SQL.
end
