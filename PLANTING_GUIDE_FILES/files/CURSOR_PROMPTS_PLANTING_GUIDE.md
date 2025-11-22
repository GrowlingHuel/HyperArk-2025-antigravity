# CURSOR AI PROMPTS - PLANTING GUIDE DATABASE IMPLEMENTATION

These prompts are ready to paste directly into Cursor.AI to build the Living Web planting guide system.

---

## 🗂️ PROMPT 1: Create Database Migrations

```
Create four Phoenix Ecto migrations for the Living Web planting guide system.

Migration 1: create_koppen_zones.exs
- Table: koppen_zones
- Fields:
  * id (primary key, auto-increment)
  * code (string, max 3 chars, unique, not null) - Köppen code like "Cfb"
  * name (string, max 100 chars) - "Oceanic" 
  * category (string, max 20 chars) - "Temperate"
  * description (text) - Climate characteristics
  * temperature_pattern (text) - Temperature profile
  * precipitation_pattern (text) - Rainfall distribution
  * inserted_at, updated_at (timestamps)
- Indexes: code (unique)

Migration 2: create_cities.exs
- Table: cities
- Fields:
  * id (primary key)
  * city_name (string, max 100)
  * country (string, max 100)
  * state_province_territory (string, max 100, nullable)
  * latitude (decimal, precision 10, scale 7, nullable)
  * longitude (decimal, precision 10, scale 7, nullable)
  * koppen_code (string, max 3, references koppen_zones.code)
  * hemisphere (string, max 10) - "Northern" or "Southern"
  * notes (text, nullable)
  * inserted_at, updated_at
- Indexes: city_name, country, koppen_code (foreign key)

Migration 3: create_plants.exs
- Table: plants
- Fields:
  * id (primary key)
  * common_name (string, max 100, not null)
  * scientific_name (string, max 150, nullable)
  * plant_family (string, max 100, nullable)
  * plant_type (string, max 50) - "Vegetable", "Herb", etc.
  * climate_zones (array of strings) - PostgreSQL text array {:array, :string}
  * growing_difficulty (string, max 20) - "Easy", "Moderate", "Hard"
  * space_required (string, max 20)
  * sunlight_needs (string, max 20)
  * water_needs (string, max 20)
  * days_to_germination_min (integer, nullable)
  * days_to_germination_max (integer, nullable)
  * days_to_harvest_min (integer, nullable)
  * days_to_harvest_max (integer, nullable)
  * perennial_annual (string, max 20)
  * planting_months_sh (string, max 50) - "Sep-Nov"
  * planting_months_nh (string, max 50) - "Mar-May"
  * height_cm_min (integer, nullable)
  * height_cm_max (integer, nullable)
  * spread_cm_min (integer, nullable)
  * spread_cm_max (integer, nullable)
  * native_region (string, max 100, nullable)
  * description (text)
  * inserted_at, updated_at
- Indexes: common_name, plant_type, climate_zones (GIN index for array search)

Migration 4: create_companion_relationships.exs
- Table: companion_relationships
- Fields:
  * id (primary key)
  * plant_a_id (integer, references plants.id, on_delete: :delete_all)
  * plant_b_id (integer, references plants.id, on_delete: :delete_all)
  * relationship_type (string, max 10) - "good" or "bad"
  * evidence_level (string, max 20) - "scientific", "traditional_strong", "traditional_weak"
  * mechanism (text) - How the relationship works
  * notes (text, nullable)
  * inserted_at, updated_at
- Indexes: plant_a_id, plant_b_id, relationship_type
- Unique constraint: [plant_a_id, plant_b_id]

Follow Ecto migration best practices:
- Use proper timestamp prefixes
- Add all indexes
- Set up foreign key constraints properly
- Use correct Ecto types
```

---

## 🗂️ PROMPT 2: Create Ecto Schemas

