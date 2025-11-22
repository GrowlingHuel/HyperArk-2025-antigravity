defmodule GreenManTavern.Repo.Migrations.CreateCities do
  use Ecto.Migration

  def change do
    create table(:cities) do
      add :city_name, :string, size: 100
      add :country, :string, size: 100
      add :state_province_territory, :string, size: 100
      add :latitude, :decimal, precision: 10, scale: 7
      add :longitude, :decimal, precision: 10, scale: 7

      add :koppen_code, :string, size: 3

      add :hemisphere, :string, size: 10
      add :notes, :text

      timestamps(type: :naive_datetime)
    end

    # Foreign key constraint for non-integer column
    execute(
      "ALTER TABLE cities ADD CONSTRAINT cities_koppen_code_fkey FOREIGN KEY (koppen_code) REFERENCES koppen_zones(code) ON DELETE RESTRICT",
      "ALTER TABLE cities DROP CONSTRAINT cities_koppen_code_fkey"
    )

    create index(:cities, [:city_name])
    create index(:cities, [:country])
    create index(:cities, [:koppen_code])
  end
end
