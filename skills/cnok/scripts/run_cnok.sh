#!/bin/bash
# run_cnok.sh <config-name> [basedir]
#
# Run one CNOK single-configuration cross-section calculation and report
# honestly. <config-name> is the valence-configuration tag whose YAML deck is
# <basedir>/<config-name>.yaml, e.g. `run_cnok.sh 1s11p config/C/C16` computes
# neutron removal from the 1s1/2 (x) 1/2+ configuration of 16C. [basedir]
# defaults to config/C/C16, the documented benchmark case; it is a path relative
# to the CNOK build directory (which is where mom resolves config/ from).
#
# CONTENT IS THE VERDICT. mom prints a long integrand trace to stdout and writes
# the answer to <basedir>/<name>_<timestamp>.txt. Success is asserted from that
# result file: three finite, positive cross sections, and an effective separation
# energy that matches the deck's Eref, so a silently substituted or wrong deck
# cannot pass. mom returns 0 on a normal run; a nonzero exit is a failure even
# with a plausible file left behind.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

NAME="${1:?usage: run_cnok.sh <config-name> [basedir]   e.g. run_cnok.sh 1s11p config/C/C16}"
BASEDIR="${2:-config/C/C16}"

# Validate NAME and BASEDIR before they reach `rm -f`, a glob, or a file path.
# NAME is a bare configuration tag (1s11p, 0d55p, 1s10p1): letters, digits,
# _ + - only, no slash and no dot, so it can never traverse out of the deck
# directory. BASEDIR is a path relative to the build tree: it may contain
# slashes but must not be absolute and must not contain a `..` component. This
# closes the path-traversal delete that an earlier version allowed
# (`run_cnok.sh evil ../victim`).
case "$NAME" in
  *[!A-Za-z0-9_+-]*|"") echo "run_cnok: illegal config name '$NAME' (allowed: letters, digits, _ + -)" >&2; exit 2;;
esac
case "$BASEDIR" in
  /*|*..*|"") echo "run_cnok: illegal basedir '$BASEDIR' (must be a relative path with no '..')" >&2; exit 2;;
esac

# Resolve the build tree and yaml-cpp lib dir. CNOK_BUILD / CNOK_YAMLLIB may be
# supplied directly (the self-test injects a stub build); otherwise install.
if [ -n "${CNOK_BUILD:-}" ]; then
  BUILD="$CNOK_BUILD"; YAMLLIB="${CNOK_YAMLLIB:-}"
else
  INSTALL_OUT="$(bash "$HERE/install_cnok.sh")"
  BUILD="$(echo "$INSTALL_OUT" | sed -n 's/^CNOK_BUILD=//p' | tail -1)"
  YAMLLIB="$(echo "$INSTALL_OUT" | sed -n 's/^CNOK_YAMLLIB=//p' | tail -1)"
fi
BIN="$BUILD/mom"
[ -x "$BIN" ] || { echo "run_cnok: no mom executable at $BIN" >&2; exit 1; }

DECK="$BUILD/$BASEDIR/$NAME.yaml"
[ -f "$DECK" ] || { echo "run_cnok: deck not found: $BASEDIR/$NAME.yaml (under $BUILD)" >&2; exit 1; }

# Expected effective separation energy from the deck, to tie output to input. A
# real CNOK deck always carries Eref; if it cannot be parsed the substitution
# guard below would be silently skipped, so treat that as an error, not a pass.
EREF="$(sed -n 's/^Eref:[[:space:]]*\([-0-9.eE+]*\).*/\1/p' "$DECK" | head -1)"
[ -n "$EREF" ] || { echo "run_cnok: deck $BASEDIR/$NAME.yaml has no parseable Eref" >&2; exit 1; }

# Point basedir at the requested case and clear stale result files for this name.
perl -pi -e "s{^basedir:.*}{basedir: $BASEDIR}" "$BUILD/config/basedir.yaml"
rm -f "$BUILD/$BASEDIR/${NAME}"_*.txt

LOG="$BUILD/run_${NAME}.stdout"; ERR="$BUILD/run_${NAME}.stderr"
set +e
( cd "$BUILD" && DYLD_LIBRARY_PATH="$YAMLLIB:${DYLD_LIBRARY_PATH:-}" \
    LD_LIBRARY_PATH="$YAMLLIB:${LD_LIBRARY_PATH:-}" \
    ./mom "$NAME" >"$LOG" 2>"$ERR" )
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "run_cnok: mom exited $RC" >&2
  [ -s "$ERR" ] && head -8 "$ERR" >&2 || tail -8 "$LOG" >&2
  exit 1
fi

RES="$(ls -t "$BUILD/$BASEDIR/${NAME}"_*.txt 2>/dev/null | head -1)"
[ -n "$RES" ] && [ -f "$RES" ] || {
  echo "run_cnok: mom exited 0 but wrote no result file for $NAME" >&2
  tail -8 "$LOG" >&2; exit 1; }

# Parse and validate the result file: three finite positive cross sections, and
# S_N+Ex consistent with the deck's Eref (the substitution guard).
python3 - "$RES" "${EREF:-nan}" <<'PY'
import re,sys,math
res,eref=sys.argv[1],sys.argv[2]
t=open(res).read()
labels={"str":"Stripping c.s.:","diff":"Diffractive c.s.:","tot":"Total knockout c.s.:"}
v={}
for k,lab in labels.items():
    m=re.search(re.escape(lab)+r"\s+([-\d.eE+]+)",t)
    if not m:
        sys.stderr.write("run_cnok: result file missing '%s'\n"%lab); sys.exit(1)
    v[k]=float(m.group(1))
if not all(math.isfinite(x) and x>0 for x in v.values()):
    sys.stderr.write("run_cnok: non-finite or non-positive cross section %r\n"%v); sys.exit(1)
# tot must be str+diff to the printed precision. The values print to 6 decimals,
# so a genuine TOTAL = STRIP + DIFF holds to a few units in the last place; 1e-5
# absolute allows that rounding and nothing looser.
if abs(v["tot"]-(v["str"]+v["diff"]))>1e-5:
    sys.stderr.write("run_cnok: total %.6f != stripping+diffractive %.6f\n"%(v["tot"],v["str"]+v["diff"])); sys.exit(1)
# S_N+Ex in the file must equal the deck's Eref (guards a substituted case).
try: er=float(eref)
except ValueError: er=float("nan")
if math.isfinite(er):
    ms=re.search(r"S_N\+Ex:\s+([-\d.eE+]+)",t)
    if not ms:
        sys.stderr.write("run_cnok: result file has no S_N+Ex line\n"); sys.exit(1)
    if abs(float(ms.group(1))-er)>1e-3:
        sys.stderr.write("run_cnok: result S_N+Ex %s != deck Eref %s (wrong deck?)\n"%(ms.group(1),eref)); sys.exit(1)
print("run_cnok: OK  %s  (sigma_str, sigma_diff, sigma_sp) = (%.6f, %.6f, %.6f) mb"%(
      res.split('/')[-1], v["str"], v["diff"], v["tot"]))
PY
