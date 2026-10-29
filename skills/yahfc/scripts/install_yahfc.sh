#!/bin/bash
# install_yahfc.sh
#
# Provision YAHFC and its optical-model engine Frescox: clone both at pinned
# commits, build them, prove the pair runs, and print on the last four lines
#   YAHFC=<path to YAHFC.x>
#   FRESCOX=<path to frescox>
#   YAHFC_DIR=<YAHFC source tree>
#   YAHFC_DATA=<YAHFC data directory, with trailing slash>
# run_yahfc.sh and verify_yahfc.sh parse those.
#
# YAHFC is W. E. Ormand's Monte Carlo Hauser-Feshbach code (LLNL, MIT licence,
# github.com/LLNL/Yet-Another-Hauser-Feshbach-Code; LLNL-TR-824700). At run time
# it writes FRESCO-style decks and calls a binary named `frescox` from PATH to
# get transmission coefficients. That must be Frescox (github.com/LLNL/Frescox,
# GPL-2.0), not Ian Thompson's fresco, which the `fresco` skill builds. Both
# binaries live in this skill's own cache bin directory; nothing is written to
# ~/bin and nothing on the user's PATH is replaced.
#
# THE PATH-LENGTH TRAP. YAHFC appends one more '/' and Coupled-Channels.txt to
# YAHFC_DATA in a 132-character buffer (fresco_make_tco.f90:136, :367), so with
# the default coupled-channels file a data path of 111 characters (trailing
# slash included) dies at line 372 with "Cannot open file ''"; 110 runs (both
# measured 2026-10-29). A local cc_file avoids it. This script refuses a root
# whose data path exceeds 110, rather than produce an install that fails.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ROOT_DIR="${YAHFC_ROOT:-$HOME/.cache/fusion/yahfc}"
YAHFC_REPO="${YAHFC_REPO:-https://github.com/LLNL/Yet-Another-Hauser-Feshbach-Code.git}"
FRESCOX_REPO="${FRESCOX_REPO:-https://github.com/LLNL/Frescox.git}"
# Pinned commits. The benchmark numbers in references/verification.md were
# measured on exactly these; change them only together with a re-measurement.
YAHFC_COMMIT="${YAHFC_COMMIT:-18af2fea77d0263986648b057c06bd96f87ae8e0}"
FRESCOX_COMMIT="${FRESCOX_COMMIT:-eca88f3d3483c4b817051734c698845abcecee5d}"

SRCDIR="$ROOT_DIR/YAHFC"
FXDIR="$ROOT_DIR/Frescox"
BINDIR="$ROOT_DIR/bin"
BIN="$BINDIR/YAHFC.x"
FXBIN="$BINDIR/frescox"
DATADIR="$SRCDIR/Data/"

if [ "${#DATADIR}" -gt 110 ]; then
  echo "install_yahfc: data path '$DATADIR' is ${#DATADIR} characters; YAHFC fails" >&2
  echo "  from 111 on (132-character buffer). Set YAHFC_ROOT to a shorter directory." >&2
  exit 1
fi

