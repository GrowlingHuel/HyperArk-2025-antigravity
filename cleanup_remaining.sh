#!/bin/bash

# Create additional subdirectory for logs if needed
mkdir -p notes/logs notes/archived

echo "Moving remaining documentation files..."
mv 03.11.25_CODEBASE_AUDIT.md.odt notes/documentation/
mv INSTALLATION.md.pdf notes/documentation/
mv TLDR_18.11.25 notes/planning/

echo "Moving debug/utility scripts..."
mv batch_debug.log notes/logs/
mv run_sql.sh notes/sql_examples/
mv reorganize_files.sh notes/archived/

echo "Moving screenshot and archive files..."
mv homesteadingPDFscreenshot.png notes/archived/
mv minddb.png notes/archived/
mv files.zip notes/archived/

echo "Cleaning up fragment/junk files..."
# These appear to be fragments, temp files, or junk
mv ";" notes/planning/ 2>/dev/null || true
mv "1" notes/planning/ 2>/dev/null || true
mv ation_history notes/planning/ 2>/dev/null || true
mv config-err-qCmwK5 notes/planning/ 2>/dev/null || true
mv erl_crash.dump notes/logs/ 2>/dev/null || true
mv er_quests notes/planning/ 2>/dev/null || true
mv "terror," notes/planning/ 2>/dev/null || true
mv "ession_id IS NOT NULL" notes/planning/ 2>/dev/null || true
mv git_commit_token notes/planning/ 2>/dev/null || true
mv "tok," notes/planning/ 2>/dev/null || true
mv sql notes/planning/ 2>/dev/null || true
mv SSH notes/planning/ 2>/dev/null || true
mv steps notes/planning/ 2>/dev/null || true
mv "t 10 filenames" notes/planning/ 2>/dev/null || true
mv ts notes/planning/ 2>/dev/null || true

echo "✓ Cleanup complete!"
echo ""
echo "Review changes with: ls -la"
echo "Stage with: git add -A"
echo "Commit with: git commit -m 'Clean up: Move remaining artifacts and junk files to /notes'"
