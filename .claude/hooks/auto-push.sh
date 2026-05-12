#!/usr/bin/env bash
# Claude Code stop hook: commit changes to feature-add/infra and open a PR.
# Remove the osascript block to make this fully automatic once you're comfortable.

set -euo pipefail

PROJECT_DIR="/Users/smyndlo/Documents/Dev-projects/ecs-fargate-project"
BRANCH="feature-add/infra"
BASE="main"

cd "$PROJECT_DIR"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "✗ 'gh' CLI not found. Install with: brew install gh && gh auth login" >&2
  exit 1
fi
if ! gh auth status &>/dev/null; then
  echo "✗ 'gh' not authenticated. Run: gh auth login" >&2
  exit 1
fi

# ── Skip if working tree is clean ─────────────────────────────────────────────
if git diff --quiet 2>/dev/null && \
   git diff --staged --quiet 2>/dev/null && \
   [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

# ── Review summary ────────────────────────────────────────────────────────────
echo ""
echo "┌──────────────────────────────────────────────┐"
echo "│  Claude Code — uncommitted changes detected  │"
echo "└──────────────────────────────────────────────┘"
echo ""
git status --short
echo ""
git diff --stat
echo ""

# ── Approval dialog (remove this block to skip manual approval) ───────────────
RESULT=$(osascript <<'EOF'
  display dialog "Push changes to 'feature-add/infra' and open a PR to main?\n\nReview the diff in VS Code Source Control (Ctrl+Shift+G) before confirming." \
    buttons {"Skip", "Push & PR"} \
    default button "Push & PR" \
    with title "Claude Code → GitHub PR" \
    with icon caution
EOF
) || true

if [[ "$RESULT" != *"Push"* ]]; then
  echo "↩  Push skipped. Commit manually when ready."
  exit 0
fi

# ── Switch to feature branch (create if it doesn't exist yet) ─────────────────
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
fi

# ── Commit ────────────────────────────────────────────────────────────────────
CHANGED=$(git diff --stat HEAD 2>/dev/null | tail -1 | xargs 2>/dev/null || echo "infrastructure changes")
git add -A
git commit -m "chore: ${CHANGED} — $(date +'%Y-%m-%d %H:%M')"

# ── Push branch ───────────────────────────────────────────────────────────────
git push -u origin "$BRANCH"
echo "✓ Pushed to $BRANCH"

# ── Open PR if one doesn't already exist ──────────────────────────────────────
if gh pr view "$BRANCH" --json state --jq '.state' 2>/dev/null | grep -q "OPEN"; then
  PR_URL=$(gh pr view "$BRANCH" --json url --jq '.url')
  echo "↩  PR already open — $PR_URL"
else
  PR_URL=$(gh pr create \
    --base  "$BASE" \
    --head  "$BRANCH" \
    --title "feat: infrastructure changes — $(date +'%Y-%m-%d')" \
    --body "$(cat <<'BODY'
## Summary
Automated PR from Claude Code.

Review the Terraform plan output in the comment below before merging.

## Checklist
- [ ] Plan output looks correct (no unintended replacements)
- [ ] No secrets or credentials in the diff
- [ ] Ready to merge to main
BODY
    )")
  echo "✓ PR created — $PR_URL"
fi
