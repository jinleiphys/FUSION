#!/bin/bash
# run_sky3d.sh
#
# Run a Sky3D deck in an isolated working directory and assert that the output is
# usable. Usage:
#
#   run_sky3d.sh --deck <input file> [--workdir <dir>] [--root <dir>]
#                [--fragment <file>[:<dest>]]... [--allow-unconverged]
#
# --deck        the namelist input. It is COPIED to <workdir>/for005 because Sky3D
#               opens the literal filename 'for005' in the current directory; it
#               does NOT read standard input. See references/failure-modes.md.
# --workdir     defaults to a fresh mktemp -d. Must be new or empty: Sky3D writes
#               its outputs by fixed name, so reusing a directory silently mixes
#               two runs. Sky3D writes for006, the .res tables, the *.tdd density
#               snapshots and the wavefunction file into it.
# --root        the sandbox a fragment destination may not escape. Defaults to the
#               workdir. Give it when a deck reads a fragment through a relative
#               path that leaves the workdir, which the shipped collision deck
#               does with '../Static/O16': then --root is the directory holding
#               both Static/ and Collision/.
# --fragment    stage a wavefunction file a &fragments deck needs. "path:dest"
#               places it at <workdir>/dest. dest is resolved canonically and must
#               land inside --root, symlinks included. Repeatable.
# --allow-unconverged
#               accept a static run that hits maxiter without reaching serr, and a
#               dynamic run that stops before nt without the separation criterion.
#               Off by default, because an unconverged run exits 0 and prints a
#               full, entirely plausible final block.
#
# Prints RESULT_DIR= and RESULT_FOR006= on the last two lines.
#
# Sky3D is CPC non-profit licensed, not open source; see install_sky3d.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DECK=""
WORKDIR=""
ROOT=""
ALLOW_UNCONVERGED=0
FRAGMENTS=()

log () { echo "run_sky3d: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --deck)     DECK="${2:-}"; shift 2 ;;
    --workdir)  WORKDIR="${2:-}"; shift 2 ;;
    --root)     ROOT="${2:-}"; shift 2 ;;
    --fragment) FRAGMENTS+=("${2:-}"); shift 2 ;;
    --allow-unconverged) ALLOW_UNCONVERGED=1; shift ;;
    -h|--help)  sed -n '2,32p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$DECK" ] || die "--deck is required"
[ -f "$DECK" ] || die "deck '$DECK' does not exist"
DECK="$(cd "$(dirname "$DECK")" && pwd)/$(basename "$DECK")"
# Fortran namelist names are case-insensitive, so '&MAIN' is a valid deck.
grep -qi '&main' "$DECK" || die "deck '$DECK' has no &main namelist; is it really a Sky3D input?"

if [ -n "${SKY3D:-}" ]; then
  BIN="$SKY3D"
else
  BIN="$("$HERE/install_sky3d.sh" | sed -n 's/^SKY3D=//p')"
fi
[ -x "$BIN" ] || die "no usable Sky3D executable (SKY3D='${SKY3D:-unset}')"

# ------------------------------------------------------------------- workdir
if [ -z "$WORKDIR" ]; then
  WORKDIR="$(mktemp -d)"
else
  if [ -e "$WORKDIR" ]; then
    [ -d "$WORKDIR" ] || die "workdir '$WORKDIR' exists and is not a directory"
    # Refuse a directory that already holds anything: Sky3D's fixed output names
    # would mix this run with whatever is already there.
    if [ -n "$(ls -A "$WORKDIR" 2>/dev/null)" ]; then
      die "workdir '$WORKDIR' is not empty; Sky3D writes fixed filenames, so give it a fresh directory"
    fi
  else
    mkdir -p "$WORKDIR"
  fi
fi
WORKDIR="$(cd "$WORKDIR" && pwd -P)"

if [ -z "$ROOT" ]; then
  ROOT="$WORKDIR"
else
  [ -d "$ROOT" ] || die "--root '$ROOT' does not exist"
  ROOT="$(cd "$ROOT" && pwd -P)"
  case "$WORKDIR/" in
    "$ROOT"/*) : ;;
    *) die "--workdir '$WORKDIR' is not inside --root '$ROOT'" ;;
  esac
fi

cp "$DECK" "$WORKDIR/for005"

# ------------------------------------------------------------------ fragments
# Canonicalize the destination's parent and require it to sit inside --root. This
# is what makes '../Static/O16' usable without opening a path-traversal hole: a
# textual ".." ban would reject the shipped collision deck's own layout, and a
# textual ban alone would not stop a symlinked component anyway.
# Resolve a path that may not exist yet WITHOUT creating it: walk up to the
# nearest existing ancestor, canonicalize that, then re-append the missing tail.
# The previous version called mkdir -p first, so a rejected destination had
# already created directories outside the sandbox by the time it was rejected.
resolve_noncreating () {
  local path="$1" tail="" base
  while [ ! -d "$path" ]; do
    base="$(basename "$path")"
    path="$(dirname "$path")"
    tail="$base${tail:+/$tail}"
    [ "$path" = "/" ] && break
  done
  local real; real="$(cd "$path" 2>/dev/null && pwd -P)" || return 1
  if [ -n "$tail" ]; then echo "$real/$tail"; else echo "$real"; fi
}

for spec in ${FRAGMENTS+"${FRAGMENTS[@]}"}; do
  src="${spec%%:*}"
  dest="${spec#*:}"
  [ "$dest" = "$spec" ] && dest="$(basename "$src")"
  [ -f "$src" ] || die "fragment file '$src' does not exist"
  case "$dest" in
    /*) die "fragment destination '$dest' must be relative to the working directory" ;;
    "") die "fragment destination is empty" ;;
  esac
  destdir="$(resolve_noncreating "$WORKDIR/$(dirname "$dest")")" \
    || die "cannot resolve the directory for fragment destination '$dest'"
  case "$destdir/" in
    "$ROOT"/*) : ;;
    *) die "fragment destination '$dest' resolves to '$destdir', outside --root '$ROOT'" ;;
  esac
  mkdir -p "$destdir" || die "cannot create '$destdir'"
  cp "$src" "$destdir/$(basename "$dest")"
done

# ---------------------------------------------------------------------- run
log "running $(basename "$BIN") in $WORKDIR"
set +e
( cd "$WORKDIR" && "$BIN" > for006 2> stderr.txt )
STATUS=$?
set -e

# shellcheck source=validate_sky3d_output.sh
. "$HERE/validate_sky3d_output.sh"

validate_sky3d_output "$WORKDIR" "$STATUS" "$ALLOW_UNCONVERGED" || exit 1

echo "RESULT_DIR=$WORKDIR"
echo "RESULT_FOR006=$WORKDIR/for006"
