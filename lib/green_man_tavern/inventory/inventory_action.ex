defmodule GreenManTavern.Inventory.InventoryAction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "inventory_actions" do
    field :action_type, :string
    field :items_affected, :map
    field :metadata, :map
    field :performed_at, :naive_datetime

    belongs_to :user, GreenManTavern.Accounts.User
    belongs_to :source_system, GreenManTavern.Systems.UserSystem
    belongs_to :target_system, GreenManTavern.Systems.UserSystem
  end

  @valid_action_types ~w(
    harvest consume process_start process_complete
    waste gift trade purchase move
  )

  def changeset(inventory_action, attrs) do
    inventory_action
    |> cast(attrs, [
      :user_id,
      :action_type,
      :source_system_id,
      :target_system_id,
      :items_affected,
      :metadata,
      :performed_at
    ])
    |> validate_required([:user_id, :action_type, :items_affected])
    |> validate_inclusion(:action_type, @valid_action_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:source_system_id)
    |> foreign_key_constraint(:target_system_id)
  end
end
