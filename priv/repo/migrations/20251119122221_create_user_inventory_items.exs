defmodule GreenManTavern.Repo.Migrations.CreateUserInventoryItems do
  use Ecto.Migration

  def up do
    create table(:user_inventory_items) do
      # Core fields
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :category, :string, null: false  # "food", "tools", "kitchen", "garden", "storage", "water", "energy"
      
      # Source tracking (polymorphic - links back to original data)
      add :source_type, :string, null: false  # "system", "plant", "conversation", "manual"
      add :source_id, :integer  # References user_systems.id, user_plants.id, etc. NULL for manual entries
      
      # Inventory-specific properties
      add :quantity, :integer, default: 1, null: false
      add :location, :string  # Physical location in user's space
      add :notes, :text
      
      # Visual/organizational (for grid layout)
      add :icon_name, :string
      add :position_x, :integer  # Grid position for user organization
      add :position_y, :integer
      
      # Extensibility
      add :metadata, :jsonb, default: fragment("'{}'::jsonb")
      
      # Timestamps
      add :inserted_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :updated_at, :naive_datetime, null: false, default: fragment("NOW()")
    end

    # Indexes for performance
    create index(:user_inventory_items, [:user_id])
    create index(:user_inventory_items, [:source_type, :source_id])
    create index(:user_inventory_items, [:category])
    
    # Ensure no duplicate source entries per user
    create unique_index(:user_inventory_items, [:user_id, :source_type, :source_id], 
      where: "source_id IS NOT NULL",
      name: :user_inventory_items_unique_source)
  end

  def down do
    drop table(:user_inventory_items)
  end
end
