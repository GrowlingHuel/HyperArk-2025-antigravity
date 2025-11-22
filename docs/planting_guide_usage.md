# PlantingGuide Context - Complete Usage Guide

This document provides comprehensive examples for all functions in the `GreenManTavern.PlantingGuide` context module.

---

## Setup

```elixir
alias GreenManTavern.PlantingGuide
```

---

## Köppen Zones Functions

### 1. `list_koppen_zones/0`

Returns all Köppen zones ordered by category, then code.

```elixir
zones = PlantingGuide.list_koppen_zones()
# [
#   %KoppenZone{category: "Continental", code: "Dfa", name: "Hot-summer humid continental"},
#   %KoppenZone{category: "Temperate", code: "Cfa", name: "Humid subtropical"},
#   %KoppenZone{category: "Temperate", code: "Cfb", name: "Oceanic"},
#   ...
# ]
```

### 2. `get_koppen_zone!/1`

Gets a Köppen zone by its code (string).

```elixir
zone = PlantingGuide.get_koppen_zone!("Cfb")
# %KoppenZone{
#   code: "Cfb",
#   name: "Oceanic",
#   category: "Temperate",
#   description: "Mild temperatures year-round...",
#   ...
# }

# Raises if not found
PlantingGuide.get_koppen_zone!("XYZ")
# ** (Ecto.NoResultsError)
```

---

## Cities Functions

### 3. `list_cities/1`

Returns cities with optional filtering.

**Available Filters:**
- `:country` - Exact country match
- `:koppen_code` - Köppen climate code
- `:hemisphere` - "Northern" or "Southern"

```elixir
# All cities (ordered by country, city_name)
all_cities = PlantingGuide.list_cities()

# Filter by country
australian_cities = PlantingGuide.list_cities(%{country: "Australia"})
# [
#   %City{city_name: "Melbourne", country: "Australia", koppen_zone: %KoppenZone{...}},
#   %City{city_name: "Sydney", country: "Australia", ...},
#   ...
# ]

# Filter by climate zone
oceanic_cities = PlantingGuide.list_cities(%{koppen_code: "Cfb"})

# Filter by hemisphere
southern_cities = PlantingGuide.list_cities(%{hemisphere: "Southern"})

# Combine filters
southern_oceanic = PlantingGuide.list_cities(%{
  koppen_code: "Cfb",
  hemisphere: "Southern"
})
# [%City{city_name: "Melbourne", hemisphere: "Southern", koppen_code: "Cfb"}, ...]
```

### 4. `get_city!/1`

Gets a city by ID with preloaded Köppen zone.

```elixir
city = PlantingGuide.get_city!(1)
# %City{
#   id: 1,
#   city_name: "Melbourne",
#   country: "Australia",
#   koppen_code: "Cfb",
#   hemisphere: "Southern",
#   koppen_zone: %KoppenZone{code: "Cfb", name: "Oceanic"}
# }

# Access preloaded association
city.koppen_zone.name
# "Oceanic"
```

### 5. `get_cities_by_koppen/1`

Gets all cities in a specific Köppen climate zone.

```elixir
cfb_cities = PlantingGuide.get_cities_by_koppen("Cfb")
# [
#   %City{city_name: "London", country: "United Kingdom", koppen_code: "Cfb"},
#   %City{city_name: "Melbourne", country: "Australia", koppen_code: "Cfb"},
#   %City{city_name: "Seattle", country: "United States", koppen_code: "Cfb"},
#   ...
# ]
```

---

## Plants Functions

### 6. `list_plants/1`

Returns plants with advanced filtering.

**Available Filters:**
- `:climate_zone` - Köppen code (searches array)
- `:plant_type` - "Vegetable", "Herb", "Fruit", etc.
- `:growing_difficulty` - "Easy", "Moderate", "Hard"
- `:hemisphere` - "Northern" or "Southern" (checks planting_months presence)
- `:month` - Month abbreviation (e.g., "Sep", "Mar")

```elixir
# All plants (ordered by common_name)
all_plants = PlantingGuide.list_plants()

# Plants suitable for Oceanic climate (Cfb)
oceanic_plants = PlantingGuide.list_plants(%{climate_zone: "Cfb"})
# [
#   %Plant{common_name: "Basil", climate_zones: ["Cfa", "Cfb", ...]},
#   %Plant{common_name: "Tomato", climate_zones: ["Cfa", "Cfb", "Csa", ...]},
#   ...
# ]

# Easy vegetables
easy_veggies = PlantingGuide.list_plants(%{
  plant_type: "Vegetable",
  growing_difficulty: "Easy"
})

# Plants with Southern Hemisphere planting data
southern_plants = PlantingGuide.list_plants(%{hemisphere: "Southern"})

# Plants plantable in September (both hemispheres)
september_plants = PlantingGuide.list_plants(%{month: "Sep"})

# Combine multiple filters
easy_cfb_veggies = PlantingGuide.list_plants(%{
  climate_zone: "Cfb",
  plant_type: "Vegetable",
  growing_difficulty: "Easy"
})
```

