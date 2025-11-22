# Script to regenerate journal entries from conversation history
# Run with: mix run priv/repo/seeds/regenerate_journal_entries.exs

alias GreenManTavern.{Repo, Conversations, Journal, Characters}
alias GreenManTavern.Journal.EntryGenerator
import Ecto.Query

require Logger

Logger.info("Starting journal entry regeneration from conversation history...")

# Get all conversation history entries, ordered by inserted_at
conversations =
  from(c in Conversations.ConversationHistory)
  |> order_by([c], asc: c.inserted_at)
  |> Repo.all()

Logger.info("Found #{length(conversations)} conversation entries to process")

# Process each conversation
results = Enum.map(conversations, fn conversation ->
  case EntryGenerator.generate_from_conversation_struct(conversation) do
    {:ok, entry} ->
      Logger.info("✓ Generated journal entry #{entry.id} from conversation #{conversation.id} (#{conversation.message_type})")
      :ok

    {:error, changeset} ->
      Logger.warning("✗ Failed to generate from conversation #{conversation.id}: #{inspect(changeset.errors)}")
      :error

    error ->
      Logger.warning("✗ Unexpected error from conversation #{conversation.id}: #{inspect(error)}")
      :error
  end
end)

success_count = Enum.count(results, &(&1 == :ok))
Logger.info("Regeneration complete: #{success_count}/#{length(conversations)} entries created")
