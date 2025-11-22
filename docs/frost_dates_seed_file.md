# Frost Dates Seed File

## File Created
**Path:** `priv/repo/seeds/frost_dates.exs`

## Purpose
Imports city frost date data from CSV files into the `city_frost_dates` table.

## Requirements Met

✅ Reads from `priv/repo/seeds/data/city_frost_dates.csv`  
✅ Matches cities by `city_name` and `country`  
✅ Skips if city not found (with warning message)  
✅ Skips if frost date already exists for that city  
✅ Prints progress messages and summary  
✅ Handles missing or invalid data gracefully  

## Usage

### Run the seed file:
```bash
mix run priv/repo/seeds/frost_dates.exs
```

### Prerequisites:
1. Cities must be seeded first (run `priv/repo/seeds/planting_guide.exs` or `priv/repo/seeds/cities.exs`)
2. CSV file must exist at `priv/repo/seeds/data/city_frost_dates.csv`

## CSV Format

The CSV file should have 9 columns (no header row):

| Column | Field | Type | Example |
|--------|-------|------|---------|
| 1 | ID | Integer | 1 |
| 2 | City Name | String | "Canberra" |
| 3 | Country | String | "Australia" |
| 4 | Last Frost Date | String | "October 5" |
| 5 | First Frost Date | String | "April 15" |
| 6 | Growing Season Days | Integer | 173 |
| 7 | Data Source | String | "Quality Plants & Seedlings AU" |
| 8 | Confidence Level | String | "high" |
| 9 | Notes | String (optional) | "ACT capital with significant frost risk" |

**Note:** For tropical regions with no frost, use "No frost" for both frost date fields.

## Output Examples

### Success Message:
```
  ✓ Canberra, Australia (October 5 - April 15)
```

### City Not Found:
```
  ⚠ City not found: Canberra, Australia
```

### Summary:
```
============================================================
Summary:
  ✅ Successfully imported: 37
  ⏭️  Skipped (already exists): 0
  ⚠️  Cities not found: 3

📊 Total frost dates in database: 37
============================================================
```

## Logic Flow

1. **File Check:**
   - Checks if CSV file exists
   - If not, prints error and exits gracefully

2. **CSV Parsing:**
   - Manually defines headers (CSV has no header row)
   - Parses CSV into list of maps
   - Maps: `%{"city_name" => "Canberra", "country" => "Australia", ...}`

3. **City Lookup:**
   - For each row, looks up city by `city_name` and `country`
   - If city not found, prints warning and increments counter
   - If city found, proceeds to check for existing frost data

4. **Duplicate Check:**
   - Checks if `CityFrostDate` already exists for this city
   - If exists, silently skips (increments skipped counter)
   - If not exists, proceeds to insert

5. **Data Parsing:**
   - Parses `growing_season_days` as integer
   - Handles parse errors gracefully (defaults to 0)
   - Uses default values for missing data source ("Unknown") and confidence ("medium")

6. **Insert:**
   - Creates changeset with all fields
   - Inserts into database
   - Prints success message with city name and frost dates
   - Increments success counter

7. **Summary:**
   - Prints counts for success, skipped, and not found
   - Queries total frost dates in database
   - Displays formatted summary

## Error Handling

### Missing City Name or Country:
- Skips row with warning
- Increments `not_found` counter

### City Not in Database:
- Prints warning with city name and country
- Increments `not_found` counter
- Does NOT crash

### Invalid Growing Season Days:
- Defaults to 0
- Continues processing

### Missing Data Source or Confidence:
- Uses defaults: "Unknown" and "medium"
- Continues processing

### Database Errors:
- Will crash with Ecto error message
- Useful for debugging schema/validation issues

## Code Structure

```elixir
alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{City, CityFrostDate}

# Setup NimbleCSV parser
NimbleCSV.define(CSVParser, separator: ",", escape: "\"")
alias CSVParser, as: CSV

results =
  if File.exists?(frost_file) do
    # Define headers (CSV has no header row)
    headers = ["id", "city_name", "country", ...]
    
    # Parse CSV
    rows = File.read!() |> CSV.parse_string()
    
    # Convert to maps and process
    rows
    |> Enum.map(fn row -> Enum.zip(headers, row) |> Enum.into(%{}) end)
    |> Enum.reduce(%{success: 0, skipped: 0, not_found: 0}, fn row, acc ->
      # Process each row...
    end)
  else
    # File not found fallback
    %{success: 0, skipped: 0, not_found: 0}
  end

# Print summary
IO.puts("Summary:")
IO.puts("  ✅ Successfully imported: #{results.success}")
IO.puts("  ⏭️  Skipped (already exists): #{results.skipped}")
IO.puts("  ⚠️  Cities not found: #{results.not_found}")
```

## Testing

### Test with no cities seeded:
```bash
mix run priv/repo/seeds/frost_dates.exs
# Should show all cities as "not found"
```

### Test with cities seeded:
```bash
mix run priv/repo/seeds/planting_guide.exs  # Seed cities first
mix run priv/repo/seeds/frost_dates.exs     # Then import frost dates
# Should show successful imports
```

### Test idempotency:
```bash
mix run priv/repo/seeds/frost_dates.exs  # First run
mix run priv/repo/seeds/frost_dates.exs  # Second run
# Second run should show all as "skipped"
```

## Database Verification

Check imported data:
```elixir
# In IEx
iex> alias GreenManTavern.Repo
iex> alias GreenManTavern.PlantingGuide.CityFrostDate
iex> Repo.all(CityFrostDate) |> length()
37

iex> cfd = Repo.get_by(CityFrostDate, city_id: 1) |> Repo.preload(:city)
iex> cfd.city.city_name
"Canberra"
iex> cfd.last_frost_date
"October 5"
iex> cfd.growing_season_days
173
```

## Integration with PlantingGuide Context

The frost dates can be queried using:
```elixir
alias GreenManTavern.PlantingGuide

# Get frost dates for a city
frost_dates = PlantingGuide.get_frost_dates(city_id)

# Calculate planting dates
planting_info = PlantingGuide.calculate_planting_date(city_id, plant_id)
# => %{
#   plant_after_date: "October 4",
#   plant_before_date: "March 1",
#   explanation: "Plant after last frost (October 5) + 14 days..."
# }
```

## Status
✅ Seed file created and tested  
✅ Compiles without errors  
✅ Handles missing cities gracefully  
✅ Provides clear progress messages  
✅ Idempotent (safe to run multiple times)  
✅ Ready for production use

