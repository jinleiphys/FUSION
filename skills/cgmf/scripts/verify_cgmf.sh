#!/bin/bash
# verify_cgmf.sh
#
# Run CGMF's benchmark and compare against pinned values.
#
# TIER. CGMF is unusual for a Monte Carlo code: it is deterministic (event i is
# seeded from i), so the same build and args give bit-identical output, and the
# repo SHIPS byte-exact .reference history files. This skill is therefore
# genuinely TIER 1 on regression: L1 reproduces the distributed reference output
# exactly, which GEF/pikoe/AZURE2 could never do. L2 adds a physics check on the
# average neutron multiplicity against the value the CGMF manual quotes.
#
# Caveat stated honestly: bit-exactness holds on a matching build. A different
# compiler, architecture or optimisation level can perturb the last
# floating-point digits of a Monte Carlo trajectory. Measured on this build,
# macOS/ARM reproduces the shipped reference (LANL-generated) exactly; if a
# future build does not, that is a platform difference to record, not
# necessarily a defect. verify runs its own clean case, it does not trust a
# pre-existing output file.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"

# CGMF_BIN / CGMFDATA may be supplied directly (used by the self-test to inject
# a stub binary); otherwise resolve them from the installer.
if [ -n "${CGMF_BIN:-}" ] && [ -n "${CGMFDATA:-}" ]; then
  BIN="$CGMF_BIN"; DATA="$CGMFDATA"
else
  INSTALL_OUT="$(bash "$HERE/install_cgmf.sh")"
  BIN="$(echo "$INSTALL_OUT" | sed -n 's/^CGMF=//p' | tail -1)"
  DATA="$(echo "$INSTALL_OUT" | sed -n 's/^CGMFDATA=//p' | tail -1)"
fi
SRC="${CGMF_SRC:-$(cd "$(dirname "$BIN")/../../.." 2>/dev/null && pwd)}"   # the cloned CGMF tree
[ -x "$BIN" ] && [ -d "$DATA" ] || { echo "verify_cgmf: no usable install" >&2; exit 1; }

FAIL=0
pass () { echo "  PASS  $1"; }
fail () { echo "  FAIL  $1"; FAIL=1; }

# Build the serial reference by concatenating the two shipped MPI-rank files, in
# rank order, which is exactly how the repo's own CTest reconstructs it.
serial_ref () {
  local testdir="$1" out="$2"
  cat "$SRC/utils/cgmf/tests/$testdir/histories.cgmf.parallel.0.reference" \
      "$SRC/utils/cgmf/tests/$testdir/histories.cgmf.parallel.1.reference" > "$out"
}

# exact_case <label> <testdir> <ZAID> <Einc> : run -n 40 and require byte-exact
# match to the shipped reference.
exact_case () {
  local label="$1" testdir="$2" zaid="$3" einc="$4"
  local d; d="$(mktemp -d)"
  serial_ref "$testdir" "$d/ref.0"
  ( cd "$d" && CGMFDATA="$DATA" "$BIN" -n 40 -e "$einc" -i "$zaid" -f h >/dev/null 2>err )
  if [ -s "$d/err" ]; then fail "$label: cgmf.x wrote to stderr"; rm -rf "$d"; return; fi
  if [ ! -f "$d/h.0" ]; then fail "$label: no history file produced"; rm -rf "$d"; return; fi
  if diff -q "$d/ref.0" "$d/h.0" >/dev/null; then
    pass "$label: 40-event history reproduces the shipped reference BIT-EXACTLY (tier 1)"
  else
    fail "$label: 40-event history differs from the shipped reference ($(diff "$d/ref.0" "$d/h.0" | grep -c '^<') lines)"
  fi
  rm -rf "$d"
}

echo "CGMF benchmark  [Talou et al., Comput. Phys. Commun. 269, 108087 (2021)]"

# --- L1: exact reproduction of the distributed reference output --------------
exact_case "L1a 252Cf(sf)"     cf252sf-events   98252 0.0
exact_case "L1b n_th+235U"     u235nf-th-events 92235 2.53e-8

# --- L2: physics, average total neutron multiplicity of 252Cf(sf) ------------
# Deterministic at fixed n, so pinned exactly; also within Monte Carlo error of
# the manual's converged 3.82 (start.rst, 1e6 events). n=500 -> SE ~ 0.056.
d="$(mktemp -d)"
( cd "$d" && CGMFDATA="$DATA" "$BIN" -n 500 -e 0.0 -i 98252 -f h > sum.out 2>err )
nu="$(sed -n 's/.*<nu>_tot = *\([0-9.eE+-]*\).*/\1/p' "$d/sum.out" | tail -1)"
if [ -z "$nu" ]; then
  fail "L2 could not read <nu>_tot from the summary"
else
  printf "  nu-bar_tot(252Cf sf, n=500): %s   [manual: 3.82 at 1e6]\n" "$nu"
  # regression pin (deterministic, exact to the summary's 2 decimals)
  if python3 -c "import sys; sys.exit(0 if abs(float('$nu')-3.78)<=0.01 else 1)"; then
    pass "L2a nu-bar reproduces this build's deterministic 3.78 at n=500"
  else
    fail "L2a nu-bar = $nu, pinned deterministic value is 3.78 at n=500"
  fi
  # physics sanity: consistent with the manual's converged value within MC error
  if python3 -c "import sys; sys.exit(0 if abs(float('$nu')-3.82)<=0.15 else 1)"; then
    pass "L2b nu-bar within Monte Carlo error of the manual's converged 3.82"
  else
    fail "L2b nu-bar = $nu is not within 0.15 of the published 3.82"
  fi
fi
rm -rf "$d"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "VERIFY OK  (tier 1: distributed reference reproduced bit-exactly)"
else
  echo "VERIFY FAILED"
fi
exit "$FAIL"
