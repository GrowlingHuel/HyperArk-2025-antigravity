# Migration Fix Notes

## Cities Migration - Foreign Key to Non-Integer Column

**Date:** November 4, 2025  
**Migration:** `20251104224923_create_cities.exs`

### Problem

The original migration attempted to use `references/2` to create a foreign key to a non-integer column:

```elixir
add :koppen_code, 
    references(:koppen_zones, column: :code, type: :string, size: 3, on_delete: :restrict)
```

This doesn't work properly in Ecto because `references/2` is designed primarily for integer foreign keys.

### Solution

Changed to use raw SQL via `execute/2` to create the foreign key constraint:

```elixir
# In the table definition
add :koppen_code, :string, size: 3

# After the table creation
execute(
  "ALTER TABLE cities ADD CONSTRAINT cities_koppen_code_fkey FOREIGN KEY (koppen_code) REFERENCES koppen_zones(code) ON DELETE RESTRICT",
  "ALTER TABLE cities DROP CONSTRAINT cities_koppen_code_fkey"
)
```

### Why This Works

1. **Separation of Concerns**: Column definition is separate from constraint creation
2. **Raw SQL Support**: PostgreSQL natively supports foreign keys to any unique column
3. **Reversible**: The `execute/2` function takes both "up" and "down" SQL for migrations and rollbacks
4. **Explicit Constraint Name**: `cities_koppen_code_fkey` follows PostgreSQL naming conventions

### Migration Structure

The final migration follows this pattern:

```elixir
create table(:cities) do
  # ... all columns including koppen_code as :string
  timestamps()
end

# Foreign key constraint (after table creation)
execute(
  "ALTER TABLE cities ADD CONSTRAINT cities_koppen_code_fkey ...",
  "ALTER TABLE cities DROP CONSTRAINT cities_koppen_code_fkey"
)

# Indexes (after constraints)
create index(:cities, [:city_name])
create index(:cities, [:country])
create index(:cities, [:koppen_code])
```

### Testing

Compilation verified successful with `mix compile --force`

### References

- Ecto Migration docs: https://hexdocs.pm/ecto_sql/Ecto.Migration.html
- PostgreSQL Foreign Key docs: https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK

### Similar Issues in Codebase

No other migrations currently need this fix. The `companion_relationships` table uses standard integer foreign keys.

