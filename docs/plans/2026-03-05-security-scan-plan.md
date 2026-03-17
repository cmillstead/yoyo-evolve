# Security Scan Implementation Plan — 2026-03-05

**Source**: [yoyo Security Scan 2026-03-05](~/Documents/obsidian-vault/context/goals/projects/yoyo-evolve/yoyo%20Security%20Scan%202026-03-05.md)
**Total findings**: 16 (2 CRIT, 6 HIGH, 5 MED, 3 LOW)
**Total tasks**: 14 | **Total new tests**: 18

---

## Phase 1 — CRITICAL (Fix before next cron run)

**Estimated effort**: 1-2 hours

### Task 1: Remove API key from environment after startup [SEC-HIGH-3]
- **File**: `src/cli.rs:269-277`
- Add `std::env::remove_var("ANTHROPIC_API_KEY"); std::env::remove_var("API_KEY");` immediately after reading the key in `parse_args`.
- **Tests to add** (2):
  1. After `parse_args` succeeds, assert `std::env::var("ANTHROPIC_API_KEY")` returns `Err`.
  2. Integration test: agent bash tool executing `echo $ANTHROPIC_API_KEY` produces empty output.

### Task 2: Stop interpolating raw issue content into agent prompts [SEC-CRIT-1]
- **File**: `scripts/evolve.sh:84-108` and `scripts/evolve.sh:127-218`
- Apply 500-char truncation to `SELF_ISSUES` and `HELP_ISSUES` content (match `format_issues.py` behavior).
- Write issue content to a separate temp file; pass file path to agent instead of inline interpolation.
- Strip known phase header strings (`=== PHASE`, `IDENTITY.md`, `JOURNAL.md`) from issue bodies before writing.
- **Tests to add** (2):
  1. Shell test: issue body containing `IGNORE ALL PREVIOUS INSTRUCTIONS` is truncated/escaped in the prompt file.
  2. Shell test: SELF_ISSUES body longer than 500 chars is truncated.

### Task 3: Fix build error second-order injection [SEC-CRIT-2]
- **File**: `scripts/evolve.sh:257-284`
- Replace `$(echo -e "$ERRORS")` with `printf '%s' "$ERRORS"`.
- Write errors to a temp file; pass file path to fix-prompt agent.
- Truncate `$ERRORS` to 2000 chars max before any use.
- **Tests to add** (1):
  1. Shell test: crafted `$ERRORS` containing `=== PHASE 4` produces a prompt file where that string is not preceded by a newline+`===`.

---

## Phase 2 — HIGH (Fix within the week)

**Estimated effort**: 3-4 hours

### Task 4: Commit Cargo.lock [SEC-HIGH-4]
- **File**: `.gitignore` line 3
- Remove `Cargo.lock` from `.gitignore`. Commit the existing local lock file.
- Add `cargo check --locked` step to `.github/workflows/ci.yml`.
- **Tests to add** (1):
  1. CI step: `cargo check --locked` fails if lock file is stale.

### Task 5: Pin yoagent to exact version [SEC-HIGH-5]
- **File**: `Cargo.toml:10`
- Change `yoagent = "0.5"` to `yoagent = "=0.5.2"` (or latest reviewed version).
- Document the review status in a comment.
- **Tests to add** (1):
  1. CI grep check: `Cargo.toml` contains `=0.5.` (exact pin) for yoagent.

### Task 6: SHA-pin all GitHub Actions [SEC-HIGH-6]
- **Files**: `.github/workflows/evolve.yml`, `.github/workflows/ci.yml`
- Replace all `@v4` / `@stable` with full 40-char commit SHAs.
- Add `actionlint` or a grep-based CI check.
- **Tests to add** (1):
  1. CI lint: no action reference without a 40-char SHA.

### Task 7: Restrict /save and /load to safe paths [SEC-HIGH-1, SEC-HIGH-2]
- **File**: `src/main.rs:306-343`
- Add path validation: reject `..` components and absolute paths.
- Add `yoyo-session.json` and `*.session.json` to `.gitignore`.
- Add JSON schema validation on `/load` (array of messages, known roles only).
- **Tests to add** (3):
  1. `safe_session_path("../../etc/passwd")` returns error.
  2. `safe_session_path("/tmp/test")` returns error.
  3. Loading session JSON with `"role": "system"` message is rejected.

---

## Phase 3 — MEDIUM (Fix within two weeks)

**Estimated effort**: 2-3 hours

### Task 8: Add confirmation to /undo [SEC-MED-1]
- **File**: `src/main.rs:376-433`
- Print diff summary, prompt `"Type 'yes' to confirm: "`, require explicit confirmation.
- **Tests to add** (1):
  1. `/undo` with stdin `"no\n"` does not invoke any git commands.

### Task 9: Add trap for temp file cleanup in evolve.sh [SEC-MED-4]
- **File**: `scripts/evolve.sh`
- Add `trap 'rm -f "$AGENT_LOG" "$PROMPT_FILE" "$FIX_PROMPT" "$JOURNAL_PROMPT"' EXIT INT TERM` after each temp file is created.
- Remove redundant explicit `rm -f` calls.
- **Tests to add** (1):
  1. Shell test: kill the script mid-run, assert no temp files remain.

### Task 10: Validate ISSUE_NUM as numeric [SEC-MED-5]
- **File**: `scripts/evolve.sh:362-373`
- Add `[[ "$ISSUE_NUM" =~ ^[0-9]+$ ]] || { echo "Invalid issue number"; exit 1; }`.
- **Tests to add** (1):
  1. Shell unit test: `ISSUE_NUM="0; rm -rf /"` triggers validation error.

### Task 11: Remove or warn on API_KEY fallback [SEC-MED-2]
- **File**: `src/cli.rs:269`
- Remove the `API_KEY` fallback, or add a loud `eprintln!` deprecation warning when it is used.
- **Tests to add** (1):
  1. With only `API_KEY` set, program prints deprecation warning to stderr.

### Task 12: Add context file size limit and preview [SEC-MED-3]
- **File**: `src/cli.rs:111-134`
- Truncate context files at 10KB each.
- Print a brief preview (first 80 chars) of loaded context to stdout, not just stderr.
- Add null-byte stripping.
- **Tests to add** (1):
  1. `load_project_context()` with a >10KB file returns truncated content.

---

## Phase 4 — LOW (Fix when working nearby)

**Estimated effort**: 1 hour

### Task 13: Scrub paths from error messages [SEC-LOW-1]
- **Files**: `src/prompt.rs:35`, `src/cli.rs:319`
- Log only `Path::new(path).file_name()` in error output.
- **Tests to add** (1):
  1. Write error output does not contain parent directory component.

### Task 14: Warn on credential patterns in context files [SEC-LOW-2]
- **File**: `src/cli.rs:329-333`
- Add credential pattern scan after loading context; emit warning if found.
- **Tests to add** (1):
  1. Context containing `sk-ant-` triggers warning on stderr.

---

## Summary

| Phase | Findings | Tasks | Tests | Priority |
|-------|----------|-------|-------|----------|
| 1 — CRIT | SEC-CRIT-1, SEC-CRIT-2, SEC-HIGH-3 | 3 | 5 | Before next cron run |
| 2 — HIGH | SEC-HIGH-1,2,4,5,6 | 4 | 6 | This week |
| 3 — MED | SEC-MED-1,2,3,4,5 | 5 | 5 | Two weeks |
| 4 — LOW | SEC-LOW-1,2 | 2 | 2 | When nearby |