**How Climate Zone Filtering Works:**

The `:climate_zone` filter uses PostgreSQL's array contains operator to efficiently search the `climate_zones` array field:

```sql
-- Generated SQL
WHERE 'Cfb' = ANY(climate_zones)
```

This is optimized by the GIN index on the `climate_zones` column.

### 7. `get_plant!/1`

Gets a plant by ID.

```elixir
plant = PlantingGuide.get_plant!(1)
# %Plant{
#   id: 1,
#   common_name: "Tomato",
#   scientific_name: "Solanum lycopersicum",
#   climate_zones: ["Cfa", "Cfb", "Csa", "Csb"],
#   growing_difficulty: "Moderate",
#   ...
# }
```

### 8. `search_plants/1`

Searches plants by name (case-insensitive partial match).

Searches both `common_name` and `scientific_name` fields.

```elixir
# Search by common name
tomato_results = PlantingGuide.search_plants("tomato")
# [%Plant{common_name: "Tomato", scientific_name: "Solanum lycopersicum"}]

# Search by scientific name
solanum = PlantingGuide.search_plants("Solanum")
# [
#   %Plant{common_name: "Tomato", scientific_name: "Solanum lycopersicum"},
#   %Plant{common_name: "Eggplant", scientific_name: "Solanum melongena"},
#   ...
# ]

# Case-insensitive
basil = PlantingGuide.search_plants("BASIL")
# [%Plant{common_name: "Basil", ...}]

# Partial match
beet = PlantingGuide.search_plants("beet")
# [
#   %Plant{common_name: "Beetroot", ...},
#   %Plant{common_name: "Sugar Beet", ...}
# ]
```

---

## Companion Relationships Functions

### 9. `get_companions/2`

Gets companion plants with optional relationship type filter.

Returns a list of maps containing:
- `:plant` - The companion Plant struct
- `:relationship_type` - "good" or "bad"
- `:evidence_level` - Evidence strength
- `:mechanism` - How it works
- `:notes` - Additional info

**This function is bidirectional** - it finds relationships where the plant is either `plant_a` or `plant_b`.

```elixir
# Get all companions (good and bad)
all_companions = PlantingGuide.get_companions(tomato_id)
# [
#   %{
#     plant: %Plant{common_name: "Basil"},
#     relationship_type: "good",
#     evidence_level: "traditional_strong",
#     mechanism: "Basil repels aphids and may improve tomato flavor",
#     notes: "Plant at base of tomato plants"
#   },
#   %{
#     plant: %Plant{common_name: "Carrot"},
#     relationship_type: "good",
#     evidence_level: "traditional_weak",
#     mechanism: "Companion planting folklore",
#     notes: nil
#   },
#   %{
#     plant: %Plant{common_name: "Brassicas"},
#     relationship_type: "bad",
#     evidence_level: "scientific",
#     mechanism: "Compete for nutrients; allelopathic compounds",
#     notes: "Keep at least 2m apart"
#   }
# ]

# Get only good companions
good_companions = PlantingGuide.get_companions(tomato_id, "good")
# [
#   %{plant: %Plant{common_name: "Basil"}, relationship_type: "good", ...},
#   %{plant: %Plant{common_name: "Carrot"}, relationship_type: "good", ...}
# ]

# Get only bad companions (plants to avoid)
bad_companions = PlantingGuide.get_companions(tomato_id, "bad")
# [%{plant: %Plant{common_name: "Brassicas"}, relationship_type: "bad", ...}]

# Access companion details
Enum.each(good_companions, fn companion ->
  IO.puts("Plant #{companion.plant.common_name} with #{companion.plant.common_name}")
  IO.puts("Evidence: #{companion.evidence_level}")
  IO.puts("Mechanism: #{companion.mechanism}")
end)
```

### 10. `get_companion_details/2`

Gets the relationship details between two specific plants.

Checks both directions (A→B and B→A).

