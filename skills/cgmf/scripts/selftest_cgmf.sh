#!/bin/bash
# selftest_cgmf.sh
#
# Feed the harness deliberately broken inputs and assert it refuses each one.
# Tests run_cgmf.sh and verify_cgmf.sh, not cgmf.x and not the physics.
#
# Every case here was chosen because it is a way a CGMF run can look successful
# while being wrong: a data-path failure that still exits, a substituted case, an
# empty run, a wrong result reproduced from a stale file. Guards decay silently,
# so they are exercised rather than assumed. Exit status is captured directly
# into a variable on its own line, because an earlier skill's ad-hoc tests
# reported working code as broken by reading the wrong process's status.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"

# Resolve the real install once (for the must-accept cases).
INSTALL_OUT="$(bash "$HERE/install_cgmf.sh")"
REAL_BIN="$(echo "$INSTALL_OUT" | sed -n 's/^CGMF=//p' | tail -1)"
REAL_DATA="$(echo "$INSTALL_OUT" | sed -n 's/^CGMFDATA=//p' | tail -1)"
REAL_SRC="$(cd "$(dirname "$REAL_BIN")/../../.." && pwd)"
[ -x "$REAL_BIN" ] || { echo "selftest: no usable cgmf.x" >&2; exit 1; }

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# Write a stub cgmf.x with a named behaviour. It parses -i/-e/-n/-f like the real
# binary. $1 = behaviour keyword.
make_stub () {
  local mode="$1" f; f="$(mktemp)"
  cat > "$f" <<STUB
#!/bin/bash
zaid=""; einc=""; nev=""; base="histories.cgmf"
while getopts "e:n:i:f:t:d:s:" o; do case \$o in
  e) einc=\$OPTARG;; n) nev=\$OPTARG;; i) zaid=\$OPTARG;; f) base=\$OPTARG;; esac; done
case "$mode" in
  stderr_exit)  echo "Cannot find valid path to CGMF data" >&2; exit 255;;
  no_output)    echo "*** Prompt Fission Neutrons ***"; echo "<nu>_tot = 3.8"; exit 0;;
  wrong_zaid)   printf '# 99999 %s 1e-08\n 1 1 0 0 1 0 0 0 0 0\n' "\$einc" > "\${base}.0"
                echo "<nu>_tot = 3.8"; exit 0;;
  no_nubar)     printf '# %s %s 1e-08\n 1 1 0 0 1 0 0 0 0 0\n' "\$zaid" "\$einc" > "\${base}.0"
                echo "no summary here"; exit 0;;
  wrong_result) printf '# %s %s 1e-08\n 9 9 9 9 9 9 9 9 9 9\n' "\$zaid" "\$einc" > "\${base}.0"
                echo "<nu>_tot = 3.8"; exit 0;;
esac
STUB
  chmod +x "$f"; echo "$f"
}

echo "run_cgmf.sh: inputs that must be refused"

S="$(make_stub stderr_exit)"
must_refuse "data-path failure (stderr + nonzero exit)" \
  env CGMF_BIN="$S" CGMFDATA="$REAL_DATA" bash "$HERE/run_cgmf.sh" 98252 0.0 40 h "$(mktemp -d)"
rm -f "$S"

S="$(make_stub no_output)"
must_refuse "exit 0 but no history file written" \
  env CGMF_BIN="$S" CGMFDATA="$REAL_DATA" bash "$HERE/run_cgmf.sh" 98252 0.0 40 h "$(mktemp -d)"
rm -f "$S"

S="$(make_stub wrong_zaid)"
must_refuse "history header ZAID does not match the request" \
  env CGMF_BIN="$S" CGMFDATA="$REAL_DATA" bash "$HERE/run_cgmf.sh" 98252 0.0 40 h "$(mktemp -d)"
rm -f "$S"

S="$(make_stub no_nubar)"
must_refuse "summary has no finite <nu>_tot" \
  env CGMF_BIN="$S" CGMFDATA="$REAL_DATA" bash "$HERE/run_cgmf.sh" 98252 0.0 40 h "$(mktemp -d)"
rm -f "$S"

echo
echo "run_cgmf.sh: input that must be ACCEPTED"
must_accept "a real 40-event 252Cf(sf) run" \
  bash "$HERE/run_cgmf.sh" 98252 0.0 40 h "$(mktemp -d)"

echo
echo "verify_cgmf.sh: must fail when the output does not match the reference"
S="$(make_stub wrong_result)"
must_refuse "verify rejects a binary whose history differs from the shipped reference" \
  env CGMF_BIN="$S" CGMFDATA="$REAL_DATA" CGMF_SRC="$REAL_SRC" bash "$HERE/verify_cgmf.sh"
rm -f "$S"

echo
echo "verify_cgmf.sh: must pass on the real install"
must_accept "verify passes with the real cgmf.x" bash "$HERE/verify_cgmf.sh"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
