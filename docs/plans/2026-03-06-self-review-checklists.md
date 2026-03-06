# Self-Review Checklists Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add structured self-review checklists to scan-code workers, _scan-common Team Leader, coding-team Planning Worker, and subagent-driven-development implementer.

**Architecture:** Surgical edits to 4 skill files. No new files. No tests (markdown). Each task edits one file, then commits.

**Tech Stack:** Markdown skill files in `~/.claude/skills/` and `~/.claude/plugins/cache/`

---

### Task 1: Add self-review to scan-code Worker 1 (Architecture)

**Files:**
- Modify: `~/.claude/skills/scan-code/SKILL.md`

**Step 1: Read the file to find the insertion point**

Open `~/.claude/skills/scan-code/SKILL.md`. Find the end of the Worker 1 (Architecture Review) block. It ends with:

```
> Use your best judgment -- if the current approach is actually the right call, say so with reasoning.
```

This is the FIRST occurrence of that line in the file (around line 91-92).

**Step 2: Insert the self-review block after that line**

Immediately after the first `> Use your best judgment...` line, add:

```
>
> ### Self-Review Pass
>
> Before returning your findings, re-read your output and check:
>
> 1. Did I check every module, or only the ones where I found issues first?
> 2. Would I defend each severity rating to a senior engineer using the `_scan-common` rubric?
> 3. Does any finding conflict with a deliberate decision in CLAUDE.md or MEMORY.md? If so, acknowledge it rather than flag it.
> 4. Are my fix suggestions concrete enough to act on, or are they vague ("consider refactoring X")?
> 5. Is there anything obvious I would catch on a second read?
>
> Fix any issues found before returning.
```

**Step 3: Verify**

Read the file and confirm the block appears at the end of Worker 1, before the `---` separator that starts Worker 2.

**Step 4: Commit**

```bash
git -C ~/.claude add skills/scan-code/SKILL.md
git -C ~/.claude commit -m "feat(scan-code): add self-review checklist to Architecture worker"
```

---

### Task 2: Add self-review to scan-code Worker 2 (Patterns)

**Files:**
- Modify: `~/.claude/skills/scan-code/SKILL.md`

**Step 1: Find the insertion point**

In `~/.claude/skills/scan-code/SKILL.md`, find the end of the Worker 2 (Patterns & Duplication) block. It ends with the SECOND occurrence of:

```
> Use your best judgment -- if the current approach is actually the right call, say so with reasoning.
```

(Around line 124-125, after the Patterns section.)

**Step 2: Insert the self-review block**

Immediately after that line, add:

```
>
> ### Self-Review Pass
>
> Before returning your findings, re-read your output and check:
>
> 1. Did I look across module boundaries for duplication, not just within files?
> 2. For each dead code finding — did I verify it's not called via macros, re-exports, or external callers?
> 3. Are any performance findings based on observable patterns, or are they speculative?
> 4. Would the suggested refactor actually improve the codebase, or is it churn?
> 5. Is there anything obvious I would catch on a second read?
>
> Fix any issues found before returning.
```

**Step 3: Verify**

Read the file and confirm the block appears at the end of Worker 2, before the `---` separator that starts Worker 3.

**Step 4: Commit**

```bash
git -C ~/.claude add skills/scan-code/SKILL.md
git -C ~/.claude commit -m "feat(scan-code): add self-review checklist to Patterns worker"
```

---

### Task 3: Add self-review to scan-code Worker 3 (Test Coverage)

**Files:**
- Modify: `~/.claude/skills/scan-code/SKILL.md`

**Step 1: Find the insertion point**

In `~/.claude/skills/scan-code/SKILL.md`, find the end of the Worker 3 (Test Coverage) block. It ends with the THIRD occurrence of:

```
> Use your best judgment -- if the current approach is actually the right call, say so with reasoning.
```

(Around line 158-159, end of the Worker 3 section, just before `---` and `## Step 3`.)

**Step 2: Insert the self-review block**

Immediately after that line, add:

```
>
> ### Self-Review Pass
>
> Before returning your findings, re-read your output and check:
>
> 1. Did I flag mock overuse — are there tests mocking what could be used for real?
> 2. For each coverage gap — did I check sibling files for tests I might have missed?
> 3. Are my test sketches concrete (function name + key assertions), not just "add a test for X"?
> 4. Did I sort gaps by real risk (HIGH) vs. nice-to-have (LOW)?
> 5. Is there anything obvious I would catch on a second read?
>
> Fix any issues found before returning.
```