```elixir
# Get relationship between tomato and basil
relationship = PlantingGuide.get_companion_details(tomato_id, basil_id)
# %CompanionRelationship{
#   plant_a_id: 1,
#   plant_b_id: 5,
#   relationship_type: "good",
#   evidence_level: "traditional_strong",
#   mechanism: "Basil repels aphids and may improve tomato flavor",
#   notes: "Plant basil at the base of tomato plants"
# }

# Works in either direction
relationship = PlantingGuide.get_companion_details(basil_id, tomato_id)
# Returns the same relationship

# Returns nil if no relationship exists
PlantingGuide.get_companion_details(tomato_id, random_plant_id)
# nil
```

---

## Helper Functions

### 11. `plants_for_city/1`

Gets all plants compatible with a city's Köppen climate zone.

```elixir
# Get all plants suitable for Melbourne's climate
melbourne_plants = PlantingGuide.plants_for_city(melbourne_id)
# [
#   %Plant{common_name: "Basil", climate_zones: ["Cfa", "Cfb", ...]},
#   %Plant{common_name: "Lettuce", climate_zones: ["Cfb", ...]},
#   %Plant{common_name: "Tomato", climate_zones: ["Cfa", "Cfb", "Csa", ...]},
#   ...
# ]

# How it works:
# 1. Get city's Köppen code (e.g., "Cfb")
# 2. Return all plants where "Cfb" is in their climate_zones array

# Returns empty list if city doesn't exist
PlantingGuide.plants_for_city(999_999)
# []
```

### 12. `plants_plantable_now/2`

Gets plants compatible with a city AND plantable in a specific month.

**Hemisphere-aware**: Uses the city's hemisphere to check the correct planting months field.

```elixir
# Plants plantable in Melbourne (Southern Hemisphere) in September
melbourne_september = PlantingGuide.plants_plantable_now(melbourne_id, "Sep")
# [
#   %Plant{
#     common_name: "Tomato",
#     climate_zones: ["Cfa", "Cfb", ...],
#     planting_months_sh: "Sep-Nov",  # Contains "Sep"
#     planting_months_nh: "Mar-May"
#   },
#   %Plant{
#     common_name: "Basil",
#     climate_zones: ["Cfa", "Cfb", ...],
#     planting_months_sh: "Sep-Dec",  # Contains "Sep"
#     ...
#   }
# ]

# Plants plantable in London (Northern Hemisphere) in March
london_march = PlantingGuide.plants_plantable_now(london_id, "Mar")
# [
#   %Plant{
#     common_name: "Lettuce",
#     planting_months_nh: "Mar-Sep",  # Contains "Mar"
#     planting_months_sh: "Sep-Mar"
#   },
#   ...
# ]

# How it works:
# 1. Get city's Köppen code and hemisphere
# 2. Filter plants where Köppen code is in climate_zones array
# 3. Check appropriate planting_months field based on hemisphere:
#    - Northern: checks planting_months_nh
#    - Southern: checks planting_months_sh
# 4. Search for month abbreviation in the planting_months string

# Returns empty list if city doesn't exist
PlantingGuide.plants_plantable_now(999_999, "Sep")
# []
```

---

## Complete Workflow Example

Here's a complete example showing how to use multiple functions together:

