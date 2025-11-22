# Troubleshooting Guide: Common Development Issues

## Issue #1: Cursor AI Agent Context Overload

### **Symptoms:**
- Cursor says it completed a task but nothing changed
- Cursor becomes unresponsive or slow
- Changes appear in some files but not others
- "Chat context summarized" message with no option to read it

### **Root Cause:**
Cursor's AI agent accumulates too much context over time (file history, conversation, diffs) and hits internal limits. This causes silent failures where it believes it completed work but didn't actually execute the changes.

### **Solution:**
**Start a new Cursor Agent periodically** (every 5-10 significant changes or when you notice issues):

1. In Cursor, look for agent/conversation management
2. Create a new agent/conversation
3. Continue working with fresh context

**Prevention:**
- Start fresh agent before major feature work
- Reset after completing a significant milestone
- Watch for slowdowns or unusual behavior as warning signs

---

## Issue #2: LiveView Event Handlers Not Executing

### **Symptoms:**
```elixir
** (FunctionClauseError) no function clause matching in handle_event/3
```
- Button clicks do nothing
- Events fire (see in terminal logs) but crash
- "No function clause matching" errors

### **Root Cause:**
Event handler functions were never added to the LiveView module, or were added in the wrong location/format.

### **Diagnosis:**
```bash
# Check if handler exists
grep -n "def handle_event(\"your_event_name\"" lib/path/to/live_view.ex

# If returns nothing → handler is missing
# If returns line number → handler exists, check signature
```

### **Solution:**
Add the missing handler function:

```elixir
@impl true
def handle_event("event_name", params, socket) do
  # Your logic here
  {:noreply, socket}
end
```

**Critical details:**
- Must have `@impl true` decorator
- Must match exact event name from template
- Must have 3 parameters: `(event_name, params, socket)`
- Must return `{:noreply, socket}` or `{:noreply, socket, options}`

---

## Issue #3: Template KeyError for Missing Assigns

### **Symptoms:**
```elixir
** (KeyError) key :show_inventory_add_form not found in: %{...}
```
- Page crashes on load
- Template references `@some_assign` that doesn't exist
- Error shows large map of existing assigns

### **Root Cause:**
Template tries to access an assign (like `@show_inventory_add_form`) before it's initialized in the LiveView.

### **Diagnosis:**
Look at the error - it shows which key is missing and lists all available keys.

### **Solution:**

**Option 1: Initialize in `mount/3`** (recommended for always-needed assigns):
```elixir
def mount(_params, _session, socket) do
  socket = socket
  |> assign(:show_inventory_add_form, false)
  |> assign(:selected_item, nil)
  # ... other assigns
  
  {:ok, socket}
end
```

**Option 2: Initialize in `handle_params/3`** (for route-specific assigns):
```elixir
def handle_params(params, _url, socket) do
  socket = case socket.assigns.live_action do
    :inventory ->
      socket
      |> assign(:show_inventory_add_form, false)
      |> assign(:inventory_items, [])
    
    _ ->
      socket
  end
  
  {:noreply, socket}
end
```

**Option 3: Safe access in template** (temporary fix):
```elixir
# Instead of:
<%= if @show_form do %>

# Use:
<%= if Map.get(assigns, :show_form, false) do %>
```

---

## Issue #4: Database Migration Already Exists

### **Symptoms:**
```
** (Postgrex.Error) ERROR 42P07 (duplicate_table) relation "table_name" already exists
```
- Migration fails
- Tables exist from manual testing in IEx
- `mix ecto.migrate` crashes

### **Root Cause:**
Table was created manually (via IEx testing) or migration was partially run before.

### **Solution:**
Mark migration as complete without running it:

```bash
# Connect to database
psql your_database_name

# Insert migration record manually
INSERT INTO schema_migrations (version, inserted_at) 
VALUES (20251120082607, NOW());

# Exit
\q
```

Or in IEx:
```elixir
Repo.query!("INSERT INTO schema_migrations (version, inserted_at) VALUES (20251120082607, NOW())")
```

**Verify:**
```bash
mix ecto.migrations
# All should show "up"
```

---

## Issue #5: Template Changes Not Visible

### **Symptoms:**
- Changed template code
- Server shows "compiled successfully"
- Browser shows old version
- Phoenix says "live reload triggered"

### **Root Cause:**
Browser cache or LiveView not detecting changes.

### **Solutions:**

**1. Hard refresh browser:**
- Chrome/Firefox: `Ctrl + Shift + R`
- Mac: `Cmd + Shift + R`

