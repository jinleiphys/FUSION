#!/bin/bash
# run_kshell.sh [snt] [valence_p] [valence_n] [parity] [mtot] [n_eigen]
#
# Run one KSHELL shell-model diagonalization and report honestly. Arguments (all
# optional, defaulting to the 20Ne USDA benchmark):
#   snt        interaction file name in the snt/ directory (e.g. usda.snt)
#   valence_p  number of valence protons above the core
#   valence_n  number of valence neutrons above the core
#   parity     +1 or -1 (as the integer 1 or -1)
#   mtot       2*M of the M-scheme (0 for even-A, 1 for odd-A)
#   n_eigen    number of lowest eigenstates to compute
# e.g. `run_kshell.sh usda.snt 2 2 1 0 5` is 20Ne (2 valence p + 2 valence n above
# the 16O sd-shell core), positive parity, M=0, five lowest states.
#
# CONTENT IS THE VERDICT. kshell.exe writes an eigenvalue summary to its log;
# success means a zero exit and a finite negative ground-state energy in that log,
# with the requested number of states present. A nonzero exit is a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

SNT="${1:-usda.snt}"; VP="${2:-2}"; VN="${3:-2}"; PAR="${4:-1}"; MTOT="${5:-0}"; NEIG="${6:-5}"

# Validate: snt is a bare filename (no path), the rest are integers, parity +-1.
case "$SNT" in *[!A-Za-z0-9._+-]*|"") echo "run_kshell: illegal interaction name '$SNT'" >&2; exit 2;; esac
for v in "$VP" "$VN" "$MTOT" "$NEIG"; do
  case "$v" in ''|*[!0-9]*) echo "run_kshell: '$v' must be a non-negative integer" >&2; exit 2;; esac
done
case "$PAR" in 1|-1) : ;; *) echo "run_kshell: parity must be 1 or -1 (got '$PAR')" >&2; exit 2;; esac
[ "$NEIG" -ge 1 ] 2>/dev/null || { echo "run_kshell: n_eigen must be >= 1" >&2; exit 2; }

if [ -n "${KSHELL:-}" ] && [ -n "${KSHELL_SNT:-}" ] && [ -n "${KSHELL_GENPTN:-}" ]; then
  BIN="$KSHELL"; SNTDIR="$KSHELL_SNT"; GENPTN="$KSHELL_GENPTN"
else
  INSTALL_OUT="$(bash "$HERE/install_kshell.sh")"
  BIN="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL=//p' | tail -1)"
  SNTDIR="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_SNT=//p' | tail -1)"
  GENPTN="$(echo "$INSTALL_OUT" | sed -n 's/^KSHELL_GENPTN=//p' | tail -1)"
fi
[ -x "$BIN" ] || { echo "run_kshell: no kshell.exe at $BIN" >&2; exit 1; }
[ -f "$SNTDIR/$SNT" ] || { echo "run_kshell: interaction $SNT not found in $SNTDIR" >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp "$SNTDIR/$SNT" "$WORK/"
( cd "$WORK" && python3 "$GENPTN" "$SNT" case.ptn "$VP" "$VN" "$PAR" <<< "0" >genptn.log 2>&1 ) || {
  echo "run_kshell: gen_partition failed" >&2; tail -4 "$WORK/genptn.log" >&2; exit 1; }
[ -s "$WORK/case.ptn" ] || { echo "run_kshell: gen_partition wrote an empty partition file" >&2; exit 1; }

cat > "$WORK/case.input" <<EOF
&input
  eff_charge = 1.5, 0.5,
  fn_int = "$SNT"
  fn_ptn = "case.ptn"
  hw_type = 2
  is_double_j = .false.
  max_lanc_vec = 200
  maxiter = 300
  mode_lv_hdd = 0
  mtot = $MTOT
  n_eigen = $NEIG
  n_restart_vec = 15
&end
EOF

set +e
( cd "$WORK" && "$BIN" case.input > run.log 2>&1 )
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "run_kshell: kshell.exe exited $RC" >&2; tail -8 "$WORK/run.log" >&2; exit 1
fi
# KSHELL exits 0 even when the Lanczos iteration did not converge, printing
# "NOT converged in Lanczos method"; the summary then holds unconverged
# eigenvalues. Treat that as a failure (raise max_lanc_vec / maxiter to fix).
if grep -qi 'NOT converged in Lanczos method' "$WORK/run.log"; then
  echo "run_kshell: KSHELL reported non-convergence in the Lanczos method (raise max_lanc_vec/maxiter)" >&2
  exit 1
fi

python3 - "$WORK/run.log" "$NEIG" <<'PY'
import sys,re,math
log,neig=sys.argv[1],int(sys.argv[2])
states=[]
for l in open(log):
    m=re.match(r'\s*(\d+)\s+<H>:\s+([-\d.]+)\s+<JJ>:\s+([\d.]+)\s+J:\s+(\d+)/2\s+prty\s+(-?\d+)',l)
    if m:
        states.append((int(m.group(1)),float(m.group(2)),int(m.group(4)),int(m.group(5))))
if not states:
    sys.stderr.write("run_kshell: no eigenvalue summary in the log\n"); sys.exit(1)
states.sort()
# State indices must be the contiguous run 1..n, so a summary numbered from 0 or
# with a gap (a malformed or partial log) is rejected rather than silently sorted.
if [s[0] for s in states] != list(range(1,len(states)+1)):
    sys.stderr.write("run_kshell: state indices are not 1..%d (got %r)\n"%(len(states),[s[0] for s in states])); sys.exit(1)
gs=states[0][1]
if not (math.isfinite(gs) and gs<0):
    sys.stderr.write("run_kshell: ground-state energy not finite/negative: %r\n"%gs); sys.exit(1)
if len(states)<neig:
    sys.stderr.write("run_kshell: requested %d states, log has only %d\n"%(neig,len(states))); sys.exit(1)
# monotonic, finite
prev=-1e18
for idx,E,j2,p in states:
    if not math.isfinite(E):
        sys.stderr.write("run_kshell: non-finite energy at state %d\n"%idx); sys.exit(1)
    if E<prev-1e-4:
        sys.stderr.write("run_kshell: eigenvalues not in ascending order at state %d\n"%idx); sys.exit(1)
    prev=E
print("run_kshell: OK  ground state %.5f MeV  J=%d%s  (%d states computed)"%(
      gs, states[0][2]//2, "+" if states[0][3]>0 else "-", len(states)))
for idx,E,j2,p in states[:min(len(states),neig)]:
    print("   state %d  E=%9.5f MeV  Ex=%7.4f  J=%d%s"%(idx,E,E-gs,j2//2,"+" if p>0 else "-"))
PY
