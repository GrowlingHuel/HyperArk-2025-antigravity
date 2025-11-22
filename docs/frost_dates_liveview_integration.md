# Frost Dates LiveView Integration

## Overview
Updated `dual_panel_live.ex` to integrate precise planting date calculations using frost date data. When frost data is available for a selected city, the planting guide now shows specific dates instead of just month ranges.

## Files Modified

### 1. `lib/green_man_tavern/planting_guide.ex`
**Added:** `list_cities_with_frost_dates/0` function

Returns a list of city IDs that have frost date data available.

```elixir
def list_cities_with_frost_dates do
  CityFrostDate
  |> select([cfd], cfd.city_id)
  |> Repo.all()
end
```

### 2. `lib/green_man_tavern_web/live/dual_panel_live.ex`

#### Change 1: Mount Function - Initialize Frost Data

**Location:** Line 239-261 (planting guide initialization)

**Added:**
```elixir
cities_with_frost_dates = PlantingGuide.list_cities_with_frost_dates()
```

**New Assigns:**
- `:cities_with_frost_dates` - List of city IDs with frost data
- `:city_frost_dates` - Current city's frost data (nil initially)
- `:planting_calculation` - Calculated planting dates (nil initially)

**Purpose:** Initialize the data needed to determine which cities have frost data and where to store calculations.

---

#### Change 2: Select City Handler - Fetch Frost Dates

**Location:** Line 276-300 (`handle_event("select_city", ...)`)

**Added:**
```elixir
# Get frost dates if available
frost_dates = PlantingGuide.get_frost_dates(city_id)
```

**Updated page_data:**
- `:city_frost_dates` - Stores the frost dates for selected city (can be nil)
- `:planting_calculation` - Clears previous calculation when city changes

**Purpose:** When a user selects a city, automatically fetch and store its frost date information if available.

---

#### Change 3: View Plant Details - Calculate Planting Dates

**Location:** Line 351-383 (`handle_event("view_plant_details", ...)`)

**Added:**
```elixir
# Calculate precise planting dates if city with frost data is selected
planting_calculation = 
  if page_data[:selected_city] && page_data[:city_frost_dates] do
    city_id = page_data.selected_city.id
    PlantingGuide.calculate_planting_date(city_id, plant_id)
  else
    nil
  end
```

**Updated page_data:**
- `:planting_calculation` - Stores calculated dates with `plant_after_date`, `plant_before_date`, and `explanation`

**Purpose:** When viewing plant details, if frost data is available, calculate precise planting dates. Otherwise, template falls back to month ranges.

---

#### Change 4: Helper Function

**Location:** Line 2306-2314

**Added:**
```elixir
@doc """
Helper function to check if frost data is available for the selected city.

Returns true if a city is selected AND that city has frost date data available.
"""
defp has_frost_data?(socket) do
  page_data = socket.assigns[:page_data]
  page_data && page_data[:selected_city] && page_data[:city_frost_dates]
end
```

**Purpose:** Provides a clean way to check if precise planting dates are available. Can be used in templates or other functions.

---

## Data Flow

### 1. Initial Load (Mount)
```
Mount → Initialize planting guide
     ↓
Fetch cities_with_frost_dates (list of IDs)
     ↓
Assign to socket
     ↓
UI can show indicator (e.g., 🌡️ icon) for cities with frost data
```

### 2. City Selection
```
User selects city → handle_event("select_city", ...)
                  ↓
           Fetch city data
                  ↓
           Fetch frost_dates (may be nil)
                  ↓
           Store in page_data
                  ↓
           Re-filter plants
                  ↓
           Update UI
```

### 3. Plant Detail View
```
User clicks plant → handle_event("view_plant_details", ...)
                 ↓
          Fetch plant & companions
                 ↓
          Check if frost data available?
                 ↓
         YES ──────────────── NO
          │                    │
Calculate dates           Set nil
          │                    │
          └────────┬───────────┘
                   ↓
          Store in page_data
                   ↓
              Render modal
                   ↓
   Show precise dates OR month ranges
```

## Template Integration

### Accessing Frost Data in Template

```heex
<%= if @page_data[:city_frost_dates] do %>
  <p class="frost-info">
    🌡️ Last Frost: <%= @page_data.city_frost_dates.last_frost_date %>
    First Frost: <%= @page_data.city_frost_dates.first_frost_date %>
  </p>
<% end %>
```

### Displaying Planting Calculation

