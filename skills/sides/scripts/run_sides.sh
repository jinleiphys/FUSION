#!/bin/bash
# run_sides.sh [input-file]
#
# Run one SIDES elastic-scattering calculation and report honestly. [input-file]
# is a SIDES stdin deck (see references/input-format.md); it defaults to the
# shipped n+40Ca 20 MeV nonlocal example. sides.x reads its answers from stdin and
# writes the integral cross sections to INTEGRAL-CROSS-SECTION-<system> and the
# angular distribution to SIDES-<system>-... in the source directory.
#
# CONTENT IS THE VERDICT. sides.x echoes its inputs to stdout and returns 0 on a
# normal run; success is asserted from the integral-cross-section FILE: finite,
# positive reaction/elastic/total, and (for a neutron projectile, no Coulomb) the
# optical theorem TOTAL = ELASTIC + REACTION. A nonzero exit is a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the build. SIDES_DIR may be supplied directly (the self-test injects a
# stub); otherwise install.
if [ -n "${SIDES_DIR:-}" ]; then
  DIR="$SIDES_DIR"
else
  INSTALL_OUT="$(bash "$HERE/install_sides.sh")"
  DIR="$(echo "$INSTALL_OUT" | sed -n 's/^SIDES_DIR=//p' | tail -1)"
fi
BIN="$DIR/sides.x"
[ -x "$BIN" ] || { echo "run_sides: no sides.x in $DIR" >&2; exit 1; }

INPUT_FILE="${1:-$DIR/INPUT}"
[ -f "$INPUT_FILE" ] || { echo "run_sides: input file not found: $INPUT_FILE" >&2; exit 1; }
# Resolve to an absolute path NOW, before the cd into $DIR. sides.x is launched
# from $DIR, so a relative deck path would otherwise be re-resolved against $DIR
# after the cd: the projectile would be parsed from one file and the run fed a
# different (or missing) one. Make both use the same absolute file.
INPUT_FILE="$(cd "$(dirname "$INPUT_FILE")" && pwd)/$(basename "$INPUT_FILE")"

# Projectile from line 1 of the deck (0 neutron, 1 proton). For a neutron the
# integral file has reaction/elastic/total and obeys the optical theorem; for a
# proton, Coulomb makes only the reaction cross section meaningful and SIDES
# writes just energy+reaction, so the wrapper validates the two cases differently.
PROJ="$(awk 'NR==1{print $1; exit}' "$INPUT_FILE")"

rm -f "$DIR"/INTEGRAL-CROSS-SECTION-*
LOG="$DIR/run.stdout"; ERR="$DIR/run.stderr"
set +e
( cd "$DIR" && ./sides.x < "$INPUT_FILE" > "$LOG" 2> "$ERR" )
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "run_sides: sides.x exited $RC" >&2
  [ -s "$ERR" ] && head -8 "$ERR" >&2 || tail -8 "$LOG" >&2
  exit 1
fi

ICF="$(ls -t "$DIR"/INTEGRAL-CROSS-SECTION-* 2>/dev/null | head -1)"
[ -n "$ICF" ] && [ -f "$ICF" ] || {
  echo "run_sides: sides.x exited 0 but wrote no integral-cross-section file" >&2
  tail -8 "$LOG" >&2; exit 1; }

python3 - "$ICF" "${PROJ:-0}" <<'PY'
import sys,math
icf,proj=sys.argv[1],sys.argv[2].strip()
rows=[l.split() for l in open(icf)
      if l.strip() and not l.strip().startswith('#') and 'ENERGY' not in l]
# A neutron row has energy+reaction+elastic+total (4 fields); a proton row has
# energy+reaction only (2 fields), because Coulomb makes elastic/total ill-defined.
need = 4 if proj=='0' else 2
rows=[r for r in rows if len(r)>=need]
if not rows:
    sys.stderr.write("run_sides: no %s data rows in %s\n"%("neutron (4-col)" if proj=='0' else "proton (2-col)",icf)); sys.exit(1)
last=None
for r in rows:
    try: vals=list(map(float,r[:need]))
    except ValueError:
        sys.stderr.write("run_sides: unparseable row %r\n"%r); sys.exit(1)
    e=vals[0]; xs=vals[1:]
    if not all(math.isfinite(x) and x>0 for x in xs):
        sys.stderr.write("run_sides: non-finite/non-positive cross section at E=%s: %r\n"%(r[0],xs)); sys.exit(1)
    if proj=='0':
        rxn,ela,tot=xs
        if abs(tot-(ela+rxn))>1e-6*tot:  # neutron optical theorem
            sys.stderr.write("run_sides: optical theorem violated at E=%s: total %.6f != elastic+reaction %.6f\n"%(r[0],tot,ela+rxn)); sys.exit(1)
    last=(e,xs)
e,xs=last
if proj=='0':
    print("run_sides: OK  E=%.3f MeV  (reaction, elastic, total) = (%.6f, %.6f, %.6f) mb"%(e,xs[0],xs[1],xs[2]))
else:
    print("run_sides: OK (proton)  E=%.3f MeV  reaction = %.6f mb  (elastic/total ill-defined with Coulomb)"%(e,xs[0]))
PY
