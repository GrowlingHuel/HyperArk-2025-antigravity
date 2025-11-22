# 🚀 QUICK START GUIDE - Living Web Planting Database

**Goal**: Get your climate-aware planting guide running in under 2 hours!

---

## 📋 STEP-BY-STEP IMPLEMENTATION

### STEP 1: Organize Your Files (5 minutes)

1. **Create data directory in your Phoenix project:**
   ```bash
   mkdir -p priv/repo/seeds/data
   ```

2. **Copy CSV files from the outputs folder:**
   ```bash
   # Copy these 4 files to priv/repo/seeds/data/
   - koppen_climate_zones.csv
   - world_cities_climate_zones.csv
   - plants_database_500.csv
   - companion_planting_relationships.csv
   ```

3. **Keep summary docs handy:**
   - DATA_PACKAGE_SUMMARY.md (reference guide)
   - CURSOR_PROMPTS_PLANTING_GUIDE.md (implementation prompts)

---

### STEP 2: Run Cursor Prompts (30-45 minutes)

Open Cursor.AI and paste prompts **one at a time** from CURSOR_PROMPTS_PLANTING_GUIDE.md:

#### 2a. Create Migrations
- ✅ Paste **PROMPT 1** into Cursor
- Wait for Cursor to generate 4 migration files
- Check: Files created in `priv/repo/migrations/`

#### 2b. Create Schemas
- ✅ Paste **PROMPT 2** into Cursor
- Wait for Cursor to generate 4 schema files
- Check: Files created in `lib/green_man_tavern/planting_guide/`

#### 2c. Create Context Module
- ✅ Paste **PROMPT 3** into Cursor
- Wait for Cursor to generate `planting_guide.ex`
- Check: File created in `lib/green_man_tavern/`

#### 2d. Create Seeds File
- ✅ Paste **PROMPT 4** into Cursor
- Wait for Cursor to generate seed file
- Check: File created in `priv/repo/seeds/`
- **IMPORTANT**: Make sure CSV paths point to correct location!

#### 2e. Update LiveView Logic
- ✅ Paste **PROMPT 5** into Cursor
- Wait for Cursor to update `dual_panel_live.ex`
- Check: Mount function and event handlers added

#### 2f. Update LiveView Template
- ✅ Paste **PROMPT 6** into Cursor
- Wait for Cursor to update `dual_panel_live.html.heex`
- Check: Planting guide UI added to right panel

---

### STEP 3: Run Migrations (2 minutes)

```bash
# Run migrations to create tables
mix ecto.migrate

# You should see output like:
# [info] == Running [...].CreateKoppenZones.change/0 forward
# [info] == Running [...].CreateCities.change/0 forward
# [info] == Running [...].CreatePlants.change/0 forward
# [info] == Running [...].CreateCompanionRelationships.change/0 forward
```

**Troubleshooting:**
- If migration fails, check for typos in migration files
- If "already exists" error, table might be partially created - check with `\d` in psql

---

### STEP 4: Seed Database (5-10 minutes)

```bash
# Run the seed file
mix run priv/repo/seeds/planting_guide.exs

# You should see output like:
# Seeding Köppen zones...
# Seeding cities...
# Seeding plants...
# Seeding companion relationships...
# ✅ Planting guide database seeded successfully!
```

**Expected data counts:**
- Köppen zones: 31
- Cities: 164
- Plants: 500
- Companion relationships: 210+

**Troubleshooting:**
- If CSV parsing fails, check file encoding (should be UTF-8)
- If foreign key error, check order of seeding (Köppen → Cities → Plants → Companions)
- If duplicate error, seeds might have run twice - check if records exist first

---

### STEP 5: Verify Data (5 minutes)

```elixir
# Start IEx
iex -S mix

# Check data counts
alias GreenManTavern.PlantingGuide

# Should return 31
PlantingGuide.list_koppen_zones() |> length()

# Should return 164
PlantingGuide.list_cities() |> length()

# Should return 500
PlantingGuide.list_plants() |> length()

# Test specific queries
PlantingGuide.get_cities_by_koppen("Cfb") # Melbourne, Sydney climate
PlantingGuide.list_plants(%{climate_zone: "Cfb"}) # Plants for this zone
PlantingGuide.get_companions(1, "good") # Good companions for first plant
```

**All working? Proceed!** ✅

---

### STEP 6: Test in Browser (10 minutes)

1. **Start Phoenix server:**
   ```bash
   mix phx.server
   ```

2. **Navigate to Planting Guide:**
   - Click "Garden" in banner menu (or whatever triggers `:planting_guide` right panel)

3. **Test filters:**
   - ✅ Select city (e.g., "Melbourne, Australia")
   - ✅ Select month (e.g., "Sep")
   - ✅ Select plant type (e.g., "Vegetable")
   - ✅ Select difficulty (e.g., "Easy")
   - ✅ See filtered plants update in real-time

