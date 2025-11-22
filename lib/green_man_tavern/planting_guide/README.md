# PlantingGuide Context - Schemas & Usage

This document describes the four Ecto schemas for the Living Web planting guide system and provides usage examples.

---

## Schema Overview

### 1. `KoppenZone` - Köppen Climate Classification

**File:** `lib/green_man_tavern/planting_guide/koppen_zone.ex`

**Purpose:** Stores Köppen climate classification data.

**Fields:**
- `id` - Primary key (auto-increment)
- `code` - Climate code (max 3 chars, unique, required) - e.g., "Cfb", "Cfa"
- `name` - Climate name (required) - e.g., "Oceanic", "Humid subtropical"
- `category` - Climate category (required) - e.g., "Temperate", "Continental"
- `description` - Climate characteristics (optional)
- `temperature_pattern` - Temperature profile (optional)
- `precipitation_pattern` - Rainfall distribution (optional)
- `inserted_at`, `updated_at` - Timestamps

**Validations:**
- Required: `code`, `name`, `category`
- `code` must be max 3 characters
- `code` must be unique

**Example:**
```elixir
alias GreenManTavern.PlantingGuide

# Create a Köppen zone
{:ok, zone} = PlantingGuide.create_koppen_zone(%{
  code: "Cfb",
  name: "Oceanic",
  category: "Temperate",
  description: "Mild temperatures year-round with frequent precipitation",
  temperature_pattern: "Cool summers (avg 10-22°C), mild winters (avg 0-10°C)",
  precipitation_pattern: "Evenly distributed throughout the year, 700-1500mm annually"
})

# Get a zone by code
zone = PlantingGuide.get_koppen_zone!("Cfb")
```

---

### 2. `City` - Location Data with Climate Zones

**File:** `lib/green_man_tavern/planting_guide/city.ex`

**Purpose:** Maps cities to Köppen climate zones for location-based recommendations.

**Fields:**
- `id` - Primary key
- `city_name` - City name (required)
- `country` - Country name (required)
- `state_province_territory` - State/province (optional)
- `latitude` - Decimal coordinates (7 decimal places, optional)
- `longitude` - Decimal coordinates (7 decimal places, optional)
- `koppen_code` - Köppen climate code (required, foreign key to `koppen_zones.code`)
- `hemisphere` - "Northern" or "Southern" (required)
- `notes` - Additional information (optional)
- `inserted_at`, `updated_at` - Timestamps

**Associations:**
- `belongs_to :koppen_zone` - References `koppen_zones.code` (string-based FK)

**Validations:**
- Required: `city_name`, `country`, `koppen_code`, `hemisphere`
- `hemisphere` must be "Northern" or "Southern"

**Example:**
```elixir
# Create a city
{:ok, city} = PlantingGuide.create_city(%{
  city_name: "Melbourne",
  country: "Australia",
  state_province_territory: "Victoria",
  latitude: -37.8136,
  longitude: 144.9631,
  koppen_code: "Cfb",
  hemisphere: "Southern",
  notes: "Major urban center with moderate climate"
})

# Find cities by name
cities = PlantingGuide.find_cities_by_name("Melbourne")

# Find cities by country
australian_cities = PlantingGuide.find_cities_by_country("Australia")
```

---

### 3. `Plant` - Comprehensive Plant Database

**File:** `lib/green_man_tavern/planting_guide/plant.ex`

**Purpose:** Stores detailed plant information for the planting guide.

**Fields:**
- `id` - Primary key
- `common_name` - Common plant name (required)
- `scientific_name` - Scientific name (optional)
- `plant_family` - Plant family (optional)
- `plant_type` - "Vegetable", "Herb", "Fruit", etc. (optional)
- `climate_zones` - **Array of Köppen codes** (required, non-empty)
- `growing_difficulty` - "Easy", "Moderate", "Hard" (optional)
- `space_required` - Space needs (optional)
- `sunlight_needs` - Sun requirements (optional)
- `water_needs` - Water requirements (optional)
- `days_to_germination_min` - Min germination days (optional)
- `days_to_germination_max` - Max germination days (optional)
- `days_to_harvest_min` - Min harvest days (optional)
- `days_to_harvest_max` - Max harvest days (optional)
- `perennial_annual` - Plant lifecycle (optional)
- `planting_months_sh` - Planting months for Southern Hemisphere (optional)
- `planting_months_nh` - Planting months for Northern Hemisphere (optional)
- `height_cm_min` - Min height in cm (optional)
- `height_cm_max` - Max height in cm (optional)
- `spread_cm_min` - Min spread in cm (optional)
- `spread_cm_max` - Max spread in cm (optional)
- `native_region` - Native region (optional)
- `description` - Plant description (optional)
- `inserted_at`, `updated_at` - Timestamps

