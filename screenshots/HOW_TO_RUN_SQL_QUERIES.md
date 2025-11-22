# How to Check the Database Using SQL

This guide shows you how to run SQL queries against your PostgreSQL database.

## Database Connection Info

From your config, your database settings are:
- **Database**: `green_man_tavern_dev`
- **Username**: `jesse`
- **Password**: `jesse` (or from `DATABASE_PASSWORD` environment variable)
- **Host**: `localhost`
- **Port**: `5432` (PostgreSQL default)

## Method 1: Using psql (Command Line)

### Connect to the Database

```bash
psql -U jesse -d green_man_tavern_dev -h localhost
```

When prompted, enter your password: `jesse`

### Alternative: Connect with Password in Command

```bash
PGPASSWORD=jesse psql -U jesse -d green_man_tavern_dev -h localhost
```

### Run a Single Query

```bash
psql -U jesse -d green_man_tavern_dev -h localhost -c "SELECT COUNT(*) FROM users;"
```

### Run Queries from a File

```bash
psql -U jesse -d green_man_tavern_dev -h localhost -f verification_queries.sql
```

Or with password:
```bash
PGPASSWORD=jesse psql -U jesse -d green_man_tavern_dev -h localhost -f verification_queries.sql
```

### Interactive psql Session

1. Connect:
   ```bash
   psql -U jesse -d green_man_tavern_dev -h localhost
   ```

2. Once connected, you can run queries directly:
   ```sql
   SELECT id, email FROM users LIMIT 5;
   ```

3. To exit, type: `\q` or press `Ctrl+D`

### Useful psql Commands

- `\dt` - List all tables
- `\d table_name` - Describe a table structure
- `\q` - Quit psql
- `\?` - Show help
- `\l` - List all databases
- `\c database_name` - Connect to a different database

## Method 2: Using IEx (Elixir Interactive Shell)

### Start IEx with Mix

```bash
iex -S mix
```

### Run Queries Using Ecto

```elixir
alias GreenManTavern.Repo
import Ecto.Query

# Example: Get user count
Repo.aggregate(from(u in "users"), :count)

# Example: Get all users
Repo.all(from(u in "users", select: [:id, :email]))

# Example: Get conversation history for a user
user_id = 1
Repo.all(
  from(ch in "conversation_history",
    where: ch.user_id == ^user_id,
    order_by: [desc: ch.inserted_at],
    limit: 10
  )
)
```

### Run Raw SQL in IEx

```elixir
alias GreenManTavern.Repo

# Run a raw SQL query
Repo.query!("SELECT id, email FROM users LIMIT 5")

# With parameters
user_id = 1
Repo.query!("SELECT * FROM conversation_history WHERE user_id = $1", [user_id])
```

## Method 3: Using the Verification Queries File

### Step 1: Get Your Test User ID

**Option A: Using psql**
```bash
psql -U jesse -d green_man_tavern_dev -h localhost -c "SELECT id, email FROM users LIMIT 5;"
```

**Option B: Using IEx**
```elixir
alias GreenManTavern.Repo
Repo.query!("SELECT id, email FROM users LIMIT 5")
```

### Step 2: Get Session ID (if testing)

**Option A: Using psql**
```bash
psql -U jesse -d green_man_tavern_dev -h localhost -c "SELECT DISTINCT session_id FROM conversation_history WHERE session_id IS NOT NULL ORDER BY session_id DESC LIMIT 5;"
```

**Option B: Using IEx**
```elixir
alias GreenManTavern.Repo
Repo.query!("SELECT DISTINCT session_id FROM conversation_history WHERE session_id IS NOT NULL ORDER BY session_id DESC LIMIT 5")
```

### Step 3: Replace Placeholders in SQL File

Open `verification_queries.sql` and replace:
- `[TEST_USER_ID]` with your actual user ID (e.g., `1`)
- `[SESSION_ID]` with your actual session ID (e.g., `'550e8400-e29b-41d4-a716-446655440000'`)

**Example:**
```sql
-- Before:
WHERE user_id = [TEST_USER_ID]

-- After:
WHERE user_id = 1
```

### Step 4: Run the Queries

**Option A: Run entire file**
```bash
PGPASSWORD=jesse psql -U jesse -d green_man_tavern_dev -h localhost -f verification_queries.sql
```

**Option B: Copy-paste individual queries into psql**
1. Connect to psql
2. Copy a query from `verification_queries.sql`
3. Replace placeholders
4. Paste and press Enter

## Method 4: Quick Verification Queries

Here are some ready-to-use queries (replace `1` with your user ID):

### Check if messages have session_id
```sql
SELECT id, session_id, message_type, LEFT(message_content, 50) as content_preview
FROM conversation_history 
WHERE user_id = 1
ORDER BY inserted_at DESC 
LIMIT 10;
```

### Check for session summary (CRITICAL)
```sql
SELECT id, session_id, session_summary, inserted_at
FROM conversation_history 
WHERE user_id = 1 
AND session_summary IS NOT NULL
ORDER BY inserted_at DESC 
LIMIT 5;
```

### Check generated quests
```sql
SELECT 
    uq.id,
    q.title,
    uq.status,
    uq.required_skills,
    uq.calculated_difficulty
FROM user_quests uq
JOIN quests q ON uq.quest_id = q.id
WHERE uq.user_id = 1
ORDER BY uq.inserted_at DESC 
LIMIT 3;
```

### Check journal entries
```sql
SELECT id, title, LEFT(body, 200) as body_preview, inserted_at
FROM journal_entries 
WHERE user_id = 1
ORDER BY inserted_at DESC 
LIMIT 5;
```

## Method 5: Using a Database GUI Tool

If you prefer a graphical interface, you can use:

- **pgAdmin** - Official PostgreSQL GUI
- **DBeaver** - Universal database tool
- **TablePlus** - Modern database client
- **DataGrip** - JetBrains database IDE

Connection settings:
- Host: `localhost`
- Port: `5432`
- Database: `green_man_tavern_dev`
- Username: `jesse`
- Password: `jesse`

## Troubleshooting

### "password authentication failed"
- Check that your password is correct
- Try using the `PGPASSWORD` environment variable

### "database does not exist"
- Make sure the database name is `green_man_tavern_dev`
- Run `mix ecto.create` if the database doesn't exist

### "connection refused"
- Make sure PostgreSQL is running: `sudo systemctl status postgresql`
- Check that PostgreSQL is listening on localhost: `sudo netstat -tlnp | grep 5432`

### "relation does not exist"
- Run migrations: `mix ecto.migrate`
- Check table names are correct (they might be pluralized differently)

## Quick Reference: Common Queries

### Count records
```sql
SELECT COUNT(*) FROM conversation_history WHERE user_id = 1;
```

### Find latest session
```sql
SELECT session_id, COUNT(*) as message_count
FROM conversation_history
WHERE user_id = 1 AND session_id IS NOT NULL
GROUP BY session_id
ORDER BY MAX(inserted_at) DESC
LIMIT 1;
```

### Check all messages in a session
```sql
SELECT id, message_type, message_content, inserted_at
FROM conversation_history
WHERE session_id = 'your-session-id-here'
ORDER BY inserted_at ASC;
```

### Find user by email
```sql
SELECT id, email FROM users WHERE email = 'test@example.com';
```


