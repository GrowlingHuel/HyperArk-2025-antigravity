#!/bin/bash
# File Reorganization Script
# This script reorganizes project files into a /notes/ directory structure
# Uses 'mv' to move files, then stages all changes with 'git add'
# Review this script before executing!

set -e  # Exit on error

echo "=========================================="
echo "File Reorganization Script"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Create /notes/ directory structure"
echo "  2. Move files using 'mv'"
echo "  3. Stage all changes with 'git add -A'"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p notes/documentation
mkdir -p notes/planning
mkdir -p notes/sql_examples
mkdir -p notes/debug_scripts
mkdir -p notes/archived_mindsdb
echo "✓ Directory structure created"
echo ""

# Move files to /notes/documentation/
echo "=========================================="
echo "Moving files to /notes/documentation/"
echo "=========================================="

echo "Moving: CHANGELOG_FROST_DATES_INTEGRATION.md -> notes/documentation/"
mv CHANGELOG_FROST_DATES_INTEGRATION.md notes/documentation/

echo "Moving: CHANGELOG_SPACE_PAGINATION.md -> notes/documentation/"
mv CHANGELOG_SPACE_PAGINATION.md notes/documentation/

echo "Moving: AGENTS.md -> notes/documentation/"
mv AGENTS.md notes/documentation/

echo "Moving: ARCHITECTURE.md -> notes/documentation/"
mv ARCHITECTURE.md notes/documentation/

echo "Moving: AUDIT_BASELINE.md -> notes/documentation/"
mv AUDIT_BASELINE.md notes/documentation/

echo "Moving: CODEBASE_AUDIT_REPORT.md -> notes/documentation/"
mv CODEBASE_AUDIT_REPORT.md notes/documentation/

echo "Moving: DIAGNOSTIC_REPORT.md -> notes/documentation/"
mv DIAGNOSTIC_REPORT.md notes/documentation/

echo "Moving: DUAL_PANEL_STATE_ARCHITECTURE.md -> notes/documentation/"
mv DUAL_PANEL_STATE_ARCHITECTURE.md notes/documentation/

echo "Moving: HOW_TO_RUN_SQL_QUERIES.md -> notes/documentation/"
mv HOW_TO_RUN_SQL_QUERIES.md notes/documentation/

echo "Moving: hypercard_chrome_spec.md -> notes/documentation/"
mv hypercard_chrome_spec.md notes/documentation/

echo "Moving: IMPLEMENTATION_LOG.md -> notes/documentation/"
mv IMPLEMENTATION_LOG.md notes/documentation/

echo "Moving: Living_Web_17.11.25.md -> notes/documentation/"
mv Living_Web_17.11.25.md notes/documentation/

echo "Moving: Living_Web_CSS_Troubleshooting_Guide.md -> notes/documentation/"
mv Living_Web_CSS_Troubleshooting_Guide.md notes/documentation/

echo "Moving: PLANTING_DATES_COMPLETE.md -> notes/documentation/"
mv PLANTING_DATES_COMPLETE.md notes/documentation/

echo "Moving: PLANTING_QUEST_RENDERING_ANALYSIS.md -> notes/documentation/"
mv PLANTING_QUEST_RENDERING_ANALYSIS.md notes/documentation/

echo "Moving: QUEST_DEDUPLICATION_PGVECTOR_CHANGES.md -> notes/documentation/"
mv QUEST_DEDUPLICATION_PGVECTOR_CHANGES.md notes/documentation/

echo "Moving: SESSION_PROCESSING_DEBUG.md -> notes/documentation/"
mv SESSION_PROCESSING_DEBUG.md notes/documentation/

echo "Moving: SESSION_PROCESSING_FIX.md -> notes/documentation/"
mv SESSION_PROCESSING_FIX.md notes/documentation/

echo "Moving: TERMINAL_COMMANDS.md -> notes/documentation/"
mv TERMINAL_COMMANDS.md notes/documentation/

echo "Moving: TEST_SESSION_FLOW_GUIDE.md -> notes/documentation/"
mv TEST_SESSION_FLOW_GUIDE.md notes/documentation/

echo "Moving: TLDR_18.11.25.md -> notes/documentation/"
mv TLDR_18.11.25.md notes/documentation/

echo "Moving: Two_Panel_Architecture_Implementation_Plan.md -> notes/documentation/"
mv Two_Panel_Architecture_Implementation_Plan.md notes/documentation/

echo "Moving: 03.11.25_implementation_guide.md -> notes/documentation/"
mv 03.11.25_implementation_guide.md notes/documentation/

echo "Moving: audit_20251103.md -> notes/documentation/"
mv audit_20251103.md notes/documentation/

echo "Moving: green_man_tavern_rag_implementation_plan.md -> notes/documentation/"
mv green_man_tavern_rag_implementation_plan.md notes/documentation/

echo "Moving: FILE_INVENTORY.md -> notes/documentation/"
mv FILE_INVENTORY.md notes/documentation/

echo "Moving: priv/repo/migrations/MIGRATION_FIX_NOTES.md -> notes/documentation/"
mv priv/repo/migrations/MIGRATION_FIX_NOTES.md notes/documentation/

echo "Moving: priv/repo/migrations/README_LIVING_WEB_MIGRATIONS.md -> notes/documentation/"
mv priv/repo/migrations/README_LIVING_WEB_MIGRATIONS.md notes/documentation/

echo "Moving: priv/repo/seeds/data/README.md -> notes/documentation/"
mv priv/repo/seeds/data/README.md notes/documentation/

echo "Moving: priv/mindsdb/README.md -> notes/documentation/"
mv priv/mindsdb/README.md notes/documentation/