**2. Clear browser cache:**
```
F12 → Application/Storage → Clear site data
```

**3. Restart Phoenix server:**
```bash
# Kill server (Ctrl+C)
mix phx.server
```

**4. Check file was actually saved:**
```bash
# View the file to confirm changes
cat lib/path/to/template.html.heex | grep "your change"
```

---

## Issue #6: Functions Not Found Despite Being Added

### **Symptoms:**
```
** (UndefinedFunctionError) function Module.function_name/arity is undefined
```
- Code editor shows function exists
- Compilation says it succeeded
- Runtime says function doesn't exist

### **Root Cause:**
- Function added to wrong module
- Typo in function name
- Wrong arity (number of parameters)
- Module not properly compiled

### **Diagnosis:**
```bash
# Search for function definition
grep -rn "def function_name" lib/

# Check if module is compiled
iex -S mix
> Module.function_exported?(YourModule, :function_name, 2)
```

### **Solution:**

**1. Recompile everything:**
```bash
mix clean
mix compile
```

**2. Verify function location:**
```elixir
# Make sure function is in correct module
defmodule GreenManTavern.Inventory do
  def create_inventory_item(attrs) do
    # ...
  end
end

# Called as:
Inventory.create_inventory_item(params)
```

**3. Check arity matches:**
```elixir
# Definition:
def my_function(param1, param2), do: ...

# Call must have 2 arguments:
my_function(arg1, arg2)
```

---

## Issue #7: Modal/Form Not Appearing Despite No Errors

### **Symptoms:**
- Button click event fires
- No errors in terminal or browser console
- Modal/form doesn't appear
- Assign is set correctly (can verify in logs)

### **Root Cause:**
Template conditional checking wrong assign or modal HTML is missing from template.

### **Diagnosis:**

**1. Check if assign is being set:**
Add logging to handler:
```elixir
def handle_event("show_form", _, socket) do
  IO.inspect(socket.assigns.show_form, label: "BEFORE")
  socket = assign(socket, :show_form, true)
  IO.inspect(socket.assigns.show_form, label: "AFTER")
  {:noreply, socket}
end
```

**2. Check template has the modal HTML:**
```bash
grep -n "show_form" lib/path/to/template.html.heex
```

### **Solution:**

**If assign is correct but modal missing:**
Add modal HTML to template:
```heex
<%= if @show_form do %>
  <div class="modal">
    <!-- form content -->
  </div>
<% end %>
```

**If modal exists but doesn't appear:**
- Check CSS (display: none? z-index issue?)
- Verify conditional uses correct assign name
- Ensure modal is in correct location in template (not nested wrong)

---

## Prevention Checklist

Before starting new feature work:

- [ ] Start fresh Cursor Agent
- [ ] Commit current working code
- [ ] Run `mix compile` to ensure clean state
- [ ] Run `mix test` if you have tests
- [ ] Plan which files need changes
- [ ] Have terminal visible to see errors immediately

After making changes:

- [ ] Check `mix compile` shows no warnings/errors
- [ ] Hard refresh browser
- [ ] Check terminal for runtime errors
- [ ] Verify changes in browser
- [ ] Commit working changes

---

## Quick Reference Commands

```bash
# Check if function exists
grep -n "def function_name" lib/**/*.ex

# Check if event handler exists
grep -n "handle_event.*event_name" lib/**/*.ex

# View migration status
mix ecto.migrations

# Recompile everything
mix clean && mix compile

# Check what's running
ps aux | grep beam

# View recent git changes
git diff

# Undo all uncommitted changes
git checkout .

# Check current branch and status
git status
```

---

## When All Else Fails

1. **Stop the server** (Ctrl+C)
2. **Revert to last working commit:**
   ```bash
   git stash
   # Or
   git checkout .
   ```
3. **Clean and recompile:**
   ```bash
   mix clean
   mix deps.get
   mix compile
   ```
4. **Restart from working state**
5. **Make changes incrementally** (one small change, test, commit, repeat)

---

## Summary

Most issues fall into these categories:

1. **Cursor context overload** → Reset agent
2. **Missing code** → Verify with grep, add manually if needed
3. **Missing assigns** → Initialize in mount/handle_params
4. **Cache issues** → Hard refresh browser
5. **Wrong module/location** → Double-check file paths

**Golden Rule:** After any Cursor operation that "completes" with no visible change, immediately verify with `grep` or by opening the file manually.
