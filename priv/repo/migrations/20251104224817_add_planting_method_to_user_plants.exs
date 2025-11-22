defmodule GreenManTavern.Repo.Migrations.AddPlantingMethodToUserPlants do
  use Ecto.Migration

  def change do
    alter table(:user_plants) do
      add :planting_method, :string, default: "seeds", null: false
    end
  end
end
