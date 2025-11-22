# Seed script for importing city frost dates from CSV
#
# Run with: mix run priv/repo/seeds/frost_dates.exs

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{City, CityFrostDate}

# Setup NimbleCSV parser
NimbleCSV.define(CSVParser, separator: ",", escape: "\"")
alias CSVParser, as: CSV

IO.puts("\n🌡️  Importing frost dates...")
IO.puts("=" |> String.duplicate(60))

frost_file = "priv/repo/seeds/data/city_frost_dates.csv"

results =
  if File.exists?(frost_file) do
    # CSV doesn't have headers, so define them manually
    headers = ["id", "city_name", "country", "last_frost_date", "first_frost_date",
               "growing_season_days", "data_source", "confidence_level", "notes"]

    rows =
      frost_file
      |> File.read!()
      |> CSV.parse_string()

    rows
    |> Enum.map(fn row -> Enum.zip(headers, row) |> Enum.into(%{}) end)
    |> Enum.reduce(%{success: 0, skipped: 0, not_found: 0}, fn row, acc ->
      # Look up city by name and country
      city_name = Map.get(row, "city_name")
      country = Map.get(row, "country")

      cond do
        is_nil(city_name) || is_nil(country) || city_name == "" || country == "" ->
          IO.puts("  ⚠ Missing city_name or country in row")
          %{acc | not_found: acc.not_found + 1}

        true ->
          city = Repo.get_by(City, city_name: city_name, country: country)

          cond do
            is_nil(city) ->
              IO.puts("  ⚠ City not found: #{city_name}, #{country}")
              %{acc | not_found: acc.not_found + 1}

            Repo.get_by(CityFrostDate, city_id: city.id) ->
              # Skip if frost date already exists
              %{acc | skipped: acc.skipped + 1}

            true ->
              # Parse growing_season_days to integer
              growing_days_str = Map.get(row, "growing_season_days", "0")
              growing_days = case Integer.parse(growing_days_str) do
                {days, _} -> days
                :error -> 0
              end

              last_frost = Map.get(row, "last_frost_date")
              first_frost = Map.get(row, "first_frost_date")
              data_source = Map.get(row, "data_source") || "Unknown"
              confidence = Map.get(row, "confidence_level") || "medium"
              notes = Map.get(row, "notes")

              %CityFrostDate{}
              |> CityFrostDate.changeset(%{
                city_id: city.id,
                last_frost_date: last_frost,
                first_frost_date: first_frost,
                growing_season_days: growing_days,
                data_source: data_source,
                confidence_level: confidence,
                notes: notes
              })
              |> Repo.insert!()

              IO.puts("  ✓ #{city_name}, #{country} (#{last_frost} - #{first_frost})")
              %{acc | success: acc.success + 1}
          end
      end
    end)
  else
    IO.puts("  ⚠️  Frost dates CSV file not found: #{frost_file}")
    %{success: 0, skipped: 0, not_found: 0}
  end

# Print summary
IO.puts("\n" <> ("=" |> String.duplicate(60)))
IO.puts("Summary:")
IO.puts("  ✅ Successfully imported: #{results.success}")
IO.puts("  ⏭️  Skipped (already exists): #{results.skipped}")
IO.puts("  ⚠️  Cities not found: #{results.not_found}")

frost_count = Repo.aggregate(CityFrostDate, :count)
IO.puts("\n📊 Total frost dates in database: #{frost_count}")
IO.puts("=" |> String.duplicate(60))
