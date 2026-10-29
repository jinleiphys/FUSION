#!/bin/bash
# verify_yahfc.sh [--seeds]
#
# TIER 2 with a physics anchor. YAHFC ships no reference output, so:
#
#   L1  fixed-seed REGRESSION, n+90Zr at 0.96 and 13.92 MeV, 2000 events, seed
#       12345 (examples/zr90-n.inp). Pins sigma_tot, sigma_R, sigma_shape-el,
#       the compound-elastic and six channel cross sections at both energies to
#       1e-6 relative, and the per-channel event counts at 13.92 MeV exactly.
#       The values were measured on this skill's pinned commits (see
#       references/verification.md). Builds differ by at most ~2e-7 relative
#       (-O0 to -Ofast), five orders below the Monte Carlo noise, so 1e-6 is a
#       regression bar, not byte identity, and not a statement about physics.
#   L2  n+235U fission with LLNL's own tuned deck (YAHFC-Examples/U235/U235.com,
#       extracted from the pinned clone), 20000 events, seed 12345, energies
#       0.5 1 2 5 14 MeV, with the shipped CC-DWBA transmission coefficients
#       staged so Frescox is not exercised here. Pins sigma_f at the five
#       energies to 1e-6 relative, and compares with measured 235U(n,f)
#       (EXFOR 10950.002, Wasson et al.; 14016.002, Lisowski et al.) at the four
#       energies those entries cover, against a 6% bar fixed before the run.
#       The bar is a regression bar on a tuned deck, not a claim of accuracy.
#   --seeds  also runs L2 at seeds 1..5 and compares the seed mean (the number
#       to set against experiment) with the pinned means to 1e-4 and with EXFOR.
#       Adds about 2 minutes.
#
# Every run goes through run_yahfc.sh, so its guards (fresh workdir, seed
# provenance, completion, event accounting, energy conservation, finite
# library) are exercised too.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
RUN="$HERE/run_yahfc.sh"
SEEDS=0; [ "${1:-}" = "--seeds" ] && SEEDS=1

if [ -z "${YAHFC_BIN:-}" ] || [ -z "${YAHFC_DIR:-}" ]; then
  INSTALL_OUT="$(bash "$HERE/install_yahfc.sh")" || { echo "verify_yahfc: install failed" >&2; exit 1; }
  export YAHFC_BIN="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC=//p' | tail -1)"
  export FRESCOX="$(echo "$INSTALL_OUT" | sed -n 's/^FRESCOX=//p' | tail -1)"
  export YAHFC_DIR="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC_DIR=//p' | tail -1)"
  export YAHFC_DATA="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC_DATA=//p' | tail -1)"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
pass () { echo "  PASS  $*"; }
bad ()  { echo "  FAIL  $*"; FAILS=$((FAILS+1)); }

# compare <label> <got> <want> <reltol>; zero wants must be exactly zero.
compare () {
  python3 - "$@" <<'EOF'
import math, sys
label, got, want, tol = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
try:
    g = float(got)
except ValueError:
    print(f"  FAIL  {label}: no value (got '{got}')"); sys.exit(1)
if not math.isfinite(g):
    print(f"  FAIL  {label}: non-finite {got}"); sys.exit(1)
rel = abs(g - want) / abs(want) if want != 0 else abs(g)
ok = (g == 0.0) if want == 0 else rel <= tol
print(f"  {'PASS' if ok else 'FAIL'}  {label}: {g:.8g} vs {want:.8g} (rel {rel:.1e}, tol {tol:g})")
sys.exit(0 if ok else 1)
EOF
}
chk () { compare "$@" || FAILS=$((FAILS+1)); }
# col2 <file> <row>: the cross section in data row <row>, but only if the file
# has exactly one row per energy of $GRID and that row's energy matches the
# expected one (1e-6 relative; builds move energies by ~2e-7, a wrong energy far more). Otherwise it prints the reason, which is not a
# number, so the comparison fails and shows it. A cross section written against
# the wrong energy, a missing or extra row, or a reordered grid cannot pass.
col2 () {
  python3 - "$1" "$2" "$GRID" <<'PY'
import math, sys
p, n, grid = sys.argv[1], int(sys.argv[2]), [float(x) for x in sys.argv[3].split()]
try:
    r = [l.split() for l in open(p) if l.strip() and not l.lstrip().startswith('#')]
except OSError:
    print("missing-file"); sys.exit()
if len(r) != len(grid):
    print(f"rows={len(r)}-expected-{len(grid)}"); sys.exit()
try:
    e = float(r[n-1][0])
except (ValueError, IndexError):
    print("bad-energy"); sys.exit()
if not math.isfinite(e) or abs(e - grid[n-1]) > 1e-6 * grid[n-1]:
    print(f"energy={r[n-1][0]}-expected-{grid[n-1]}"); sys.exit()
print(r[n-1][1])
PY
}

