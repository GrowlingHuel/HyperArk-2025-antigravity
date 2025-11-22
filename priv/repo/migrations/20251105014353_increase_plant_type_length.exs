defmodule GreenManTavern.Repo.Migrations.IncreasePlantTypeLength do
  use Ecto.Migration

  def change do
    alter table(:plants) do
      modify :plant_type, :string, size: 50
    end
  end
end
