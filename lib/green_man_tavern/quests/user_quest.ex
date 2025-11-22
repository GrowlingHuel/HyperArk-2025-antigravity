defmodule GreenManTavern.Quests.UserQuest do
  use Ecto.Schema
  import Ecto.Changeset

  # Custom type for plant_tracking that stores arrays directly (no wrapper)
  defmodule PlantTrackingType do
    @behaviour Ecto.Type

    def type, do: :map

    def cast(value) when is_list(value), do: {:ok, value}
    def cast(value) when is_map(value), do: {:ok, normalize_plant_tracking(value)}
    def cast(_), do: :error

    def load(value) when is_list(value), do: {:ok, value}
    def load(value) when is_map(value), do: {:ok, normalize_plant_tracking(value)}
    def load(nil), do: {:ok, []}
    def load(_), do: :error

    def dump(value) when is_list(value), do: {:ok, value}
    def dump(value) when is_map(value), do: {:ok, normalize_plant_tracking(value)}
    def dump(_), do: :error

    def embed_as(_), do: :self

    def equal?(a, b), do: normalize_plant_tracking(a) == normalize_plant_tracking(b)

    # Normalize plant_tracking to always be a list (extract from "steps" wrapper if present)
    defp normalize_plant_tracking(%{"steps" => steps}) when is_list(steps) do
      # Extract from old format: %{"steps" => [...]}
      steps
    end

    defp normalize_plant_tracking(value) when is_map(value) do
      # Map but no "steps" key - return empty list
      []
    end

    defp normalize_plant_tracking(_) do
      # Fallback to empty list
      []
    end
  end

  schema "user_quests" do
    field :status, :string, default: "available"
    field :progress_data, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    # Dynamic quest fields (for AI-generated quests when quest_id is NULL)
    field :title, :string
    field :description, :string
    field :objective, :string
    field :steps, :map  # JSONB array stored as list in Elixir

    # Quest difficulty and skill tracking fields
    field :required_skills, :map, default: %{}
    field :calculated_difficulty, :integer
    field :xp_rewards, :map, default: %{}
    field :conversation_context, :string

    # Plant quest tracking fields
    field :quest_type, :string
    field :plant_tracking, PlantTrackingType, default: []
    field :date_window_start, :date
    field :date_window_end, :date
    field :planting_complete, :boolean, default: false
    field :harvest_complete, :boolean, default: false

    # Quest deduplication fields
    field :topic_tags, {:array, :string}, default: []
    field :suggested_by_character_ids, {:array, :integer}, default: []
    field :merged_from_conversations, {:array, :string}, default: []
    # Conversation key points: stores key points from each character who suggested/merged into this quest
    # Format: [%{"character_name" => "...", "key_points" => ["...", "..."], "added_at" => "..."}, ...]
    # Stored as JSONB array in database, but Ecto :map type requires %{} default
    field :conversation_key_points, :map, default: %{}
    # Vector embedding for quest description (pgvector, 1536 dimensions)
    # Stored as list of floats in Elixir, converted to vector type in database
    field :description_embedding, :map

    belongs_to :user, GreenManTavern.Accounts.User
    belongs_to :quest, GreenManTavern.Quests.Quest
    belongs_to :generated_by_character, GreenManTavern.Characters.Character

    timestamps()
  end

  @statuses ["available", "active", "completed", "failed"]
  @quest_types ["planting_window", "conversation", "system_opportunity"]

  @doc false
  def changeset(user_quest, attrs) do
    # Normalize steps: handle both array and map inputs
    # AI sends: ["Step 1", "Step 2"] -> we keep as list for JSONB
    normalized_steps = extract_steps(attrs)

    # Cast all fields except steps (which we handle separately)
    changeset =
      user_quest
      |> cast(attrs, [
        :user_id,
        :quest_id,
        :status,
        :progress_data,
        :started_at,
        :completed_at,
        :title,
        :description,
        :objective,
        :required_skills,
        :calculated_difficulty,
        :xp_rewards,
        :generated_by_character_id,
        :conversation_context,
        :quest_type,
        :plant_tracking,
        :date_window_start,
        :date_window_end,
        :planting_complete,
        :harvest_complete,
        :topic_tags,
        :suggested_by_character_ids,
        :merged_from_conversations,
        :conversation_key_points,
        :description_embedding
      ])
      |> put_steps(normalized_steps)
      |> normalize_conversation_key_points()
      |> validate_required([:user_id, :status])
      |> validate_quest_id_or_dynamic_fields()
      |> validate_inclusion(:status, @statuses)
      |> validate_quest_type()
      |> validate_planting_quest_dates()
      |> validate_number(:calculated_difficulty,
        greater_than_or_equal_to: 1,
        less_than_or_equal_to: 10
      )
      |> foreign_key_constraint(:user_id)
      |> foreign_key_constraint(:quest_id)
      |> foreign_key_constraint(:generated_by_character_id)
      |> unique_constraint([:user_id, :quest_id])

    changeset
  end

  # Validate quest_type if provided
  defp validate_quest_type(changeset) do
    quest_type = get_field(changeset, :quest_type)

    if quest_type && quest_type != "" do
      validate_inclusion(changeset, :quest_type, @quest_types)
    else
      changeset
    end
  end

  # Validate that planting_window quests have date_window_start
  defp validate_planting_quest_dates(changeset) do
    quest_type = get_field(changeset, :quest_type)

    if quest_type == "planting_window" do
      validate_required(changeset, :date_window_start)
    else
      changeset
    end
  end

  @doc """
  Checks if a quest is a planting quest.
  Returns true if quest_type == "planting_window".
  """
  def is_planting_quest?(quest) do
    quest.quest_type == "planting_window"
  end

  @doc """
  Extracts plant_ids from quest's plant_tracking JSONB.
  Returns list of plant IDs.
  """
  def get_plants(quest) do
    plant_tracking = quest.plant_tracking
    steps = get_plant_tracking_steps(plant_tracking)

    Enum.map(steps, fn entry ->
      case entry do
        %{"plant_id" => plant_id} when is_integer(plant_id) -> plant_id
        %{"plant_id" => plant_id} when is_binary(plant_id) -> String.to_integer(plant_id)
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Adds a plant to quest's plant_tracking array.
  plant_data should be a map with at least "plant_id" key.
  Returns updated plant_tracking array.
  """
  def add_plant(quest, plant_data) do
    plant_tracking = quest.plant_tracking
    current_steps = get_plant_tracking_steps(plant_tracking)
    plant_id = get_plant_id(plant_data)

    # Check if plant already exists
    if Enum.any?(current_steps, fn entry -> get_plant_id(entry) == plant_id end) do
      # Plant already exists, return unchanged
      plant_tracking
    else
      # Add new plant entry
      [plant_data | current_steps]
    end
  end

  @doc """
  Removes a plant from quest's plant_tracking array by plant_id.
  Returns updated plant_tracking array.
  """
  def remove_plant(quest, plant_id) when is_integer(plant_id) do
    plant_tracking = quest.plant_tracking
    current_steps = get_plant_tracking_steps(plant_tracking)
    Enum.reject(current_steps, fn entry -> get_plant_id(entry) == plant_id end)
  end

  def remove_plant(quest, plant_id) when is_binary(plant_id) do
    remove_plant(quest, String.to_integer(plant_id))
  end

  # Helper to extract plant_tracking steps
  defp get_plant_tracking_steps(plant_tracking) do
    case plant_tracking do
      %{"steps" => steps} when is_list(steps) -> steps
      steps when is_list(steps) -> steps
      _ -> []
    end
  end

  # Helper to extract plant_id from entry (handles both integer and string IDs)
  defp get_plant_id(entry) when is_map(entry) do
    case Map.get(entry, "plant_id") do
      id when is_integer(id) -> id
      id when is_binary(id) -> String.to_integer(id)
      _ -> nil
    end
  end

  defp get_plant_id(_), do: nil

  # Extract and normalize steps field to handle array inputs from AI
  # Handles: ["Step 1", "Step 2"] -> returns list for JSONB storage
  defp extract_steps(attrs) do
    steps_value =
      cond do
        Map.has_key?(attrs, :steps) -> Map.get(attrs, :steps)
        Map.has_key?(attrs, "steps") -> Map.get(attrs, "steps")
        true -> nil
      end

    cond do
      is_list(steps_value) ->
        # Array input: return as-is (JSONB will serialize it correctly)
        steps_value

      is_map(steps_value) ->
        # Map input: extract array if nested, otherwise return empty list
        if Map.has_key?(steps_value, "steps") and is_list(steps_value["steps"]) do
          steps_value["steps"]
        else
          []
        end

      true ->
        # Default to empty list if not provided or invalid
        []
    end
  end

  # Put steps into changeset (wraps array in map for Ecto's :map type)
  defp put_steps(changeset, steps) when is_list(steps) do
    # Wrap array in a map so Ecto's :map type accepts it
    # Store as: %{"steps" => ["Step 1", "Step 2", "Step 3"]}
    steps_map = %{"steps" => steps}
    put_change(changeset, :steps, steps_map)
  end

  defp put_steps(changeset, _steps) do
    # Default to empty map with empty steps array
    put_change(changeset, :steps, %{"steps" => []})
  end

  # Normalize conversation_key_points: convert %{} to [] for JSONB array storage
  defp normalize_conversation_key_points(changeset) do
    key_points = get_field(changeset, :conversation_key_points)

    normalized = case key_points do
      nil -> []
      %{} -> []  # Empty map becomes empty list
      list when is_list(list) -> list
      _ -> []  # Fallback
    end

    put_change(changeset, :conversation_key_points, normalized)
  end

  # Validate that either quest_id is set (template quest) or dynamic fields are set (AI-generated quest)
  defp validate_quest_id_or_dynamic_fields(changeset) do
    quest_id = get_field(changeset, :quest_id)
    title = get_field(changeset, :title)
    objective = get_field(changeset, :objective)

    cond do
      # Template quest: quest_id must be set
      not is_nil(quest_id) ->
        changeset

      # Dynamic quest: title and objective must be set
      not is_nil(title) and not is_nil(objective) ->
        changeset

      # Neither: invalid
      true ->
        add_error(changeset, :quest_id, "must be set for template quests, or title and objective must be set for dynamic quests")
    end
  end

  @doc """
  Adds a character ID to the suggested_by_character_ids array.
  If the character ID is already in the array, returns the quest unchanged.
  Returns the updated array.
  """
  def add_suggesting_character(quest, character_id) when is_integer(character_id) do
    current_ids = quest.suggested_by_character_ids || []

    if character_id in current_ids do
      current_ids
    else
      [character_id | current_ids]
    end
  end

  def add_suggesting_character(quest, character_id) when is_binary(character_id) do
    add_suggesting_character(quest, String.to_integer(character_id))
  end

  @doc """
  Adds a session_id to the merged_from_conversations array.
  If the session_id is already in the array, returns the quest unchanged.
  Returns the updated array.
  """
  def add_merged_conversation(quest, session_id) when is_binary(session_id) do
    current_sessions = quest.merged_from_conversations || []

    if session_id in current_sessions do
      current_sessions
    else
      [session_id | current_sessions]
    end
  end

  @doc """
  Checks if a character ID is in the suggested_by_character_ids array.
  Returns true if the character suggested this quest, false otherwise.
  """
  def is_suggested_by?(quest, character_id) when is_integer(character_id) do
    character_ids = quest.suggested_by_character_ids || []
    character_id in character_ids
  end

  def is_suggested_by?(quest, character_id) when is_binary(character_id) do
    is_suggested_by?(quest, String.to_integer(character_id))
  end
end
