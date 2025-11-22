defmodule GreenManTavern.Quests.CharacterVoice do
  @moduledoc """
  Generates character-specific flavor text for quest presentation.

  This module provides character-voiced introductions for quests based on
  the character who suggested the quest and the calculated difficulty for
  the user.

  ## Usage

      iex> CharacterVoice.get_quest_introduction(1, quest, difficulty_breakdown)
      %{
        introduction: "You're ready for this, dear. I'll be here if you need me.",
        tone: "encouraging"
      }
  """

  alias GreenManTavern.Characters

  @doc """
  Generates a character-specific quest introduction based on difficulty.

  Returns a map with:
  - `introduction`: The character's message
  - `tone`: The emotional tone of the message ("encouraging", "direct", "technical", etc.)

  ## Parameters

  - `character_id`: The ID of the character who suggested the quest
  - `quest`: The quest struct or map (currently unused but available for future customization)
  - `difficulty_breakdown`: The result from `DifficultyCalculator.calculate_difficulty/2`
    with `overall_difficulty` field ("easy", "medium", or "hard")

  ## Examples

      iex> difficulty_breakdown = %{overall_difficulty: "easy"}
      iex> CharacterVoice.get_quest_introduction(1, quest, difficulty_breakdown)
      %{
        introduction: "You're ready for this, dear. I'll be here if you need me.",
        tone: "encouraging"
      }
  """
  def get_quest_introduction(character_id, _quest, difficulty_breakdown)
      when is_integer(character_id) and is_map(difficulty_breakdown) do
    try do
      character = Characters.get_character!(character_id)
      overall_difficulty = Map.get(difficulty_breakdown, :overall_difficulty, "medium")

      {introduction, tone} = get_character_message(character.name, overall_difficulty)

      %{
        introduction: introduction,
        tone: tone
      }
    rescue
      Ecto.NoResultsError ->
        # Fallback if character not found
        %{
          introduction: "This quest will help you grow your skills and build something meaningful.",
          tone: "neutral"
        }
    end
  end

  def get_quest_introduction(_character_id, _quest, _difficulty_breakdown) do
    # Fallback for invalid inputs
    %{
      introduction: "This quest will help you grow your skills and build something meaningful.",
      tone: "neutral"
    }
  end

  defp get_character_message(character_name, difficulty) do
    case {character_name, difficulty} do
      # The Grandmother
      {"The Grandmother", "easy"} ->
        {"You're ready for this, dear. I'll be here if you need me.", "encouraging"}

      {"The Grandmother", "medium"} ->
        {"This will stretch you a bit, but you have the foundation.", "encouraging"}

      {"The Grandmother", "hard"} ->
        {"This is ambitious, but I believe in you. Take your time.", "encouraging"}

      # The Farmer
      {"The Farmer", "easy"} ->
        {"You can handle this. Just do it.", "direct"}

      {"The Farmer", "medium"} ->
        {"Not rocket science. Follow the steps.", "direct"}

      {"The Farmer", "hard"} ->
        {"This'll be work, but you'll learn fast if you pay attention.", "direct"}

      # The Robot
      {"The Robot", "easy"} ->
        {"SKILL CHECK: PASSED. PROBABILITY OF SUCCESS: HIGH.", "technical"}

      {"The Robot", "medium"} ->
        {"SKILL CHECK: PARTIAL. ADDITIONAL LEARNING REQUIRED.", "technical"}

      {"The Robot", "hard"} ->
        {"SKILL CHECK: INSUFFICIENT. RECOMMEND SKILL DEVELOPMENT FIRST.", "technical"}

      # The Alchemist
      {"The Alchemist", "easy"} ->
        {"The path is clear. Begin when ready.", "mystical"}

      {"The Alchemist", "medium"} ->
        {"Some mysteries to unravel. Observe carefully.", "mystical"}

      {"The Alchemist", "hard"} ->
        {"A transformation awaits, but patience is required.", "mystical"}

      # The Survivalist
      {"The Survivalist", "easy"} ->
        {"Basic preparedness. Execute.", "pragmatic"}

      {"The Survivalist", "medium"} ->
        {"Standard difficulty. Plan accordingly.", "pragmatic"}

      {"The Survivalist", "hard"} ->
        {"High-stakes. Prepare thoroughly before attempting.", "pragmatic"}

      # The Student
      {"The Student", "easy"} ->
        {"Great learning opportunity! I'm excited for you.", "enthusiastic"}

      {"The Student", "medium"} ->
        {"This will teach you a lot. Take notes!", "enthusiastic"}

      {"The Student", "hard"} ->
        {"This is advanced, but we can research it together.", "enthusiastic"}

      # The Hobo (same message for all difficulties)
      {"The Hobo", _difficulty} ->
        {"Do you need it? Or does it need you?", "cryptic"}

      # Fallback for unknown characters or difficulties
      {_character_name, _difficulty} ->
        {"This quest will help you grow your skills and build something meaningful.", "neutral"}
    end
  end
end
