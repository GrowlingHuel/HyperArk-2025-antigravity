defmodule GreenManTavernWeb.DualPanelLive do
  use GreenManTavernWeb, :live_view

  require Logger

  alias Phoenix.PubSub
  alias GreenManTavern.Characters
  alias GreenManTavern.{Conversations, Accounts, Sessions}
  alias GreenManTavern.AI.{OpenAIClient, CharacterContext, SessionProcessor}
  alias GreenManTavern.PlantingGuide
  alias GreenManTavern.PlantingGuide.UserPlant
  alias GreenManTavern.PlantingGuide.Plant
  alias GreenManTavern.Repo
  alias GreenManTavern.Inventory
  alias GreenManTavern.Journal
  alias GreenManTavern.Quests
  alias GreenManTavern.Quests.{QuestGenerator, PlantingQuestManager}


  @pubsub GreenManTavern.PubSub
  @topic "navigation"

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      PubSub.subscribe(@pubsub, @topic)

      # Subscribe to user-specific updates for journal entries and quests
      if current_user do
        Phoenix.PubSub.subscribe(GreenManTavern.PubSub, "user:#{current_user.id}")
      end
    end

    # Generate session_id for this conversation session
    session_id = Sessions.generate_session_id()

    socket =
      socket
      |> assign(:user_id, current_user && current_user.id)
      |> assign(:session_id, session_id)
      |> assign(:left_panel_view, :tavern_home)
      |> assign(:selected_character, nil)
      |> assign(:right_panel_action, :home)
      |> assign(:chat_messages, [])
      |> assign(:character_messages, %{})
      |> assign(:current_message, "")
      |> assign(:is_loading, false)
      |> assign(:characters, Characters.list_characters())


    user_id = if current_user, do: current_user.id, else: nil

    
    # Initialize user_plants (even if empty) - needed for planting guide
    user_plants = if current_user do
      PlantingGuide.list_user_plants(current_user.id)
    else
      []
    end


    socket =
      socket

      |> assign(:user_plants, user_plants || [])
      |> assign(:history_stack, [])  # Undo/redo history
      |> assign(:history_index, -1)  # Current position in history
      |> assign(:max_history, 50)  # Maximum history entries
      |> assign(:inventory_items, [])
      |> assign(:inventory_category_counts, %{})
      |> assign(:inventory_active_processes, [])
      |> assign(:selected_inventory_category, "all")
      |> assign(:selected_inventory_item, nil)
      |> assign(:show_inventory_add_form, false)
      |> assign(:selected_living_web_node, nil)
      |> assign(:show_harvest_panel, false)
      |> assign(:show_opportunities_panel, false)
      |> assign(:opportunities, [])
      |> assign(:projects, [])
      |> assign(:diagram, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Set right panel action from live_action
    action = socket.assigns.live_action || :home

    socket =
      socket
      |> assign(:right_panel_action, action)
      |> assign(:page_title, page_title(action))

    {:noreply, socket}
  end

  @impl true


  @impl true
  def handle_event("select_inventory_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_inventory_category, category)}
  end

  @impl true
  def handle_event("select_inventory_item", %{"id" => id}, socket) do
    item = Inventory.get_inventory_item!(String.to_integer(id))
    {:noreply, assign(socket, :selected_inventory_item, item)}
  end

  @impl true
  def handle_event("show_inventory_add_form", _params, socket) do
    {:noreply, assign(socket, :show_inventory_add_form, true)}
  end

  @impl true
  def handle_event("hide_inventory_add_form", _params, socket) do
    {:noreply, assign(socket, :show_inventory_add_form, false)}
  end

  @impl true
  def handle_event("add_inventory_item", %{"item" => item_params}, socket) do
    user_id = socket.assigns.current_user.id

    params = Map.merge(item_params, %{
      "user_id" => user_id,
      "source_type" => "manual"
    })

    case Inventory.create_inventory_item(params) do
      {:ok, _item} ->
        items = Inventory.list_inventory_items(user_id)
        category_counts = Inventory.count_by_category(user_id)

        {:noreply,
         socket
         |> assign(:inventory_items, items)
         |> assign(:inventory_category_counts, category_counts)
         |> assign(:show_inventory_add_form, false)
         |> put_flash(:info, "Item added successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add item")}
    end
  end

  @impl true
  def handle_event("delete_inventory_item", %{"id" => id}, socket) do
    item = Inventory.get_inventory_item!(String.to_integer(id))
    user_id = socket.assigns.current_user.id

    case Inventory.delete_inventory_item(item) do
      {:ok, _} ->
        items = Inventory.list_inventory_items(user_id)
        category_counts = Inventory.count_by_category(user_id)

        {:noreply,
         socket
         |> assign(:inventory_items, items)
         |> assign(:inventory_category_counts, category_counts)
         |> assign(:selected_inventory_item, nil)
         |> put_flash(:info, "Item deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete item")}
    end
  end

  @impl true
  def handle_event("node_selected", %{"node_id" => node_id, "node_type" => node_type, "node_label" => label}, socket) do
    IO.puts("Node selected: #{node_id} (#{node_type}) - #{label}")

    # Check if this node is linked to real data
    diagram = socket.assigns[:diagram]
    nodes = if diagram, do: diagram.nodes || %{}, else: %{}
    node_data = Map.get(nodes, node_id)

    linked_data = case node_data do
      %{"data" => %{"linked_type" => "user_plant", "linked_id" => plant_id}} when not is_nil(plant_id) ->
        # Load the actual plant data
        case PlantingGuide.get_user_plant(socket.assigns.current_user.id, plant_id) do
          nil -> nil
          user_plant ->
            plant = PlantingGuide.get_plant!(user_plant.plant_id)
            %{type: "plant", user_plant: user_plant, plant: plant}
        end

      _ -> nil
    end

    socket = socket
    |> assign(:selected_living_web_node, %{
      id: node_id,
      type: node_type,
      label: label,
      linked_data: linked_data
    })
    |> assign(:show_harvest_panel, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_harvest_panel", _params, socket) do
    socket = socket
    |> assign(:show_harvest_panel, false)
    |> assign(:selected_living_web_node, nil)

    {:noreply, socket}
  end

  @impl true
  # LEFT WINDOW: Character selection should only affect left-side chat state.
  # - Loads character, conversation history, and clears input
  # - DOES NOT touch right window state (current page or page_data)
  def handle_event("select_character", %{"character_slug" => slug}, socket) do
    require Logger
    alias GreenManTavern.Sessions

    Logger.info("="<>String.duplicate("=", 70))
    Logger.info("[DualPanel] select_character event START")
    Logger.info("[DualPanel] Received slug: #{slug}")
    Logger.info("[DualPanel] Current left_panel_view: #{inspect(socket.assigns[:left_panel_view])}")
    Logger.info("[DualPanel] Current right_panel_action: #{inspect(socket.assigns[:right_panel_action])}")
    Logger.info("[DualPanel] Current selected_character: #{inspect(socket.assigns[:selected_character] && socket.assigns[:selected_character].name)}")

    case Characters.get_character_by_slug(slug) do
      nil ->
        Logger.warning("[DualPanel] Character not found for slug: #{slug}")
        {:noreply, socket}

      character ->
        Logger.info("[DualPanel] Found character: #{character.name} (ID: #{character.id})")
        user_id = socket.assigns.user_id

        # STEP 1: Process OLD session if switching away from another character
        if socket.assigns[:selected_character] && socket.assigns[:session_id] && socket.assigns[:current_user] do
          Logger.info("[DualPanel] 📝 User switching characters - processing current session...")

          # Convert session_id to string (it might be a UUID struct from Ecto)
          current_session_id =
            case socket.assigns.session_id do
              %{__struct__: Ecto.UUID} = uuid -> Ecto.UUID.cast!(uuid)
              id when is_binary(id) -> id
              other -> to_string(other)
            end
          current_user_id = socket.assigns.current_user.id

          Logger.info("[DualPanel] Processing session_id: #{inspect(current_session_id)}")

          Task.start(fn ->
            process_session_end(current_session_id, current_user_id)
          end)
        end

        # STEP 2: Generate NEW session_id for the new character conversation
        # ALWAYS generate a new session_id, even if it's the first character selection
        new_session_id = Sessions.generate_session_id()
        Logger.info("[DualPanel] 🆕 Generated new session_id: #{inspect(new_session_id)}")
        Logger.info("[DualPanel] 🆕 Starting new session: #{new_session_id} for character: #{character.name}")

        # Store current messages for current character before switching
        # This preserves any unsaved messages when switching between characters
        current_character = socket.assigns[:selected_character]
        current_messages = socket.assigns[:chat_messages] || []

        # Maintain a map of character_id -> messages to preserve all conversations
        character_messages = socket.assigns[:character_messages] || %{}

        # If we're switching away from a character, save their current messages
        updated_character_messages =
          if current_character && current_messages != [] do
            Map.put(character_messages, current_character.id, current_messages)
          else
            character_messages
          end

        # Check if we have cached messages for this character
        messages =
          case Map.get(updated_character_messages, character.id) do
            nil ->
              Logger.info("[DualPanel] No cached messages, loading from DB")
              # No cached messages - load from database
              if user_id && character do
                db_messages =
                  Conversations.get_recent_conversation(user_id, character.id, 20)
                  |> Enum.reverse()
                  |> Enum.map(fn conv ->
                    %{
                      id: conv.id,
                      type: String.to_atom(conv.message_type),
                      content: conv.message_content,
                      timestamp: conv.inserted_at
                    }
                  end)
                Logger.info("[DualPanel] Loaded #{length(db_messages)} messages from DB")
                # Cache the loaded messages
                Map.put(updated_character_messages, character.id, db_messages)
                db_messages
              else
                Logger.warning("[DualPanel] No user_id or character for loading messages")
                []
              end

            cached_messages ->
              Logger.info("[DualPanel] Using #{length(cached_messages)} cached messages")
              # Use cached messages (may include unsaved ones from socket)
              cached_messages
          end

        # CRITICAL: Preserve right panel state - do NOT change right_panel_action
        current_right_action = socket.assigns[:right_panel_action] || :home
        Logger.info("[DualPanel] BEFORE assign - right_panel_action: #{inspect(current_right_action)}")

        # STEP 3: Assign new session_id to socket BEFORE returning
        new_socket = socket
         |> assign(:selected_character, character)
         |> assign(:left_panel_view, :character_chat)
         |> assign(:chat_messages, messages)
         |> assign(:character_messages, updated_character_messages)
         |> assign(:current_message, "")
         |> assign(:right_panel_action, current_right_action)
         |> assign(:session_id, new_session_id)  # CRITICAL: Assign new session_id here

        Logger.info("[DualPanel] AFTER assign - left_panel_view: #{inspect(new_socket.assigns.left_panel_view)}")
        Logger.info("[DualPanel] AFTER assign - right_panel_action: #{inspect(new_socket.assigns.right_panel_action)}")
        Logger.info("[DualPanel] AFTER assign - selected_character: #{inspect(new_socket.assigns.selected_character.name)}")
        Logger.info("[DualPanel] 🔍 Socket now has session_id: #{inspect(new_socket.assigns[:session_id])}")
        Logger.info("[DualPanel] AFTER assign - session_id: #{inspect(new_socket.assigns.session_id)}")
        Logger.info("[DualPanel] select_character event END")
        Logger.info("="<>String.duplicate("=", 70))

        {:noreply, new_socket}
    end
  end

  @impl true
  def handle_event("show_tavern_home", _params, socket) do
    require Logger

    # Process current session before leaving character
    if socket.assigns[:selected_character] && socket.assigns[:session_id] && socket.assigns[:current_user] do
      Logger.info("[DualPanel] 📝 User returning to tavern - processing session...")

      # Convert session_id to string (it might be a UUID struct from Ecto)
      current_session_id =
        case socket.assigns.session_id do
          %{__struct__: Ecto.UUID} = uuid -> Ecto.UUID.cast!(uuid)
          id when is_binary(id) -> id
          other -> to_string(other)
        end
      user_id = socket.assigns.current_user.id

      Logger.info("[DualPanel] Processing session_id: #{inspect(current_session_id)}")

      Task.start(fn ->
        process_session_end(current_session_id, user_id)
      end)

      # Clear session_id since we're leaving character conversation
      socket = assign(socket, :session_id, nil)
      socket = assign(socket, :selected_character, nil)
    end

    socket =
      socket
      |> assign(:left_panel_view, :tavern_home)
      |> assign(:selected_character, nil)

    {:noreply, socket}
  end

  # LEFT WINDOW CLEAR ONLY: HyperArk click clears chat state, preserves right page.
  def handle_event("navigate", %{"page" => "hyperark"}, socket) do
    {:noreply,
     socket
     |> assign(:selected_character, nil)
     |> assign(:chat_messages, [])
     |> assign(:current_message, "")
     |> assign(:left_panel_view, :tavern_home)}
  end

  @impl true
  # RIGHT WINDOW: Page navigation should only affect right-side page state.
  # - Changes current page (:living_web | :database | :garden)
  # - Loads page-specific data into :page_data
  # - DOES NOT touch left window chat state
  def handle_event("navigate", %{"page" => "journal"}, socket) do
    require Logger

    # Process current session before navigating to journal
    if socket.assigns[:selected_character] && socket.assigns[:session_id] && socket.assigns[:current_user] do
      Logger.info("[DualPanel] 📝 User navigating to journal - processing session...")

      # Convert session_id to string (it might be a UUID struct from Ecto)
      current_session_id =
        case socket.assigns.session_id do
          %{__struct__: Ecto.UUID} = uuid -> Ecto.UUID.cast!(uuid)
          id when is_binary(id) -> id
          other -> to_string(other)
        end
      user_id = socket.assigns.current_user.id

      Logger.info("[DualPanel] Processing session_id: #{inspect(current_session_id)}")

      Task.start(fn ->
        process_session_end(current_session_id, user_id)
      end)
    end

    # Ensure all journal-related assigns are properly initialized
    user_id = if socket.assigns[:current_user], do: socket.assigns.current_user.id, else: nil

    socket =
      socket
      |> assign(:right_panel_action, :journal)
      |> assign(:journal_entries, if(user_id, do: Journal.list_entries(user_id, limit: 1000), else: []))
      |> assign(:journal_current_page, socket.assigns[:journal_current_page] || 1)
      |> assign(:journal_entries_per_page, socket.assigns[:journal_entries_per_page] || 15)
      |> assign(:journal_has_overflow, socket.assigns[:journal_has_overflow] || false)
      |> assign(:journal_show_hidden, socket.assigns[:journal_show_hidden] || false)
      |> assign(:journal_search_term, socket.assigns[:journal_search_term] || "")
      |> assign(:characters, socket.assigns[:characters] || Characters.list_characters())

    {:noreply, socket}
  end

  def handle_event("navigate", %{"page" => page}, socket) do
    page_atom =
      case page do
        "living_web" -> :living_web
        "database" -> :database
        "garden" -> :garden
        "planting_guide" -> :planting_guide
        "hyperark" -> :hyperark
        other -> String.to_existing_atom(other)
      end

    page_data =
      case page_atom do
        :living_web -> %{projects: socket.assigns[:projects], diagram: socket.assigns[:diagram]}
        :database -> %{}
        :garden -> %{}
        :planting_guide ->
          # Initialize planting guide data
          # Initialize user_plants (even if empty) - MUST be before any filtering
          user_plants = if socket.assigns[:current_user] do
            PlantingGuide.list_user_plants(socket.assigns.current_user.id)
          else
            []
          end

          koppen_zones = PlantingGuide.list_koppen_zones()
          cities = PlantingGuide.list_cities()
          plants = PlantingGuide.list_plants()
          cities_with_frost_dates = PlantingGuide.list_cities_with_frost_dates()
          current_year = Date.utc_today().year
          calendars = generate_all_calendars(current_year)

          # Try to get user's default city from their user_plants
          default_city_id = if socket.assigns[:current_user] do
            PlantingGuide.get_user_default_city_id(socket.assigns.current_user.id)
          else
            nil
          end

          # If we found a default city, verify it exists in the cities list and set it up
          {default_city_id, default_city, default_climate_zone, default_frost_dates} =
            if default_city_id do
              case Enum.find(cities, fn c -> c.id == default_city_id end) do
                nil ->
                  # City not found in list (shouldn't happen, but be safe)
                  {nil, nil, nil, nil}
                city ->
                  # City found - set it up
                  frost_dates = PlantingGuide.get_frost_dates(city.id)
                  {city.id, city, city.koppen_code, frost_dates}
              end
            else
              {nil, nil, nil, nil}
            end

          %{
            koppen_zones: koppen_zones,
            cities: cities,
            all_plants: plants,
            filtered_plants: plants,
            cities_with_frost_dates: cities_with_frost_dates,
            calendars: calendars,
            current_year: current_year,
            selected_city_id: default_city_id,
            selected_city: default_city,
            selected_climate_zone: default_climate_zone,
            selected_month: nil,
            selected_day: if(default_city_id, do: Date.utc_today(), else: nil),  # Default to today if city is selected
            selected_day_range_start: nil,
            selected_day_range_end: nil,
            selected_plant_type: "all",
            selected_difficulty: "all",
            selected_plant: nil,
            companion_plants: %{good: [], bad: []},
            city_frost_dates: default_frost_dates,
            planting_calculation: nil,
            filter_companion_group: false,
            selected_plant_group_id: nil
          }
        _ -> %{}
      end

    socket =
      socket
      |> assign(:right_panel_action, page_atom)
      |> assign(:page_data, page_data)

    # Load user plants if navigating to planting guide
    socket =
      if page_atom == :planting_guide do
        # Initialize user_plants (even if empty) - MUST exist before filtering
        user_plants = if socket.assigns[:current_user] do
          PlantingGuide.list_user_plants(socket.assigns.current_user.id)
        else
          []
        end

        socket = socket
        |> assign(:user_plants, user_plants || [])
        |> assign(:planting_method, :seeds)

        # If we have a default city from user_plants, filter plants accordingly
        page_data = socket.assigns[:page_data] || %{}
        if page_data[:selected_city_id] do
          filter_planting_guide_plants(socket)
        else
          socket
        end
      else
        assign(socket, :user_plants, [])
      end

    {:noreply, socket}
  end

  # ======================
  # Planting Guide Event Handlers
  # ======================

  @impl true
  def handle_event("select_city", %{"city_id" => city_id_str}, socket) do
    city_id = String.to_integer(city_id_str)
    city = PlantingGuide.get_city!(city_id)

    # Get frost dates if available
    frost_dates = PlantingGuide.get_frost_dates(city_id)

    page_data = socket.assigns.page_data || %{}

    # IMPORTANT: Preserve existing selections (month, plant_type, difficulty) when updating city - check both atom and string keys
    existing_month = page_data[:selected_month] || page_data["selected_month"]
    existing_day = page_data[:selected_day] || page_data["selected_day"]
    existing_day_range_start = page_data[:selected_day_range_start] || page_data["selected_day_range_start"]
    existing_day_range_end = page_data[:selected_day_range_end] || page_data["selected_day_range_end"]
    existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
    existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

    Logger.info("select_city event: city_id=#{city_id}, city_name=#{city.city_name}, hemisphere=#{city.hemisphere}, preserving month=#{inspect(existing_month)}, plant_type=#{existing_plant_type}, difficulty=#{existing_difficulty}")

    # Default to today's date if no date/range/month is selected
    default_day = if existing_day || existing_day_range_start || existing_month, do: nil, else: Date.utc_today()

    # Update page_data with selected city (store both ID and struct for compatibility)
    page_data =
      page_data
      |> Map.put(:selected_city_id, city_id)
      |> Map.put(:selected_city, city)
      |> Map.put(:selected_climate_zone, city.koppen_code)
      |> Map.put(:city_frost_dates, frost_dates)
      |> Map.put(:selected_month, existing_month)  # Preserve month!
      |> Map.put(:selected_plant_type, existing_plant_type)  # Preserve plant type!
      |> Map.put(:selected_difficulty, existing_difficulty)  # Preserve difficulty!
      |> Map.put(:selected_day, existing_day || default_day)  # Preserve existing day or default to today
      |> Map.put(:selected_day_range_start, existing_day_range_start)  # Preserve range start
      |> Map.put(:selected_day_range_end, existing_day_range_end)  # Preserve range end
      |> Map.put(:planting_calculation, nil)  # Clear previous calculation

    Logger.info("After city selection: selected_city_id=#{page_data[:selected_city_id]}, selected_city=#{inspect(page_data[:selected_city] && page_data[:selected_city].city_name)}, selected_month=#{inspect(page_data[:selected_month])}")

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_month", params, socket) do
    page_data = socket.assigns.page_data || %{}

    # Extract month from params (handles both dropdown and button clicks)
    month = Map.get(params, "month", "") |> String.trim()

    # If empty string, clear the selection
    month = if month == "", do: nil, else: month

    # Log the current state BEFORE updating
    current_city = page_data[:selected_city]
    current_city_id = page_data[:selected_city_id]
    Logger.info("select_month event: month=#{inspect(month)}, current city=#{inspect(current_city && current_city.city_name)}, current city_id=#{inspect(current_city_id)}, page_data keys=#{inspect(Map.keys(page_data))}")

    # IMPORTANT: Preserve ALL existing selections when updating month
    # Preserve city_id, city struct, climate_zone, etc.
    page_data = cond do
      # Case 1: We have city_id but city struct is missing - reload it
      current_city_id && is_nil(current_city) ->
        try do
          city = PlantingGuide.get_city!(current_city_id)
          Logger.info("Reloaded city from ID: #{city.city_name}")
          page_data
          |> Map.put(:selected_city, city)
          |> Map.put(:selected_climate_zone, city.koppen_code)
          |> Map.put(:selected_month, month)
        rescue
          e ->
            Logger.warn("Failed to reload city from ID: #{current_city_id}, error: #{inspect(e)}")
            Map.put(page_data, :selected_month, month)
        end

      # Case 2: We have both city_id and city struct - preserve everything, just update month
      current_city_id && current_city ->
        Logger.info("Preserving existing city selection: #{current_city.city_name}")
        Map.put(page_data, :selected_month, month)

      # Case 3: Neither exists - just update month
      true ->
        Logger.info("No city selected, just updating month")
        Map.put(page_data, :selected_month, month)
    end

    # Verify city is still there after update
    Logger.info("After month update: selected_city_id=#{inspect(page_data[:selected_city_id])}, selected_city=#{inspect(page_data[:selected_city] && page_data[:selected_city].city_name)}")

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    final_page_data = socket.assigns.page_data
    Logger.info("After filtering: filtered_plants count=#{length(final_page_data[:filtered_plants] || [])}, selected_city=#{inspect(final_page_data[:selected_city] && final_page_data[:selected_city].city_name)}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_plant_type", %{"type" => type}, socket) do
    page_data = socket.assigns.page_data || %{}

    # Preserve existing selections (city, date, difficulty) - check both atom and string keys
    existing_city_id = page_data[:selected_city_id] || page_data["selected_city_id"]
    existing_city = page_data[:selected_city] || page_data["selected_city"]
    existing_day = page_data[:selected_day] || page_data["selected_day"]
    existing_day_range_start = page_data[:selected_day_range_start] || page_data["selected_day_range_start"]
    existing_day_range_end = page_data[:selected_day_range_end] || page_data["selected_day_range_end"]
    existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

    Logger.info("select_plant_type event: type=#{type}, existing_city_id=#{inspect(existing_city_id)}, existing_difficulty=#{existing_difficulty}, current page_data keys=#{inspect(Map.keys(page_data))}")

    # Update page_data with selected plant type (always use atom keys)
    page_data =
      page_data
      |> Map.put(:selected_plant_type, type)
      |> Map.put(:selected_city_id, existing_city_id)
      |> Map.put(:selected_city, existing_city)
      |> Map.put(:selected_day, existing_day)
      |> Map.put(:selected_day_range_start, existing_day_range_start)
      |> Map.put(:selected_day_range_end, existing_day_range_end)
      |> Map.put(:selected_difficulty, existing_difficulty)

    Logger.info("After select_plant_type update: selected_plant_type=#{inspect(page_data[:selected_plant_type])}, selected_difficulty=#{inspect(page_data[:selected_difficulty])}")

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("ignore", _params, socket) do
    # Ignore form submission events that we don't want to handle
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_day_with_shift", params, socket) do
    # Handle shift-click via pushEvent from hook
    handle_event("select_day", Map.put(params, "shift_key", "true"), socket)
  end

  @impl true
  def handle_event("select_day", params, socket) do
    page_data = socket.assigns.page_data || %{}

    year = String.to_integer(params["year"])
    month = String.to_integer(params["month"])
    day = String.to_integer(params["day"])

    clicked_date = Date.new!(year, month, day)

    # Get shift key state from data attribute (set by CalendarDayHook)
    # We need to read it via push_event or check the DOM
    # For now, use a simpler approach: push event with shift key info
    # Actually, let's use the simpler logic that was working before

    range_start = page_data[:selected_day_range_start]
    range_end = page_data[:selected_day_range_end]
    selected_day = page_data[:selected_day]

    # Check if shift key was pressed (from data attribute via JavaScript)
    # We'll read it from push_event or check params
    # For now, let's restore the working behavior:
    # - Click = single day or convert to range
    # - Shift-click = always start/complete range

    # Try to get shift key from params (if sent via pushEvent)
    shift_key = params["shift_key"] == "true" || params["shift_key"] == true

    cond do
      # Shift-click with single day selected - create range
      shift_key && selected_day && !range_start ->
        {actual_start, actual_end} = if Date.compare(selected_day, clicked_date) == :gt do
          {clicked_date, selected_day}
        else
          {selected_day, clicked_date}
        end

        Logger.info("Shift-click: Creating range: #{Date.to_string(actual_start)} to #{Date.to_string(actual_end)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day_range_start, actual_start)
          |> Map.put(:selected_day_range_end, actual_end)
          |> Map.put(:selected_day, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        socket =
          socket
          |> assign(:page_data, page_data)
          |> filter_planting_guide_plants()

        {:noreply, socket}

      # Shift-click with range start - complete range
      shift_key && range_start && !range_end ->
        {actual_start, actual_end} = if Date.compare(range_start, clicked_date) == :gt do
          {clicked_date, range_start}
        else
          {range_start, clicked_date}
        end

        Logger.info("Shift-click: Completing range: #{Date.to_string(actual_start)} to #{Date.to_string(actual_end)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day_range_start, actual_start)
          |> Map.put(:selected_day_range_end, actual_end)
          |> Map.put(:selected_day, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        socket =
          socket
          |> assign(:page_data, page_data)
          |> filter_planting_guide_plants()

        {:noreply, socket}

      # Shift-click with no selection - start range
      shift_key && !selected_day && !range_start ->
        Logger.info("Shift-click: Starting range: #{Date.to_string(clicked_date)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day_range_start, clicked_date)
          |> Map.put(:selected_day_range_end, nil)
          |> Map.put(:selected_day, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        {:noreply, assign(socket, :page_data, page_data)}

      # Regular click: We have a range start but no end - complete the range
      range_start && !range_end && !shift_key ->
        {actual_start, actual_end} = if Date.compare(range_start, clicked_date) == :gt do
          {clicked_date, range_start}
        else
          {range_start, clicked_date}
        end

        Logger.info("Completing range: #{Date.to_string(actual_start)} to #{Date.to_string(actual_end)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day_range_start, actual_start)
          |> Map.put(:selected_day_range_end, actual_end)
          |> Map.put(:selected_day, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        socket =
          socket
          |> assign(:page_data, page_data)
          |> filter_planting_guide_plants()

        {:noreply, socket}

      # Regular click: We have a single day selected - convert to range
      selected_day && !range_start && !shift_key ->
        {actual_start, actual_end} = if Date.compare(selected_day, clicked_date) == :gt do
          {clicked_date, selected_day}
        else
          {selected_day, clicked_date}
        end

        Logger.info("Converting single day to range: #{Date.to_string(actual_start)} to #{Date.to_string(actual_end)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day_range_start, actual_start)
          |> Map.put(:selected_day_range_end, actual_end)
          |> Map.put(:selected_day, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        socket =
          socket
          |> assign(:page_data, page_data)
          |> filter_planting_guide_plants()

        {:noreply, socket}

      # Regular click: No selection - select single day
      true ->
        Logger.info("Selecting single day: #{Date.to_string(clicked_date)}")

        # Preserve existing filters - check both atom and string keys
        existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
        existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

        page_data =
          page_data
          |> Map.put(:selected_day, clicked_date)
          |> Map.put(:selected_day_range_start, nil)
          |> Map.put(:selected_day_range_end, nil)
          |> Map.put(:selected_month, nil)
          |> Map.put(:selected_plant_type, existing_plant_type)
          |> Map.put(:selected_difficulty, existing_difficulty)

        socket =
          socket
          |> assign(:page_data, page_data)
          |> filter_planting_guide_plants()

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_day_selection", _params, socket) do
    page_data = socket.assigns.page_data || %{}

    # Preserve existing filters - check both atom and string keys
    existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")
    existing_difficulty = (page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all")

    page_data =
      page_data
      |> Map.put(:selected_day, nil)
      |> Map.put(:selected_day_range_start, nil)
      |> Map.put(:selected_day_range_end, nil)
      |> Map.put(:selected_plant_type, existing_plant_type)
      |> Map.put(:selected_difficulty, existing_difficulty)

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_difficulty", %{"difficulty" => difficulty}, socket) do
    page_data = socket.assigns.page_data || %{}

    # Preserve existing selections (city, date, plant_type) - check both atom and string keys
    existing_city_id = page_data[:selected_city_id] || page_data["selected_city_id"]
    existing_city = page_data[:selected_city] || page_data["selected_city"]
    existing_day = page_data[:selected_day] || page_data["selected_day"]
    existing_day_range_start = page_data[:selected_day_range_start] || page_data["selected_day_range_start"]
    existing_day_range_end = page_data[:selected_day_range_end] || page_data["selected_day_range_end"]
    existing_plant_type = (page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all")

    Logger.info("select_difficulty event: difficulty=#{difficulty}, existing_city_id=#{inspect(existing_city_id)}, existing_plant_type=#{existing_plant_type}, current page_data keys=#{inspect(Map.keys(page_data))}")

    # Update page_data with selected difficulty (always use atom keys)
    page_data =
      page_data
      |> Map.put(:selected_difficulty, difficulty)
      |> Map.put(:selected_city_id, existing_city_id)
      |> Map.put(:selected_city, existing_city)
      |> Map.put(:selected_day, existing_day)
      |> Map.put(:selected_day_range_start, existing_day_range_start)
      |> Map.put(:selected_day_range_end, existing_day_range_end)
      |> Map.put(:selected_plant_type, existing_plant_type)

    Logger.info("After select_difficulty update: selected_plant_type=#{inspect(page_data[:selected_plant_type])}, selected_difficulty=#{inspect(page_data[:selected_difficulty])}")

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_plant_details", %{"plant_id" => plant_id_str}, socket) do
    plant_id = String.to_integer(plant_id_str)
    plant = PlantingGuide.get_plant!(plant_id)

    # Fetch good and bad companions
    good_companions = PlantingGuide.get_companions(plant_id, "good")
    bad_companions = PlantingGuide.get_companions(plant_id, "bad")

    companion_plants = %{
      good: good_companions,
      bad: bad_companions
    }

    page_data = socket.assigns.page_data

    # Calculate precise planting dates if city with frost data is selected
    planting_calculation =
      if page_data[:selected_city] && page_data[:city_frost_dates] do
        city_id = page_data.selected_city.id
        PlantingGuide.calculate_planting_date(city_id, plant_id)
      else
        nil
      end

    # Get the plant's companion group ID (from filtered plants if available, or compute it)
    companion_group_id =
      case Enum.find(page_data[:filtered_plants] || [], &(&1.id == plant.id)) do
        nil -> nil
        filtered_plant -> Map.get(filtered_plant, :companion_group_id)
      end

    # Get user_plant if user is logged in, preload plant association
    user_plant = if socket.assigns[:current_user] do
      case PlantingGuide.get_user_plant(socket.assigns.current_user.id, plant_id) do
        nil -> nil
        up -> PlantingGuide.preload_plant(up)
      end
    else
      nil
    end

    # Update page_data with selected plant, companions, planting calculation, and user_plant
    page_data =
      page_data
      |> Map.put(:selected_plant, plant)
      |> Map.put(:companion_plants, companion_plants)
      |> Map.put(:planting_calculation, planting_calculation)
      |> Map.put(:selected_plant_group_id, companion_group_id)
      |> Map.put(:selected_user_plant, user_plant)
      # Don't change filter_companion_group when viewing details - keep existing state

    {:noreply, assign(socket, :page_data, page_data)}
  end

  @impl true
  def handle_event("clear_plant_details", _params, socket) do
    page_data = socket.assigns.page_data

    # Clear selected plant and companions, but keep companion group filter state
    page_data =
      page_data
      |> Map.put(:selected_plant, nil)
      |> Map.put(:companion_plants, %{good: [], bad: []})
      |> Map.put(:selected_plant_group_id, nil)
      |> Map.put(:selected_user_plant, nil)

    socket =
      socket
      |> assign(:page_data, page_data)
      |> assign(:editing_harvest_date, false)
      |> assign(:editing_plant_id, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_companion_group", _params, socket) do
    page_data = socket.assigns.page_data

    # Enable companion group filter
    page_data = Map.put(page_data, :filter_companion_group, true)

    socket = assign(socket, :page_data, page_data)

    # Re-filter plants to show only companion group
    socket = filter_planting_guide_plants(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_all", _params, socket) do
    page_data = socket.assigns.page_data

    # Disable companion group filter
    page_data = Map.put(page_data, :filter_companion_group, false)

    socket = assign(socket, :page_data, page_data)

    # Re-filter plants to show all
    socket = filter_planting_guide_plants(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_planting_method", %{"method" => method}, socket) do
    method_atom =
      case method do
        "seeds" -> :seeds
        "seedlings" -> :seedlings
        _ -> :seeds # Default to seeds if invalid
      end

    socket =
      socket
      |> assign(:planting_method, method_atom)
      |> filter_planting_guide_plants() # Re-filter with new method

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_harvest_date", %{"plant-id" => plant_id_str}, socket) do
    plant_id = String.to_integer(plant_id_str)
    {:noreply, assign(socket, editing_harvest_date: true, editing_plant_id: plant_id)}
  end

  @impl true
  def handle_event("save_harvest_override", %{"plant-id" => plant_id_str} = params, socket) do
    require Logger

    unless socket.assigns[:current_user] do
      {:noreply, put_flash(socket, :error, "Please log in to edit harvest dates")}
    else
      plant_id = String.to_integer(plant_id_str)
      user = socket.assigns.current_user

      # Get the date value from params
      date_string = Map.get(params, "harvest_date_override") || Map.get(params, "value")

      if date_string && date_string != "" do
        case Date.from_iso8601(date_string) do
          {:ok, override_date} ->
            # Get user_plant
            case PlantingGuide.get_user_plant(user.id, plant_id) do
              nil ->
                {:noreply, put_flash(socket, :error, "Plant not found in your garden")}

              user_plant ->
                # Update plant with override
                case PlantingGuide.update_user_plant(user_plant, %{harvest_date_override: override_date}) do
                  {:ok, _updated_plant} ->
                    # Reload user plants
                    updated_plants = PlantingGuide.list_user_plants(user.id)

                    # Reload user_plant in page_data if viewing this plant
                    page_data = socket.assigns.page_data
                    updated_page_data = if page_data[:selected_plant] && page_data[:selected_plant].id == plant_id do
                      case PlantingGuide.get_user_plant(user.id, plant_id) do
                        nil -> Map.put(page_data, :selected_user_plant, nil)
                        up -> Map.put(page_data, :selected_user_plant, PlantingGuide.preload_plant(up))
                      end
                    else
                      page_data
                    end

                    socket =
                      socket
                      |> assign(:user_plants, updated_plants)
                      |> assign(:page_data, updated_page_data)
                      |> assign(:editing_harvest_date, false)
                      |> assign(:editing_plant_id, nil)
                      |> put_flash(:info, "Harvest date updated!")

                    {:noreply, socket}

                  {:error, _changeset} ->
                    {:noreply, put_flash(socket, :error, "Could not update harvest date")}
                end
            end

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Invalid date format")}
        end
      else
        # Clear override if empty
        case PlantingGuide.get_user_plant(user.id, plant_id) do
          nil ->
            {:noreply, put_flash(socket, :error, "Plant not found in your garden")}

          user_plant ->
            case PlantingGuide.update_user_plant(user_plant, %{harvest_date_override: nil}) do
              {:ok, _updated_plant} ->
                updated_plants = PlantingGuide.list_user_plants(user.id)

                page_data = socket.assigns.page_data
                updated_page_data = if page_data[:selected_plant] && page_data[:selected_plant].id == plant_id do
                  case PlantingGuide.get_user_plant(user.id, plant_id) do
                    nil -> Map.put(page_data, :selected_user_plant, nil)
                    up -> Map.put(page_data, :selected_user_plant, PlantingGuide.preload_plant(up))
                  end
                else
                  page_data
                end

                socket =
                  socket
                  |> assign(:user_plants, updated_plants)
                  |> assign(:page_data, updated_page_data)
                  |> assign(:editing_harvest_date, false)
                  |> assign(:editing_plant_id, nil)
                  |> put_flash(:info, "Harvest date override cleared!")

                {:noreply, socket}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Could not clear harvest date override")}
            end
        end
      end
    end
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    # Just stop event propagation, no action needed
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_plant_status", %{"plant_id" => plant_id_str, "status" => status} = params, socket) do
    # Check user is logged in
    unless socket.assigns[:current_user] do
      {:noreply, put_flash(socket, :error, "Please log in to track plants")}
    else
      plant_id = String.to_integer(plant_id_str)
      user = socket.assigns.current_user
      # Get selected city and plant
      page_data = socket.assigns.page_data || %{}
      city = page_data[:selected_city] || page_data["selected_city"]
      plant = PlantingGuide.get_plant!(plant_id)

      cond do
        status == "" ->
          # User deselected - delete if exists
          case PlantingGuide.get_user_plant(user.id, plant_id) do
            nil -> {:noreply, socket}
            user_plant ->
              PlantingGuide.delete_user_plant(user_plant)
              updated_plants = PlantingGuide.list_user_plants(user.id)
              {:noreply, assign(socket, :user_plants, updated_plants)}
          end

        true ->
          # User selected a status
          # Get old status before update
          old_user_plant = PlantingGuide.get_user_plant(user.id, plant_id)
          old_status = if old_user_plant, do: old_user_plant.status, else: nil

          # Calculate planting date for quest generation
          planting_date = calculate_planting_start(socket) || calculate_planting_end(socket)

          case old_user_plant do
            nil ->
              # Create new
              attrs = %{
                user_id: user.id,
                plant_id: plant_id,
                city_id: if(city, do: city.id, else: nil),
                status: status,
                planting_date_start: calculate_planting_start(socket),
                planting_date_end: calculate_planting_end(socket),
                planting_method: to_string(socket.assigns[:planting_method] || :seeds)
              }

              case PlantingGuide.create_user_plant(attrs) do
                {:ok, user_plant} ->
                  updated_plants = PlantingGuide.list_user_plants(user.id)

                  # Trigger quest generation/update
                  socket =
                    socket
                    |> assign(:user_plants, updated_plants)
                    |> put_flash(:info, "Added #{plant.common_name} to your garden!")

                  # Handle quest generation after plant creation
                  socket = handle_quest_generation(socket, user.id, plant_id, old_status, status, planting_date)

                  {:noreply, socket}

                {:error, _changeset} ->
                  {:noreply, put_flash(socket, :error, "Could not add plant")}
              end

            user_plant ->
              # Update existing
              case PlantingGuide.update_user_plant(user_plant, %{status: status}) do
                {:ok, updated_plant} ->
                  updated_plants = PlantingGuide.list_user_plants(user.id)

                  socket =
                    socket
                    |> assign(:user_plants, updated_plants)
                    |> put_flash(:info, "Updated #{plant.common_name} status!")

                  # Handle quest generation after plant update
                  socket = handle_quest_generation(socket, user.id, plant_id, old_status, status, planting_date || updated_plant.planting_date_start || updated_plant.planting_date_end)

                  {:noreply, socket}

                {:error, _changeset} ->
                  {:noreply, put_flash(socket, :error, "Could not update status")}
              end
          end
      end
    end
  end

  defp calculate_planting_start(socket) do
    page_data = socket.assigns.page_data || %{}
    selected_day = page_data[:selected_day] || page_data["selected_day"]
    selected_day_range_start = page_data[:selected_day_range_start] || page_data["selected_day_range_start"]
    selected_month = page_data[:selected_month] || page_data["selected_month"]

    cond do
      selected_day ->
        selected_day
      selected_day_range_start ->
        selected_day_range_start
      selected_month ->
        # Convert month name to date (first of that month)
        month_num = month_name_to_number(selected_month)
        Date.new!(Date.utc_today().year, month_num, 1)
      true ->
        Date.utc_today()
    end
  end

  defp calculate_planting_end(socket) do
    start = calculate_planting_start(socket)
    page_data = socket.assigns.page_data || %{}
    selected_day_range_end = page_data[:selected_day_range_end] || page_data["selected_day_range_end"]

    if selected_day_range_end do
      selected_day_range_end
    else
      Date.add(start, 14) # 2-week planting window
    end
  end

  # Handle quest generation after plant status change
  defp handle_quest_generation(socket, user_id, plant_id, old_status, new_status, planting_date) do
    require Logger

    case PlantingQuestManager.handle_plant_status_change(
      user_id,
      plant_id,
      old_status || "interested",
      new_status,
      planting_date
    ) do
      {:ok, quest} ->
        Logger.info("[PlantQuest] ✅ Quest updated: #{quest.title}")

        # Broadcast quest update for real-time UI refresh
        Phoenix.PubSub.broadcast(
          GreenManTavern.PubSub,
          "user:#{user_id}",
          {:quest_updated, user_id}
        )

        # Show success message to user
        put_flash(socket, :info, "Quest updated: #{quest.title}")

      {:ok, :no_action} ->
        # No quest action needed
        socket

      {:error, reason} ->
        Logger.warning("[PlantQuest] ⚠️ Quest update failed: #{inspect(reason)}")
        socket
    end
  end

  defp month_name_to_number(month_name) do
    months = %{
      "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4,
      "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8,
      "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
    }
    Map.get(months, month_name, 1)
  end



  # Chat event handlers
  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    message = String.trim(message || "")
    Logger.info("[DualPanel] 📤 SEND MESSAGE START - session_id from socket: #{inspect(socket.assigns[:session_id])}")
    Logger.info("[DualPanel] send_message event received: '#{message}' (length: #{String.length(message)})")

    if message == "" do
      Logger.warning("[DualPanel] Empty message, ignoring")
      {:noreply, socket}
    else
      Logger.info("[DualPanel] Processing message with send_message helper")
      send_message(socket, message)
    end
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :current_message, message)}
  end

  defp send_message(socket, message) when message in [nil, ""] do
    {:noreply, socket}
  end

  defp send_message(socket, message) do
    user_id = socket.assigns.user_id
    character = socket.assigns.selected_character

    Logger.info("[DualPanel] send_message helper called: user_id=#{inspect(user_id)}, character=#{inspect(character && character.name)}, msg_len=#{String.length(message)}")

    # Add user message to UI
    user_message = %{
      id: System.unique_integer([:positive]),
      type: :user,
      content: message,
      timestamp: DateTime.utc_now()
    }

    current_messages = socket.assigns[:chat_messages] || []
    new_messages = current_messages ++ [user_message]
    Logger.info("[DualPanel] Updated messages list: #{length(current_messages)} -> #{length(new_messages)} messages")

    # Update the character_messages cache to preserve this message when switching characters
    character_messages = socket.assigns[:character_messages] || %{}
    updated_character_messages =
      if character do
        Map.put(character_messages, character.id, new_messages)
      else
        character_messages
      end

    # Update UI with user message and loading state IMMEDIATELY (before any blocking operations)
    updated_socket =
      socket
      |> assign(:chat_messages, new_messages)
      |> assign(:character_messages, updated_character_messages)
      |> assign(:current_message, "")
      |> assign(:is_loading, true)

    Logger.info("[DualPanel] Socket updated with #{length(new_messages)} messages, returning immediately")

    # CRITICAL: Capture LiveView PID and session_id BEFORE starting async task
    liveview_pid = self()
    session_id = socket.assigns[:session_id]
    Logger.info("[DualPanel] 💾 About to save message with session_id: #{inspect(session_id)}")

    # Do all async work in background task (after socket update)
    if user_id && character do
      # Store user message in conversation history and process (async)
      Task.start(fn ->
        alias GreenManTavern.Conversations

        alias GreenManTavern.AI.FactExtractor
        alias GreenManTavern.Accounts
        require Logger

        case Conversations.create_conversation_entry(%{
          user_id: user_id,
          character_id: character.id,
          message_type: "user",
          message_content: message,
          session_id: session_id
        }) do
          {:ok, saved_conv} ->
            Logger.info("[DualPanel] ✅ Message saved to DB with session_id: #{inspect(saved_conv.session_id)}")
            Logger.info("[DualPanel] ✅ Saved user message to conversation_history (ID: #{saved_conv.id})")
            # Journal entries are now created per-session via session-end processing, not per-message

            # Extract and persist facts BEFORE calling OpenAI (so facts are available for context)
            Logger.debug("[DualPanel] Extracting facts from message...")
            case FactExtractor.extract_facts(message, character.name) do
              {:ok, %{facts: facts} = extraction_result} ->
                Logger.debug("[DualPanel] Extracted #{length(facts)} facts")
                Logger.debug("[DualPanel] User question: #{inspect(extraction_result.user_question)}")
                Logger.debug("[DualPanel] Emotional tone: #{inspect(extraction_result.emotional_tone)}")
                Logger.debug("[DualPanel] Commitment level: #{inspect(extraction_result.commitment_level)}")

                # Store enhanced extraction data in conversation_history.extracted_facts
                extracted_facts_data = %{
                  "facts" => facts,
                  "user_question" => extraction_result.user_question,
                  "emotional_tone" => extraction_result.emotional_tone,
                  "commitment_level" => extraction_result.commitment_level
                }

                # Update the saved conversation entry with extracted_facts
                case Conversations.update_conversation_entry(saved_conv, user_id, %{extracted_facts: extracted_facts_data}) do
                  {:ok, _updated} ->
                    Logger.debug("[DualPanel] ✅ Stored enhanced extraction data in conversation_history")
                  {:error, changeset} ->
                    Logger.warning("[DualPanel] ⚠️ Failed to store extracted_facts: #{inspect(changeset.errors)}")
                end

                if length(facts) > 0 do
                  user = Accounts.get_user!(user_id)
                  existing = (user.profile_data || %{})["facts"] || []
                  merged = FactExtractor.merge_facts(existing, facts)
                  new_pd = Map.put(user.profile_data || %{}, "facts", merged)
                  case Accounts.update_user(user, %{profile_data: new_pd}) do
                    {:ok, _updated_user} ->
                      Logger.info("[DualPanel] ✅ Saved #{length(facts)} new facts to user profile (total: #{length(merged)} facts)")
                    {:error, changeset} ->
                      Logger.warning("[DualPanel] ⚠️ Failed to save facts: #{inspect(changeset.errors)}")
                  end
                end

              {:error, reason} ->
                Logger.warning("[DualPanel] ⚠️ Fact extraction failed: #{inspect(reason)}")
            end

            # Now process with OpenAI via OpenRouter (facts are saved)
            # CRITICAL: Send to LiveView PID, not Task PID
            Logger.info("[DualPanel] Queuing AI processing: user_id=#{inspect(user_id)} character=#{inspect(character.name)} msg_len=#{String.length(message)} liveview_pid=#{inspect(liveview_pid)}")
            send(liveview_pid, {:process_with_claude, user_id, character, message})

          {:error, changeset} ->
            Logger.error("[DualPanel] ❌ FAILED to save user message: #{inspect(changeset.errors)}")
            # Still try to process even if save failed
            Logger.info("[DualPanel] Still queuing AI processing despite save failure")
            send(liveview_pid, {:process_with_claude, user_id, character, message})
        end
      end)
    else
      Logger.warning("[DualPanel] ⚠️ Cannot save user message: user_id=#{inspect(user_id)}, character=#{inspect(character && character.id)}")
      # Still try to process even if we can't save
      if user_id && character do
        Logger.info("[DualPanel] Queuing AI processing directly (no save)")
        send(liveview_pid, {:process_with_claude, user_id, character, message})
      end
    end

    # Return socket update immediately so user sees their message
    {:noreply, updated_socket}
  end

  @impl true
  def handle_info({:process_with_claude, user_id, character, message}, socket) do
    require Logger
    alias GreenManTavern.AI.FactExtractor
    alias GreenManTavern.Conversations

    Logger.info("[DualPanel] ✅ handle_info(:process_with_claude) RECEIVED user_id=#{inspect(user_id)} character=#{inspect(character && character.name)} message_len=#{String.length(message)}")
    try do
      api_key = System.get_env("OPENROUTER_API_KEY")
      if is_nil(api_key) or api_key == "" do
        Logger.debug("[DualPanel] Missing OPENROUTER_API_KEY; returning error to UI")
        error_message = %{
          id: System.unique_integer([:positive]),
          type: :error,
          content: "API key not configured. Please set OPENROUTER_API_KEY environment variable.",
          timestamp: DateTime.utc_now()
        }
        new_messages = socket.assigns.chat_messages ++ [error_message]
        {:noreply, socket |> assign(:chat_messages, new_messages) |> assign(:is_loading, false)}
      else
        # Build combined context with user facts + knowledge base
        # Reload user to ensure we have latest facts (fact extraction runs async)
        user = if user_id, do: Accounts.get_user!(user_id), else: nil
        Logger.debug("[DualPanel] Loaded user: present?=#{!!user}")
        if user && user.profile_data do
          facts_count = length(Map.get(user.profile_data, "facts", []))
          Logger.debug("[DualPanel] User has #{facts_count} facts in profile_data")
        end
        Logger.debug("[DualPanel] Loaded character: #{inspect(character)}")
        context = CharacterContext.build_context(user, message, limit: 5)
        Logger.debug("[DualPanel] Context includes facts: #{String.contains?(context || "", "USER PROFILE")}")
        Logger.debug("[DualPanel] Context built: chars=#{String.length(context || "")}\n#{String.slice(context || "", 0, 300)}...")
        system_prompt = CharacterContext.build_system_prompt(character)
        Logger.debug("[DualPanel] System prompt present?=#{system_prompt != nil and String.trim(system_prompt) != ""} len=#{String.length(system_prompt || "")}")

        # Query OpenAI via OpenRouter
        Logger.info("[DualPanel] 🚀 Calling OpenAIClient.chat... msg_len=#{String.length(message)} system_prompt_len=#{String.length(system_prompt || "")} context_len=#{String.length(context || "")}")
        start_time = System.system_time(:millisecond)
        result = OpenAIClient.chat(message, system_prompt, context)
        elapsed = System.system_time(:millisecond) - start_time
        Logger.info("[DualPanel] OpenAIClient result after #{elapsed}ms: #{inspect(result, limit: 200)}")

        case result do
          {:ok, response} ->
            Logger.debug("[DualPanel] Received AI response len=#{String.length(response)}")
            character_response = %{
              id: System.unique_integer([:positive]),
              type: :character,
              content: response,
              timestamp: DateTime.utc_now()
            }

            new_messages = socket.assigns.chat_messages ++ [character_response]

            # Update the character_messages cache to preserve this message when switching characters
            character_messages = socket.assigns[:character_messages] || %{}
            updated_character_messages =
              if character do
                Map.put(character_messages, character.id, new_messages)
              else
                character_messages
              end

            # Store character response in conversation history
            if user_id && character do
              session_id = socket.assigns[:session_id]

              # Extract character_advice from the response
              # Pass empty string as user_message and response as character_response to extract advice
              extracted_facts_data = %{}
              case FactExtractor.extract_facts("", character.name, response) do
                {:ok, extraction_result} ->
                  extracted_facts_data = %{
                    "character_advice" => extraction_result.character_advice,
                    "facts" => extraction_result.facts || []
                  }
                {:error, _reason} ->
                  # Extraction failed, continue without it
                  extracted_facts_data = %{}
              end

              Logger.info("[DualPanel] 💾 About to save character message with session_id: #{inspect(session_id)}")
              case Conversations.create_conversation_entry(%{
                user_id: user_id,
                character_id: character.id,
                message_type: "character",
                message_content: response,
                session_id: session_id,
                extracted_facts: extracted_facts_data
              }) do
                {:ok, saved_conv} ->
                  Logger.info("[DualPanel] ✅ Character message saved to DB with session_id: #{inspect(saved_conv.session_id)}")
                  Logger.info("[DualPanel] ✅ Saved AI response to conversation_history (ID: #{saved_conv.id}, Length: #{String.length(response)} chars)")
                  # Journal entries are now created per-session via session-end processing, not per-message
                {:error, changeset} ->
                  Logger.error("[DualPanel] ❌ FAILED to save AI response: #{inspect(changeset.errors)}")
                  Logger.error("[DualPanel] Response length: #{String.length(response)} chars, user_id: #{inspect(user_id)}, character_id: #{inspect(character && character.id)}")
                  # Try to notify user if save fails (though in async context we can't update socket)
                  Logger.warning("[DualPanel] Character response may not persist after logout/login!")
              end
            else
              Logger.warning("[DualPanel] ⚠️ Cannot save character response: user_id=#{inspect(user_id)}, character=#{inspect(character && character.id)}")
            end

            # Update trust level based on interaction
            if user_id && character do
              update_trust_level(user_id, character.id, message, response)
            end

            {:noreply,
             socket
             |> assign(:chat_messages, new_messages)
             |> assign(:character_messages, updated_character_messages)
             |> assign(:is_loading, false)}

          {:error, reason} ->
            Logger.error("[DualPanel] OpenAIClient (via OpenRouter) error: #{inspect(reason)}")
            error_message = %{
              id: System.unique_integer([:positive]),
              type: :error,
              content: "I apologize, but I'm having trouble responding right now. Error: #{inspect(reason)}",
              timestamp: DateTime.utc_now()
            }

            new_messages = socket.assigns.chat_messages ++ [error_message]

            {:noreply,
             socket
             |> assign(:chat_messages, new_messages)
             |> assign(:is_loading, false)
             |> put_flash(:error, "Failed to get response from character")}
        end
      end
    rescue
      error ->
        Logger.error("[DualPanel] handle_info exception: #{inspect(error)}")
        error_message = %{
          id: System.unique_integer([:positive]),
          type: :error,
          content: "An unexpected error occurred. Please try again.",
          timestamp: DateTime.utc_now()
        }

        new_messages = (socket.assigns.chat_messages || []) ++ [error_message]

        {:noreply,
         socket
         |> assign(:chat_messages, new_messages)
         |> assign(:is_loading, false)}
    end
  end

  defp page_title(:home), do: "Green Man Tavern"
  defp page_title(:living_web), do: "Living Web"
  defp page_title(:journal), do: "Journal & Quests"
  defp page_title(_), do: "Green Man Tavern"

  # Collision detection temporarily disabled
  # defp find_free_position(x, y, existing_nodes, spacing \\ 80) do
  #   %{x: x, y: y}
  # end
  # defp position_occupied?(_x, _y, _nodes, _min_spacing), do: false
  # defp get_position_x(_node), do: 0
  # defp get_position_y(_node), do: 0
  # defp find_spiral_position(x, y, _nodes, _spacing, _attempt), do: %{x: x, y: y}

  # TODO: Helper functions to extract inputs/outputs from project data
  # Projects store inputs/outputs as maps, but we need arrays for port handles

  defp update_trust_level(user_id, character_id, user_message, character_response) do
    # Simple trust calculation based on message length and response quality
    trust_delta = calculate_trust_delta(user_message, character_response)

    # Update user's trust level with this character
    Accounts.update_user_character_trust(user_id, character_id, trust_delta)
  end

  defp calculate_trust_delta(user_message, character_response) do
    message_length = String.length(user_message)
    response_length = String.length(character_response)

    cond do
      message_length > 50 and response_length > 100 -> 0.1
      message_length > 20 and response_length > 50 -> 0.05
      true -> 0.01
    end
  end


  @impl true
  def handle_info({:journal_entry_created, user_id}, socket) do
    if socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_journal)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:journal_updated, user_id}, socket) do
    if socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_journal)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:quest_updated, user_id}, socket) do
    if socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_quests)
    end
    {:noreply, socket}
  end

  # Journal creation handlers






  # ======================
  # Planting Guide Helper Functions
  # ======================

  defp generate_calendar_month(month_number, year) when month_number in 1..12 do
    first_date = Date.new!(year, month_number, 1)
    last_day = Date.end_of_month(first_date)

    month_names = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ]

    days =
      1..last_day.day
      |> Enum.map(fn day ->
        date = Date.new!(year, month_number, day)
        day_of_week = Date.day_of_week(date, :monday) # 1 = Monday, 7 = Sunday
        %{
          day: day,
          date: date,
          day_of_week: day_of_week
        }
      end)

    %{
      month_name: Enum.at(month_names, month_number - 1),
      month_number: month_number,
      year: year,
      days: days,
      first_day_of_week: Date.day_of_week(first_date, :monday)
    }
  end

  defp generate_all_calendars(year \\ nil) do
    year = year || Date.utc_today().year

    1..12
    |> Enum.map(fn month_num ->
      generate_calendar_month(month_num, year)
    end)
  end


  defp month_abbreviation_from_number(month_num) do
    Enum.at(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec), month_num - 1)
  end

  defp date_in_planting_string?(date, months_str, hemisphere) when is_struct(date, Date) and is_binary(months_str) do
    month_abbr = month_abbreviation_from_number(date.month)
    month_in_planting_string?(month_abbr, months_str)
  end

  defp date_in_planting_string?(_, _, _), do: false



  defp date_range_in_planting_string?(start_date, end_date, months_str, hemisphere)
       when is_struct(start_date, Date) and is_struct(end_date, Date) do
    # Generate all dates in the range
    Date.range(start_date, end_date)
    |> Enum.any?(fn date ->
      date_in_planting_string?(date, months_str, hemisphere)
    end)
  end

  defp date_range_in_planting_string?(_, _, _, _), do: false

  """
  Handles formats like:
  - "Sep-Nov" (range: Sep, Oct, Nov all match)
  - "Feb-Apr,Aug-Oct" (multiple ranges)
  - "Sep" (single month)
  """
  defp month_in_planting_string?(month, months_str) when is_binary(month) and is_binary(months_str) do
    if months_str == "" do
      false
    else
      # Split by both comma and slash to get individual ranges/months
      # Formats can be: "Sep-Nov", "Feb-Apr,Aug-Oct", "Mar-May/Aug-Oct", "May/Aug"
      # First normalize slashes to commas (they're both separators)
      normalized = String.replace(months_str, "/", ",")

      normalized
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.any?(fn range_or_month ->
        # Check if it's a range (contains hyphen) or single month
        if String.contains?(range_or_month, "-") do
          # Parse range like "Sep-Nov" or handle edge cases
          parts = String.split(range_or_month, "-") |> Enum.map(&String.trim/1)
          case parts do
            [start_month, end_month] ->
              # Valid range - check if month is in range
              month_in_range?(month, start_month, end_month)
            [single] ->
              # Only one part after splitting - might be a month name
              single == month
            _ ->
              # More than 2 parts - something went wrong, skip this one
              false
          end
        else
          # Single month - exact match
          range_or_month == month
        end
      end)
    end
  end

  defp month_in_planting_string?(_, _), do: false


  defp month_in_range?(month, start_month, end_month) do
    month_order = %{
      "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4,
      "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8,
      "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
    }

    month_num = Map.get(month_order, month)
    start_num = Map.get(month_order, start_month)
    end_num = Map.get(month_order, end_month)

    cond do
      # If all values are valid
      month_num && start_num && end_num ->
        # Handle wrap-around (e.g., "Nov-Jan" means Nov, Dec, Jan)
        if start_num <= end_num do
          # Normal range: start <= month <= end
          month_num >= start_num && month_num <= end_num
        else
          # Wrap-around range: month >= start OR month <= end
          month_num >= start_num || month_num <= end_num
        end

      # If month doesn't exist in order, check exact match
      month == start_month || month == end_month ->
        true

      # Default: no match (invalid month or not in range)
      true ->
        false
    end
  end

  """
  Applies filters in order:
  1. Climate zone (if city selected)
  2. Planting month (if month and city selected)
  3. Plant type
  4. Growing difficulty
  """
  defp filter_planting_guide_plants(socket) do
    page_data = socket.assigns.page_data || %{}
    all_plants = page_data[:all_plants] || page_data["all_plants"] || []

    # Start with all plants
    plants = all_plants

    # Filter by city/climate if selected
    selected_climate_zone = page_data[:selected_climate_zone] || page_data["selected_climate_zone"]
    plants =
      if selected_climate_zone do
        before_count = length(plants)
        filtered = Enum.filter(plants, fn plant ->
          plant_climate_zones = plant.climate_zones || []
          selected_climate_zone in plant_climate_zones
        end)
        after_count = length(filtered)
        Logger.debug("Climate filter: #{before_count} -> #{after_count} plants (zone: #{selected_climate_zone})")
        filtered
      else
        plants
      end

    # Filter by day/range OR month (day/range takes precedence)
    selected_day = page_data[:selected_day]
    selected_day_range_start = page_data[:selected_day_range_start]
    selected_day_range_end = page_data[:selected_day_range_end]
    selected_month = page_data[:selected_month] || page_data["selected_month"]
    selected_city_id = page_data[:selected_city_id] || page_data["selected_city_id"]

    # Try to get city from stored struct, or reload from ID if struct is missing
    selected_city = page_data[:selected_city] || page_data["selected_city"]
    selected_city = if is_nil(selected_city) && selected_city_id do
      Logger.info("City struct missing, reloading from city_id=#{selected_city_id}")
      try do
        PlantingGuide.get_city!(selected_city_id)
      rescue
        _ -> nil
      end
    else
      selected_city
    end

    plants =
      cond do
        # Priority 1: Filter by selected day (single date)
        selected_day && selected_city ->
          hemisphere = selected_city.hemisphere
          Logger.info("Applying day filter: date=#{Date.to_string(selected_day)}, hemisphere=#{hemisphere}")
          before_count = length(plants)
          filtered = Enum.filter(plants, fn plant ->
            months_str = if hemisphere == "Southern" do
              plant.planting_months_sh || ""
            else
              plant.planting_months_nh || ""
            end
            date_in_planting_string?(selected_day, months_str, hemisphere)
          end)
          after_count = length(filtered)
          Logger.info("Day filter result: #{before_count} -> #{after_count} plants")
          filtered

        # Priority 2: Filter by selected day range
        selected_day_range_start && selected_day_range_end && selected_city ->
          hemisphere = selected_city.hemisphere
          Logger.info("Applying day range filter: #{Date.to_string(selected_day_range_start)} to #{Date.to_string(selected_day_range_end)}, hemisphere=#{hemisphere}")
          before_count = length(plants)
          filtered = Enum.filter(plants, fn plant ->
            months_str = if hemisphere == "Southern" do
              plant.planting_months_sh || ""
            else
              plant.planting_months_nh || ""
            end
            date_range_in_planting_string?(selected_day_range_start, selected_day_range_end, months_str, hemisphere)
          end)
          after_count = length(filtered)
          Logger.info("Day range filter result: #{before_count} -> #{after_count} plants")
          filtered

        # Priority 3: Filter by month (fallback to month selection)
        selected_month && selected_city ->
          hemisphere = selected_city.hemisphere
          month = selected_month
          Logger.info("Applying month filter: month=#{month}, hemisphere=#{hemisphere}")
          before_count = length(plants)
          filtered = Enum.filter(plants, fn plant ->
            months_str = if hemisphere == "Southern" do
              plant.planting_months_sh || ""
            else
              plant.planting_months_nh || ""
            end
            month_in_planting_string?(month, months_str)
          end)
          after_count = length(filtered)
          Logger.info("Month filter result: #{before_count} -> #{after_count} plants (month: #{month}, hemisphere: #{hemisphere})")
          filtered

        # No date/month filter applied
        true ->
          Logger.info("No date/month filter: missing date/day_range/month (#{inspect({selected_day, selected_day_range_start, selected_month})}) or city (#{inspect(selected_city_id)})")
          plants
      end

    # Filter by plant type if selected
    selected_plant_type = page_data[:selected_plant_type] || page_data["selected_plant_type"] || "all"
    Logger.info("Plant type filter check: selected_plant_type=#{inspect(selected_plant_type)}, current plants count=#{length(plants)}")
    plants =
      if selected_plant_type != "all" do
        before_count = length(plants)
        filtered = Enum.filter(plants, fn plant ->
          plant_type = plant.plant_type || ""
          # Handle "Native" as a wildcard that matches all "Native *" types
          matches = cond do
            selected_plant_type == "Native" ->
              String.starts_with?(plant_type, "Native")
            true ->
              plant_type == selected_plant_type
          end
          matches
        end)
        after_count = length(filtered)
        Logger.info("Plant type filter: #{before_count} -> #{after_count} plants (type: #{selected_plant_type})")
        filtered
      else
        Logger.info("Plant type filter skipped: type is 'all'")
        plants
      end

    # Filter by growing difficulty if selected
    selected_difficulty = page_data[:selected_difficulty] || page_data["selected_difficulty"] || "all"
    Logger.info("Difficulty filter check: selected_difficulty=#{inspect(selected_difficulty)}, current plants count=#{length(plants)}")
    plants =
      if selected_difficulty != "all" do
        before_count = length(plants)
        filtered = Enum.filter(plants, fn plant ->
          difficulty = plant.growing_difficulty || ""
          matches = difficulty == selected_difficulty
          if !matches do
            Logger.debug("Plant '#{plant.common_name}' difficulty '#{difficulty}' does not match '#{selected_difficulty}'")
          end
          matches
        end)
        after_count = length(filtered)
        Logger.info("Difficulty filter: #{before_count} -> #{after_count} plants (difficulty: #{selected_difficulty})")
        filtered
      else
        Logger.info("Difficulty filter skipped: difficulty is 'all'")
        plants
      end

    # Filter out plants that can't be transplanted if seedlings selected
    plants =
      if socket.assigns[:planting_method] == :seedlings do
        Enum.filter(plants, fn plant ->
          Plant.can_transplant?(plant)
        end)
      else
        plants
      end

    # Enrich plants with companion status (pre-grouped approach)
    plants = enrich_plants_with_companion_groups(plants)

    # Filter by companion group if enabled
    plants =
      if page_data[:filter_companion_group] == true && page_data[:selected_plant_group_id] do
        target_group_id = page_data[:selected_plant_group_id]
        before_count = length(plants)
        filtered = Enum.filter(plants, fn plant ->
          plant_group_id = Map.get(plant, :companion_group_id)
          plant_group_id == target_group_id
        end)
        after_count = length(filtered)
        Logger.info("Companion group filter: #{before_count} -> #{after_count} plants (group_id: #{target_group_id})")
        filtered
      else
        plants
      end

    # Update page_data with filtered plants
    Logger.info("Final filtered plants count: #{length(plants)} (from #{length(all_plants)} total)")
    page_data = Map.put(page_data, :filtered_plants, plants)
    assign(socket, :page_data, page_data)
  end

  """
  Groups plants that can be planted together (connected through good relationships,
  with no bad relationships between them). Each group gets a unique pattern ID.

  Returns plants with :companion_group_id field (integer 1-N, or nil for no group).
  Plants with NO known companions (neither good nor bad relationships) will have nil.
  """
  defp enrich_plants_with_companion_groups(plants) do
    if Enum.empty?(plants) do
      plants
    else
      # Build companion relationship maps for efficient lookup
      plant_ids = Enum.map(plants, & &1.id)

      # Get all good relationships (edges in our compatibility graph)
      good_relationships = get_all_good_relationships(plant_ids)

      # Get all bad relationships (conflicts - plants that can't be together)
      bad_relationships = get_all_bad_relationships(plant_ids)

      # Find all plants that have at least one companion relationship (good or bad)
      plants_with_relationships = get_plants_with_relationships(plant_ids, good_relationships, bad_relationships)

      # Only group plants that have relationships
      if Enum.empty?(plants_with_relationships) do
        # No plants have relationships - all get nil
        Enum.map(plants, fn plant -> Map.put(plant, :companion_group_id, nil) end)
      else
        # Build adjacency map for good relationships
        good_graph = build_adjacency_map(good_relationships)

        # Find connected components (groups of compatible plants)
        groups = find_companion_groups(plants_with_relationships, good_graph, bad_relationships)

        # Assign group IDs only to plants that have relationships
        Enum.map(plants, fn plant ->
          if plant.id in plants_with_relationships do
            group_id = Map.get(groups, plant.id)
            Map.put(plant, :companion_group_id, group_id)
          else
            # Plant has no known companions - leave as nil
            Map.put(plant, :companion_group_id, nil)
          end
        end)
      end
    end
  end

  # Get all good companion relationships for the given plant IDs
  defp get_all_good_relationships(plant_ids) when is_list(plant_ids) do
    import Ecto.Query

    CompanionRelationship
    |> where([cr], cr.relationship_type == "good")
    |> where([cr], cr.plant_a_id in ^plant_ids)
    |> where([cr], cr.plant_b_id in ^plant_ids)
    |> select([cr], {cr.plant_a_id, cr.plant_b_id})
    |> Repo.all()
  end

  # Get all bad companion relationships (conflicts)
  defp get_all_bad_relationships(plant_ids) when is_list(plant_ids) do
    import Ecto.Query

    CompanionRelationship
    |> where([cr], cr.relationship_type == "bad")
    |> where([cr], cr.plant_a_id in ^plant_ids)
    |> where([cr], cr.plant_b_id in ^plant_ids)
    |> select([cr], {cr.plant_a_id, cr.plant_b_id})
    |> Repo.all()
    |> MapSet.new()
  end

  # Get list of plant IDs that have at least one companion relationship (good or bad)
  # Note: plant_ids parameter is kept for consistency, but we extract IDs from relationships
  defp get_plants_with_relationships(_plant_ids, good_relationships, bad_relationships) do
    # Extract all plant IDs from good relationships
    good_plant_ids =
      good_relationships
      |> Enum.flat_map(fn {a_id, b_id} -> [a_id, b_id] end)
      |> MapSet.new()

    # Extract all plant IDs from bad relationships
    bad_plant_ids =
      bad_relationships
      |> Enum.flat_map(fn {a_id, b_id} -> [a_id, b_id] end)
      |> MapSet.new()

    # Union of both sets - plants that have any relationship
    MapSet.union(good_plant_ids, bad_plant_ids)
    |> MapSet.to_list()
  end

  # Build adjacency map from relationships (bidirectional)
  defp build_adjacency_map(relationships) do
    relationships
    |> Enum.reduce(%{}, fn {a_id, b_id}, acc ->
      acc
      |> Map.update(a_id, MapSet.new([b_id]), &MapSet.put(&1, b_id))
      |> Map.update(b_id, MapSet.new([a_id]), &MapSet.put(&1, a_id))
    end)
  end

  # Find connected components (companion groups) using DFS
  # Ensures no bad relationships exist within a group
  defp find_companion_groups(plant_ids, good_graph, bad_relationships) do
    find_companion_groups_recursive(plant_ids, good_graph, bad_relationships, MapSet.new(), %{}, 1)
  end

  defp find_companion_groups_recursive([], _graph, _bad_relationships, _visited, groups, _next_id), do: groups

  defp find_companion_groups_recursive([plant_id | rest], graph, bad_relationships, visited, groups, next_id) do
    if MapSet.member?(visited, plant_id) do
      find_companion_groups_recursive(rest, graph, bad_relationships, visited, groups, next_id)
    else
      # Start new component - find all connected plants
      {component, new_visited} = find_connected_component(plant_id, graph, bad_relationships, visited, [])

      # Assign group ID to all plants in this component
      new_groups = Enum.reduce(component, groups, fn pid, g -> Map.put(g, pid, next_id) end)

      find_companion_groups_recursive(rest, graph, bad_relationships, new_visited, new_groups, next_id + 1)
    end
  end

  # DFS to find connected component (all plants reachable through good relationships)
  # Returns {component_list, updated_visited_set}
  defp find_connected_component(start_id, graph, bad_relationships, visited, component) do
    if MapSet.member?(visited, start_id) do
      {component, visited}
    else
      neighbors = Map.get(graph, start_id, MapSet.new())
      new_visited = MapSet.put(visited, start_id)
      new_component = [start_id | component]

      # Only traverse to neighbors that don't have bad relationships with current component
      valid_neighbors = Enum.filter(neighbors, fn neighbor_id ->
        !MapSet.member?(new_visited, neighbor_id) and
        !has_bad_relationship_with_any(neighbor_id, new_component, bad_relationships)
      end)

      # Recursively visit all valid neighbors
      {final_component, final_visited} = Enum.reduce(valid_neighbors, {new_component, new_visited}, fn neighbor_id, {acc_component, acc_visited} ->
        find_connected_component(neighbor_id, graph, bad_relationships, acc_visited, acc_component)
      end)

      {final_component, final_visited}
    end
  end

  # Check if a plant has a bad relationship with any plant in a list
  defp has_bad_relationship_with_any(plant_id, plant_list, bad_relationships) do
    Enum.any?(plant_list, fn other_id ->
      MapSet.member?(bad_relationships, {plant_id, other_id}) or
      MapSet.member?(bad_relationships, {other_id, plant_id})
    end)
  end



  @impl true
  def handle_event("accept_quest", %{"quest_id" => quest_id_str}, socket) do
    quest_id = String.to_integer(quest_id_str)
    user_id = socket.assigns.current_user.id

    case Quests.get_user_quest!(quest_id) do
      user_quest when user_quest.user_id == user_id ->
        case Quests.accept_quest(user_quest) do
          {:ok, _updated_quest} ->
            send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_quests)

            {:noreply,
             socket
             |> put_flash(:info, "Quest started!")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to start quest: #{inspect(changeset.errors)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Quest not found")}
    end
  end














  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:session_id] && socket.assigns[:current_user] do
      # Spawn async task so we don't block user navigation
      Task.start(fn ->
        process_session_end(socket.assigns.session_id, socket.assigns.current_user.id)
      end)
    end
    :ok
  end

  # Private function to handle session end processing
  defp process_session_end(session_id, user_id) do
    require Logger
    alias GreenManTavern.{Conversations, Journal, Sessions}
    alias GreenManTavern.Repo

    # Ensure session_id is a string (handle UUID structs from Ecto)
    session_id_string =
      case session_id do
        %{__struct__: Ecto.UUID} = uuid -> Ecto.UUID.cast!(uuid)
        id when is_binary(id) -> id
        other -> to_string(other)
      end

    Logger.info("[DualPanel] Processing session end for session_id: #{session_id_string} (user_id: #{user_id})")

    # Check if session has already been processed (has a session_summary)
    messages = Sessions.get_session_messages(session_id_string)
    if messages != [] do
      first_message = List.first(messages)
      if first_message.session_summary do
        Logger.info("[DualPanel] ⏭️ Session #{session_id_string} already processed (has summary), skipping")
      else
        # Continue with processing
        do_process_session(session_id_string, user_id)
      end
    else
      # No messages, skip processing
      Logger.warning("[DualPanel] ⚠️ No messages found for session #{session_id_string}, skipping")
    end
  end

  # Helper function to actually process the session
  defp do_process_session(session_id_string, user_id) do
    require Logger
    alias GreenManTavern.{Conversations, Journal, Sessions, Characters}
    alias GreenManTavern.Repo

    # Ensure Repo is available in this process (Task.start runs in separate process)
    _ = Repo

    # Get character name from session metadata
    character_name =
      case Sessions.get_session_metadata(session_id_string) do
        nil -> "the character"
        metadata ->
          try do
            character = Characters.get_character!(metadata.character_id)
            character.name
          rescue
            Ecto.NoResultsError ->
              Logger.warning("[DualPanel] Character not found for character_id: #{metadata.character_id}")
              "the character"
          end
      end

    case SessionProcessor.process_session(session_id_string, user_id, character_name) do
      {:ok, result} ->
        journal_summary = Map.get(result, :journal_summary)
        quest_data = Map.get(result, :quest_data)
        merged_quest_id = Map.get(result, :merged_quest_id)

        Logger.info("[DualPanel] ✅ Session processing succeeded. journal_summary: #{if journal_summary, do: "present", else: "nil"}, quest_data: #{if quest_data, do: "present", else: "nil"}, merged_quest_id: #{if merged_quest_id, do: "present (#{merged_quest_id})", else: "nil"}")

        # Store journal summary in conversation_history
        if journal_summary do
          store_session_summary(session_id_string, journal_summary, user_id)
        end

        # Create journal entry if summary exists
        if journal_summary do
          create_session_journal_entry(user_id, journal_summary, session_id_string)
        end

        # Handle quest creation or merging
        cond do
          # Quest was merged into existing
          merged_quest_id ->
            Logger.info("[DualPanel] 🔄 Quest merged into existing quest #{merged_quest_id}")

            # Broadcast quest update
            Phoenix.PubSub.broadcast(
              GreenManTavern.PubSub,
              "user:#{user_id}",
              {:quest_updated, user_id}
            )

          # New unique quest
          quest_data ->
            create_session_quest(user_id, quest_data, session_id_string)

          # No quest generated
          true ->
            :ok
        end

        Logger.info("[DualPanel] ✅ Session processing completed for session_id: #{session_id_string}")

      {:error, reason} ->
        Logger.error("[DualPanel] ⚠️ Session processing failed for session_id #{session_id_string}: #{inspect(reason)}")
        Logger.error("[DualPanel] This means no journal entry or quest will be created for this session.")
    end
  rescue
    error ->
      Logger.error("[DualPanel] ❌ Error in process_session_end: #{inspect(error)}")
      Logger.error("[DualPanel] Stacktrace: #{inspect(__STACKTRACE__)}")
  end

  defp store_session_summary(session_id, journal_summary, user_id) do
    require Logger
    alias GreenManTavern.Conversations

    # Get all messages for this session to find the first one
    messages = Sessions.get_session_messages(session_id)

    if messages != [] do
      first_message = List.first(messages)

      # Update the first message with session summary
      case Conversations.update_conversation_entry(first_message, user_id, %{
        session_summary: journal_summary
      }) do
        {:ok, _updated} ->
          Logger.info("[DualPanel] ✅ Stored session summary in conversation_history")
        {:error, changeset} ->
          Logger.warning("[DualPanel] ⚠️ Failed to store session summary: #{inspect(changeset.errors)}")
      end
    else
      Logger.warning("[DualPanel] ⚠️ No messages found for session #{session_id}, cannot store summary")
    end
  end

  defp create_session_journal_entry(user_id, journal_summary, session_id) do
    require Logger
    alias GreenManTavern.{Journal, Sessions}

    # Get session metadata and messages for journal entry
    metadata = Sessions.get_session_metadata(session_id)
    messages = Sessions.get_session_messages(session_id)

    if metadata do
      # Get first message's conversation_history_id for source_id (if available)
      first_message_id =
        case messages do
          [first_message | _] -> first_message.id
          _ -> nil
        end

      # Format journal entry
      max_day = Journal.get_max_day_number(user_id)
      day_number = max_day + 1

      # Format entry_date as YYYY-MM-DD
      entry_date = Date.utc_today() |> Date.to_string()

      # Extract title from summary (first sentence or default)
      title =
        case journal_summary do
          nil -> "Conversation Summary"
          summary when is_binary(summary) ->
            # Try to extract first sentence (up to 60 chars) or use default
            first_sentence =
              summary
              |> String.split(~r/[.!?]\s+/)
              |> List.first()
              |> String.trim()

            if first_sentence && String.length(first_sentence) <= 60 do
              first_sentence
            else
              "Conversation Summary"
            end
          _ -> "Conversation Summary"
        end

      case Journal.create_entry(%{
        user_id: user_id,
        entry_date: entry_date,
        day_number: day_number,
        title: title,
        body: journal_summary,
        source_type: "conversation",
        source_id: first_message_id,
        conversation_session_id: session_id,
        hidden: false
      }) do
        {:ok, entry} ->
          Logger.info("[DualPanel] ✅ Created journal entry from session summary (ID: #{entry.id}, session_id: #{session_id})")

          # Broadcast journal update so UI refreshes
          Phoenix.PubSub.broadcast(
            GreenManTavern.PubSub,
            "user:#{user_id}",
            {:journal_updated, user_id}
          )
        {:error, changeset} ->
          Logger.warning("[DualPanel] ⚠️ Failed to create journal entry: #{inspect(changeset.errors)}")
      end
    else
      Logger.warning("[DualPanel] ⚠️ No metadata found for session #{session_id}, cannot create journal entry")
    end
  end

  defp create_session_quest(user_id, quest_data, session_id) do
    require Logger
    alias GreenManTavern.{Sessions, Characters}

    # Get session metadata to find character_id
    metadata = Sessions.get_session_metadata(session_id)

    if metadata && metadata.character_id do
      case QuestGenerator.create_quest_from_session(
        user_id,
        quest_data,
        metadata.character_id,
        session_id
      ) do
        {:ok, user_quest} ->
          Logger.info("[DualPanel] ✅ Created quest from session (Quest ID: #{user_quest.id})")

          # Broadcast quest update so UI refreshes
          Phoenix.PubSub.broadcast(
            GreenManTavern.PubSub,
            "user:#{user_id}",
            {:quest_updated, user_id}
          )
        {:error, reason} ->
          Logger.warning("[DualPanel] ⚠️ Failed to create quest from session: #{inspect(reason)}")
      end
    else
      Logger.warning("[DualPanel] ⚠️ No character_id found for session #{session_id}, cannot create quest")
    end
  end
end
