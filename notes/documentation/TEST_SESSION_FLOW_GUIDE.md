# Session-to-Quest Flow Testing Guide

This guide will help you test the complete conversation-to-quest system flow.

## Prerequisites

1. Phoenix server must be running: `iex -S mix phx.server`
2. Database must be accessible
3. OpenRouter API key must be configured (for SessionProcessor)

## Quick Test (Automated Script)

### Option 1: Run the Test Script in IEx

1. Start IEx console:
   ```bash
   iex -S mix
   ```

2. Load and run the test script:
   ```elixir
   Code.eval_file("test_session_flow.exs")
   ```

3. The script will:
   - Identify or create a test user
   - Show pre-test state
   - Simulate a conversation with The Grandmother
   - Process the session
   - Show post-test verification

### Option 2: Manual Browser Test

1. **Start Phoenix server:**
   ```bash
   iex -S mix phx.server
   ```

2. **Log in as a test user** (or create one)

3. **Note the pre-test state:**
   - Run these queries in psql or IEx:
   ```elixir
   alias GreenManTavern.{Repo, Accounts, Conversations, Quests, Journal}
   import Ecto.Query
   
   user_id = 1  # Replace with your test user ID
   
   # Count conversation_history
   conv_count = Repo.aggregate(
     from(ch in Conversations.ConversationHistory, where: ch.user_id == ^user_id),
     :count
   )
   
   # Count user_quests
   quest_count = Repo.aggregate(
     from(uq in Quests.UserQuest, where: uq.user_id == ^user_id),
     :count
   )
   
   # Count journal_entries
   journal_count = Repo.aggregate(
     from(je in Journal.Entry, where: je.user_id == ^user_id),
     :count
   )
   
   IO.puts("Pre-test: conv=#{conv_count}, quests=#{quest_count}, journal=#{journal_count}")
   ```

4. **Have a conversation:**
   - Navigate to The Grandmother character page
   - Send these messages (at least 4 questions):
     - "I'm thinking about starting composting in my backyard. I have about 50 square feet of space."
     - "What size bin should I get? I'm in a temperate climate zone."
     - "Where should I place it? I have partial shade and full sun options."
     - "How do I know when it's ready? What should I look for?"
   - Include specific details (space size, climate, etc.)

5. **Navigate away** from the character page (back to Tavern or another character)

6. **Wait 5-10 seconds** for async processing

7. **Check logs** for:
   - `[DualPanel] Processing session end for session_id: ...`
   - `[SessionProcessor] ...`
   - `[DualPanel] ✅ Stored session summary in conversation_history`
   - `[DualPanel] ✅ Created quest from session`
   - Any errors

## Verification Queries

Run these queries in psql or IEx to verify the results:

### 1. Check Messages Have Session ID

```sql
SELECT id, session_id, message_type, LEFT(message_content, 50) as content_preview
FROM conversation_history 
WHERE user_id = [TEST_USER_ID]
ORDER BY inserted_at DESC 
LIMIT 10;
```

**Expected:** All messages from the conversation should have the same `session_id` (UUID format)

### 2. Check Session Summary (CRITICAL)

```sql
SELECT id, session_id, session_summary, inserted_at
FROM conversation_history 
WHERE user_id = [TEST_USER_ID] 
AND session_summary IS NOT NULL
ORDER BY inserted_at DESC 
LIMIT 5;
```

**Expected:** 
- At least one row with `session_summary` populated
- The summary should be 2-3 sentences about THE ENTIRE SESSION
- Example: "User discussed composting with The Grandmother, asked about bin size and placement, received advice on location and timing..."

**If NULL:** This is the main problem - session processing didn't complete or failed

### 3. Check Generated Quest

```sql
SELECT 
    uq.id,
    q.title,
    uq.status,
    uq.required_skills,
    uq.calculated_difficulty,
    uq.generated_by_character_id,
    uq.conversation_context
FROM user_quests uq
JOIN quests q ON uq.quest_id = q.id
WHERE uq.user_id = [TEST_USER_ID]
ORDER BY uq.inserted_at DESC 
LIMIT 3;
```

**Expected:**
- If quest_score ≥ 8: A quest should be created
- `required_skills` should be a JSONB map (e.g., `{"composting": 3}`)
- `calculated_difficulty` should be 1-10
- `generated_by_character_id` should match The Grandmother's ID

### 4. Check Journal Entries

```sql
SELECT id, title, LEFT(body, 200) as body_preview, inserted_at
FROM journal_entries 
WHERE user_id = [TEST_USER_ID]
ORDER BY inserted_at DESC 
LIMIT 5;
```

