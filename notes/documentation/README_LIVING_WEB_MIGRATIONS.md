# Living Web Planting Guide System - Migrations

This document describes the four migrations created for the Living Web planting guide system.

## Migration Overview

### 1. `20251104224922_create_koppen_zones.exs`

Creates the `koppen_zones` table for storing Köppen climate classification data.

**Key Features:**
- Unique 3-character climate codes (e.g., "Cfb", "Cfa", "BSk")
- Climate categories (Tropical, Temperate, Continental, etc.)
- Temperature and precipitation pattern descriptions
- Unique index on `code` field

**Purpose:** Foundation table for climate-based planting recommendations.

---

### 2. `20251104224923_create_cities.exs`

Creates the `cities` table for storing location data with climate zones.

**Key Features:**
- City name, country, and optional state/province/territory
- Geographic coordinates (latitude/longitude with 7 decimal places precision)
- Foreign key reference to `koppen_zones.code` (string-based FK)
- Hemisphere classification (Northern/Southern) for seasonal calculations
- Indexes on city_name, country, and koppen_code

**Purpose:** Maps locations to climate zones for personalized planting guides.

---

### 3. `20251104224924_create_plants.exs`

Creates the `plants` table for storing comprehensive plant data.

**Key Features:**
- Common and scientific names
- Plant type categorization (Vegetable, Herb, Fruit, etc.)
- **Climate zones array** (PostgreSQL text array with GIN index for efficient searching)
- Growing metrics:
  - Germination time range (min/max days)
  - Harvest time range (min/max days)
  - Height and spread ranges (in cm)
  - Space, sunlight, and water requirements
  - Growing difficulty rating
- **Hemisphere-specific planting months** (separate fields for NH and SH)
- Perennial/annual classification
- Native region information

**Purpose:** Core plant database for the planting guide system.

**Special Note:** The GIN index on `climate_zones` enables efficient queries like:
```sql
WHERE 'Cfb' = ANY(climate_zones)
```

---

### 4. `20251104224925_create_companion_relationships.exs`

Creates the `companion_relationships` table for storing plant companion data.

**Key Features:**
- Links two plants (plant_a_id, plant_b_id) with foreign keys
- Relationship type: "good" or "bad"
- Evidence level: "scientific", "traditional_strong", "traditional_weak"
- Mechanism description (how the relationship works)
- Cascade delete: If a plant is deleted, all its relationships are removed
- **Unique constraint** on [plant_a_id, plant_b_id] prevents duplicate relationships
- Indexes on both plant IDs and relationship_type

**Purpose:** Enables companion planting recommendations.

---

## Running the Migrations

To run these migrations:

```bash
mix ecto.migrate
```

To rollback:

```bash
mix ecto.rollback --step 4
```

---

## Database Schema Relationships

```
koppen_zones
    |
    | (koppen_zones.code → cities.koppen_code)
    |
cities

plants ←→ companion_relationships ←→ plants
  (many-to-many self-referential relationship)
```

---

## Notes

1. **String-based Foreign Key:** The `cities.koppen_code` references `koppen_zones.code` (a string field, not an integer ID). This is intentional as Köppen codes are standardized 3-character strings.

2. **PostgreSQL-Specific Features:**
   - Array type for `plants.climate_zones`
   - GIN index for efficient array searching
   - Decimal precision for geographic coordinates (10,7 = ±180.0000000°)

3. **Hemisphere-Specific Data:** The `plants` table has separate planting months for Northern and Southern hemispheres, enabling accurate seasonal recommendations globally.

4. **Evidence-Based Companions:** The `companion_relationships` table tracks evidence levels, allowing the system to prioritize scientifically-backed relationships over traditional folklore.

---

## Future Schema Extensions

Potential additions to consider:

- **plant_varieties** - Different cultivars of the same plant
- **planting_schedules** - User-specific planting calendars
- **garden_beds** - Spatial planning and layout
- **pest_disease_relationships** - What pests affect which plants
- **soil_preferences** - pH, type, drainage requirements

---

Created: November 4, 2025

