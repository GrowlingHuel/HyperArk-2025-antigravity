# Quest Deduplication Migration to PgVector - Change Documentation

## Overview

This document details all changes made to migrate quest deduplication from AI-based comparison to pgvector similarity search. The migration improves reliability, speed, and cost-effectiveness by using vector embeddings instead of OpenAI chat API calls for duplicate detection.

## Summary of Changes

1. **Database Migration**: Added pgvector extension and `description_embedding` column
2. **New Module**: Created `EmbeddingGenerator` for OpenAI embeddings API
3. **Schema Update**: Added `description_embedding` field to `UserQuest` schema
4. **Deduplication Logic**: Replaced AI comparison with pgvector similarity search
5. **Merge Logic**: Updated to use SQL UPDATE with `array_append` for safe merging
6. **Quest Creation**: Added embedding generation for new quests

---

## 1. Database Migration

### File: `priv/repo/migrations/20251110002116_add_pgvector_and_quest_embeddings.exs`

**New File Created**

**Changes:**
- Enables pgvector extension: `CREATE EXTENSION IF NOT EXISTS vector`
- Adds `description_embedding` column to `user_quests` table as `vector(1536)` (OpenAI text-embedding-3-small dimensions)
- Creates two indexes:
  - `idx_user_quests_description_embedding`: Single column index for general similarity searches
  - `idx_user_quests_user_id_embedding`: Composite index for user-filtered similarity searches
- Both indexes use `ivfflat` with `vector_cosine_ops` for efficient cosine distance queries

**Migration Commands:**
```bash
mix ecto.migrate
```

**Rollback:**
```bash
mix ecto.rollback
```

---

## 2. Embedding Generator Module

### File: `lib/green_man_tavern/ai/embedding_generator.ex`

**New File Created**

**Purpose:** Generates vector embeddings for text using OpenAI's embeddings API.

**Key Functions:**
- `generate_embedding(text)`: Generates a 1536-dimensional embedding vector for the given text

**Configuration:**
- Model: `text-embedding-3-small` (cheapest option at $0.02 per 1M tokens)
- Dimensions: 1536
- API Endpoint: `https://api.openai.com/v1/embeddings`
- API Key: Reads from `OPENAI_API_KEY` environment variable or application config

**Error Handling:**
- Gracefully handles API failures, timeouts, and authentication errors
- Returns `{:ok, embedding_list}` on success or `{:error, reason}` on failure
- Logs all errors for debugging

**Example Usage:**
```elixir
case EmbeddingGenerator.generate_embedding("Build a compost bin") do
  {:ok, embedding} -> # embedding is a list of 1536 floats
  {:error, reason} -> # handle error
end
```

---

## 3. UserQuest Schema Update

### File: `lib/green_man_tavern/quests/user_quest.ex`

**Changes Made:**

1. **Added field to schema:**
```elixir
# Vector embedding for quest description (pgvector, 1536 dimensions)
# Stored as list of floats in Elixir, converted to vector type in database
field :description_embedding, :map
```

2. **Added to changeset cast list:**
```elixir
:description_embedding
```

**Note:** Ecto doesn't natively support pgvector's `vector` type, so we store it as `:map` in Elixir and handle conversion to vector type using raw SQL when inserting/updating.

---

## 4. Deduplication Module Updates

### File: `lib/green_man_tavern/quests/deduplication.ex`

**Major Changes:**

### 4.1 Added Constants and Aliases

```elixir
alias GreenManTavern.AI.{OpenAIClient, EmbeddingGenerator}

# Similarity threshold for cosine distance (0.15 = 85% similarity)
# pgvector <=> operator returns cosine distance: 0 = identical, 1 = orthogonal, 2 = opposite
@similarity_threshold 0.15
```

### 4.2 Replaced `check_for_duplicate/2` Function

**Before:** Used AI-based comparison with OpenAI chat API, comparing each existing quest individually.

**After:** 
1. Generates embedding for proposed quest description
2. Uses pgvector similarity search to find closest match in single database query
3. Falls back to AI-based comparison if embedding generation fails

**New Implementation:**
- Extracts quest description from `proposed_quest_data`
- Calls `EmbeddingGenerator.generate_embedding/1`
- If successful, calls `find_similar_quest_by_embedding/3`
- If embedding generation fails, falls back to `check_for_duplicate_ai_fallback/2` (original AI logic)

### 4.3 New Private Function: `find_similar_quest_by_embedding/3`

