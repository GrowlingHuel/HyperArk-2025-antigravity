# File Inventory - Root and Immediate Subdirectories

This document lists all `.md`, `.txt`, `.sql`, `.ex`, and `.exs` files in the project root and immediate subdirectories (not deep in `lib/` or `test/`).

| File Path | File Type | Referenced By | Standard Phoenix/Elixir File |
|-----------|-----------|---------------|------------------------------|
| **ROOT LEVEL FILES** |
| `mix.exs` | `.ex` | Application entry point, Mix tasks | ✅ Yes - Standard Mix project file |
| `README.md` | `.md` | Documentation (referenced in docs) | ✅ Yes - Standard project README |
| `CHANGELOG.md` | `.md` | Documentation | ❌ No - Project-specific |
| `CHANGELOG_FROST_DATES_INTEGRATION.md` | `.md` | Documentation | ❌ No - Project-specific |
| `CHANGELOG_SPACE_PAGINATION.md` | `.md` | Documentation | ❌ No - Project-specific |
| `AGENTS.md` | `.md` | Documentation | ❌ No - Project-specific |
| `ARCHITECTURE.md` | `.md` | Documentation | ❌ No - Project-specific |
| `AUDIT_BASELINE.md` | `.md` | Documentation | ❌ No - Project-specific |
| `CODEBASE_AUDIT_REPORT.md` | `.md` | Documentation | ❌ No - Project-specific |
| `DIAGNOSTIC_REPORT.md` | `.md` | Documentation | ❌ No - Project-specific |
| `DUAL_PANEL_STATE_ARCHITECTURE.md` | `.md` | Documentation | ❌ No - Project-specific |
| `HOW_TO_RUN_SQL_QUERIES.md` | `.md` | Documentation (references `verification_queries.sql`, `run_sql.sh`) | ❌ No - Project-specific |
| `hypercard_chrome_spec.md` | `.md` | Documentation | ❌ No - Project-specific |
| `IMPLEMENTATION_LOG.md` | `.md` | Documentation | ❌ No - Project-specific |
| `Living_Web_17.11.25.md` | `.md` | Documentation | ❌ No - Project-specific |
| `Living_Web_CSS_Troubleshooting_Guide.md` | `.md` | Documentation | ❌ No - Project-specific |
| `PLANTING_DATES_COMPLETE.md` | `.md` | Documentation | ❌ No - Project-specific |
| `PLANTING_QUEST_RENDERING_ANALYSIS.md` | `.md` | Documentation | ❌ No - Project-specific |
| `QUEST_DEDUPLICATION_PGVECTOR_CHANGES.md` | `.md` | Documentation | ❌ No - Project-specific |
| `SESSION_PROCESSING_DEBUG.md` | `.md` | Documentation | ❌ No - Project-specific |
| `SESSION_PROCESSING_FIX.md` | `.md` | Documentation | ❌ No - Project-specific |
| `TERMINAL_COMMANDS.md` | `.md` | Documentation (references `priv/repo/seeds.exs`) | ❌ No - Project-specific |
| `TEST_SESSION_FLOW_GUIDE.md` | `.md` | Documentation | ❌ No - Project-specific |
| `TLDR_18.11.25.md` | `.md` | Documentation | ❌ No - Project-specific |
| `Two_Panel_Architecture_Implementation_Plan.md` | `.md` | Documentation | ❌ No - Project-specific |
| `03.11.25_implementation_guide.md` | `.md` | Documentation | ❌ No - Project-specific |
| `audit_20251103.md` | `.md` | Documentation | ❌ No - Project-specific |
| `green_man_tavern_rag_implementation_plan.md` | `.md` | Documentation | ❌ No - Project-specific |
| `audit_prompt.txt` | `.txt` | Documentation | ❌ No - Project-specific |
| `cookies.txt` | `.txt` | Not referenced | ❌ No - Project-specific |
| `cursor_responses_03.11.25.txt` | `.txt` | Documentation | ❌ No - Project-specific |
| `living_web_update_03.11.25.txt` | `.txt` | Documentation | ❌ No - Project-specific |
| `mindsdb_setup_guide.txt` | `.txt` | Documentation | ❌ No - Project-specific |
| `verification_queries.sql` | `.sql` | Referenced by `HOW_TO_RUN_SQL_QUERIES.md`, `run_sql.sh` | ❌ No - Project-specific |
| `check_openai.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `configure_openrouter.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `debug_models.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `direct_knowledge_upload.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `direct_model_test.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `final_test.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `fix_httpclient_simple.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `fix_httpclient.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `fix_model_initialization.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `fix_pdf_extraction.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `mindsdb_diagnostic.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `start_knowledge_upload.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_agents.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_complete.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_http_client.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_knowledge_upload.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_llm_agents.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_openai_integration.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_session_flow.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `test_sqlclient.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| `upload_knowledge_base.exs` | `.exs` | Standalone script | ❌ No - Project-specific |
| **CONFIG DIRECTORY** |
| `config/config.exs` | `.exs` | Loaded by Mix, imports env-specific configs | ✅ Yes - Standard Phoenix config |
| `config/dev.exs` | `.exs` | Imported by `config.exs` (via `import_config`) | ✅ Yes - Standard Phoenix config |
| `config/prod.exs` | `.exs` | Imported by `config.exs` (via `import_config`) | ✅ Yes - Standard Phoenix config |
| `config/runtime.exs` | `.exs` | Loaded at runtime by Phoenix | ✅ Yes - Standard Phoenix config |
| `config/test.exs` | `.exs` | Imported by `config.exs` (via `import_config`) | ✅ Yes - Standard Phoenix config |
| **PRIV/REPO DIRECTORY** |
| `priv/repo/seeds.exs` | `.exs` | ✅ Referenced by `mix.exs` (alias `ecto.setup`), `TERMINAL_COMMANDS.md` | ✅ Yes - Standard Ecto seeds file |
| `priv/repo/seeds/characters.exs` | `.exs` | ✅ Referenced by `priv/repo/seeds.exs` (via `Code.eval_file`) | ❌ No - Project-specific seed |
| `priv/repo/seeds/003_projects.exs` | `.exs` | ✅ Referenced by `priv/repo/seeds.exs` (via `Code.eval_file`) | ❌ No - Project-specific seed |
| `priv/repo/seeds/01_systems.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/companion_expanded.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/create_user5.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/create_user5_systems.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/frost_dates.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/journal_and_quests_seeds.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/knowledge_terms.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/living_web_test_data.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/missing_plants.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/plant_quest_seeds.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/planting_guide_quickstart.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/planting_guide_seeds.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/planting_guide.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/regenerate_journal_entries.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/remove_mindsdb_names.exs` | `.exs` | Not directly referenced (may be run manually) | ❌ No - Project-specific seed |
| `priv/repo/seeds/data/README.md` | `.md` | Documentation | ❌ No - Project-specific |
| `priv/repo/migrations/*.exs` | `.exs` | ✅ Loaded automatically by Ecto migrations | ✅ Yes - Standard Ecto migration files |
| `priv/repo/migrations/MIGRATION_FIX_NOTES.md` | `.md` | Documentation | ❌ No - Project-specific |
| `priv/repo/migrations/README_LIVING_WEB_MIGRATIONS.md` | `.md` | Documentation | ❌ No - Project-specific |
| `priv/repo/character_prompt_template.txt` | `.txt` | Not referenced in codebase | ❌ No - Project-specific |
| **PRIV/MINDSDB DIRECTORY** |
| `priv/mindsdb/agents/definitions.exs` | `.exs` | Not referenced (MindsDB integration removed per mix.exs) | ❌ No - Project-specific |
| `priv/mindsdb/README.md` | `.md` | Documentation | ❌ No - Project-specific |
| **PRIV/STATIC DIRECTORY** |
| `priv/static/robots.txt` | `.txt` | ✅ Served by Phoenix static file handler | ✅ Yes - Standard web robots.txt |

## Summary

- **Total Files Listed**: 75
- **Standard Phoenix/Elixir Files**: 12
- **Project-Specific Files**: 63
- **Files Referenced by mix.exs/config**: 8
- **Standalone Scripts**: 20
- **Documentation Files**: 30
- **Seed Files**: 16
- **Migration Files**: ~62 (in migrations directory, loaded automatically by Ecto)

## Notes

1. **Migration files** (`priv/repo/migrations/*.exs`) are automatically loaded by Ecto when running `mix ecto.migrate`. They are not explicitly referenced in code but are part of the standard Phoenix/Ecto workflow.

2. **Seed files** in `priv/repo/seeds/` are mostly not directly referenced, but can be run manually with `mix run priv/repo/seeds/<filename>.exs`.

3. **Standalone scripts** in the root directory are utility scripts that can be run directly with `mix run <filename>.exs` or `elixir <filename>.exs`.

4. **Config files** are automatically loaded by Mix and Phoenix in the order: `config.exs` → environment-specific config (`dev.exs`, `test.exs`, `prod.exs`) → `runtime.exs`.

5. The `priv/repo/seeds.exs` file is the main entry point for seeding and is referenced in `mix.exs` aliases.

