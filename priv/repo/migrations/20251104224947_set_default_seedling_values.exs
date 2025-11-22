defmodule GreenManTavern.Repo.Migrations.SetDefaultSeedlingValues do
  use Ecto.Migration

  def up do
    # Direct-sow-only plants (roots, legumes)
    direct_sow_plants = [
      "Carrot", "Radish", "Turnip", "Parsnip", "Beetroot",
      "Beans (Bush)", "Beans (Pole)", "Peas", "Broad Bean",
      "Corn", "Sorghum", "Millet"
    ]

    # Set direct_sow_only = true
    for plant_name <- direct_sow_plants do
      execute """
      UPDATE plants
      SET direct_sow_only = true,
          transplant_friendly = false,
          transplant_notes = 'This plant is best direct-sown. Transplanting often damages roots or reduces vigor.'
      WHERE common_name = '#{String.replace(plant_name, "'", "''")}'
      """
    end

    # Slow-growing plants (longer seedling age)
    slow_growers = [
      {"Tomato", 42, "Moderate", "Transplant after last frost when soil is warm."},
      {"Capsicum", 56, "Moderate", "Harden off before transplanting. Very sensitive to cold."},
      {"Eggplant", 56, "Moderate", "Transplant after soil warms to 18°C+"},
      {"Chilli", 56, "Moderate", "Harden off before transplanting. Very sensitive to cold."},
      {"Celery", 70, "Moderate", "Needs long growing season. Transplant carefully."},
      {"Celeriac", 70, "Moderate", "Needs long growing season. Transplant carefully."}
    ]

    for {plant_name, seedling_age, difficulty, notes} <- slow_growers do
      escaped_name = String.replace(plant_name, "'", "''")
      escaped_notes = String.replace(notes, "'", "''")

      execute """
      UPDATE plants
      SET typical_seedling_age_days = #{seedling_age},
          seedling_difficulty = '#{difficulty}',
          transplant_notes = '#{escaped_notes}',
          transplant_friendly = true
      WHERE common_name = '#{escaped_name}'
      """
    end

    # Fast-growing plants (shorter seedling age)
    fast_growers = [
      {"Lettuce", 21, "Easy", "Transplant when young (2-3 true leaves)."},
      {"Spinach", 21, "Easy", "Transplant carefully to avoid bolting."},
      {"Brassicas", 28, "Easy", "Very transplant-friendly. Harden off first."},
      {"Cucumber", 21, "Moderate", "Handle roots carefully - sensitive to disturbance."},
      {"Squash", 21, "Moderate", "Transplant before roots get pot-bound."},
      {"Zucchini", 21, "Easy", "Transplant when soil is warm."}
    ]

    for {plant_name, seedling_age, difficulty, notes} <- fast_growers do
      escaped_name = String.replace(plant_name, "'", "''")
      escaped_notes = String.replace(notes, "'", "''")

      execute """
      UPDATE plants
      SET typical_seedling_age_days = #{seedling_age},
          seedling_difficulty = '#{difficulty}',
          transplant_notes = '#{escaped_notes}',
          transplant_friendly = true
      WHERE common_name LIKE '#{escaped_name}%'
      """
    end

    # Set default for all others (moderate plants)
    execute """
    UPDATE plants
    SET typical_seedling_age_days = 42,
        transplant_friendly = true,
        seedling_difficulty = growing_difficulty
    WHERE typical_seedling_age_days IS NULL
    """
  end

  def down do
    execute """
    UPDATE plants
    SET direct_sow_only = false,
        transplant_friendly = true,
        typical_seedling_age_days = NULL,
        seedling_difficulty = NULL,
        transplant_notes = NULL
    """
  end
end
