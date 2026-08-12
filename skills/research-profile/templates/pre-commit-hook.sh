#!/usr/bin/env bash
#
# research-profile — pre-commit privacy guard (bash 3.2 compatible)
#
# Refuses to commit files that match private/embargoed patterns. Catches
# accidents the .gitignore alone cannot (e.g., `git add -f` of an ignored
# file, or files added before the gitignore rule existed).
#
# Install in your wiki repo:
#   cp templates/pre-commit-hook.sh <wiki>/.git/hooks/pre-commit
#   chmod +x <wiki>/.git/hooks/pre-commit
#
# Bypass once with: git commit --no-verify
# (Use only when you intentionally want to commit a flagged file.
# Never bypass for sensitivity: embargoed pages.)

set -euo pipefail

violations=0

# --- Pattern 1: filename matches *.private.md or *.local.md ---
private_msg=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    private_msg="$private_msg  $f
"
done < <(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(private|local)\.md$' || true)

if [[ -n "$private_msg" ]]; then
    {
        echo "❌ research-profile pre-commit: refusing to commit private files."
        echo ""
        echo "These files match *.private.md or *.local.md (gitignored by default;"
        echo "for incoming referee reports, drafts not wanted in history, etc.):"
        echo ""
        printf '%s' "$private_msg"
        echo ""
        echo "If you truly want them tracked, rename to a non-private name AND"
        echo "remove the matching line from .gitignore."
        echo "Bypass once: git commit --no-verify"
    } >&2
    violations=1
fi

# --- Pattern 2: file frontmatter contains `sensitivity: embargoed` ---
embargo_msg=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [[ -f "$f" ]] && head -n 30 "$f" 2>/dev/null \
        | grep -qE '^[[:space:]]*sensitivity:[[:space:]]*embargoed[[:space:]]*$'; then
        embargo_msg="$embargo_msg  $f
"
    fi
done < <(git diff --cached --name-only --diff-filter=ACM | grep -E '\.md$' || true)

if [[ -n "$embargo_msg" ]]; then
    {
        echo "❌ research-profile pre-commit: refusing to commit embargoed files."
        echo ""
        echo "These files have 'sensitivity: embargoed' in their frontmatter:"
        echo ""
        printf '%s' "$embargo_msg"
        echo ""
        echo "Remove the embargo (change to private/public) when the period expires,"
        echo "or move the content to a *.private.md file. Avoid --no-verify here."
    } >&2
    violations=1
fi

exit $violations
