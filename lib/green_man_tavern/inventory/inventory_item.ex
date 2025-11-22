defmodule GreenManTavern.Inventory.InventoryItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_inventory_items" do
    field :name, :string
    field :category, :string
    field :source_type, :string
    field :source_id, :integer
    field :quantity, :integer, default: 1
    field :user_id, :integer  # ← FIXED: Define as regular field
    field :location, :string
    field :notes, :string
    field :icon_name, :string
    field :position_x, :integer
    field :position_y, :integer
    field :metadata, :map

    timestamps()
  end

  @valid_source_types ~w(system plant conversation manual)
  @valid_categories ~w(food tools kitchen garden storage water energy waste)

  @doc false
  def changeset(inventory_item, attrs) do
    inventory_item
    |> cast(attrs, [
      :user_id, 
      :name, 
      :category, 
      :source_type, 
      :source_id,
      :quantity,
      :location,
      :notes,
      :icon_name,
      :position_x,
      :position_y,
      :metadata
    ])
    |> validate_required([:user_id, :name, :category, :source_type])
    |> validate_inclusion(:source_type, @valid_source_types)
    |> validate_inclusion(:category, @valid_categories)
    |> validate_number(:quantity, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :source_type, :source_id], 
         name: :user_inventory_items_unique_source)
  end

  @doc """
    Changeset for manually added items (no source tracking)
"""
    def manual_changeset(inventory_item, attrs) do
     # Convert attrs to string keys to avoid mixing atom/string keys
    attrs = 
     attrs
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Map.new()
        |> Map.put("source_type", "manual")
        |> Map.put("source_id", nil)
  
  changeset(inventory_item, attrs)
end
end