```elixir
alias GreenManTavern.PlantingGuide

# 1. Setup: Create Köppen zone
{:ok, zone} = PlantingGuide.create_koppen_zone(%{
  code: "Cfb",
  name: "Oceanic",
  category: "Temperate",
  description: "Mild, maritime climate with cool summers",
  temperature_pattern: "Cool summers (10-22°C), mild winters (0-10°C)",
  precipitation_pattern: "Evenly distributed, 700-1500mm annually"
})

# 2. Create city in that zone
{:ok, melbourne} = PlantingGuide.create_city(%{
  city_name: "Melbourne",
  country: "Australia",
  state_province_territory: "Victoria",
  latitude: -37.8136,
  longitude: 144.9631,
  koppen_code: "Cfb",
  hemisphere: "Southern"
})

# 3. Create plants
{:ok, tomato} = PlantingGuide.create_plant(%{
  common_name: "Tomato",
  scientific_name: "Solanum lycopersicum",
  plant_type: "Vegetable",
  climate_zones: ["Cfa", "Cfb", "Csa", "Csb"],
  growing_difficulty: "Moderate",
  planting_months_sh: "Sep-Nov",
  planting_months_nh: "Mar-May"
})

{:ok, basil} = PlantingGuide.create_plant(%{
  common_name: "Basil",
  plant_type: "Herb",
  climate_zones: ["Cfa", "Cfb", "Csa"],
  growing_difficulty: "Easy",
  planting_months_sh: "Sep-Dec",
  planting_months_nh: "Apr-Jun"
})

{:ok, brassica} = PlantingGuide.create_plant(%{
  common_name: "Cabbage",
  plant_type: "Vegetable",
  climate_zones: ["Cfb", "Dfb"],
  growing_difficulty: "Easy",
  planting_months_sh: "Feb-Apr",
  planting_months_nh: "Aug-Oct"
})

# 4. Create companion relationships
{:ok, _good_rel} = PlantingGuide.create_companion_relationship(%{
  plant_a_id: tomato.id,
  plant_b_id: basil.id,
  relationship_type: "good",
  evidence_level: "traditional_strong",
  mechanism: "Basil repels aphids and may improve tomato flavor"
})

{:ok, _bad_rel} = PlantingGuide.create_companion_relationship(%{
  plant_a_id: tomato.id,
  plant_b_id: brassica.id,
  relationship_type: "bad",
  evidence_level: "scientific",
  mechanism: "Compete for nutrients; allelopathic compounds"
})

# 5. USE CASE: Melbourne gardener in September
# "What can I plant in Melbourne right now (September)?"

# Get plants suitable for Melbourne's climate
suitable_plants = PlantingGuide.plants_for_city(melbourne.id)
IO.puts("Plants suitable for Melbourne: #{length(suitable_plants)}")

# Narrow down to plants plantable in September
plantable_now = PlantingGuide.plants_plantable_now(melbourne.id, "Sep")
IO.puts("Plants plantable in September: #{length(plantable_now)}")

Enum.each(plantable_now, fn plant ->
  IO.puts("\n#{plant.common_name}")
  IO.puts("  Type: #{plant.plant_type}")
  IO.puts("  Difficulty: #{plant.growing_difficulty}")
  IO.puts("  Planting: #{plant.planting_months_sh}")
  
  # Get good companions
  good_companions = PlantingGuide.get_companions(plant.id, "good")
  if good_companions != [] do
    IO.puts("  Good companions:")
    Enum.each(good_companions, fn c ->
      IO.puts("    - #{c.plant.common_name} (#{c.evidence_level})")
    end)
  end
  
  # Get plants to avoid
  bad_companions = PlantingGuide.get_companions(plant.id, "bad")
  if bad_companions != [] do
    IO.puts("  Avoid planting near:")
    Enum.each(bad_companions, fn c ->
      IO.puts("    - #{c.plant.common_name}")
    end)
  end
end)

# Output:
# Plants suitable for Melbourne: 45
# Plants plantable in September: 12
#
# Tomato
#   Type: Vegetable
#   Difficulty: Moderate
#   Planting: Sep-Nov
#   Good companions:
#     - Basil (traditional_strong)
#   Avoid planting near:
#     - Cabbage
#
# Basil
#   Type: Herb
#   Difficulty: Easy
#   Planting: Sep-Dec
#   Good companions:
#     - Tomato (traditional_strong)
```

---

## Advanced Query Examples

### Complex Plant Filtering

```elixir
# Easy vegetables for Cfb climate plantable in September
easy_september_veggies = PlantingGuide.list_plants(%{
  climate_zone: "Cfb",
  plant_type: "Vegetable",
  growing_difficulty: "Easy",
  month: "Sep"
})

# All plants with Northern Hemisphere planting data
nh_plants = PlantingGuide.list_plants(%{hemisphere: "Northern"})
```

### Bidirectional Companion Queries

```elixir
# Get all plants that work well with tomatoes
tomato_companions = PlantingGuide.get_companions(tomato.id, "good")

# Check if two plants are compatible before planting
relationship = PlantingGuide.get_companion_details(plant1_id, plant2_id)

case relationship do
  %{relationship_type: "good"} ->
    IO.puts("Great pairing! #{relationship.mechanism}")
  %{relationship_type: "bad"} ->
    IO.puts("Don't plant together! #{relationship.mechanism}")
  nil ->
    IO.puts("No known relationship")
end
```

### Climate Zone Queries

```elixir
# All cities with Oceanic climate
oceanic_cities = PlantingGuide.get_cities_by_koppen("Cfb")

# All plants suitable for Oceanic climate
oceanic_plants = PlantingGuide.list_plants(%{climate_zone: "Cfb"})

# Intersection: Plants plantable in ALL Oceanic cities
# (Already handled by climate_zone filter)
```

---

## Performance Notes

1. **Array Queries**: The `climate_zones` field uses a GIN index for efficient array searching. Queries like `list_plants(%{climate_zone: "Cfb"})` are optimized.

2. **Preloading**: Functions like `list_cities/1` and `get_city!/1` preload associations to avoid N+1 queries.

3. **Bidirectional Queries**: `get_companions/2` makes two queries (plant_a and plant_b) but returns combined results.

4. **Empty Results**: All functions gracefully handle empty results by returning `[]` instead of raising errors.

---

Created: November 4, 2025

