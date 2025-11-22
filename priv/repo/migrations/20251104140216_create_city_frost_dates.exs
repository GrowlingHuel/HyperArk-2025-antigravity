defmodule GreenManTavern.Repo.Migrations.CreateCityFrostDates do
  use Ecto.Migration

  def change do
    create table(:city_frost_dates) do
      add :city_id, references(:cities, on_delete: :delete_all), null: false
      add :last_frost_date, :string, size: 50
      add :first_frost_date, :string, size: 50
      add :growing_season_days, :integer
      add :data_source, :string, size: 100
      add :confidence_level, :string, size: 20
      add :notes, :text

      timestamps()
    end

    # Unique index - one frost date record per city
    create unique_index(:city_frost_dates, [:city_id])

    # Index on confidence_level for filtering
    create index(:city_frost_dates, [:confidence_level])
  end
end
