#!/bin/bash
# verify_pikoe.sh [case ...]
#
# Clean-room verification: fresh workdir with no pre-existing output, run one or
# more of the distributed sample decks through run_pikoe.sh, and compare the
# extracted anchors against the pinned values in references/verification.md.
#
# Cases: TDXnorm TDXinv QDXinv MD MD100
# With no argument, runs the three fast cases (TDXnorm TDXinv QDXinv), each a
# few seconds. MD and MD100 are momentum-distribution runs and take about an
# hour each, so they are opt-in.
#
# NOTE ON WHAT THIS PROVES. pikoe ships no reference output (its readme
# documents tbl_*.dat and *.outlist inside every sample directory, and neither
# is in the archive). The pins are therefore values established here and
# cross-checked against the published figures of the CPC paper, not distributed
# reference numbers. This is a regression check plus a coarse physics check.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"

# macOS ships bash 3.2, which has no associative arrays. Keep this a case
# statement so the skill runs on a stock Mac as well as on Linux.
deck_for () {
  case "$1" in
    TDXnorm) echo 12Cp2pTDXnorm.cnt ;;
    TDXinv)  echo 12Cp2pTDXinv.cnt ;;
    QDXinv)  echo 12Cp2pQDXinv.cnt ;;
    MD)      echo 12Cp2pMD.cnt ;;
    MD100)   echo 12Cp2pMD100.cnt ;;
    *)       echo "" ;;
  esac
}
KNOWN_CASES="TDXnorm TDXinv QDXinv MD MD100"

if [ $# -eq 0 ]; then
  CASES=(TDXnorm TDXinv QDXinv)
else
  CASES=("$@")
fi

TMP="$(mktemp -d -t pikoe-verify)"
trap 'rm -rf "$TMP"' EXIT

fail=0
checked=0
skipped=0
for case in "${CASES[@]}"; do
  deck="$(deck_for "$case")"
  if [ -z "$deck" ]; then
    echo "unknown case: $case (known: $KNOWN_CASES)" >&2
    fail=1
    continue
  fi
  src="$SKILL/examples/$deck"
  [ -f "$src" ] || { echo "missing example deck: $src" >&2; fail=1; continue; }

  echo "== $case ($deck)"
  work="$TMP/$case"
  # Clean room by construction: $work does not exist yet, so no reference file
  # can be sitting there for the run to be compared against itself.
  [ -e "$work" ] && { echo "workdir already exists, aborting: $work" >&2; exit 1; }

  if ! bash "$HERE/run_pikoe.sh" "$src" "$work" > "$TMP/$case.log" 2>&1; then
    echo "  RUN FAILED"
    sed 's/^/    /' "$TMP/$case.log"
    fail=1
    continue
  fi

  set +e
  python3 "$HERE/check_pikoe.py" "$case" "$work/case"
  crc=$?
  set -e
  case "$crc" in
    0) checked=$((checked + 1)) ;;
    3) echo "  SKIPPED (no pin recorded for this case)"
       skipped=$((skipped + 1)) ;;
    *) fail=1 ;;
  esac
done

if [ "$fail" -ne 0 ]; then
  echo "VERIFY FAILED"
  exit 1
fi
if [ "$checked" -eq 0 ]; then
  echo "VERIFY INCONCLUSIVE: $skipped case(s) ran but nothing was checked against a pin"
  exit 2
fi
echo "VERIFY OK ($checked checked, $skipped skipped)"
