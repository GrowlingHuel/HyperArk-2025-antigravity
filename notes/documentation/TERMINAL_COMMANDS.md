

# Green Man Tavern - Terminal Commands Cheat Sheet


most common: 


# Start work
git status                           # Check where you are
mix phx.server                       # Start server

# Test database
psql -d green_man_tavern_dev        # Access DB
\dt                                  # List tables
SELECT * FROM user_quests LIMIT 5;  # Quick query
\q                                   # Exit

# Save work
git add .
git commit -m "feat: Your changes"
git push




## Git Commands

### Branching & Commits
- Create and switch to new branch: `git checkout -b feature/your-feature-name`
- Check current branch: `git branch`
- Check status: `git status`
- Stage all changes: `git add .`
- Commit: `git commit -m "feat: Your commit message"`
- Push branch: `git push -u origin feature/your-feature-name`
- Switch branches: `git checkout branch-name`
- Merge branch into main: `git checkout main && git merge feature/your-feature-name`
- Delete branch: `git branch -d feature/your-feature-name`

### Viewing History
- View commit history: `git log --oneline`
- View changes: `git diff`
- View specific file history: `git log --follow filename`

## Phoenix/Elixir Commands

### Server Management
- Start server: `mix phx.server`
- Start interactive shell with server: `iex -S mix phx.server`
- Start interactive shell: `iex -S mix`
- Stop server: `Ctrl+C` twice

### Database Commands
- Create database: `mix ecto.create`
- Run migrations: `mix ecto.migrate`
- Rollback last migration: `mix ecto.rollback`
- Rollback specific number: `mix ecto.rollback --step 3`
- Reset database (drop, create, migrate): `mix ecto.reset`
- Drop database: `mix ecto.drop`
- Check migration status: `mix ecto.migrations`
- Generate new migration: `mix ecto.gen.migration add_field_to_table`

### Code Management
- Compile code: `mix compile`
- Clean build: `mix clean`
- Run tests: `mix test`
- Run specific test file: `mix test test/path/to/test_file.exs`
- Format code: `mix format`
- Check for issues: `mix credo` (if installed)

## PostgreSQL Commands

### Accessing Database
- Connect to dev database: `psql -d green_man_tavern_dev`
- Connect with specific user: `psql -U postgres -d green_man_tavern_dev`
- Connect to test database: `psql -d green_man_tavern_test`

### Inside psql
- List databases: `\l`
- Connect to database: `\c database_name`
- List tables: `\dt`
- Describe table: `\d table_name`
- Describe table with details: `\d+ table_name`
- List all schemas: `\dn`
- Quit psql: `\q`
- Execute SQL file: `\i /path/to/file.sql`
- Toggle expanded display: `\x`
- Show query history: `\s`

### Common SQL Queries for Testing

#### View Recent Conversations
```sql
SELECT id, user_id, character_id, session_id, 
       LEFT(message_content, 50) as preview,
       inserted_at
FROM conversation_history 
ORDER BY inserted_at DESC 
LIMIT 10;
```

#### Check Session Summaries
```sql
SELECT DISTINCT session_id, session_summary,
       COUNT(*) as message_count
FROM conversation_history 
WHERE session_summary IS NOT NULL
GROUP BY session_id, session_summary
ORDER BY MAX(inserted_at) DESC;
```

#### View Journal Entries
```sql
SELECT j.id, j.title, 
       LEFT(j.body, 80) as body_preview,
       j.conversation_session_id,
       c.name as character_name,
       j.inserted_at
FROM journal_entries j
LEFT JOIN conversation_history ch ON ch.session_id = j.conversation_session_id
LEFT JOIN characters c ON c.id = ch.character_id
ORDER BY j.inserted_at DESC 
LIMIT 10;
```

#### View User Quests
```sql
SELECT uq.id, uq.title, uq.status, 
       uq.calculated_difficulty,
       c.name as character_name,
       uq.inserted_at
FROM user_quests uq
LEFT JOIN characters c ON c.id = uq.generated_by_character_id
ORDER BY uq.inserted_at DESC;
```

#### Check User Skills
```sql
SELECT domain, level, experience_points, last_updated
FROM user_skills
WHERE user_id = YOUR_USER_ID
ORDER BY domain;
```

#### Find Unprocessed Sessions
```sql
SELECT session_id, character_id, 
       COUNT(*) as message_count,
       MAX(inserted_at) as last_message
FROM conversation_history 
WHERE session_summary IS NULL 
  AND session_id IS NOT NULL
GROUP BY session_id, character_id
ORDER BY MAX(inserted_at) DESC;
```

## Development Workflow

### Typical Development Cycle
```bash
# 1. Start on main branch
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/new-feature

# 3. Make changes, then check database
psql -d green_man_tavern_dev
# Run test queries

# 4. Test in Phoenix
mix phx.server
# Test feature in browser

# 5. Check for errors
# Look at terminal logs

# 6. Commit changes
git add .
git commit -m "feat: Add new feature"

# 7. Push branch
git push -u origin feature/new-feature
```

### When Things Break

#### Reset Database
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs  # if you have seeds
```

#### Clear Elixir Build
```bash
mix clean
mix compile
```

#### Check for Compilation Errors
```bash
mix compile --force --warnings-as-errors
```

## Useful Aliases (add to ~/.bashrc or ~/.zshrc)
```bash
# Phoenix shortcuts
alias mps='mix phx.server'
alias mpr='mix phx.routes'
alias mer='mix ecto.reset'
alias mem='mix ecto.migrate'

# Database shortcuts
alias dbdev='psql -d green_man_tavern_dev'
alias dbtest='psql -d green_man_tavern_test'

# Git shortcuts
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline'
alias gb='git branch'
```

## Troubleshooting

### Port Already in Use
```bash
# Find process on port 4000
lsof -i :4000

# Kill process
kill -9 PID
```

### Database Connection Issues
```bash
# Check if PostgreSQL is running
sudo service postgresql status

# Start PostgreSQL
sudo service postgresql start

# Restart PostgreSQL
sudo service postgresql restart
```

### Clear Everything and Start Fresh
```bash
mix deps.clean --all
mix deps.get
mix clean
mix compile
mix ecto.reset
mix phx.server
```

## Project-Specific Notes

### Character IDs
- The Student: 1
- The Grandmother: 2
- The Farmer: 3
- The Robot: 4
- The Alchemist: 5
- The Survivalist: 6
- The Hobo: 7

### Quest Score Thresholds
- Minimum score for quest generation: 8 points
- Scoring: Multiple questions (+2 each), specific details (+3), 
  resource inquiries (+2), comparisons (+3)

### Important Database Tables
- `conversation_history` - All chat messages with sessions
- `journal_entries` - User's journal with session links
- `user_quests` - Dynamic and template quests
- `user_skills` - User's skill levels per domain
- `characters` - The Seven Seekers data
