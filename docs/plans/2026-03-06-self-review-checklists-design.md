# Self-Review Checklists for Agent Skills — Design

**Date**: 2026-03-06
**Skills affected**: `/coding-team`, `/scan-code`, `_scan-common`, `subagent-driven-development`

## Context

From an SDLC video: the single highest-leverage improvement for AI coding agents is a self-review pass after generating output. "Ask the agent to review the code it just wrote — 9/10 it finds issues it missed the first time." This applies not just to code but to any agent output (scan findings, implementation plans).

Our skills already have cross-review (workers reading sibling outputs) and Team Leader quality checks. What's missing is **self-review**: the same agent re-examining its own output through a structured checklist before returning.

`subagent-driven-development` already has a self-review section in `implementer-prompt.md`. It's missing error handling and security checks.

---

## Approach

**Approach B (chosen)**: Structured self-review checklists tailored per worker type. Vague "what did I miss?" prompts are unreliable — agents rubber-stamp their own output. Specific checklists (5-7 items) give the agent a concrete lens to look through.

Rejected:
- **Approach A** (inline nudge): too vague to be reliable
- **Approach C** (separate challenger subagent): overkill, doubles task count

---

## Changes

### 1. `scan-code/SKILL.md` — Worker self-review checklists

Append to end of each worker's task description block (after "Use your best judgment..." line).

**Worker 1 — Architecture:**
```
### Self-Review Pass

Before returning your findings, re-read your output and check:

1. Did I check every module, or only the ones where I found issues first?
2. Would I defend each severity rating to a senior engineer using the `_scan-common` rubric?
3. Does any finding conflict with a deliberate decision in CLAUDE.md or MEMORY.md? If so, acknowledge it rather than flag it.
4. Are my fix suggestions concrete enough to act on, or are they vague ("consider refactoring X")?
5. Is there anything obvious I would catch on a second read?

Fix any issues found before returning.
```

**Worker 2 — Patterns:**
```
### Self-Review Pass

Before returning your findings, re-read your output and check:

1. Did I look across module boundaries for duplication, not just within files?
2. For each dead code finding — did I verify it's not called via macros, re-exports, or external callers?
3. Are any performance findings based on observable patterns, or are they speculative?
4. Would the suggested refactor actually improve the codebase, or is it churn?
5. Is there anything obvious I would catch on a second read?

Fix any issues found before returning.
```

**Worker 3 — Test Coverage:**
```
### Self-Review Pass

Before returning your findings, re-read your output and check:

1. Did I flag mock overuse — are there tests mocking what could be used for real?
2. For each coverage gap — did I check sibling files for tests I might have missed?
3. Are my test sketches concrete (function name + key assertions), not just "add a test for X"?
4. Did I sort gaps by real risk (HIGH) vs. nice-to-have (LOW)?
5. Is there anything obvious I would catch on a second read?

Fix any issues found before returning.
```

### 2. `_scan-common/SKILL.md` — Team Leader quality check

In Phase 2, Step 4 (Quality check), append:

```
Before accepting a worker's output, verify it includes a completed self-review pass. If the output shows no evidence of self-review, send the worker back with the relevant checklist and ask them to complete it before returning.
```

### 3. `coding-team/SKILL.md` — Planning Worker quality gate

Replace the current quality gate paragraph:
> **Quality gate for the plan itself:** Before returning, verify the plan has zero ambiguous steps. If any step requires inference about file names, function signatures, or behavior — add the missing detail.

With a numbered self-review checklist:
```
**Quality gate — self-review before returning:**

1. Pick 3 tasks at random — could a developer implement each without asking a single question? If not, add the missing detail.
2. Are all file references exact (`src/config.rs:14`, not "the config file")?
3. Does every feature task have a corresponding test task?
4. Are there security implications not addressed anywhere in the plan?
5. Is there any step that silently assumes context the implementer won't have?
```

### 4. `subagent-driven-development/implementer-prompt.md` — Add missing checklist items

The existing self-review already covers completeness, quality, discipline, and testing. Add a **Robustness** section:

```
**Robustness:**
- Are all error paths handled, not just the happy path?
- Is any user input validated before use?
- Are there new trust boundaries introduced that need hardening?
```

---

## Files to Modify

| File | Change |
|------|--------|
| `~/.claude/skills/scan-code/SKILL.md` | Append self-review checklist to each of 3 worker blocks |
| `~/.claude/skills/_scan-common/SKILL.md` | Add 1 sentence to Team Leader quality check step |
| `~/.claude/skills/coding-team/SKILL.md` | Replace quality gate paragraph with 5-item numbered checklist |
| `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/subagent-driven-development/implementer-prompt.md` | Add Robustness section to self-review |

---

## Out of Scope

- `scan-security`, `scan-product`, `scan-adversarial` — same pattern applies but different worker types; update separately
- CI/CD review integration (video mentioned automated PR review) — separate feature
