defmodule GreenManTavern.Repo.Migrations.CreateRackTables do
  use Ecto.Migration

  def change do
    create table(:devices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :nothing), null: false
      add :user_plant_id, references(:user_plants, on_delete: :nilify_all)
      add :name, :string
      add :position_index, :integer, null: false
      add :settings, :map, default: %{}

      timestamps()
    end

    create index(:devices, [:user_id])
    create index(:devices, [:project_id])
    create index(:devices, [:user_plant_id])

    create table(:patch_cables, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :source_device_id, references(:devices, on_delete: :delete_all, type: :binary_id), null: false
      add :target_device_id, references(:devices, on_delete: :delete_all, type: :binary_id), null: false
      add :source_jack_id, :string, null: false
      add :target_jack_id, :string, null: false
      add :cable_color, :string

      timestamps()
    end

    create index(:patch_cables, [:user_id])
    create index(:patch_cables, [:source_device_id])
    create index(:patch_cables, [:target_device_id])
  end
end