**Step 3: Verify**

Read the file and confirm the block appears at the end of Worker 3, before the `---` separator that starts Step 3.

**Step 4: Commit**

```bash
git -C ~/.claude add skills/scan-code/SKILL.md
git -C ~/.claude commit -m "feat(scan-code): add self-review checklist to Test Coverage worker"
```

---

### Task 4: Add Team Leader self-review gate to _scan-common

**Files:**
- Modify: `~/.claude/skills/_scan-common/SKILL.md`

**Step 1: Find the insertion point**

Open `~/.claude/skills/_scan-common/SKILL.md`. Find Phase 3, Step 1 (Collect findings). It reads:

```
### Step 1: Collect findings
```

**Step 2: Insert a new step before Step 1**

Immediately before `### Step 1: Collect findings`, insert:

```
### Step 0: Verify self-review completion

Before collecting findings, verify each worker's output includes a completed self-review pass. Look for evidence that the worker re-examined their own output (e.g., "Self-review: found X, fixed Y" or an explicit note that no issues were found).

If a worker's output shows no evidence of self-review, send it back with the relevant checklist and ask them to complete it before proceeding. Do not synthesize unreviewed output.

---

```

**Step 3: Renumber**

Step 0 is intentionally numbered 0 (pre-flight check). Steps 1–6 keep their numbers — no renumbering needed.

**Step 4: Verify**

Read `_scan-common/SKILL.md` and confirm Step 0 appears just before the existing Step 1 under Phase 3.

**Step 5: Commit**

```bash
git -C ~/.claude add skills/_scan-common/SKILL.md
git -C ~/.claude commit -m "feat(_scan-common): require self-review evidence before Team Leader synthesis"
```

---

### Task 5: Replace Planning Worker quality gate in coding-team

**Files:**
- Modify: `~/.claude/skills/coding-team/SKILL.md`

**Step 1: Find the text to replace**

Open `~/.claude/skills/coding-team/SKILL.md`. Find this exact paragraph (around lines 101-103):

```
**Quality gate for the plan itself:** Before returning, verify the plan has zero ambiguous steps. If any step requires inference about file names, function signatures, or behavior — add the missing detail.
```

**Step 2: Replace with the numbered checklist**

Replace that paragraph with:

```
**Quality gate — self-review before returning:**

1. Pick 3 tasks at random — could a developer implement each without asking a single question? If not, add the missing detail.
2. Are all file references exact (`src/config.rs:14`, not "the config file")?
3. Does every feature task have a corresponding test task?
4. Are there security implications not addressed anywhere in the plan?
5. Is there any step that silently assumes context the implementer won't have?
```

**Step 3: Verify**

Read the file and confirm the numbered checklist replaced the single-sentence quality gate. The surrounding context (Planning Worker section) should be otherwise unchanged.

**Step 4: Commit**

```bash
git -C ~/.claude add skills/coding-team/SKILL.md
git -C ~/.claude commit -m "feat(coding-team): expand Planning Worker quality gate to numbered self-review checklist"
```

---

### Task 6: Add Robustness section to subagent-driven-development implementer

**Files:**
- Modify: `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/subagent-driven-development/implementer-prompt.md`

**Step 1: Find the insertion point**

Open the file. Find the `**Testing:**` section in the self-review block:

```
    **Testing:**
    - Do tests actually verify behavior (not just mock behavior)?
    - Did I follow TDD if required?
    - Are tests comprehensive?
```

**Step 2: Add Robustness section after Testing**

Immediately after the `**Testing:**` block (after `- Are tests comprehensive?`), add:

```

    **Robustness:**
    - Are all error paths handled, not just the happy path?
    - Is any user input validated before use?
    - Are there new trust boundaries introduced that need hardening?
```

**Step 3: Verify**

Read the file and confirm **Robustness** appears as the last section in the self-review block, after **Testing**, before "If you find issues during self-review, fix them now before reporting."

**Step 4: Commit**

The superpowers plugin is a cached plugin — check if there's a git repo at `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/`. If yes, commit there. If no git repo, the file is directly edited in place (no commit needed — the plugin cache is not version controlled).

```bash
# Check for git repo
git -C ~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1 status 2>/dev/null || echo "no git repo — edit in place, no commit"
```

---

## Execution Order

Tasks 1–3 all edit the same file (`scan-code/SKILL.md`) — run sequentially. Tasks 4–6 edit different files — could run in any order after tasks 1–3.

Recommended sequence: 1 → 2 → 3 → 4 → 5 → 6
