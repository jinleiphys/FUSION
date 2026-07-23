#!/bin/bash
# run_smash.sh
#
# Run a SMASH configuration in an isolated directory and assert the output is
# usable. Usage:
#
#   run_smash.sh --config <config.yaml> [--outdir <dir>] [--seed <int>]
#                [--nevents <int>] [--end-time <fm/c>] [--allow-random-seed]
#                [--particles <f>] [--decaymodes <f>] [--no-auto-tables]
#                [--workdir <dir>]
#
# --config     a SMASH YAML configuration. Copied into the output directory, so
#              the run records the input it actually used.
# --outdir     defaults to a fresh mktemp -d. Must be new or empty.
# --seed       overwrite General:Randomseed. SMASH's shipped configs use -1,
#              which draws a fresh seed per run and makes the output
#              irreproducible. A benchmark MUST pin the seed; run_smash.sh
#              therefore refuses -1 unless --allow-random-seed is given.
# --nevents, --end-time   convenience overrides for a shorter run.
# --workdir    directory to run SMASH from. Defaults to the config's directory,
#              which is what a Modus resolving paths relative to its config
#              needs. The shipped List example is the exception: its
#              File_Directory is relative to the BUILD directory, so it needs
#              --workdir "$SMASH_ROOT/build".
#
# Prints RESULT_DIR= and RESULT_OSCAR= on the last two lines.
#
# SMASH is GPL-3.0-or-later; see install_smash.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""; OUTDIR=""; SEED=""; NEVENTS=""; END_TIME=""; ALLOW_RANDOM=0
PARTICLES=""; DECAYMODES=""; AUTO_TABLES=1; WORKDIR=""

log () { echo "run_smash: $*" >&2; }
die () { log "$*"; exit 1; }

# An option given an EMPTY value is a caller bug, not a request for the default:
# `--end-time ""` used to skip validation entirely, because every check below is
# guarded by [ -n ... ], and the run then silently used the config's value.
need_val () { [ -n "${2:-}" ] || die "$1 requires a non-empty value"; printf '%s' "$2"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --config)   CONFIG="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --outdir)   OUTDIR="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --seed)     SEED="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --nevents)  NEVENTS="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --end-time) END_TIME="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --particles)  PARTICLES="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --decaymodes) DECAYMODES="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
    --workdir)  WORKDIR="$(need_val "$1" "${2:-}")" || exit 1; shift 2 ;;
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
# Bounded to 18 digits. The regex accepted an integer of ANY length, and the
# `-lt` comparison that follows is done by bash, which cannot represent one:
# `--seed 9223372036854775808` printed "integer expression expected" and then
# ran anyway, so the negative-seed guard was bypassed by a number too large to
# compare. 18 digits is comfortably inside int64 and far beyond any real seed.
is_int ()  { printf '%s' "$1" | grep -qE '^-?[0-9]{1,18}$'; }
is_uint () { printf '%s' "$1" | grep -qE '^[0-9]{1,18}$'; }
# Accepts every non-negative decimal literal SMASH's YAML reader does, including
# the ones the previous pattern wrongly rejected: '.5', '5.', '1e-3', '1.5E3'.
# Still rejects '.', '--', '1-2', '1..2' and anything negative.
is_num ()  { printf '%s' "$1" | grep -qE '^([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$'; }

# Strips an inline YAML comment. `Nevents: 2 # two events` is valid YAML, and
# without this the value read back was "2 # two events", is_uint rejected it, no
# --events expectation was passed, and the event-count check silently did
# nothing: a run that wrote one of two events passed. A validation that a
# comment can disable is not a validation.
read_key () {
  grep -E "^[[:space:]]*$1:" "$WORKCFG" 2>/dev/null | head -1 \
    | sed -E "s/.*$1:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//" | tr -d '\r' || true
}

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
EFFECTIVE_SEED="$(read_key Randomseed)"
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
# SMASH is invoked from inside CFGDIR (below), so a relative --particles path
# would be validated here against the CALLER's directory and then resolved by
# SMASH against a different one, silently loading another table or none. Make
# both paths absolute at the point of validation so the file checked is the file
# used.
abspath () { ( cd "$(dirname "$1")" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")" ); }
EXTRA=()
if [ -n "$PARTICLES" ]; then
  [ -f "$PARTICLES" ] || die "--particles '$PARTICLES' does not exist"
  PARTICLES="$(abspath "$PARTICLES")" || die "cannot resolve --particles path"
  cp "$PARTICLES" "$OUTDIR/particles_used.txt"; EXTRA+=(-p "$PARTICLES")
  log "using particle table $PARTICLES"
fi
if [ -n "$DECAYMODES" ]; then
  [ -f "$DECAYMODES" ] || die "--decaymodes '$DECAYMODES' does not exist"
  DECAYMODES="$(abspath "$DECAYMODES")" || die "cannot resolve --decaymodes path"
  cp "$DECAYMODES" "$OUTDIR/decaymodes_used.txt"; EXTRA+=(-d "$DECAYMODES")
  log "using decay table $DECAYMODES"
fi

