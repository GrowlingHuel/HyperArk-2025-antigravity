# Test script for session-to-quest flow
# Run this in IEx: `iex -S mix`
# Then: `Code.eval_file("test_session_flow.exs")`

alias GreenManTavern.{Repo, Accounts, Characters, Conversations, Quests, Journal, Sessions}
alias GreenManTavern.AI.SessionProcessor
alias GreenManTavern.Quests.QuestGenerator
import Ecto.Query

# ============================================
# STEP 1: IDENTIFY TEST USER
# ============================================
IO.puts("\n=== STEP 1: IDENTIFYING TEST USER ===\n")

# Get first user or create test user
test_user = case Repo.one(from u in Accounts.User, limit: 1) do
  nil ->
    IO.puts("No users found. Creating test user...")
    {:ok, user} = Accounts.register_user(%{
      email: "test@example.com",
      password: "testpassword123"
    })
    user
  user ->
    IO.puts("Using existing user: #{user.email} (ID: #{user.id})")
    user
end

test_user_id = test_user.id
IO.puts("Test User ID: #{test_user_id}\n")

# ============================================
# STEP 2: PRE-TEST STATE
# ============================================
IO.puts("=== STEP 2: PRE-TEST STATE ===\n")

# Count conversation_history records
conv_count_before = Repo.aggregate(
  from(ch in Conversations.ConversationHistory, where: ch.user_id == ^test_user_id),
  :count
)

# Count user_quests
quest_count_before = Repo.aggregate(
  from(uq in Quests.UserQuest, where: uq.user_id == ^test_user_id),
  :count
)

# Count journal_entries
journal_count_before = Repo.aggregate(
  from(je in Journal.Entry, where: je.user_id == ^test_user_id),
  :count
)

IO.puts("Pre-test counts:")
IO.puts("  conversation_history: #{conv_count_before}")
IO.puts("  user_quests: #{quest_count_before}")
IO.puts("  journal_entries: #{journal_count_before}\n")

# ============================================
# STEP 3: GET CHARACTER
# ============================================
IO.puts("=== STEP 3: GETTING CHARACTER ===\n")

grandmother = Characters.get_character_by_name("The Grandmother")
if grandmother do
  IO.puts("Found character: #{grandmother.name} (ID: #{grandmother.id})\n")
else
  IO.puts("ERROR: The Grandmother character not found!")
  System.halt(1)
end

# ============================================
# STEP 4: SIMULATE CONVERSATION
# ============================================
IO.puts("=== STEP 4: SIMULATING CONVERSATION ===\n")

# Generate session ID
session_id = Sessions.generate_session_id()
IO.puts("Generated session_id: #{session_id}\n")

# Simulate conversation messages
messages = [
  {"user", "I'm thinking about starting composting in my backyard. I have about 50 square feet of space."},
  {"character", "That's wonderful! A 50 square foot space is perfect for a compost pile. Let's start with the basics."},
  {"user", "What size bin should I get? I'm in a temperate climate zone."},
  {"character", "For your space, I'd recommend a 3x3x3 foot bin. In a temperate climate, you'll want good drainage."},
  {"user", "Where should I place it? I have partial shade and full sun options."},
  {"character", "Partial shade is ideal - it keeps the pile from drying out too quickly while still allowing decomposition."},
  {"user", "How do I know when it's ready? What should I look for?"},
  {"character", "You'll know it's ready when it's dark, crumbly, and smells like earth. Usually takes 3-6 months."}
]

IO.puts("Creating #{length(messages)} conversation messages...")

Enum.each(messages, fn {message_type, content} ->
  case Conversations.create_conversation_entry(%{
    user_id: test_user_id,
    character_id: grandmother.id,
    message_type: message_type,
    message_content: content,
    session_id: session_id
  }) do
    {:ok, conv} ->
      IO.puts("  ✅ Created #{message_type} message (ID: #{conv.id})")
    {:error, changeset} ->
      IO.puts("  ❌ Failed to create #{message_type} message: #{inspect(changeset.errors)}")
  end
end)

IO.puts("\n✅ Conversation simulation complete\n")

# ============================================
# STEP 5: VERIFY SESSION MESSAGES
# ============================================
IO.puts("=== STEP 5: VERIFYING SESSION MESSAGES ===\n")

session_messages = Sessions.get_session_messages(session_id)
IO.puts("Messages in session: #{length(session_messages)}")
IO.puts("All messages have session_id: #{Enum.all?(session_messages, &(&1.session_id == session_id))}\n")

# ============================================
# STEP 6: PROCESS SESSION
# ============================================
IO.puts("=== STEP 6: PROCESSING SESSION ===\n")
IO.puts("Calling SessionProcessor.process_session/1...\n")

