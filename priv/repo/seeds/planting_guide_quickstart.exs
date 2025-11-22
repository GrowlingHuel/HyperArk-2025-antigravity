# Quick-Start Seed File for Planting Guide
# Creates minimal test data WITHOUT requiring CSV files
# Run with: mix run priv/repo/seeds/planting_guide_quickstart.exs

alias GreenManTavern.Repo
alias GreenManTavern.PlantingGuide.{KoppenZone, City, Plant, CompanionRelationship, CityFrostDate}

IO.puts("\n🌱 Quick-Start Planting Guide Seed")
IO.puts("=" |> String.duplicate(60))

# ======================
# 1. Köppen Zones
# ======================
IO.puts("\n1️⃣ Seeding Köppen Zones...")

koppen_data = [
  %{code: "Cfb", name: "Oceanic", category: "Temperate",
    description: "Mild maritime climate with cool summers",
    temperature_pattern: "Cool summers (10-22°C) mild winters (0-10°C)",
    precipitation_pattern: "Evenly distributed 700-1500mm annually"},
  %{code: "Cfa", name: "Humid subtropical", category: "Temperate",
    description: "Hot humid summers with mild winters",
    temperature_pattern: "Hot summers (22-27°C) mild winters (-3-18°C)",
    precipitation_pattern: "Summer rainfall peak 800-1600mm"},
  %{code: "Csa", name: "Mediterranean hot summer", category: "Temperate",
    description: "Hot dry summers mild wet winters",
    temperature_pattern: "Hot summers (22-28°C) mild winters (0-18°C)",
    precipitation_pattern: "Winter rainfall 400-900mm"},
  %{code: "Af", name: "Tropical rainforest", category: "Tropical",
    description: "Hot and wet year-round",
    temperature_pattern: "Hot all year (25-28°C)",
    precipitation_pattern: "Heavy rainfall year-round 2000-4000mm"}
]

koppen_count = Enum.reduce(koppen_data, 0, fn data, count ->
  case Repo.get_by(KoppenZone, code: data.code) do
    nil ->
      %KoppenZone{}
      |> KoppenZone.changeset(data)
      |> Repo.insert!()
      count + 1
    _ ->
      count
  end
end)

IO.puts("  ✅ Created #{koppen_count} Köppen zones")

# ======================
# 2. Cities
# ======================
IO.puts("\n2️⃣  Seeding Cities...")

cities_data = [
  %{city_name: "Melbourne", country: "Australia", state_province_territory: "Victoria",
    latitude: Decimal.new("-37.8136"), longitude: Decimal.new("144.9631"),
    koppen_code: "Cfb", hemisphere: "Southern", notes: "Major urban center"},
  %{city_name: "Sydney", country: "Australia", state_province_territory: "New South Wales",
    latitude: Decimal.new("-33.8688"), longitude: Decimal.new("151.2093"),
    koppen_code: "Cfa", hemisphere: "Southern", notes: "Largest city"},
  %{city_name: "Brisbane", country: "Australia", state_province_territory: "Queensland",
    latitude: Decimal.new("-27.4698"), longitude: Decimal.new("153.0251"),
    koppen_code: "Cfa", hemisphere: "Southern", notes: "Subtropical capital"},
  %{city_name: "Cairns", country: "Australia", state_province_territory: "Queensland",
    latitude: Decimal.new("-16.9186"), longitude: Decimal.new("145.7781"),
    koppen_code: "Af", hemisphere: "Southern", notes: "Tropical city"},
  %{city_name: "London", country: "United Kingdom", state_province_territory: "England",
    latitude: Decimal.new("51.5074"), longitude: Decimal.new("-0.1278"),
    koppen_code: "Cfb", hemisphere: "Northern", notes: "Capital city"},
  %{city_name: "Seattle", country: "United States", state_province_territory: "Washington",
    latitude: Decimal.new("47.6062"), longitude: Decimal.new("-122.3321"),
    koppen_code: "Cfb", hemisphere: "Northern", notes: "Pacific Northwest"}
]

cities_count = Enum.reduce(cities_data, 0, fn data, count ->
  case Repo.get_by(City, city_name: data.city_name, country: data.country) do
    nil ->
      %City{}
      |> City.changeset(data)
      |> Repo.insert!()
      count + 1
    _ ->
      count
  end
end)

IO.puts("  ✅ Created #{cities_count} cities")

# ======================
# 3. Plants
# ======================
IO.puts("\n3️⃣  Seeding Plants...")