```
Create four Ecto schemas in lib/green_man_tavern/planting_guide/ matching the migrations.

Schema 1: koppen_zone.ex
- Module: GreenManTavern.PlantingGuide.KoppenZone
- Maps to: koppen_zones table
- Fields: All from migration
- Changeset:
  * Required: code, name, category
  * Validate: code is max 3 chars, unique
  * Optional: description, temperature_pattern, precipitation_pattern

Schema 2: city.ex
- Module: GreenManTavern.PlantingGuide.City
- Maps to: cities table
- Fields: All from migration
- Associations:
  * belongs_to :koppen_zone, KoppenZone, foreign_key: :koppen_code, references: :code
- Changeset:
  * Required: city_name, country, koppen_code, hemisphere
  * Validate: hemisphere in ["Northern", "Southern"]
  * Optional: state_province_territory, latitude, longitude, notes

Schema 3: plant.ex
- Module: GreenManTavern.PlantingGuide.Plant
- Maps to: plants table
- Fields: All from migration (including climate_zones as array)
- Associations:
  * has_many :companion_relationships_a, CompanionRelationship, foreign_key: :plant_a_id
  * has_many :companion_relationships_b, CompanionRelationship, foreign_key: :plant_b_id
- Changeset:
  * Required: common_name, climate_zones (must be array)
  * Validate: climate_zones is non-empty array
  * Validate: growing_difficulty in ["Easy", "Moderate", "Hard"]
  * Optional: All other fields

Schema 4: companion_relationship.ex
- Module: GreenManTavern.PlantingGuide.CompanionRelationship
- Maps to: companion_relationships table
- Fields: All from migration
- Associations:
  * belongs_to :plant_a, Plant
  * belongs_to :plant_b, Plant
- Changeset:
  * Required: plant_a_id, plant_b_id, relationship_type, evidence_level
  * Validate: relationship_type in ["good", "bad"]
  * Validate: evidence_level in ["scientific", "traditional_strong", "traditional_weak"]
  * Validate: plant_a_id != plant_b_id (prevent self-reference)
  * Optional: mechanism, notes

Use proper Ecto conventions:
- @derive {Jason.Encoder, only: [list all fields]}
- Use cast and validate_required properly
- Add custom validators where needed
```

---

## 🗂️ PROMPT 3: Create Context Module

```
Create lib/green_man_tavern/planting_guide.ex context module with comprehensive query functions.

Module: GreenManTavern.PlantingGuide
Alias all schemas: KoppenZone, City, Plant, CompanionRelationship

FUNCTIONS TO IMPLEMENT:

## Köppen Zones
1. list_koppen_zones() 
   - Returns: All Köppen zones ordered by category then code

2. get_koppen_zone!(code)
   - Input: Köppen code string (e.g., "Cfb")
   - Returns: KoppenZone struct or raises
   
## Cities
3. list_cities(filters \\ %{})
   - Input: filters map with optional keys: country, koppen_code, hemisphere
   - Returns: List of City structs preloading :koppen_zone
   - Ordered by: country, city_name

4. get_city!(id)
   - Input: city ID
   - Returns: City with preloaded koppen_zone

5. get_cities_by_koppen(koppen_code)
   - Input: Köppen code
   - Returns: All cities in that climate zone

## Plants
6. list_plants(filters \\ %{})
   - Input: filters map with optional keys:
     * climate_zone (string) - searches climate_zones array
     * plant_type (string)
     * growing_difficulty (string)
     * hemisphere (string) - filters by planting_months_sh/nh presence
     * month (string) - filters by planting month (e.g., "Sep")
   - Returns: List of Plant structs
   - Ordered by: common_name
   - Use: Ecto.Query for complex array searching (? operator for climate_zones)

7. get_plant!(id)
   - Input: plant ID
   - Returns: Plant struct

8. search_plants(query_string)
   - Input: search term
   - Returns: Plants where common_name or scientific_name ILIKE query
   - Use: case-insensitive search

## Companion Relationships
9. get_companions(plant_id, relationship_type \\ nil)
   - Input: plant ID, optional relationship type ("good"/"bad")
   - Returns: List of Plant structs that are companions
   - Logic: Query companion_relationships where plant_a_id OR plant_b_id = plant_id
   - Preload: the other plant (if plant_a_id matches, return plant_b; vice versa)
   - Filter: by relationship_type if provided
   - Include: evidence_level, mechanism, notes in result

10. get_companion_details(plant_a_id, plant_b_id)
    - Input: Two plant IDs
    - Returns: CompanionRelationship struct if exists, nil otherwise
    - Check: both directions (A→B and B→A)

## Helper Functions
11. plants_for_city(city_id)
    - Input: city ID
    - Returns: All plants compatible with city's Köppen zone
    - Logic: Get city's koppen_code, then filter plants where code in climate_zones array

12. plants_plantable_now(city_id, month)
    - Input: city ID, month name (e.g., "Sep")
    - Returns: Plants compatible with city AND plantable in given month
    - Logic: Check city's hemisphere, then filter by appropriate planting_months field

Follow Ecto best practices:
- Use Repo.all, Repo.get, Repo.get_by
- Use Ecto.Query for complex queries
- Preload associations efficiently
- Handle empty results gracefully (return [])
- Add @doc for each function
```

