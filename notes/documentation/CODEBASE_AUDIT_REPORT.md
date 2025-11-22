# GREEN MAN TAVERN CODEBASE AUDIT REPORT

**Date:** November 7, 2025  
**Analysis Type:** Comprehensive Codebase Audit (No Code Changes)

---

## EXECUTIVE SUMMARY

- **Phoenix version:** ~1.8.1
- **Elixir version:** ~1.15
- **Database:** PostgreSQL (version not specified in code)
- **API Integration:** 
  - **Primary:** OpenRouter (OpenAI GPT-4o-mini) - ACTIVE
  - **Secondary:** Anthropic Claude (ClaudeClient exists but not actively used in DualPanelLive)
- **Chat System Status:** **WORKING** - Uses OpenRouter/OpenAI via `OpenAIClient` module
- **MindsDB Status:** **DISABLED** - Config exists but no active integration found

---

## DATABASE FINDINGS

### Existing Tables (from migrations)

1. `users`
2. `characters`
3. `user_characters`
4. `systems`
5. `user_systems`
6. `connections`
7. `user_connections`
8. `quests`
9. `user_quests`
10. `achievements`
11. `user_achievements`
12. `user_projects`
13. `conversation_history`
14. `documents`
15. `document_chunks`
16. `projects`
17. `diagrams`
18. `composite_systems`
19. `journal_entries`
20. `knowledge_terms`
21. `plant_families`
22. `cities`
23. `city_frost_dates`
24. `plants`
25. `user_plants`
26. `koppen_zones`
27. `companion_relationships`

### users table

**Fields present:**
- `id` (primary key)
- `email` (string, unique, required)
- `hashed_password` (string, required)
- `confirmed_at` (naive_datetime, nullable)
- `profile_data` (map/jsonb, default: %{})
- `xp` (integer, default: 0)
- `level` (integer, default: 1)
- `primary_character_id` (integer, nullable, FK to characters)
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**NEW FIELDS NEEDED:**
- ❌ `current_season` (not present)
- ❌ `days_into_growing_season` (not present)
- ❌ `active_projects_state` (not present - though `profile_data` map could store this)
- ✅ `profile_data` EXISTS - Currently stores facts in `profile_data["facts"]` array

**CURRENT USAGE:**
- `profile_data` is actively used to store extracted facts in format:
  ```json
  {
    "facts": [
      {
        "type": "location",
        "key": "city",
        "value": "Launceston",
        "confidence": 0.95,
        "source": "character_name",
        "learned_at": "ISO8601 timestamp",
        "context": "optional"
      }
    ]
  }
  ```

### characters table

**Fields present:**
- `id` (primary key)
- `name` (string, unique, required)
- `archetype` (string, required)
- `description` (text, nullable)
- `focus_area` (string, nullable)
- `personality_traits` (jsonb array, default: [])
- `icon_name` (string, nullable)
- `color_scheme` (string, nullable)
- `trust_requirement` (string, default: "none")
- `mindsdb_agent_name` (string, nullable) ⚠️ **LEGACY - NOT USED**
- `system_prompt` (text, nullable) ✅ **EXISTS** (added via migration 20251030120000)
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**FIELDS TO KEEP:**
- ✅ `name`, `archetype`, `description`, `focus_area` - Core character data
- ✅ `personality_traits` - JSONB array, actively used
- ✅ `system_prompt` - **EXISTS** and actively used by `CharacterContext.build_system_prompt/1`
- ✅ `trust_requirement` - Used for trust level calculations
- ✅ `icon_name`, `color_scheme` - UI display

**NEW FIELDS NEEDED:**
- ❌ `knowledge_domains` (not present - could be JSONB array)
- ❌ `response_style` (not present - currently hardcoded in `CharacterContext`)
- ❌ `greeting_templates` (not present)

