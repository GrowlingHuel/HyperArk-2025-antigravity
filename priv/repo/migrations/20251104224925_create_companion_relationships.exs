defmodule GreenManTavern.Repo.Migrations.CreateCompanionRelationships do
  use Ecto.Migration

  def change do
    create table(:companion_relationships) do
      add :plant_a_id, references(:plants, on_delete: :delete_all), null: false
      add :plant_b_id, references(:plants, on_delete: :delete_all), null: false
      add :relationship_type, :string, size: 10
      add :evidence_level, :string, size: 20
      add :mechanism, :text
      add :notes, :text

      timestamps(type: :naive_datetime)
    end

    create index(:companion_relationships, [:plant_a_id])
    create index(:companion_relationships, [:plant_b_id])
    create index(:companion_relationships, [:relationship_type])

    # Unique constraint to prevent duplicate relationships
    create unique_index(:companion_relationships, [:plant_a_id, :plant_b_id])
  end
end
