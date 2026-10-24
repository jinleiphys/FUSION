#!/bin/bash
# run_band.sh: run a Python script (or `-m module`, or `-c code`) in the BAND environment,
# installing it first if needed. All arguments are passed to that environment's python.
#
#   run_band.sh my_calibration.py --seed 3
#   run_band.sh -m pytest -q --pyargs surmise.tests
#
# The exit status is python's. A script that prints results and then raises still exits
# nonzero here; do not report a run as successful on its printed output alone.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PY="$(bash "$HERE/install_band.sh" | sed -n 's/^BAND_PYTHON=//p')"
[ -x "$PY" ] || { echo "run_band: the BAND environment is not available" >&2; exit 1; }
# Put the environment's bin/ first, as activating it would: openbt (Taweret's tree mixing)
# launches `mpirun` at run time, and in a conda-built environment that lives there.
export PATH="$(dirname "$PY"):$PATH"
exec "$PY" "$@"