echo ""
echo "✓ Documentation files moved"
echo ""

# Move files to /notes/planning/
echo "=========================================="
echo "Moving files to /notes/planning/"
echo "=========================================="

echo "Moving: audit_prompt.txt -> notes/planning/"
mv audit_prompt.txt notes/planning/

echo "Moving: cookies.txt -> notes/planning/"
mv cookies.txt notes/planning/

echo "Moving: cursor_responses_03.11.25.txt -> notes/planning/"
mv cursor_responses_03.11.25.txt notes/planning/

echo "Moving: living_web_update_03.11.25.txt -> notes/planning/"
mv living_web_update_03.11.25.txt notes/planning/

echo "Moving: mindsdb_setup_guide.txt -> notes/planning/"
mv mindsdb_setup_guide.txt notes/planning/

echo "Moving: priv/repo/character_prompt_template.txt -> notes/planning/"
mv priv/repo/character_prompt_template.txt notes/planning/

echo ""
echo "✓ Planning files moved"
echo ""

# Move files to /notes/sql_examples/
echo "=========================================="
echo "Moving files to /notes/sql_examples/"
echo "=========================================="

echo "Moving: verification_queries.sql -> notes/sql_examples/"
mv verification_queries.sql notes/sql_examples/

echo ""
echo "✓ SQL example files moved"
echo ""

# Move files to /notes/debug_scripts/
echo "=========================================="
echo "Moving files to /notes/debug_scripts/"
echo "=========================================="

echo "Moving: check_openai.exs -> notes/debug_scripts/"
mv check_openai.exs notes/debug_scripts/

echo "Moving: configure_openrouter.exs -> notes/debug_scripts/"
mv configure_openrouter.exs notes/debug_scripts/

echo "Moving: debug_models.exs -> notes/debug_scripts/"
mv debug_models.exs notes/debug_scripts/

echo "Moving: direct_knowledge_upload.exs -> notes/debug_scripts/"
mv direct_knowledge_upload.exs notes/debug_scripts/

echo "Moving: direct_model_test.exs -> notes/debug_scripts/"
mv direct_model_test.exs notes/debug_scripts/

echo "Moving: final_test.exs -> notes/debug_scripts/"
mv final_test.exs notes/debug_scripts/

echo "Moving: fix_httpclient_simple.exs -> notes/debug_scripts/"
mv fix_httpclient_simple.exs notes/debug_scripts/

echo "Moving: fix_httpclient.exs -> notes/debug_scripts/"
mv fix_httpclient.exs notes/debug_scripts/

echo "Moving: fix_model_initialization.exs -> notes/debug_scripts/"
mv fix_model_initialization.exs notes/debug_scripts/

echo "Moving: fix_pdf_extraction.exs -> notes/debug_scripts/"
mv fix_pdf_extraction.exs notes/debug_scripts/

echo "Moving: mindsdb_diagnostic.exs -> notes/debug_scripts/"
mv mindsdb_diagnostic.exs notes/debug_scripts/

echo "Moving: start_knowledge_upload.exs -> notes/debug_scripts/"
mv start_knowledge_upload.exs notes/debug_scripts/

echo "Moving: test_agents.exs -> notes/debug_scripts/"
mv test_agents.exs notes/debug_scripts/

echo "Moving: test_complete.exs -> notes/debug_scripts/"
mv test_complete.exs notes/debug_scripts/

echo "Moving: test_http_client.exs -> notes/debug_scripts/"
mv test_http_client.exs notes/debug_scripts/

echo "Moving: test_knowledge_upload.exs -> notes/debug_scripts/"
mv test_knowledge_upload.exs notes/debug_scripts/

echo "Moving: test_llm_agents.exs -> notes/debug_scripts/"
mv test_llm_agents.exs notes/debug_scripts/

echo "Moving: test_openai_integration.exs -> notes/debug_scripts/"
mv test_openai_integration.exs notes/debug_scripts/

echo "Moving: test_session_flow.exs -> notes/debug_scripts/"
mv test_session_flow.exs notes/debug_scripts/

echo "Moving: test_sqlclient.exs -> notes/debug_scripts/"
mv test_sqlclient.exs notes/debug_scripts/

echo "Moving: upload_knowledge_base.exs -> notes/debug_scripts/"
mv upload_knowledge_base.exs notes/debug_scripts/

echo ""
echo "✓ Debug script files moved"
echo ""

# Move files to /notes/archived_mindsdb/
echo "=========================================="
echo "Moving files to /notes/archived_mindsdb/"
echo "=========================================="

echo "Moving: priv/mindsdb/agents/definitions.exs -> notes/archived_mindsdb/"
mv priv/mindsdb/agents/definitions.exs notes/archived_mindsdb/

echo ""
echo "✓ Archived MindsDB files moved"
echo ""

# Summary
echo "=========================================="
echo "Reorganization Complete!"
echo "=========================================="
echo ""
echo "Files have been moved to:"
echo "  - notes/documentation/ (29 files)"
echo "  - notes/planning/ (6 files)"
echo "  - notes/sql_examples/ (1 file)"
echo "  - notes/debug_scripts/ (20 files)"
echo "  - notes/archived_mindsdb/ (1 file)"
echo ""
echo "Total files moved: 57"
echo ""

echo "=========================================="
echo "Staging changes in Git..."
echo "=========================================="
git add -A
echo "✓ All changes staged"
echo ""
echo "Review changes with: git status"
echo "Commit with: git commit -m 'Organize: Move documentation and debug files to /notes structure'"
echo ""