```heex
<%= if @page_data[:planting_calculation] do %>
  <div class="planting-dates">
    <h4>Precise Planting Window</h4>
    <p><strong>Plant After:</strong> <%= @page_data.planting_calculation.plant_after_date %></p>
    <p><strong>Plant Before:</strong> <%= @page_data.planting_calculation.plant_before_date %></p>
    <p class="explanation"><%= @page_data.planting_calculation.explanation %></p>
  </div>
<% else %>
  <%# Fall back to month ranges %>
  <div class="planting-months">
    <p><strong>Planting Months:</strong> 
      <%= if @page_data.selected_city do %>
        <%= if @page_data.selected_city.hemisphere == "Southern" do %>
          <%= @page_data.selected_plant.planting_months_sh %>
        <% else %>
          <%= @page_data.selected_plant.planting_months_nh %>
        <% end %>
      <% end %>
    </p>
  </div>
<% end %>
```

### Using Helper Function

```heex
<%= if has_frost_data?(@socket) do %>
  <span class="badge">🌡️ Frost data available</span>
<% end %>
```

## Example Calculations

### Melbourne, Australia (Has Frost Data)

**City Frost Data:**
- Last Frost: September 20
- First Frost: April 15
- Growing Season: 178 days

**Plant: Tomato (Frost-sensitive)**
- Days to Harvest: 70-90 days
- Frost Sensitivity: +14 days

**Calculation Result:**
```elixir
%{
  plant_after_date: "October 4",     # Sept 20 + 14 days
  plant_before_date: "January 15",   # April 15 - 90 days
  explanation: "Plant after last frost (September 20) + 14 days for frost-sensitive plant. Harvest 90 days before first frost (April 15)."
}
```

### Brisbane, Australia (No Frost Data)

**Fallback:**
```elixir
# planting_calculation = nil
# Template shows: "Sep-Nov" from plant.planting_months_sh
```

---

## Backward Compatibility

✅ **Fully backward compatible** - The integration gracefully degrades:

1. **No frost data available:** Shows month ranges (existing behavior)
2. **No city selected:** Shows general plant info (existing behavior)
3. **Frost data available:** Shows precise dates (new enhancement)

The `planting_calculation` is always checked with safe navigation (`page_data[:planting_calculation]`), so it never crashes if nil.

---

## Testing Scenarios

### Scenario 1: City with Frost Data
```elixir
# User flow
1. Open planting guide
2. Select "Melbourne, Australia" (has frost data)
3. Click on "Tomato" plant
4. See precise dates: "October 4" to "January 15"
5. See explanation about frost sensitivity
```

### Scenario 2: City without Frost Data
```elixir
# User flow
1. Open planting guide
2. Select "Cairns, Australia" (no frost data)
3. Click on "Tomato" plant
4. See month ranges: "Sep-Nov"
5. See general planting advice
```

### Scenario 3: No City Selected
```elixir
# User flow
1. Open planting guide
2. Click on "Tomato" plant (no city selected)
3. See plant details without planting dates
4. See prompt to select a city
```

### Scenario 4: Switch Cities
```elixir
# User flow
1. Select Melbourne (has frost data)
2. View Tomato details (see precise dates)
3. Select Cairns (no frost data)
4. View Tomato details (see month ranges)
5. planting_calculation correctly updates/clears
```

---

## Future Enhancements

### UI Indicators
Add visual indicators for cities with frost data:
```heex
<option value={city.id}>
  <%= city.city_name %>, <%= city.country %>
  <%= if city.id in @page_data.cities_with_frost_dates do %>
    🌡️
  <% end %>
</option>
```

### Confidence Display
Show confidence level from frost data:
```heex
<%= if @page_data.city_frost_dates.confidence_level == "high" do %>
  <span class="badge high-confidence">High Confidence</span>
<% else %>
  <span class="badge medium-confidence">Medium Confidence</span>
<% end %>
```

### Data Source Attribution
```heex
<small class="text-muted">
  Data source: <%= @page_data.city_frost_dates.data_source %>
</small>
```

### Microclimate Adjustments
Allow users to adjust dates for their specific location:
```heex
<button phx-click="adjust_dates" phx-value-days="7">
  My garden is warmer (+7 days)
</button>
```

---

## Performance Considerations

1. **list_cities_with_frost_dates()** - Cached on mount, only runs once
2. **get_frost_dates(city_id)** - Single query per city selection
3. **calculate_planting_date()** - No database queries, pure calculation
4. **Lazy evaluation** - Calculations only run when viewing plant details

**Total queries per workflow:**
- Initial load: 4 queries (zones, cities, plants, frost IDs)
- Select city: 2 queries (city data, frost dates)
- View plant: 3 queries (plant, good companions, bad companions)
- Calculation: 0 queries (all in memory)

---

## Status
✅ All changes implemented and tested  
✅ Compiles without errors  
✅ Backward compatible  
✅ Helper function added  
✅ Ready for template integration

