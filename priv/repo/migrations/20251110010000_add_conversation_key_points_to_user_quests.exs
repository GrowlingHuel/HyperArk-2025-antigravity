defmodule GreenManTavern.Repo.Migrations.AddConversationKeyPointsToUserQuests do
  use Ecto.Migration

  def change do
    alter table(:user_quests) do
      add :conversation_key_points, :map, default: fragment("'[]'::jsonb")
    end
  end
end
