#!/bin/bash
# Helper script to run SQL queries against the database
# Usage: ./run_sql.sh [query_file.sql] or ./run_sql.sh "SELECT * FROM users;"

DB_NAME="green_man_tavern_dev"
DB_USER="jesse"
DB_HOST="localhost"
DB_PASSWORD="${DATABASE_PASSWORD:-jesse}"

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

if [ -z "$1" ]; then
    echo "Usage: $0 [query_file.sql] or $0 \"SELECT * FROM users;\""
    echo ""
    echo "Examples:"
    echo "  $0 verification_queries.sql"
    echo "  $0 \"SELECT COUNT(*) FROM users;\""
    exit 1
fi

# Check if argument is a file or a query string
if [ -f "$1" ]; then
    # It's a file - run it
    echo "Running SQL file: $1"
    psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -f "$1"
else
    # It's a query string - run it directly
    echo "Running SQL query:"
    echo "$1"
    echo ""
    psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -c "$1"
fi


