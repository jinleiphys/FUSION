#!/bin/bash
# publish_kb.sh: commit the local kb-wiki/ as the next snapshot on the `kb` branch.
#
# The knowledge base does not live on `main`. `main` is the plugin, and every plugin
# install copies its whole tree, so 600 MB of pages there would be copied on every
# install and every update, once per agent. The pages live on the `kb` branch with the
# page tree at its root, and the kb-search skill shallow-clones that branch into
# ~/.cache/fusion/kb-wiki the first time it is needed (skills/kb-search/scripts/ensure_kb.sh).
#
# Locally kb-wiki/ stays where the build scripts expect it (repo root, ignored on
# main). After a rebuild, run this, check the summary, then `git push origin kb`.
#
# A MANIFEST file is added at the branch root with the expected counts. ensure_kb.sh
# refuses a copy that does not match it: a partially downloaded knowledge base still
# answers queries, just with pages missing, which is worse than no answer.
#
# Usage: scripts/publish_kb.sh [--dry-run]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
KB="$REPO/kb-wiki"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

die () { echo "publish_kb: $*" >&2; exit 1; }
[ -d "$KB/papers" ] && [ -d "$KB/topics" ] || die "no kb-wiki/papers or kb-wiki/topics under $REPO"

papers=$(find "$KB/papers" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
topics=$(find "$KB/topics" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
[ "$papers" -gt 0 ] && [ "$topics" -gt 0 ] || die "empty papers/ or topics/"

IDX="$(mktemp -d)/index"
trap 'rm -rf "$(dirname "$IDX")"' EXIT
export GIT_INDEX_FILE="$IDX"
GIT=(git --git-dir="$REPO/.git" --work-tree="$KB")

# Stage the page tree (global excludes such as .DS_Store still apply).
(cd "$KB" && "${GIT[@]}" add -A .)
files=$(( $("${GIT[@]}" ls-files | wc -l) + 1 ))   # +1 for MANIFEST itself
src=$(git -C "$REPO" rev-parse --short HEAD)
manifest="papers=$papers
topics=$topics
files=$files
source=$src
date=$(date +%Y-%m-%d)
"
blob=$(printf '%s' "$manifest" | git --git-dir="$REPO/.git" hash-object -w --stdin)
"${GIT[@]}" update-index --add --cacheinfo 100644 "$blob" MANIFEST
tree=$("${GIT[@]}" write-tree)

parent=$(git -C "$REPO" rev-parse -q --verify refs/heads/kb || true)
if [ -n "$parent" ] && [ "$(git -C "$REPO" rev-parse "$parent^{tree}")" = "$tree" ]; then
  echo "publish_kb: kb branch already holds this tree, nothing to do"; exit 0
fi
echo "publish_kb: papers=$papers topics=$topics files=$files source=$src"
[ -n "$parent" ] && git -C "$REPO" diff --shortstat "$parent" "$tree" | sed 's/^/publish_kb: vs previous snapshot:/'
if [ "$DRY" = 1 ]; then echo "publish_kb: dry run, branch not moved"; exit 0; fi

msg="kb snapshot $(date +%Y-%m-%d): $papers papers, $topics topics (from main $src)"
if [ -n "$parent" ]; then
  commit=$(git -C "$REPO" commit-tree "$tree" -p "$parent" -m "$msg")
else
  commit=$(git -C "$REPO" commit-tree "$tree" -m "$msg")
fi
git -C "$REPO" update-ref refs/heads/kb "$commit" ${parent:+"$parent"}
echo "publish_kb: kb -> $(git -C "$REPO" rev-parse --short "$commit"). Publish with: git push origin kb"