---

## 🗂️ PROMPT 4: Create Seeds File

```
Create priv/repo/seeds/planting_guide.exs to populate the database from CSV files.

IMPORTANT: This seed file should:
1. Read CSV files from priv/repo/seeds/data/ directory
2. Parse CSV data properly
3. Insert records in correct order (respecting foreign keys)
4. Handle ranges like "7-14" → min: 7, max: 14
5. Handle arrays like "Cfa,Cfb,Csa" → ["Cfa", "Cfb", "Csa"]
6. Skip duplicates (check if record exists before inserting)
7. Print progress messages

STRUCTURE:

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{KoppenZone, City, Plant, CompanionRelationship}

# Helper function to parse ranges
defp parse_range(range_string) do
  case String.split(range_string, "-") do
    [min, max] -> {String.to_integer(min), String.to_integer(max)}
    [single] -> {String.to_integer(single), String.to_integer(single)}
    _ -> {nil, nil}
  end
end

# Helper to parse climate zones array
defp parse_climate_zones(zones_string) do
  zones_string
  |> String.split(",")
  |> Enum.map(&String.trim/1)
end

# 1. Seed Köppen Zones
IO.puts("Seeding Köppen zones...")
"priv/repo/seeds/data/koppen_climate_zones.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  case Repo.get_by(KoppenZone, code: row["code"]) do
    nil ->
      %KoppenZone{}
      |> KoppenZone.changeset(%{
        code: row["code"],
        name: row["name"],
        category: row["category"],
        description: row["description"],
        temperature_pattern: row["temperature_pattern"],
        precipitation_pattern: row["precipitation_pattern"]
      })
      |> Repo.insert!()
    _ ->
      :ok # Skip if exists
  end
end)

# 2. Seed Cities
IO.puts("Seeding cities...")
"priv/repo/seeds/data/world_cities_climate_zones.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  latitude = if row["latitude"], do: Decimal.new(row["latitude"]), else: nil
  longitude = if row["longitude"], do: Decimal.new(row["longitude"]), else: nil
  
  case Repo.get_by(City, city_name: row["city_name"], country: row["country"]) do
    nil ->
      %City{}
      |> City.changeset(%{
        city_name: row["city_name"],
        country: row["country"],
        state_province_territory: row["state_province_territory"],
        latitude: latitude,
        longitude: longitude,
        koppen_code: row["koppen_code"],
        hemisphere: row["hemisphere"],
        notes: row["notes"]
      })
      |> Repo.insert!()
    _ ->
      :ok
  end
end)

# 3. Seed Plants
IO.puts("Seeding plants...")
"priv/repo/seeds/data/plants_database_500.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  {germ_min, germ_max} = parse_range(row["days_to_germination"])
  {harvest_min, harvest_max} = parse_range(row["days_to_harvest"])
  {height_min, height_max} = parse_range(row["height_cm"])
  {spread_min, spread_max} = parse_range(row["spread_cm"])
  climate_zones = parse_climate_zones(row["climate_zones"])
  
  case Repo.get_by(Plant, common_name: row["common_name"], scientific_name: row["scientific_name"]) do
    nil ->
      %Plant{}
      |> Plant.changeset(%{
        common_name: row["common_name"],
        scientific_name: row["scientific_name"],
        plant_family: row["plant_family"],
        plant_type: row["plant_type"],
        climate_zones: climate_zones,
        growing_difficulty: row["growing_difficulty"],
        space_required: row["space_required"],
        sunlight_needs: row["sunlight_needs"],
        water_needs: row["water_needs"],
        days_to_germination_min: germ_min,
        days_to_germination_max: germ_max,
        days_to_harvest_min: harvest_min,
        days_to_harvest_max: harvest_max,
        perennial_annual: row["perennial_annual"],
        planting_months_sh: row["planting_months_sh"],
        planting_months_nh: row["planting_months_nh"],
        height_cm_min: height_min,
        height_cm_max: height_max,
        spread_cm_min: spread_min,
        spread_cm_max: spread_max,
        native_region: row["native_region"],
        description: row["description"]
      })
      |> Repo.insert!()
    _ ->
      :ok
  end
end)

# 4. Seed Companion Relationships
IO.puts("Seeding companion relationships...")
"priv/repo/seeds/data/companion_planting_relationships.csv"
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  plant_a = Repo.get_by(Plant, common_name: row["plant_a"])
  plant_b = Repo.get_by(Plant, common_name: row["plant_b"])
  
  if plant_a && plant_b do
    case Repo.get_by(CompanionRelationship, plant_a_id: plant_a.id, plant_b_id: plant_b.id) do
      nil ->
        %CompanionRelationship{}
        |> CompanionRelationship.changeset(%{
          plant_a_id: plant_a.id,
          plant_b_id: plant_b.id,
          relationship_type: row["relationship_type"],
          evidence_level: row["evidence_level"],
          mechanism: row["mechanism"],
          notes: row["notes"]
        })
        |> Repo.insert!()
      _ ->
        :ok
    end
  end
end)

IO.puts("✅ Planting guide database seeded successfully!")
```

