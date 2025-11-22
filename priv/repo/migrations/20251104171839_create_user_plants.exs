defmodule GreenManTavern.Repo.Migrations.CreateUserPlants do
  use Ecto.Migration

  def change do
    create table(:user_plants) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :plant_id, references(:plants, on_delete: :delete_all), null: false
      add :city_id, references(:cities, on_delete: :nilify_all), null: true
      add :status, :string, null: false
      add :planting_date_start, :date, null: true
      add :planting_date_end, :date, null: true
      add :expected_harvest_date, :date, null: true
      add :actual_planting_date, :date, null: true
      add :actual_harvest_date, :date, null: true
      add :notes, :text, null: true

      timestamps(type: :utc_datetime)
    end

    create index(:user_plants, [:user_id])
    create index(:user_plants, [:plant_id])
    create index(:user_plants, [:status])
    create unique_index(:user_plants, [:user_id, :plant_id])
  end
end
