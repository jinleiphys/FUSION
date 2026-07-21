#!/bin/bash
# verify_nlat.sh [case ...]
#
# Clean-room verification: run a distributed sample deck in a fresh workdir and
# compare against the reference output shipped in the install tree.
#
# Cases: local nonlocal
# With no argument, runs both.
#
# CLEAN ROOM MATTERS HERE MORE THAN USUAL. Each shipped deck names its own
# output directory, and that name is the sample directory itself. Running a deck
# from inside the unpacked tree overwrites the reference output with the run's
# own results, after which any comparison passes trivially and proves nothing.
# run_nlat.sh always runs in a fresh workdir, so the references stay pristine;
# this script additionally asserts the reference file it is about to compare
# against was not written by the run.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

deck_for () {
  case "$1" in
    local)    echo "LOCAL_SAMPLE/dp48Ca_10-0_DWBA.in" ;;
    nonlocal) echo "NONLOCAL_SAMPLE/dp48Ca_20-0_NL.in" ;;
    *)        echo "" ;;
  esac
}
refdir_for () {
  case "$1" in
    local)    echo "LOCAL_SAMPLE" ;;
    nonlocal) echo "NONLOCAL_SAMPLE" ;;
    *)        echo "" ;;
  esac
}
KNOWN_CASES="local nonlocal"

# Fingerprint the reference files by CONTENT. The first version hashed an
# `ls -l` listing, which only sees permissions, size and mtime, so an overwrite
# that preserved both went undetected. That is precisely the overwrite this
# guard exists to catch, so it must read the bytes.
fingerprint () {
  find "$1" -name '*.txt' -type f -exec shasum -a 256 {} + | sort | shasum -a 256
}

if [ $# -eq 0 ]; then
  CASES="local nonlocal"
else
  CASES="$*"
fi

BIN_LINE="$(bash "$HERE/install_nlat.sh")"
BIN="${BIN_LINE#NLAT=}"
SRCDIR="$(cd "$(dirname "$BIN")" && pwd)"

TMP="$(mktemp -d -t nlat-verify)"
trap 'rm -rf "$TMP"' EXIT

fail=0
for case in $CASES; do
  deck="$(deck_for "$case")"
  refname="$(refdir_for "$case")"
  if [ -z "$deck" ]; then
    echo "unknown case: $case (known: $KNOWN_CASES)" >&2
    fail=1
    continue
  fi
  src="$SRCDIR/$deck"
  ref="$SRCDIR/$refname"
  [ -f "$src" ] || { echo "missing deck: $src" >&2; fail=1; continue; }
  [ -d "$ref" ] || { echo "missing reference dir: $ref" >&2; fail=1; continue; }

  echo "== $case ($(basename "$deck"))"

  # Record the references' modification times, and confirm afterwards that the
  # run did not touch them. This is the direct check against the failure this
  # whole design exists to prevent.
  before="$(fingerprint "$ref")"

  work="$TMP/$case"
  if ! bash "$HERE/run_nlat.sh" "$src" "$work" > "$TMP/$case.log" 2>&1; then
    echo "  RUN FAILED"
    sed 's/^/    /' "$TMP/$case.log"
    fail=1
    continue
  fi

  after="$(fingerprint "$ref")"
  if [ "$before" != "$after" ]; then
    echo "  ABORT: the run modified the reference output in $ref."
    echo "  Any comparison from here is meaningless. Reinstall with NLAT_FORCE=1."
    fail=1
    continue
  fi

  outdir="$work/$refname"
  [ -d "$outdir" ] || outdir="$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -1)"

  # One declared, pinned deviation, for the nonlocal case only. The distributed
  # NONLOCAL_SAMPLE/TransferCS.txt holds 180 angles while the shipped deck and
  # code produce 179. The reference files there are dated 2016-04-12, a month
  # BEFORE the deck they ship with (2016-05-13), so they were generated with an
  # earlier deck or code; the LOCAL_SAMPLE references are same-day as their deck
  # and have 179, matching. The 179 shared angles agree to 1.3e-12, so this is a
  # stale-reference packaging fault upstream, not a physics disagreement.
  # The counts are pinned so any OTHER length change is still a hard failure.
  extra=""
  if [ "$case" = "nonlocal" ]; then
    extra="--prefix-ok TransferCS.txt:360:358"
  fi

  if ! python3 "$HERE/compare_nlat.py" "$ref" "$outdir" $extra; then
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "VERIFY FAILED"
  exit 1
fi
echo "VERIFY OK"
