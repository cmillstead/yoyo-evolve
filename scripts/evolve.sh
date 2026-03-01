#!/bin/bash
# scripts/evolve.sh — One evolution cycle. Run every 4 hours via GitHub Actions or manually.
#
# Usage:
#   ANTHROPIC_API_KEY=sk-... ./scripts/evolve.sh
#
# Environment:
#   ANTHROPIC_API_KEY  — required
#   REPO               — GitHub repo (default: yologdev/yoyo-evolve)
#   MODEL              — LLM model (default: claude-opus-4-6)
#   TIMEOUT            — Max session time in seconds (default: 600)

set -euo pipefail

REPO="${REPO:-yologdev/yoyo-evolve}"
MODEL="${MODEL:-claude-opus-4-6}"
TIMEOUT="${TIMEOUT:-600}"
DAY=$(cat DAY_COUNT 2>/dev/null || echo 1)
DATE=$(date +%Y-%m-%d)

echo "=== Day $DAY: $DATE ==="
echo "Model: $MODEL"
echo "Timeout: ${TIMEOUT}s"
echo ""

# ── Step 1: Verify starting state ──
echo "→ Checking build..."
cargo build --quiet
cargo test --quiet
echo "  Build OK."
echo ""

# ── Step 2: Check previous CI status ──
CI_STATUS_MSG=""
if command -v gh &>/dev/null; then
    echo "→ Checking previous CI run..."
    CI_CONCLUSION=$(gh run list --repo "$REPO" --workflow ci.yml --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "unknown")
    if [ "$CI_CONCLUSION" = "failure" ]; then
        CI_RUN_ID=$(gh run list --repo "$REPO" --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
        CI_LOGS=""
        if [ -n "$CI_RUN_ID" ]; then
            CI_LOGS=$(gh run view "$CI_RUN_ID" --repo "$REPO" --log-failed 2>/dev/null | tail -30 || echo "Could not fetch logs.")
        fi
        CI_STATUS_MSG="Previous CI run FAILED. Error logs:
$CI_LOGS"
        echo "  CI: FAILED — agent will be told to fix this first."
    else
        echo "  CI: $CI_CONCLUSION"
    fi
    echo ""
fi

# ── Step 3: Fetch GitHub issues ──
ISSUES_FILE="ISSUES_TODAY.md"
echo "→ Fetching community issues..."
if command -v gh &>/dev/null; then
    gh issue list --repo "$REPO" \
        --state open \
        --label "agent-input" \
        --limit 10 \
        --json number,title,body,labels,reactionGroups \
        > /tmp/issues_raw.json 2>/dev/null || true

    python3 scripts/format_issues.py /tmp/issues_raw.json > "$ISSUES_FILE" 2>/dev/null || echo "No issues found." > "$ISSUES_FILE"
    echo "  $(grep -c '^### Issue' "$ISSUES_FILE" 2>/dev/null || echo 0) issues loaded."
else
    echo "  gh CLI not available. Skipping issue fetch."
    echo "No issues available (gh CLI not installed)." > "$ISSUES_FILE"
fi
echo ""

# ── Step 4: Prepare journal tail (last 10 entries for context) ──
RECENT_JOURNAL=$(head -200 JOURNAL.md 2>/dev/null || echo "No journal yet.")

# ── Step 5: Run evolution session ──
echo "→ Starting evolution session..."
echo ""

# Use gtimeout (brew install coreutils) on macOS, timeout on Linux
TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null; then
    if command -v gtimeout &>/dev/null; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
    fi
fi

PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<PROMPT
Today is Day $DAY ($DATE).

Read these files in this order:
1. IDENTITY.md (who you are and your rules)
2. src/main.rs (your current source code — this is YOU)
3. JOURNAL.md (your recent history — last 10 entries)
4. ISSUES_TODAY.md (community requests)
${CI_STATUS_MSG:+
=== CI STATUS ===
⚠️ PREVIOUS CI FAILED. Fix this FIRST before any new work.
$CI_STATUS_MSG
}
=== PHASE 1: Self-Assessment ===

Read your own source code carefully. Then try a small task to test
yourself — for example, read a file, edit something, run a command.
Note any friction, bugs, crashes, or missing capabilities.

=== PHASE 2: Review Community Issues ===

Read ISSUES_TODAY.md. These are real people asking you to improve.
Issues with more 👍 reactions should be prioritized higher.

=== PHASE 3: Decide ===

Make as many improvements as you can this session. Prioritize:
0. Fix CI failures (if any — this overrides everything else)
1. Self-discovered crash or data loss bug
2. Community issue with most 👍 (if actionable today)
3. Self-discovered UX friction or missing error handling
4. Whatever you think will make you most useful to real developers

=== PHASE 4: Implement ===

For each improvement, follow the evolve skill rules:
- Write a test first if possible
- Use edit_file for surgical changes
- Run cargo build && cargo test after changes
- If build fails, try to fix it. If you can't, revert with: bash git checkout -- src/
- After each successful change, commit: git add -A && git commit -m "Day $DAY: <short description>"
- Then move on to the next improvement

=== PHASE 5: Journal (MANDATORY — DO NOT SKIP) ===

This is NOT optional. You MUST write a journal entry before the session ends.

Write today's entry at the TOP of JOURNAL.md (above all existing entries). Format:
## Day $DAY — [title]
[2-4 sentences: what you tried, what worked, what didn't, what's next]

Then commit it: git add JOURNAL.md && git commit -m "Day $DAY: journal entry"

If you skip the journal, you have failed the session — even if all code changes succeeded.

=== PHASE 6: Issue Response ===

If you worked on a community GitHub issue, write to ISSUE_RESPONSE.md:
issue_number: [N]
status: fixed|partial|wontfix
comment: [your 2-3 sentence response to the person]

Now begin. Read IDENTITY.md first.
PROMPT

${TIMEOUT_CMD:+$TIMEOUT_CMD "$TIMEOUT"} cargo run -- \
    --model "$MODEL" \
    --skills ./skills \
    < "$PROMPT_FILE" || true

rm -f "$PROMPT_FILE"

echo ""
echo "→ Session complete. Checking results..."

# ── Step 6: Verify build and handle leftovers ──
if cargo build --quiet 2>/dev/null && cargo test --quiet 2>/dev/null && cargo clippy --quiet --all-targets 2>/dev/null && cargo fmt -- --check 2>/dev/null; then
    echo "  Build: PASS"
else
    echo "  Build: FAIL — reverting source changes"
    git checkout -- src/
fi

# ── Step 6b: Verify journal was written ──
if ! grep -q "## Day $DAY" JOURNAL.md 2>/dev/null; then
    echo "  WARNING: No journal entry for Day $DAY — agent skipped the journal!"
    # Write a minimal fallback entry
    COMMITS=$(git log --oneline --grep="Day $DAY:" --format="%s" | sed "s/Day $DAY: //" | paste -sd ", " -)
    if [ -z "$COMMITS" ]; then
        COMMITS="no commits made"
    fi
    ENTRY="## Day $DAY — (auto-generated, agent skipped journal)\n\nSession commits: $COMMITS.\n"
    sed -i.bak "s/^# Journal$/# Journal\n\n$ENTRY/" JOURNAL.md && rm -f JOURNAL.md.bak
    echo "  Auto-generated fallback journal entry."
fi

# Increment day counter
echo "$((DAY + 1))" > DAY_COUNT

# Rebuild website
echo "→ Rebuilding website..."
python3 scripts/build_site.py
echo "  Site rebuilt."

# Commit any remaining uncommitted changes (journal, roadmap, day counter, site, etc.)
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Day $DAY: session wrap-up"
    echo "  Committed session wrap-up."
else
    echo "  No uncommitted changes remaining."
fi

# ── Step 7: Handle issue response ──
if [ -f ISSUE_RESPONSE.md ]; then
    echo ""
    echo "→ Posting issue response..."
    
    ISSUE_NUM=$(grep "^issue_number:" ISSUE_RESPONSE.md | awk '{print $2}' || true)
    STATUS=$(grep "^status:" ISSUE_RESPONSE.md | awk '{print $2}' || true)
    COMMENT=$(sed -n '/^comment:/,$ p' ISSUE_RESPONSE.md | sed '1s/^comment: //' || true)
    
    if [ -n "$ISSUE_NUM" ] && command -v gh &>/dev/null; then
        gh issue comment "$ISSUE_NUM" \
            --repo "$REPO" \
            --body "🤖 **Day $DAY**

$COMMENT

Commit: $(git rev-parse --short HEAD)" || true

        if [ "$STATUS" = "fixed" ]; then
            gh issue close "$ISSUE_NUM" --repo "$REPO" || true
            echo "  Closed issue #$ISSUE_NUM"
        else
            echo "  Commented on issue #$ISSUE_NUM (status: $STATUS)"
        fi
    fi
    
    rm -f ISSUE_RESPONSE.md
fi

# ── Step 8: Push ──
echo ""
echo "→ Pushing..."
git push || echo "  Push failed (maybe no remote or auth issue)"

echo ""
echo "=== Day $DAY complete ==="