**Purpose:** Performs pgvector similarity search to find duplicate quests.

**Implementation:**
- Converts embedding list to PostgreSQL array format: `"[0.1,0.2,0.3,...]"`
- Executes SQL query using pgvector `<=>` operator (cosine distance)
- Filters by:
  - `user_id` (only quests for the same user)
  - `status IN ('available', 'active')` (only active quests)
  - `quest_type != 'planting_window' OR quest_type IS NULL` (exclude date-specific quests)
  - `description_embedding IS NOT NULL` (only quests with embeddings)
- Orders by distance (ascending) and limits to 1 result
- Checks if distance < `@similarity_threshold` (0.15)
- Returns `{:duplicate, quest_id}` if below threshold, `{:unique}` otherwise

**SQL Query:**
```sql
SELECT id, (description_embedding <=> $1::vector) AS distance
FROM user_quests
WHERE user_id = $2
  AND status IN ('available', 'active')
  AND (quest_type != 'planting_window' OR quest_type IS NULL)
  AND description_embedding IS NOT NULL
ORDER BY distance
LIMIT 1
```

### 4.4 New Private Function: `check_for_duplicate_ai_fallback/2`

**Purpose:** Fallback to original AI-based comparison when embedding generation fails.

**Implementation:** Contains the original AI comparison logic that was in `check_for_duplicate/2`.

### 4.5 Updated `merge_quest_perspectives/3` Function

**Before:** Used Elixir list operations:
```elixir
existing_ids ++ [character_id]
```

**After:** Uses SQL UPDATE with `array_append`:
```sql
UPDATE user_quests
SET suggested_by_character_ids = array_append(suggested_by_character_ids, $1)
WHERE id = $2
  AND NOT ($1 = ANY(suggested_by_character_ids))
RETURNING suggested_by_character_ids
```

