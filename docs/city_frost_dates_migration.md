# City Frost Dates Migration

## Migration Created
**File:** `priv/repo/migrations/20251104140216_create_city_frost_dates.exs`

## Table: `city_frost_dates`

### Fields
- `id` - Primary key (auto-increment)
- `city_id` - Integer, references `cities.id`, on_delete: `:delete_all`, not null
- `last_frost_date` - String (50 chars) - Format: "September 20" or "No frost"
- `first_frost_date` - String (50 chars) - Format: "April 15" or "No frost"
- `growing_season_days` - Integer - Days between frosts
- `data_source` - String (100 chars) - Where the data came from
- `confidence_level` - String (20 chars) - "high", "medium", or "low"
- `notes` - Text (nullable) - Additional notes
- `inserted_at` - Timestamp (auto)
- `updated_at` - Timestamp (auto)

### Indexes
1. **Unique index on `city_id`** - Ensures one frost date record per city
2. **Index on `confidence_level`** - For filtering by data confidence

### Foreign Key Behavior
- When a city is deleted, all associated frost date records are deleted (`:delete_all`)

## Migration Status
✅ Successfully migrated on 2025-11-04

## Usage Example
```elixir
# One city, one frost date record
%CityFrostDate{
  city_id: 123,
  last_frost_date: "September 20",
  first_frost_date: "April 15",
  growing_season_days: 178,
  data_source: "BOM Climate Data",
  confidence_level: "high",
  notes: "Based on 30-year average"
}
```

## Notes
- Frost dates stored as strings for flexibility (allows "No frost" for tropical regions)
- Growing season days calculated as integer for easy comparisons
- Confidence level allows filtering unreliable data
- Unique constraint prevents duplicate frost records per city