# Prove the pair works rather than assuming presence means it works: a 200-event
# n+90Zr run at 14 MeV in a scratch directory. Needs a clean exit, the closing
# banner, every event accounted for, and a transmission-coefficient file written
# by frescox. Runs on the cache fast path too, so a stale or broken cached
# binary is rebuilt instead of handed out.
probe () {
  local d rc; d="$(mktemp -d)"
  printf '%s\n' "file probe" "target Zr90" "projectile n" "proj_eminmax 14.0 14.0 1.0" \
    "num_mc_samp 200" "ran_seed 1" "xs_only y" "end" > "$d/in.txt"
  set +e
  ( cd "$d" && LC_ALL=C LANG=C PATH="$BINDIR:$PATH" YAHFC_DIR="$SRCDIR" YAHFC_DATA="$DATADIR" \
      "$BIN" < in.txt > out.log 2> err.log )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "install_yahfc: YAHFC.x exited $rc on the probe run" >&2
    grep -a -v '^ *$' "$d/out.log" | tail -5 >&2; rm -rf "$d"; return 1
  fi
  if ! grep -a -q "That's all Folks" "$d/out.log" || ! grep -a -q "All events are accounted for" "$d/out.log"; then
    echo "install_yahfc: probe run did not complete cleanly" >&2
    grep -a -v '^ *$' "$d/out.log" | tail -5 >&2; rm -rf "$d"; return 1
  fi
  if ! grep -a -q "There were no events that violated energy conservation" "$d/out.log"; then
    echo "install_yahfc: probe run violated energy conservation" >&2; rm -rf "$d"; return 1
  fi
  # stderr may carry only YAHFC's own mkdir/rm chatter (see run_yahfc.sh)
  if grep -a -v -E "^mkdir: (cannot create directory .)?Fresco-files.?: File exists$|^rm: (cannot remove .)?(fort\.\*|90Zr).?: No such file or directory$" "$d/err.log" | grep -q .; then
    echo "install_yahfc: probe wrote unexpected stderr:" >&2; head -3 "$d/err.log" >&2; rm -rf "$d"; return 1
  fi
  # Frescox error files may hold only gfortran's note on harmless IEEE flags
  if cat "$d"/Fresco-files/*_fresco_err.out 2>/dev/null | grep -v -E '^Note: The following floating-point exceptions are signalling:( (IEEE_DENORMAL|IEEE_UNDERFLOW_FLAG|IEEE_INEXACT_FLAG))+$' | grep -q .; then
    echo "install_yahfc: frescox wrote errors during the probe" >&2; rm -rf "$d"; return 1
  fi
  if [ ! -s "$d/nZr90.tcoef" ]; then
    echo "install_yahfc: probe wrote no nZr90.tcoef, so frescox did not run" >&2
    rm -rf "$d"; return 1
  fi
  rm -rf "$d"; return 0
}

emit () {
  echo "YAHFC=$BIN"
  echo "FRESCOX=$FXBIN"
  echo "YAHFC_DIR=$SRCDIR"
  echo "YAHFC_DATA=$DATADIR"
}

# Both artifacts are required: a cache holding YAHFC.x but not frescox (or the
# reverse) is incomplete, and the FRESCO skill once shipped exactly that bug
# (it checked one binary while installing two).
# The fast path also requires both source trees at the pinned commits with no
# tracked-file edits, so changing a pin (or editing the source) forces a rebuild.
at_pin () { [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" = "$2" ] && git -C "$1" diff --quiet HEAD 2>/dev/null; }
if [ -x "$BIN" ] && [ -x "$FXBIN" ] && [ -d "$DATADIR" ] && [ -z "${YAHFC_FORCE:-}" ] \
   && at_pin "$SRCDIR" "$YAHFC_COMMIT" && at_pin "$FXDIR" "$FRESCOX_COMMIT"; then
  if probe; then emit; exit 0; fi
  echo "install_yahfc: cached install failed its probe; rebuilding" >&2
fi

for t in git make gfortran; do
  command -v "$t" >/dev/null || { echo "install_yahfc: '$t' is required" >&2; exit 1; }
done

# Clone one repository at one exact commit (shallow fetch of that commit).
fetch_at () {
  local repo="$1" dir="$2" commit="$3"
  if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null)" = "$commit" ] \
     && git -C "$dir" diff --quiet HEAD 2>/dev/null; then
    return 0
  fi
  rm -rf "$dir"; mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$repo"
  git -C "$dir" fetch -q --depth 1 origin "$commit" || {
    echo "install_yahfc: could not fetch $commit from $repo" >&2; return 1; }
  git -C "$dir" checkout -q FETCH_HEAD
}

mkdir -p "$ROOT_DIR" "$BINDIR"
fetch_at "$YAHFC_REPO" "$SRCDIR" "$YAHFC_COMMIT"
fetch_at "$FRESCOX_REPO" "$FXDIR" "$FRESCOX_COMMIT"
[ -f "$SRCDIR/Src/Makefile" ] && [ -d "$DATADIR" ] || { echo "install_yahfc: YAHFC source incomplete" >&2; exit 1; }
[ -f "$FXDIR/source/makefile" ] || { echo "install_yahfc: Frescox source incomplete" >&2; exit 1; }

# Frescox: the upstream gfortran recipe. Its link line names a macOS SDK
# directory; on Linux that is an unused -L and only a warning.
( cd "$FXDIR/source" && make clean > /dev/null 2>&1; make MACH=gfortran > build.log 2>&1 ) || {
  echo "install_yahfc: Frescox build failed; see $FXDIR/source/build.log" >&2
  grep -a -iE "error" "$FXDIR/source/build.log" | head -10 >&2; exit 1; }
[ -x "$FXDIR/source/frescox" ] || { echo "install_yahfc: no frescox after build" >&2; exit 1; }
cp "$FXDIR/source/frescox" "$FXBIN"

# YAHFC: the upstream Makefile and its default flags (-Ofast). On the L1 test
# case, other optimisation levels changed library numbers by at most ~2e-7; see
# references/verification.md for the measured breakdown.
( cd "$SRCDIR/Src" && make clean > /dev/null 2>&1; make YAHFC YAHFC_BIN_DIR="$BINDIR" > build.log 2>&1 ) || {
  echo "install_yahfc: YAHFC build failed; see $SRCDIR/Src/build.log" >&2
  grep -a -iE "error" "$SRCDIR/Src/build.log" | head -10 >&2; exit 1; }
[ -x "$BIN" ] || { echo "install_yahfc: no YAHFC.x after build" >&2; exit 1; }

probe || { echo "install_yahfc: freshly built install failed its probe" >&2; exit 1; }
emit
