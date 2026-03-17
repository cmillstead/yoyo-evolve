# Yoyo Evolve — Agent Navigation

Self-evolving coding agent CLI in Rust (~230 lines). GitHub Actions cron evolves its own source every 8 hours.

## Quick Reference

- **Full details**: See `CLAUDE.md` for architecture, build commands, and safety rules
- **Agent identity**: See `IDENTITY.md` (never modify)
- **Evolution journal**: See `JOURNAL.md`

## 1. Environment — Check Before Starting

- **Repository state**: `git status`, `git stash list`, `git branch`
- **CI/PR state**: `gh run list --limit 5`, `gh pr list`, `gh pr view`
- **Recent history**: `git log --oneline -20`
- **Escalation**: If CI is already failing on an unrelated issue, note it and proceed

## 2. Memory — Check Prior Knowledge

- **Git memory**: `git log --oneline -- <file>`, `git blame -L <start>,<end> <file>`
- **QMD vault**: Use QMD `search` and `vector_search` tools. QMD indexes `~/src/**/*.md`
- **ContextKeep**: `list_all_memories`, `retrieve_memory` (when configured, skip if unavailable)
- **Evolution context**: Read `JOURNAL.md` (top entries) for recent sessions, `LEARNINGS.md` for cached knowledge
- **Escalation**: If Memory reveals a prior decision that contradicts the current task, surface to user

## 3. Task — Assemble Context for the Work

- Single-file agent — `src/main.rs` is ~230 lines, full read is fine
- Read skill files (`skills/`) before modifying agent behavior
- Check prior analysis: scan reports and plans in `docs/plans/`
- Don't pre-load other files unless the task requires them

## Structure

| Area | Location | Purpose |
|------|----------|---------|
| Agent | `src/main.rs` | Entire application (~230 lines) |
| Evolution | `scripts/evolve.sh` | Build → issues → prompt → verify → commit |
| Skills | `skills/` | self-assess, evolve, communicate |
| State | `JOURNAL.md`, `LEARNINGS.md`, `DAY_COUNT` | Evolution state files |

## Commands

```bash
cargo build                       # Build
cargo test                        # Test
cargo clippy --all-targets -- -D warnings  # Lint (warnings are errors)
cargo fmt                         # Format
```

## Safety Rules

All detailed in `CLAUDE.md`. Highlights:
- Never modify `IDENTITY.md`, `scripts/evolve.sh`, or `.github/workflows/`
- Every code change must pass `cargo build && cargo test`
- If build fails after changes, revert with `git checkout -- src/`
- One improvement per evolution session

## 4. Validation — Before Claiming Done

- **Self-review**: `git diff --stat`, `git diff`, re-read task/issue for acceptance criteria
- **Local verification**: `cargo build && cargo test && cargo clippy --all-targets -- -D warnings && cargo fmt -- --check`
- **After pushing**: `gh run list --limit 1`, `gh run view <id>`, fix CI failures immediately
- **Common CI failures**: clippy warnings-as-errors, fmt check
- **Don't claim done until**: local tests pass, CI green, diff is intentional only


## Boundaries

### Always Do
- Run tests and linting before committing — NEVER commit without verification
- Follow the architectural layer structure defined above
- Use real implementations in tests — NEVER use mocks, patches, or stubs
- Use existing utilities before creating new ones — search before writing
- Write tests alongside new code — NEVER ship untested business logic
- Read the spec/plan before implementing — understand "done" before starting

### Ask First
- Adding a new external dependency
- Modifying database schema or migrations
- Changing public API contracts or interfaces
- Deleting or moving files in shared directories
- Any change affecting more than 3 modules

### Never Do
- NEVER commit secrets, tokens, API keys, or credentials
- NEVER modify deployed migration files
- NEVER skip or disable tests to make CI pass
- NEVER force push to main or release branches
- NEVER commit .env files or sensitive configuration
- NEVER introduce a new framework or library without explicit approval
- NEVER claim work is done without running verification
- NEVER retry the same failed approach more than 3 times — escalate instead
- NEVER expand task scope without asking — park new ideas separately

## Golden Principles
Read docs/golden-principles.md when: making architectural decisions, resolving ambiguity, or unsure which approach to take.
