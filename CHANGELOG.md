## 2025-11-10

- **Quest Deletion Feature**: Added delete button (×) to quest items in Active and Available Quests sections
  - Button positioned in top-right corner of each quest item with subtle styling (transparent background, brown border, low opacity)
  - Uses `Repo.delete_all/1` with query to avoid loading vector fields (prevents Postgrex errors with pgvector)
  - Properly verifies quest ownership (user_id check) before deletion
  - Reloads quest list after successful deletion
  - Clears expanded quest state if deleted quest was expanded
  - Fully functional and tested

## 2025-10-22

- Switched MindsDB integration from PostgreSQL wire protocol to HTTP API (port 47334)
- Implemented Req-based `MindsDB.Client` with robust response parsing
- Standardized HTTP config across environments (`mindsdb_host`, `mindsdb_http_port`, `mindsdb_user`, `mindsdb_password`)
- Removed supervision of MindsDB client (no longer a GenServer)
- Verified connectivity and agent querying via HTTP; seven character agents tested end-to-end


