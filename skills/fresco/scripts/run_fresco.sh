#!/bin/bash
# run_fresco.sh <deck.in> [runname]
# Runs ~/bin/fresco on a deck inside a fresh scratch dir (so the many fort.* files
# never pollute a source tree), then prints the integrated cross sections.
#
# Why a scratch dir: FRESCO writes ~20 fort.* files into cwd. Running in a repo or
# a shared tree leaves junk and can overwrite files. Always isolate.
#
# Note: this machine (macOS) has no `timeout`. To cap a long run, kill it by hand
# or run on a Linux box. Heavy production runs go remote, not here.

set -euo pipefail

FRESCO="${FRESCO_BIN:-$HOME/bin/fresco}"
DECK="${1:?usage: run_fresco.sh <deck.in> [runname]}"
NAME="${2:-$(basename "${DECK%.*}")}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate the deck first, before any (possibly slow) network clone / compile.
if [ ! -f "$DECK" ]; then
  echo "ERROR: deck not found: $DECK" >&2
  exit 1
fi

# Auto-install: if the binary is missing, build it from source once.
if [ ! -x "$FRESCO" ]; then
  if command -v fresco >/dev/null 2>&1; then
    FRESCO="$(command -v fresco)"
  else
    echo "# fresco not found at $FRESCO; building from source (one time)" >&2
    RESOLVED="$("$HERE/install_fresco.sh" | sed -n 's/^FRESCO=//p' | tail -1)"
    [ -n "$RESOLVED" ] && FRESCO="$RESOLVED"
  fi
fi
if [ ! -x "$FRESCO" ]; then
  echo "ERROR: fresco binary not found/executable at $FRESCO" >&2
  echo "       build it with: $HERE/install_fresco.sh" >&2
  echo "       or set FRESCO_BIN=/path/to/fresco" >&2
  exit 1
fi
# Absolutize the binary path so it still resolves after we cd into the scratch dir.
case "$FRESCO" in
  */*) FRESCO="$(cd "$(dirname "$FRESCO")" && pwd -P)/$(basename "$FRESCO")" ;;
esac

SCRATCH="${FRESCO_SCRATCH:-${TMPDIR:-/tmp}/fresco-runs}/$NAME"
mkdir -p "$SCRATCH"
cp "$DECK" "$SCRATCH/in"
cd "$SCRATCH"

echo "# run dir : $SCRATCH"
echo "# binary  : $FRESCO"
START=$(python3 -c "import time;print(time.time())" 2>/dev/null || echo 0)
STATUS=0
"$FRESCO" < in > out 2>&1 || STATUS=$?
END=$(python3 -c "import time;print(time.time())" 2>/dev/null || echo 0)

echo "# runtime : $(python3 -c "print(f'{$END-$START:.2f}s')" 2>/dev/null || echo '?')"
echo "# --- integrated cross sections (last energy) ---"
grep -i "CUMULATIVE REACTION\|CUMULATIVE outgoing cross sections in partition\|Cumulative ABSORB\|CUMULATIVE OUTGOING" out | tail -8 || \
  echo "(no CUMULATIVE block found; run may have failed, inspect $SCRATCH/out)"
echo "# full output: $SCRATCH/out   (fort.* files also in $SCRATCH)"
if [ "$STATUS" -ne 0 ]; then
  echo "# fresco exited non-zero (status $STATUS); the result above may be incomplete" >&2
fi
exit "$STATUS"
