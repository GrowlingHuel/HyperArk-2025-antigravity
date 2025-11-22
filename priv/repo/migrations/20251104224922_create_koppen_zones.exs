defmodule GreenManTavern.Repo.Migrations.CreateKoppenZones do
  use Ecto.Migration

  def change do
    create table(:koppen_zones) do
      add :code, :string, size: 3, null: false
      add :name, :string, size: 100
      add :category, :string, size: 20
      add :description, :text
      add :temperature_pattern, :text
      add :precipitation_pattern, :text

      timestamps(type: :naive_datetime)
    end

    create unique_index(:koppen_zones, [:code])
  end
end
