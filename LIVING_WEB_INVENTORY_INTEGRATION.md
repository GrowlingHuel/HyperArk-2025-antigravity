# Living Web ↔ Inventory Integration: Aspirational Design

## Core Philosophy

**Living Web = Design Phase** (Planning what systems to build)  
**Inventory = Operations Phase** (Managing what you've built)

The integration creates a **design → build → operate → optimize** loop that mirrors real-world permaculture implementation.

---

## The Integration Loop

```
┌─────────────────────────────────────────────────────────┐
│                  THE FULL CYCLE                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. DESIGN (Living Web)                                 │
│     "I want to connect my herb garden to my kitchen"    │
│     → Validates connection is possible                  │
│     → Shows what flows (herbs, waste)                   │
│     → Generates quest: "Build this connection"          │
│                                                          │
│  2. BUILD (Real World)                                  │
│     User physically creates the system                  │
│     → Takes photos                                      │
│     → Marks quest as "In Progress"                      │
│     → System status: "planned" → "building"             │
│                                                          │
│  3. ACTIVATE (Inventory appears)                        │
│     User marks system as "Active"                       │
│     → System appears in Living Web with color change    │
│     → Inventory category for this system appears        │
│     → Ready to track resources                          │
│                                                          │
│  4. OPERATE (Inventory tracks daily use)                │
│     User harvests basil from herb garden                │
│     → 12 basil appears in inventory (source: garden)    │
│     → Living Web shows flow animation (garden→kitchen)  │
│     → User marks "used in recipe"                       │
│     → 3 basil consumed, 9 remain                        │
│                                                          │
│  5. OPTIMIZE (System learns and suggests)               │
│     Inventory shows: "You harvest 12 basil weekly"      │
│     → Living Web suggests: "Add drying rack?"           │
│     → Shows potential connection: garden→rack→pantry    │
│     → New quest generated: "Preserve your abundance"    │
│                                                          │
│  6. EXPAND (Loop continues)                             │
│     User adds drying rack to Living Web                 │
│     → [Back to step 1: Design]                          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Interaction Patterns

### **Pattern 1: From Design to Reality**

#### Living Web (Planning Phase):
```
┌────────────────────────────────────────────────┐
│ LIVING WEB - Design Mode                       │
├────────────────────────────────────────────────┤
│                                                 │
│    [HERB GARDEN] ─────→ [KITCHEN]              │
│          ↓                   ↓                  │
│    [DRYING RACK]       [COMPOST BIN]            │
│                                                 │
│  Status: PLANNED                                │
│  ┌──────────────────────────────────────────┐  │
│  │ Quest Generated:                         │  │
│  │ "Build Herb Garden Connection"           │  │
│  │                                           │  │
│  │ Steps:                                    │  │
│  │ 1. Install garden bed (estimated: $50)   │  │
│  │ 2. Plant 4 herb varieties                │  │
│  │ 3. Set up path to kitchen                │  │
│  │ 4. Upload completion photo               │  │
│  │                                           │  │
│  │ Reward: 50 XP + unlock "Harvesting"      │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  [Mark as Building] [Mark as Active]           │
└────────────────────────────────────────────────┘
```

#### After User Builds in Real World:
```
┌────────────────────────────────────────────────┐
│ LIVING WEB - Active System                     │
├────────────────────────────────────────────────┤
│                                                 │
│    [HERB GARDEN] ═════→ [KITCHEN]              │
│     (Active ✓)          (Active ✓)             │
│                                                 │
│  Status: ACTIVE (Since: Nov 15, 2025)          │
│                                                 │
│  Resources produced: 156 herbs (lifetime)      │
│  Current inventory: 12 basil, 5 cilantro       │
│  Next harvest: ~3 days                          │
│                                                 │
│  [View Inventory] [View History] [Optimize]    │
└────────────────────────────────────────────────┘
```

---

### **Pattern 2: Inventory Drives Living Web Suggestions**

#### Inventory Shows Pattern:
```
╔═══════════════════════════════════════════════════════╗
║ INVENTORY - Herb Stockpile                           ║
╠═══════════════════════════════════════════════════════╣
║                                                        ║
║  §§§§§§ ≈≈≈≈≈≈ ♠♠♠♠♠♠  ◘◘◘◘◘◘                       ║
║  HERBS  WATER  TOOLS   SEEDS                          ║
║  (87)   (12L)  (8)     (156)                          ║
║   ⚠️    ✓      ✓       ✓                            ║
║                                                        ║
║  ┌─ HERBS (87) ──────────────────────────────────┐   ║
║  │                                                │   ║
║  │  🌿🌿🌿🌿🌿🌿🌿🌿🌿🌿🌿🌿 Basil (45)           │   ║
║  │  🌱🌱🌱🌱🌱🌱🌱🌱🌱 Cilantro (32)              │   ║
║  │  🍃🍃🍃 Oregano (10)                          │   ║
║  │                                                │   ║
║  │  ⚠️ WARNING: You have 3x normal harvest       │   ║
║  │     87% will spoil in 4 days                  │   ║
║  │                                                │   ║
║  │  💡 SUGGESTION:                                │   ║
║  │     Add "Drying Rack" to preserve excess      │   ║
║  │     [View in Living Web] [Generate Quest]     │   ║
║  └────────────────────────────────────────────────┘   ║
╚═══════════════════════════════════════════════════════╝
```

#### User Clicks "View in Living Web":
```
┌────────────────────────────────────────────────┐
│ LIVING WEB - Opportunity Detection              │
├────────────────────────────────────────────────┤
│                                                 │
│    [HERB GARDEN] ─────→ [KITCHEN]              │
│          ↓                                      │
│          ?  ← OPPORTUNITY DETECTED              │
│          ↓                                      │
│    [DRYING RACK] ─────→ [PANTRY]               │
│     (Suggested)         (Existing)              │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │ OPPORTUNITY: Preserve Herb Abundance     │  │
│  │                                           │  │
│  │ Problem:                                  │  │
│  │ • Producing 45 basil/week                │  │
│  │ • Using only 15/week                     │  │
│  │ • Losing 30/week to spoilage             │  │
│  │                                           │  │
│  │ Solution:                                 │  │
│  │ • Add drying rack ($25)                  │  │
│  │ • Preserve 30 basil/week                 │  │
│  │ • Dried herbs last 12 months             │  │
│  │                                           │  │
│  │ Impact:                                   │  │
│  │ • Close the loop (0% waste)              │  │
│  │ • Year-round herb supply                 │  │
│  │ • Unlock "Preservation" skill tree       │  │
│  │                                           │  │
│  │ [Add to Living Web] [Create Quest]       │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

---

### **Pattern 3: Daily Operations Flow**

#### Morning: User Harvests from Garden
```
Real World Action: Pick 12 basil leaves

Living Web Updates:
┌────────────────────────────────────┐
│ [HERB GARDEN] ═══[🌿]═══→ [?]     │
│                  ↑                  │
│            Harvested!              │
│         (12 basil collected)        │
└────────────────────────────────────┘

Inventory Updates:
╔══════════════════════════════════╗
║ + 12 BASIL added to inventory    ║
║   Source: Herb Garden (Zone A)   ║
║   Fresh - use within 3 days      ║
╚══════════════════════════════════╝
```

#### Afternoon: User Cooks
```
Inventory Action: Select basil → "Use in Recipe: Salad"

Inventory Shows:
┌─────────────────────────────────────┐
│ 🥗 SALAD RECIPE                     │
│                                     │
│ Needs:                              │
│ • 3 basil ✓                         │
│ • 2 tomato ✓                        │
│ • 1 lettuce ✓                       │
│                                     │
│ [MAKE SALAD]                        │
└─────────────────────────────────────┘

After Making:
• 3 basil consumed (9 remain)
• Waste produced: stems, roots

Living Web Updates:
┌────────────────────────────────────┐
│ [HERB GARDEN] → [KITCHEN] ✓        │
│                     ↓               │
│              [COMPOST BIN]          │
│           (♻️ waste detected)       │
│                                     │
│  ⚠️ Opportunity: Add waste         │
│     [Track Waste] [Compost It]     │
└────────────────────────────────────┘
```

---

### **Pattern 4: Processing Visualization**

#### Starting a Process:
```
Inventory: User selects 20 basil → "Start Drying"

╔══════════════════════════════════════════════════════╗
║ ACTIVE PROCESSES                                     ║
╠══════════════════════════════════════════════════════╣
║                                                       ║
║  [DRYING RACK]                                       ║
║  ┌────────────────────────────────────────────────┐ ║
║  │ 🌿🌿🌿 → [====    ] → 🍃🍃🍃                   │ ║
║  │ 20 basil        Day 2/3      (Hover: drying...) │ ║
║  │                                                 │ ║
║  │ Started: Nov 18, 2025                          │ ║
║  │ Complete: Nov 20, 2025 (~1 day remaining)     │ ║
║  │                                                 │ ║
║  │ Result: ~15g dried basil                       │ ║
║  └────────────────────────────────────────────────┘ ║
║                                                       ║
║  [FERMENTING CROCK]                                  ║
║  ┌────────────────────────────────────────────────┐ ║
║  │ 🥒🥒🥒 → [========  ] → 🫙                      │ ║
║  │ 40 cucumbers   Day 6/7    (Hover: fermenting...)│ ║
║  │                                                 │ ║
║  │ Result: ~3 jars pickles (Est. tomorrow)        │ ║
║  └────────────────────────────────────────────────┘ ║
╚══════════════════════════════════════════════════════╝

Living Web Shows:
┌────────────────────────────────────┐
│ [HERB GARDEN] → [DRYING RACK]      │
│                  [Processing...]    │
│                  ↓                  │
│                [PANTRY]             │
│             (Will receive in 1d)    │
└────────────────────────────────────┘
```

#### When Process Completes:
```
Notification:
╔══════════════════════════════════════╗
║ 🎉 Process Complete!                 ║
║                                      ║
║ Your basil is dried!                 ║
║ + 15g dried basil → Pantry           ║
║                                      ║
║ XP Earned: +10 (Preservation)        ║
╚══════════════════════════════════════╝

Living Web Updates:
┌────────────────────────────────────┐
│ [HERB GARDEN] → [DRYING RACK] ✓    │
│                  ↓                  │
│                [PANTRY] ✓           │
│           (15g dried basil stored)  │
│                                     │
│  Connection used: 1 time            │
│  Total preserved: 15g               │
└────────────────────────────────────┘
```

---

## System States and Transitions

### **Living Web Node States:**

```
PLANNED (Grey, dashed border)
  ↓ [User marks "Building"]
BUILDING (Orange, dashed border)
  ↓ [User uploads photo + marks "Active"]
ACTIVE (Green, solid border)
  ↓ [System detects no activity for 30 days]
DORMANT (Blue, dotted border)
  ↓ [User marks "Deactivated"]
INACTIVE (Grey, solid border)
```

### **Inventory Item States:**

```
FRESH (Green symbol)
  → "Use within 3 days"
  → Hover shows countdown
  
AGING (Yellow symbol)
  → "Use today!"
  → Prominent warning
  
PRESERVED (Blue symbol)
  → "Shelf-stable"
  → Shows preservation date
  
PROCESSING (Purple symbol, animated)
  → "Drying..." / "Fermenting..."
  → Progress bar on hover
  
CONSUMED (No longer in inventory)
  → Logged in history
  → Contributes to statistics
```

---

## Data Flow Architecture

### **What Living Web Knows:**

```elixir
# Living Web stores SYSTEMS
%Node{
  id: "herb_garden_1",
  type: "system",
  status: "active",
  position: {x, y},
  metadata: %{
    installed_date: ~D[2025-11-15],
    production_rate: 12,  # basil per week
    next_harvest_estimate: ~D[2025-11-23]
  }
}

%Edge{
  from: "herb_garden_1",
  to: "kitchen_1",
  resource_type: "herbs",
  status: "active",
  total_flows: 156,  # lifetime herbs moved
  last_flow: ~N[2025-11-19 14:30:00]
}
```

### **What Inventory Knows:**

```elixir
# Inventory stores RESOURCES
%InventoryItem{
  id: "basil_batch_42",
  name: "Basil",
  category: "herbs",
  symbol: "§",
  quantity: 12,
  unit: "plants",
  status: "fresh",
  freshness_days: 3,
  source_system_id: "herb_garden_1",  # ← Links to Living Web!
  harvested_at: ~N[2025-11-19 08:00:00],
  possible_uses: [
    %{type: "recipe", name: "Salad", quantity_needed: 3},
    %{type: "recipe", name: "Pesto", quantity_needed: 20},
    %{type: "process", name: "Dry", system_id: "drying_rack_1"},
    %{type: "waste", name: "Compost", system_id: "compost_bin_1"}
  ]
}
```

### **The Bridge: Actions**

```elixir
# When user performs action in inventory:
%Action{
  type: "harvest",
  user_id: 1,
  source_system_id: "herb_garden_1",  # Living Web node
  items_created: ["basil_batch_42"],  # Inventory items
  timestamp: ~N[2025-11-19 08:00:00]
}

# This action:
# 1. Creates inventory item
# 2. Updates Living Web edge.last_flow
# 3. Increments edge.total_flows
# 4. Triggers animation in Living Web
# 5. Checks for completion of any quests
```

---

## Visual Integration Examples

### **Example 1: Clicking Inventory Item**

```
User clicks "12 Basil" in inventory
  ↓
Detail panel shows:
┌──────────────────────────────────────┐
│ 🌿 BASIL (Fresh)                     │
│ Quantity: 12 plants                  │
│ Harvested: Nov 19, 8:00 AM (2h ago)  │
│                                       │
│ Source System:                        │
│ → Herb Garden (Zone A)                │
│   [View in Living Web] ← Button       │
│                                       │
│ Can use in:                           │
│ • 4 salads                            │
│ • 1 batch pesto (need 8 more)        │
│ • Start drying                        │
│ • Compost                             │
└──────────────────────────────────────┘

User clicks [View in Living Web]
  ↓
Living Web opens with:
• Herb Garden node highlighted
• Camera zooms to this node
• Popup shows recent harvests
• Connected nodes glow
```

### **Example 2: Clicking Living Web Node**

```
User clicks "Herb Garden" node in Living Web
  ↓
Detail panel shows:
┌──────────────────────────────────────┐
│ 🌿 HERB GARDEN (Zone A)              │
│ Status: Active since Nov 15          │
│                                       │
│ Connections:                          │
│ → Kitchen (herbs)                     │
│ → Drying Rack (herbs)                 │
│ ← Water Tank (water)                  │
│                                       │
│ Production Statistics:                │
│ • 156 herbs harvested (lifetime)      │
│ • Avg 12/week                         │
│ • Last harvest: 2 hours ago           │
│                                       │
│ Current Inventory:                    │
│ → 12 basil (fresh)                    │
│ → 5 cilantro (fresh)                  │
│ → 0 oregano                           │
│   [View in Inventory] ← Button        │
│                                       │
│ Next Actions:                         │
│ • Ready to harvest (3 days)           │
│ • Water needed (2 days)               │
└──────────────────────────────────────┘
```

---

## Opportunity Detection Logic

### **Pattern Recognition:**

```
IF inventory shows:
  • Item quantity > 3x normal usage
  • Item will spoil before use
  • No preservation system connected

THEN Living Web suggests:
  • Add preservation system (drying, fermenting, freezing)
  • Show potential connection (dotted line)
  • Calculate ROI (cost vs waste saved)
  • Generate implementation quest

Example:
  User has 45 basil, uses 15/week
  → Will lose 30 to spoilage
  → Living Web suggests: "Add drying rack ($25)"
  → Shows: "Save $120/year in wasted herbs"
  → Quest: "Build a Drying Rack"
```

### **Loop Closure Detection:**

```
IF Living Web shows:
  • Output with no destination (waste)
  • Input with no source (buying externally)
  
THEN suggest connection:
  • Kitchen waste → Compost
  • Compost → Garden (close the loop!)
  • Show: "You're buying X/month that you could produce"
  
Example:
  Kitchen produces 2kg food waste/week
  → Currently goes to trash
  → Living Web suggests: "Add compost bin"
  → Shows: "Save $40/year on fertilizer"
  → Quest: "Start Composting"
```

---

## Quest Generation from Integration

### **Quest Type 1: Build Missing System**

```
Trigger: Inventory shows abundance, no processing system
Generated Quest:

┌──────────────────────────────────────────────────┐
│ 🎯 QUEST: Preserve Your Herb Abundance           │
├──────────────────────────────────────────────────┤
│                                                   │
│ Why: You're losing 30 basil/week to spoilage    │
│                                                   │
│ Goal: Add a drying system to preserve herbs      │
│                                                   │
│ Steps:                                            │
│ 1. ☐ Research drying methods (3 options below)   │
│ 2. ☐ Acquire/build drying rack ($25-50)         │
│ 3. ☐ Install in Living Web (add node)           │
│ 4. ☐ Connect: Garden → Rack → Pantry            │
│ 5. ☐ Dry first batch (3 days)                   │
│ 6. ☐ Upload photo of dried herbs                │
│                                                   │
│ Reward:                                           │
│ • 100 XP                                          │
│ • Unlock "Preservation" skill tree               │
│ • Badge: "Food Saver"                            │
│                                                   │
│ Resources:                                        │
│ • [How to build a solar dehydrator - PDF]       │
│ • [Herb drying guide - Video]                   │
│ • [Buy dehydrator - Link]                        │
└──────────────────────────────────────────────────┘
```

### **Quest Type 2: Close the Loop**

```
Trigger: Waste detected, compost system available
Generated Quest:

┌──────────────────────────────────────────────────┐
│ 🎯 QUEST: Close Your Kitchen Loop                │
├──────────────────────────────────────────────────┤
│                                                   │
│ Why: 2kg food waste/week going to trash         │
│      Could return to garden as fertilizer        │
│                                                   │
│ Goal: Connect kitchen waste → compost → garden   │
│                                                   │
│ Steps:                                            │
│ 1. ☐ Set up compost collection in kitchen       │
│ 2. ☐ Add "Compost Bin" to Living Web            │
│ 3. ☐ Connect: Kitchen → Compost → Garden        │
│ 4. ☐ Compost first batch (30 days)              │
│ 5. ☐ Apply to garden                            │
│ 6. ☐ Track results (plant growth)               │
│                                                   │
│ Impact:                                           │
│ • Zero kitchen waste                             │
│ • Free fertilizer ($40/year saved)               │
│ • Closed nutrient loop! ♻️                       │
│                                                   │
│ Reward: 150 XP + "Loop Closer" badge            │
└──────────────────────────────────────────────────┘
```

---

## Mobile-First Considerations (Future)

While not needed now, the design accommodates mobile:

### **Mobile Living Web:**
- Tap node → Detail sheet slides up
- Swipe between nodes
- Pinch to zoom
- Long-press to edit

### **Mobile Inventory:**
- Symbol categories at top (swipeable)
- Tap symbol to expand
- Item cards (not grid)
- Swipe item left for actions

---

## Success Metrics

### **For Users (Game Metrics):**
- Systems built (Living Web nodes activated)
- Resources tracked (Inventory items logged)
- Waste reduced (spoilage %)
- Loops closed (complete cycles)
- XP earned, levels gained

### **For Real World (Impact Metrics):**
- Money saved (external inputs eliminated)
- Time efficiency (less shopping, less waste management)
- Resilience gained (% of needs met internally)
- Knowledge acquired (skills unlocked)
- Community engagement (shares, trades)

---

## Technical Implementation Notes

### **Data Sync:**
```
Living Web changes → Update inventory
- Node activated → Enable inventory category
- Node deactivated → Mark items as "orphaned"
- Connection made → Enable resource flows

Inventory changes → Update Living Web
- Harvest logged → Increment edge.total_flows
- Process started → Mark system "in use"
- Abundance detected → Trigger opportunity
```

### **State Management:**
```
Phoenix LiveView assigns:
@nodes (Living Web systems)
@edges (Living Web connections)
@inventory_items (Current resources)
@active_processes (Ongoing transformations)
@opportunities (Detected suggestions)
@quests (Generated from opportunities)
```

### **Real-time Updates:**
```
PubSub topics:
- "user:#{user_id}:living_web" → Node/edge updates
- "user:#{user_id}:inventory" → Item updates
- "user:#{user_id}:processes" → Processing complete
- "user:#{user_id}:quests" → New quest available
```

---

## Phase-by-Phase Rollout

### **Phase 1: Basic Link (Week 1)**
- Inventory items have `source_system_id`
- "View in Living Web" button
- Living Web shows "Current Inventory: X items"

### **Phase 2: Harvesting Flow (Week 2)**
- Click Living Web node → "Harvest"
- Creates inventory item automatically
- Flow animation shows resource moving

### **Phase 3: Processing (Week 3)**
- Start process in inventory
- Track progress (drying, fermenting)
- Complete → New item in inventory
- Living Web shows processing systems active

### **Phase 4: Opportunity Detection (Week 4)**
- Analyze inventory patterns
- Detect waste, abundance, shortages
- Generate Living Web suggestions
- Create implementation quests

### **Phase 5: Full Integration (Week 5+)**
- Recipe system
- Waste tracking
- Loop closure metrics
- Community features (trade, share)

---

## The Ultimate Vision

**A user's journey:**

1. **Day 1:** Draws herb garden on Living Web (planning)
2. **Week 1:** Builds garden in real life (photos uploaded)
3. **Week 2:** Marks system active, harvests first basil
4. **Week 3:** Inventory tracks 12 basil, used in 4 meals
5. **Week 4:** Abundance detected, drying rack suggested
6. **Week 5:** Adds drying rack to Living Web, starts quest
7. **Week 6:** Builds rack, dries first batch
8. **Week 7:** Has year-round herb supply, no waste
9. **Week 8:** Shares system design with community
10. **Week 10:** Helping others build similar systems

**The app becomes a bridge between digital planning and physical reality, with the Living Web as the blueprint and Inventory as the logbook of real-world operations.**

---

## Key Principles for Development

1. **Real-world first:** Every feature must help users BUILD and OPERATE actual systems
2. **Show, don't tell:** Visual feedback, not just text notifications
3. **Celebrate wins:** Animations, badges, XP for completed loops
4. **Learn from patterns:** System suggests based on actual usage data
5. **Keep it simple:** Dense information, but intuitive navigation
6. **Modular design:** Every system/item follows same structure
7. **Fractal thinking:** Systems within systems, resources become products

---

## Questions This Design Answers

✅ How do users go from idea to implementation?  
→ Living Web planning → Quest generation → Real-world build → Activate system

✅ How do we track what they actually have?  
→ Inventory logs resources with source system links

✅ How do we detect opportunities?  
→ Analyze inventory patterns, detect waste/abundance/shortages

✅ How do we guide optimization?  
→ Living Web suggests connections based on inventory data

✅ How do we prevent the systems from being redundant?  
→ Living Web = macro (systems), Inventory = micro (resources), unified by actions

✅ How do we make it feel like a game?  
→ Quests, XP, badges, animations, progress bars, achievements

✅ How do we serve the real-world goal?  
→ Every digital action maps to a physical step in building resilient systems

---

This integration transforms Green Man Tavern from a planning tool into a **complete lifecycle management system** for real-world permaculture implementation.
