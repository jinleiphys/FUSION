#!/bin/bash
# verify_kshell.sh
#
# TIER 2 benchmark. KSHELL ships interaction files and test scripts but no
# reference energy for a fixed case, so this verifies the code the way the
# 2026-07-20 tier-2 ruling and the 2026-07-21 cross-build standard prescribe:
# build integrity by cross-build agreement, plus a physics anchor, on the 20Ne
# USDA case (2 valence protons + 2 valence neutrons in the sd shell above 16O).
#
#   L1  the five lowest M=0 eigenvalues reproduce the pinned reference to the
#       printed precision. The pin is the macOS/ARM64 gfortran 15.2 value; the
#       Linux/x86_64 gfortran 13.3 build gives the SAME five numbers to all five
#       printed decimals (recorded in references/verification.md), so the 1e-4
#       gate certifies the diagonalization is reproduced and rejects a real bug.
#   L2  the spectrum is physically the 20Ne rotational band: J=0+ ground state,
#       first excited J=2+ at Ex ~ 1.70 MeV (experiment 1.63 MeV; USDA is a fitted
#       sd-shell interaction), then J=4+. This anchors the physics independently
#       of the pinned number.
#
# CONTENT IS THE VERDICT: parsed from the eigenvalue summary in the log.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${KSHELL:-}" ] && [ -n "${KSHELL_SNT:-}" ] && [ -n "${KSHELL_GENPTN:-}" ]; then
  BIN="$KSHELL"; SNTDIR="$KSHELL_SNT"; GENPTN="$KSHELL_GENPTN"
else
  INSTALL_OUT="$(bash "$HERE/install_kshell.sh")" || { echo "verify_kshell: install failed" >&2; exit 1; }
  BIN="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL=//p' | tail -1)"
  SNTDIR="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_SNT=//p' | tail -1)"
  GENPTN="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_GENPTN=//p' | tail -1)"
fi
[ -x "$BIN" ] || { echo "verify_kshell: no kshell.exe at $BIN" >&2; exit 1; }
[ -f "$SNTDIR/usda.snt" ] || { echo "verify_kshell: usda.snt missing" >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$SNTDIR/usda.snt" "$WORK/"
( cd "$WORK" && python3 "$GENPTN" usda.snt p.ptn 2 2 1 <<< "0" >genptn.log 2>&1 ) || {
  echo "verify_kshell: gen_partition failed" >&2; tail -4 "$WORK/genptn.log" >&2; exit 1; }
[ -s "$WORK/p.ptn" ] || { echo "verify_kshell: gen_partition wrote an empty partition file" >&2; exit 1; }
printf '&input\n eff_charge=1.5,0.5,\n fn_int="usda.snt"\n fn_ptn="p.ptn"\n hw_type=2\n is_double_j=.false.\n max_lanc_vec=200\n maxiter=300\n mode_lv_hdd=0\n mtot=0\n n_eigen=5\n n_restart_vec=15\n&end\n' > "$WORK/v.input"
set +e
( cd "$WORK" && "$BIN" v.input > v.log 2>&1 )
RC=$?
set -e
[ "$RC" -eq 0 ] || { echo "verify_kshell: kshell.exe exited $RC" >&2; tail -8 "$WORK/v.log" >&2; exit 1; }
if grep -qi 'NOT converged in Lanczos method' "$WORK/v.log"; then
  echo "verify_kshell: KSHELL reported non-convergence in the Lanczos method" >&2; exit 1
fi

python3 - "$WORK/v.log" <<'PY'
import sys,re,math
# pinned reference (macOS gfortran 15.2 == Linux gfortran 13.3, to 5 decimals):
# (energy MeV, 2*J, parity)
REF=[(-40.46689,0,1),(-38.77105,4,1),(-36.37577,8,1),(-33.91870,0,1),(-32.88208,4,1)]
states=[]
for l in open(sys.argv[1]):
    m=re.match(r'\s*(\d+)\s+<H>:\s+([-\d.]+)\s+<JJ>:\s+([\d.]+)\s+J:\s+(\d+)/2\s+prty\s+(-?\d+)',l)
    if m: states.append((int(m.group(1)),float(m.group(2)),int(m.group(4)),int(m.group(5))))
states.sort()
if len(states)<5:
    print("verify_kshell: FAIL  fewer than 5 states in the log (%d)"%len(states)); sys.exit(1)
if [s[0] for s in states] != list(range(1,len(states)+1)):
    print("verify_kshell: FAIL  state indices are not 1..%d (got %r)"%(len(states),[s[0] for s in states])); sys.exit(1)
ok=True
for i,(ref_e,ref_j2,ref_p) in enumerate(REF):
    idx,E,j2,p=states[i]
    de=abs(E-ref_e)
    tag="ok" if (de<=1e-4 and j2==ref_j2 and p==ref_p) else "MISMATCH"
    if tag=="MISMATCH": ok=False
    print("  L1 state %d  E=%9.5f (ref %9.5f, |d|=%.1e)  J=%d%s (ref %d%s)  %s"%(
          i+1,E,ref_e,de,j2//2,"+" if p>0 else "-",ref_j2//2,"+" if ref_p>0 else "-",tag))
# L2 physics: ground J=0+, first excited J=2+, Ex(2+) in [1.4,2.0] MeV
gsE,gsJ2,gsP=states[0][1],states[0][2],states[0][3]
exJ2,exP=states[1][2],states[1][3]; ex=states[1][1]-gsE
phys = (gsJ2==0 and gsP>0 and exJ2==4 and exP>0 and 1.4<=ex<=2.0)
print("  L2 physics  g.s. J=%d%s, first excited J=%d%s at Ex=%.4f MeV (20Ne band, exp 2+ 1.63)  %s"%(
      gsJ2//2,"+" if gsP>0 else "-",exJ2//2,"+" if exP>0 else "-",ex,"ok" if phys else "MISMATCH"))
if not phys: ok=False
print("verify_kshell: %s"%("PASS  (tier 2: cross-build spectrum + 20Ne rotational-band physics)" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PY
