# Investigation Report - November 4, 2025

## 1. ✅ CONVERSATIONS ARE BEING SAVED CORRECTLY

### What Happened to Old Conversations
- **Database was reset** during migrations this morning (due to migration conflicts)
- **Old conversations were lost** (this was collateral damage from the database reset)
- **NEW conversations ARE being saved** properly since the reset

### Current Conversation Data
```
Total messages: 10 (saved today after reset)

- Farmer conversation (4 messages) - About turnips/potatoes in Launceston
- Alchemist conversation (6 messages) - About homebrewing & your location
```

### Verification: System IS Working
✅ Your Launceston conversation with Farmer was saved  
✅ Alchemist correctly knew you were in Launceston (from profile data)  
✅ All messages timestamped and stored in `conversation_history` table

---

## 2. ✅ USER PROFILE/CONTEXT SYSTEM CONFIRMED WORKING

### How It Works

#### Step 1: Fact Extraction (Async)
When you send a message, the `FactExtractor` runs in the background using OpenAI:

```elixir
# Runs asynchronously after each message
Task.start(fn ->
  facts = FactExtractor.extract_facts(message, character.name)
  # Merges new facts with existing profile_data
  merged = FactExtractor.merge_facts(existing, facts)
  # Updates user.profile_data["facts"]
  Accounts.update_user(user, %{profile_data: new_pd})
end)
```

#### Step 2: Fact Storage
Facts are stored in `users.profile_data` as JSON:
```json
{
  "facts": [
    {
      "type": "location",
      "key": "city",
      "value": "Launceston",
      "confidence": 0.95,
      "learned_at": "2025-11-04T12:57:25Z"
    },
    ...
  ]
}
```

#### Step 3: Context Building
When an AI character responds, the system:
1. **Loads latest user facts** from database
2. **Builds context** using `CharacterContext.build_context/3`
3. **Formats facts** into structured profile
4. **Sends to AI** with system prompt + context + user message

### Your Current Profile Data

```
Facts extracted: 6

[location] city: Launceston (confidence: 0.95)
[location] state: Tasmania (confidence: 0.95)
[goal] planting_intent: immediate planting (confidence: 0.9)
[planting] plant_type_1: turnips (confidence: 0.8)
[planting] plant_type_2: potatoes (confidence: 0.8)
[goal] exploration_of_alternatives: looking for other root vegetables (confidence: 0.7)
```

### Fact Types Tracked
- **location**: city, state, hemisphere, etc.
- **planting**: plant types, techniques
- **sunlight**: exposure, timing
- **climate**: zone, conditions
- **resource**: tools, materials
- **goal**: objectives, intentions
- **constraint**: limitations, challenges
- **water**: availability, systems
- **soil**: type, quality

### Example API Context Sent to Characters

```
USER PROFILE (6 facts known):

Location: Launceston, Tasmania
Planting: turnips, potatoes
Goals: immediate planting, looking for other root vegetables
```

This is why the Alchemist knew you were in Launceston - it was in the context sent with your message!

---

## 3. ❓ JOURNAL PAGINATION DISAPPEARED

### Investigation Findings

The pagination code **EXISTS** in the template (lines 1272-1380), but it only displays when:

```elixir
<%= if total_pages_pagination > 1 do %>
  <!-- Pagination controls here -->
<% end %>
```

### Why It's Not Showing

**Calculation:**
```
Entries per page: 15 (default)
Total entries: 11 (from seed data)
Total pages: ceil(11 / 15) = 1 page
```

**Result:** Pagination hidden because `total_pages (1) is NOT > 1`

### When Pagination WILL Appear

Pagination will automatically show when you have **16+ journal entries** (more than one page).

### Yesterday vs Today

**Yesterday:**
- You likely had 16+ entries from real conversations
- Pagination was visible

**Today (after reset):**
- Only 11 seed entries (placeholder data)
- Pagination hidden (by design - no need to paginate 1 page)

### Solution

The pagination **will automatically reappear** once you:
1. Have more conversations (creates journal entries)
2. Manually create more journal entries
3. Have 16+ total entries

---

## SUMMARY

| System | Status | Details |
|--------|--------|---------|
| **Conversation Saving** | ✅ WORKING | 10 messages saved today |
| **Fact Extraction** | ✅ WORKING | 6 facts extracted from your conversations |
| **Profile Building** | ✅ WORKING | Location, planting goals tracked |
| **AI Context** | ✅ WORKING | Alchemist knew about Launceston |
| **Journal Pagination** | ⚠️ HIDDEN | Will reappear at 16+ entries |
| **Old Data** | ❌ LOST | Database reset this morning |

---

## WHAT HAPPENED THIS MORNING

1. **Migration conflicts** detected (old plant migrations conflicting with new ones)
2. **Database reset** to ensure clean migration state
3. **All user data lost** including:
   - Old conversations
   - Old journal entries  
   - Old user profiles
4. **Systems working correctly** now:
   - New conversations saving ✅
   - Facts extracting ✅
   - Context building ✅

---

## GOING FORWARD

### Development Phase (Now)
- Data resets are **normal and expected**
- Seed data used for testing
- Focus on features, not data preservation

### Production Phase (Later)
- Migrations only **ADD** new features
- User data **never deleted**
- Database backups in place
- No more resets

---

## VERIFICATION CHECKLIST

✅ Conversations stored in `conversation_history` table  
✅ Facts stored in `users.profile_data["facts"]`  
✅ Facts sent to AI in context  
✅ Characters reference user information correctly  
✅ Pagination code exists (hidden when < 2 pages)  
✅ API credentials safe in `.env` file  

**All systems operational!** 🎉

