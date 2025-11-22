# Script for populating knowledge_terms table with pre-fetched Wikipedia summaries
# Run with: mix run priv/repo/seeds/knowledge_terms.exs

alias GreenManTavern.{Repo, Knowledge}
alias GreenManTavern.Knowledge.TermLookup

require Logger

Logger.info("Starting knowledge term seeding...")

case Knowledge.seed_terms() do
  {:ok, count} ->
    Logger.info("✓ Successfully seeded #{count} knowledge terms!")
  error ->
    Logger.error("✗ Seeding failed: #{inspect(error)}")
    System.halt(1)
end
