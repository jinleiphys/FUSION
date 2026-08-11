#!/bin/bash
# run_sfresco.sh <file.search> [file.min] [runname]
#
# Run SFRESCO on a search file in a fresh scratch dir, then print the fit
# summary (initial chi2, final chi2, fitted parameters with errors, error-matrix
# status, correlations).
#
# Why a scratch dir: sfresco writes the search output, -init, -trace, -snap,
# search.plot, minuit-saved.dat and ~20 fort.* files into cwd. Never run it in a
# source tree or in the directory holding your only copy of the data.
#
# The search file, the FRESCO deck named on its first line, and any external
# data files it references are copied in automatically.
#
# With no .min file, a standard batch session is generated:
#   q / plot <name>-init.plot / min / set strategy 2 / migrad / hesse / end
#   / q / show / plot <name>-fit.plot / ex
# `hesse` is what turns "ERR MATRIX APPROXIMATE" into real error bars, and the
# second `q` must come after `end` or you report the starting values.
#
# Config (env): SFRESCO_BIN (default ~/bin/sfresco), SFRESCO_SCRATCH.

set -euo pipefail

SEARCH="${1:?usage: run_sfresco.sh <file.search> [file.min] [runname]}"
MIN="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SBASE="$(basename "$SEARCH")"
NAME="${3:-${SBASE%.*}}"
# The scratch dir is removed with rm -rf, so the run name must not be able to
# point outside it: no slashes, no dots, nothing but a plain directory name.
NAME="$(printf '%s' "$(basename "$NAME")" | tr -c 'A-Za-z0-9._-' '_')"
case "$NAME" in ""|.|..) NAME="run" ;; esac

[ -f "$SEARCH" ] || { echo "ERROR: search file not found: $SEARCH" >&2; exit 1; }
SDIR="$(cd "$(dirname "$SEARCH")" && pwd)"

# ---- binary -----------------------------------------------------------------
# sfresco contains FRESCO, so this one binary is all that is needed. It is built
# by the fresco skill's installer, which produces `fresco` and `sfresco` together.
BIN="${SFRESCO_BIN:-$HOME/bin/sfresco}"
if [ ! -x "$BIN" ] && command -v sfresco >/dev/null 2>&1; then
  BIN="$(command -v sfresco)"
fi
if [ ! -x "$BIN" ]; then
  INSTALLER="$HERE/../../fresco/scripts/install_fresco.sh"
  if [ -x "$INSTALLER" ]; then
    # No --force: the installer already treats "fresco present but sfresco
    # missing" as a reason to build, and --force would overwrite whatever
    # binaries are in ~/bin, which is the user's decision and not ours.
    echo "# sfresco not found; building fresco + sfresco from source (~2 min)" >&2
    "$INSTALLER" >&2 || true
    BIN="${SFRESCO_BIN:-$HOME/bin/sfresco}"
    [ -x "$BIN" ] || { command -v sfresco >/dev/null 2>&1 && BIN="$(command -v sfresco)"; }
  fi
fi
if [ ! -x "$BIN" ]; then
  echo "ERROR: sfresco binary not found (tried \$SFRESCO_BIN, ~/bin/sfresco, PATH)." >&2
  echo "       The fresco skill owns the build. Either:" >&2
  echo "         bash <path-to>/skills/fresco/scripts/install_fresco.sh --force" >&2
  echo "       or build it by hand:" >&2
  echo "         git clone --depth 1 https://github.com/I-Thompson/fresco" >&2
  echo "         make -C fresco/source FC=gfortran && cp fresco/source/sfresco ~/bin/" >&2
  echo "       Needs gfortran, git, make (macOS: brew install gcc)." >&2
  exit 1
fi
BIN="$(cd "$(dirname "$BIN")" && pwd -P)/$(basename "$BIN")"

# ---- scratch dir + inputs ---------------------------------------------------
SCRATCH="${SFRESCO_SCRATCH:-${TMPDIR:-/tmp}/sfresco-runs}/$NAME"
rm -rf "$SCRATCH"; mkdir -p "$SCRATCH"
cp "$SEARCH" "$SCRATCH/$SBASE"

# copy_in <relative-name> <what-it-is>: copy a file the search deck references,
# keeping any relative directory, since SFRESCO opens it by the name it was given.
copy_in() {
  local f="$1" what="$2" src=""
  if   [ -f "$SDIR/$f" ]; then src="$SDIR/$f"
  elif [ -f "$f" ];       then src="$f"
  else return 1
  fi
  case "$f" in */*) mkdir -p "$SCRATCH/$(dirname "$f")" ;; esac
  cp "$src" "$SCRATCH/$f"
}

# First line of a search file: 'fresco_input' 'fresco_output' [nvars ndata].
# Fortran list-directed input accepts single or double quotes.
DECK="$(head -1 "$SEARCH" | sed -n -e "s/^[^'\"]*['\"]\([^'\"]*\)['\"].*/\1/p")"
if [ -n "$DECK" ]; then
  copy_in "$DECK" deck || {
    echo "ERROR: FRESCO deck '$DECK' named in $SBASE not found next to it" >&2; exit 1; }
else
  echo "WARNING: could not read the FRESCO deck name from line 1 of $SBASE" >&2
fi

# External data files: data_file='name' or "name" (skip '=' inline and '<' stdin).
# Read line by line so names containing spaces survive.
# `|| true`: grep exits 1 when a search file has no external data files at all,
# and `set -o pipefail` would turn that into a silent early exit.
{ grep -io "data_file *= *['\"][^'\"]*['\"]" "$SEARCH" || true; } |
  sed -e "s/.*['\"]\(.*\)['\"]/\1/" | sort -u |
while IFS= read -r df; do
  case "$df" in "="|"<"|"") continue ;; esac
  copy_in "$df" data || \
    echo "WARNING: data file '$df' not found; sfresco will fail on it" >&2
done

# ---- command file -----------------------------------------------------------
if [ -n "$MIN" ]; then
  [ -f "$MIN" ] || { echo "ERROR: command file not found: $MIN" >&2; exit 1; }
  # Force line 1 to the copied search file, so a path in the .min cannot break.
  { echo "$SBASE"; tail -n +2 "$MIN"; } > "$SCRATCH/cmd.min"
else
  cat > "$SCRATCH/cmd.min" <<EOF
$SBASE
q
plot $NAME-init.plot
min
set strategy 2
migrad
hesse
end
q
show
plot $NAME-fit.plot
ex
EOF
fi

# ---- run --------------------------------------------------------------------
cd "$SCRATCH"
echo "# run dir : $SCRATCH"
echo "# binary  : $BIN"
echo "# search  : $SBASE   deck: ${DECK:-?}"
STATUS=0
"$BIN" < cmd.min > "$NAME.log" 2>&1 || STATUS=$?

# ---- summary ----------------------------------------------------------------
echo "# --- fit summary ---"
python3 "$HERE/fitreport.py" "$NAME.log" || {
  echo "(fitreport failed; raw chi2 lines follow)"
  grep -E "ChiSq/N" "$NAME.log" | tail -3 || true
}
echo "# outputs : $SCRATCH/$NAME.log  (plots: *.plot, trace: *-trace, snaps: *-snap)"
if [ "$STATUS" -ne 0 ]; then
  echo "# sfresco exited non-zero (status $STATUS); the summary above may be incomplete" >&2
fi
exit "$STATUS"