**Benefits:**
- Prevents double-adding character_id (SQL condition ensures it's only added if not already present)
- Atomic operation (no race conditions)
- Falls back to Elixir list operations if SQL fails

**Behavior:**
- If character_id is added: Returns updated array and logs success
- If character_id already exists: No rows updated, uses existing array
- If SQL fails: Falls back to Elixir list operations

---

## 5. Quest Generator Updates

### File: `lib/green_man_tavern/quests/quest_generator.ex`

**Changes Made:**

### 5.1 Added Alias

```elixir
alias GreenManTavern.AI.EmbeddingGenerator
```

### 5.2 Updated `create_quest_from_session/4` Function

**New Logic:**
1. Extracts quest description before creating quest attributes
2. Generates embedding using `EmbeddingGenerator.generate_embedding/1`
3. If embedding generation fails, logs warning and continues without embedding (quest creation not blocked)
4. Removes embedding from attrs before initial insert (Ecto doesn't handle vector type natively)
5. After successful insert, updates quest with embedding using raw SQL

**Code Flow:**
```elixir
# Generate embedding
description_embedding = case EmbeddingGenerator.generate_embedding(quest_description) do
  {:ok, embedding} -> embedding
  {:error, reason} -> nil  # Continue without embedding
end

# Create quest without embedding
attrs_without_embedding = Map.delete(user_quest_attrs, :description_embedding)
{:ok, user_quest} = Repo.insert(...)

# Update embedding using raw SQL
if description_embedding do
  update_quest_embedding(user_quest.id, description_embedding)
end
```

### 5.3 New Private Function: `update_quest_embedding/2`

**Purpose:** Updates quest embedding using raw SQL (required because Ecto doesn't support vector type).

**Implementation:**
- Converts embedding list to PostgreSQL array format
- Executes SQL UPDATE to set `description_embedding = $1::vector`
- Logs success or failure

**SQL:**
```sql
UPDATE user_quests
SET description_embedding = $1::vector
WHERE id = $2
```

---

## Configuration Requirements

### Environment Variables

Add to your environment or `config/runtime.exs`:

```elixir
config :green_man_tavern, :openai_api_key, System.get_env("OPENAI_API_KEY")
```

Or set directly:
```bash
export OPENAI_API_KEY="sk-..."
```

### Database Setup

Ensure PostgreSQL has pgvector extension available:

```bash
# On Ubuntu/Debian
sudo apt-get install postgresql-14-pgvector  # or appropriate version

# Or compile from source
# See: https://github.com/pgvector/pgvector
```

---

## Migration Strategy

### New Quests
- **Automatic**: All new quests created via `QuestGenerator.create_quest_from_session/4` will have embeddings generated
- **On Failure**: If embedding generation fails, quest is still created (without embedding)
- **Deduplication**: Only quests with embeddings can be matched in similarity search

### Existing Quests
- **No Backfill**: Per requirements, existing quests are NOT updated with embeddings
- **Behavior**: Existing quests without embeddings won't be matched in similarity search
- **Fallback**: If no embeddings exist, system falls back to AI-based comparison

### Similarity Threshold

- **Value**: `0.15` (cosine distance)
- **Meaning**: Quests with >85% similarity will be considered duplicates
- **Adjustment**: Can be modified in `Deduplication` module `@similarity_threshold` constant

---

## Testing Considerations

### What to Test

1. **Embedding Generation**
   - Test with various description lengths
   - Test API failure scenarios
   - Verify embedding dimensions (1536)

2. **Similarity Search**
   - Test with known duplicate quests
   - Test with unique quests
   - Verify threshold behavior (0.15)

3. **Merge Logic**
   - Test SQL UPDATE with `array_append`
   - Verify character_id is not double-added
   - Test fallback behavior on SQL failure

4. **Quest Creation**
   - Verify embeddings are generated for new quests
   - Test quest creation when embedding generation fails
   - Verify embedding is stored correctly in database

### SQL Verification Queries

```sql
-- Check if pgvector extension is enabled
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Check quests with embeddings
SELECT id, title, description_embedding IS NOT NULL as has_embedding
FROM user_quests
ORDER BY inserted_at DESC
LIMIT 10;

-- Test similarity search manually
SELECT id, title, (description_embedding <=> '[0.1,0.2,...]'::vector) AS distance
FROM user_quests
WHERE description_embedding IS NOT NULL
ORDER BY distance
LIMIT 5;

-- Check merged quests
SELECT id, title, suggested_by_character_ids, 
       array_length(suggested_by_character_ids, 1) as suggester_count
FROM user_quests 
WHERE array_length(suggested_by_character_ids, 1) > 1;
```

---

## Performance Considerations

### Benefits
- **Faster**: Single database query vs. multiple AI API calls
- **Cheaper**: Embeddings cost $0.02 per 1M tokens vs. chat API costs
- **More Reliable**: No dependency on OpenAI chat API availability for deduplication

### Indexes
- Two indexes created for optimal query performance:
  - Single column index for general searches
  - Composite index for user-filtered searches

### Embedding Storage
- Each embedding: 1536 floats × 4 bytes = ~6KB
- Minimal storage overhead for improved deduplication

---

## Rollback Plan

If issues arise, the system includes fallback mechanisms:

1. **Embedding Generation Failure**: Falls back to AI-based comparison
2. **SQL Merge Failure**: Falls back to Elixir list operations
3. **Database Migration**: Can be rolled back using `mix ecto.rollback`

### Complete Rollback

1. Rollback migration: `mix ecto.rollback`
2. Remove embedding generation from `QuestGenerator`
3. Revert `Deduplication.check_for_duplicate/2` to original AI-only logic
4. Revert `merge_quest_perspectives/3` to Elixir list operations

---

## Files Modified Summary

1. ✅ `priv/repo/migrations/20251110002116_add_pgvector_and_quest_embeddings.exs` (NEW)
2. ✅ `lib/green_man_tavern/ai/embedding_generator.ex` (NEW)
3. ✅ `lib/green_man_tavern/quests/user_quest.ex` (MODIFIED)
4. ✅ `lib/green_man_tavern/quests/deduplication.ex` (MODIFIED)
5. ✅ `lib/green_man_tavern/quests/quest_generator.ex` (MODIFIED)

---

## Next Steps

1. **Run Migration**: `mix ecto.migrate`
2. **Set API Key**: Ensure `OPENAI_API_KEY` environment variable is set
3. **Test**: Create a new quest and verify embedding is generated
4. **Monitor**: Check logs for embedding generation and similarity search behavior
5. **Adjust Threshold**: If needed, adjust `@similarity_threshold` based on real-world results

---

## Notes

- **No Backfill**: Existing quests are intentionally not updated with embeddings (per requirements)
- **Graceful Degradation**: System continues to work even if embedding generation fails
- **Cost**: Embeddings are very cheap ($0.02 per 1M tokens), much cheaper than chat API
- **Compatibility**: All function signatures remain the same, no breaking changes to external APIs

---

**Documentation Generated:** 2025-11-10
**Migration Version:** 20251110002116







