# CityFrostDate Schema

## File Created
**Path:** `lib/green_man_tavern/planting_guide/city_frost_date.ex`

## Module
`GreenManTavern.PlantingGuide.CityFrostDate`

## Schema Definition

### Table
Maps to: `city_frost_dates`

### Fields
- `id` - Primary key
- `city_id` - Integer (foreign key to cities)
- `last_frost_date` - String (e.g., "September 20" or "No frost")
- `first_frost_date` - String (e.g., "April 15" or "No frost")
- `growing_season_days` - Integer
- `data_source` - String
- `confidence_level` - String
- `notes` - String (optional)
- `inserted_at` - Timestamp
- `updated_at` - Timestamp

### Associations

#### Belongs To
```elixir
belongs_to :city, City
```

## Changeset Validation

### Required Fields
- `city_id`
- `last_frost_date`
- `first_frost_date`
- `growing_season_days`
- `data_source`
- `confidence_level`

### Optional Fields
- `notes`

### Validations
1. **Confidence level inclusion** - Must be one of: `["high", "medium", "low"]`
2. **Foreign key constraint** - Ensures `city_id` references valid city
3. **Unique constraint** - Ensures one frost date record per city

## Bidirectional Association

The `City` schema has been updated to include:

```elixir
has_one :frost_date, CityFrostDate
```

This allows querying in both directions:
- From CityFrostDate to City: `city_frost_date.city`
- From City to CityFrostDate: `city.frost_date`

## JSON Encoding

The schema includes `@derive {Jason.Encoder}` for all fields, making it serializable for API responses.

## Usage Examples

### Creating a Frost Date Record
```elixir
alias GreenManTavern.PlantingGuide.CityFrostDate

attrs = %{
  city_id: 1,
  last_frost_date: "September 20",
  first_frost_date: "April 15",
  growing_season_days: 178,
  data_source: "BOM Climate Data",
  confidence_level: "high",
  notes: "Based on 30-year average (1991-2020)"
}

changeset = CityFrostDate.changeset(%CityFrostDate{}, attrs)

case Repo.insert(changeset) do
  {:ok, frost_date} -> # Success
  {:error, changeset} -> # Validation errors
end
```

### Querying with Associations
```elixir
# Get frost date for a city
city = Repo.get(City, 1) |> Repo.preload(:frost_date)
frost_date = city.frost_date

# Get city from frost date
frost_date = Repo.get(CityFrostDate, 1) |> Repo.preload(:city)
city = frost_date.city
```

### Filtering by Confidence
```elixir
high_confidence_data = 
  from(cfd in CityFrostDate, where: cfd.confidence_level == "high")
  |> Repo.all()
```

### Calculating Growing Season
```elixir
# Example: Update growing season days
def calculate_growing_season(first_frost, last_frost) do
  # Logic to calculate days between dates
  # This is a placeholder - actual implementation would parse dates
  178
end

changeset = CityFrostDate.changeset(frost_date, %{
  growing_season_days: calculate_growing_season(
    frost_date.first_frost_date,
    frost_date.last_frost_date
  )
})
```

## Validation Errors

Common validation errors and their meanings:

```elixir
# Missing required field
%{city_id: ["can't be blank"]}

# Invalid confidence level
%{confidence_level: ["is invalid"]}

# Duplicate city (unique constraint)
%{city_id: ["has already been taken"]}

# Invalid city_id (foreign key)
%{city_id: ["does not exist"]}
```

## Notes

- Frost dates stored as strings for flexibility (supports "No frost" for tropical regions)
- Growing season days as integer for easy sorting and comparison
- Confidence level allows filtering unreliable data
- Unique constraint ensures data integrity (one record per city)
- Cascade delete: When a city is deleted, its frost date record is also deleted

## Status
✅ Schema created and compiles successfully  
✅ Associations configured correctly  
✅ Validations in place  
✅ Ready for use in the PlantingGuide context

