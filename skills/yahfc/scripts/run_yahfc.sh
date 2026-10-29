#!/bin/bash
# run_yahfc.sh <deck> [workdir] [file-to-stage ...]
#
# Run one YAHFC deck in a FRESH work directory and report honestly.
#   <deck>     a plain YAHFC command file. The example `.com` files in
#              YAHFC-Examples are shell scripts wrapping a deck in a heredoc;
#              extract the lines between `<< input` and the closing `input`.
#   [workdir]  must not exist or be empty; default ./yahfc-run-<deck name>.
#   [files]    copied into the workdir before the run: a proj_e_file energy
#              list, a cc_file, or shipped .tcoef + -CC.data pairs.
#
# Supported: particle-induced library runs (projectile n, p, d, t, h or a).
# Photon and population runs, and event_generator mode, print a different
# stdout layout and are refused rather than certified by the wrong rules.
#
# WHY A FRESH DIRECTORY. YAHFC reuses a <proj><target>.tcoef found in the run
# directory instead of calling Frescox, provided the matching -CC.data is there
# too (optical_setup.f90:184-199). A stale pair from another optical model would
# be used without a word, so a non-empty workdir is refused and every file present
# at start is one the caller named. provenance.txt records each staged file with
# its sha256 and, after the run, whether each .tcoef was used or recomputed.
#
# THE SEED. Without `ran_seed` YAHFC seeds from the clock. If the deck has none,
# `ran_seed $YAHFC_SEED` (default 12345) is added; the verdict then requires
# YAHFC-commands.txt to show that seed executed.
#
# THE DECK is read the way YAHFC reads it (yahfc_check.py, `deck`): an indented
# command, a tab, a line over 132 characters, a comment glued to a word, a
# commented proj_e_file line and anything after `end` are refused, because YAHFC
# would silently ignore or misread them.
#
# CONTENT IS THE VERDICT (yahfc_check.py, `verdict`): exit 0; only YAHFC's own
# mkdir/rm chatter on stderr; the closing banner; one block per announced energy,
# each with exactly one accounting check that succeeded and every required cross
# section exactly once, finite, non-negative, in the declared units; for neutrons
# sigma_tot = sigma_R + sigma_SE; no energy-conservation violations; the seed
# executed; every Frescox run recorded with exit 0, an output and an empty error
# file; one generated library whose Reaction_cs.dat matches stdout row by row;
# no NaN, Infinity or overflow field in the library, .tcoef or Frescox output.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/yahfc_check.py"

refuse () { local name="$1"; shift; echo "run_yahfc: REFUSED [$name], $*" >&2; exit 2; }

usage="usage: run_yahfc.sh <deck> [workdir] [file-to-stage ...]"
DECK="${1:?$usage}"; shift
[ -f "$DECK" ] || refuse deck "deck '$DECK' not found"
DECK="$(cd "$(dirname "$DECK")" && pwd)/$(basename "$DECK")"
NAME="$(basename "$DECK")"; NAME="${NAME%.*}"
WORK="${1:-$(pwd)/yahfc-run-$NAME}"; [ $# -gt 0 ] && shift
STAGE=("$@")
SEED="${YAHFC_SEED:-12345}"

# Resolve the binaries. YAHFC_BIN, FRESCOX, YAHFC_DIR and YAHFC_DATA may all be
# supplied (the self-test uses this to inject stubs); otherwise ask the installer.
if [ -n "${YAHFC_BIN:-}" ] && [ -n "${FRESCOX:-}" ] && [ -n "${YAHFC_DIR:-}" ] && [ -n "${YAHFC_DATA:-}" ]; then
  BIN="$YAHFC_BIN"; FX="$FRESCOX"; SRC="$YAHFC_DIR"; DATA="$YAHFC_DATA"
else
  INSTALL_OUT="$(bash "$HERE/install_yahfc.sh")"
  BIN="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC=//p' | tail -1)"
  FX="$(echo "$INSTALL_OUT" | sed -n 's/^FRESCOX=//p' | tail -1)"
  SRC="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC_DIR=//p' | tail -1)"
  DATA="$(echo "$INSTALL_OUT" | sed -n 's/^YAHFC_DATA=//p' | tail -1)"
fi
[ -x "$BIN" ] || refuse binary "no usable YAHFC.x ($BIN)"
[ -x "$FX" ] || refuse binary "no usable frescox ($FX)"
[ -d "$DATA" ] || refuse binary "data directory not found ($DATA)"
case "$DATA" in */) ;; *) DATA="$DATA/";; esac
[ "${#DATA}" -le 110 ] || refuse datapath "data path is ${#DATA} characters; YAHFC appends Coupled-Channels.txt to it in a 132-character buffer, which fails from 111 on (measured)"
[ "$(basename "$FX")" = frescox ] || refuse fxname "Frescox binary must be named 'frescox' (got $FX)"

