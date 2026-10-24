#!/bin/bash
# verify_band.sh: benchmark the BAND environment against the anchors in references/verification.md.
#
#   verify_band.sh            fast checks (~20 s): rose n+90Zr vs FRESCO/COLOSS, surmise exact
#                             posterior, Taweret vs the SAMBA paper's equations
#   verify_band.sh --paper    also the ROSE paper's Fig. 5 (15,15) claim (~3 min)
#   verify_band.sh --full     also the shipped test suites of surmise (303) and Taweret (28)
#
# A check passes only if its script exits 0 AND prints its OK line; a suite passes only with the
# exact pinned count of passed tests and no failures. Prints VERIFY OK or VERIFY FAILED last.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EX="$HERE/../examples"
PAPER=0; FULL=0
for a in "$@"; do case "$a" in --paper) PAPER=1 ;; --full) FULL=1; PAPER=1 ;; *) echo "unknown option $a" >&2; exit 2 ;; esac; done

PY="$(bash "$HERE/install_band.sh" | sed -n 's/^BAND_PYTHON=//p')"
[ -x "$PY" ] || { echo "VERIFY FAILED: no BAND environment"; exit 1; }
export PATH="$(dirname "$PY"):$PATH"   # openbt runs `mpirun`; a conda env keeps it in its bin/
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
fail=0

check () {  # name script marker [args...]
  local name="$1" script="$2" marker="$3"; shift 3
  local out rc
  out="$(cd "$WORK" && "$PY" "$EX/$script" "$@" 2>&1)"; rc=$?
  echo "$out" | grep -v -iE "warning|it/s\]" | grep -E "sigma_R|ESS|exact|surmise mean|F\(g\)|series|mixing|gap|metric|emulator|seed" | sed 's/^/    /'
  if [ $rc -eq 0 ] && echo "$out" | grep -qx "$marker OK"; then echo "PASS  $name"; else echo "FAIL  $name (exit $rc)"; fail=1; fi
}

suite () {  # name module expected_passed
  local name="$1" mod="$2" want="$3" out line rc
  out="$(cd "$WORK" && "$PY" -m pytest -q -p no:cacheprovider --pyargs "$mod" 2>&1)"; rc=$?
  line="$(echo "$out" | grep -E "passed|failed|error" | tail -1)"
  # pytest's own exit status AND the exact count: a session can print "N passed" and still fail
  if [ $rc -eq 0 ] && echo "$line" | grep -qE "^=* *$want passed" && ! echo "$line" | grep -qE "failed|error"; then
    echo "PASS  $name: $line"
  else
    echo "FAIL  $name: ${line:-no summary} (pytest exit $rc; expected exit 0 and exactly $want passed)"; fail=1
  fi
}

check "rose high-fidelity, n+90Zr KD02 50 MeV vs FRESCO/COLOSS" rose_n90zr_hifi.py "ROSE N90ZR"
check "surmise, exact Gaussian posterior" surmise_linear_posterior.py "SURMISE POSTERIOR" 7
check "Taweret, SAMBA toy vs the paper's equations" taweret_samba_mixing.py "TAWERET SAMBA"
[ $PAPER = 1 ] && check "rose, PRC 109 044612 Fig. 5 (15,15)" rose_paper_fig5.py "ROSE FIG5" 13
if [ $FULL = 1 ]; then
  # --pyargs runs the INSTALLED package's tests. Run from a source checkout instead and pytest
  # imports the uncompiled tree: surmise then shows 92 failures and 20 errors that are not real.
  suite "surmise shipped tests" surmise.tests 303
  suite "Taweret shipped tests (includes SAMBA reference arrays)" Taweret.tests 28
fi

[ $fail = 0 ] && echo "VERIFY OK" || echo "VERIFY FAILED"
exit $fail