# ------------------------------------------------------------------ L1
echo "L1  n+90Zr fixed-seed regression"
D="$WORK/zr90"
if bash "$RUN" "$SKILL/examples/zr90-n.inp" "$D" > "$WORK/l1.log" 2>&1; then
  pass "run_yahfc verdict OK"
  L="$D/90Zr/n"
  GRID="0.96188550 13.921512"
  # energy index: 1 = 0.96188550 MeV, 2 = 13.921512 MeV
  for spec in \
    "Total_cs.dat 1 6.4621054" "Total_cs.dat 2 3.9052591" \
    "Reaction_cs.dat 1 2.6804315" "Reaction_cs.dat 2 1.7440681" \
    "n/Shape_Elastic_cs.dat 1 3.7816739" "n/Shape_Elastic_cs.dat 2 2.1611910" \
    "n/Compound_Elastic_cs.dat 1 2.6692514" "n/Compound_Elastic_cs.dat 2 0" \
    "g/Channel_g_cs_Tot.dat 1 1.0876038E-02" "g/Channel_g_cs_Tot.dat 2 6.8401474E-04" \
    "n/Channel_n_cs_Tot.dat 1 3.0414606E-04" "n/Channel_n_cs_Tot.dat 2 9.0971417E-01" \
    "2n/Channel_2n_cs_Tot.dat 1 0" "2n/Channel_2n_cs_Tot.dat 2 7.0166661E-01" \
    "p/Channel_p_cs_Tot.dat 1 0" "p/Channel_p_cs_Tot.dat 2 2.3602736E-02" \
    "np/Channel_np_cs_Tot.dat 1 0" "np/Channel_np_cs_Tot.dat 2 9.0580624E-02" \
    "2p/Channel_2p_cs_Tot.dat 2 0"; do
    set -- $spec
    chk "$1 E#$2" "$(col2 "$L/$1" "$2")" "$3" 1e-6
  done
  # Event counts per channel at 13.92 MeV: the last "Num events" table.
  got="$(tr -d '\000' < "$D/yahfc.stdout" | awk '/^Channel: +[0-9]+ /{c[$3]=$NF} END{printf "g=%s n=%s 2n=%s p=%s np=%s 2p=%s", c["g"],c["n"],c["2n"],c["p"],c["np"],c["2p"]}')"
  want="g=233 n=582 2n=110 p=806 np=262 2p=0"
  [ "$got" = "$want" ] && pass "events per channel at 13.92 MeV: $got" || bad "events per channel at 13.92 MeV: $got, want $want"
  # Flux sum read back from the library: sigma_R = compound elastic + all
  # inelastic (n/Inelastic_cs_Total) + every non-inelastic channel total. A
  # file mislabelled or double-counted by a parser breaks this; the printed
  # digits allow 1e-6.
  for i in 1 2; do
    s="$(GRID="$GRID" python3 - "$L" "$i" <<'EOF'
import glob, os, sys
L, i = sys.argv[1], int(sys.argv[2])
grid = [float(x) for x in os.environ["GRID"].split()]
def v(p):
    rows = [l.split() for l in open(p) if l.strip() and not l.startswith('#')]
    if len(rows) != len(grid) or abs(float(rows[i-1][0]) - grid[i-1]) > 1e-6 * grid[i-1]:
        print(f"grid-mismatch-in-{os.path.basename(p)}"); sys.exit()
    return float(rows[i-1][1])
t = v(f"{L}/n/Compound_Elastic_cs.dat") + v(f"{L}/n/Inelastic_cs_Total.dat")
for p in glob.glob(f"{L}/*/Channel_*_cs_Tot.dat"):
    if os.path.basename(os.path.dirname(p)) != "n":
        t += v(p)
print(f"{t:.8e}")
EOF
)"
    chk "flux sum CE + inelastic + channels = sigma_R, E#$i" "$s" "$(col2 "$L/Reaction_cs.dat" $i)" 1e-6
  done
  grep -q '^seed from deck: 12345' "$D/provenance.txt" && pass "seed 12345 recorded in provenance" || bad "seed not recorded as 12345"
else
  bad "run_yahfc failed on L1:"; sed 's/^/        /' "$WORK/l1.log" | tail -8
fi

