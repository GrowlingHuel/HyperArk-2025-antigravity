defmodule GreenManTavern.Repo.Migrations.CreatePlants do
  use Ecto.Migration

  def change do
    create table(:plants) do
      add :common_name, :string, size: 100, null: false
      add :scientific_name, :string, size: 150
      add :plant_family, :string, size: 100
      add :family_id, references(:plant_families, on_delete: :nilify_all)
      add :plant_type, :string, size: 50
      add :climate_zones, {:array, :string}
      add :growing_difficulty, :string, size: 20
      add :space_required, :string, size: 20
      add :sunlight_needs, :string, size: 20
      add :water_needs, :string, size: 20
      add :days_to_germination_min, :integer
      add :days_to_germination_max, :integer
      add :days_to_harvest_min, :integer
      add :days_to_harvest_max, :integer
      add :perennial_annual, :string, size: 20
      add :planting_months_sh, :string, size: 50
      add :planting_months_nh, :string, size: 50
      add :height_cm_min, :integer
      add :height_cm_max, :integer
      add :spread_cm_min, :integer
      add :spread_cm_max, :integer
      add :native_region, :string, size: 100
      add :description, :text

      timestamps(type: :naive_datetime)
    end

    create index(:plants, [:common_name])
    create index(:plants, [:plant_type])
    create index(:plants, [:family_id])
    # GIN index for efficient array searching in PostgreSQL
    create index(:plants, [:climate_zones], using: :gin)
  end
end