**FIELDS TO REMOVE:**
- ⚠️ `mindsdb_agent_name` - **LEGACY FIELD** - Still in schema and seed data, but:
  - No active MindsDB integration found
  - Only referenced in backup/disabled files
  - **SAFE TO REMOVE** after confirming no production data depends on it

### user_characters table

**Fields present:**
- `id` (primary key)
- `user_id` (FK to users, required)
- `character_id` (FK to characters, required)
- `trust_level` (integer, default: 0)
- `first_interaction_at` (utc_datetime_usec, nullable)
- `last_interaction_at` (utc_datetime_usec, nullable)
- `interaction_count` (integer, default: 0)
- `is_trusted` (boolean, default: false)
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**NEW FIELDS NEEDED:**
- ❌ `communication_style_notes` (not present)
- ❌ `successful_strategies` (not present - could be JSONB array)

**CURRENT USAGE:**
- Trust system is **ACTIVE** - `update_trust_level/4` function exists in DualPanelLive
- Trust levels increment based on interactions
- `is_trusted` boolean calculated from `trust_level` vs `character.trust_requirement`

### conversation_history table

**Fields present:**
- `id` (primary key)
- `user_id` (FK to users, required)
- `character_id` (FK to characters, required)
- `message_type` (string, required) - "user" or "character"
- `message_content` (text, required)
- `extracted_projects` (jsonb array, default: [])
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**NEW FIELDS NEEDED:**
- ❌ `session_id` (not present) - **CRITICAL FOR SESSION-END EXTRACTION**
- ❌ `session_summary` (not present) - **CRITICAL FOR SESSION-END EXTRACTION**
- ❌ `extracted_facts` (not present) - Currently facts extracted per-message, not per-session

**CURRENT USAGE:**
- Messages stored individually (user + character responses)
- No session grouping mechanism
- Facts extracted **per message** via `FactExtractor.extract_facts/2`
- No session-end extraction or summarization

### user_projects table

**Fields present:**
- `id` (primary key)
- `user_id` (FK to users, required)
- `project_type` (string, required)
- `status` (string, required) - "desire", "planning", "in_progress", "completed", "abandoned"
- `mentioned_at` (naive_datetime, required)
- `confidence_score` (float, required)
- `related_systems` (map/jsonb, default: %{})
- `notes` (text, nullable)
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**Status:** Appears complete for current needs.

### user_systems table

**Fields present:**
- `id` (primary key)
- `user_id` (FK to users, required)
- `system_id` (FK to systems, required)
- `status` (string, default: "planned")
- `position_x` (integer, nullable)
- `position_y` (integer, nullable)
- `custom_notes` (text, nullable)
- `location_notes` (text, nullable)
- `implemented_at` (naive_datetime, nullable)
- `inserted_at` (naive_datetime)
- `updated_at` (naive_datetime)

**Status:** Appears complete for current needs.

---

## MODULE FINDINGS

### API Integration

**Current API client:** `lib/green_man_tavern/ai/openai_client.ex`