**Associations:**
- `has_many :companion_relationships_a` - Relationships where this is plant A
- `has_many :companion_relationships_b` - Relationships where this is plant B

**Validations:**
- Required: `common_name`, `climate_zones`
- `climate_zones` must be a non-empty array
- `growing_difficulty` must be "Easy", "Moderate", or "Hard" (if provided)

**Example:**
```elixir
# Create a plant
{:ok, tomato} = PlantingGuide.create_plant(%{
  common_name: "Tomato",
  scientific_name: "Solanum lycopersicum",
  plant_family: "Solanaceae",
  plant_type: "Vegetable",
  climate_zones: ["Cfb", "Cfa", "Csa", "Csb"],
  growing_difficulty: "Moderate",
  space_required: "Medium",
  sunlight_needs: "Full sun",
  water_needs: "Regular",
  days_to_germination_min: 5,
  days_to_germination_max: 10,
  days_to_harvest_min: 60,
  days_to_harvest_max: 85,
  perennial_annual: "Annual",
  planting_months_sh: "Sep-Nov",
  planting_months_nh: "Mar-May",
  height_cm_min: 60,
  height_cm_max: 180,
  spread_cm_min: 45,
  spread_cm_max: 90,
  native_region: "South America",
  description: "Popular fruiting vegetable with numerous varieties"
})

# Find plants suitable for a climate zone
plants = PlantingGuide.find_plants_by_climate_zone("Cfb")

# Search plants by name
results = PlantingGuide.search_plants("tomato")

# Find plants by type
vegetables = PlantingGuide.find_plants_by_type("Vegetable")
```

**Note on Array Queries:**

The `climate_zones` field uses a PostgreSQL array type with a GIN index, enabling efficient queries:

```elixir
# The query: WHERE 'Cfb' = ANY(climate_zones)
# is optimized by the GIN index for fast lookups
```

---

### 4. `CompanionRelationship` - Plant Companion Data

**File:** `lib/green_man_tavern/planting_guide/companion_relationship.ex`

**Purpose:** Stores companion planting relationships (good/bad plant pairings).

**Fields:**
- `id` - Primary key
- `plant_a_id` - First plant (required, foreign key)
- `plant_b_id` - Second plant (required, foreign key)
- `relationship_type` - "good" or "bad" (required)
- `evidence_level` - "scientific", "traditional_strong", "traditional_weak" (required)
- `mechanism` - How the relationship works (optional)
- `notes` - Additional information (optional)
- `inserted_at`, `updated_at` - Timestamps

**Associations:**
- `belongs_to :plant_a` - First plant in relationship
- `belongs_to :plant_b` - Second plant in relationship

**Validations:**
- Required: `plant_a_id`, `plant_b_id`, `relationship_type`, `evidence_level`
- `relationship_type` must be "good" or "bad"
- `evidence_level` must be "scientific", "traditional_strong", or "traditional_weak"
- `plant_a_id` must not equal `plant_b_id` (no self-reference)
- Unique constraint on `[plant_a_id, plant_b_id]`

**Example:**
```elixir
# Create a companion relationship
{:ok, relationship} = PlantingGuide.create_companion_relationship(%{
  plant_a_id: tomato.id,
  plant_b_id: basil.id,
  relationship_type: "good",
  evidence_level: "traditional_strong",
  mechanism: "Basil repels aphids and may improve tomato flavor",
  notes: "Plant basil at the base of tomato plants"
})

# Get good companions for a plant
good_companions = PlantingGuide.get_good_companions(tomato.id)

# Get bad companions (avoid planting together)
bad_companions = PlantingGuide.get_bad_companions(tomato.id)
```

