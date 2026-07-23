#!/bin/bash
# run_nucleartoolkit.sh [nucleus] [interaction] [n_eigen]
#
# Run a valence shell-model calculation with NuclearToolkit.jl and report the
# lowest eigenvalues. This is the self-contained entry point (a shipped
# interaction, no chiral-EFT/IMSRG step). For the ab-initio pipeline
# (chiral EFT -> HFMBPT/IMSRG -> shell model) see references/input-format.md; it
# is exercised end to end by verify_nucleartoolkit.sh (Pkg.test).
#
#   nucleus      e.g. Be8 (default), Li6, He6, C12 for ckpot; O18, Ne20, Mg24 for usdb
#   interaction  ckpot (p-shell, default) or usdb (sd-shell); shipped with the package
#   n_eigen      number of eigenstates (default 10)
#
# CONTENT IS THE VERDICT: the eigenvalues are parsed and required to be finite,
# ascending, and with a negative ground state; a zero exit alone is not trusted.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

NUC="${1:-Be8}"
INT="${2:-ckpot}"
NEIG="${3:-10}"

# validate arguments (no path traversal into the package: fixed interaction set,
# alphanumeric nucleus, integer count)
case "$INT" in ckpot|usdb) : ;; *) echo "run_nucleartoolkit: interaction must be ckpot or usdb (got '$INT')" >&2; exit 2 ;; esac
case "$NUC" in *[!A-Za-z0-9]*|"") echo "run_nucleartoolkit: nucleus must be alphanumeric (got '$NUC')" >&2; exit 2 ;; esac
case "$NEIG" in ''|*[!0-9]*) echo "run_nucleartoolkit: n_eigen must be a positive integer (got '$NEIG')" >&2; exit 2 ;; esac
[ "$NEIG" -ge 1 ] || { echo "run_nucleartoolkit: n_eigen must be >= 1" >&2; exit 2; }

if [ -n "${NTK_JULIA:-}" ] && [ -n "${NTK_DEPOT:-}" ] && [ -n "${NTK_PROJ:-}" ] && [ -n "${NTK_PKGDIR:-}" ]; then
  JULIA="$NTK_JULIA"; DEPOT="$NTK_DEPOT"; PROJ="$NTK_PROJ"; PKGDIR="$NTK_PKGDIR"
else
  INSTALL_OUT="$(bash "$HERE/install_nucleartoolkit.sh")" || { echo "run_nucleartoolkit: install failed" >&2; exit 1; }
  JULIA="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_JULIA=//p' | tail -1)"
  DEPOT="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_DEPOT=//p' | tail -1)"
  PROJ="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_PROJ=//p' | tail -1)"
  PKGDIR="$(echo "$INSTALL_OUT" | sed -n 's/^NTK_PKGDIR=//p' | tail -1)"
fi
SNT="$PKGDIR/test/interaction_file/$INT.snt"
[ -f "$SNT" ] || { echo "run_nucleartoolkit: interaction file not found: $SNT" >&2; exit 1; }

OUT="$(mktemp)"; trap 'rm -f "$OUT"' EXIT
set +e
JULIA_DEPOT_PATH="$DEPOT" "$JULIA" --project="$PROJ" --startup-file=no -e '
  using NuclearToolkit
  snt, nuc, neig = ARGS[1], ARGS[2], parse(Int, ARGS[3])
  E = main_sm(snt, nuc, neig, Int[]; q=2, is_block=true)
  for (i, e) in enumerate(E)
      println("EIGEN ", i, " ", e)
  end
' "$SNT" "$NUC" "$NEIG" > "$OUT" 2>&1
RC=$?
set -e

python3 - "$OUT" "$NUC" "$INT" "$RC" "$NEIG" <<'PY'
import sys, math
path, nuc, intn, rc, neig = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
E = []
for l in open(path):
    if l.startswith("EIGEN "):
        try: E.append(float(l.split()[2]))
        except (IndexError, ValueError): pass
# A successful main_sm exits 0; a nonzero exit means the run failed even if it
# printed some eigenvalues first (a crash mid-diagonalization).
if rc != 0:
    sys.stderr.write(open(path).read()[-800:])
    print("run_nucleartoolkit: FAIL  main_sm exited %d (%d eigenvalue(s) printed before the failure)" % (rc, len(E))); sys.exit(1)
if not E:
    print("run_nucleartoolkit: FAIL  no eigenvalues in output"); sys.exit(1)
if len(E) != neig:
    print("run_nucleartoolkit: FAIL  requested %d eigenvalues but got %d" % (neig, len(E))); sys.exit(1)
if any(not math.isfinite(x) for x in E):
    print("run_nucleartoolkit: FAIL  a non-finite eigenvalue was produced"); sys.exit(1)
if E[0] >= 0:
    print("run_nucleartoolkit: FAIL  ground state is not negative (%.4f)" % E[0]); sys.exit(1)
# eigenvalues must be (non-strictly) ascending
for a, b in zip(E, E[1:]):
    if b < a - 1e-6:
        print("run_nucleartoolkit: FAIL  eigenvalues not ascending (%.4f then %.4f)" % (a, b)); sys.exit(1)
print("run_nucleartoolkit: %s with %s, %d state(s)" % (nuc, intn, len(E)))
for i, e in enumerate(E, 1):
    print("    state %2d  E = %11.4f MeV" % (i, e))
print("run_nucleartoolkit: PASS  (finite ascending spectrum, g.s. %.4f MeV; "
      "run verify_nucleartoolkit.sh for the benchmark)" % E[0])
PY
