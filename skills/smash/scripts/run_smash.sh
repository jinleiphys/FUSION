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

log () { echo "run_smash: $*" >&2; }
die () { log "$*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config)   CONFIG="${2:-}"; shift 2 ;;
    --outdir)   OUTDIR="${2:-}"; shift 2 ;;
    --seed)     SEED="${2:-}"; shift 2 ;;
    --nevents)  NEVENTS="${2:-}"; shift 2 ;;
    --end-time) END_TIME="${2:-}"; shift 2 ;;
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
for pair in "seed:$SEED" "nevents:$NEVENTS"; do
  name="${pair%%:*}"; val="${pair#*:}"
  [ -z "$val" ] && continue
  case "$val" in ''|*[!0-9-]*) die "--$name must be an integer, got '$val'" ;; esac
done
if [ -n "$END_TIME" ]; then
  case "$END_TIME" in ''|*[!0-9.]*) die "--end-time must be a number, got '$END_TIME'" ;; esac
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
EFFECTIVE_SEED="$(grep -E "^[[:space:]]*Randomseed:" "$WORKCFG" | head -1 | sed -E 's/.*Randomseed:[[:space:]]*//')"
if [ "$EFFECTIVE_SEED" = "-1" ] && [ "$ALLOW_RANDOM" = "0" ]; then
  die "Randomseed is -1, so this run would be irreproducible. Pass --seed <int>, or --allow-random-seed if that is what you want."
fi

log "running $(basename "$BIN") with seed $EFFECTIVE_SEED into $OUTDIR"
set +e
"$BIN" -i "$WORKCFG" -o "$OUTDIR/out" > "$OUTDIR/smash.log" 2> "$OUTDIR/stderr.txt"
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

NPART="$(grep -cvE '^#' "$OSCAR" || true)"
[ "${NPART:-0}" -gt 0 ] || die "the particle output has a header but no particles"

# The number of events actually written must match what was asked for, or the
# run stopped early while still exiting 0.
WANT_EVENTS="$(grep -E "^[[:space:]]*Nevents:" "$WORKCFG" | head -1 | sed -E 's/.*Nevents:[[:space:]]*//')"
GOT_EVENTS="$(grep -cE '^# event .* end' "$OSCAR" || true)"
if [ -n "$WANT_EVENTS" ] && [ "${GOT_EVENTS:-0}" -ne "$WANT_EVENTS" ]; then
  die "requested $WANT_EVENTS events but the output ends $GOT_EVENTS of them; the run stopped early"
fi

log "run complete: $GOT_EVENTS events, $NPART particle records"
echo "RESULT_DIR=$OUTDIR"
echo "RESULT_OSCAR=$OSCAR"
