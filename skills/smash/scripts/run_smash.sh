#!/bin/bash
# run_smash.sh
#
# Run a SMASH configuration in an isolated directory and assert the output is
# usable. Usage:
#
#   run_smash.sh --config <config.yaml> [--outdir <dir>] [--seed <int>]
#                [--nevents <int>] [--end-time <fm/c>] [--allow-random-seed]
#
# --config     a SMASH YAML configuration. Copied into the output directory, so
#              the run records the input it actually used.
# --outdir     defaults to a fresh mktemp -d. Must be new or empty.
# --seed       overwrite General:Randomseed. SMASH's shipped configs use -1,
#              which draws a fresh seed per run and makes the output
#              irreproducible. A benchmark MUST pin the seed; run_smash.sh
#              therefore refuses -1 unless --allow-random-seed is given.
# --nevents, --end-time   convenience overrides for a shorter run.
#
# Prints RESULT_DIR= and RESULT_OSCAR= on the last two lines.
#
# SMASH is GPL-3.0-or-later; see install_smash.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""; OUTDIR=""; SEED=""; NEVENTS=""; END_TIME=""; ALLOW_RANDOM=0
PARTICLES=""; DECAYMODES=""; AUTO_TABLES=1

log () { echo "run_smash: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config)   CONFIG="${2:-}"; shift 2 ;;
    --outdir)   OUTDIR="${2:-}"; shift 2 ;;
    --seed)     SEED="${2:-}"; shift 2 ;;
    --nevents)  NEVENTS="${2:-}"; shift 2 ;;
    --end-time) END_TIME="${2:-}"; shift 2 ;;
    --particles)  PARTICLES="${2:-}"; shift 2 ;;
    --decaymodes) DECAYMODES="${2:-}"; shift 2 ;;
    --no-auto-tables) AUTO_TABLES=0; shift ;;
    --allow-random-seed) ALLOW_RANDOM=1; shift ;;
    -h|--help)  sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown argument '$1'" ;;
  esac
done

[ -n "$CONFIG" ] || die "--config is required"
[ -f "$CONFIG" ] || die "config '$CONFIG' does not exist"
CONFIG="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
grep -q "General:" "$CONFIG" || die "config '$CONFIG' has no 'General:' block; is it a SMASH configuration?"

# Numeric arguments must be numeric before they are spliced into YAML.
# Full-match validation. The earlier character-class test accepted '--', '1-2'
# and '1..2', which are not numbers even though they contain only permitted
# characters.
is_int ()  { printf '%s' "$1" | grep -qE '^-?[0-9]+$'; }
is_uint () { printf '%s' "$1" | grep -qE '^[0-9]+$'; }
is_num ()  { printf '%s' "$1" | grep -qE '^[0-9]+(\.[0-9]+)?$'; }

if [ -n "$SEED" ]; then
  is_int "$SEED" || die "--seed must be an integer, got '$SEED'"
  # SMASH treats EVERY negative seed as "draw a random one", not just -1: two
  # runs with --seed -2 produced seeds 8409242248972502135 and
  # 4845130125537222390 and different output, while config_used.yaml still read
  # -2 and looked pinned.
  if [ "$SEED" -lt 0 ] && [ "$ALLOW_RANDOM" = "0" ]; then
    die "--seed $SEED is negative, and SMASH treats any negative seed as random, so the run would be irreproducible. Use a non-negative seed, or --allow-random-seed."
  fi
fi
if [ -n "$NEVENTS" ]; then
  is_uint "$NEVENTS" || die "--nevents must be a non-negative integer, got '$NEVENTS'"
  [ "$NEVENTS" -ge 1 ] || die "--nevents must be at least 1"
fi
if [ -n "$END_TIME" ]; then
  is_num "$END_TIME" || die "--end-time must be a non-negative number, got '$END_TIME'"
fi

if [ -n "${SMASH:-}" ]; then
  BIN="$SMASH"
else
  INSTALL_OUT="$("$HERE/install_smash.sh")" || die "install_smash.sh failed"
  BIN="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^SMASH=//p')"
