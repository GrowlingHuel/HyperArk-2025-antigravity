# Green Man Tavern: AI Agent Training Summary

> **Purpose**: This document provides a comprehensive overview of the Green Man Tavern project, its architecture, core systems, and technical standards. It is designed to onboard AI agents and developers to the project's context, codebase, and philosophy.

---

## 1. Project Identity & Vision

**Green Man Tavern** is a **Permaculture-based Real-Life RPG** web application.
- **Goal**: Gamify the design and implementation of regenerative systems (gardens, water systems, community structures) in the real world.
- **Core Metaphor**: A digital "Tavern" where users interact with AI characters (Mentors) to learn, plan, and track their real-world permaculture journey.
- **Tech Stack**:
    - **Backend**: Elixir / Phoenix LiveView (v1.8+)
    - **Database**: PostgreSQL (with pgvector for RAG)
    - **Frontend**: Tailwind CSS (v4), Vanilla JS Hooks (XyFlow for canvas)
    - **AI**: Anthropic Claude (via API), MindsDB (legacy/removed), RAG (Knowledge Base)

### **Aesthetic Philosophy**
- **HyperCard / Macintosh System 7**: Greyscale, sharp corners, 1px black borders, Chicago/Monaco fonts.
- **"System, not App"**: Tools feel like utilities, not "content".
- **No Smooth Animations**: Snap transitions, instant UI updates (unless specifically designed for "aliveness").

---

## 2. Architecture Overview

### **2.1 Dual-Panel Layout**
The application uses a persistent **Dual-Panel Architecture** (`DualPanelLive`) to maintain state across navigation.
- **Left Panel (Tavern)**: Persistent character interaction. Shows Tavern Home or Character Chat. Never unmounts during right-panel navigation.
- **Right Panel (Workspace)**: Context-specific content. Shows Welcome, Living Web (Canvas), Garden, or Database.
- **Navigation**: Handled via `push_patch` and LiveView events (`navigate_right`, `select_character`).
- **State**: Managed in `DualPanelLive` parent, passed to `LiveComponents` (`TavernPanelComponent`, `LivingWebPanelComponent`).

### **2.2 Core Contexts**
- **Accounts**: User authentication (Argon2, Session tokens).
- **Characters**: AI mentors (The Grandmother, The Alchemist, etc.), Trust levels, Personality traits.
- **Systems**: Permaculture system templates (Projects), User instances (UserSystems), Connections.
- **Diagrams**: Living Web canvas state (Nodes, Edges).
- **Conversations**: Chat history, Session management.
- **Documents**: Knowledge base chunks for RAG.
- **PlantingGuide**: Frost dates, Plant data, Climate zones.

---

## 3. Key Systems & Features

### **3.1 The Living Web (Visual System Designer)**
A node-based editor for designing permaculture systems.
- **Tech**: XyFlow (React-based) wrapped in a Phoenix LiveView Hook (`xyflow_editor.js`).
- **Nodes**: Represent Systems (e.g., "Herb Garden", "Compost Bin").
- **Edges**: Represent Resource Flows (e.g., "Water", "Waste", "Nutrients").
- **Features**:
    - **Visual I/O**: Nodes show input/output ports with counts.
    - **Drag-to-Connect**: Create connections by dragging between ports.
    - **Opportunity Detection**: System suggests connections (e.g., "You have unused waste, connect to Compost").
    - **Inventory Integration**: "Planned" systems in Living Web become "Active" inventory categories upon implementation.

### **3.2 AI Characters & RAG**
- **Interaction**: Users chat with characters to get advice.
- **RAG (Retrieval-Augmented Generation)**:
    - User query → Search `document_chunks` (PostgreSQL) → Retrieve context → Send to Claude with System Prompt.
- **Session Processing**:
    - Conversations are grouped into **Sessions**.
    - **Trigger**: Switching characters, returning to tavern, or navigating to journal.
    - **Output**: A single **Journal Entry** summary per session and **Quests** (if conversation score ≥ 8).
    - **Fix**: UUID handling ensures session IDs are correctly processed as strings.

### **3.3 Planting Guide**
- **Frost Dates**: Precise planting calculations based on city frost data.
    - **Data**: `city_frost_dates` table (First/Last frost).
    - **Logic**: `PlantingGuide.calculate_planting_date/2`.
    - **UI**: Shows "Precise Planting Window" (Green) if data exists, else Month Ranges (Orange).
- **Climate Zones**: Köppen climate classification for broad recommendations.

### **3.4 Journal & Quests**
- **Journal**:
    - **Space-Based Pagination**: Pagination appears only if content overflows vertical space (dynamic detection via JS Hook `JournalOverflow`).
    - **Generation**: Created automatically from AI sessions.
- **Quests**:
    - Generated from high-quality conversations.
    - Tracked in `user_quests`.
    - **Rendering**: Special handling for "Planting Quests" (requires string conversion for HTML rendering).

---

## 4. Technical Standards & Guidelines

### **4.1 Code Style**
- **Elixir**: Functional, pattern matching, `with` blocks for complex flows.
- **LiveView**:
    - Use `stream` for collections.
    - Use `JS` commands for client-side interactions where possible.
    - **NEVER** use `phx-update="append/prepend"` (deprecated).
- **CSS**: Tailwind v4. Use utility classes. Avoid `@apply` in CSS files.
- **Naming**: `snake_case` for files/functions, `PascalCase` for modules.

### **4.2 Common Pitfalls (Troubleshooting)**
- **Cursor Context Overload**: If AI seems stuck, reset the agent/context.
- **LiveView Handlers**: Ensure `handle_event` matches the `phx-click` name exactly.
- **UUIDs**: Ecto UUIDs are binaries; API/Templates often need Strings. Always cast if unsure (`Ecto.UUID.cast!/1` or `to_string/1`).
- **HTML Concatenation**: `Phoenix.HTML.raw()` returns a Tuple. Convert to string before concatenating with `<>`.

### **4.3 Testing**
- **Strategy**: Focus on critical paths (Session flow, Quest generation, Planting calculations).
- **Manual Verification**: Essential for UI/UX (Living Web interactions, HyperCard styling).

---

## 5. Recent Developments (Changelog Summary)

- **Nov 2025**:
    - **Living Web**: Visual I/O ports, Sidebar details, Connection improvements.
    - **Session Processing**: Fixed UUID type mismatch, ensured reliable journal/quest generation.
    - **Planting Guide**: Integrated Frost Dates for precise local advice.
    - **Journal**: Implemented dynamic space-based pagination.
    - **Architecture**: Solidified Dual-Panel state management.

---

## 6. File Inventory Highlights

- **Core Logic**: `lib/green_man_tavern/` (Contexts: `planting_guide.ex`, `sessions.ex`, `ai.ex`).
- **Web Interface**: `lib/green_man_tavern_web/live/` (`dual_panel_live.ex`, `panels/`).
- **Frontend Assets**: `assets/js/hooks/` (`xyflow_editor.js`, `journal_overflow_hook.js`).
- **Documentation**: `notes/documentation/` (Detailed logs, architecture docs).
- **Seeds**: `priv/repo/seeds/` (Data population for plants, cities, frost dates).

---

> **Note to Agents**: When starting a task, always verify the current state of `DualPanelLive` and the relevant Context. Use this summary to understand the "Why" and "How" of the existing system before making changes.
