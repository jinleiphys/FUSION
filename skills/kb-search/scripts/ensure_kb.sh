#!/bin/bash
# ensure_kb.sh: find FUSION's offline knowledge base, downloading it on first use.
#
# The pages are not inside the plugin: they live on the `kb` branch of the FUSION
# repository and are fetched once into a cache, so installing or updating the plugin
# never copies 600 MB. Prints the directory on the last line as
#   KB_DIR=<absolute path>
#
# Lookup order:
#   1. $FUSION_KB_DIR, if set (must hold a valid knowledge base, else this fails).
#   2. kb-wiki/ at the root of a FUSION development clone (this skill's ../../..).
#   3. the cache, ${FUSION_KB_CACHE:-~/.cache/fusion/kb-wiki}; downloaded there
#      (git shallow clone of the kb branch, about 250 MB) if absent.
#
#   ensure_kb.sh            locate, download if needed
#   ensure_kb.sh --update   refresh the cached copy to the newest snapshot
#   ensure_kb.sh --check    locate only; exit 1 instead of downloading
#
# A download is verified against the MANIFEST the snapshot carries (page and topic
# counts, total file count) before it is moved into place. A partial knowledge base
# still answers queries, just with pages silently missing, so a copy that does not
# match is refused rather than used. Behind a proxy, git honours https_proxy.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
URL="${FUSION_KB_URL:-https://github.com/jinleiphys/FUSION.git}"
CACHE="${FUSION_KB_CACHE:-$HOME/.cache/fusion/kb-wiki}"
MODE="${1:-}"

log () { echo "ensure_kb: $*" >&2; }
die () { log "$*"; exit 1; }

case "$CACHE" in
  ""|"/"|"$HOME"|"$HOME/"|"/usr"*|"/etc"*|"/bin"*|"/System"*|"/Users"|"/home") die "refusing unsafe FUSION_KB_CACHE='$CACHE'" ;;
  /*) : ;;
  *) die "FUSION_KB_CACHE must be an absolute path" ;;
esac

manifest_get () { sed -n "s/^$2=//p" "$1/MANIFEST" | head -1; }
count_md () { find "$1" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }

# Fast check, run on every call: the page and topic counts match the MANIFEST.
quick_ok () {
  local d="$1"
  [ -d "$d/papers" ] && [ -d "$d/topics" ] || return 1
  [ -f "$d/MANIFEST" ] || return 1
  [ "$(count_md "$d/papers")" = "$(manifest_get "$d" papers)" ] || return 1
  [ "$(count_md "$d/topics")" = "$(manifest_get "$d" topics)" ] || return 1
}

# Full check, run after a download: also every tracked file present and unmodified.
full_ok () {
  local d="$1" n
  quick_ok "$d" || { log "page or topic count does not match MANIFEST in $d"; return 1; }
  n=$(git -C "$d" ls-files | wc -l | tr -d ' ')
  [ "$n" = "$(manifest_get "$d" files)" ] || { log "file count $n, MANIFEST says $(manifest_get "$d" files)"; return 1; }
  [ -z "$(git -C "$d" status --porcelain --untracked-files=no)" ] || { log "tracked files missing or modified in $d"; return 1; }
}

emit () { echo "KB_DIR=$(cd "$1" && pwd)"; exit 0; }

# 1. explicit override
if [ -n "${FUSION_KB_DIR:-}" ]; then
  [ -d "$FUSION_KB_DIR/papers" ] || die "FUSION_KB_DIR=$FUSION_KB_DIR has no papers/"
  emit "$FUSION_KB_DIR"
fi

# 2. a development clone keeps kb-wiki/ at its root (no MANIFEST there; it is the
#    working copy the build scripts write)
DEV="$HERE/../../../kb-wiki"
if [ "$MODE" != "--update" ] && [ -d "$DEV/papers" ] && [ -d "$DEV/topics" ]; then
  emit "$DEV"
fi

# 3. the cache
if [ "$MODE" = "--update" ]; then
  [ -d "$CACHE/.git" ] || die "no cached copy at $CACHE to update; run without --update first"
  log "fetching the newest snapshot into $CACHE"
  old=$(git -C "$CACHE" rev-parse --short HEAD)
  git -C "$CACHE" fetch -q --depth 1 origin kb || die "fetch failed (network or proxy?); the cached copy is unchanged"
  git -C "$CACHE" reset -q --hard FETCH_HEAD
  full_ok "$CACHE" || die "updated copy failed verification; delete $CACHE and rerun to download afresh"
  log "snapshot $old -> $(git -C "$CACHE" rev-parse --short HEAD) ($(manifest_get "$CACHE" date))"
  emit "$CACHE"
fi

if quick_ok "$CACHE"; then emit "$CACHE"; fi

[ "$MODE" = "--check" ] && die "knowledge base not downloaded yet (would go to $CACHE)"
[ -e "$CACHE" ] && die "$CACHE exists but is not a complete knowledge base; delete it and rerun"
command -v git >/dev/null || die "git is required to download the knowledge base"

log "first use: downloading the knowledge base (about 250 MB) into $CACHE"
mkdir -p "$(dirname "$CACHE")"
TMP="$(mktemp -d "$(dirname "$CACHE")/.kb-download.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
git clone -q --depth 1 --branch kb --single-branch "$URL" "$TMP/kb" \
  || die "download failed (network or proxy?). Nothing was kept; rerun to retry"
full_ok "$TMP/kb" || die "downloaded copy failed verification; nothing was kept"
mv "$TMP/kb" "$CACHE"
log "done: $(manifest_get "$CACHE" papers) papers, $(manifest_get "$CACHE" topics) topics, snapshot $(manifest_get "$CACHE" date)"
emit "$CACHE"
