# validate_sky3d_output.sh
#
# One output validator, sourced by BOTH run_sky3d.sh and verify_sky3d.sh so the
# two cannot drift apart. Verify used to run the binary itself and thereby skip
# every guard run_sky3d.sh applies, which is exactly how a fatal stderr message
# or a NaN could have passed verification.
#
# validate_sky3d_output <workdir> <exit status> <allow unconverged: 0|1>
# Returns 0 when the run is usable, 1 otherwise, and explains itself on stderr.

validate_sky3d_output () {
  local w="$1" status="$2" allow="${3:-0}"
  local out="$w/for006" err="$w/stderr.txt" deck="$w/for005"

  _v () { echo "validate_sky3d: $*" >&2; }

  if [ "$status" -ne 0 ]; then
    _v "Sky3D exited with status $status"
    [ -s "$err" ] && tail -10 "$err" >&2
    return 1
  fi

  [ -s "$out" ] || { _v "for006 is empty; the run produced no output"; return 1; }

  # A Fortran runtime error can reach stderr while the exit status still looks
  # usable, so stderr is inspected rather than discarded.
  if [ -f "$err" ] && grep -qiE 'Fortran runtime error|Error termination|Segmentation fault|Backtrace' "$err"; then
    _v "the run wrote a fatal error to stderr:"; tail -10 "$err" >&2; return 1
  fi

  if grep -qiE 'NaN|Infinity' "$out"; then
    _v "for006 contains NaN or Infinity"
    grep -niE 'NaN|Infinity' "$out" | head -3 >&2
    return 1
  fi

  # A Fortran numeric field that overflows its format prints as a run of
  # asterisks, which downstream parsers skip silently. Sky3D decorates headers
  # the same way (" ***** Force definition *****"), so exclude that symmetric
  # header form first, or the check fires on every healthy run. Exercised in both
  # directions by selftest_sky3d.sh.
  if grep -vE '^[[:space:]]*\*{3,}.*\*{3,}[[:space:]]*$' "$out" | grep -qE '\*{4,}'; then
    _v "for006 contains a Fortran numeric field overflow (asterisks outside a header)"
    grep -vE '^[[:space:]]*\*{3,}.*\*{3,}[[:space:]]*$' "$out" | grep -nE '\*{4,}' | head -3 >&2
    return 1
  fi

  # Use the LAST energy, not the first: the first is the starting configuration,
  # and reporting it as "final" hid non-convergence.
  local energy
  energy="$(grep '^ Total:.*MeV' "$out" | tail -1 | sed -E 's/^ Total: *([^ ]+) MeV.*/\1/' || true)"
  [ -n "$energy" ] || { _v "for006 has no 'Total: ... MeV' line; the run reached no printout"; return 1; }
  python3 - "$energy" <<'PY' || { _v "final total energy '$energy' is not finite"; return 1; }
import sys, math
sys.exit(0 if math.isfinite(float(sys.argv[1].replace('E', 'e'))) else 1)
PY

  local mode
  mode="$(grep -oE 'imode *= *[0-9]+' "$deck" | head -1 | grep -oE '[0-9]+' || echo 1)"

  if [ "$mode" = "1" ]; then
    local iters maxiter
    iters="$(grep -c 'Static Iteration No' "$out" || true)"
    [ "${iters:-0}" -gt 0 ] || { _v "a static run (imode=1) printed no iterations"; return 1; }
    maxiter="$(grep -oiE 'maxiter *= *[0-9]+' "$deck" | head -1 | grep -oE '[0-9]+' || true)"
    if [ -n "$maxiter" ] && [ "$iters" -ge "$maxiter" ]; then
      if [ "$allow" = "1" ]; then
        _v "WARNING: static run hit maxiter=$maxiter without converging; accepted because --allow-unconverged was given"
      else
        _v "static run hit maxiter=$maxiter without reaching serr, so it did NOT converge"
        _v "(it still exits 0 and prints a full final block; pass --allow-unconverged to accept it)"
        return 1
      fi
    fi
    _v "static run: $iters iterations, final total energy $energy MeV"
  else
    local steps nt
    steps="$(grep -c 'Starting time step' "$out" || true)"
    [ "${steps:-0}" -gt 0 ] || { _v "a dynamic run (imode=2) printed no time steps"; return 1; }
    nt="$(grep -oiE 'nt *= *[0-9]+' "$deck" | head -1 | grep -oE '[0-9]+' || true)"
    # A dynamic run legitimately ends early only through the separation criterion.
    if ! grep -q 'Final separation distance reached' "$out"; then
      if [ -n "$nt" ] && [ "$steps" -lt "$nt" ]; then
        if [ "$allow" = "1" ]; then
          _v "WARNING: dynamic run stopped after $steps of nt=$nt steps with no separation message; accepted because --allow-unconverged was given"
        else
          _v "dynamic run stopped after $steps of nt=$nt steps and never printed"
          _v "'Final separation distance reached', so it terminated early"
          return 1
        fi
      fi
    fi
    _v "dynamic run: $steps time steps, final total energy $energy MeV"
  fi
  return 0
}
