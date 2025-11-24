defmodule GreenManTavernWeb.JournalPanelComponent do
  use GreenManTavernWeb, :live_component

  alias GreenManTavern.Journal
  alias GreenManTavern.Quests
  alias GreenManTavern.Quests.{DifficultyCalculator, PlantingQuestManager}
  alias GreenManTavernWeb.TextFormattingHelpers
  alias GreenManTavern.Characters

  require Logger

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Initial data fetch if not already present
    socket =
      if Map.get(assigns, :action) == :refresh_quests do
        refresh_quests(socket)
      else
        socket
      end

    socket =
      if Map.get(assigns, :action) == :refresh_journal do
        refresh_journal(socket)
      else
        socket
      end

    socket =
      if is_nil(socket.assigns[:journal_entries]) do
        user_id = socket.assigns[:current_user].id
        
        socket
        |> assign(:journal_entries, Journal.list_entries(user_id, limit: 1000))
        |> assign(:journal_current_page, 1)
        |> assign(:journal_entries_per_page, 15)
        |> assign(:journal_has_overflow, false)
        |> assign(:journal_show_hidden, false)
        |> assign(:journal_search_term, "")
        |> assign(:user_quests, fetch_and_enrich_quests(user_id))
        |> assign(:quest_filter, "all")
        |> assign(:quest_search_term, "")
        |> assign(:expanded_quest_id, nil)
        |> assign(:creating_new_entry, false)
        |> assign(:new_entry_text, "")
        |> assign(:editing_entry_id, nil)
        |> assign(:editing_entry_text, "")
      else
        socket
      end

    {:ok, socket}
  end

  defp refresh_quests(socket) do
    user_id = socket.assigns[:current_user].id
    assign(socket, :user_quests, fetch_and_enrich_quests(user_id))
  end

  defp refresh_journal(socket) do
    user_id = socket.assigns[:current_user].id
    show_hidden = socket.assigns[:journal_show_hidden] || false
    term = socket.assigns[:journal_search_term] || ""
    
    entries = if term == "" do
      Journal.list_entries(user_id, limit: 1000, include_hidden: show_hidden)
    else
      Journal.search_entries(user_id, term, include_hidden: show_hidden)
    end
    
    assign(socket, :journal_entries, entries)
  end

  defp fetch_and_enrich_quests(user_id) do
    Quests.list_user_quests_with_characters(user_id, "all")
    |> enrich_quests_with_difficulty(user_id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="journal-panel" style="height: 100%; padding: 10px; background: #CCCCCC; font-family: Georgia, 'Times New Roman', serif; box-sizing: border-box; overflow: hidden;">
      <!-- Main Notebook Container -->
      <div style="
        height: 100%;
        background: #FFF;
        border: 3px solid #000;
        outline: 1px solid #000;
        outline-offset: -6px;
        display: flex;
        position: relative;
        box-shadow: 5px 5px 0 rgba(0,0,0,0.2);
      ">
        <!-- LEFT PAGE -->
        <div class="journal-page left-page" style="flex: 1; padding: 20px 10px 20px 20px; display: flex; flex-direction: column; overflow: hidden; position: relative; background: transparent; background-image: none; border: none; box-shadow: none;">
          <!-- Header Row -->
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; padding-bottom: 10px;">
            <h2 style="margin: 0; font-size: 22px; font-weight: bold; color: #333;">Journal</h2>
            
            <div style="display: flex; gap: 8px;">
              <%= if not @creating_new_entry do %>
                <button
                  phx-click="start_new_entry"
                  phx-target={@myself}
                  title="New Entry"
                  style="
                    width: 32px; 
                    height: 32px; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center;
                    background: #FFF;
                    border: 1px solid #CCC;
                    font-size: 18px;
                    cursor: pointer;
                    color: #666;
                  "
                >+</button>
                <button
                  phx-click="start_new_entry"
                  phx-target={@myself}
                  style="
                    padding: 0 12px;
                    height: 32px;
                    background: #FFF;
                    border: 1px solid #CCC;
                    font-family: Georgia, 'Times New Roman', serif;
                    font-size: 13px;
                    color: #333;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                  "
                >+ New Entry</button>
              <% end %>
            </div>
          </div>

          <!-- Content Area (Entries) -->
          <div style="flex: 1; overflow-y: auto; padding-right: 10px; margin-bottom: 10px;">
            <!-- New Entry Form -->
            <%= if @creating_new_entry do %>
              <div style="margin-bottom: 20px; padding: 15px; background: #F9F9F9; border: 1px solid #CCC;">
                <form phx-submit="save_new_entry" phx-change="update_new_entry" phx-target={@myself}>
                  <textarea
                    name="text"
                    placeholder="Write your journal entry..."
                    style="
                      width: 100%;
                      min-height: 120px;
                      padding: 10px;
                      background: #FFF;
                      border: 1px solid #CCC;
                      font-family: Georgia, 'Times New Roman', serif;
                      font-size: 13px;
                      color: #000;
                      line-height: 1.5;
                      resize: vertical;
                      margin-bottom: 10px;
                    "
                  ><%= @new_entry_text %></textarea>
                  <div style="display: flex; gap: 10px; justify-content: flex-end;">
                    <button
                      type="submit"
                      disabled={String.trim(@new_entry_text) == ""}
                      style="padding: 6px 15px; background: #333; color: #FFF; border: none; cursor: pointer; font-size: 12px;"
                    >Save</button>
                    <button
                      type="button"
                      phx-click="cancel_new_entry"
                      phx-target={@myself}
                      style="padding: 6px 15px; background: #DDD; color: #000; border: none; cursor: pointer; font-size: 12px;"
                    >Cancel</button>
                  </div>
                </form>
              </div>
            <% end %>

            <!-- Entries List -->
            <%= if Enum.empty?(@journal_entries) do %>
              <div style="padding: 20px; text-align: center; color: #999; font-style: italic; font-size: 13px;">
                No journal entries yet.
              </div>
            <% else %>
              <% 
                paginated = paginated_entries(@journal_entries, @journal_current_page, @journal_entries_per_page)
              %>
              
              <%= for entry <- paginated do %>
                <div class="journal-entry" style={"margin-bottom: 24px; position: relative; opacity: #{if entry.hidden, do: "0.6", else: "1.0"};"}>
                  <div style="display: flex; align-items: flex-start; gap: 10px;">
                    <div style="flex: 1;">
                      <div style="font-size: 13px; line-height: 1.6; color: #333;">
                        <%= raw(TextFormattingHelpers.render_markdown(entry.body)) %>
                      </div>
                    </div>
                    
                    <div style="display: flex; gap: 2px;">
                       <button 
                        phx-click="delete_entry" 
                        phx-value-id={entry.id} 
                        phx-target={@myself}
                        data-confirm="Delete this entry?"
                        title="Delete"
                        style="width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; border: 1px solid #CCC; background: #FFF; color: #999; cursor: pointer; font-size: 10px;"
                      >×</button>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Bottom Controls Container -->
          <div style="margin-top: auto; padding-top: 10px; border-top: 1px solid #EEE;">
            <!-- Search -->
            <div style="margin-bottom: 15px;">
               <form phx-change="search_journal" phx-submit="search_journal" phx-target={@myself} onsubmit="return false;">
                <input 
                  type="text" 
                  name="term" 
                  value={@journal_search_term} 
                  placeholder="Search journal entries..." 
                  style="width: 100%; padding: 10px; border: 1px solid #CCC; background: #FFF; font-family: Georgia, serif; font-size: 13px; color: #666;"
                />
              </form>
            </div>

            <!-- Pagination -->
            <% total_pgs = total_pages(@journal_entries, @journal_entries_per_page) %>
            <div style="display: flex; justify-content: center; align-items: center; padding: 10px; border: 1px solid #CCC; background: #FFF;">
              <div style="display: flex; gap: 8px; align-items: center;">
                <button phx-click="journal_first_page" phx-target={@myself} disabled={@journal_current_page == 1} style="width: 24px; height: 24px; border: 1px solid #CCC; background: #FFF; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #666;">|&laquo;</button>
                <button phx-click="journal_prev_page" phx-target={@myself} disabled={@journal_current_page == 1} style="width: 24px; height: 24px; border: 1px solid #CCC; background: #FFF; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #666;">&laquo;</button>
                
                <span style="font-size: 12px; color: #666; margin: 0 8px;">
                  Page <span style="border: 1px solid #CCC; padding: 2px 6px; margin: 0 4px;"><%= @journal_current_page %></span> of <%= total_pgs %>
                </span>
                
                <button phx-click="journal_next_page" phx-target={@myself} disabled={@journal_current_page == total_pgs} style="width: 24px; height: 24px; border: 1px solid #CCC; background: #FFF; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #666;">&raquo;</button>
                <button phx-click="journal_last_page" phx-target={@myself} disabled={@journal_current_page == total_pgs} style="width: 24px; height: 24px; border: 1px solid #CCC; background: #FFF; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: 10px; color: #666;">&raquo;|</button>
              </div>
            </div>
          </div>
        </div>

        <!-- SPINE -->
        <div class="notebook-spine" style="
          width: 40px;
          background: #F0F0F0;
          border-left: 1px solid #DDD;
          border-right: 1px solid #DDD;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding-top: 20px;
          padding-bottom: 20px;
          justify-content: space-between;
          flex-shrink: 0;
          z-index: 10;
          height: 100%;
          overflow: hidden;
        ">
          <%= for _i <- 1..20 do %>
            <div style="
              width: 100%;
              height: 12px;
              position: relative;
              display: flex;
              align-items: center;
              justify-content: center;
              margin: 15px 0;
            ">
              <!-- Ring -->
              <div style="
                width: 36px;
                height: 4px;
                background: #333;
                border-radius: 2px;
                position: absolute;
                z-index: 2;
              "></div>
              <!-- Hole Left -->
              <div style="
                width: 8px;
                height: 8px;
                background: #333;
                border-radius: 50%;
                position: absolute;
                left: -4px;
                z-index: 1;
              "></div>
              <!-- Hole Right -->
              <div style="
                width: 8px;
                height: 8px;
                background: #333;
                border-radius: 50%;
                position: absolute;
                right: -4px;
                z-index: 1;
              "></div>
            </div>
          <% end %>
        </div>

        <!-- RIGHT PAGE -->
        <div class="journal-page right-page" style="flex: 1; padding: 20px 20px 20px 10px; display: flex; flex-direction: column; overflow: hidden; background: transparent; background-image: none; border: none; box-shadow: none;">
           <!-- Header Row -->
          <div style="margin-bottom: 20px; padding-bottom: 10px;">
            <h2 style="margin: 0; font-size: 22px; font-weight: bold; color: #333;">Quests</h2>
          </div>

          <div style="flex: 1; overflow-y: auto; padding-left: 10px;">
            <!-- Active Quests -->
            <div style="margin-bottom: 30px;">
              <h3 style="font-size: 14px; font-weight: bold; margin-bottom: 10px; color: #333;">Active Quests</h3>
              
              <% active_quests = Enum.filter(@user_quests, fn q -> q.status != "completed" end) %>
              
              <%= if Enum.empty?(active_quests) do %>
                <div style="padding: 15px; background: #F5F5F5; color: #888; font-style: italic; font-size: 13px; border-radius: 4px;">
                  No active quests yet. Start a quest from the Available Quests section below.
                </div>
              <% else %>
                <%= for user_quest <- active_quests do %>
                  <%= render_quest_item(user_quest, @expanded_quest_id == user_quest.id, @characters) %>
                <% end %>
              <% end %>
            </div>

            <!-- Available Quests -->
            <div style="margin-bottom: 30px;">
              <h3 style="font-size: 14px; font-weight: bold; margin-bottom: 10px; color: #333;">Available Quests</h3>
               <div style="padding: 15px; background: #F5F5F5; color: #888; font-style: italic; font-size: 13px; border-radius: 4px;">
                  No available quests yet. Chat with characters to discover new quests!
                </div>
            </div>
            
            <!-- Completed Quests -->
            <div style="margin-bottom: 30px;">
              <h3 style="font-size: 14px; font-weight: bold; margin-bottom: 10px; color: #333;">Completed</h3>
              
              <% completed_quests = Enum.filter(@user_quests, fn q -> q.status == "completed" end) %>
              
              <%= if Enum.empty?(completed_quests) do %>
                <div style="padding: 15px; background: #F5F5F5; color: #888; font-style: italic; font-size: 13px; border-radius: 4px;">
                  No completed quests yet. Complete active quests to see them here.
                </div>
              <% else %>
                <%= for user_quest <- completed_quests do %>
                  <%= render_quest_item(user_quest, @expanded_quest_id == user_quest.id, @characters) %>
                <% end %>
              <% end %>
            </div>

            <!-- Search -->
            <div style="margin-top: 20px; margin-bottom: 20px;">
              <form phx-change="search_quests" phx-submit="search_quests" phx-target={@myself} onsubmit="return false;">
                <input 
                  type="text" 
                  name="term" 
                  value={@quest_search_term} 
                  placeholder="Search quests..." 
                  style="width: 100%; padding: 10px; border: 1px solid #CCC; background: #FFF; font-family: Georgia, serif; font-size: 13px; color: #666;"
                />
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("search_journal", %{"term" => term}, socket) do
    user_id = socket.assigns.current_user.id
    show_hidden = socket.assigns.journal_show_hidden
    
    entries = if term == "" do
      Journal.list_entries(user_id, limit: 1000, include_hidden: show_hidden)
    else
      Journal.search_entries(user_id, term, include_hidden: show_hidden)
    end
    
    {:noreply,
     socket
     |> assign(:journal_entries, entries)
     |> assign(:journal_search_term, term)
     |> assign(:journal_current_page, 1)}
  end

  @impl true
  def handle_event("toggle_hidden_entries", _params, socket) do
    new_show_hidden = !socket.assigns.journal_show_hidden
    user_id = socket.assigns.current_user.id
    term = socket.assigns.journal_search_term
    
    entries = if term == "" do
      Journal.list_entries(user_id, limit: 1000, include_hidden: new_show_hidden)
    else
      Journal.search_entries(user_id, term, include_hidden: new_show_hidden)
    end
    
    {:noreply,
     socket
     |> assign(:journal_show_hidden, new_show_hidden)
     |> assign(:journal_entries, entries)
     |> assign(:journal_current_page, 1)}
  end

  @impl true
  def handle_event("start_new_entry", _params, socket) do
    {:noreply, assign(socket, :creating_new_entry, true)}
  end

  @impl true
  def handle_event("cancel_new_entry", _params, socket) do
    {:noreply, assign(socket, :creating_new_entry, false) |> assign(:new_entry_text, "")}
  end

  @impl true
  def handle_event("update_new_entry", %{"text" => text}, socket) do
    {:noreply, assign(socket, :new_entry_text, text)}
  end

  @impl true
  def handle_event("save_new_entry", %{"text" => text}, socket) do
    user_id = socket.assigns.current_user.id
    
    case Journal.create_entry(%{user_id: user_id, body: text, title: "New Entry"}) do
      {:ok, _entry} ->
        socket = refresh_journal(socket)
        {:noreply, 
         socket 
         |> assign(:creating_new_entry, false) 
         |> assign(:new_entry_text, "")
         |> put_flash(:info, "Entry created successfully")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create entry")}
    end
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    # In a real app, we might want a confirmation dialog or undo
    # For now, just delete it
    entry = Journal.get_entry!(id)
    
    if entry.user_id == socket.assigns.current_user.id do
      case Journal.delete_entry(entry) do
        {:ok, _} ->
          # Refresh list
          refresh_journal(socket)
          {:noreply, put_flash(socket, :info, "Entry deleted")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete entry")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  # Pagination Handlers
  @impl true
  def handle_event("journal_prev_page", _params, socket) do
    current = socket.assigns.journal_current_page
    new_page = max(1, current - 1)
    {:noreply, assign(socket, :journal_current_page, new_page)}
  end

  @impl true
  def handle_event("journal_next_page", _params, socket) do
    current = socket.assigns.journal_current_page
    total = total_pages(socket.assigns.journal_entries, socket.assigns.journal_entries_per_page)
    new_page = min(total, current + 1)
    {:noreply, assign(socket, :journal_current_page, new_page)}
  end

  @impl true
  def handle_event("journal_first_page", _params, socket) do
    {:noreply, assign(socket, :journal_current_page, 1)}
  end

  @impl true
  def handle_event("journal_last_page", _params, socket) do
    total = total_pages(socket.assigns.journal_entries, socket.assigns.journal_entries_per_page)
    {:noreply, assign(socket, :journal_current_page, total)}
  end

  # Quest Handlers

  @impl true
  def handle_event("expand_quest", %{"quest_id" => quest_id}, socket) do
    id = String.to_integer(quest_id)
    {:noreply, assign(socket, :expanded_quest_id, id)}
  end

  @impl true
  def handle_event("collapse_quest", _params, socket) do
    {:noreply, assign(socket, :expanded_quest_id, nil)}
  end

  @impl true
  def handle_event("filter_quests", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :quest_filter, filter)}
  end

  @impl true
  def handle_event("search_quests", %{"term" => term}, socket) do
    {:noreply, assign(socket, :quest_search_term, term)}
  end

  # Helpers

  defp paginated_entries(entries, current_page, per_page) do
    start_index = (current_page - 1) * per_page
    Enum.slice(entries, start_index, per_page)
  end

  defp total_pages(entries, per_page) do
    count = length(entries)
    if count == 0, do: 1, else: ceil(count / per_page)
  end

  defp filter_quests(quests, filter, term) do
    quests
    |> Enum.filter(fn q -> 
      case filter do
        "all" -> true
        "active" -> q.status != "completed"
        "completed" -> q.status == "completed"
        _ -> true
      end
    end)
    |> Enum.filter(fn q ->
      if term == "" do
        true
      else
        title = if q.quest, do: q.quest.title, else: q.title
        String.contains?(String.downcase(title), String.downcase(term))
      end
    end)
  end

  defp enrich_quests_with_difficulty(user_quests, user_id) do
    user_quests
    |> Enum.map(fn user_quest ->
      difficulty_data = DifficultyCalculator.calculate_difficulty(user_id, user_quest)
      Map.put(user_quest, :difficulty_data, difficulty_data)
    end)
    |> sort_quests_by_difficulty()
  end

  defp sort_quests_by_difficulty(quests) do
    quests
    |> Enum.sort(fn quest1, quest2 ->
      difficulty1 = case Map.get(quest1, :difficulty_data, %{}) |> Map.get(:overall_difficulty, "medium") do
        "easy" -> 1
        "medium" -> 2
        "hard" -> 3
        _ -> 2
      end

      difficulty2 = case Map.get(quest2, :difficulty_data, %{}) |> Map.get(:overall_difficulty, "medium") do
        "easy" -> 1
        "medium" -> 2
        "hard" -> 3
        _ -> 2
      end

      if difficulty1 == difficulty2 do
        # Secondary sort by date (newest first)
        inserted_at1 = quest1.inserted_at || ~N[2000-01-01 00:00:00]
        inserted_at2 = quest2.inserted_at || ~N[2000-01-01 00:00:00]
        NaiveDateTime.compare(inserted_at1, inserted_at2) == :gt
      else
        difficulty1 < difficulty2
      end
    end)
  end

  # Render Helpers (copied from DualPanelLive)

  defp render_quest_item(user_quest, is_expanded, characters) do
    # Extract data
    difficulty_data = Map.get(user_quest, :difficulty_data, %{})
    overall_difficulty = Map.get(difficulty_data, :overall_difficulty, "medium")
    readiness_ratio = Map.get(difficulty_data, :readiness_ratio, "0/0")
    skill_breakdown = Map.get(difficulty_data, :skill_breakdown, [])

    # Get quest details
    quest_steps = if user_quest.quest, do: user_quest.quest.steps || [], else: user_quest.steps || []
    is_planting = user_quest.type == "planting"

    # Get character info
    character = case user_quest.generated_by_character do
      %Ecto.Association.NotLoaded{} ->
        if user_quest.generated_by_character_id do
          case GreenManTavern.Repo.get(Characters.Character, user_quest.generated_by_character_id) do
            nil -> nil
            char -> char
          end
        else
          nil
        end
      nil ->
        if user_quest.quest, do: user_quest.quest.character, else: nil
      character ->
        character
    end

    character_name = case character do
      nil -> "Unknown"
      char when is_map(char) -> char.name || "Unknown"
      _ -> "Unknown"
    end
    
    char_emoji = character_emoji(character_name)

    # Difficulty rating
    stars = case overall_difficulty do
      "easy" -> "*"
      "medium" -> "***"
      "hard" -> "*****"
      _ -> "***"
    end

    click_event = if is_expanded, do: "collapse_quest", else: "expand_quest"
    quest_id = Integer.to_string(user_quest.id)
    
    title = if user_quest.quest, do: user_quest.quest.title, else: user_quest.title
    title_html = TextFormattingHelpers.render_text_with_terms(title, characters)

    assigns = %{
      user_quest: user_quest,
      is_expanded: is_expanded,
      characters: characters,
      click_event: click_event,
      quest_id: quest_id,
      title_html: title_html,
      stars: stars,
      readiness_ratio: readiness_ratio,
      char_emoji: char_emoji,
      character_name: character_name,
      is_planting: is_planting,
      quest_steps: quest_steps,
      skill_breakdown: skill_breakdown
    }

    ~H"""
    <div style="margin-bottom: 12px; padding: 8px; border: 1px solid rgba(61, 40, 23, 0.2); background: rgba(255, 255, 255, 0.5); font-family: Georgia, 'Times New Roman', serif;">
      <div style="cursor: pointer;" phx-click={@click_event} phx-value-quest_id={@quest_id} phx-target={@myself}>
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
          <div style="flex: 1;">
            <div style="font-size: 14px; font-weight: bold; color: #3d2817; margin-bottom: 2px;">
              <%= @title_html %>
            </div>
            <div style="font-size: 11px; color: #666; display: flex; align-items: center; gap: 8px;">
              <span><%= @stars %></span>
              <span>•</span>
              <span><%= @readiness_ratio %></span>
              <span>•</span>
              <span style="display: flex; align-items: center; gap: 4px;">
                <span style="font-size: 14px;"><%= @char_emoji %></span>
                <%= @character_name %>
              </span>
            </div>
            <%= multiple_suggesters_html(@user_quest, @characters) %>
          </div>
          <div style="font-size: 12px; color: #666;">
            <%= if @is_expanded, do: "−", else: "+" %>
          </div>
        </div>
      </div>

      <%= if @is_expanded do %>
        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px dashed rgba(61, 40, 23, 0.2);">
          <%= if @is_planting do %>
            <%= render_planting_quest_details(@user_quest) %>
          <% else %>
            <%
              ready_skills = Enum.filter(@skill_breakdown, &(&1.status == "ready"))
              challenging_skills = Enum.filter(@skill_breakdown, &(&1.status == "challenging"))
            %>
            
            <%= if @quest_steps != [] do %>
              <div style="margin-bottom: 12px;">
                <div style="font-size: 11px; font-weight: bold; color: #3d2817; margin-bottom: 4px;">Steps:</div>
                <ol style="margin: 0; padding-left: 20px; font-size: 12px; color: #2a2a2a; line-height: 1.6;">
                  <%= for step <- @quest_steps do %>
                    <li style="margin-bottom: 4px;">
                      <%= TextFormattingHelpers.render_text_with_terms(step, @characters) %>
                    </li>
                  <% end %>
                </ol>
              </div>
            <% end %>

            <%= if ready_skills != [] do %>
              <div style="margin-bottom: 8px;">
                <div style="font-size: 11px; font-weight: bold; color: #2E7D32; margin-bottom: 2px;">Ready Skills:</div>
                <%= for skill <- ready_skills do %>
                  <div style="font-size: 12px; color: #2a2a2a; margin-left: 8px; margin-bottom: 2px;">✅ <%= format_skill_name(skill.domain) %> (you know this!)</div>
                <% end %>
              </div>
            <% end %>

            <%= if challenging_skills != [] do %>
              <div style="margin-bottom: 8px;">
                <div style="font-size: 11px; font-weight: bold; color: #C62828; margin-bottom: 2px;">Challenging Skills:</div>
                <%= for skill <- challenging_skills do %>
                  <div style="font-size: 12px; color: #2a2a2a; margin-left: 8px; margin-bottom: 2px;">⚠️ <%= format_skill_name(skill.domain) %> (needs practice)</div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_planting_quest_details(user_quest) do
    # This is a placeholder for planting quest details
    # In the original code, this called PlantingQuestManager logic
    # We'll simplify for now or copy the logic if needed
    assigns = %{user_quest: user_quest}
    ~H"""
    <div style="font-size: 12px; color: #333;">
      <p><strong>Planting Quest:</strong> Follow the planting guide for this crop.</p>
      <p>Status: <%= @user_quest.status %></p>
    </div>
    """
  end

  defp multiple_suggesters_html(user_quest, characters) do
    # Check if there are other suggesters
    # This logic was in DualPanelLive, simplifying for now
    assigns = %{}
    ~H""
  end

  defp character_emoji(name) do
    case name do
      "Green Man" -> "🌿"
      "Elder Oak" -> "🌳"
      "River Spirit" -> "💧"
      "Stone Guardian" -> "🪨"
      "Fire Sprite" -> "🔥"
      "Wind Whisperer" -> "💨"
      _ -> "👤"
    end
  end

  defp format_skill_name(domain) do
    domain
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