4. **Test plant details:**
   - ✅ Click on a plant card (e.g., "Tomato")
   - ✅ Modal opens with full details
   - ✅ See good companions (Basil, Carrots, Marigold, etc.)
   - ✅ See bad companions (Brassicas, Fennel, Potato)
   - ✅ Evidence levels shown (scientific, traditional_strong, etc.)
   - ✅ Close modal with X button

---

## 🎉 SUCCESS CRITERIA

Your planting guide is working if:

✅ **City selector** shows 164 cities with Köppen codes
✅ **Month filter** updates plant list correctly
✅ **Plant cards** display: name, type, difficulty, harvest time
✅ **Plant details modal** opens with full information
✅ **Companions section** shows good/bad companions with evidence levels
✅ **Filtering works** - selecting city + month shows only compatible + seasonal plants

---

## 🐛 COMMON ISSUES & FIXES

### Issue: "No plants showing after selecting city"
**Fix**: Check that city's Köppen code matches plants' climate_zones array. Try:
```elixir
city = PlantingGuide.get_city!(1)
plants = PlantingGuide.list_plants(%{climate_zone: city.koppen_code})
IO.inspect(length(plants))
```

### Issue: "Companion relationships not displaying"
**Fix**: Check that plant names in CSV exactly match. Run:
```elixir
plant = PlantingGuide.get_plant!(1)
companions = PlantingGuide.get_companions(plant.id)
IO.inspect(companions)
```

### Issue: "Month filter not working"
**Fix**: Check hemisphere logic in filter function. Verify:
```elixir
city = PlantingGuide.get_city!(1) # Melbourne
IO.inspect(city.hemisphere) # Should be "Southern"
plant = PlantingGuide.get_plant!(1)
IO.inspect(plant.planting_months_sh) # Should contain months
```

### Issue: "Seeds fail with foreign key error"
**Fix**: Ensure seeds run in order:
1. Köppen zones first (no dependencies)
2. Cities second (depend on Köppen zones)
3. Plants third (no dependencies)
4. Companions last (depend on plants)

---

## 📊 WHAT YOU'VE BUILT

🎯 **A fully functional, climate-aware planting guide with:**

- ✅ 31 Köppen climate zones covering all major world climates
- ✅ 164 cities (all major capitals + Australian states + US states)
- ✅ 500 plants with comprehensive growing data
- ✅ 210+ companion relationships with evidence tiers
- ✅ Hemisphere-aware planting windows
- ✅ Real-time filtering by location, month, type, difficulty
- ✅ Evidence-based companion planting recommendations

**User can now:**
1. Select their city
2. See which plants grow in their climate
3. Filter by planting month (current season)
4. View detailed plant information
5. See which plants work well together (and which don't)
6. Make informed planting decisions based on science + tradition

---

## 🔮 NEXT FEATURES TO ADD

### Priority 1 (This week):
- [ ] Search bar (filter plants by name)
- [ ] "My Garden" (save favorite plants to user account)
- [ ] Export plant list (CSV/PDF of filtered results)

### Priority 2 (Next 2 weeks):
- [ ] Frost date calculator (add frost date data to cities)
- [ ] Precise planting date recommendations
- [ ] Plant photos (add image URLs to plants table)

### Priority 3 (Next month):
- [ ] User contributions (crowdsource planting times)
- [ ] Plant progress tracking ("I planted tomatoes on...")
- [ ] Harvest reminders (based on days_to_harvest)
- [ ] Quest integration (plant 3 companions together)

### Priority 4 (Future):
- [ ] Weather API integration (frost warnings)
- [ ] Mobile app (planting reminders)
- [ ] AI plant identification (photo upload)
- [ ] Community sharing (share your garden layout)

---

## 📚 RESOURCES

### Data Source Attribution:
- Köppen climate data: Based on standard climate classification system
- City climate zones: Derived from NOAA, BoM, and meteorological databases
- Plant data: Compiled from USDA Plants Database, permaculture references, and seed catalogs
- Companion data: Based on scientific literature + traditional gardening wisdom

### Further Reading:
- Köppen Climate Classification: [Wikipedia](https://en.wikipedia.org/wiki/K%C3%B6ppen_climate_classification)
- Companion Planting Research: Academic journals on allelopathy
- Australian Native Plants: [Australian Native Plants Society](https://anpsa.org.au/)
- Permaculture Design: *Gaia's Garden* by Toby Hemenway

---

## 🙌 YOU DID IT!

You now have a production-ready planting guide with:
- ✅ Climate-aware recommendations
- ✅ Seasonal planting windows
- ✅ Evidence-based companion planting
- ✅ Native plant database
- ✅ Global city coverage

**Time to test with real users and iterate!** 🌱

---

**Document Version**: 1.0
**Last Updated**: November 4, 2025
**Total Implementation Time**: ~2 hours (from scratch to running app)

Got questions? Check DATA_PACKAGE_SUMMARY.md for detailed data explanations!
