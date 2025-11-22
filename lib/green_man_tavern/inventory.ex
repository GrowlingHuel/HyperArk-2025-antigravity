defmodule GreenManTavern.Inventory do
  @moduledoc """
  The Inventory context - manages user inventory items.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo
  alias GreenManTavern.Inventory.InventoryItem
  alias GreenManTavern.Inventory.ProcessingBatch
  alias GreenManTavern.Inventory.InventoryAction

  @doc """
  Returns the list of inventory items for a user.
  """
  def list_inventory_items(user_id) do
    InventoryItem
    |> where([i], i.user_id == ^user_id)
    |> order_by([i], [asc: i.category, asc: i.name])
    |> Repo.all()
  end

  @doc """
  Returns inventory items for a user filtered by category.
  """
  def list_by_category(user_id, category) do
    InventoryItem
    |> where([i], i.user_id == ^user_id and i.category == ^category)
    |> order_by([i], asc: i.name)
    |> Repo.all()
  end

  @doc """
  Returns inventory items for a user filtered by source type.
  """
  def list_by_source(user_id, source_type) do
    InventoryItem
    |> where([i], i.user_id == ^user_id and i.source_type == ^source_type)
    |> order_by([i], asc: i.name)
    |> Repo.all()
  end

  @doc """
  Gets a single inventory item.
  Raises `Ecto.NoResultsError` if the item does not exist.
  """
  def get_inventory_item!(id), do: Repo.get!(InventoryItem, id)

  @doc """
  Creates an inventory item.
  """
  def create_inventory_item(attrs \\ %{}) do
    %InventoryItem{}
    |> InventoryItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a manually-added inventory item.
  """
  def create_manual_item(user_id, attrs) do
    attrs = Map.put(attrs, :user_id, user_id)

    %InventoryItem{}
    |> InventoryItem.manual_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an inventory item.
  """
  def update_inventory_item(%InventoryItem{} = item, attrs) do
    item
    |> InventoryItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an inventory item.
  """
  def delete_inventory_item(%InventoryItem{} = item) do
    Repo.delete(item)
  end

  @doc """
  Returns the count of inventory items by category for a user.
  """
  def count_by_category(user_id) do
    InventoryItem
    |> where([i], i.user_id == ^user_id)
    |> group_by([i], i.category)
    |> select([i], {i.category, count(i.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Checks if an item from a specific source already exists in inventory.
  """
  def item_exists_from_source?(user_id, source_type, source_id) do
    InventoryItem
    |> where([i], i.user_id == ^user_id)
    |> where([i], i.source_type == ^source_type)
    |> where([i], i.source_id == ^source_id)
    |> Repo.exists?()
  end

  # ========================================
  # PROCESSING BATCHES
  # ========================================

  @doc """
  Lists all active processing batches for a user.
  """
  def list_active_processes(user_id) do
    ProcessingBatch
    |> where([p], p.user_id == ^user_id)
    |> where([p], p.status == "in_progress")
    |> order_by([p], asc: p.complete_at)
    |> Repo.all()
  end

  @doc """
  Creates a new processing batch.
  """
  def create_processing_batch(attrs \\ %{}) do
    %ProcessingBatch{}
    |> ProcessingBatch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Completes a processing batch and creates output items.
  """
  def complete_processing_batch(%ProcessingBatch{} = batch) do
    Repo.transaction(fn ->
      # Update batch status
      batch
      |> ProcessingBatch.changeset(%{status: "complete"})
      |> Repo.update!()

      # Create output items in inventory
      Enum.each(batch.output_items, fn output ->
        create_inventory_item(%{
          user_id: batch.user_id,
          name: output["name"],
          category: output["category"] || "food",
          quantity: output["quantity"],
          source_type: "system",
          source_id: batch.system_id,
          metadata: %{
            created_from_process: batch.id,
            process_type: batch.process_type
          }
        })
      end)

      batch
    end)
  end

  # ========================================
  # INVENTORY ACTIONS
  # ========================================

  @doc """
  Logs an inventory action.
  """
  def log_action(attrs \\ %{}) do
    %InventoryAction{}
    |> InventoryAction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists recent actions for a user.
  """
  def list_recent_actions(user_id, limit \\ 20) do
    InventoryAction
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.performed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets actions by type for a user.
  """
  def list_actions_by_type(user_id, action_type) do
    InventoryAction
    |> where([a], a.user_id == ^user_id)
    |> where([a], a.action_type == ^action_type)
    |> order_by([a], desc: a.performed_at)
    |> Repo.all()
  end
end