fi
[ -x "$BIN" ] || die "no usable SMASH executable (SMASH='${SMASH:-unset}')"

if [ -z "$OUTDIR" ]; then
  OUTDIR="$(mktemp -d)"
else
  if [ -e "$OUTDIR" ]; then
    [ -d "$OUTDIR" ] || die "outdir '$OUTDIR' exists and is not a directory"
    [ -n "$(ls -A "$OUTDIR" 2>/dev/null)" ] && die "outdir '$OUTDIR' is not empty; give a fresh directory"
  else
    mkdir -p "$OUTDIR"
  fi
fi
OUTDIR="$(cd "$OUTDIR" && pwd -P)"

WORKCFG="$OUTDIR/config_used.yaml"
cp "$CONFIG" "$WORKCFG"
apply () {  # apply <key> <value> to the YAML, in place, only if requested
  local key="$1" val="$2"
  [ -n "$val" ] || return 0
  grep -qE "^[[:space:]]*$key:" "$WORKCFG" || die "config has no '$key:' line to override"
  python3 - "$WORKCFG" "$key" "$val" <<'PY'
import re, sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
new, n = re.subn(rf'(?m)^(\s*{re.escape(key)}:\s*)\S+', rf'\g<1>{val}', text)
if n == 0:
    sys.exit(1)
open(path, 'w').write(new)
PY
}
apply Randomseed "$SEED"
apply Nevents "$NEVENTS"
apply End_Time "$END_TIME"

# Refuse an unpinned seed by default. SMASH's shipped configs carry -1, and a
# run made with it cannot be compared with anything, including itself.
# Read the seed that will ACTUALLY be used, from the config as it now stands,
# and judge it numerically. A literal test against "-1" missed every other
# negative value, which SMASH treats identically.
EFFECTIVE_SEED="$(grep -E "^[[:space:]]*Randomseed:" "$WORKCFG" | head -1 | sed -E 's/.*Randomseed:[[:space:]]*//' | tr -d '\r')"
if [ "$ALLOW_RANDOM" = "0" ]; then
  if ! is_int "$EFFECTIVE_SEED"; then
    die "the configuration's Randomseed is '$EFFECTIVE_SEED', which is not an integer; pin it with --seed"
  fi
  if [ "$EFFECTIVE_SEED" -lt 0 ]; then
    die "the configuration's Randomseed is $EFFECTIVE_SEED; SMASH treats ANY negative seed as random, so this run would be irreproducible. Pass --seed <non-negative>, or --allow-random-seed."
  fi
fi

# Several shipped examples (box, sphere, multi_particle_box) carry their OWN
# particles.txt and decaymodes.txt next to the configuration, and SMASH does not
# pick those up implicitly: without -p/-d it silently runs the DEFAULT tables, so
# the run succeeds and is simply not the example you asked for. Auto-detect them.
CFGDIR="$(dirname "$CONFIG")"
if [ "$AUTO_TABLES" = "1" ]; then
  [ -z "$PARTICLES" ]  && [ -f "$CFGDIR/particles.txt" ]   && PARTICLES="$CFGDIR/particles.txt"
  [ -z "$DECAYMODES" ] && [ -f "$CFGDIR/decaymodes.txt" ] && DECAYMODES="$CFGDIR/decaymodes.txt"
fi
EXTRA=()
if [ -n "$PARTICLES" ]; then
  [ -f "$PARTICLES" ] || die "--particles '$PARTICLES' does not exist"
  cp "$PARTICLES" "$OUTDIR/particles_used.txt"; EXTRA+=(-p "$PARTICLES")
  log "using particle table $PARTICLES"
fi
if [ -n "$DECAYMODES" ]; then
  [ -f "$DECAYMODES" ] || die "--decaymodes '$DECAYMODES' does not exist"
  cp "$DECAYMODES" "$OUTDIR/decaymodes_used.txt"; EXTRA+=(-d "$DECAYMODES")
  log "using decay table $DECAYMODES"
fi