---

## 🗂️ PROMPT 5: Update DualPanelLive for Planting Guide

```
Update lib/green_man_tavern_web/live/dual_panel_live.ex to integrate the planting guide using the PlantingGuide context.

ADD TO MOUNT FUNCTION (when right_panel_view == :planting_guide):

# Fetch initial data
koppen_zones = PlantingGuide.list_koppen_zones()
cities = PlantingGuide.list_cities()
plants = PlantingGuide.list_plants()

# Default selections
socket =
  socket
  |> assign(:koppen_zones, koppen_zones)
  |> assign(:cities, cities)
  |> assign(:all_plants, plants)
  |> assign(:filtered_plants, plants)
  |> assign(:selected_city, nil)
  |> assign(:selected_climate_zone, nil)
  |> assign(:selected_month, nil)
  |> assign(:selected_plant_type, "all")
  |> assign(:selected_difficulty, "all")
  |> assign(:selected_plant, nil)
  |> assign(:companion_plants, %{good: [], bad: []})

ADD EVENT HANDLERS:

1. handle_event("select_city", %{"city_id" => city_id}, socket)
   - Get city and its Köppen zone
   - Filter plants to those compatible with city's climate
   - Store selected_city and selected_climate_zone in socket
   - Re-filter plants

2. handle_event("select_month", %{"month" => month}, socket)
   - Store month in socket
   - Filter plants to those plantable in this month
   - Use city's hemisphere to check correct planting_months field

3. handle_event("select_plant_type", %{"type" => type}, socket)
   - Filter plants by plant_type
   - Re-filter based on all active filters

4. handle_event("select_difficulty", %{"difficulty" => difficulty}, socket)
   - Filter plants by growing_difficulty
   - Re-filter based on all active filters

5. handle_event("view_plant_details", %{"plant_id" => plant_id}, socket)
   - Get plant details
   - Fetch good and bad companions using PlantingGuide.get_companions/2
   - Assign to socket: selected_plant, companion_plants

HELPER FUNCTION:

defp filter_plants(socket) do
  plants = socket.assigns.all_plants
  
  # Filter by city/climate if selected
  plants = if socket.assigns.selected_climate_zone do
    Enum.filter(plants, fn plant ->
      socket.assigns.selected_climate_zone in plant.climate_zones
    end)
  else
    plants
  end
  
  # Filter by month if selected
  plants = if socket.assigns.selected_month && socket.assigns.selected_city do
    hemisphere = socket.assigns.selected_city.hemisphere
    month_field = if hemisphere == "Southern", do: :planting_months_sh, else: :planting_months_nh
    
    Enum.filter(plants, fn plant ->
      months = Map.get(plant, month_field, "")
      String.contains?(months, socket.assigns.selected_month)
    end)
  else
    plants
  end
  
  # Filter by type if selected
  plants = if socket.assigns.selected_plant_type != "all" do
    Enum.filter(plants, fn plant ->
      plant.plant_type == socket.assigns.selected_plant_type
    end)
  else
    plants
  end
  
  # Filter by difficulty if selected
  plants = if socket.assigns.selected_difficulty != "all" do
    Enum.filter(plants, fn plant ->
      plant.growing_difficulty == socket.assigns.selected_difficulty
    end)
  else
    plants
  end
  
  assign(socket, :filtered_plants, plants)
end

Use this helper in all filter event handlers.
```

---

## 🗂️ PROMPT 6: Create Planting Guide Template

