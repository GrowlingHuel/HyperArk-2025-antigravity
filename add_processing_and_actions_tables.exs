defmodule GreenManTavern.Repo.Migrations.AddProcessingAndActionsTables do
  use Ecto.Migration

  def up do
    # ========================================
    # TABLE 1: PROCESSING BATCHES
    # Tracks active transformations (drying, fermenting, etc.)
    # ========================================
    create table(:processing_batches) do
      # Who is processing?
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      # What kind of process?
      add :process_type, :string, null: false
      # Examples: "drying", "fermenting", "composting", "seed_saving"
      
      # Which system is doing the processing?
      add :system_id, references(:user_systems, on_delete: :nilify_all)
      # Examples: drying_rack.id, fermenting_crock.id
      # Can be NULL if process doesn't need a specific system
      
      # What went in?
      add :input_items, :jsonb, null: false, default: fragment("'[]'::jsonb")
      # Example: [{"item_id": 123, "name": "Fresh Basil", "quantity": 20}]
      
      # What will come out?
      add :output_items, :jsonb, null: false, default: fragment("'[]'::jsonb")
      # Example: [{"name": "Dried Basil", "quantity": 15, "unit": "g"}]
      
      # Timing
      add :started_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :complete_at, :naive_datetime, null: false
      
      # Status tracking
      add :status, :string, null: false, default: "in_progress"
      # Values: "in_progress", "complete", "cancelled", "failed"
      
      # Flexible storage for process-specific data
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      # Example: {"temperature": "low", "notes": "First batch"}

      timestamps()
    end

    # Indexes for performance
    create index(:processing_batches, [:user_id])
    create index(:processing_batches, [:status])
    create index(:processing_batches, [:complete_at])
    create index(:processing_batches, [:system_id])

    # ========================================
    # TABLE 2: INVENTORY ACTIONS
    # Tracks all actions users perform with inventory
    # ========================================
    create table(:inventory_actions) do
      # Who performed the action?
      add :user_id, references(:users, on_delete: :delete_all), null: false
      
      # What type of action?
      add :action_type, :string, null: false
      # Examples: "harvest", "consume", "process_start", "process_complete", 
      #           "waste", "gift", "trade", "purchase"
      
      # Where did items come from? (optional)
      add :source_system_id, references(:user_systems, on_delete: :nilify_all)
      # Example: herb_garden.id (harvested from)
      
      # Where did items go to? (optional)
      add :target_system_id, references(:user_systems, on_delete: :nilify_all)
      # Example: kitchen.id (used in)
      
      # Which items were affected?
      add :items_affected, :jsonb, null: false, default: fragment("'[]'::jsonb")
      # Example: [{"item_id": 456, "name": "Basil", "quantity": 12}]
      
      # Additional context
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      # Example: {"recipe": "Pesto", "living_web_node": "node_123"}
      
      # When did this happen?
      add :performed_at, :naive_datetime, null: false, default: fragment("NOW()")
    end

    # Indexes for performance
    create index(:inventory_actions, [:user_id])
    create index(:inventory_actions, [:action_type])
    create index(:inventory_actions, [:performed_at])
    create index(:inventory_actions, [:source_system_id])
    create index(:inventory_actions, [:target_system_id])
  end

  def down do
    # Rollback in reverse order
    drop table(:inventory_actions)
    drop table(:processing_batches)
  end
end
