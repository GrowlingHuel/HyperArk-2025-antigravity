# Adding New Panels to Green Man Tavern

## Core Architecture Principle

**Green Man Tavern uses a dual-panel layout:**
- **LEFT PANEL:** Always shows the tavern scene (or selected character)
- **RIGHT PANEL:** Shows different page content based on navigation

**The pattern is extremely simple** - no complex state management, just basic routing.

---

## The 4-Step Pattern

Every new panel follows this exact same pattern:

### **Step 1: Add Route**

**File:** `lib/green_man_tavern_web/router.ex`

**Pattern:**
```elixir
scope "/", GreenManTavernWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  live "/", DualPanelLive, :home
  live "/living-web", DualPanelLive, :living_web
  live "/inventory", DualPanelLive, :inventory  # ← Add your route here
end
```

**Format:** `live "/url-path", DualPanelLive, :action_atom`

---

### **Step 2: Add Banner Menu Item**

**File:** `lib/green_man_tavern_web/components/banner_menu_component.ex`

**Pattern:**
```elixir
@menu_items [
  %{label: "HyperArk", path: "/", icon: "home"},
  %{label: "Living Web", path: "/living-web", icon: "network"},
  %{label: "Inventory", path: "/inventory", icon: "package"},  # ← Add your menu item here
  # ... more items
]
```

**Format:** `%{label: "Display Name", path: "/url-path", icon: "lucide-icon-name"}`

---

### **Step 3: Add Template Case to Right Panel**

**File:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex`

**Find the right panel section:**
```heex
<%= case @right_panel_action do %>
  <% :home -> %>
    [home content]
  
  <% :living_web -> %>
    [living web content]
  
  <% :inventory -> %>  <!-- ← Add your case here -->
    <div class="p-4">
      <h2 class="text-xl font-bold mb-4">Your Panel Title</h2>
      
      <!-- Your panel content goes here -->
      <p>Panel content...</p>
    </div>
  
  <% _ -> %>
    [catch-all]
<% end %>
```

**Key Points:**
- Use the same `:action_atom` from Step 1
- Wrap content in a container div
- Use HyperCard aesthetic (black borders, greyscale, Monaco font)
- **ONLY put content for the RIGHT panel** - left panel stays as tavern automatically

---

### **Step 4: (Optional) Add Data Loading**

If your panel needs database data, modify `handle_params` in `DualPanelLive`:

**File:** `lib/green_man_tavern_web/live/dual_panel_live.ex`

**Current pattern (minimal - just sets action):**
```elixir
def handle_params(_params, _url, socket) do
  action = socket.assigns.live_action || :home
  socket =
    socket
    |> assign(:right_panel_action, action)
    |> assign(:page_title, page_title(action))
  {:noreply, socket}
end
```

**If you need data, add a case statement:**
```elixir
def handle_params(_params, _url, socket) do
  action = socket.assigns.live_action || :home
  
  socket = case action do
    :inventory ->
      # Load inventory-specific data
      items = MyApp.Inventory.list_items(socket.assigns.current_user.id)
      socket
      |> assign(:inventory_items, items)
      |> assign(:right_panel_action, action)
    
    _ ->
      # Default behavior for all other pages
      socket
      |> assign(:right_panel_action, action)
  end
  
  socket = assign(socket, :page_title, page_title(action))
  {:noreply, socket}
end
```

**Important:** Always set `:right_panel_action` to the action atom. This is what the template checks.

---

## Complete Example: Adding a "Resources" Panel

### Step 1: Router
```elixir
live "/resources", DualPanelLive, :resources
```

### Step 2: Banner Menu
```elixir
%{label: "Resources", path: "/resources", icon: "book-open"}
```

### Step 3: Template
```heex
<% :resources -> %>
  <div class="p-4">
    <h2 class="text-xl font-bold font-mono mb-4">📚 Resources</h2>
    
    <div class="space-y-4">
      <%= for resource <- @resources do %>
        <div class="border-2 border-black p-3 bg-white">
          <h3 class="font-mono font-bold"><%= resource.title %></h3>
          <p class="font-mono text-sm text-gray-600"><%= resource.description %></p>
        </div>
      <% end %>
    </div>
  </div>
```

### Step 4: Data Loading (if needed)
```elixir
:resources ->
  resources = MyApp.Resources.list_all()
  socket
  |> assign(:resources, resources)
  |> assign(:right_panel_action, :resources)
```

---

## Critical Rules

### ✅ DO:
- Use the exact same `:action_atom` in all 3 places (route, template case, assign)
- Keep content simple and in the right panel only
- Follow the HyperCard aesthetic (black borders, greyscale, Monaco font)
- Test navigation between all pages after adding

### ❌ DON'T:
- Set `:left_panel_content` - it stays as tavern automatically
- Create standalone LiveView modules for new pages
- Use `:right_panel_content` - use `:right_panel_action` only
- Modify handle_params unless you need data loading
- Break the existing pattern - copy what works

---

## Testing Checklist

After adding a new panel:

```bash
# 1. Compile
mix compile

# 2. Check routes
mix phx.routes | grep your-panel-name

# 3. Start server
mix phx.server

# 4. Test navigation
✓ Click your new menu item
✓ Verify left panel shows tavern
✓ Verify right panel shows your content
✓ Click other menu items to verify you didn't break them
✓ Navigate back to your panel
✓ Check browser console for errors
```

---

## Common Issues

### Issue: "My panel doesn't show up"
- Check that `:action_atom` matches in all 3 places exactly
- Verify route is in the authenticated scope
- Check for typos in the template case statement

### Issue: "My panel shows but other panels are broken"
- You probably modified `:left_panel_content` - remove that
- Check that you didn't accidentally remove existing template cases
- Verify handle_params still has the default behavior for other actions

### Issue: "Navigation doesn't work"
- Check router - route might not be in authenticated scope
- Verify banner menu path matches the route path exactly
- Check browser console for JavaScript errors

---

## File Reference

Quick links to the 3 files you'll modify:

1. **Router:** `lib/green_man_tavern_web/router.ex`
2. **Banner Menu:** `lib/green_man_tavern_web/components/banner_menu_component.ex`
3. **Template:** `lib/green_man_tavern_web/live/dual_panel_live.html.heex`
4. **LiveView (optional):** `lib/green_man_tavern_web/live/dual_panel_live.ex`

---

## Summary: The Simplest Possible Pattern

```
1. Route:   live "/my-page", DualPanelLive, :my_page
2. Menu:    %{label: "My Page", path: "/my-page", icon: "icon"}
3. Template: <% :my_page -> %> [your HTML]
4. (Optional) Data: Add case to handle_params
```

That's it. Four simple steps. No magic, no complexity.

The dual-panel architecture handles everything else automatically:
- Left panel stays as tavern
- Right panel shows your content
- Navigation works
- State is managed

**Just follow this pattern and you can't go wrong.**