```
Update lib/green_man_tavern_web/live/dual_panel_live.html.heex to add the planting guide interface in the right panel.

ADD THIS SECTION (when @right_panel_view == :planting_guide):

<div class="planting-guide-container">
  <!-- Filter Section -->
  <div class="filters-section" style="padding: 20px; background: #f0f0f0; border-bottom: 2px solid black;">
    <h2 style="font-family: 'Chicago', monospace; margin-bottom: 15px;">🌱 Planting Guide</h2>
    
    <!-- City Selector -->
    <div class="filter-group" style="margin-bottom: 15px;">
      <label style="font-weight: bold;">Select Your City:</label>
      <select phx-change="select_city" name="city_id" style="width: 100%; padding: 5px; border: 2px solid black;">
        <option value="">-- Choose a city --</option>
        <%= for city <- @cities do %>
          <option value={city.id} selected={@selected_city && @selected_city.id == city.id}>
            <%= city.city_name %>, <%= city.country %> (<%= city.koppen_code %>)
          </option>
        <% end %>
      </select>
      <%= if @selected_city do %>
        <p style="margin-top: 5px; font-size: 12px;">
          Climate: <%= @selected_climate_zone %> | Hemisphere: <%= @selected_city.hemisphere %>
        </p>
      <% end %>
    </div>
    
    <!-- Month Selector -->
    <div class="filter-group" style="margin-bottom: 15px;">
      <label style="font-weight: bold;">Planting Month:</label>
      <select phx-change="select_month" name="month" style="width: 100%; padding: 5px; border: 2px solid black;">
        <option value="">-- Any month --</option>
        <%= for month <- ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] do %>
          <option value={month} selected={@selected_month == month}><%= month %></option>
        <% end %>
      </select>
    </div>
    
    <!-- Plant Type Filter -->
    <div class="filter-group" style="margin-bottom: 15px;">
      <label style="font-weight: bold;">Plant Type:</label>
      <select phx-change="select_plant_type" name="type" style="width: 100%; padding: 5px; border: 2px solid black;">
        <option value="all">All Types</option>
        <option value="Vegetable">Vegetables</option>
        <option value="Herb">Herbs</option>
        <option value="Fruit">Fruits</option>
        <option value="Cover Crop">Cover Crops</option>
        <option value="Native">Native Plants</option>
      </select>
    </div>
    
    <!-- Difficulty Filter -->
    <div class="filter-group" style="margin-bottom: 15px;">
      <label style="font-weight: bold;">Growing Difficulty:</label>
      <select phx-change="select_difficulty" name="difficulty" style="width: 100%; padding: 5px; border: 2px solid black;">
        <option value="all">All Levels</option>
        <option value="Easy">Easy</option>
        <option value="Moderate">Moderate</option>
        <option value="Hard">Hard</option>
      </select>
    </div>
    
    <p style="font-size: 14px; margin-top: 10px;">
      Showing <%= length(@filtered_plants) %> plants
    </p>
  </div>
  
  <!-- Plants Grid -->
  <div class="plants-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 15px; padding: 20px;">
    <%= for plant <- @filtered_plants do %>
      <div 
        class="plant-card" 
        phx-click="view_plant_details" 
        phx-value-plant_id={plant.id}
        style="border: 2px solid black; padding: 15px; background: white; cursor: pointer; box-shadow: 4px 4px 0 black;"
      >
        <h3 style="font-family: 'Chicago', monospace; margin-bottom: 10px; border-bottom: 1px solid black; padding-bottom: 5px;">
          <%= plant.common_name %>
        </h3>
        <p style="font-style: italic; font-size: 12px; margin-bottom: 8px;">
          <%= plant.scientific_name %>
        </p>
        <div class="plant-info" style="font-size: 13px;">
          <p><strong>Type:</strong> <%= plant.plant_type %></p>
          <p><strong>Difficulty:</strong> <%= plant.growing_difficulty %></p>
          <p><strong>Harvest:</strong> <%= plant.days_to_harvest_min %>-<%= plant.days_to_harvest_max %> days</p>
          <%= if @selected_city do %>
            <p><strong>Plant:</strong> 
              <%= if @selected_city.hemisphere == "Southern", do: plant.planting_months_sh, else: plant.planting_months_nh %>
            </p>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
  
  <!-- Plant Details Modal (when plant selected) -->
  <%= if @selected_plant do %>
    <div class="modal-overlay" phx-click="close_plant_details" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 100;">
      <div class="modal-content" phx-click.stop style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); background: white; border: 3px solid black; padding: 30px; max-width: 600px; max-height: 80vh; overflow-y: auto;">
        <button phx-click="close_plant_details" style="position: absolute; top: 10px; right: 10px; border: 2px solid black; padding: 5px 10px; background: white;">✕</button>
        
        <h2 style="font-family: 'Chicago', monospace; border-bottom: 2px solid black; padding-bottom: 10px;">
          <%= @selected_plant.common_name %>
        </h2>
        <p style="font-style: italic; margin-bottom: 15px;"><%= @selected_plant.scientific_name %></p>
        
        <div style="margin-bottom: 20px;">
          <p><%= @selected_plant.description %></p>
        </div>
        
        <div class="plant-details-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 20px;">
          <div><strong>Family:</strong> <%= @selected_plant.plant_family %></div>
          <div><strong>Type:</strong> <%= @selected_plant.plant_type %></div>
          <div><strong>Difficulty:</strong> <%= @selected_plant.growing_difficulty %></div>
          <div><strong>Lifecycle:</strong> <%= @selected_plant.perennial_annual %></div>
          <div><strong>Sun:</strong> <%= @selected_plant.sunlight_needs %></div>
          <div><strong>Water:</strong> <%= @selected_plant.water_needs %></div>
          <div><strong>Space:</strong> <%= @selected_plant.space_required %></div>
          <div><strong>Height:</strong> <%= @selected_plant.height_cm_min %>-<%= @selected_plant.height_cm_max %> cm</div>
        </div>
        
        <!-- Companion Plants -->
        <div class="companions-section">
          <h3 style="font-family: 'Chicago', monospace; border-bottom: 1px solid black; padding-bottom: 5px; margin-bottom: 10px;">
            ✅ Good Companions
          </h3>
          <%= if length(@companion_plants.good) > 0 do %>
            <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 20px;">
              <%= for comp <- @companion_plants.good do %>
                <span style="border: 2px solid green; padding: 5px 10px; background: #e8f5e9; font-size: 12px;">
                  <%= comp.plant.common_name %>
                  <span style="font-size: 10px;">(<%= comp.evidence_level %>)</span>
                </span>
              <% end %>
            </div>
          <% else %>
            <p style="font-style: italic; color: #666;">No known good companions</p>
          <% end %>
          
          <h3 style="font-family: 'Chicago', monospace; border-bottom: 1px solid black; padding-bottom: 5px; margin-bottom: 10px;">
            ❌ Bad Companions
          </h3>
          <%= if length(@companion_plants.bad) > 0 do %>
            <div style="display: flex; flex-wrap: wrap; gap: 8px;">
              <%= for comp <- @companion_plants.bad do %>
                <span style="border: 2px solid red; padding: 5px 10px; background: #ffebee; font-size: 12px;">
                  <%= comp.plant.common_name %>
                  <span style="font-size: 10px;">(<%= comp.mechanism %>)</span>
                </span>
              <% end %>
            </div>
          <% else %>
            <p style="font-style: italic; color: #666;">No known bad companions</p>
          <% end %>
        </div>
      </div>
    </div>
  <% end %>
</div>

ADD EVENT HANDLER FOR CLOSING MODAL:
handle_event("close_plant_details", _, socket) do
  {:noreply, assign(socket, selected_plant: nil, companion_plants: %{good: [], bad: []})}
end

Style using HyperCard aesthetic:
- Black borders (2-3px solid)
- Monospace fonts for headers
- Box shadows for cards
- Grid layouts
- Simple color coding (green=good, red=bad)
```

---

## ✅ IMPLEMENTATION CHECKLIST

After running all prompts above:

1. ☐ Run migrations: `mix ecto.migrate`
2. ☐ Copy CSV files to `priv/repo/seeds/data/`
3. ☐ Run seeds: `mix run priv/repo/seeds/planting_guide.exs`
4. ☐ Verify data: `mix run -e "IO.inspect GreenManTavern.PlantingGuide.list_plants() |> length()"`
5. ☐ Test LiveView: Navigate to planting guide in browser
6. ☐ Test filters: Select city, month, type, difficulty
7. ☐ Test plant details: Click plant card, view companions

---

## 🚀 NEXT STEPS (After Implementation)

1. Add search functionality (full-text search on plant names)
2. Add plant photos (store URLs or upload images)
3. Add user favorites (save plants to user account)
4. Add "My Garden" (track what user is growing)
5. Add frost date calculator (Phase 2 from data package)

---

**Ready to paste into Cursor.AI!** Each prompt is self-contained and can be run sequentially. 🌱
