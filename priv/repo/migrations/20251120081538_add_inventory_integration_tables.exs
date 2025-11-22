defmodule GreenManTavern.Repo.Migrations.AddInventoryIntegrationTables do
  use Ecto.Migration

  def up do
    # Table 1: Processing Batches
    create table(:processing_batches) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :process_type, :string, null: false
      add :system_id, references(:user_systems, on_delete: :nilify_all)
      add :input_items, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :output_items, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :started_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :complete_at, :naive_datetime, null: false
      add :status, :string, null: false, default: "in_progress"
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")

      timestamps()
    end

    create index(:processing_batches, [:user_id])
    create index(:processing_batches, [:status])
    create index(:processing_batches, [:complete_at])

    # Table 2: Inventory Actions
    create table(:inventory_actions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :action_type, :string, null: false
      add :source_system_id, references(:user_systems, on_delete: :nilify_all)
      add :target_system_id, references(:user_systems, on_delete: :nilify_all)
      add :items_affected, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :performed_at, :naive_datetime, null: false, default: fragment("NOW()")
    end

    create index(:inventory_actions, [:user_id])
    create index(:inventory_actions, [:action_type])
    create index(:inventory_actions, [:performed_at])
  end

  def down do
    drop table(:inventory_actions)
    drop table(:processing_batches)
  end
end