log "running $(basename "$BIN") with seed $EFFECTIVE_SEED into $OUTDIR"
set +e
( cd "$CFGDIR" && "$BIN" -i "$WORKCFG" -o "$OUTDIR/out" ${EXTRA+"${EXTRA[@]}"} ) > "$OUTDIR/smash.log" 2> "$OUTDIR/stderr.txt"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  log "SMASH exited with status $STATUS"
  tail -15 "$OUTDIR/stderr.txt" >&2 2>/dev/null
  tail -5 "$OUTDIR/smash.log" >&2 2>/dev/null
  exit 1
fi

OSCAR="$OUTDIR/out/particle_lists.oscar"
[ -s "$OSCAR" ] || die "no particle output at $OSCAR; the run produced nothing usable"

# Word-bounded: a bare substring search for "inf" would also match ordinary
# text, and the OSCAR header is text.
if grep -qiE "(^|[^a-z])(nan|inf|infinity)([^a-z]|$)" "$OSCAR"; then
  log "the particle output contains NaN or Inf"
  grep -niE "(^|[^a-z])(nan|inf|infinity)([^a-z]|$)" "$OSCAR" | head -3 >&2; exit 1
fi
# Match SMASH's log SEVERITY FIELD, not the word "error" anywhere in the text.
# SMASH lines look like "[15'04'57]  WARN   Fpe : Failed to setup trap on pole
# error." and a case-insensitive search for "error" flags that benign warning on
# every macOS run. Severity is the second field; aborts are matched literally.
ERROR_RE="^\[[^]]*\][[:space:]]+(ERROR|FATAL)\b|terminate called|Assertion .* failed"
if grep -qE "$ERROR_RE" "$OUTDIR/smash.log" "$OUTDIR/stderr.txt" 2>/dev/null; then
  log "the run logged an error:"; grep -E "$ERROR_RE" "$OUTDIR/smash.log" "$OUTDIR/stderr.txt" 2>/dev/null | head -5 >&2
  exit 1
fi

# Structural validation, not a line count. A stub that wrote a non-OSCAR header,
# two garbage records and two forged "# event ... end" comments used to be
# reported as a complete run.
head -1 "$OSCAR" | grep -qE '^#!OSCAR2013' \
  || die "the particle output does not start with an OSCAR2013 header"
NPART="$(grep -cvE '^#' "$OSCAR" || true)"
[ "${NPART:-0}" -gt 0 ] || die "the particle output has a header but no particles"

WANT_EVENTS="$(grep -E "^[[:space:]]*Nevents:" "$WORKCFG" | head -1 | sed -E 's/.*Nevents:[[:space:]]*//')"
# Match SMASH-3.3's real grammar, "# event N ensemble E out/end ...", and require
# the out and end blocks to pair up.
GOT_OUT="$(grep -cE '^# event [0-9]+ ensemble [0-9]+ out\b' "$OSCAR" || true)"
GOT_EVENTS="$(grep -cE '^# event [0-9]+ ensemble [0-9]+ end\b' "$OSCAR" || true)"
[ "${GOT_OUT:-0}" -eq "${GOT_EVENTS:-0}" ] \
  || die "the output has $GOT_OUT event-start and $GOT_EVENTS event-end markers; they must pair"
if [ -n "$WANT_EVENTS" ] && [ "${GOT_EVENTS:-0}" -ne "$WANT_EVENTS" ]; then
  die "requested $WANT_EVENTS events but the output completes $GOT_EVENTS of them; the run stopped early"
fi
# Every record must have the number of columns the header declares.
NCOL="$(head -1 "$OSCAR" | awk '{print NF-2}')"
BADCOL="$(awk -v n="$NCOL" '!/^#/ && NF != n' "$OSCAR" | wc -l | tr -d ' ')"
[ "${BADCOL:-0}" -eq 0 ] \
  || die "$BADCOL particle records do not have the $NCOL columns the header declares"

log "run complete: $GOT_EVENTS events, $NPART particle records"
echo "RESULT_DIR=$OUTDIR"
echo "RESULT_OSCAR=$OSCAR"