case SessionProcessor.process_session(session_id) do
  {:ok, %{journal_summary: journal_summary, quest_data: quest_data}} ->
    IO.puts("✅ Session processing successful!")
    IO.puts("\nJournal Summary:")
    IO.puts("  #{journal_summary}")

    if quest_data do
      IO.puts("\nQuest Data:")
      IO.puts("  Title: #{quest_data.title}")
      IO.puts("  Objective: #{quest_data.objective}")
      IO.puts("  Required Skills: #{inspect(quest_data.required_skills)}")
      IO.puts("  XP Rewards: #{inspect(quest_data.xp_rewards)}")
    else
      IO.puts("\nNo quest generated (score below threshold)")
    end

    # Store session summary
    if journal_summary do
      messages = Sessions.get_session_messages(session_id)
      if messages != [] do
        first_message = List.first(messages)
        case Conversations.update_conversation_entry(first_message, test_user_id, %{
          session_summary: journal_summary
        }) do
          {:ok, _updated} ->
            IO.puts("\n✅ Stored session summary in conversation_history")
          {:error, changeset} ->
            IO.puts("\n❌ Failed to store session summary: #{inspect(changeset.errors)}")
        end
      end
    end

    # Create journal entry
    if journal_summary do
      metadata = Sessions.get_session_metadata(session_id)
      if metadata do
        max_day = Journal.get_max_day_number(test_user_id)
        day_number = max_day + 1
        entry_date = Journal.format_entry_date(day_number)

        case Journal.create_entry(%{
          user_id: test_user_id,
          entry_date: entry_date,
          day_number: day_number,
          title: "Conversation Summary",
          body: journal_summary,
          source_type: "character_conversation",
          source_id: metadata.character_id
        }) do
          {:ok, entry} ->
            IO.puts("✅ Created journal entry (ID: #{entry.id})")
          {:error, changeset} ->
            IO.puts("❌ Failed to create journal entry: #{inspect(changeset.errors)}")
        end
      end
    end

    # Create quest
    if quest_data do
      metadata = Sessions.get_session_metadata(session_id)
      if metadata && metadata.character_id do
        case QuestGenerator.create_quest_from_session(
          test_user_id,
          quest_data,
          metadata.character_id,
          session_id
        ) do
          {:ok, user_quest} ->
            IO.puts("✅ Created quest (ID: #{user_quest.id})")
          {:error, reason} ->
            IO.puts("❌ Failed to create quest: #{inspect(reason)}")
        end
      end
    end

  {:error, reason} ->
    IO.puts("❌ Session processing failed: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 60) <> "\n")

# ============================================
# STEP 7: POST-TEST VERIFICATION
# ============================================
IO.puts("=== STEP 7: POST-TEST VERIFICATION ===\n")

# Count conversation_history records
conv_count_after = Repo.aggregate(
  from(ch in Conversations.ConversationHistory, where: ch.user_id == ^test_user_id),
  :count
)

# Count user_quests
quest_count_after = Repo.aggregate(
  from(uq in Quests.UserQuest, where: uq.user_id == ^test_user_id),
  :count
)

# Count journal_entries
journal_count_after = Repo.aggregate(
  from(je in Journal.Entry, where: je.user_id == ^test_user_id),
  :count
)

IO.puts("Post-test counts:")
IO.puts("  conversation_history: #{conv_count_after} (+#{conv_count_after - conv_count_before})")
IO.puts("  user_quests: #{quest_count_after} (+#{quest_count_after - quest_count_before})")
IO.puts("  journal_entries: #{journal_count_after} (+#{journal_count_after - journal_count_before})\n")

# Check for session summary
session_summary_check = Repo.one(
  from(ch in Conversations.ConversationHistory,
    where: ch.user_id == ^test_user_id and not is_nil(ch.session_summary),
    order_by: [desc: ch.inserted_at],
    limit: 1,
    select: ch.session_summary
  )
)

if session_summary_check do
  IO.puts("✅ Session summary found:")
  IO.puts("  #{String.slice(session_summary_check, 0, 200)}...\n")
else
  IO.puts("❌ NO SESSION SUMMARY FOUND - THIS IS THE PROBLEM!\n")
end

# Check for quest
latest_quest = Repo.one(
  from(uq in Quests.UserQuest,
    where: uq.user_id == ^test_user_id,
    order_by: [desc: uq.inserted_at],
    limit: 1,
    preload: [:quest]
  )
)

if latest_quest do
  IO.puts("✅ Latest quest:")
  IO.puts("  Title: #{latest_quest.quest.title}")
  IO.puts("  Status: #{latest_quest.status}")
  IO.puts("  Required Skills: #{inspect(latest_quest.required_skills)}")
  IO.puts("  Calculated Difficulty: #{latest_quest.calculated_difficulty}\n")
else
  IO.puts("❌ No quest found\n")
end

IO.puts("=== TEST COMPLETE ===")
IO.puts("\nRun these SQL queries for detailed verification:\n")

IO.puts("""
-- Check messages with session_id
SELECT id, session_id, message_type, LEFT(message_content, 50) as content_preview
FROM conversation_history
WHERE user_id = #{test_user_id}
ORDER BY inserted_at DESC
LIMIT 10;

-- Check for session summary
SELECT id, session_id, session_summary, inserted_at
FROM conversation_history
WHERE user_id = #{test_user_id}
AND session_summary IS NOT NULL
ORDER BY inserted_at DESC
LIMIT 5;

-- Check generated quest
SELECT id, title, status, required_skills, calculated_difficulty,
       generated_by_character_id, conversation_context
FROM user_quests
WHERE user_id = #{test_user_id}
ORDER BY inserted_at DESC
LIMIT 3;

-- Check journal entries
SELECT id, title, LEFT(body, 100) as body_preview, inserted_at
FROM journal_entries
WHERE user_id = #{test_user_id}
ORDER BY inserted_at DESC
LIMIT 5;
""")

IO.puts("\nSession ID for this test: #{session_id}")
