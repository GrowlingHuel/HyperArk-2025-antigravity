defmodule GreenManTavernWeb.PlantingGuidePanelComponent do
  use GreenManTavernWeb, :live_component

  require Logger

  alias GreenManTavern.PlantingGuide
  alias GreenManTavern.PlantingGuide.{Plant, UserPlant, CompanionRelationship}
  alias GreenManTavern.Repo
  alias GreenManTavern.Quests.PlantingQuestManager

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    Logger.info("[PlantingGuidePanel] 🔄 Update called with assigns: #{inspect(Map.keys(assigns))}")
    Logger.info("[PlantingGuidePanel] 🔄 initialize_planting_guide flag: #{inspect(assigns[:initialize_planting_guide])}")
    
    # Assign all passed assigns
    socket = assign(socket, assigns)

    # Ensure page_data exists (initialize with empty map if not present)
    socket =
      if socket.assigns[:page_data] do
        Logger.info("[PlantingGuidePanel] ✅ page_data already exists")
        socket
      else
        Logger.info("[PlantingGuidePanel] 🆕 Initializing empty page_data")
        assign(socket, :page_data, %{})
      end

    # Initialize planting guide state if navigating to planting guide
    socket =
      if socket.assigns[:initialize_planting_guide] == true do
        Logger.info("[PlantingGuidePanel] 🌱 Initializing planting guide state...")
        socket
        |> initialize_planting_guide_state()
        |> assign(:initialize_planting_guide, false)
        |> tap(fn _ -> Logger.info("[PlantingGuidePanel] ✅ Planting guide state initialized") end)
      else
        Logger.info("[PlantingGuidePanel] ⏭️  Skipping initialization (flag not set)")
        socket
      end

    {:ok, socket}
  end

  defp initialize_planting_guide_state(socket) do
    user_id = if socket.assigns[:current_user], do: socket.assigns.current_user.id, else: nil

    # Initialize user_plants (even if empty) - MUST be before any filtering
    user_plants =
      if user_id do
        PlantingGuide.list_user_plants(user_id)
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
    default_city_id =
      if user_id do
        PlantingGuide.get_user_default_city_id(user_id)
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

    page_data = %{
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
      selected_day: if(default_city_id, do: Date.utc_today(), else: nil),
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

    socket =
      socket
      |> assign(:user_plants, user_plants || [])
      |> assign(:planting_method, :seeds)
      |> assign(:page_data, page_data)
      |> assign(:editing_harvest_date, false)
      |> assign(:editing_plant_id, nil)

    # If we have a default city from user_plants, filter plants accordingly
    if page_data[:selected_city_id] do
      filter_planting_guide_plants(socket)
    else
      socket
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="height: 100%">
              <div class="planting-guide-container">
                <%!-- Filter Section --%>
                <div class="filters-section">
                  <%!-- City Selector --%>
                  <div class="filter-group">
                    <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 10px;">
                      <label style="margin: 0; font-weight: bold;">Select your city:</label>
                      <form phx-change="select_city" phx-target={@myself} phx-submit="ignore" style="flex: 1; margin: 0;">
                        <select name="city_id" id="city-selector" style="width: 100%;">
                          <option value="">-- Choose a city --</option>
                          <%= for city <- @page_data[:cities] || [] do %>
                            <% hemisphere_abbr = if city.hemisphere == "Southern", do: "S", else: "N" %>
                            <option value={city.id} selected={@page_data[:selected_city_id] == city.id}>
                              <%= city.city_name %>, <%= city.country %> (<%= city.koppen_code %>) - <%= hemisphere_abbr %>
                            </option>
                          <% end %>
                        </select>
                      </form>
                    </div>
                    <div style="font-size: 11px; color: #666; margin-top: 4px;">
                      * Selecting a city will automatically set your climate zone and frost dates
                    </div>
                  </div>

                  <%!-- Manual Overrides (Collapsible) --%>
                  <details style="margin-bottom: 15px; border: 1px solid #999; padding: 8px; background: #EEE;">
                    <summary style="font-weight: bold; cursor: pointer; font-family: Georgia, 'Times New Roman', serif; font-size: 12px;">
                      Manual Climate Settings
                    </summary>
                    <div style="margin-top: 10px;">
                      <div class="filter-group">
                        <label>Climate Zone (Koppen):</label>
                        <form phx-change="select_zone" phx-target={@myself} phx-submit="ignore">
                          <select name="zone_id">
                            <option value="">-- Select Zone --</option>
                            <%= for zone <- @page_data[:koppen_zones] || [] do %>
                              <option value={zone.code} selected={@page_data[:selected_climate_zone] == zone.code}>
                                <%= zone.code %> - <%= zone.description %>
                              </option>
                            <% end %>
                          </select>
                        </form>
                      </div>

                      <div class="filter-group">
                        <label>Last Frost Date (Spring):</label>
                        <form phx-change="select_last_frost" phx-target={@myself} phx-submit="ignore">
                          <input type="date" name="date" value={if @page_data[:last_frost_date], do: Date.to_string(@page_data[:last_frost_date])} 
                                 style="width: 100%; padding: 5px; border: 2px solid #000; font-family: Georgia, 'Times New Roman', serif;">
                        </form>
                      </div>

                      <div class="filter-group">
                        <label>First Frost Date (Autumn):</label>
                        <form phx-change="select_first_frost" phx-target={@myself} phx-submit="ignore">
                          <input type="date" name="date" value={if @page_data[:first_frost_date], do: Date.to_string(@page_data[:first_frost_date])}
                                 style="width: 100%; padding: 5px; border: 2px solid #000; font-family: Georgia, 'Times New Roman', serif;">
                        </form>
                      </div>
                    </div>
                  </details>

                  <%!-- Date Selection --%>
                  <div class="filter-group" style="background: #FFF; padding: 10px; border: 2px solid #000; box-shadow: 2px 2px 0 #000;">
                    <label style="border-bottom: 1px solid #000; padding-bottom: 5px; margin-bottom: 10px;">Planning Date:</label>
                    <div style="display: flex; gap: 10px;">
                      <form phx-change="select_month" phx-target={@myself} phx-submit="ignore" style="flex: 1;">
                        <select name="month">
                          <%= for month <- 1..12 do %>
                            <option value={month} selected={@page_data[:selected_month] == month}>
                              <%= Calendar.strftime(Date.new!(2024, month, 1), "%B") %>
                            </option>
                          <% end %>
                        </select>
                      </form>
                      <form phx-change="select_day" phx-target={@myself} phx-submit="ignore" style="flex: 0 0 80px;">
                        <select name="day">
                          <%= for day <- 1..31 do %>
                            <option value={day} selected={@page_data[:selected_day] && @page_data[:selected_day].day == day}>
                              <%= day %>
                            </option>
                          <% end %>
                        </select>
                      </form>
                    </div>
                    <div style="text-align: center; margin-top: 10px; font-weight: bold; font-size: 14px;">
                      <%= if @page_data[:selected_day] do %>
                        <%= Calendar.strftime(@page_data[:selected_day], "%B %d, %Y") %>
                      <% else %>
                        Select a date
                      <% end %>
                    </div>
                  </div>

                  <%!-- Filters --%>
                  <div class="filter-group">
                    <label>Plant Type:</label>
                    <form phx-change="select_plant_type" phx-target={@myself} phx-submit="ignore">
                      <select name="type">
                        <option value="all" selected={@page_data[:selected_plant_type] == "all"}>All Types</option>
                        <option value="vegetable" selected={@page_data[:selected_plant_type] == "vegetable"}>Vegetables</option>
                        <option value="herb" selected={@page_data[:selected_plant_type] == "herb"}>Herbs</option>
                        <option value="fruit" selected={@page_data[:selected_plant_type] == "fruit"}>Fruits</option>
                        <option value="flower" selected={@page_data[:selected_plant_type] == "flower"}>Flowers</option>
                      </select>
                    </form>
                  </div>

                  <div class="filter-group">
                    <label>Difficulty:</label>
                    <form phx-change="select_difficulty" phx-target={@myself} phx-submit="ignore">
                      <select name="difficulty">
                        <option value="all" selected={@page_data[:selected_difficulty] == "all"}>All Levels</option>
                        <option value="easy" selected={@page_data[:selected_difficulty] == "easy"}>Easy</option>
                        <option value="medium" selected={@page_data[:selected_difficulty] == "medium"}>Medium</option>
                        <option value="hard" selected={@page_data[:selected_difficulty] == "hard"}>Hard</option>
                      </select>
                    </form>
                  </div>

                  <%!-- Companion Planting Filter --%>
                  <div class="filter-group" style="margin-top: 20px; border-top: 2px solid #000; padding-top: 15px;">
                    <label style="color: #2E7D32;">Companion Planting:</label>
                    <div style="font-size: 11px; margin-bottom: 10px; color: #555;">
                      Select a plant to highlight its friends (green) and foes (red).
                    </div>
                    
                    <%= if @page_data[:selected_companion_plant] do %>
                      <div style="background: #E8F5E9; border: 2px solid #2E7D32; padding: 10px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                          <span style="font-weight: bold;"><%= @page_data[:selected_companion_plant].common_name %></span>
                          <div style="font-size: 10px;">Showing relationships</div>
                        </div>
                        <button phx-click="clear_companion_filter" phx-target={@myself} style="background: #FFF; border: 1px solid #2E7D32; cursor: pointer; padding: 2px 6px; font-size: 10px;">Clear</button>
                      </div>
                    <% end %>

                    <form phx-change="toggle_companion_filter" phx-target={@myself} phx-submit="ignore">
                      <select name="plant_id">
                        <option value="">-- Highlight Companions For... --</option>
                        <%= for plant <- @page_data[:all_plants] || [] do %>
                          <option value={plant.id} selected={@page_data[:selected_companion_plant] && @page_data[:selected_companion_plant].id == plant.id}>
                            <%= plant.common_name %>
                          </option>
                        <% end %>
                      </select>
                    </form>
                  </div>
                </div>

                <%!-- Resizer Handle --%>
                <div id="planting-guide-resizer" class="planting-guide-resizer" phx-hook="PlantingGuideResizer">
                  <div class="resizer-handle">↕</div>
                </div>

                <%!-- Plants Grid --%>
                <div class="plants-grid-container">
                  <div style="margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center;">
                    <h2 style="font-family: Georgia, 'Times New Roman', serif; margin: 0; font-size: 18px;">
                      Available Plants (<%= length(@page_data[:filtered_plants] || []) %>)
                    </h2>
                    
                    <%!-- View Toggle --%>
                    <div style="display: flex; border: 2px solid #000;">
                      <button phx-click="set_view_mode" phx-value-mode="grid" phx-target={@myself}
                              style={"padding: 5px 10px; cursor: pointer; background: #{if @page_data[:view_mode] == "grid", do: "#000", else: "#FFF"}; color: #{if @page_data[:view_mode] == "grid", do: "#FFF", else: "#000"}; border: none; font-family: monospace;"}>
                        GRID
                      </button>
                      <button phx-click="set_view_mode" phx-value-mode="list" phx-target={@myself}
                              style={"padding: 5px 10px; cursor: pointer; background: #{if @page_data[:view_mode] == "list", do: "#000", else: "#FFF"}; color: #{if @page_data[:view_mode] == "list", do: "#FFF", else: "#000"}; border: none; font-family: monospace;"}>
                        LIST
                      </button>
                    </div>
                  </div>

                  <%= if @page_data[:filtered_plants] && length(@page_data[:filtered_plants]) > 0 do %>
                    <%= if @page_data[:view_mode] == "list" do %>
                      <%!-- List View --%>
                      <div style="display: flex; flex-direction: column; gap: 10px;">
                        <%= for plant <- @page_data[:filtered_plants] do %>
                          <% 
                            # Determine companion status style
                            companion_style = 
                              cond do
                                @page_data[:selected_companion_plant] && plant.id == @page_data[:selected_companion_plant].id ->
                                  "border-color: #000; background: #FFF; box-shadow: 0 0 10px rgba(0,0,0,0.5);"
                                @page_data[:selected_companion_plant] && plant.id in (@page_data[:good_companion_ids] || []) ->
                                  "border-color: #2E7D32; background: #E8F5E9;"
                                @page_data[:selected_companion_plant] && plant.id in (@page_data[:bad_companion_ids] || []) ->
                                  "border-color: #C62828; background: #FFEBEE;"
                                true -> ""
                              end
                              
                            # Determine companion group pattern class
                            companion_group_class = ""
                          %>
                          <div class={"plant-card #{companion_group_class}"} phx-click="view_plant_details" phx-value-plant_id={plant.id} phx-target={@myself} style={companion_style}>
                            <div class="plant-type-sidebar">
                              <span class="plant-type-text"><%= String.upcase(plant.plant_type) %></span>
                            </div>
                            <div class="plant-card-content" style="display: flex; justify-content: space-between; align-items: center;">
                              <div>
                                <h3 style="border: none; margin: 0;"><%= plant.common_name %></h3>
                                <div style="font-size: 11px; color: #666;"><%= plant.scientific_name %></div>
                              </div>
                              <div style="text-align: right;">
                                <div style="font-weight: bold; font-size: 12px;">
                                  <%= if plant.days_to_harvest_min, do: "#{plant.days_to_harvest_min} days", else: "N/A" %>
                                </div>
                                <div style="font-size: 10px;">to harvest</div>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% else %>
                      <%!-- Grid View --%>
                      <div class="plants-grid">
                        <%= for plant <- @page_data[:filtered_plants] do %>
                          <% 
                            # Determine companion status style
                            companion_style = 
                              cond do
                                @page_data[:selected_companion_plant] && plant.id == @page_data[:selected_companion_plant].id ->
                                  "border-color: #000; background: #FFF; box-shadow: 0 0 10px rgba(0,0,0,0.5);"
                                @page_data[:selected_companion_plant] && plant.id in (@page_data[:good_companion_ids] || []) ->
                                  "border-color: #2E7D32; background: #E8F5E9;"
                                @page_data[:selected_companion_plant] && plant.id in (@page_data[:bad_companion_ids] || []) ->
                                  "border-color: #C62828; background: #FFEBEE;"
                                true -> ""
                              end
                              
                            # Determine companion group pattern class
                            companion_group_class = ""
                          %>
                          <div class={"plant-card #{companion_group_class}"} phx-click="view_plant_details" phx-value-plant_id={plant.id} phx-target={@myself} style={companion_style}>
                            <div class="plant-type-sidebar">
                              <span class="plant-type-text"><%= String.upcase(plant.plant_type) %></span>
                            </div>
                            <div class="plant-card-content">
                              <h3><%= plant.common_name %></h3>
                              <div class="plant-info">
                                <p><strong>Scientific:</strong> <%= plant.scientific_name %></p>
                                <p><strong>Family:</strong> <%= plant.plant_family %></p>
                                <p><strong>Spacing:</strong> <%= plant.space_required %>"</p>
                                <p><strong>Sun:</strong> <%= plant.sunlight_needs %></p>
                              </div>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% else %>
                    <div style="text-align: center; padding: 40px; color: #666; font-style: italic;">
                      No plants match your current filters. Try adjusting the climate zone or date.
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- Plant Details Modal --%>
              <%= if @page_data[:selected_plant] do %>
                <div class="modal-overlay" phx-click="clear_plant_details" phx-target={@myself}>
                  <div class="modal-content" phx-click="stop_propagation" phx-target={@myself}>
                    <button class="modal-close-btn" phx-click="clear_plant_details" phx-target={@myself}>X</button>
                    
                    <div style="display: flex; gap: 20px; flex-wrap: wrap;">
                      <div style="flex: 1; min-width: 300px;">
                        <h2 style="font-family: Georgia, 'Times New Roman', serif; font-size: 28px; margin-top: 0; border-bottom: 4px solid #000; padding-bottom: 10px;">
                          <%= @page_data[:selected_plant].common_name %>
                        </h2>
                        <div style="font-style: italic; margin-bottom: 20px; font-size: 16px;"><%= @page_data[:selected_plant].scientific_name %></div>
                        
                        <div style="background: #EEE; padding: 15px; border: 2px solid #000; margin-bottom: 20px;">
                          <h3 style="margin-top: 0;">Quick Facts</h3>
                          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; font-size: 14px;">
                            <div><strong>Type:</strong> <%= String.capitalize(@page_data[:selected_plant].plant_type) %></div>
                            <div><strong>Family:</strong> <%= @page_data[:selected_plant].plant_family %></div>
                            <div><strong>Difficulty:</strong> <%= String.capitalize(@page_data[:selected_plant].growing_difficulty) %></div>
                            <div><strong>Life Cycle:</strong> <%= String.capitalize(@page_data[:selected_plant].perennial_annual) %></div>
                            <div><strong>Sun:</strong> <%= @page_data[:selected_plant].sunlight_needs %></div>
                            <div><strong>Water:</strong> <%= @page_data[:selected_plant].water_needs %></div>
                          </div>
                        </div>

                        <div style="margin-bottom: 20px;">
                          <h3>Description</h3>
                          <p style="line-height: 1.6;"><%= @page_data[:selected_plant].description %></p>
                        </div>

                        <div style="margin-bottom: 20px;">
                          <h3>Growing Information</h3>
                          <ul style="line-height: 1.6;">
                            <li><strong>Sowing Method:</strong> <%= @page_data[:selected_plant].description %></li>
                            <li><strong>Depth:</strong> N/A inches</li>
                            <li><strong>Spacing:</strong> <%= @page_data[:selected_plant].space_required %> inches apart</li>
                            <li><strong>Days to Maturity:</strong> <%= @page_data[:selected_plant].days_to_harvest_min %> days</li>
                          </ul>
                        </div>
                      </div>

                      <div style="flex: 1; min-width: 300px;">
                        <div class="companions-section">
                          <h3>Good Companions (Friends)</h3>
                          <div class="companion-tags">
                            <%= for companion <- @page_data[:good_companions] || [] do %>
                              <div class="companion-tag good" phx-click="view_plant_details" phx-value-plant_id={companion.id} phx-target={@myself} style="cursor: pointer;">
                                <strong><%= companion.common_name %></strong>
                                <div style="font-size: 10px; margin-top: 2px;"><%= companion.relationship_notes %></div>
                              </div>
                            <% end %>
                            <%= if length(@page_data[:good_companions] || []) == 0 do %>
                              <div style="font-style: italic; color: #666;">No specific good companions listed.</div>
                            <% end %>
                          </div>

                          <h3>Bad Companions (Foes)</h3>
                          <div class="companion-tags">
                            <%= for companion <- @page_data[:bad_companions] || [] do %>
                              <div class="companion-tag bad" phx-click="view_plant_details" phx-value-plant_id={companion.id} phx-target={@myself} style="cursor: pointer;">
                                <strong><%= companion.common_name %></strong>
                                <div style="font-size: 10px; margin-top: 2px;"><%= companion.relationship_notes %></div>
                              </div>
                            <% end %>
                            <%= if length(@page_data[:bad_companions] || []) == 0 do %>
                              <div style="font-style: italic; color: #666;">No specific bad companions listed.</div>
                            <% end %>
                          </div>
                        </div>

                        <%!-- User Actions --%>
                        <div style="margin-top: 30px; border-top: 4px solid #000; padding-top: 20px;">
                          <h3>My Garden Actions</h3>
                          
                          <% 
                            user_plant = Enum.find(@user_plants || [], fn up -> up.plant_id == @page_data[:selected_plant].id end)
                          %>
                          
                          <%= if user_plant do %>
                            <div style="background: #E8F5E9; border: 2px solid #2E7D32; padding: 15px;">
                              <div style="font-weight: bold; color: #2E7D32; margin-bottom: 10px;">✓ In Your Garden</div>
                              
                              <div style="margin-bottom: 10px;">
                                <label style="font-weight: bold; display: block; margin-bottom: 5px;">Status:</label>
                                <form phx-change="update_plant_status" phx-target={@myself}>
                                  <input type="hidden" name="plant_id" value={user_plant.id}>
                                  <select name="status" style="width: 100%; padding: 5px; border: 1px solid #000;">
                                    <option value="planned" selected={user_plant.status == "planned"}>Planned</option>
                                    <option value="planted" selected={user_plant.status == "planted"}>Planted</option>
                                    <option value="harvested" selected={user_plant.status == "harvested"}>Harvested</option>
                                  </select>
                                </form>
                              </div>

                              <div style="display: flex; gap: 10px;">
                                <button phx-click="delete_user_plant" phx-value-id={user_plant.id} phx-target={@myself}
                                        style="background: #FFEBEE; color: #C62828; border: 1px solid #C62828; padding: 5px 10px; cursor: pointer; font-weight: bold;">
                                  Remove from Garden
                                </button>
                              </div>
                            </div>
                          <% else %>
                            <button phx-click="add_plant_to_garden" phx-value-plant_id={@page_data[:selected_plant].id} phx-target={@myself}
                                    style="background: #000; color: #FFF; border: none; padding: 10px 20px; font-weight: bold; cursor: pointer; font-size: 16px; width: 100%;">
                              + Add to My Garden
                            </button>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
    </div>
    """
  end


  # ======================
  # Event Handlers
  # ======================

  @impl true
  def handle_event("select_city", %{"city_id" => city_id_str}, socket) do
    city_id = String.to_integer(city_id_str)
    city = PlantingGuide.get_city!(city_id)

    # Get frost dates if available
    frost_dates = PlantingGuide.get_frost_dates(city_id)

    page_data = socket.assigns.page_data || %{}

    # IMPORTANT: Preserve existing selections (month, plant_type, difficulty) when updating city
    existing_month = page_data[:selected_month]
    existing_day = page_data[:selected_day]
    existing_day_range_start = page_data[:selected_day_range_start]
    existing_day_range_end = page_data[:selected_day_range_end]
    existing_plant_type = page_data[:selected_plant_type] || "all"
    existing_difficulty = page_data[:selected_difficulty] || "all"

    Logger.info(
      "select_city event: city_id=#{city_id}, city_name=#{city.city_name}, hemisphere=#{city.hemisphere}, preserving month=#{inspect(existing_month)}, plant_type=#{existing_plant_type}, difficulty=#{existing_difficulty}"
    )

    # Default to today's date if no date/range/month is selected
    default_day =
      if existing_day || existing_day_range_start || existing_month,
        do: nil,
        else: Date.utc_today()

    # Update page_data with selected city
    page_data =
      page_data
      |> Map.put(:selected_city_id, city_id)
      |> Map.put(:selected_city, city)
      |> Map.put(:selected_climate_zone, city.koppen_code)
      |> Map.put(:city_frost_dates, frost_dates)
      |> Map.put(:selected_month, existing_month)
      |> Map.put(:selected_plant_type, existing_plant_type)
      |> Map.put(:selected_difficulty, existing_difficulty)
      |> Map.put(:selected_day, existing_day || default_day)
      |> Map.put(:selected_day_range_start, existing_day_range_start)
      |> Map.put(:selected_day_range_end, existing_day_range_end)
      |> Map.put(:planting_calculation, nil)

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

    # Extract month from params
    month = Map.get(params, "month", "") |> String.trim()
    month = if month == "", do: nil, else: month

    current_city = page_data[:selected_city]
    current_city_id = page_data[:selected_city_id]

    page_data =
      cond do
        # Case 1: We have city_id but city struct is missing - reload it
        current_city_id && is_nil(current_city) ->
          try do
            city = PlantingGuide.get_city!(current_city_id)

            page_data
            |> Map.put(:selected_city, city)
            |> Map.put(:selected_climate_zone, city.koppen_code)
            |> Map.put(:selected_month, month)
          rescue
            e ->
              Logger.warn(
                "Failed to reload city from ID: #{current_city_id}, error: #{inspect(e)}"
              )

              Map.put(page_data, :selected_month, month)
          end

        # Case 2: We have both - preserve everything, just update month
        current_city_id && current_city ->
          Map.put(page_data, :selected_month, month)

        # Case 3: Neither exists - just update month
        true ->
          Map.put(page_data, :selected_month, month)
      end

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_plant_type", %{"type" => type}, socket) do
    page_data = socket.assigns.page_data || %{}

    # Preserve existing selections
    existing_city_id = page_data[:selected_city_id]
    existing_city = page_data[:selected_city]
    existing_day = page_data[:selected_day]
    existing_day_range_start = page_data[:selected_day_range_start]
    existing_day_range_end = page_data[:selected_day_range_end]
    existing_difficulty = page_data[:selected_difficulty] || "all"

    # Update page_data with selected plant type
    page_data =
      page_data
      |> Map.put(:selected_plant_type, type)
      |> Map.put(:selected_city_id, existing_city_id)
      |> Map.put(:selected_city, existing_city)
      |> Map.put(:selected_day, existing_day)
      |> Map.put(:selected_day_range_start, existing_day_range_start)
      |> Map.put(:selected_day_range_end, existing_day_range_end)
      |> Map.put(:selected_difficulty, existing_difficulty)

    # Update socket and re-filter plants
    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("ignore", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_day_with_shift", params, socket) do
    handle_event("select_day", Map.put(params, "shift_key", "true"), socket)
  end

  @impl true
  def handle_event("select_day", params, socket) do
    page_data = socket.assigns.page_data || %{}

    year = String.to_integer(params["year"])
    month = String.to_integer(params["month"])
    day = String.to_integer(params["day"])

    clicked_date = Date.new!(year, month, day)

    range_start = page_data[:selected_day_range_start]
    range_end = page_data[:selected_day_range_end]
    selected_day = page_data[:selected_day]

    shift_key = params["shift_key"] == "true" || params["shift_key"] == true

    cond do
      # Shift-click with single day selected - create range
      shift_key && selected_day && !range_start ->
        {actual_start, actual_end} =
          if Date.compare(selected_day, clicked_date) == :gt do
            {clicked_date, selected_day}
          else
            {selected_day, clicked_date}
          end

        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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
        {actual_start, actual_end} =
          if Date.compare(range_start, clicked_date) == :gt do
            {clicked_date, range_start}
          else
            {range_start, clicked_date}
          end

        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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
        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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
        {actual_start, actual_end} =
          if Date.compare(range_start, clicked_date) == :gt do
            {clicked_date, range_start}
          else
            {range_start, clicked_date}
          end

        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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
        {actual_start, actual_end} =
          if Date.compare(selected_day, clicked_date) == :gt do
            {clicked_date, selected_day}
          else
            {selected_day, clicked_date}
          end

        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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
        existing_plant_type = page_data[:selected_plant_type] || "all"
        existing_difficulty = page_data[:selected_difficulty] || "all"

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

    existing_plant_type = page_data[:selected_plant_type] || "all"
    existing_difficulty = page_data[:selected_difficulty] || "all"

    page_data =
      page_data
      |> Map.put(:selected_day, nil)
      |> Map.put(:selected_day_range_start, nil)
      |> Map.put(:selected_day_range_end, nil)
      |> Map.put(:selected_plant_type, existing_plant_type)
      |> Map.put(:selected_difficulty, existing_difficulty)

    socket =
      socket
      |> assign(:page_data, page_data)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_difficulty", %{"difficulty" => difficulty}, socket) do
    page_data = socket.assigns.page_data || %{}

    existing_city_id = page_data[:selected_city_id]
    existing_city = page_data[:selected_city]
    existing_day = page_data[:selected_day]
    existing_day_range_start = page_data[:selected_day_range_start]
    existing_day_range_end = page_data[:selected_day_range_end]
    existing_plant_type = page_data[:selected_plant_type] || "all"

    page_data =
      page_data
      |> Map.put(:selected_difficulty, difficulty)
      |> Map.put(:selected_city_id, existing_city_id)
      |> Map.put(:selected_city, existing_city)
      |> Map.put(:selected_day, existing_day)
      |> Map.put(:selected_day_range_start, existing_day_range_start)
      |> Map.put(:selected_day_range_end, existing_day_range_end)
      |> Map.put(:selected_plant_type, existing_plant_type)

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

    good_companions = PlantingGuide.get_companions(plant_id, "good")
    bad_companions = PlantingGuide.get_companions(plant_id, "bad")

    companion_plants = %{
      good: good_companions,
      bad: bad_companions
    }

    page_data = socket.assigns.page_data

    planting_calculation =
      if page_data[:selected_city] && page_data[:city_frost_dates] do
        city_id = page_data.selected_city.id
        PlantingGuide.calculate_planting_date(city_id, plant_id)
      else
        nil
      end

    companion_group_id =
      case Enum.find(page_data[:filtered_plants] || [], &(&1.id == plant.id)) do
        nil -> nil
        filtered_plant -> Map.get(filtered_plant, :companion_group_id)
      end

    user_plant =
      if socket.assigns[:current_user] do
        case PlantingGuide.get_user_plant(socket.assigns.current_user.id, plant_id) do
          nil -> nil
          up -> PlantingGuide.preload_plant(up)
        end
      else
        nil
      end

    page_data =
      page_data
      |> Map.put(:selected_plant, plant)
      |> Map.put(:companion_plants, companion_plants)
      |> Map.put(:planting_calculation, planting_calculation)
      |> Map.put(:selected_plant_group_id, companion_group_id)
      |> Map.put(:selected_user_plant, user_plant)

    {:noreply, assign(socket, :page_data, page_data)}
  end

  @impl true
  def handle_event("clear_plant_details", _params, socket) do
    page_data = socket.assigns.page_data

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
    page_data = Map.put(page_data, :filter_companion_group, true)
    socket = assign(socket, :page_data, page_data)
    socket = filter_planting_guide_plants(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_all", _params, socket) do
    page_data = socket.assigns.page_data
    page_data = Map.put(page_data, :filter_companion_group, false)
    socket = assign(socket, :page_data, page_data)
    socket = filter_planting_guide_plants(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_planting_method", %{"method" => method}, socket) do
    method_atom =
      case method do
        "seeds" -> :seeds
        "seedlings" -> :seedlings
        _ -> :seeds
      end

    socket =
      socket
      |> assign(:planting_method, method_atom)
      |> filter_planting_guide_plants()

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_harvest_date", %{"plant-id" => plant_id_str}, socket) do
    plant_id = String.to_integer(plant_id_str)
    {:noreply, assign(socket, editing_harvest_date: true, editing_plant_id: plant_id)}
  end

  @impl true
  def handle_event("save_harvest_override", %{"plant-id" => plant_id_str} = params, socket) do
    unless socket.assigns[:current_user] do
      {:noreply, put_flash(socket, :error, "Please log in to edit harvest dates")}
    else
      plant_id = String.to_integer(plant_id_str)
      user = socket.assigns.current_user

      date_string = Map.get(params, "harvest_date_override") || Map.get(params, "value")

      if date_string && date_string != "" do
        case Date.from_iso8601(date_string) do
          {:ok, override_date} ->
            case PlantingGuide.get_user_plant(user.id, plant_id) do
              nil ->
                {:noreply, put_flash(socket, :error, "Plant not found in your garden")}

              user_plant ->
                case PlantingGuide.update_user_plant(user_plant, %{
                       harvest_date_override: override_date
                     }) do
                  {:ok, _updated_plant} ->
                    updated_plants = PlantingGuide.list_user_plants(user.id)

                    page_data = socket.assigns.page_data

                    updated_page_data =
                      if page_data[:selected_plant] && page_data[:selected_plant].id == plant_id do
                        case PlantingGuide.get_user_plant(user.id, plant_id) do
                          nil ->
                            Map.put(page_data, :selected_user_plant, nil)

                          up ->
                            Map.put(page_data, :selected_user_plant, PlantingGuide.preload_plant(up))
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

                updated_page_data =
                  if page_data[:selected_plant] && page_data[:selected_plant].id == plant_id do
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
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_plant_status", %{"plant_id" => plant_id_str, "status" => status}, socket) do
    unless socket.assigns[:current_user] do
      {:noreply, put_flash(socket, :error, "Please log in to track plants")}
    else
      plant_id = String.to_integer(plant_id_str)
      user = socket.assigns.current_user
      page_data = socket.assigns.page_data || %{}
      city = page_data[:selected_city]
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
          old_user_plant = PlantingGuide.get_user_plant(user.id, plant_id)
          old_status = if old_user_plant, do: old_user_plant.status, else: nil

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
                {:ok, _user_plant} ->
                  updated_plants = PlantingGuide.list_user_plants(user.id)

                  socket =
                    socket
                    |> assign(:user_plants, updated_plants)
                    |> put_flash(:info, "Added #{plant.common_name} to your garden!")

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

                  socket =
                    handle_quest_generation(
                      socket,
                      user.id,
                      plant_id,
                      old_status,
                      status,
                      planting_date || updated_plant.planting_date_start || updated_plant.planting_date_end
                    )

                  {:noreply, socket}

                {:error, _changeset} ->
                  {:noreply, put_flash(socket, :error, "Could not update status")}
              end
          end
      end
    end
  end

  # ======================
  # Helper Functions
  # ======================

  defp calculate_planting_start(socket) do
    page_data = socket.assigns.page_data || %{}
    selected_day = page_data[:selected_day]
    selected_day_range_start = page_data[:selected_day_range_start]
    selected_month = page_data[:selected_month]

    cond do
      selected_day ->
        selected_day

      selected_day_range_start ->
        selected_day_range_start

      selected_month ->
        month_num = month_name_to_number(selected_month)
        Date.new!(Date.utc_today().year, month_num, 1)

      true ->
        Date.utc_today()
    end
  end

  defp calculate_planting_end(socket) do
    start = calculate_planting_start(socket)
    page_data = socket.assigns.page_data || %{}
    selected_day_range_end = page_data[:selected_day_range_end]

    if selected_day_range_end do
      selected_day_range_end
    else
      Date.add(start, 14)
    end
  end

  defp handle_quest_generation(socket, user_id, plant_id, old_status, new_status, planting_date) do
    case PlantingQuestManager.handle_plant_status_change(
           user_id,
           plant_id,
           old_status || "interested",
           new_status,
           planting_date
         ) do
      {:ok, quest} ->
        Logger.info("[PlantQuest] ✅ Quest updated: #{quest.title}")

        Phoenix.PubSub.broadcast(
          GreenManTavern.PubSub,
          "user:#{user_id}",
          {:quest_updated, user_id}
        )

        put_flash(socket, :info, "Quest updated: #{quest.title}")

      {:ok, :no_action} ->
        socket

      {:error, reason} ->
        Logger.warning("[PlantQuest] ⚠️ Quest update failed: #{inspect(reason)}")
        socket
    end
  end

  defp month_name_to_number(month_name) do
    months = %{
      "Jan" => 1,
      "Feb" => 2,
      "Mar" => 3,
      "Apr" => 4,
      "May" => 5,
      "Jun" => 6,
      "Jul" => 7,
      "Aug" => 8,
      "Sep" => 9,
      "Oct" => 10,
      "Nov" => 11,
      "Dec" => 12
    }

    Map.get(months, month_name, 1)
  end

  defp generate_calendar_month(month_number, year) when month_number in 1..12 do
    first_date = Date.new!(year, month_number, 1)
    last_day = Date.end_of_month(first_date)

    month_names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ]

    days =
      1..last_day.day
      |> Enum.map(fn day ->
        date = Date.new!(year, month_number, day)
        day_of_week = Date.day_of_week(date, :monday)

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

  defp date_in_planting_string?(date, months_str, _hemisphere)
       when is_struct(date, Date) and is_binary(months_str) do
    month_abbr = month_abbreviation_from_number(date.month)
    month_in_planting_string?(month_abbr, months_str)
  end

  defp date_in_planting_string?(_, _, _), do: false

  defp date_range_in_planting_string?(start_date, end_date, months_str, hemisphere)
       when is_struct(start_date, Date) and is_struct(end_date, Date) do
    Date.range(start_date, end_date)
    |> Enum.any?(fn date ->
      date_in_planting_string?(date, months_str, hemisphere)
    end)
  end

  defp date_range_in_planting_string?(_, _, _, _), do: false

  defp month_in_planting_string?(month, months_str)
       when is_binary(month) and is_binary(months_str) do
    if months_str == "" do
      false
    else
      normalized = String.replace(months_str, "/", ",")

      normalized
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.any?(fn range_or_month ->
        if String.contains?(range_or_month, "-") do
          parts = String.split(range_or_month, "-") |> Enum.map(&String.trim/1)

          case parts do
            [start_month, end_month] ->
              month_in_range?(month, start_month, end_month)

            [single] ->
              single == month

            _ ->
              false
          end
        else
          range_or_month == month
        end
      end)
    end
  end

  defp month_in_planting_string?(_, _), do: false

  defp month_in_range?(month, start_month, end_month) do
    month_order = %{
      "Jan" => 1,
      "Feb" => 2,
      "Mar" => 3,
      "Apr" => 4,
      "May" => 5,
      "Jun" => 6,
      "Jul" => 7,
      "Aug" => 8,
      "Sep" => 9,
      "Oct" => 10,
      "Nov" => 11,
      "Dec" => 12
    }

    month_num = Map.get(month_order, month)
    start_num = Map.get(month_order, start_month)
    end_num = Map.get(month_order, end_month)

    cond do
      month_num && start_num && end_num ->
        if start_num <= end_num do
          month_num >= start_num && month_num <= end_num
        else
          month_num >= start_num || month_num <= end_num
        end

      month == start_month || month == end_month ->
        true

      true ->
        false
    end
  end

  defp filter_planting_guide_plants(socket) do
    page_data = socket.assigns.page_data || %{}
    all_plants = page_data[:all_plants] || []

    plants = all_plants

    # Filter by climate zone
    selected_climate_zone = page_data[:selected_climate_zone]

    plants =
      if selected_climate_zone do
        Enum.filter(plants, fn plant ->
          plant_climate_zones = plant.climate_zones || []
          selected_climate_zone in plant_climate_zones
        end)
      else
        plants
      end

    # Filter by day/range/month
    selected_day = page_data[:selected_day]
    selected_day_range_start = page_data[:selected_day_range_start]
    selected_day_range_end = page_data[:selected_day_range_end]
    selected_month = page_data[:selected_month]
    selected_city = page_data[:selected_city]

    plants =
      cond do
        selected_day && selected_city ->
          hemisphere = selected_city.hemisphere

          Enum.filter(plants, fn plant ->
            months_str =
              if hemisphere == "Southern" do
                plant.planting_months_sh || ""
              else
                plant.planting_months_nh || ""
              end

            date_in_planting_string?(selected_day, months_str, hemisphere)
          end)

        selected_day_range_start && selected_day_range_end && selected_city ->
          hemisphere = selected_city.hemisphere

          Enum.filter(plants, fn plant ->
            months_str =
              if hemisphere == "Southern" do
                plant.planting_months_sh || ""
              else
                plant.planting_months_nh || ""
              end

            date_range_in_planting_string?(
              selected_day_range_start,
              selected_day_range_end,
              months_str,
              hemisphere
            )
          end)

        selected_month && selected_city ->
          hemisphere = selected_city.hemisphere

          Enum.filter(plants, fn plant ->
            months_str =
              if hemisphere == "Southern" do
                plant.planting_months_sh || ""
              else
                plant.planting_months_nh || ""
              end

            month_in_planting_string?(selected_month, months_str)
          end)

        true ->
          plants
      end

    # Filter by plant type
    selected_plant_type = page_data[:selected_plant_type] || "all"

    plants =
      if selected_plant_type != "all" do
        Enum.filter(plants, fn plant ->
          plant_type = plant.plant_type || ""

          cond do
            selected_plant_type == "Native" ->
              String.starts_with?(plant_type, "Native")

            true ->
              plant_type == selected_plant_type
          end
        end)
      else
        plants
      end

    # Filter by difficulty
    selected_difficulty = page_data[:selected_difficulty] || "all"

    plants =
      if selected_difficulty != "all" do
        Enum.filter(plants, fn plant ->
          difficulty = plant.growing_difficulty || ""
          difficulty == selected_difficulty
        end)
      else
        plants
      end

    # Filter by planting method
    plants =
      if socket.assigns[:planting_method] == :seedlings do
        Enum.filter(plants, fn plant ->
          Plant.can_transplant?(plant)
        end)
      else
        plants
      end

    # Enrich with companion groups
    plants = enrich_plants_with_companion_groups(plants)

    # Filter by companion group
    plants =
      if page_data[:filter_companion_group] == true && page_data[:selected_plant_group_id] do
        target_group_id = page_data[:selected_plant_group_id]

        Enum.filter(plants, fn plant ->
          plant_group_id = Map.get(plant, :companion_group_id)
          plant_group_id == target_group_id
        end)
      else
        plants
      end

    page_data = Map.put(page_data, :filtered_plants, plants)
    assign(socket, :page_data, page_data)
  end

  defp enrich_plants_with_companion_groups(plants) do
    if Enum.empty?(plants) do
      plants
    else
      plant_ids = Enum.map(plants, & &1.id)

      good_relationships = get_all_good_relationships(plant_ids)
      bad_relationships = get_all_bad_relationships(plant_ids)

      plants_with_relationships =
        get_plants_with_relationships(plant_ids, good_relationships, bad_relationships)

      if Enum.empty?(plants_with_relationships) do
        Enum.map(plants, fn plant -> Map.put(plant, :companion_group_id, nil) end)
      else
        good_graph = build_adjacency_map(good_relationships)
        groups = find_companion_groups(plants_with_relationships, good_graph, bad_relationships)

        Enum.map(plants, fn plant ->
          if plant.id in plants_with_relationships do
            group_id = Map.get(groups, plant.id)
            Map.put(plant, :companion_group_id, group_id)
          else
            Map.put(plant, :companion_group_id, nil)
          end
        end)
      end
    end
  end

  defp get_all_good_relationships(plant_ids) when is_list(plant_ids) do
    import Ecto.Query

    CompanionRelationship
    |> where([cr], cr.relationship_type == "good")
    |> where([cr], cr.plant_a_id in ^plant_ids)
    |> where([cr], cr.plant_b_id in ^plant_ids)
    |> select([cr], {cr.plant_a_id, cr.plant_b_id})
    |> Repo.all()
  end

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

  defp get_plants_with_relationships(_plant_ids, good_relationships, bad_relationships) do
    good_plant_ids =
      good_relationships
      |> Enum.flat_map(fn {a_id, b_id} -> [a_id, b_id] end)
      |> MapSet.new()

    bad_plant_ids =
      bad_relationships
      |> Enum.flat_map(fn {a_id, b_id} -> [a_id, b_id] end)
      |> MapSet.new()

    MapSet.union(good_plant_ids, bad_plant_ids)
    |> MapSet.to_list()
  end

  defp build_adjacency_map(relationships) do
    relationships
    |> Enum.reduce(%{}, fn {a_id, b_id}, acc ->
      acc
      |> Map.update(a_id, MapSet.new([b_id]), &MapSet.put(&1, b_id))
      |> Map.update(b_id, MapSet.new([a_id]), &MapSet.put(&1, a_id))
    end)
  end

  defp find_companion_groups(plant_ids, good_graph, bad_relationships) do
    find_companion_groups_recursive(plant_ids, good_graph, bad_relationships, MapSet.new(), %{}, 1)
  end

  defp find_companion_groups_recursive([], _graph, _bad_relationships, _visited, groups, _next_id),
    do: groups

  defp find_companion_groups_recursive(
         [plant_id | rest],
         graph,
         bad_relationships,
         visited,
         groups,
         next_id
       ) do
    if MapSet.member?(visited, plant_id) do
      find_companion_groups_recursive(rest, graph, bad_relationships, visited, groups, next_id)
    else
      {component, new_visited} =
        find_connected_component(plant_id, graph, bad_relationships, visited, [])

      new_groups = Enum.reduce(component, groups, fn pid, g -> Map.put(g, pid, next_id) end)

      find_companion_groups_recursive(
        rest,
        graph,
        bad_relationships,
        new_visited,
        new_groups,
        next_id + 1
      )
    end
  end

  defp find_connected_component(start_id, graph, bad_relationships, visited, component) do
    if MapSet.member?(visited, start_id) do
      {component, visited}
    else
      neighbors = Map.get(graph, start_id, MapSet.new())
      new_visited = MapSet.put(visited, start_id)
      new_component = [start_id | component]

      valid_neighbors =
        Enum.filter(neighbors, fn neighbor_id ->
          !MapSet.member?(new_visited, neighbor_id) and
            !has_bad_relationship_with_any(neighbor_id, new_component, bad_relationships)
        end)

      {final_component, final_visited} =
        Enum.reduce(valid_neighbors, {new_component, new_visited}, fn neighbor_id,
                                                                       {acc_component,
                                                                        acc_visited} ->
          find_connected_component(neighbor_id, graph, bad_relationships, acc_visited, acc_component)
        end)

      {final_component, final_visited}
    end
  end

  defp has_bad_relationship_with_any(plant_id, plant_list, bad_relationships) do
    Enum.any?(plant_list, fn other_id ->
      MapSet.member?(bad_relationships, {plant_id, other_id}) or
        MapSet.member?(bad_relationships, {other_id, plant_id})
    end)
  end
end
