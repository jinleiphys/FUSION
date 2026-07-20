#!/bin/bash
# run_gsm.sh <target> <deck.in> [workdir]
#
# Build the requested GSM binary if needed, run it on a deck in a clean
# workdir, and print the result.  GSM codes read the deck on stdin and write
# everything to stdout, so the run is always
#     <binary> < deck.in > deck.out
# The shipped Exercises/*/**.out files are reference outputs, NEVER inputs;
# this script refuses to run in a directory that already holds the reference,
# so a crashed run can never be mistaken for a reproduction.
#
# Targets: one one-ptg res opt rotor gsm2 gsm2rel gsm1d gsm2d cc1d
#          (see install_gsm.sh for the dir/binary each maps to)
#
# Many-body decks name a workspace directory on their 4th line.  It must
# exist and hold the interaction files.  Pass GSM_WORKSPACE to have this
# script rewrite that line to a workspace it prepares from workspace_for_GSM.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

TARGET="${1:?usage: run_gsm.sh <target> <deck.in> [workdir]}"
DECK="${2:?usage: run_gsm.sh <target> <deck.in> [workdir]}"
WORK="${3:-$(pwd)/gsm-run}"
[ -f "$DECK" ] || { echo "no such deck: $DECK" >&2; exit 1; }

ROOT_LINE="$(bash "$HERE/install_gsm.sh" "$TARGET")"
ROOT="${ROOT_LINE#GSM_ROOT=}"

case "$TARGET" in
  one)     REL="Gamow_one/One_particle_dir/run_one" ;;
  one-ptg) REL="Gamow_one/One_particle_PTG_dir/run_one" ;;
  res)     REL="Gamow_one/resonances_dir/run_res" ;;
  opt)     REL="Gamow_one/optimization_code_dir/run_opt" ;;
  rotor)   REL="CC_rotor_dir/CC_rotor_exe" ;;
  gsm2)    REL="GSM_two_dir/GSM_two_exe" ;;
  gsm2rel) REL="GSM_two_relative_dir/GSM_two_relative_exe" ;;
  gsm1d)   REL="GSM_dir_1D/GSM_dir/GSM_exe" ;;
  gsm2d)   REL="GSM_dir_2D/GSM_dir/GSM_exe" ;;
  cc1d)    REL="GSM_dir_1D/CC_dir/CC_exe" ;;
  *) echo "unknown target: $TARGET" >&2; exit 2 ;;
esac
BIN="$ROOT/GSM_code/$REL"
[ -x "$BIN" ] || { echo "binary missing: $BIN" >&2; exit 1; }

base="$(basename "$DECK")"; stem="${base%.in}"
mkdir -p "$WORK"
# Clean-room guard: a stale reference in the workdir would let a failed run
# look like a perfect reproduction.
if [ -e "$WORK/$stem.out" ]; then
  echo "refusing to run: $WORK/$stem.out already exists (clean-room rule)." >&2
  echo "Use a fresh workdir, or move the reference elsewhere before comparing." >&2
  exit 3
fi
cp "$DECK" "$WORK/$base"

# Optional workspace rewrite for many-body decks.
if [ -n "${GSM_WORKSPACE:-}" ]; then
  mkdir -p "$GSM_WORKSPACE"
  cp -n "$ROOT"/workspace_for_GSM/* "$GSM_WORKSPACE"/ 2>/dev/null || true
  ws="${GSM_WORKSPACE%/}/"
  perl -pi -e "if (\$. == 4) { s|^\\s*\\S*\\s*$|$ws\n| }" "$WORK/$base"
  echo "workspace line set to: $(sed -n '4p' "$WORK/$base")" >&2
fi

cd "$WORK"
set +e
"$BIN" < "$base" > "$stem.out" 2> "$stem.err"
rc=$?
set -e

if [ -s "$stem.err" ]; then
  echo "== stderr ==" >&2
  head -20 "$stem.err" >&2
fi
if [ "$rc" -ne 0 ]; then
  echo "GSM exited with status $rc (139 = SIGSEGV, usually the finite() patch is missing" >&2
  echo "or the workspace directory on line 4 of the deck does not exist)" >&2
  echo "-- last lines produced --" >&2
  tail -5 "$stem.out" >&2
  exit "$rc"
fi

echo "== $WORK/$stem.out =="
cat "$stem.out"
