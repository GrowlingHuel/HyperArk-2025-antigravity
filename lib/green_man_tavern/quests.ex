defmodule GreenManTavern.Quests do
  import Ecto.Query
  alias GreenManTavern.Repo
  alias GreenManTavern.Quests.{Quest, UserQuest}
  alias GreenManTavern.Characters.Character

  # Quest template functions

  def list_quests(_opts \\ []) do
    Quest
    |> preload(:character)
    |> Repo.all()
  end

  def get_quest!(id), do: Repo.get!(Quest, id) |> Repo.preload(:character)

  def create_quest(attrs \\ %{}) do
    %Quest{}
    |> Quest.changeset(attrs)
    |> Repo.insert()
  end

  # User quest functions

  def list_user_quests(user_id, filter \\ "all") do
    # Use raw SQL to exclude description_embedding field to avoid Postgrex vector type errors
    # We don't need the embedding for listing quests, only for similarity search
    base_query = """
    SELECT id, user_id, quest_id, status, progress_data, started_at, completed_at,
           title, description, objective, steps, required_skills, calculated_difficulty,
           xp_rewards, conversation_context, quest_type, plant_tracking, date_window_start,
           date_window_end, planting_complete, harvest_complete, topic_tags,
           suggested_by_character_ids, merged_from_conversations, generated_by_character_id,
           inserted_at, updated_at
    FROM user_quests
    WHERE user_id = $1
    """

    filter_clause = case filter do
      "available" -> " AND status = 'available'"
      "active" -> " AND status = 'active'"
      "completed" -> " AND status = 'completed'"
      _ -> ""
    end

    sql = base_query <> filter_clause <> " ORDER BY inserted_at DESC"

    results = Ecto.Adapters.SQL.query!(Repo, sql, [user_id])

    # Convert results to UserQuest structs
    user_quests = results.rows
    |> Enum.map(fn row ->
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

    # Preload associations
    quest_ids = Enum.map(user_quests, & &1.quest_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    character_ids = Enum.map(user_quests, & &1.generated_by_character_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    quests_map = if quest_ids != [] do
      Quest
      |> where([q], q.id in ^quest_ids)
      |> preload(:character)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})
    else
      %{}
    end

    characters_map = if character_ids != [] do
      Character
      |> where([c], c.id in ^character_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})
    else
      %{}
    end

    # Attach preloaded associations
    Enum.map(user_quests, fn uq ->
      uq
      |> Map.put(:quest, Map.get(quests_map, uq.quest_id))
      |> Map.put(:generated_by_character, Map.get(characters_map, uq.generated_by_character_id))
    end)
  end

  def get_user_quest!(id) do
    Repo.get!(UserQuest, id) |> Repo.preload(quest: :character)
  end

  def create_user_quest(user_id, quest_id) do
    %UserQuest{}
    |> UserQuest.changeset(%{
      user_id: user_id,
      quest_id: quest_id,
      status: "available",
      progress_data: %{}
    })
    |> Repo.insert()
  end

  def accept_quest(%UserQuest{} = user_quest) do
    user_quest
    |> UserQuest.changeset(%{
      status: "active",
      started_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def complete_quest(%UserQuest{} = user_quest) do
    user_quest
    |> UserQuest.changeset(%{
      status: "completed",
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def search_user_quests(user_id, search_term) when is_binary(search_term) do
    search_pattern = "%#{search_term}%"

    UserQuest
    |> join(:inner, [uq], q in Quest, on: uq.quest_id == q.id)
    |> where([uq, q], uq.user_id == ^user_id)
    |> where([uq, q],
      ilike(q.title, ^search_pattern) or
      ilike(q.description, ^search_pattern)
    )
    |> preload([uq, q], quest: :character)
    |> order_by([uq], desc: uq.inserted_at)
    |> Repo.all()
  end
  def list_user_quests_with_characters(user_id, filter \\ "all") do
    list_user_quests(user_id, filter)
  end

  def get_user_quest_with_character!(id) do
    Repo.get!(UserQuest, id)
    |> Repo.preload(quest: :character)
  end
end