**Expected:**
- A new journal entry with title "Conversation Summary"
- Body should match the `session_summary` from conversation_history

### 5. Check Journal Entry Link

```sql
SELECT 
    ch.id,
    ch.session_id,
    ch.session_summary IS NOT NULL as has_summary,
    ch.journal_entry_id,
    je.title as journal_title
FROM conversation_history ch
LEFT JOIN journal_entries je ON ch.journal_entry_id = je.id
WHERE ch.user_id = [TEST_USER_ID]
AND ch.session_summary IS NOT NULL
ORDER BY ch.inserted_at DESC
LIMIT 3;
```

**Expected:**
- `journal_entry_id` should link to the journal entry created
- Note: This link may not be set yet if the code doesn't update it

## IEx Verification Commands

You can also verify in IEx:

```elixir
alias GreenManTavern.{Repo, Sessions, Conversations, Quests, Journal}
import Ecto.Query

user_id = 1  # Your test user ID
session_id = "your-session-id-here"  # From logs or database

# Get session messages
messages = Sessions.get_session_messages(session_id)
IO.puts("Messages in session: #{length(messages)}")

# Get session metadata
metadata = Sessions.get_session_metadata(session_id)
IO.inspect(metadata)

# Check for session summary
summary_record = Repo.one(
  from(ch in Conversations.ConversationHistory,
    where: ch.session_id == ^session_id and not is_nil(ch.session_summary),
    limit: 1
  )
)
IO.inspect(summary_record)

# Check for quest
latest_quest = Repo.one(
  from(uq in Quests.UserQuest,
    where: uq.user_id == ^user_id,
    order_by: [desc: uq.inserted_at],
    limit: 1,
    preload: [:quest]
  )
)
IO.inspect(latest_quest)
```

## Expected Test Report Format

### 1. Pre-test State
- conversation_history count before: X
- user_quests count before: X
- journal_entries count before: X

### 2. Test Execution
- Conversation had: [describe briefly]
- Number of messages in session: X
- Session ID generated: [UUID]
- Navigation away triggered: YES/NO

### 3. Log Analysis
- Session processing triggered: YES/NO
- Errors in logs: [paste any errors]
- Quest generation logged: YES/NO

### 4. Database Verification
- All messages have same session_id: YES/NO
- session_summary populated: YES/NO
  - If YES, show the summary text
  - If NO, **THIS IS THE PROBLEM**
- Quest created: YES/NO
  - If YES, show: title, required_skills, calculated_difficulty
- Journal entry created: YES/NO
- journal_entry_id link exists: YES/NO

### 5. Critical Issue - Journal Summary
- Is session_summary a summary of THE ENTIRE SESSION or just individual messages?
- **Expected:** "User discussed composting with Grandmother, asked about bin size and placement, received advice on X, Y, Z"
- **Not expected:** Individual message summaries

### 6. Issues Found
- List any problems discovered
- If session_summary is NULL or wrong, this is priority #1

## Common Issues and Solutions

### Issue: session_summary is NULL

**Possible causes:**
1. `terminate/2` callback not being called
2. Session processing failing silently
3. API call to SessionProcessor failing
4. `store_session_summary/3` failing

**Debug steps:**
1. Check logs for `[DualPanel] Processing session end for session_id: ...`
2. Check logs for `[SessionProcessor]` messages
3. Check logs for errors in `process_session_end/2`
4. Manually call `SessionProcessor.process_session(session_id)` in IEx

### Issue: Quest not created

**Possible causes:**
1. Quest score < 8
2. `quest_data` is nil
3. QuestGenerator failing

**Debug steps:**
1. Check logs for quest score
2. Check if `quest_data` is returned from SessionProcessor
3. Check QuestGenerator logs

### Issue: Messages don't have session_id

**Possible causes:**
1. `session_id` not being assigned in mount
2. `session_id` not being passed to `create_conversation_entry`

**Debug steps:**
1. Check that `socket.assigns[:session_id]` exists
2. Check that `session_id` is passed in both user and character message creation

## Next Steps After Testing

1. If session_summary is NULL:
   - Check `terminate/2` is being called
   - Check SessionProcessor is working
   - Check API key is configured

2. If quest not created:
   - Check quest score in logs
   - Verify conversation has enough detail/questions

3. If everything works:
   - Test with different characters
   - Test with different conversation topics
   - Test edge cases (very short conversations, etc.)

