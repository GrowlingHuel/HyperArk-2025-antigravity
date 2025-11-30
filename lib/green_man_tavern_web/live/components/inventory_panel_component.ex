defmodule GreenManTavernWeb.InventoryPanelComponent do
  use GreenManTavernWeb, :live_component
  alias GreenManTavern.Inventory

  @impl true
  def update(assigns, socket) do
    # Load inventory data if we have a current user
    socket =
      if assigns[:current_user] do
        user_id = assigns.current_user.id
        items = Inventory.list_inventory_items(user_id)
        category_counts = Inventory.count_by_category(user_id)

        socket
        |> assign(assigns)
        |> assign(:inventory_items, items)
        |> assign(:inventory_category_counts, category_counts)
        |> assign_new(:selected_category, fn -> "all" end)
        |> assign_new(:selected_item, fn -> nil end)
        |> assign_new(:show_add_form, fn -> false end)
      else
        socket
        |> assign(assigns)
        |> assign(:inventory_items, [])
        |> assign(:inventory_category_counts, %{})
        |> assign(:selected_category, "all")
        |> assign(:selected_item, nil)
        |> assign(:show_add_form, false)
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("select_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  @impl true
  def handle_event("select_item", %{"id" => id}, socket) do
    item = Inventory.get_inventory_item!(String.to_integer(id))
    {:noreply, assign(socket, :selected_item, item)}
  end

  @impl true
  def handle_event("show_add_form", _params, socket) do
    {:noreply, assign(socket, :show_add_form, true)}
  end

  @impl true
  def handle_event("hide_add_form", _params, socket) do
    {:noreply, assign(socket, :show_add_form, false)}
  end

  @impl true
  def handle_event("add_item", %{"item" => item_params}, socket) do
    if socket.assigns[:current_user] do
      user_id = socket.assigns.current_user.id

      case Inventory.create_manual_item(user_id, item_params) do
        {:ok, _item} ->
          # Reload inventory data
          items = Inventory.list_inventory_items(user_id)
          category_counts = Inventory.count_by_category(user_id)

          {:noreply,
           socket
           |> assign(:inventory_items, items)
           |> assign(:inventory_category_counts, category_counts)
           |> assign(:show_add_form, false)
           |> put_flash(:info, "Item added successfully")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to add item")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to add items")}
    end
  end

  @impl true
  def handle_event("delete_item", %{"id" => id}, socket) do
    if socket.assigns[:current_user] do
      item = Inventory.get_inventory_item!(String.to_integer(id))
      user_id = socket.assigns.current_user.id

      case Inventory.delete_inventory_item(item) do
        {:ok, _} ->
          # Reload inventory data
          items = Inventory.list_inventory_items(user_id)
          category_counts = Inventory.count_by_category(user_id)

          {:noreply,
           socket
           |> assign(:inventory_items, items)
           |> assign(:inventory_category_counts, category_counts)
           |> assign(:selected_item, nil)
           |> put_flash(:info, "Item deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete item")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to delete items")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h2 class="text-xl font-bold mb-4">Inventory</h2>

      <!-- Category tabs -->
      <div class="flex gap-2 mb-4">
        <button
          phx-click="select_category"
          phx-value-category="all"
          phx-target={@myself}
          class="px-3 py-2 border-2 border-black bg-white font-mono"
        >
          📦 All ({map_size(@inventory_category_counts)})
        </button>
        <button
          phx-click="select_category"
          phx-value-category="food"
          phx-target={@myself}
          class="px-3 py-2 border-2 border-black bg-[#CCC] font-mono"
        >
          🍃 Food ({Map.get(@inventory_category_counts, "food", 0)})
        </button>
      </div>

      <!-- Empty state or items list -->
      <div class="text-center py-12 font-mono text-gray-500">
        <div class="text-center py-12">
          <div class="font-mono text-4xl mb-2 text-gray-400">§</div>
          <p class="font-mono text-sm text-gray-500 mb-4">No items in inventory</p>
          <button
            phx-click="show_add_form"
            phx-target={@myself}
            class="px-4 py-2 border-2 border-black bg-[#CCC] font-mono text-sm hover:bg-white"
          >
            + Add Manual Item
          </button>

          <%= if @show_add_form do %>
            <div class="mt-2 p-4 border-2 border-black bg-white">
              <h3 class="font-mono text-sm font-bold mb-3">Add Item</h3>
              <.form for={%{}} phx-submit="add_item" phx-target={@myself}>
                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block font-mono text-xs mb-1">Name</label>
                    <input
                      type="text"
                      name="item[name]"
                      required
                      class="w-full px-2 py-1 border border-black font-mono text-sm"
                      placeholder="Basil"
                    />
                  </div>

                  <div>
                    <label class="block font-mono text-xs mb-1">Category</label>
                    <select
                      name="item[category]"
                      required
                      class="w-full px-2 py-1 border border-black font-mono text-sm"
                    >
                      <option value="food">🍃 Food</option>
                      <option value="water">💧 Water</option>
                      <option value="waste">♻️ Waste</option>
                      <option value="energy">⚡ Energy</option>
                    </select>
                  </div>

                  <div>
                    <label class="block font-mono text-xs mb-1">Quantity</label>
                    <input
                      type="number"
                      name="item[quantity]"
                      value="1"
                      min="1"
                      required
                      class="w-full px-2 py-1 border border-black font-mono text-sm"
                    />
                  </div>

                  <div>
                    <label class="block font-mono text-xs mb-1">Notes</label>
                    <input
                      type="text"
                      name="item[notes]"
                      class="w-full px-2 py-1 border border-black font-mono text-sm"
                      placeholder="Optional"
                    />
                  </div>
                </div>

                <div class="flex gap-2 mt-3">
                  <button
                    type="submit"
                    class="flex-1 px-3 py-1 border-2 border-black bg-[#CCC] font-mono text-sm hover:bg-white"
                  >
                    Add
                  </button>
                  <button
                    type="button"
                    phx-click="hide_add_form"
                    phx-target={@myself}
                    class="flex-1 px-3 py-1 border-2 border-black bg-[#DDD] font-mono text-sm hover:bg-white"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
