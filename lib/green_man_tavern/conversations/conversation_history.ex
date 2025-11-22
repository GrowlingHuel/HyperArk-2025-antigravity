defmodule GreenManTavern.Conversations.ConversationHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_history" do
    field :message_type, :string
    field :message_content, :string
    field :extracted_projects, {:array, :string}
    field :session_id, Ecto.UUID
    field :session_summary, :string
    field :extracted_facts, :map, default: %{}

    timestamps(type: :naive_datetime)

    belongs_to :user, GreenManTavern.Accounts.User
    belongs_to :character, GreenManTavern.Characters.Character
    belongs_to :journal_entry, GreenManTavern.Journal.Entry
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [
      :user_id,
      :character_id,
      :message_type,
      :message_content,
      :extracted_projects,
      :session_id,
      :session_summary,
      :extracted_facts,
      :journal_entry_id
    ])
    |> validate_required([:user_id, :character_id, :message_type, :message_content])
    |> validate_inclusion(:message_type, ["user", "character"])
    |> foreign_key_constraint(:journal_entry_id)
    # Note: Database uses :text type (unlimited length), so no length validation needed
    # Note: HTML escaping is handled at display time by HEEx templates for security
    # This ensures raw content is stored, and proper escaping happens in the view layer
  end
end
