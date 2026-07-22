#!/bin/bash
# verify_sides.sh
#
# TIER 2 benchmark. SIDES ships no reference output, so this verifies the code
# the way the 2026-07-20 tier-2 ruling and the 2026-07-21 cross-build standard
# prescribe: build integrity by cross-build agreement, plus a physics-consistency
# anchor, on the shipped n+40Ca 20 MeV nonlocal (Tian-Pang-Ma) example.
#
#   L1  the integral cross sections match the pinned reference (a REGRESSION gate,
#       not a re-run of the cross-build). The pin is the macOS/ARM64 gfortran 15.2
#       value; Linux/x86_64 gfortran 13.3 agrees to ~12 significant figures
#       (~1e-11 relative, recorded in references/verification.md). The gate is
#       1e-9 relative: two orders of margin over that observed agreement, and far
#       tighter than the percent-level shift a genuine regression makes.
#   L2  the neutron optical theorem TOTAL = ELASTIC + REACTION holds to ~1e-9
#       (a code-internal identity, no Coulomb for a neutron projectile).
#
# CONTENT IS THE VERDICT: parsed from the integral-cross-section file, never from
# exit status. State honestly what tier this is: input alignment + cross-build
# integrity + a physics identity, NOT a reproduction of a shipped reference
# number (the distribution ships none).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# pinned reference (macOS/ARM64 gfortran 15.2; Linux gfortran 13.3 agrees to ~1e-11)
RXN_REF=1115.7176002621441
ELA_REF=769.20018156053038
TOT_REF=1884.9177818226751

if [ -n "${SIDES_DIR:-}" ]; then
  DIR="$SIDES_DIR"
else
  INSTALL_OUT="$(bash "$HERE/install_sides.sh")" || { echo "verify_sides: install failed" >&2; exit 1; }
  DIR="$(echo "$INSTALL_OUT" | sed -n 's/^SIDES_DIR=//p' | tail -1)"
fi
BIN="$DIR/sides.x"
[ -x "$BIN" ] || { echo "verify_sides: no sides.x in $DIR" >&2; exit 1; }
[ -f "$DIR/INPUT" ] || { echo "verify_sides: shipped INPUT missing" >&2; exit 1; }

rm -f "$DIR"/INTEGRAL-CROSS-SECTION-*
set +e
( cd "$DIR" && ./sides.x < INPUT > verify.out 2> verify.err )
RC=$?
set -e
[ "$RC" -eq 0 ] || { echo "verify_sides: sides.x exited $RC" >&2; tail -8 "$DIR/verify.err" >&2; exit 1; }

ICF="$(ls -t "$DIR"/INTEGRAL-CROSS-SECTION-* 2>/dev/null | head -1)"
[ -n "$ICF" ] && [ -f "$ICF" ] || { echo "verify_sides: no integral-cross-section file produced" >&2; exit 1; }

python3 - "$ICF" "$RXN_REF" "$ELA_REF" "$TOT_REF" <<'PY'
import sys,math
icf=sys.argv[1]; rxn_ref,ela_ref,tot_ref=map(float,sys.argv[2:5])
rows=[l.split() for l in open(icf)
      if l.strip() and not l.strip().startswith('#') and 'ENERGY' not in l]
rows=[r for r in rows if len(r)>=4]
# The shipped INPUT is a SINGLE-energy neutron case, so a correct run writes
# exactly one 4-column row at 20 MeV. Require that: a multi-row or wrong-energy
# output is not this benchmark and must not be accepted (guards a substituted run
# and validates every row rather than only the last).
if len(rows)!=1:
    print("verify_sides: FAIL  expected exactly one data row (single-energy benchmark), got %d"%len(rows)); sys.exit(1)
try: e,rxn,ela,tot=map(float,rows[0][:4])
except ValueError:
    print("verify_sides: FAIL  unparseable cross-section row"); sys.exit(1)
if abs(e-20.0)>1e-6:
    print("verify_sides: FAIL  benchmark energy is 20 MeV, got %s"%rows[0][0]); sys.exit(1)
if not all(math.isfinite(x) and x>0 for x in (rxn,ela,tot)):
    print("verify_sides: FAIL  non-finite/non-positive cross section"); sys.exit(1)

ok=True
def sigfigs(a,b):
    if a==b: return 16
    return -math.log10(abs(a-b)/abs(b))
# L1 gate at 1e-9 relative: the observed cross-version agreement (gfortran 13.3
# vs 15.2) is ~1e-11, so 1e-9 passes every known build with two orders of margin
# and still rejects the percent-level shift a real regression makes. This is a
# REGRESSION gate against the pinned value, not a re-run of the cross-build; the
# cross-build agreement itself is recorded in references/verification.md.
for name,val,ref in (("reaction",rxn,rxn_ref),("elastic",ela,ela_ref),("total",tot,tot_ref)):
    rel=abs(val-ref)/abs(ref)
    tag="ok" if rel<=1e-9 else "MISMATCH"
    if rel>1e-9: ok=False
    print("  L1 %-8s %.10f  vs pin %.10f   rel=%.1e (~%.1f sig figs)  %s"%(name,val,ref,rel,sigfigs(val,ref),tag))
# L2 optical theorem (neutron): total = elastic + reaction
oth=abs(tot-(ela+rxn))/tot
print("  L2 optical theorem  |total-(elastic+reaction)|/total = %.1e  %s"%(oth,"ok" if oth<=1e-9 else "MISMATCH"))
if oth>1e-9: ok=False

print("verify_sides: %s"%("PASS  (tier 2: local run matches the pinned reference; neutron optical theorem holds)" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PY
