PART 5: TESTING STRATEGY
Test Scenario 1: Complete Session Flow
Setup:

Log in as test user
Open chat with The Grandmother
Have conversation about composting (4+ questions, specific details)

Expected Results:

Session ID generated and stored in assigns
All messages saved with same session_id
When navigating away, terminate callback triggers
Session processing completes (check logs)
Journal summary appears in conversation_history.session_summary
Journal entry created in journal_entries table
Quest generated (check user_quests for new "available" quest)
Quest has required_skills populated
Quest has calculated_difficulty populated

Verify in Database:
sql-- Check session messages
SELECT session_id, message_content FROM conversation_history 
WHERE user_id = [test_user_id] 
ORDER BY inserted_at DESC LIMIT 10;

-- Check session summary
SELECT session_summary FROM conversation_history 
WHERE session_id = '[session_id]' AND session_summary IS NOT NULL;

-- Check generated quest
SELECT title, status, required_skills, calculated_difficulty 
FROM user_quests 
WHERE user_id = [test_user_id] 
ORDER BY inserted_at DESC LIMIT 1;

-- Check journal entry
SELECT * FROM journal_entries 
WHERE user_id = [test_user_id] 
ORDER BY inserted_at DESC LIMIT 1;

Test Scenario 2: Skill Progression & Difficulty Recalculation
Setup:

User has quest marked as "Hard" with required_skills: {"planting": 7, "composting": 5}
User's current skills: planting (beginner/3), composting (novice/1)
Complete a different planting quest

Expected Results:

XP awarded to planting domain
Planting skill levels up (beginner → intermediate)
All quests recalculate difficulty
Original "Hard" quest becomes "Medium" (planting gap closed)
Quest Log reorders automatically

Verify in Database:
sql-- Check skill before
SELECT domain, level, experience_points FROM user_skills 
WHERE user_id = [test_user_id] AND domain = 'planting';

-- Complete quest
-- (trigger ProgressionHandler.complete_quest)

-- Check skill after
SELECT domain, level, experience_points FROM user_skills 
WHERE user_id = [test_user_id] AND domain = 'planting';

-- Check quest difficulty updated
SELECT title, calculated_difficulty FROM user_quests 
WHERE user_id = [test_user_id] AND id = [quest_id];

Test Scenario 3: Character-Specific Quest Generation
Setup:

Have conversation with The Farmer (direct, action-oriented)
Have conversation with The Grandmother (gentle, patient)
Both about similar topics

Expected Results:

Farmer generates quest with direct language
Grandmother generates quest with nurturing language
Both quests stored with correct generated_by_character_id
Quest presentation uses character-specific voice

Verify:

Check quest titles match character personality
Check quest introduction text matches character voice
Check generated_by_character_id is correct


Test Scenario 4: Low-Score Conversation (No Quest)
Setup:

Have brief conversation (1-2 questions)
Ask only theoretical questions
Show no commitment signals

Expected Results:

Session processes normally
Journal summary generated
Quest score < 8
NO quest generated
User sees journal entry but no new quest

Verify:

Session summary exists
No new user_quests record
Logs show "quest score: [X], below threshold"


Test Scenario 5: Quest Log Display
Setup:

User has 3 quests:

Quest A: Easy (all skills ready)
Quest B: Medium (1/2 skills ready)
Quest C: Hard (0/3 skills ready)



Expected Results:

Quest Log shows all 3 quests
Sorted: Easy → Medium → Hard
Each shows:

Star rating (⭐ to ⭐⭐⭐⭐⭐)
Readiness ratio ("2/2 skills ready", "1/2 skills ready", etc.)


When expanded:

Skills broken down with progress framing
"You're Ready For:" section shows ready skills
"You'll Learn:" section shows challenging skills with level gaps



Verify:

Visual inspection of Quest Log
Correct sorting
Correct difficulty display
Progress framing shows correctly