# Fresh workdir only.
if [ -e "$WORK" ]; then
  [ -d "$WORK" ] || refuse workdir "workdir '$WORK' exists and is not a directory"
  [ -z "$(ls -A "$WORK")" ] || refuse nonempty "workdir '$WORK' is not empty; YAHFC would reuse any .tcoef/-CC.data in it. Give a new directory and stage files explicitly"
fi
mkdir -p "$WORK"
WORK="$(cd "$WORK" && pwd)"

sha () { if command -v shasum >/dev/null; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
PROV="$WORK/provenance.txt"
{
  echo "# run_yahfc provenance, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "deck $DECK sha256 $(sha "$DECK")"
  echo "yahfc $BIN"
  echo "yahfc_commit $(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "frescox $FX"
} > "$PROV"

# Staged files: plain names only, never one of the files this script or YAHFC writes.
STAGED_LIST="$(mktemp)"
FXREC="$(mktemp -d)"
trap 'rm -rf "$STAGED_LIST" "$FXREC"' EXIT
for f in ${STAGE[@]+"${STAGE[@]}"}; do
  [ -f "$f" ] || refuse stagemissing "file to stage '$f' not found"
  b="$(basename "$f")"
  case "$b" in *[[:space:]]*) refuse stagename "staged file name '$b' contains whitespace; YAHFC cannot open such a name";; esac
  case "$b" in input.txt|provenance.txt|yahfc.stdout|yahfc.stderr|YAHFC-commands.txt|Fresco-files) refuse reserved "'$b' is a name this run writes; rename the file";; esac
  [ ! -e "$WORK/$b" ] || refuse stagedup "two staged files share the name '$b'"
  cp "$f" "$WORK/$b"
  echo "$b" >> "$STAGED_LIST"
  echo "staged $b from $(cd "$(dirname "$f")" && pwd)/$b sha256 $(sha "$f")" >> "$PROV"
done

# Deck preflight (exit 2 on refusal), read the way YAHFC reads it.
PRE="$(python3 "$CHECK" deck "$DECK" "$SEED" "$STAGED_LIST")" || exit 2
SEED_ACTION="$(echo "$PRE" | sed -n 's/^SEED_ACTION=//p')"
SEED="$(echo "$PRE" | sed -n 's/^SEED=//p')"
PROJ="$(echo "$PRE" | sed -n 's/^PROJ=//p')"
UNITS="$(echo "$PRE" | sed -n 's/^UNITS=//p')"
TDIR="$(echo "$PRE" | sed -n 's/^TARGET_DIR=//p')"

INPUT="$WORK/input.txt"
if [ "$SEED_ACTION" = inject ]; then
  { echo "ran_seed $SEED"; cat "$DECK"; } > "$INPUT"
  echo "seed injected: ran_seed $SEED (deck had none; YAHFC would have used the clock)" >> "$PROV"
  echo "run_yahfc: deck has no ran_seed; added 'ran_seed $SEED' so the run is reproducible" >&2
else
  cp "$DECK" "$INPUT"
  echo "seed from deck: $SEED" >> "$PROV"
fi

# A recording wrapper named frescox goes first on PATH: YAHFC calls frescox by
# bare name through system() and never checks its exit status
# (run_fresco.f90:355), so the wrapper logs every call's status for the verdict.
FXLOG="$FXREC/exits.log"; : > "$FXLOG"
# %q quotes both paths for the shell, so a path containing $, backticks or
# spaces is passed literally and never expanded.
FXABS="$(cd "$(dirname "$FX")" && pwd)/$(basename "$FX")"
printf '#!/bin/bash\n%q "$@"\nrc=$?\necho "$rc" >> %q\nexit "$rc"\n' "$FXABS" "$FXLOG" > "$FXREC/frescox"
chmod +x "$FXREC/frescox"

LOG="$WORK/yahfc.stdout"; ERR="$WORK/yahfc.stderr"
set +e
# LC_ALL=C keeps the mkdir/rm chatter in the English wording the verdict
# filters by; a localized system (heliumx runs zh_CN) prints it translated.
( cd "$WORK" && LC_ALL=C LANG=C PATH="$FXREC:$PATH" YAHFC_DIR="$SRC" YAHFC_DATA="$DATA" "$BIN" < "$INPUT" > "$LOG" 2> "$ERR" )
RC=$?
set -e

python3 "$CHECK" verdict "$WORK" "$RC" "$SEED" "$PROJ" "$UNITS" "$TDIR" "$FXLOG" "$STAGED_LIST" || {
  echo "  work directory: $WORK" >&2; exit 1; }
echo "work directory: $WORK  (provenance.txt, yahfc.stdout, library)"