plants_data = [
  %{common_name: "Tomato", scientific_name: "Solanum lycopersicum", plant_family: "Solanaceae",
    plant_type: "Vegetable", climate_zones: ["Cfa", "Cfb", "Csa"], growing_difficulty: "Moderate",
    space_required: "Medium", sunlight_needs: "Full sun", water_needs: "Regular",
    days_to_germination_min: 5, days_to_germination_max: 10,
    days_to_harvest_min: 60, days_to_harvest_max: 85, perennial_annual: "Annual",
    planting_months_sh: "Sep-Nov", planting_months_nh: "Mar-May",
    height_cm_min: 60, height_cm_max: 180, spread_cm_min: 45, spread_cm_max: 90,
    native_region: "South America", description: "Popular fruiting vegetable with numerous varieties"},

  %{common_name: "Basil", scientific_name: "Ocimum basilicum", plant_family: "Lamiaceae",
    plant_type: "Herb", climate_zones: ["Cfa", "Cfb", "Csa", "Af"], growing_difficulty: "Easy",
    space_required: "Small", sunlight_needs: "Full sun", water_needs: "Regular",
    days_to_germination_min: 7, days_to_germination_max: 14,
    days_to_harvest_min: 60, days_to_harvest_max: 90, perennial_annual: "Annual",
    planting_months_sh: "Sep-Dec", planting_months_nh: "Apr-Jun",
    height_cm_min: 30, height_cm_max: 60, spread_cm_min: 30, spread_cm_max: 45,
    native_region: "Tropical Asia", description: "Aromatic herb used in cooking"},

  %{common_name: "Lettuce", scientific_name: "Lactuca sativa", plant_family: "Asteraceae",
    plant_type: "Vegetable", climate_zones: ["Cfb"], growing_difficulty: "Easy",
    space_required: "Small", sunlight_needs: "Partial shade", water_needs: "Regular",
    days_to_germination_min: 7, days_to_germination_max: 14,
    days_to_harvest_min: 45, days_to_harvest_max: 75, perennial_annual: "Annual",
    planting_months_sh: "Feb-Apr,Aug-Oct", planting_months_nh: "Mar-May,Sep-Oct",
    height_cm_min: 15, height_cm_max: 30, spread_cm_min: 25, spread_cm_max: 35,
    native_region: "Mediterranean", description: "Cool season salad crop"},

  %{common_name: "Broccoli", scientific_name: "Brassica oleracea var. italica", plant_family: "Brassicaceae",
    plant_type: "Vegetable", climate_zones: ["Cfb", "Cfa"], growing_difficulty: "Moderate",
    space_required: "Medium", sunlight_needs: "Full sun", water_needs: "Regular",
    days_to_germination_min: 5, days_to_germination_max: 10,
    days_to_harvest_min: 70, days_to_harvest_max: 100, perennial_annual: "Annual",
    planting_months_sh: "Feb-Apr", planting_months_nh: "Jul-Sep",
    height_cm_min: 45, height_cm_max: 75, spread_cm_min: 45, spread_cm_max: 60,
    native_region: "Mediterranean", description: "Cool season brassica crop"},

  %{common_name: "Capsicum", scientific_name: "Capsicum annuum", plant_family: "Solanaceae",
    plant_type: "Vegetable", climate_zones: ["Cfa", "Cfb", "Csa", "Af"], growing_difficulty: "Moderate",
    space_required: "Medium", sunlight_needs: "Full sun", water_needs: "Regular",
    days_to_germination_min: 10, days_to_germination_max: 21,
    days_to_harvest_min: 70, days_to_harvest_max: 90, perennial_annual: "Annual",
    planting_months_sh: "Sep-Nov", planting_months_nh: "Mar-May",
    height_cm_min: 45, height_cm_max: 90, spread_cm_min: 40, spread_cm_max: 60,
    native_region: "Central America", description: "Bell peppers and chili peppers"},
]

plants_count = Enum.reduce(plants_data, 0, fn data, count ->
  case Repo.get_by(Plant, common_name: data.common_name, scientific_name: data.scientific_name) do
    nil ->
      %Plant{}
      |> Plant.changeset(data)
      |> Repo.insert!()
      count + 1
    _ ->
      count
  end
end)

IO.puts("  ✅ Created #{plants_count} plants")

# ======================
# 4. Companion Relationships
# ======================
IO.puts("\n4️⃣  Seeding Companion Relationships...")

