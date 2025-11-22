-- Verification Queries for Session-to-Quest Flow Test
-- Replace [TEST_USER_ID] with your actual test user ID
-- Replace [SESSION_ID] with the session_id from the test

-- ============================================
-- 1. Check that messages have session_id
-- ============================================
SELECT 
    id, 
    session_id, 
    message_type, 
    LEFT(message_content, 50) as content_preview,
    inserted_at
FROM conversation_history 
WHERE user_id = [TEST_USER_ID]
ORDER BY inserted_at DESC 
LIMIT 10;

-- ============================================
-- 2. Check for session summary (KEY VERIFICATION)
-- ============================================
SELECT 
    id, 
    session_id, 
    session_summary, 
    inserted_at
FROM conversation_history 
WHERE user_id = [TEST_USER_ID] 
AND session_summary IS NOT NULL
ORDER BY inserted_at DESC 
LIMIT 5;

-- ============================================
-- 3. Check all messages in a specific session
-- ============================================
SELECT 
    id,
    session_id,
    message_type,
    message_content,
    inserted_at
FROM conversation_history
WHERE session_id = '[SESSION_ID]'
ORDER BY inserted_at ASC;

-- ============================================
-- 4. Check generated quest
-- ============================================
SELECT 
    uq.id,
    q.title,
    uq.status,
    uq.required_skills,
    uq.calculated_difficulty,
    uq.generated_by_character_id,
    uq.conversation_context,
    uq.inserted_at
FROM user_quests uq
JOIN quests q ON uq.quest_id = q.id
WHERE uq.user_id = [TEST_USER_ID]
ORDER BY uq.inserted_at DESC 
LIMIT 3;

-- ============================================
-- 5. Check journal entries
-- ============================================
SELECT 
    id,
    user_id,
    title,
    LEFT(body, 200) as body_preview,
    source_type,
    source_id,
    inserted_at
FROM journal_entries 
WHERE user_id = [TEST_USER_ID]
ORDER BY inserted_at DESC 
LIMIT 5;

-- ============================================
-- 6. Check if journal_entry_id link exists
-- ============================================
SELECT 
    ch.id,
    ch.session_id,
    ch.session_summary IS NOT NULL as has_summary,
    ch.journal_entry_id,
    je.title as journal_title,
    LEFT(je.body, 100) as journal_content_preview
FROM conversation_history ch
LEFT JOIN journal_entries je ON ch.journal_entry_id = je.id
WHERE ch.user_id = [TEST_USER_ID]
AND ch.session_summary IS NOT NULL
ORDER BY ch.inserted_at DESC
LIMIT 3;

-- ============================================
-- 7. Session metadata check
-- ============================================
-- This query shows all messages in a session with their order
SELECT 
    ch.id,
    ch.session_id,
    ch.message_type,
    LEFT(ch.message_content, 80) as content,
    ch.inserted_at,
    ch.session_summary IS NOT NULL as has_summary
FROM conversation_history ch
WHERE ch.session_id = '[SESSION_ID]'
ORDER BY ch.inserted_at ASC;

-- ============================================
-- 8. Count messages per session
-- ============================================
SELECT 
    session_id,
    COUNT(*) as message_count,
    COUNT(CASE WHEN message_type = 'user' THEN 1 END) as user_messages,
    COUNT(CASE WHEN message_type = 'character' THEN 1 END) as character_messages,
    MIN(inserted_at) as session_start,
    MAX(inserted_at) as session_end
FROM conversation_history
WHERE user_id = [TEST_USER_ID]
AND session_id IS NOT NULL
GROUP BY session_id
ORDER BY session_start DESC
LIMIT 5;