- **Calls:** OpenRouter API (https://openrouter.ai/api/v1/chat/completions)
- **Model:** `openai/gpt-4o-mini`
- **Module name:** `GreenManTavern.AI.OpenAIClient`
- **Key functions:**
  - `chat/3` - Main chat function (message, system_prompt, context)
  - Uses `Req` library for HTTP requests (not httpoison)
  - 30-second timeout
  - Error handling for common status codes (401, 402, 429, 500, 503)

**Secondary API client:** `lib/green_man_tavern/ai/claude_client.ex`

- **Calls:** Anthropic Claude API (https://api.anthropic.com/v1/messages)
- **Model:** `claude-sonnet-4-20250514`
- **Module name:** `GreenManTavern.AI.ClaudeClient`
- **Status:** **EXISTS but NOT ACTIVELY USED** in DualPanelLive
  - `CharacterLive` uses `OpenAIClient` (not ClaudeClient) despite naming
  - `HomeLive` uses `ClaudeClient`
  - `DualPanelLive` uses `OpenAIClient` (OpenRouter)

**MindsDB Integration:**
- **Status:** **DISABLED/NOT USED**
- Config exists in `config/dev.exs` and `config/config.exs`
- No active MindsDB client module found
- Only references in backup/disabled files

### Context Building

**Context builder:** `lib/green_man_tavern/ai/character_context.ex` ✅ **EXISTS**

- **Module name:** `GreenManTavern.AI.CharacterContext`
- **Current implementation:**
  - `build_system_prompt/1` - Creates character personality prompts
    - Uses `character.system_prompt` if present (DB field)
    - Falls back to hardcoded prompts for specific characters
  - `build_context/3` - Builds user context for AI
    - Extracts facts from `user.profile_data["facts"]`
    - Formats facts by type (location, planting, sunlight, climate, etc.)
    - **PDF knowledge base search DISABLED** (commented out to save costs)
- **What context is sent:**
  - User profile facts (from `profile_data["facts"]`)
  - Formatted as structured text blocks by category
  - **NO knowledge base context** (currently disabled)

### Conversation Storage

**Conversation module:** `lib/green_man_tavern/conversations.ex` ✅ **EXISTS**

- **Module name:** `GreenManTavern.Conversations`
- **How messages stored:**
  - Individual messages stored in `conversation_history` table
  - Each message has: `user_id`, `character_id`, `message_type`, `message_content`
  - Messages stored immediately when sent/received
- **Session tracking:** ❌ **NO SESSION TRACKING**
  - No `session_id` field
  - No session grouping mechanism
  - Messages are just a flat list per user/character
- **Extraction:** ✅ **PER-MESSAGE EXTRACTION** (not session-end)
  - `FactExtractor.extract_facts/2` called per user message
  - Facts merged into `user.profile_data["facts"]`
  - No session-end summarization or extraction

### Character LiveView

**Path:** `lib/green_man_tavern_web/live/character_live.ex`

- **mount():**
  - Loads character by slug
  - Loads conversation history via `load_conversation_history/2`
  - Initializes empty chat_messages if no history
  - Sets up assigns for character, user_id, page titles

- **handle_event("send_message"):**
  - Adds user message to UI immediately
  - Stores message in `conversation_history` (sync)
  - Extracts facts asynchronously via `Task.start`
  - Sends `{:process_with_claude, ...}` message to self
  - **Note:** Despite name, actually uses `OpenAIClient` (not ClaudeClient)

- **handle_info({:process_with_claude, ...}):**
  - Builds context using `CharacterContext.build_context/3`
  - Builds system prompt using `CharacterContext.build_system_prompt/1`
  - Calls `OpenAIClient.chat/3` (OpenRouter)
  - Stores character response in `conversation_history`
  - Updates trust level
  - Updates UI with response

- **terminate():** ❌ **DOES NOT EXIST**
  - No cleanup on disconnect
  - No session-end processing

- **Current API call:**
  - Location: `handle_info({:process_with_claude, ...})`
  - Uses: `OpenAIClient.chat(message, system_prompt, context)`
  - API: OpenRouter (OpenAI GPT-4o-mini)

### DualPanelLive (Main Chat Interface)

**Path:** `lib/green_man_tavern_web/live/dual_panel_live.ex`

- **Similar structure to CharacterLive**
- Uses `OpenAIClient` (OpenRouter) for all AI calls
- Facts extracted per-message (async)
- No session tracking
- No terminate callback

---

## LIVEVIEW FINDINGS

### Active LiveViews

1. **DualPanelLive** (`lib/green_man_tavern_web/live/dual_panel_live.ex`)
   - Main application interface
   - Handles character chat, journal, quests, planting guide, living web
   - **Status:** ACTIVE, WORKING

2. **CharacterLive** (`lib/green_man_tavern_web/live/character_live.ex`)
   - Dedicated character interaction page
   - **Status:** ACTIVE, WORKING

3. **HomeLive** (`lib/green_man_tavern_web/live/home_live.ex`)
   - Home/tavern page
   - Uses `ClaudeClient` (different from DualPanelLive)
   - **Status:** ACTIVE

4. **LivingWebLive** (`lib/green_man_tavern_web/live/living_web_live.ex`)
   - Living web diagram interface
   - **Status:** ACTIVE

5. **DatabaseLive** (`lib/green_man_tavern_web/live/database_live.ex`)
   - Database management interface
   - **Status:** ACTIVE

6. **UserRegistrationLive** (`lib/green_man_tavern_web/live/user_registration_live.ex`)
   - User registration
   - **Status:** ACTIVE

7. **UserSessionLive** (`lib/green_man_tavern_web/live/user_session_live.ex`)
   - User login
   - **Status:** ACTIVE

### Backup/Disabled Files

- `living_web_live.ex.backup` - Backup file
- `OLD_living_web_live.ex.disabled` - Disabled file

**No terminate() callbacks found** in any LiveView.

---

## SEED DATA FINDINGS

### Character Seeds (`priv/repo/seeds/characters.exs`)

**What fields are being seeded:**
- `name` - Character name
- `archetype` - Character archetype
- `description` - Character description
- `focus_area` - Focus area
- `personality_traits` - JSONB array of traits
- `icon_name` - Icon identifier
- `color_scheme` - Color scheme (all "grey")
- `trust_requirement` - Trust level required ("none", "basic", "intermediate", "advanced")
- ⚠️ **`mindsdb_agent_name`** - **STILL PRESENT IN SEEDS** but not used

**Does mindsdb_agent_name still exist in seed?**
- ✅ **YES** - All 7 characters have `mindsdb_agent_name` values
- Example: `"student_knowledge_seeker"`, `"grandmother_elder_wisdom"`, etc.
- **SAFE TO REMOVE** from seeds (not used in code)

**Are there already system_prompt or similar fields?**
- ✅ **YES** - `system_prompt` field exists in characters table (added via migration)
- Migration `20251030120500_set_system_prompts_for_characters.exs` sets prompts
- `CharacterContext.build_system_prompt/1` uses DB field if present

---

## CONFIG FINDINGS

### API Keys

**OpenRouter:**
- Environment variable: `OPENROUTER_API_KEY`
- Config location: `System.get_env("OPENROUTER_API_KEY")` or `Application.get_env(:green_man_tavern, :openrouter_api_key)`
- **Status:** ACTIVE - Used by `OpenAIClient`

**Anthropic/Claude:**
- Environment variable: `ANTHROPIC_API_KEY`
- Config location: `System.get_env("ANTHROPIC_API_KEY")` or `Application.get_env(:green_man_tavern, :anthropic_api_key)`
- **Status:** EXISTS but not used in DualPanelLive (used in HomeLive)

**MindsDB:**
- Config exists in `config/dev.exs`:
  - `host: "localhost"`
  - `http_port: 48334`
  - `mysql_port: 48335`
  - `database: "mindsdb"`
  - `username: "mindsdb"`
  - `password: ""`
- **Status:** CONFIGURED but NOT USED

### Base URLs

- **OpenRouter:** `https://openrouter.ai/api/v1/chat/completions` (hardcoded in OpenAIClient)
- **Anthropic:** `https://api.anthropic.com/v1/messages` (hardcoded in ClaudeClient)
- **MindsDB:** Not actively used

---

## DEPENDENCY FINDINGS

### Key Dependencies (from `mix.exs`)

**HTTP Client:**
- ✅ `{:req, "~> 0.5"}` - **ACTIVE** - Used for all API calls
- ❌ `httpoison` - **NOT PRESENT** (correct - using Req as per guidelines)

**JSON:**
- ✅ `{:jason, "~> 1.2"}` - **PRESENT** - Used for JSON encoding/decoding

**MindsDB:**
- ❌ No MindsDB-related dependencies found
- Comment in `mix.exs`: `# Removed: MindsDB Integration Dependencies (no longer using MindsDB)`

**OpenRouter:**
- ❌ No OpenRouter-specific dependency (uses Req for HTTP)

**Other Notable:**
- `{:phoenix, "~> 1.8.1"}`
- `{:phoenix_live_view, "~> 1.1.0"}`
- `{:ecto_sql, "~> 3.11"}`
- `{:postgrex, ">= 0.0.0"}`
- `{:bcrypt_elixir, "~> 3.0"}` - Password hashing

---

## GAPS ANALYSIS

### What's Missing for Five-Tier Memory:

#### Tier 1 (Facts): ✅ **PARTIALLY IMPLEMENTED**
- ✅ Facts extraction exists (`FactExtractor`)
- ✅ Facts stored in `user.profile_data["facts"]`
- ✅ Facts formatted and sent to AI in context
- ❌ **GAP:** No confidence decay over time
- ❌ **GAP:** No fact conflict resolution
- ❌ **GAP:** No fact expiration/cleanup

#### Tier 2 (Threads): ❌ **NOT IMPLEMENTED**
- ❌ No `session_id` field in `conversation_history`
- ❌ No session grouping mechanism
- ❌ No thread/conversation thread tracking
- ❌ No session-end extraction
- ❌ No session summaries

#### Tier 3 (Trust): ✅ **IMPLEMENTED**
- ✅ `user_characters` table with `trust_level`
- ✅ `is_trusted` boolean calculated from trust_level
- ✅ Trust increments on interactions
- ✅ Trust requirements per character (`character.trust_requirement`)
- ❌ **GAP:** No trust decay over time
- ❌ **GAP:** No trust-based feature gating

#### Tier 4 (World State): ❌ **NOT IMPLEMENTED**
- ❌ No world state tracking
- ❌ No season tracking (`current_season` field missing)
- ❌ No growing season tracking (`days_into_growing_season` missing)
- ❌ No global game state

#### Tier 5 (Tavern State): ❌ **NOT IMPLEMENTED**
- ❌ No tavern-level state
- ❌ No active projects state tracking (`active_projects_state` missing)
- ❌ No tavern-wide statistics

### What's Missing for Session-End Extraction:

**CRITICAL GAPS:**
1. ❌ No `session_id` field in `conversation_history` table
2. ❌ No session grouping mechanism
3. ❌ No `terminate()` callback in LiveViews to trigger session-end processing
4. ❌ No session summarization module
5. ❌ No session-end fact extraction (only per-message extraction exists)
6. ❌ No `session_summary` field in `conversation_history`

**CURRENT BEHAVIOR:**
- Facts extracted **per message** immediately
- No session boundaries
- No session-end processing

### What's Missing for ASCII Diagrams:

**GAP ANALYSIS:** ❌ **EVERYTHING MISSING**
- No ASCII diagram generation module
- No diagram rendering system
- No ASCII art library
- No diagram storage mechanism
- No diagram display in UI

### What's Missing for Mysteries/Journeys:

**GAP ANALYSIS:** ❌ **EVERYTHING MISSING**
- No mysteries system
- No journeys system
- No quest-like narrative structures
- No mystery/journey database tables
- No mystery/journey UI components

---

## RECOMMENDATIONS

### PHASE 1: Safe Additions (No Risk)

**1. Add these database fields:**

**conversation_history:**
- `session_id` (string/uuid, nullable initially, indexed)
- `session_summary` (text, nullable)
- `extracted_facts` (jsonb, nullable) - For session-level facts

**users:**
- `current_season` (string, nullable)
- `days_into_growing_season` (integer, nullable)
- `active_projects_state` (jsonb, nullable) - Or store in existing `profile_data`

**characters:**
- `knowledge_domains` (jsonb array, nullable)
- `response_style` (string, nullable)
- `greeting_templates` (jsonb array, nullable)

**user_characters:**
- `communication_style_notes` (text, nullable)
- `successful_strategies` (jsonb array, nullable)

**2. Create these new modules:**

- `GreenManTavern.AI.SessionExtractor` - Session-end extraction
- `GreenManTavern.AI.SessionSummarizer` - Session summarization
- `GreenManTavern.Sessions` - Session management context
- `GreenManTavern.WorldState` - World state management
- `GreenManTavern.TavernState` - Tavern state management

**3. Create these new tables:**

- `sessions` table (if needed for session metadata)
- `mysteries` table (for mysteries system)
- `journeys` table (for journeys system)
- `user_mysteries` / `user_journeys` (user progress tracking)

### PHASE 2: Enhancements (Low Risk)

**1. Enhance these existing modules:**

- **CharacterContext:**
  - Add support for `knowledge_domains` filtering
  - Add support for `response_style` customization
  - Add support for `greeting_templates`

- **FactExtractor:**
  - Add confidence decay over time
  - Add fact conflict resolution
  - Add fact expiration logic

- **Conversations:**
  - Add session grouping functions
  - Add session query functions
  - Add session summary storage

**2. Add these features to LiveViews:**

- Add `terminate/2` callback to all chat LiveViews
- Implement session-end extraction on disconnect
- Add session ID generation on mount
- Add session tracking throughout conversation

### PHASE 3: Replacements (Higher Risk - Do Last)

**1. Only after testing, consider removing:**

- ⚠️ `mindsdb_agent_name` field from `characters` table
  - **Check production data first**
  - Remove from schema
  - Remove from seeds
  - Remove from any backup files

- ⚠️ MindsDB configuration from `config/dev.exs` and `config/config.exs`
  - Only remove if confirmed not needed
  - Keep commented for reference if uncertain

---

## CRITICAL NOTES

### DO NOT REMOVE:

- ✅ `profile_data` field in users - **ACTIVELY USED** for facts storage
- ✅ `system_prompt` field in characters - **ACTIVELY USED** by CharacterContext
- ✅ `trust_level` and trust system - **ACTIVELY USED** for character interactions
- ✅ `conversation_history` table - **CRITICAL** for all chat functionality
- ✅ `FactExtractor` module - **ACTIVELY USED** for per-message fact extraction
- ✅ `OpenAIClient` module - **PRIMARY API CLIENT** for all chat interactions

### SAFE TO ADD:

- ✅ All Phase 1 database fields (nullable, won't break existing code)
- ✅ New modules for session management
- ✅ Session tracking fields (backward compatible)
- ✅ World state fields (nullable)
- ✅ Character enhancement fields (nullable)

### TEST BEFORE REMOVING:

- ⚠️ `mindsdb_agent_name` - Check if any production data uses it
- ⚠️ MindsDB config - Verify no external systems depend on it
- ⚠️ `ClaudeClient` - Currently unused in DualPanelLive but used in HomeLive

---

## SUMMARY

**Current State:**
- ✅ Chat system is **WORKING** using OpenRouter/OpenAI
- ✅ Fact extraction is **ACTIVE** (per-message)
- ✅ Trust system is **IMPLEMENTED**
- ✅ Context building is **FUNCTIONAL**
- ❌ Session tracking is **MISSING**
- ❌ Session-end extraction is **MISSING**
- ❌ World/Tavern state tracking is **MISSING**
- ❌ ASCII diagrams are **NOT IMPLEMENTED**
- ❌ Mysteries/Journeys are **NOT IMPLEMENTED**

**Primary Gaps:**
1. **Session Management** - No session_id, no session grouping, no session-end processing
2. **World State** - No season tracking, no growing season tracking
3. **Session Extraction** - Only per-message extraction, no session-level summarization
4. **Advanced Features** - ASCII diagrams and mysteries/journeys completely missing

**Legacy Code:**
- `mindsdb_agent_name` field exists but unused (safe to remove after verification)
- MindsDB config exists but unused (safe to remove after verification)

---

**END OF REPORT**