# SMASH is run from the config's directory so that a Modus resolving paths
# relative to the config finds them. Some shipped configs assume a DIFFERENT
# cwd: input/list/config.yaml sets File_Directory: "../input/list", which
# resolves only from the build directory, so that example fails here with
# "External particle list does not exist". --workdir overrides the cwd for
# exactly those cases.
RUNDIR="${WORKDIR:-$CFGDIR}"
[ -d "$RUNDIR" ] || die "--workdir '$RUNDIR' is not a directory"
log "running $(basename "$BIN") with seed $EFFECTIVE_SEED into $OUTDIR"
set +e
( cd "$RUNDIR" && "$BIN" -i "$WORKCFG" -o "$OUTDIR/out" ${EXTRA+"${EXTRA[@]}"} ) > "$OUTDIR/smash.log" 2> "$OUTDIR/stderr.txt"
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  log "SMASH exited with status $STATUS"
  tail -15 "$OUTDIR/stderr.txt" >&2 2>/dev/null
  tail -5 "$OUTDIR/smash.log" >&2 2>/dev/null
  exit 1
fi

# The log scan runs BEFORE the output branching below, and must stay there.
# When the non-OSCAR path was added it exited early, ahead of this check, so a
# Binary-only run that logged a genuine ERROR returned success. Checks that
# apply to EVERY run belong before any branch that can exit.
#
# Match SMASH's log SEVERITY FIELD, not the word "error" anywhere in the text.
# SMASH lines look like "[15'04'57]  WARN   Fpe : Failed to setup trap on pole
# error." and a case-insensitive search for "error" flags that benign warning on
# every macOS run. Severity is the second field; aborts are matched literally.
ERROR_RE="^\[[^]]*\][[:space:]]+(ERROR|FATAL)\b|terminate called|Assertion .* failed"
if grep -qE "$ERROR_RE" "$OUTDIR/smash.log" "$OUTDIR/stderr.txt" 2>/dev/null; then
  log "the run logged an error:"; grep -E "$ERROR_RE" "$OUTDIR/smash.log" "$OUTDIR/stderr.txt" 2>/dev/null | head -5 >&2
  exit 1
fi

# The OSCAR particle list is what this wrapper can VALIDATE, not what SMASH is
# required to write. A configuration whose Output block asks only for Binary,
# Root, HepMC, YODA or Vtk is perfectly legitimate and used to fail here purely
# because particle_lists.oscar was absent. So: require the run to have produced
# SOMETHING, validate the OSCAR list when there is one, and say plainly when
# there is not, instead of pretending the run failed.
OSCAR="$OUTDIR/out/particle_lists.oscar"
if [ ! -e "$OSCAR" ]; then
  # SMASH ALWAYS writes the configuration it used into the output directory, so
  # "the directory is not empty" is satisfied by a run that produced no physics
  # output whatsoever. Count only files that are not that echo of the input.
  PRODUCED="$(find "$OUTDIR/out" -type f -size +0c ! -name config.yaml 2>/dev/null | wc -l | tr -d ' ')"
  [ "${PRODUCED:-0}" -gt 0 ] \
    || die "the run wrote no output beyond the copy of its own configuration; the Output: block requests nothing this produced"
  log "no particle_lists.oscar (this configuration requests other output formats);"
  log "$PRODUCED non-empty output files were written, but NOT structurally validated"
  echo "RESULT_DIR=$OUTDIR"
  exit 0
fi
[ -s "$OSCAR" ] || die "the particle output at $OSCAR is empty; the run produced nothing usable"

# Structural validation is DELEGATED to check_conservation_smash.py, which
# transcribes the grammar from src/oscaroutput.cc. It used to be re-implemented
# here in shell, and the two copies then disagreed: this one required the 'out'
# and 'end' markers to pair one-to-one, which is true only for the shipped
# Only_Final: Yes configuration. A real Only_Final: No run writes one 'in' and
# one 'out' per output interval inside a single event, and every such run was
# rejected. One grammar, one parser.
#
# Independent events = Nevents * Ensembles: each parallel ensemble is a separate
# system with its own initialisation and its own end marker, so a config with
# Nevents: 1 and Ensembles: 20 completes 20 of them, not 1.
# Both keys are OPTIONAL (Ensembles defaults to 1 and is absent from every
# shipped config), so a miss must return empty and succeed. Without the `|| true`
# the failing grep killed the whole script under `set -e`, after the run had
# already completed, with no message at all.
WANT_EVENTS="$(read_key Nevents)"
WANT_ENS="$(read_key Ensembles)"
EXPECT_ARG=()
if is_uint "${WANT_EVENTS:-}"; then
  if is_uint "${WANT_ENS:-}" && [ "${WANT_ENS:-1}" -ge 1 ]; then
    EXPECT_ARG=(--events "$((WANT_EVENTS * WANT_ENS))")
  else
    EXPECT_ARG=(--events "$WANT_EVENTS")
  fi
fi
if ! python3 "$HERE/check_conservation_smash.py" "$OSCAR" --structure-only \
       ${EXPECT_ARG+"${EXPECT_ARG[@]}"} >"$OUTDIR/structure.txt" 2>&1; then
  log "the particle output is not a well-formed OSCAR2013 particle list:"
  cat "$OUTDIR/structure.txt" >&2
  exit 1
fi
log "run complete: $(sed -n 's/^particles: //p' "$OUTDIR/structure.txt" | head -1)"
echo "RESULT_DIR=$OUTDIR"
echo "RESULT_OSCAR=$OSCAR"
