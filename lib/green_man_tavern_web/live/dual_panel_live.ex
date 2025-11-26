defmodule GreenManTavernWeb.DualPanelLive do
  use GreenManTavernWeb, :live_view

  require Logger

  alias Phoenix.PubSub
  alias GreenManTavern.Characters
  alias GreenManTavern.{Conversations, Accounts, Sessions}
  alias GreenManTavern.AI.{OpenAIClient, CharacterContext, SessionProcessor}
  alias GreenManTavern.PlantingGuide
  alias GreenManTavern.Inventory
  alias GreenManTavern.Quests
  alias GreenManTavern.Quests.QuestGenerator


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
  def handle_params(params, _url, socket) do
    Logger.info("[DualPanel] 🔗 handle_params called with params: #{inspect(params)}")
    
    # Store current params for URL construction
    socket = assign(socket, :current_params, params)

    # Determine action from params or live_action
    action =
      case params["page"] do
        "planting_guide" -> :planting_guide
        "living_web" -> :living_web
        "journal" -> :journal
        _ -> socket.assigns.live_action || :home
      end

    Logger.info("[DualPanel] handle_params - action: #{inspect(action)}, params: #{inspect(params)}")

    socket = assign(socket, :right_panel_action, action)
    socket = assign(socket, :last_action, "handle_params")

    # Handle character selection from URL
    socket = 
      case params["character"] do
        nil -> 
          # If character param is missing but we have one selected, close it
          if socket.assigns[:selected_character] do
            close_character_session(socket)
          else
            socket
          end
        
        slug ->
          # If slug is different from current, load it
          current_slug = socket.assigns[:selected_character] && Characters.name_to_slug(socket.assigns.selected_character.name)
          
          if slug != current_slug do
            load_character(socket, slug)
          else
            socket
          end
      end

    # Load data for the right panel action
    socket = load_right_panel_data(socket, action, params)

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
    if socket.assigns[:current_user] do
      user_id = socket.assigns.current_user.id

    case Inventory.create_manual_item(user_id, item_params) do
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
  else
    {:noreply, put_flash(socket, :error, "You must be logged in to add items")}
  end
  end

  @impl true
  def handle_event("delete_inventory_item", %{"id" => id}, socket) do
    if socket.assigns[:current_user] do
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
  else
    {:noreply, put_flash(socket, :error, "You must be logged in to delete items")}
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
  # - Updates URL with character param (via push_patch)
  # - State loading is handled by handle_params
  def handle_event("select_character", %{"character_slug" => slug}, socket) do
    require Logger
    Logger.info("[DualPanel] 🎯 select_character event - slug: #{inspect(slug)}, live_action: #{inspect(socket.assigns.live_action)}")
    
    # Construct new params with character slug
    current_params = socket.assigns[:current_params] || %{}
    new_params = Map.put(current_params, "character", slug)
    
    Logger.info("[DualPanel] 🎯 current_params: #{inspect(current_params)}, new_params: #{inspect(new_params)}")
    
    # Build path based on current live_action
    path = build_current_path(socket, new_params)
    
    Logger.info("[DualPanel] 🎯 Built path: #{inspect(path)}")
    
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("show_tavern_home", _params, socket) do
    # Remove character param from URL
    current_params = socket.assigns[:current_params] || %{}
    new_params = Map.delete(current_params, "character")
    
    # Build path based on current live_action
    path = build_current_path(socket, new_params)
    
    {:noreply, push_patch(socket, to: path)}
  end

  # Helper to build path based on live_action and params
  defp build_current_path(socket, params) do
    require Logger
    
    path = 
      case socket.assigns.live_action do
        :home -> "/"
        :living_web -> "/living-web"
        :inventory -> "/inventory"
        _ -> "/"
      end
    
    Logger.info("[DualPanel] 🛤️ build_current_path - live_action: #{inspect(socket.assigns.live_action)}, base path: #{inspect(path)}, params: #{inspect(params)}")
      
    if map_size(params) > 0 do
      full_path = "#{path}?#{URI.encode_query(params)}"
      Logger.info("[DualPanel] 🛤️ Full path with params: #{inspect(full_path)}")
      full_path
    else
      path
    end
  end

  # Private helper to close character session
  defp close_character_session(socket) do
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
    end

    socket
    |> assign(:left_panel_view, :tavern_home)
    |> assign(:selected_character, nil)
    |> assign(:session_id, nil)
  end

  # Private helper to load character and setup session
  defp load_character(socket, slug) do
    require Logger
    alias GreenManTavern.Sessions

    Logger.info("="<>String.duplicate("=", 70))
    Logger.info("[DualPanel] load_character START")
    Logger.info("[DualPanel] Loading slug: #{slug}")

    case Characters.get_character_by_slug(slug) do
      nil ->
        Logger.warning("[DualPanel] Character not found for slug: #{slug}")
        socket

      character ->
        Logger.info("[DualPanel] Found character: #{character.name} (ID: #{character.id})")
        user_id = socket.assigns.user_id
        Logger.info("[DualPanel] Current user_id: #{inspect(user_id)}")

        # STEP 1: Process OLD session if switching away from another character
        socket = 
          if socket.assigns[:selected_character] && socket.assigns[:selected_character].id != character.id do
            close_character_session(socket)
          else
            socket
          end

        # STEP 2: Get or Create session_id
        # Use get_or_create_session to resume recent sessions or start new one
        session_id = 
          if user_id do
            case Conversations.get_or_create_session(user_id, character.id) do
              {:ok, sid} -> 
                Logger.info("[DualPanel] 🆕 Using session_id: #{inspect(sid)}")
                sid
              {:error, reason} ->
                Logger.error("[DualPanel] ❌ Failed to get/create session: #{inspect(reason)}")
                Sessions.generate_session_id() # Fallback
            end
          else
            Logger.warning("[DualPanel] ⚠️ No user_id, generating temporary session_id")
            Sessions.generate_session_id()
          end
        
        Logger.info("[DualPanel] 🆕 Session for character: #{character.name}")

        # Store current messages for current character before switching (if any)
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

        Logger.info("[DualPanel] load_character END")
        Logger.info("="<>String.duplicate("=", 70))

        socket
         |> assign(:selected_character, character)
         |> assign(:left_panel_view, :character_chat)
         |> assign(:chat_messages, messages)
         |> assign(:character_messages, updated_character_messages)
         |> assign(:current_message, "")
         |> assign(:session_id, session_id)
    end
  rescue
    e ->
      Logger.error("[DualPanel] ❌ CRASH in load_character: #{inspect(e)}")
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      socket
  end

  # Private helper to load data for right panel actions
  defp load_right_panel_data(socket, action, _params) do
    require Logger
    alias GreenManTavern.Journal
    
    case action do
      :journal ->
        Logger.info("[DualPanel] 📖 Loading Journal data...")
        user_id = if socket.assigns[:current_user], do: socket.assigns.current_user.id, else: nil
        
        socket
        |> assign(:journal_entries, if(user_id, do: Journal.list_entries(user_id, limit: 1000), else: []))
        |> assign(:journal_current_page, socket.assigns[:journal_current_page] || 1)
        |> assign(:journal_entries_per_page, socket.assigns[:journal_entries_per_page] || 15)
        |> assign(:journal_has_overflow, socket.assigns[:journal_has_overflow] || false)
        |> assign(:journal_show_hidden, socket.assigns[:journal_show_hidden] || false)
        |> assign(:journal_search_term, socket.assigns[:journal_search_term] || "")
        |> assign(:characters, socket.assigns[:characters] || Characters.list_characters())

      :planting_guide ->
        Logger.info("[DualPanel] 🌱 Loading Planting Guide data...")
        user_plants =
          if socket.assigns[:current_user] do
            PlantingGuide.list_user_plants(socket.assigns.current_user.id)
          else
            []
          end
          
        socket
        |> assign(:user_plants, user_plants || [])
        |> assign(:initialize_planting_guide, true)

      :living_web ->
        # Add any living web specific data loading here
        socket

      _ ->
        socket
    end
  end

  # LEFT WINDOW CLEAR ONLY: HyperArk click clears chat state, preserves right page.
  def handle_event("navigate", %{"page" => "hyperark"}, socket) do
    # Just clear character param from URL
    current_params = socket.assigns[:current_params] || %{}
    new_params = Map.delete(current_params, "character")
    
    # Keep current page if any
    path = build_current_path(socket, new_params)
    
    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  # RIGHT WINDOW: Page navigation should only affect right-side page state.
  # - Changes current page (:living_web | :database | :garden)
  # - Loads page-specific data into :page_data
  # - DOES NOT touch left window chat state
  def handle_event("navigate", %{"page" => "journal"}, socket) do
    require Logger
    
    # Just update URL, let handle_params do the work
    current_params = socket.assigns[:current_params] || %{}
    new_params = Map.put(current_params, "page", "journal")
    path = build_current_path(socket, new_params) # Note: build_current_path uses live_action, so we might need to adjust logic or just construct manually
    
    # Since we are changing "page", we should construct the path manually or update build_current_path
    # But wait, build_current_path uses socket.assigns.live_action which hasn't changed yet.
    # Actually, simpler to just push_patch to the target URL.
    
    # Preserve character param
    char_slug = if socket.assigns.selected_character, do: Characters.name_to_slug(socket.assigns.selected_character.name), else: nil
    
    path = "/?page=journal"
    path = if char_slug, do: path <> "&character=#{char_slug}", else: path
    
    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("navigate", %{"page" => page}, socket) do
    Logger.info("[DualPanel] 🧭 Navigate event received: page=#{page}")
    
    # Preserve character param
    char_slug = if socket.assigns.selected_character, do: Characters.name_to_slug(socket.assigns.selected_character.name), else: nil
    
    path = 
      case page do
        "living_web" -> "/living-web"
        "database" -> "/?page=database" # Assuming database is a page param? Or route?
        "garden" -> "/?page=garden"
        "planting_guide" -> "/?page=planting_guide"
        "hyperark" -> "/"
        _ -> "/"
      end

    path = if char_slug, do: path <> (if String.contains?(path, "?"), do: "&", else: "?") <> "character=#{char_slug}", else: path

    {:noreply, push_patch(socket, to: path)}
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
    if socket.assigns[:current_user] && socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_journal)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:journal_updated, user_id}, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_journal)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:quest_updated, user_id}, socket) do
    if socket.assigns[:current_user] && socket.assigns.current_user.id == user_id do
      send_update(GreenManTavernWeb.JournalPanelComponent, id: "journal-panel", action: :refresh_quests)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:select_character, slug}, socket) do
    require Logger
    Logger.info("[DualPanel] 📨 Received select_character message - slug: #{inspect(slug)}")
    # Forward to handle_event
    handle_event("select_character", %{"character_slug" => slug}, socket)
  end

  # Journal creation handlers






  @impl true
  def handle_event("accept_quest", %{"quest_id" => quest_id_str}, socket) do
    if socket.assigns[:current_user] do
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
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to accept quests")}
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
