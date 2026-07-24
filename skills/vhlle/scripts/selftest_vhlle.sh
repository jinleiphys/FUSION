#!/bin/bash
# selftest_vhlle.sh: exercise the vHLLE skill HARNESS (argument validation, table
# checks, the analytic Gubser comparator, and the guards each verify stage relies
# on) without needing a vHLLE build. Guards that require a real run are exercised
# against synthetic fixtures. Every guard is confirmed to FAIL when its condition
# is violated, so a green suite means the guards actually fire.
#
# Prints "SELFTEST OK" and exits 0 only if all cases pass.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PY=python3
pass=0; fail=0
ok ()  { pass=$((pass+1)); }
bad () { fail=$((fail+1)); echo "SELFTEST FAIL: $*" >&2; }
# expect a command to SUCCEED
exp_ok ()  { if "$@" >/dev/null 2>&1; then ok; else bad "expected success: $*"; fi; }
# expect a command to FAIL (non-zero)
exp_bad () { if "$@" >/dev/null 2>&1; then bad "expected failure: $*"; else ok; fi; }

CG="$HERE/check_gubser.py"
CO="$HERE/check_output.py"

# ---------- check_output.py ----------
# a good rectangular table
printf '1 2 3\n4 5 6\n7 8 9\n' > "$TMP/good.dat"
exp_ok  $PY "$CO" "$TMP/good.dat" --min-rows 3 --min-cols 3
exp_bad $PY "$CO" "$TMP/good.dat" --min-rows 4 --min-cols 3      # too few rows
exp_bad $PY "$CO" "$TMP/good.dat" --min-rows 3 --min-cols 4      # too few cols
# ragged table must be rejected
printf '1 2 3\n4 5\n' > "$TMP/ragged.dat"
exp_bad $PY "$CO" "$TMP/ragged.dat"
# NaN / Inf must be rejected
printf '1 2 3\n4 nan 6\n' > "$TMP/nan.dat"
exp_bad $PY "$CO" "$TMP/nan.dat"
printf '1 2 3\n4 inf 6\n' > "$TMP/inf.dat"
exp_bad $PY "$CO" "$TMP/inf.dat"
# non-numeric token must be rejected
printf '1 2 3\nx y z\n' > "$TMP/text.dat"
exp_bad $PY "$CO" "$TMP/text.dat"
# empty file must be rejected
: > "$TMP/empty.dat"
exp_bad $PY "$CO" "$TMP/empty.dat"
# negative thresholds rejected (argparse error)
exp_bad $PY "$CO" "$TMP/good.dat" --min-rows -1

# ---------- check_gubser.py: synthesize an EXACT analytic outx.dat ----------
# Build a file whose eps/vx ARE the analytic solution at tau=1.5, so a correct
# comparator must report ~0 deviation and PASS the tight thresholds.
$PY - "$TMP/exact.dat" <<'PY'
import sys, math
tau=1.5
def eps(t,r):
    D=1+2*(t*t+r*r)+(t*t-r*r)**2; return (4**(4/3))/(t**(4/3)*D**(4/3))
def vr(t,r): return 2*t*r/(1+t*t+r*r)
with open(sys.argv[1],"w") as f:
    # symmetric integer grid so +x and -x share |x| (for the symmetry check) and
    # x=0 is present (for the center-eps check): x = i*0.15, i in -33..33
    for i in range(-33,34):
        x=i*0.15
        r=abs(x); e=eps(tau,r); v=vr(tau,r)*(1 if x>=0 else -1)
        # 20 cols: t x vx vy eps nb T mub + 12 zeros
        f.write("%.10g %.10g %.10g 0 %.10g 0 %.10g 0 %s\n"%(tau,x,v,e,e**0.25," ".join(["0"]*12)))