---

## Context API

The `GreenManTavern.PlantingGuide` context module provides a clean API for working with these schemas.

### Available Functions

**Köppen Zones:**
- `list_koppen_zones/0` - Get all zones
- `get_koppen_zone!/1` - Get zone by code
- `create_koppen_zone/1` - Create new zone
- `update_koppen_zone/2` - Update zone
- `delete_koppen_zone/1` - Delete zone
- `change_koppen_zone/2` - Get changeset

**Cities:**
- `list_cities/0` - Get all cities
- `get_city!/1` - Get city by ID
- `find_cities_by_name/1` - Search by name
- `find_cities_by_country/1` - Filter by country
- `create_city/1` - Create new city
- `update_city/2` - Update city
- `delete_city/1` - Delete city
- `change_city/2` - Get changeset

**Plants:**
- `list_plants/0` - Get all plants
- `get_plant!/1` - Get plant by ID
- `find_plants_by_climate_zone/1` - Plants for a climate zone
- `find_plants_by_type/1` - Plants by type
- `search_plants/1` - Search by name
- `create_plant/1` - Create new plant
- `update_plant/2` - Update plant
- `delete_plant/1` - Delete plant
- `change_plant/2` - Get changeset

**Companion Relationships:**
- `list_companion_relationships/0` - Get all relationships
- `get_companion_relationship!/1` - Get relationship by ID
- `get_good_companions/1` - Get compatible plants
- `get_bad_companions/1` - Get incompatible plants
- `create_companion_relationship/1` - Create relationship
- `update_companion_relationship/2` - Update relationship
- `delete_companion_relationship/1` - Delete relationship
- `change_companion_relationship/2` - Get changeset

---

## Usage Example: Complete Workflow

```elixir
alias GreenManTavern.PlantingGuide

# 1. Create Köppen zone
{:ok, zone} = PlantingGuide.create_koppen_zone(%{
  code: "Cfb",
  name: "Oceanic",
  category: "Temperate"
})

# 2. Create city in that zone
{:ok, city} = PlantingGuide.create_city(%{
  city_name: "Melbourne",
  country: "Australia",
  koppen_code: "Cfb",
  hemisphere: "Southern"
})

# 3. Create plants suitable for this zone
{:ok, tomato} = PlantingGuide.create_plant(%{
  common_name: "Tomato",
  climate_zones: ["Cfb", "Cfa"],
  growing_difficulty: "Moderate"
})

{:ok, basil} = PlantingGuide.create_plant(%{
  common_name: "Basil",
  climate_zones: ["Cfb", "Cfa"],
  growing_difficulty: "Easy"
})

# 4. Create companion relationship
{:ok, _relationship} = PlantingGuide.create_companion_relationship(%{
  plant_a_id: tomato.id,
  plant_b_id: basil.id,
  relationship_type: "good",
  evidence_level: "traditional_strong"
})

# 5. Get recommendations for Melbourne gardener
suitable_plants = PlantingGuide.find_plants_by_climate_zone("Cfb")
tomato_companions = PlantingGuide.get_good_companions(tomato.id)
```

---

## Key Features

### 1. **PostgreSQL Array Type**
The `climate_zones` field uses PostgreSQL arrays with a GIN index for efficient searching:
```elixir
# Efficient query: finds all plants suitable for Cfb climate
plants = PlantingGuide.find_plants_by_climate_zone("Cfb")
```

### 2. **String-Based Foreign Key**
City → KoppenZone uses a string foreign key (Köppen codes like "Cfb" instead of integer IDs).

### 3. **Hemisphere-Aware Planting**
Plants store separate planting months for Northern and Southern hemispheres.

### 4. **Evidence-Based Companions**
Companion relationships track evidence level, allowing prioritization of scientific data.

### 5. **Self-Reference Prevention**
CompanionRelationship prevents a plant from being its own companion.

---

## Testing

Run tests with:
```bash
mix test
```

For IEx testing:
```bash
iex -S mix
alias GreenManTavern.PlantingGuide
# ... use examples above
```

---

Created: November 4, 2025