tomato = Repo.get_by(Plant, common_name: "Tomato")
basil = Repo.get_by(Plant, common_name: "Basil")
lettuce = Repo.get_by(Plant, common_name: "Lettuce")
broccoli = Repo.get_by(Plant, common_name: "Broccoli")

companions_count = 0

if tomato && basil do
  case Repo.get_by(CompanionRelationship, plant_a_id: tomato.id, plant_b_id: basil.id) do
    nil ->
      %CompanionRelationship{}
      |> CompanionRelationship.changeset(%{
        plant_a_id: tomato.id,
        plant_b_id: basil.id,
        relationship_type: "good",
        evidence_level: "traditional_strong",
        mechanism: "Basil repels aphids and may improve tomato flavor",
        notes: "Plant basil at the base of tomato plants"
      })
      |> Repo.insert!()
      companions_count = companions_count + 1
    _ -> :ok
  end
end

if tomato && broccoli do
  case Repo.get_by(CompanionRelationship, plant_a_id: tomato.id, plant_b_id: broccoli.id) do
    nil ->
      %CompanionRelationship{}
      |> CompanionRelationship.changeset(%{
        plant_a_id: tomato.id,
        plant_b_id: broccoli.id,
        relationship_type: "bad",
        evidence_level: "traditional_weak",
        mechanism: "Compete for nutrients",
        notes: "Keep at least 1m apart"
      })
      |> Repo.insert!()
      companions_count = companions_count + 1
    _ -> :ok
  end
end

IO.puts("  ✅ Created #{companions_count} companion relationships")

# ======================
# 5. Frost Dates
# ======================
IO.puts("\n5️⃣  Seeding Frost Dates...")

melbourne = Repo.get_by(City, city_name: "Melbourne", country: "Australia")
sydney = Repo.get_by(City, city_name: "Sydney", country: "Australia")
london = Repo.get_by(City, city_name: "London", country: "United Kingdom")

frost_count = 0

if melbourne do
  case Repo.get_by(CityFrostDate, city_id: melbourne.id) do
    nil ->
      %CityFrostDate{}
      |> CityFrostDate.changeset(%{
        city_id: melbourne.id,
        last_frost_date: "September 20",
        first_frost_date: "April 15",
        growing_season_days: 178,
        data_source: "BOM Climate Data",
        confidence_level: "high",
        notes: "Melbourne frost dates based on 30-year average"
      })
      |> Repo.insert!()
      frost_count = frost_count + 1
    _ -> :ok
  end
end

if sydney do
  case Repo.get_by(CityFrostDate, city_id: sydney.id) do
    nil ->
      %CityFrostDate{}
      |> CityFrostDate.changeset(%{
        city_id: sydney.id,
        last_frost_date: "August 15",
        first_frost_date: "May 10",
        growing_season_days: 268,
        data_source: "BOM Climate Data",
        confidence_level: "high",
        notes: "Sydney has rare frost events"
      })
      |> Repo.insert!()
      frost_count = frost_count + 1
    _ -> :ok
  end
end

if london do
  case Repo.get_by(CityFrostDate, city_id: london.id) do
    nil ->
      %CityFrostDate{}
      |> CityFrostDate.changeset(%{
        city_id: london.id,
        last_frost_date: "April 20",
        first_frost_date: "November 5",
        growing_season_days: 198,
        data_source: "Met Office UK",
        confidence_level: "high",
        notes: "London frost dates based on urban heat island effect"
      })
      |> Repo.insert!()
      frost_count = frost_count + 1
    _ -> :ok
  end
end

IO.puts("  ✅ Created #{frost_count} frost date records")

# ======================
# Summary
# ======================
IO.puts("\n" <> ("=" |> String.duplicate(60)))
IO.puts("🎉 Quick-Start Seed Complete!")
IO.puts("=" |> String.duplicate(60))
IO.puts("Summary:")
IO.puts("  - Köppen Zones: #{koppen_count} created")
IO.puts("  - Cities: #{cities_count} created")
IO.puts("  - Plants: #{plants_count} created")
IO.puts("  - Companion Relationships: #{companions_count} created")
IO.puts("  - Frost Dates: #{frost_count} created")
IO.puts("=" |> String.duplicate(60))
IO.puts("\n✨ You can now:")
IO.puts("  1. Visit the Planting Guide")
IO.puts("  2. Select 'Melbourne, Australia' or 'London, United Kingdom'")
IO.puts("  3. Click on 'Tomato' or 'Capsicum'")
IO.puts("  4. See precise planting dates with frost data! 🌡️")
IO.puts("")