PY
# exact data: must PASS with tight thresholds
exp_ok  $PY "$CG" "$TMP/exact.dat" --tau 1.5 --xcut 5.0 --max-eps-reldiff 1e-6 --max-vx-absdiff 1e-6
# wrong tau: no rows -> FAIL
exp_bad $PY "$CG" "$TMP/exact.dat" --tau 1.7
# impossibly tight center anchor -> FAIL (center must match a pinned value)
CEN=$(awk '$2==0{print $5}' "$TMP/exact.dat" | head -1)
exp_ok  $PY "$CG" "$TMP/exact.dat" --tau 1.5 --center-eps "$CEN" --center-tol 1e-6
exp_bad $PY "$CG" "$TMP/exact.dat" --tau 1.5 --center-eps 0.5 --center-tol 1e-6
# center-eps without center-tol -> argparse error
exp_bad $PY "$CG" "$TMP/exact.dat" --tau 1.5 --center-eps 0.5
# non-positive tau -> error
exp_bad $PY "$CG" "$TMP/exact.dat" --tau 0
exp_bad $PY "$CG" "$TMP/exact.dat" --tau -1

# a deviated file: perturb eps by 10% -> must FAIL a 3% eps threshold
$PY - "$TMP/exact.dat" "$TMP/dev.dat" <<'PY'
import sys
inp,out=sys.argv[1],sys.argv[2]
with open(inp) as fi, open(out,"w") as fo:
    for line in fi:
        p=line.split(); p[4]=str(float(p[4])*1.10); fo.write(" ".join(p)+"\n")
PY
exp_bad $PY "$CG" "$TMP/dev.dat" --tau 1.5 --xcut 5.0 --max-eps-reldiff 0.03

# a vx-perturbed file: bump vx by 0.05 -> must FAIL a 0.02 vx threshold (this
# guard is otherwise not exercised; a disabled vx check must be caught here)
$PY - "$TMP/exact.dat" "$TMP/vxdev.dat" <<'PY'
import sys
inp,out=sys.argv[1],sys.argv[2]
with open(inp) as fi, open(out,"w") as fo:
    for line in fi:
        p=line.split(); p[2]=str(float(p[2])+0.05); fo.write(" ".join(p)+"\n")
PY
exp_bad $PY "$CG" "$TMP/vxdev.dat" --tau 1.5 --xcut 5.0 --max-vx-absdiff 0.02 --max-eps-reldiff 1.0

# broken symmetry: perturb ONE side -> must FAIL the hard symmetry invariant
$PY - "$TMP/exact.dat" "$TMP/asym.dat" <<'PY'
import sys
inp,out=sys.argv[1],sys.argv[2]
with open(inp) as fi, open(out,"w") as fo:
    for line in fi:
        p=line.split()
        if float(p[1])>0: p[4]=str(float(p[4])*1.01)   # bump only x>0
        fo.write(" ".join(p)+"\n")
PY
exp_bad $PY "$CG" "$TMP/asym.dat" --tau 1.5 --xcut 5.0 --max-eps-reldiff 0.5

# non-finite in a Gubser file -> FAIL
$PY - "$TMP/exact.dat" "$TMP/gnan.dat" <<'PY'
import sys
inp,out=sys.argv[1],sys.argv[2]
lines=open(inp).read().splitlines()
p=lines[3].split(); p[4]="nan"; lines[3]=" ".join(p)
open(out,"w").write("\n".join(lines)+"\n")
PY
exp_bad $PY "$CG" "$TMP/gnan.dat" --tau 1.5

# ---------- check_glauber.py (the production anchor guard) ----------
CGL="$HERE/check_glauber.py"
# a synthetic Glauber outx: last tau=3.05, central cell eps=3.211810 T=0.213454
$PY - "$TMP/glauber.dat" <<'PY'
import sys
fn=sys.argv[1]
rows=[]
for t in (3.0,3.05):
    for x in (-0.5,0.0,0.5):
        eps=3.211810 if (abs(t-3.05)<1e-9 and x==0.0) else 1.0
        T=0.213454 if (abs(t-3.05)<1e-9 and x==0.0) else 0.15
        rows.append("%.10g %.10g 0 0 %.10g 0 %.10g 0 %s"%(t,x,eps,T," ".join(["0"]*12)))
