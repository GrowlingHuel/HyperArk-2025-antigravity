defmodule GreenManTavern.Quests.PlantingQuestManager do
  @moduledoc """
  Manages planting quests - links plants to quests, tracks planting/harvest progress,
  and generates quest content based on plant data.
  """

  require Logger
  import Ecto.Query
  alias GreenManTavern.{Repo, Quests, Skills}
  alias GreenManTavern.Quests.UserQuest
  alias GreenManTavern.PlantingGuide
  alias GreenManTavern.PlantingGuide.{Plant, UserPlant}

  @merge_window_days 7

  @doc """
  Main entry point called when plant status changes.
  Routes to appropriate handler based on status transition.

  ## Examples

      iex> handle_plant_status_change(1, 5, "interested", "will_plant", ~D[2025-11-09])
      {:ok, %UserQuest{}}

      iex> handle_plant_status_change(1, 5, "will_plant", "planted", ~D[2025-11-09])
      {:ok, %UserQuest{}}
  """
  def handle_plant_status_change(user_id, plant_id, old_status, new_status, planting_date) do
    require Logger

    # Get user plant
    case PlantingGuide.get_user_plant(user_id, plant_id) do
      nil ->
        Logger.warning("[PlantQuest] ⚠️ Plant #{plant_id} not found for user #{user_id}")
        {:error, :plant_not_found}

      user_plant ->
        Logger.info("[PlantQuest] 📝 Status change: #{old_status} → #{new_status} for plant #{plant_id} (user #{user_id})")

        case {old_status, new_status} do
          # Interested → Will Plant: Create quest
          {_, "will_plant"} ->
            create_or_update_planting_quest(user_id, user_plant, planting_date)

          # Will Plant → Planted: Activate quest
          {"will_plant", "planted"} ->
            quest = get_quest_for_plant(user_id, plant_id)
            if quest do
              mark_plant_planted(quest, plant_id, Date.utc_today())
            else
              # Fallback: create quest if missing
              case create_or_update_planting_quest(user_id, user_plant, planting_date) do
                {:ok, quest} -> mark_plant_planted(quest, plant_id, Date.utc_today())
                error -> error
              end
            end

          # Planted → Harvested: Complete harvest step
          {"planted", "harvested"} ->
            quest = get_quest_for_plant(user_id, plant_id)
            if quest do
              mark_plant_harvested(quest, plant_id, Date.utc_today())
            else
              {:error, :quest_not_found}
            end

          # Status downgrade (e.g., Will Plant → Interested): Remove from quest
          {old, new} when old in ["will_plant", "planted"] and new == "interested" ->
            quest = get_quest_for_plant(user_id, plant_id)
            if quest do
              case remove_plant_from_quest(quest, plant_id) do
                :deleted -> {:ok, :no_quest}
                result -> result
              end
            else
              {:ok, :no_quest}
            end

          # Other transitions: no quest action needed
          _ ->
            Logger.info("[PlantQuest] ℹ️ No quest action needed for status change: #{old_status} → #{new_status}")
            {:ok, :no_action}
        end
    end
  end

  @doc """
  Finds existing quest within 7-day window of planting_date, or creates new quest.
  Adds plant to existing quest if found, otherwise creates new quest.

  Returns {:ok, quest} or {:error, reason}
  """
  def create_or_update_planting_quest(user_id, plant, planting_date) do
    require Logger

    Logger.info("[PlantQuest] 🔍 Looking for compatible quest for plant #{plant.id} on #{inspect(planting_date)}")

    case find_compatible_quest(user_id, planting_date) do
      nil ->
        # Create new quest
        Logger.info("[PlantQuest] 📋 No compatible quest found, creating new quest")
        create_new_planting_quest(user_id, plant, planting_date)

      existing_quest ->
        # Add to existing quest
        Logger.info("[PlantQuest] 🔗 Found compatible quest #{existing_quest.id}, adding plant")
        add_plant_to_quest(existing_quest, plant)
    end
  end

  @doc """
  Searches for quests with date windows within 7 days of target_date.
  Finds quests where date_window_start is within 7 days before or after target_date.

  Returns quest or nil.
  """
  def find_compatible_quest(user_id, target_date) do
    require Logger

    # Find quests within 7 days of target_date
    # Use raw SQL to exclude description_embedding (vector type) to avoid Postgrex errors
    seven_days_before = Date.add(target_date, -7)
    seven_days_after = Date.add(target_date, 7)

    sql = """
    SELECT id, user_id, quest_id, status, progress_data, started_at, completed_at,
           title, description, objective, steps, required_skills, calculated_difficulty,
           xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
           date_window_end, planting_complete, harvest_complete, topic_tags,
           suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
           inserted_at, updated_at
    FROM user_quests
    WHERE user_id = $1
      AND quest_type = 'planting_window'
      AND status IN ('available', 'active')
      AND date_window_start >= $2
      AND date_window_start <= $3
    ORDER BY inserted_at DESC
    LIMIT 1
    """

    case Ecto.Adapters.SQL.query(Repo, sql, [user_id, seven_days_before, seven_days_after]) do
      {:ok, %{rows: []}} ->
        Logger.info("[PlantQuest] ℹ️ No compatible quest found for date #{inspect(target_date)} (user #{user_id})")
        nil

      {:ok, %{rows: [row]}} ->
        [
          id, user_id, quest_id, status, progress_data, started_at, completed_at,
          title, description, objective, steps, required_skills, calculated_difficulty,
          xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
          date_window_end, planting_complete, harvest_complete, topic_tags,
          suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
          inserted_at, updated_at
        ] = row

        quest = %UserQuest{
          id: id,
          user_id: user_id,
          quest_id: quest_id,
          status: status,
          progress_data: progress_data || %{},
          started_at: started_at,
          completed_at: completed_at,
          title: title,
          description: description,
          objective: objective,
          steps: steps,
          required_skills: required_skills || %{},
          calculated_difficulty: calculated_difficulty,
          xp_rewards: xp_rewards || %{},
          conversation_context: conversation_context,
          quest_type: quest_type,
          plant_tracking: plant_tracking || [],
          date_window_start: date_window_start,
          date_window_end: date_window_end,
          planting_complete: planting_complete || false,
          harvest_complete: harvest_complete || false,
          topic_tags: topic_tags || [],
          suggested_by_character_ids: suggested_by_character_ids || [],
          merged_from_conversations: merged_from_conversations || [],
          generated_by_character_id: generated_by_character_id,
          inserted_at: inserted_at,
          updated_at: updated_at
        }

        Logger.info("[PlantQuest] ✅ Found compatible quest #{quest.id} with window #{inspect(quest.date_window_start)} - #{inspect(quest.date_window_end)}")
        quest

      {:error, error} ->
        Logger.error("[PlantQuest] ❌ Error querying for compatible quest: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Expands date window to include a new date.
  Returns {new_start, new_end} with expanded window.
  """
  defp calculate_expanded_date_window(current_start, current_end, new_date) do
    # Handle nil dates - if no current window, use new_date for both
    case {current_start, current_end} do
      {nil, nil} ->
        {new_date, new_date}

      {nil, end_date} ->
        # Only end date exists
        new_end = if Date.compare(new_date, end_date) == :gt, do: new_date, else: end_date
        {new_date, new_end}

      {start_date, nil} ->
        # Only start date exists
        new_start = if Date.compare(new_date, start_date) == :lt, do: new_date, else: start_date
        {new_start, new_date}

      {start_date, end_date} ->
        # Both dates exist - expand window to include new date
        new_start = if Date.compare(new_date, start_date) == :lt, do: new_date, else: start_date
        new_end = if Date.compare(new_date, end_date) == :gt, do: new_date, else: end_date
        {new_start, new_end}
    end
  end

  @doc """
  Recalculates date window from plant tracking entries.
  Finds the earliest and latest planting dates from all plants.
  Returns {start_date, end_date}.
  """
  defp recalculate_date_window(plant_tracking) do
    # Extract all planting dates from tracking entries
    planting_dates =
      plant_tracking
      |> Enum.map(fn entry ->
        case entry["planting_date"] do
          date_str when is_binary(date_str) ->
            case Date.from_iso8601(date_str) do
              {:ok, date} -> date
              _ -> nil
            end
          date when is_struct(date, Date) -> date
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    case planting_dates do
      [] ->
        # No dates found, use today
        today = Date.utc_today()
        {today, today}

      dates ->
        # Find min and max dates
        start_date = Enum.min(dates, Date)
        end_date = Enum.max(dates, Date)
        {start_date, end_date}
    end
  end

  @doc """
  Calculates date window for quest.
  If quest has no dates: use new_plant_date for both start/end.
  If adding plant to existing: expand window to include new date if within 7 days.

  Returns {start_date, end_date}.
  """
  def calculate_date_window(existing_quest, new_plant_date) do
    case {existing_quest.date_window_start, existing_quest.date_window_end} do
      {nil, nil} ->
        # No existing dates - use new date for both
        {new_plant_date, new_plant_date}

      {existing_start, existing_end} ->
        # Expand window to include new date if within merge window
        days_before = Date.diff(new_plant_date, existing_start)
        days_after = Date.diff(existing_end, new_plant_date)

        cond do
          days_before >= 0 and days_after >= 0 ->
            # New date is within existing window
            {existing_start, existing_end}

          abs(days_before) <= @merge_window_days ->
            # New date is before but within merge window
            {new_plant_date, existing_end}

          abs(days_after) <= @merge_window_days ->
            # New date is after but within merge window
            {existing_start, new_plant_date}

          true ->
            # Too far from existing window - keep existing
            {existing_start, existing_end}
        end
    end
  end

  @doc """
  Adds plant to quest.plant_tracking JSONB.
  Updates date window if needed.
  Regenerates quest title/description.
  Returns updated quest.
  """
  def add_plant_to_quest(quest, plant) do
    require Logger

    # Preload plant association if not already loaded
    user_plant = case plant.plant do
      %Ecto.Association.NotLoaded{} -> Repo.preload(plant, :plant)
      _ -> plant
    end

    plant_data = user_plant.plant

    # Get current plant tracking
    current_tracking = get_plant_tracking(quest)

    # Check if plant already in quest
    if Enum.any?(current_tracking, &(&1["plant_id"] == user_plant.id)) do
      Logger.warning("[PlantQuest] ⚠️ Plant #{user_plant.id} (#{plant_data.common_name}) already in quest #{quest.id}")
      # Ensure link is set even if plant is already in quest
      if user_plant.planting_quest_id != quest.id do
        case user_plant
             |> UserPlant.changeset(%{planting_quest_id: quest.id})
             |> Repo.update() do
          {:ok, _updated_plant} ->
            Logger.info("[PlantQuest] ✅ Linked plant #{user_plant.id} to quest #{quest.id}")
          {:error, _} ->
            Logger.warning("[PlantQuest] ⚠️ Failed to link plant #{user_plant.id} to quest #{quest.id}")
        end
      end
      {:ok, quest}
    else
      Logger.info("[PlantQuest] 🌱 Adding plant #{user_plant.id} (#{plant_data.common_name}) to quest #{quest.id}")
      # Build new plant entry
      planting_date = user_plant.planting_date_start || user_plant.planting_date_end || Date.utc_today()

      # Calculate expected harvest
      days_to_maturity = plant_data.days_to_harvest_max || plant_data.days_to_harvest_min
      expected_harvest = calculate_expected_harvest(planting_date, days_to_maturity)

      plant_entry = %{
        "plant_id" => user_plant.id,
        "variety_name" => plant_data.common_name,
        "status" => user_plant.status,
        "planting_date" => if(planting_date, do: Date.to_string(planting_date), else: nil),
        "expected_harvest" => if(expected_harvest, do: Date.to_string(expected_harvest), else: nil),
        "actual_planting_date" => if(user_plant.actual_planting_date, do: Date.to_string(user_plant.actual_planting_date), else: nil),
        "actual_harvest_date" => nil
      }

      # Add to plant_tracking array
      updated_tracking = current_tracking ++ [plant_entry]

      # Recalculate date window
      {new_start, new_end} = calculate_expanded_date_window(
        quest.date_window_start,
        quest.date_window_end,
        planting_date
      )

      # Regenerate content with all plants
      content = generate_quest_content_for_plants(
        updated_tracking,
        new_start,
        new_end
      )

      # Update quest
      changeset =
        quest
        |> UserQuest.changeset(%{
          plant_tracking: updated_tracking,
          date_window_start: new_start,
          date_window_end: new_end,
          title: content.title,
          description: content.description,
          objective: content.objective,
          steps: content.steps
        })

      case Repo.update(changeset) do
        {:ok, updated_quest} ->
          # CRITICAL: Link the newly added plant to this quest
          case user_plant
               |> UserPlant.changeset(%{planting_quest_id: updated_quest.id})
               |> Repo.update() do
            {:ok, _updated_plant} ->
              Logger.info("[PlantQuest] ✅ Successfully added plant #{user_plant.id} (#{plant_data.common_name}) to quest #{updated_quest.id}")
              Logger.info("[PlantQuest] ✅ Linked plant #{user_plant.id} to quest #{updated_quest.id}")
              {:ok, updated_quest}

            {:error, plant_changeset} ->
              Logger.warning("[PlantQuest] ⚠️ Added plant to quest #{updated_quest.id} but failed to link plant #{user_plant.id}: #{inspect(plant_changeset.errors)}")
              # Still return success since quest was updated
              {:ok, updated_quest}
          end

        {:error, changeset} ->
          Logger.error("[PlantQuest] ❌ Failed to add plant #{user_plant.id} to quest #{quest.id}: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end
  end

  @doc """
  Removes plant from quest.plant_tracking.
  If quest becomes empty: delete quest.
  Otherwise recalculates date window and regenerates content.
  Returns updated quest or {:ok, :deleted}.
  """
  def remove_plant_from_quest(quest, plant_id) do
    require Logger

    # Get current tracking
    current_tracking = get_plant_tracking(quest)

    # Find plant name for logging
    plant_name = case Enum.find(current_tracking, &(&1["plant_id"] == plant_id)) do
      nil -> "plant #{plant_id}"
      entry -> entry["variety_name"] || "plant #{plant_id}"
    end

    Logger.info("[PlantQuest] 🗑️ Removing #{plant_name} (ID: #{plant_id}) from quest #{quest.id}")

    # Remove plant from tracking
    updated_tracking = Enum.reject(current_tracking, fn p -> p["plant_id"] == plant_id end)

    case length(updated_tracking) do
      0 ->
        # No plants left, delete quest
        Logger.info("[PlantQuest] 🗑️ Quest #{quest.id} is now empty, deleting quest")
        case Repo.delete(quest) do
          {:ok, _} ->
            Logger.info("[PlantQuest] ✅ Successfully deleted empty quest #{quest.id}")
            {:ok, :deleted}
          {:error, changeset} ->
            Logger.error("[PlantQuest] ❌ Failed to delete quest #{quest.id}: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

      _ ->
        # Recalculate date window based on remaining plants
        {new_start, new_end} = recalculate_date_window(updated_tracking)

        # Regenerate content
        content = generate_quest_content_for_plants(updated_tracking, new_start, new_end)

        # Update quest
        changeset =
          quest
          |> UserQuest.changeset(%{
            plant_tracking: updated_tracking,
            date_window_start: new_start,
            date_window_end: new_end,
            title: content.title,
            description: content.description,
            objective: content.objective,
            steps: content.steps
          })

        case Repo.update(changeset) do
          {:ok, updated} ->
            Logger.info("[PlantQuest] ✅ Successfully removed #{plant_name} from quest #{updated.id} (#{length(updated_tracking)} plants remaining)")
            {:ok, updated}

          {:error, changeset} ->
            Logger.error("[PlantQuest] ❌ Failed to remove plant #{plant_id} from quest #{quest.id}: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
    end
  end

  @doc """
  Updates plant status in quest.plant_tracking to "have_planted".
  Checks if all plants planted → set planting_complete = true.
  Changes quest status to 'active' when first plant is planted.
  Returns updated quest.
  """
  def mark_plant_planted(quest, plant_id, actual_date) do
    require Logger

    # Get current tracking
    current_tracking = get_plant_tracking(quest)

    # Find plant name for logging
    plant_entry = Enum.find(current_tracking, &(&1["plant_id"] == plant_id))
    plant_name = if plant_entry, do: plant_entry["variety_name"] || "plant #{plant_id}", else: "plant #{plant_id}"

    Logger.info("[PlantQuest] 🌱 Marking #{plant_name} (ID: #{plant_id}) as planted in quest #{quest.id} on #{Date.to_string(actual_date)}")

    # Update plant in tracking
    updated_tracking = Enum.map(current_tracking, fn plant ->
      if plant["plant_id"] == plant_id do
        plant
        |> Map.put("status", "have_planted")
        |> Map.put("actual_planting_date", Date.to_string(actual_date))
      else
        plant
      end
    end)

    # Check if all plants planted
    all_planted = Enum.all?(updated_tracking, fn p -> p["status"] in ["have_planted", "have_harvested"] end)

    old_status = quest.status
    new_status = "active"  # Quest becomes active when first plant is planted

    # Update quest
    changeset =
      quest
      |> UserQuest.changeset(%{
        plant_tracking: updated_tracking,
        planting_complete: all_planted,
        status: new_status
      })

    case Repo.update(changeset) do
      {:ok, updated} ->
        if old_status != new_status do
          Logger.info("[PlantQuest] 📝 Updated quest #{updated.id} status: #{old_status} → #{new_status}")
        end
        if all_planted do
          Logger.info("[PlantQuest] ✅ All plants planted in quest #{updated.id} (#{length(updated_tracking)}/#{length(updated_tracking)})")
        else
          planted_count = Enum.count(updated_tracking, fn p -> p["status"] in ["have_planted", "have_harvested"] end)
          Logger.info("[PlantQuest] 📊 Planting progress: #{planted_count}/#{length(updated_tracking)} plants planted in quest #{updated.id}")
        end
        {:ok, updated}

      {:error, changeset} ->
        Logger.error("[PlantQuest] ❌ Failed to mark plant #{plant_id} as planted in quest #{quest.id}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Updates plant harvest status in quest.plant_tracking.
  Checks if all plants harvested → set harvest_complete = true.
  If harvest_complete: change quest status to 'completed', award XP.
  Returns updated quest.
  """
  def mark_plant_harvested(quest, plant_id, harvest_date) do
    require Logger

    # Get current tracking
    current_tracking = get_plant_tracking(quest)

    # Find plant name for logging
    plant_entry = Enum.find(current_tracking, &(&1["plant_id"] == plant_id))
    plant_name = if plant_entry, do: plant_entry["variety_name"] || "plant #{plant_id}", else: "plant #{plant_id}"

    Logger.info("[PlantQuest] 🌾 Marking #{plant_name} (ID: #{plant_id}) as harvested in quest #{quest.id} on #{Date.to_string(harvest_date)}")

    # Update plant in tracking
    updated_tracking = Enum.map(current_tracking, fn plant ->
      if plant["plant_id"] == plant_id do
        plant
        |> Map.put("status", "have_harvested")
        |> Map.put("actual_harvest_date", Date.to_string(harvest_date))
      else
        plant
      end
    end)

    # Check if all plants harvested
    all_harvested = Enum.all?(updated_tracking, fn p -> p["status"] == "have_harvested" end)

    old_status = quest.status
    new_status = if(all_harvested, do: "completed", else: "active")

    # Update quest
    changeset =
      quest
      |> UserQuest.changeset(%{
        plant_tracking: updated_tracking,
        harvest_complete: all_harvested,
        status: new_status
      })

    case Repo.update(changeset) do
      {:ok, updated_quest} = result ->
        if all_harvested do
          Logger.info("[PlantQuest] 🎉 Quest #{updated_quest.id} completed! All #{length(updated_tracking)} plants harvested")
          if old_status != new_status do
            Logger.info("[PlantQuest] 📝 Updated quest #{updated_quest.id} status: #{old_status} → #{new_status}")
          end
          award_quest_completion_xp(updated_quest)
        else
          harvested_count = Enum.count(updated_tracking, fn p -> p["status"] == "have_harvested" end)
          Logger.info("[PlantQuest] 📊 Harvest progress: #{harvested_count}/#{length(updated_tracking)} plants harvested in quest #{updated_quest.id}")
        end
        result

      {:error, changeset} ->
        Logger.error("[PlantQuest] ❌ Failed to mark plant #{plant_id} as harvested in quest #{quest.id}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  @doc """
  Generates quest content from plant entries directly.
  Used when creating new quests before they exist in the database.

  Returns %{title: "", description: "", objective: "", steps: map}
  """
  def generate_quest_content_for_plants(plant_entries, start_date, end_date) do
    # Format title
    title = if Date.compare(start_date, end_date) == :eq do
      "Planting Day - #{format_date(start_date)}"
    else
      "Planting Window - #{format_date(start_date)} to #{format_date(end_date)}"
    end

    # Build plant list for description
    plant_names = Enum.map(plant_entries, fn p -> p["variety_name"] end)
    plant_list = format_plant_list(plant_names)

    description = "Plant #{length(plant_entries)} #{pluralize("variety", length(plant_entries))}: #{plant_list}"

    objective = "Successfully plant and grow #{plant_list} to harvest"

    # Build steps
    steps = build_planting_steps(plant_entries)

    %{
      title: title,
      description: description,
      objective: objective,
      steps: steps
    }
  end

  @doc """
  Generates quest title, description, objective, and steps based on plants in quest.

  Title: "Planting Day - Nov 9" or "Planting Window - Nov 9-15"
  Description: Lists all plants
  Steps: Plant-specific steps array

  Returns %{title: "", description: "", objective: "", steps: []}
  """
  def generate_quest_content(quest) do
    tracking = get_plant_tracking(quest)
    plant_ids = Enum.map(tracking, & &1["plant_id"])

    # Load plants
    plants =
      plant_ids
      |> Enum.map(fn id ->
        try do
          PlantingGuide.get_plant!(id)
        rescue
          Ecto.NoResultsError -> nil
        end
      end)
      |> Enum.filter(& &1)

    # Determine if single day or window
    {start_date, end_date} = {quest.date_window_start, quest.date_window_end}
    is_single_day = start_date == end_date

    # Generate title
    title = if is_single_day do
      date_str = format_date(start_date)
      "Planting Day - #{date_str}"
    else
      start_str = format_date(start_date)
      end_str = format_date(end_date)
      "Planting Window - #{start_str} - #{end_str}"
    end

    # Generate description
    plant_names = Enum.map(plants, & &1.common_name) |> Enum.join(", ")
    description = "Plant #{plant_names} during this #{if is_single_day, do: "day", else: "window"}."

    # Generate objective
    objective = "Plant and care for #{length(plants)} #{if length(plants) == 1, do: "plant", else: "plants"}."

    # Generate steps
    steps =
      plants
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {plant, idx} ->
        [
          "Prepare soil for #{plant.common_name}",
          "Plant #{plant.common_name}",
          "Water #{plant.common_name} after planting",
          "Monitor #{plant.common_name} growth"
        ]
      end)

    %{
      title: title,
      description: description,
      objective: objective,
      steps: steps
    }
  end

  @doc """
  Calculates expected harvest date by adding days_to_maturity to planting_date.
  Returns date.
  """
  def calculate_expected_harvest(planting_date, days_to_maturity) when is_struct(planting_date, Date) and is_integer(days_to_maturity) do
    Date.add(planting_date, days_to_maturity)
  end

  def calculate_expected_harvest(_planting_date, _days_to_maturity), do: nil

  @doc """
  Calculates quest progress statistics.
  Returns %{planted: 2, total: 3, harvested: 1, planting_complete: false}
  """
  def get_quest_progress(quest) do
    tracking = get_plant_tracking(quest)

    total = length(tracking)
    planted = Enum.count(tracking, &(&1["status"] == "planted" || &1["status"] == "harvested"))
    harvested = Enum.count(tracking, &(&1["status"] == "harvested"))

    %{
      planted: planted,
      total: total,
      harvested: harvested,
      planting_complete: quest.planting_complete || false,
      harvest_complete: quest.harvest_complete || false
    }
  end

  # Private helper functions

  defp create_new_planting_quest(user_id, plant, planting_date) do
    require Logger

    # Preload plant association if not already loaded
    user_plant = case plant.plant do
      %Ecto.Association.NotLoaded{} -> Repo.preload(plant, :plant)
      _ -> plant
    end

    plant_data = user_plant.plant

    Logger.info("[PlantQuest] 📋 Creating new quest for plant #{user_plant.id} (#{plant_data.common_name}) on #{inspect(planting_date)}")

    # Calculate expected harvest
    days_to_maturity = plant_data.days_to_harvest_max || plant_data.days_to_harvest_min
    expected_harvest = calculate_expected_harvest(planting_date, days_to_maturity)

    # Build plant tracking entry
    plant_entry = %{
      "plant_id" => user_plant.id,
      "variety_name" => plant_data.common_name,
      "status" => "will_plant",
      "planting_date" => if(planting_date, do: Date.to_string(planting_date), else: nil),
      "expected_harvest" => if(expected_harvest, do: Date.to_string(expected_harvest), else: nil),
      "actual_planting_date" => nil,
      "actual_harvest_date" => nil
    }

    # Generate quest content
    content = generate_quest_content_for_plants([plant_entry], planting_date, planting_date)

    # Create quest
    changeset =
      %UserQuest{}
      |> UserQuest.changeset(%{
        user_id: user_id,
        quest_type: "planting_window",
        status: "available",
        title: content.title,
        description: content.description,
        objective: content.objective,
        steps: content.steps,
        plant_tracking: [plant_entry],
        date_window_start: planting_date,
        date_window_end: planting_date,
        planting_complete: false,
        harvest_complete: false
      })

    case Repo.insert(changeset) do
      {:ok, created_quest} ->
        # CRITICAL: Link the plant back to this quest
        case user_plant
             |> UserPlant.changeset(%{planting_quest_id: created_quest.id})
             |> Repo.update() do
          {:ok, _updated_plant} ->
            Logger.info("[PlantQuest] ✅ Created quest: \"#{created_quest.title}\" (ID: #{created_quest.id}) for user #{user_id} with plant #{plant_data.common_name}")
            Logger.info("[PlantQuest] ✅ Linked plant #{user_plant.id} to quest #{created_quest.id}")
            {:ok, created_quest}

          {:error, plant_changeset} ->
            Logger.error("[PlantQuest] ⚠️ Created quest #{created_quest.id} but failed to link plant #{user_plant.id}: #{inspect(plant_changeset.errors)}")
            # Still return success since quest was created
            {:ok, created_quest}
        end

      {:error, changeset} ->
        Logger.error("[PlantQuest] ❌ Failed to create quest for user #{user_id}, plant #{user_plant.id}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp mark_plant_planted_by_id(user_id, plant_id, actual_date) do
    require Logger

    # Find quest containing this plant
    case find_quest_by_plant_id(user_id, plant_id) do
      nil ->
        Logger.warning("[PlantQuest] ⚠️ No quest found for plant #{plant_id} (user #{user_id})")
        {:error, :quest_not_found}

      quest ->
        mark_plant_planted(quest, plant_id, actual_date)
    end
  end

  defp mark_plant_harvested_by_id(user_id, plant_id, harvest_date) do
    require Logger

    # Find quest containing this plant
    case find_quest_by_plant_id(user_id, plant_id) do
      nil ->
        Logger.warning("[PlantQuest] ⚠️ No quest found for plant #{plant_id} (user #{user_id})")
        {:error, :quest_not_found}

      quest ->
        mark_plant_harvested(quest, plant_id, harvest_date)
    end
  end

  defp remove_plant_from_quest_by_plant_id(user_id, plant_id) do
    require Logger

    case find_quest_by_plant_id(user_id, plant_id) do
      nil ->
        Logger.info("[PlantQuest] ℹ️ No quest found for plant #{plant_id} (user #{user_id}), nothing to remove")
        {:ok, :no_quest}

      quest ->
        remove_plant_from_quest(quest, plant_id)
    end
  end

  @doc """
  Finds quest containing the specified plant_id.
  Tries multiple approaches:
  1. Check planting_quest_id link on UserPlant
  2. Search plant_tracking JSONB field (handles both {"steps": [...]} and [...] formats)

  Returns quest or nil.
  """
  def get_quest_for_plant(user_id, plant_id) do
    require Logger

    # Approach 1: Check planting_quest_id link
    case PlantingGuide.get_user_plant(user_id, plant_id) do
      nil ->
        Logger.debug("[PlantQuest] 🔍 UserPlant not found for plant #{plant_id} (user #{user_id})")
        nil

      user_plant ->
        # Approach 1: Check planting_quest_id link using raw SQL to avoid vector type errors
        if user_plant.planting_quest_id do
          sql = """
          SELECT id, user_id, quest_id, status, progress_data, started_at, completed_at,
                 title, description, objective, steps, required_skills, calculated_difficulty,
                 xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
                 date_window_end, planting_complete, harvest_complete, topic_tags,
                 suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
                 inserted_at, updated_at
          FROM user_quests
          WHERE id = $1
          """

          case Ecto.Adapters.SQL.query(Repo, sql, [user_plant.planting_quest_id]) do
            {:ok, %{rows: [row]}} ->
              [
                id, user_id, quest_id, status, progress_data, started_at, completed_at,
                title, description, objective, steps, required_skills, calculated_difficulty,
                xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
                date_window_end, planting_complete, harvest_complete, topic_tags,
                suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
                inserted_at, updated_at
              ] = row

              quest = %UserQuest{
                id: id,
                user_id: user_id,
                quest_id: quest_id,
                status: status,
                progress_data: progress_data || %{},
                started_at: started_at,
                completed_at: completed_at,
                title: title,
                description: description,
                objective: objective,
                steps: steps,
                required_skills: required_skills || %{},
                calculated_difficulty: calculated_difficulty,
                xp_rewards: xp_rewards || %{},
                conversation_context: conversation_context,
                quest_type: quest_type,
                plant_tracking: plant_tracking || [],
                date_window_start: date_window_start,
                date_window_end: date_window_end,
                planting_complete: planting_complete || false,
                harvest_complete: harvest_complete || false,
                topic_tags: topic_tags || [],
                suggested_by_character_ids: suggested_by_character_ids || [],
                merged_from_conversations: merged_from_conversations || [],
                generated_by_character_id: generated_by_character_id,
                inserted_at: inserted_at,
                updated_at: updated_at
              }

              Logger.debug("[PlantQuest] ✅ Found quest #{quest.id} via planting_quest_id link for plant #{plant_id} (user #{user_id})")
              quest

            _ ->
              # Quest ID exists but quest not found (might be deleted)
              Logger.warning("[PlantQuest] ⚠️ planting_quest_id #{user_plant.planting_quest_id} not found for plant #{plant_id}")
              nil
          end
        else
          # Approach 2: Search plant_tracking JSON
          # Handle both {"steps": [...]} and [...] formats
          # Use raw SQL to exclude description_embedding (vector type) to avoid Postgrex errors
          plant_id_json = Jason.encode!([%{"plant_id" => plant_id}])

          sql = """
          SELECT id, user_id, quest_id, status, progress_data, started_at, completed_at,
                 title, description, objective, steps, required_skills, calculated_difficulty,
                 xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
                 date_window_end, planting_complete, harvest_complete, topic_tags,
                 suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
                 inserted_at, updated_at
          FROM user_quests
          WHERE user_id = $1
            AND quest_type = 'planting_window'
            AND (
              plant_tracking @> $2::jsonb OR
              plant_tracking->'steps' @> $2::jsonb
            )
          ORDER BY inserted_at DESC
          LIMIT 1
          """

          case Ecto.Adapters.SQL.query(Repo, sql, [user_id, plant_id_json]) do
            {:ok, %{rows: []}} ->
              Logger.debug("[PlantQuest] 🔍 No quest found in plant_tracking for plant #{plant_id} (user #{user_id})")
              nil

            {:ok, %{rows: [row]}} ->
              [
                id, user_id, quest_id, status, progress_data, started_at, completed_at,
                title, description, objective, steps, required_skills, calculated_difficulty,
                xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
                date_window_end, planting_complete, harvest_complete, topic_tags,
                suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
                inserted_at, updated_at
              ] = row

              quest = %UserQuest{
                id: id,
                user_id: user_id,
                quest_id: quest_id,
                status: status,
                progress_data: progress_data || %{},
                started_at: started_at,
                completed_at: completed_at,
                title: title,
                description: description,
                objective: objective,
                steps: steps,
                required_skills: required_skills || %{},
                calculated_difficulty: calculated_difficulty,
                xp_rewards: xp_rewards || %{},
                conversation_context: conversation_context,
                quest_type: quest_type,
                plant_tracking: plant_tracking || [],
                date_window_start: date_window_start,
                date_window_end: date_window_end,
                planting_complete: planting_complete || false,
                harvest_complete: harvest_complete || false,
                topic_tags: topic_tags || [],
                suggested_by_character_ids: suggested_by_character_ids || [],
                merged_from_conversations: merged_from_conversations || [],
                generated_by_character_id: generated_by_character_id,
                inserted_at: inserted_at,
                updated_at: updated_at
              }

              Logger.debug("[PlantQuest] ✅ Found quest #{quest.id} in plant_tracking for plant #{plant_id} (user #{user_id})")
              quest

            {:error, error} ->
              Logger.error("[PlantQuest] ❌ Error querying for quest: #{inspect(error)}")
              nil
          end
        end
    end
  end

  defp find_quest_by_plant_id(user_id, plant_id) do
    # Fallback: Find quests that contain this plant_id in their plant_tracking JSONB
    # Use raw SQL to exclude description_embedding (vector type) to avoid Postgrex errors
    sql = """
    SELECT id, user_id, quest_id, status, progress_data, started_at, completed_at,
           title, description, objective, steps, required_skills, calculated_difficulty,
           xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
           date_window_end, planting_complete, harvest_complete, topic_tags,
           suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
           inserted_at, updated_at
    FROM user_quests
    WHERE user_id = $1
      AND quest_type = 'planting_window'
    ORDER BY inserted_at DESC
    """

    case Ecto.Adapters.SQL.query(Repo, sql, [user_id]) do
      {:ok, %{rows: rows}} ->
        # Convert rows to UserQuest structs and filter in Elixir
        quests = Enum.map(rows, fn row ->
          [
            id, user_id, quest_id, status, progress_data, started_at, completed_at,
            title, description, objective, steps, required_skills, calculated_difficulty,
            xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
            date_window_end, planting_complete, harvest_complete, topic_tags,
            suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
            inserted_at, updated_at
          ] = row

          %UserQuest{
            id: id,
            user_id: user_id,
            quest_id: quest_id,
            status: status,
            progress_data: progress_data || %{},
            started_at: started_at,
            completed_at: completed_at,
            title: title,
            description: description,
            objective: objective,
            steps: steps,
            required_skills: required_skills || %{},
            calculated_difficulty: calculated_difficulty,
            xp_rewards: xp_rewards || %{},
            conversation_context: conversation_context,
            quest_type: quest_type,
            plant_tracking: plant_tracking || [],
            date_window_start: date_window_start,
            date_window_end: date_window_end,
            planting_complete: planting_complete || false,
            harvest_complete: harvest_complete || false,
            topic_tags: topic_tags || [],
            suggested_by_character_ids: suggested_by_character_ids || [],
            merged_from_conversations: merged_from_conversations || [],
            generated_by_character_id: generated_by_character_id,
            inserted_at: inserted_at,
            updated_at: updated_at
          }
        end)

        # Filter to find quest containing this plant_id
        Enum.find(quests, fn quest ->
          tracking = get_plant_tracking(quest)
          Enum.any?(tracking, &(&1["plant_id"] == plant_id))
        end)

      {:error, _error} ->
        nil
    end
  end

  defp get_plant_tracking(quest) do
    case quest.plant_tracking do
      %{"steps" => steps} when is_list(steps) -> steps
      steps when is_list(steps) -> steps
      _ -> []
    end
  end

  defp build_planting_steps(plant_entries) do
    preparation_step = %{
      "text" => "Prepare planting area and gather materials",
      "completed" => false
    }

    plant_steps = Enum.map(plant_entries, fn plant ->
      %{
        "text" => "Plant #{plant["variety_name"]}",
        "plant_id" => plant["plant_id"],
        "completed" => plant["status"] in ["have_planted", "have_harvested"],
        "planted_date" => plant["actual_planting_date"],
        "expected_harvest" => plant["expected_harvest"]
      }
    end)

    harvest_step = %{
      "text" => "Harvest all plants when ready",
      "completed" => Enum.all?(plant_entries, fn p -> p["status"] == "have_harvested" end)
    }

    %{"steps" => [preparation_step] ++ plant_steps ++ [harvest_step]}
  end

  defp format_date(date) when is_struct(date, Date) do
    # Format as "January 5, 2025" (no leading zero on day)
    month_name = Calendar.strftime(date, "%B")
    day = Integer.to_string(date.day)  # Removes leading zero automatically
    year = Integer.to_string(date.year)
    "#{month_name} #{day}, #{year}"
  end

  defp format_date(nil), do: "Unknown"

  defp format_plant_list(names) do
    case length(names) do
      1 -> hd(names)
      2 -> Enum.join(names, " and ")
      _ ->
        {last, rest} = List.pop_at(names, -1)
        Enum.join(rest, ", ") <> ", and " <> last
    end
  end

  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  @doc """
  Awards XP to user for completing a planting quest.
  Calculates XP based on number of plants in the quest.
  """
  defp award_quest_completion_xp(quest) do
    require Logger

    # Get plant tracking to count plants
    tracking = get_plant_tracking(quest)
    plant_count = length(tracking)

    # Calculate XP based on number of plants and time to completion
    base_xp = plant_count * 50

    Logger.info("[PlantQuest] 🎁 Calculating XP reward for quest #{quest.id}: #{plant_count} plants × 50 = #{base_xp} XP")

    # Award to planting skill domain
    case Skills.award_xp(quest.user_id, "planting", base_xp, %{
      source: "quest_completion",
      quest_id: quest.id,
      quest_title: quest.title,
      plants_count: plant_count
    }) do
      {:ok, _skill, level_up: level_up} ->
        level_msg = if level_up, do: " (LEVEL UP! 🎉)", else: ""
        Logger.info("[PlantQuest] 🎉 Quest completed! Awarded #{base_xp} XP to user #{quest.user_id} for: \"#{quest.title}\"#{level_msg}")

      {:error, reason} ->
        Logger.warning("[PlantQuest] ⚠️ Failed to award #{base_xp} XP for quest #{quest.id}: #{inspect(reason)}")
    end
  end

  defp month_abbrev(month) do
    case month do
      1 -> "Jan"
      2 -> "Feb"
      3 -> "Mar"
      4 -> "Apr"
      5 -> "May"
      6 -> "Jun"
      7 -> "Jul"
      8 -> "Aug"
      9 -> "Sep"
      10 -> "Oct"
      11 -> "Nov"
      12 -> "Dec"
    end
  end
end
