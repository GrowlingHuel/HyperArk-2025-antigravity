# Migration Errors Fixed - November 4, 2025

## Problem Summary

When running `mix phx.server`, the application crashed with:
```
ERROR 42P01 (undefined_table) relation "plants" does not exist
```

## Root Cause

**Migration Order Conflict**: Old migrations from November 1st were trying to reference the `plants` table before it was created by newer migrations from November 4th.

Migrations run in **timestamp order**, so:
1. ❌ `20251101091000_create_planting_windows.exs` - tried to reference `plants` (doesn't exist yet)
2. ❌ `20251101091500_create_companions.exs` - tried to reference `plants` (doesn't exist yet)
3. ✅ `20251104224924_create_plants.exs` - creates `plants` table

## Errors Encountered

### 1. watchman: not found
**Severity**: Low (harmless warning)  
**Meaning**: Missing file-watching tool for dev environment  
**Action**: Ignored - not critical

### 2. Phoenix.Ecto.PendingMigrationError
**Severity**: High (blocks app startup)  
**Meaning**: Database has pending migrations that need to run  
**Action**: Fixed by running `mix ecto.migrate`

### 3. ERROR 42P01 (undefined_table)
**Severity**: High (migration failure)  
**Meaning**: Migration trying to reference table that doesn't exist yet  
**Action**: Removed conflicting old migrations

## Actions Taken

### 1. Deleted Conflicting Old Migrations

#### Deleted: `20251101091000_create_planting_windows.exs`
**Reason**: Old design used separate `planting_windows` table. New design stores planting months directly in `plants` table as `planting_months_sh` and `planting_months_nh` fields.

**Old approach:**
```elixir
# Separate table with FK to plants
create table(:planting_windows) do
  add :plant_id, references(:plants)
  add :month, :integer
  add :hemisphere, :string
end
```

**New approach:**
```elixir
# Directly in plants table
field :planting_months_sh, :string  # "Sep-Nov"
field :planting_months_nh, :string  # "Mar-May"
```

#### Deleted: `20251101091500_create_companions.exs`
**Reason**: Old `companions` table replaced by more sophisticated `companion_relationships` table.

**Old approach:**
```elixir
create table(:companions) do
  add :plant_id, references(:plants)
  add :companion_plant_id, references(:plants)
  add :relation, :string  # "good" or "bad"
  add :notes, :text
end
```

**New approach:**
```elixir
create table(:companion_relationships) do
  add :plant_a_id, references(:plants)
  add :plant_b_id, references(:plants)
  add :relationship_type, :string  # "good" or "bad"
  add :evidence_level, :string     # NEW: "scientific", "traditional_strong", etc.
  add :mechanism, :text            # NEW: explains how relationship works
  add :notes, :text
end
```

### 2. Fixed Cities Migration

**Changed**: Foreign key to non-integer column (Köppen code)

**From:**
```elixir
add :koppen_code, references(:koppen_zones, column: :code, type: :string)
```

**To:**
```elixir
add :koppen_code, :string, size: 3

# Then separately:
execute(
  "ALTER TABLE cities ADD CONSTRAINT cities_koppen_code_fkey FOREIGN KEY (koppen_code) REFERENCES koppen_zones(code) ON DELETE RESTRICT"
)
```

### 3. Added family_id to Plants Migration

**Added** to support Plant ↔ PlantFamily relationship:
```elixir
add :family_id, references(:plant_families, on_delete: :nilify_all)

# And index:
create index(:plants, [:family_id])
```

### 4. Fixed Plant Schema Association

**Added** to `/lib/green_man_tavern/planting_guide/plant.ex`:
```elixir
# Alias
alias GreenManTavern.PlantingGuide.PlantFamily

# Field
field :family_id, :id

# Association
belongs_to :family, PlantFamily, define_field: false
```

## Final Migration Order

✅ **All migrations now run successfully in this order:**

1. `20251101090000` - create_plant_families
2. `20251101204252` - create_journal_entries  
3. `20251102172508` - create_knowledge_terms
4. `20251104224922` - create_koppen_zones
5. `20251104224923` - create_cities (references koppen_zones)
6. `20251104224924` - create_plants (references plant_families)
7. `20251104224925` - create_companion_relationships (references plants)

## Verification

### Migration Output
```
[info] == Migrated 20251104224922 in 0.0s  ✅ koppen_zones
[info] == Migrated 20251104224923 in 0.0s  ✅ cities
[info] == Migrated 20251104224924 in 0.0s  ✅ plants
[info] == Migrated 20251104224925 in 0.0s  ✅ companion_relationships
```

### Database Tables Created
- ✅ `koppen_zones` - Köppen climate classification
- ✅ `cities` - Cities with climate zones and hemispheres
- ✅ `plants` - Plant species with growing data
- ✅ `plant_families` - Botanical families (from Nov 1)
- ✅ `companion_relationships` - Companion planting evidence

### Foreign Keys Working
- ✅ `cities.koppen_code` → `koppen_zones.code` (string FK)
- ✅ `plants.family_id` → `plant_families.id` (integer FK)
- ✅ `companion_relationships.plant_a_id` → `plants.id`
- ✅ `companion_relationships.plant_b_id` → `plants.id`

## Next Steps

1. ✅ Migrations fixed and run successfully
2. 📝 Ready to seed database: `mix run priv/repo/seeds/planting_guide.exs`
3. 🚀 Ready to start server: `mix phx.server`

## Lessons Learned

1. **Always delete obsolete migrations** before running new ones
2. **Check migration timestamps** - older dates run first
3. **Foreign keys to non-integer columns** require raw SQL via `execute/2`
4. **Schema associations must match database columns** - if schema has `family_id`, migration must create it

## Files Modified

- ✅ Deleted: `priv/repo/migrations/20251101091000_create_planting_windows.exs`
- ✅ Deleted: `priv/repo/migrations/20251101091500_create_companions.exs`
- ✅ Modified: `priv/repo/migrations/20251104224923_create_cities.exs`
- ✅ Modified: `priv/repo/migrations/20251104224924_create_plants.exs`
- ✅ Modified: `lib/green_man_tavern/planting_guide/plant.ex`

## Status

🎉 **ALL ISSUES RESOLVED** - Database ready for seeding!