# ------------------------------------------------------------------ L2
COM="$YAHFC_DIR/YAHFC-Examples/U235/U235.com"
CC="$YAHFC_DATA/Trans-coeff/CC-DWBA"
mkdeck () {  # mkdeck <out> : U235.com's heredoc, 20000 events, five energies
  sed -n '/<< *input/,/^input$/p' "$COM" | sed '1d;$d' \
    | sed -E 's/^[[:space:]]*num_mc_samp.*/num_mc_samp 20000/' \
    | sed -E '/^[[:space:]]*ran_seed/d; /^[[:space:]]*proj_e(minmax|_file)/d' \
    | awk '/^[[:space:]]*end[[:space:]]*$/ {print "proj_e_file elist.txt"} {print}' > "$1"
  grep -q '^num_mc_samp 20000$' "$1" && grep -q '^proj_e_file elist.txt$' "$1" && grep -q '^target U235' "$1"
}
printf '0.5\n1.0\n2.0\n5.0\n14.0\n' > "$WORK/elist.txt"
# measured sigma_f (b) interpolated at the YAHFC energies, energy index 1,2,4,5
EXP=("1.137" "1.185" "" "1.072" "2.065")
EXPSRC=("EXFOR 10950.002" "EXFOR 10950.002" "" "EXFOR 14016.002" "EXFOR 14016.002")

runu235 () {  # runu235 <seed> <dir>
  YAHFC_SEED="$1" bash "$RUN" "$WORK/u235.inp" "$2" "$WORK/elist.txt" "$CC/nU235.tcoef" "$CC/nU235-CC.data"
}

echo "L2  n+235U fission, LLNL tuned deck"
if [ ! -f "$COM" ] || [ ! -f "$CC/nU235.tcoef" ] || [ ! -f "$CC/nU235-CC.data" ]; then
  bad "U235 example or CC-DWBA transmission coefficients missing from the clone"
elif ! mkdeck "$WORK/u235.inp"; then
  bad "could not extract the U235 deck from $COM"
elif runu235 12345 "$WORK/u235-12345" > "$WORK/l2.log" 2>&1; then
  pass "run_yahfc verdict OK"
  F="$WORK/u235-12345/235U/n/f/fission_cs.dat"
  GRID="0.46074054 0.97089601 1.9912105 4.9501491 14.031277"
  PIN=(1.1807830 1.1831120 1.3145280 1.1053485 2.0096643)
  for i in 1 2 3 4 5; do chk "sigma_f seed 12345 E#$i" "$(col2 "$F" $i)" "${PIN[$((i-1))]}" 1e-6; done
  for i in 1 2 4 5; do
    e="${EXP[$((i-1))]}"
    chk "sigma_f seed 12345 E#$i vs ${EXPSRC[$((i-1))]}" "$(col2 "$F" $i)" "$e" 0.06
  done
else
  bad "run_yahfc failed on L2:"; sed 's/^/        /' "$WORK/l2.log" | tail -8
fi

if [ "$SEEDS" -eq 1 ]; then
  echo "L2+ seed mean over seeds 1..5"
  ok=1
  for s in 1 2 3 4 5; do
    runu235 "$s" "$WORK/u235-s$s" > "$WORK/l2s$s.log" 2>&1 || { bad "seed $s run failed"; ok=0; }
  done
  if [ "$ok" -eq 1 ]; then
    MEANPIN=(1.1717 1.1554 1.2920 1.0999 1.9840)
    GRID="0.46074054 0.97089601 1.9912105 4.9501491 14.031277"
    for i in 1 2 3 4 5; do
      # every one of the five reads must be a finite number on the right grid;
      # one failed read makes the mean "no value" instead of averaging in a 0
      m="$(for s in 1 2 3 4 5; do col2 "$WORK/u235-s$s/235U/n/f/fission_cs.dat" $i; done | python3 -c '
import math, sys
v = []
for t in sys.stdin.read().split():
    try: x = float(t)
    except ValueError: print("bad-read:" + t); sys.exit()
    if not math.isfinite(x): print("bad-read:" + t); sys.exit()
    v.append(x)
print(f"{sum(v)/5:.6f}" if len(v) == 5 else f"only-{len(v)}-reads")')"
      chk "seed-mean sigma_f E#$i" "$m" "${MEANPIN[$((i-1))]}" 1e-4
      e="${EXP[$((i-1))]}"; [ -n "$e" ] && chk "seed-mean sigma_f E#$i vs ${EXPSRC[$((i-1))]}" "$m" "$e" 0.06
    done
  fi
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "verify_yahfc: VERIFY OK (tier 2: fixed-seed regression plus a 6% bar against measured 235U(n,f))"
  exit 0
fi
echo "verify_yahfc: $FAILS check(s) FAILED"
exit 1
