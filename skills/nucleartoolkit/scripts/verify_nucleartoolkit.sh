#!/bin/bash
# verify_nucleartoolkit.sh
#
# TIER 1 benchmark. NuclearToolkit.jl ships a test suite whose @test assertions
# compare against the authors' own reference values; this reproduces them.
#
#   L1  (fast, self-contained) the CKpot Be-8 valence shell-model spectrum: the
#       10 lowest eigenvalues reproduce the shipped reference to the test's
#       tolerance |dE| < 1e-3 (the references are quoted to 3 decimals; the test
#       gate is (Eref-E)^2 < 1e-6). Deterministic, ~15 s.
#   L2  (full ab-initio suite) `Pkg.test("NuclearToolkit")`: the ordered
#       chiral-EFT -> HFMBPT -> (VS-)IMSRG -> shell-model pipeline, reproducing
#       He-4 HFMBPT [1.493, -5.805, 0.395], the IMSRG ground state -4.05225276
#       to 1e-6, and the shell-model spectra. ~3.5 min; set NTK_FAST=1 to skip.
#
# CONTENT IS THE VERDICT: L1 pins the eigenvalues; L2 parses the Pass/Total count
# and the "tests passed" line, never a bare exit status.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${NTK_JULIA:-}" ] && [ -n "${NTK_DEPOT:-}" ] && [ -n "${NTK_PROJ:-}" ] && [ -n "${NTK_PKGDIR:-}" ]; then
  JULIA="$NTK_JULIA"; DEPOT="$NTK_DEPOT"; PROJ="$NTK_PROJ"; PKGDIR="$NTK_PKGDIR"
else
  INSTALL_OUT="$(bash "$HERE/install_nucleartoolkit.sh")" || { echo "verify_nucleartoolkit: install failed" >&2; exit 1; }
  JULIA="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_JULIA=//p' | tail -1)"
  DEPOT="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_DEPOT=//p' | tail -1)"
  PROJ="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_PROJ=//p' | tail -1)"
  PKGDIR="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_PKGDIR=//p' | tail -1)"
fi
CKPOT="$PKGDIR/test/interaction_file/ckpot.snt"
[ -f "$CKPOT" ] || { echo "verify_nucleartoolkit: no ckpot.snt at $CKPOT" >&2; exit 1; }

ok=1
echo "verify_nucleartoolkit: L1 CKpot Be-8 shell-model spectrum (shipped reference, |dE| < 1e-3)"
L1_OUT="$(mktemp)"; trap 'rm -f "$L1_OUT"' EXIT
set +e
JULIA_DEPOT_PATH="$DEPOT" "$JULIA" --project="$PROJ" --startup-file=no -e '
  using NuclearToolkit
  E = main_sm(ARGS[1], "Be8", 10, Int[]; q=2, is_block=true)
  for (i,e) in enumerate(E); println("EIGEN ", i, " ", e); end
' "$CKPOT" > "$L1_OUT" 2>&1
L1_RC=$?
set -e
python3 - "$L1_OUT" "$L1_RC" <<'PY' || ok=0
import sys, math
Eref = [-31.119,-27.300,-19.162,-18.249,-16.722,-14.925,-14.517,-14.017,-13.951,-13.478]
rc = int(sys.argv[2])
E = []
for l in open(sys.argv[1]):
    if l.startswith("EIGEN "):
        try: E.append(float(l.split()[2]))
        except (IndexError, ValueError): pass
if rc != 0:
    print("  L1 FAIL  main_sm exited %d" % rc); sys.exit(1)
if len(E) != len(Eref):
    print("  L1 FAIL  got %d eigenvalues, need exactly %d" % (len(E), len(Eref))); sys.exit(1)
mx = 0.0; bad = False
for i, ref in enumerate(Eref):
    d = abs(E[i]-ref); mx = max(mx, d)
    if not math.isfinite(E[i]) or d >= 1e-3: bad = True
print("  L1 %s  max |dE| = %.2e over 10 states (g.s. %.4f vs %.3f)" %
      ("FAIL" if bad else "ok", mx, E[0], Eref[0]))
sys.exit(1 if bad else 0)
PY
[ "$ok" -eq 1 ] && echo "  L1 ok" || echo "  L1 FAILED"

if [ -n "${NTK_FAST:-}" ]; then
  echo "verify_nucleartoolkit: L2 skipped (NTK_FAST set)"
  [ "$ok" -eq 1 ] && { echo "verify_nucleartoolkit: PASS (L1 only; tier-1 CKpot anchor; run without NTK_FAST for the full ab-initio suite)"; exit 0; }
  echo "verify_nucleartoolkit: FAIL"; exit 1
fi

echo "verify_nucleartoolkit: L2 full Pkg.test (chiral EFT -> HFMBPT -> IMSRG -> shell model; ~3.5 min)"
L2_OUT="$(mktemp)"; trap 'rm -f "$L1_OUT" "$L2_OUT"' EXIT
set +e
JULIA_DEPOT_PATH="$DEPOT" "$JULIA" --project="$PROJ" --startup-file=no -e 'using Pkg; Pkg.test("NuclearToolkit")' > "$L2_OUT" 2>&1
L2_RC=$?
set -e
python3 - "$L2_OUT" "$L2_RC" <<'PY' || ok=0
import sys, re
path, rc = sys.argv[1], int(sys.argv[2])
# The suite is pinned to NuclearToolkit v0.5.2, whose test count is exactly 30.
# A partial or skipped suite (e.g. 25/25) must NOT certify tier 1, so require the
# exact count, a zero exit, and the anchored "tests passed" line.
EXPECT = 30
txt = open(path).read()
m = re.search(r'NuclearToolkit\.jl\s*\|\s*(\d+)\s+(\d+)', txt)
passed_str = "Testing NuclearToolkit tests passed" in txt or "tests passed" in txt
if m is None:
    print("  L2 FAIL  no test-summary line (suite did not run; rc=%d)" % rc)
    sys.stderr.write(txt[-800:]); sys.exit(1)
npass, ntot = int(m.group(1)), int(m.group(2))
good = (npass == ntot == EXPECT and passed_str and rc == 0)
reasons = []
if npass != ntot: reasons.append("pass!=total")
if ntot != EXPECT: reasons.append("total %d != pinned %d" % (ntot, EXPECT))
if not passed_str: reasons.append("no 'tests passed' line")
if rc != 0: reasons.append("rc=%d" % rc)
print("  L2 %s  Pkg.test %d/%d passed%s" %
      ("ok" if good else "FAIL", npass, ntot, "" if good else "  [" + ", ".join(reasons) + "]"))
sys.exit(0 if good else 1)
PY

if [ "$ok" -eq 1 ]; then
  echo "verify_nucleartoolkit: PASS  (tier 1: CKpot shell-model anchor + full Pkg.test reproduce the shipped references)"
  exit 0
fi
echo "verify_nucleartoolkit: FAIL"; exit 1