open(fn,"w").write("\n".join(rows)+"\n")
PY
exp_ok  $PY "$CGL" "$TMP/glauber.dat" --last-tau 3.05 --center-eps 3.211810 --center-T 0.213454 --tol 2e-3
exp_bad $PY "$CGL" "$TMP/glauber.dat" --last-tau 3.10 --center-eps 3.211810 --center-T 0.213454 --tol 2e-3   # wrong last tau
exp_bad $PY "$CGL" "$TMP/glauber.dat" --last-tau 3.05 --center-eps 5.0      --center-T 0.213454 --tol 2e-3   # wrong eps
exp_bad $PY "$CGL" "$TMP/glauber.dat" --last-tau 3.05 --center-eps 3.211810 --center-T 0.30     --tol 2e-3   # wrong T
# nonfinite central eps must fail
$PY - "$TMP/glauber.dat" "$TMP/glauber_nan.dat" <<'PY'
import sys
inp,out=sys.argv[1],sys.argv[2]
with open(inp) as fi, open(out,"w") as fo:
    for line in fi:
        p=line.split()
        if len(p)>=7 and abs(float(p[0])-3.05)<1e-9 and float(p[1])==0.0:
            p[4]="nan"
        fo.write(" ".join(p)+"\n")
PY
exp_bad $PY "$CGL" "$TMP/glauber_nan.dat" --last-tau 3.05 --center-eps 3.211810 --center-T 0.213454 --tol 2e-3

# ---------- install/run/verify argument validation (no build needed) ----------
INS="$HERE/install_vhlle.sh"
RUN="$HERE/run_vhlle.sh"
VER="$HERE/verify_vhlle.sh"
exp_bad env VHLLE_EOS=bogus  bash "$INS"                       # bad EoS mode
exp_bad env VHLLE_PIN=nothex bash "$INS"                       # bad pin format
exp_bad env VHLLE_PIN=--upload-pack bash "$INS"               # injection blocked by format check
exp_bad env VHLLE_JOBS=0     bash "$INS"                       # bad jobs
exp_bad env VHLLE_JOBS=-4    bash "$INS"
exp_bad bash "$RUN"                                            # missing --params
exp_bad bash "$RUN" --params /no/such/file                     # params not found
exp_bad bash "$RUN" --params "$TMP/good.dat" --eos bogus       # bad eos
exp_bad bash "$VER" --nonsense                                 # unknown arg
# run_vhlle must NOT pass on STALE output: a no-op binary plus a pre-seeded
# outx.dat must fail (the run clears stale files, so no fresh output -> error)
mkdir -p "$TMP/fakeroot" "$TMP/staleout"
printf '#!/bin/sh\nexit 0\n' > "$TMP/fakeroot/hlle_visc_simple"; chmod +x "$TMP/fakeroot/hlle_visc_simple"
printf '1 0 0 0 1 0 1 0 %s\n' "0 0 0 0 0 0 0 0 0 0 0 0" > "$TMP/staleout/outx.dat"
exp_bad env VHLLE="$TMP/fakeroot/hlle_visc_simple" VHLLE_ROOT="$TMP/fakeroot" \
  bash "$RUN" --params "$HERE/../examples/gubser.params" --eos simple --outdir "$TMP/staleout"
exp_bad env VHLLE_PIN=zzzz bash "$VER" --gubser-only 2>/dev/null || true  # not the canonical pin path still parses
# help must succeed
exp_ok bash "$RUN" --help
exp_ok bash "$VER" --help

# ---------- FLIP TEST: prove check_output NaN guard is load-bearing ----------
# (already covered by nan.dat/inf.dat above; assert the good file still passes so
#  the guard is specific to the bad input, not rejecting everything)
exp_ok $PY "$CO" "$TMP/good.dat"

echo "selftest_vhlle: $pass passed, $fail failed"
if [ "$fail" -eq 0 ]; then echo "SELFTEST OK"; exit 0; else echo "SELFTEST FAILED"; exit 1; fi
