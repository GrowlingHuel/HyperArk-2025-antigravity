defmodule GreenManTavern.Repo.Migrations.AddLivingWebNodeIdToUserPlants do
  use Ecto.Migration

  def change do
    alter table(:user_plants) do
      add :living_web_node_id, :string
    end
  end
end
