#!/bin/bash
# selftest_cnok.sh
#
# Feed run_cnok.sh and verify_cnok.sh deliberately broken stub builds and assert
# each one is refused. Tests the harness, not mom and not the physics. Every case
# is a way a CNOK run can look successful while being wrong: a nonzero exit with a
# plausible file, an empty run, a non-finite result, a total that is not the sum
# of its parts, a silently substituted deck, a wrong reproduced number.
#
# Each negative case is built to fail ONLY the guard under test: it satisfies
# every other guard so that a pass would require the target guard to be the thing
# that fires. This is the "isolate each guard" half of the 2026-07-22 rule. The
# other half, that each guard actually flips (starts accepting) when disabled, was
# checked during development by disabling each guard on a copy and confirming
# exactly its case flipped; that is a one-off audit, not run here (disabling a
# guard in the shipped script would defeat its purpose). Exit status is captured
# on its own line into a variable, never read across a pipe.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

PASS=0; FAIL=0
ok  () { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad () { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
must_refuse () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -ne 0 ]; then ok "$l (refused, rc=$rc)"; else bad "$l (WRONGLY ACCEPTED)"; fi; }
must_accept () { local l="$1"; shift; "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq 0 ]; then ok "$l"; else bad "$l (WRONGLY REFUSED, rc=$rc)"; fi; }

# Build a stub build-tree in a fresh temp dir: a basedir.yaml, a C16/1s11p.yaml
# deck carrying Eref, and a stub `mom` of the requested behaviour. Echoes the
# build dir. $1 = behaviour keyword.
make_stub_build () {
  local mode="$1" d; d="$(mktemp -d)"
  mkdir -p "$d/config/C/C16"
  echo "basedir: config/C/C16" > "$d/config/basedir.yaml"
  cat > "$d/config/C/C16/1s11p.yaml" <<'YML'
Eref: 4.2503
n: 1
l: 0
j: 0.5
YML
  cat > "$d/mom" <<STUB
#!/bin/bash
# stub mom: arg 1 = config name; reads config/basedir.yaml for the basedir.
name="\$1"
base="\$(sed -n 's/^basedir:[[:space:]]*//p' config/basedir.yaml | head -1)"
out="\$base/\${name}_stub.txt"
write_res () { # \$1 str \$2 diff \$3 tot \$4 seref
  cat > "\$out" <<EOF
Run at stub
Orbit: 1s1/2_15C_n
S_N+Ex: \$4 MeV

The calculated total knockout cross sections (in mb)
       M       STRIP        DIFF       TOTAL
       0   \$1   \$2   \$3

In total:
Stripping c.s.:         \$1 mb
Diffractive c.s.:       \$2 mb
Total knockout c.s.:    \$3 mb
EOF
}
case "$mode" in
  good)          write_res 60.086689 18.056073 78.142761 4.250300; exit 0;;
  # str correct (so only the L1 reference check, not the L2 paper anchor, can
  # reject this), diff/total wrong: isolates verify's reference-match guard.
  wrong_result)  write_res 60.086689 99.000000 159.086689 4.250300; exit 0;;
  no_output)     echo "computed nothing"; exit 0;;
  nonzero_exit)  write_res 60.086689 18.056073 78.142761 4.250300; exit 99;;
  # 1e999 parses to +inf (so it clears the numeric regex and reaches the
  # isfinite check), isolating the finite guard from the parse guard that a bare
  # "nan" would trip instead.
  nonfinite)     write_res 60.086689 1e999     1e999     4.250300; exit 0;;
  negative)      write_res -5.000000 18.056073 13.056073 4.250300; exit 0;;
  bad_total)     write_res 60.086689 18.056073 99.999999 4.250300; exit 0;;
  wrong_seref)   write_res 60.086689 18.056073 78.142761 9.999999; exit 0;;
esac
STUB
  chmod +x "$d/mom"
  echo "$d"
}

run ()    { env CNOK_BUILD="$1" CNOK_YAMLLIB="" bash "$HERE/run_cnok.sh" "$2" config/C/C16; }
verify () { env CNOK_BUILD="$1" CNOK_YAMLLIB="" bash "$HERE/verify_cnok.sh"; }

echo "run_cnok.sh: inputs that must be REFUSED"

D="$(make_stub_build nonzero_exit)"
must_refuse "nonzero exit with a valid-looking result file" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build no_output)"
must_refuse "exit 0 but no result file written" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build nonfinite)"
must_refuse "non-finite cross section (nan diffractive)" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build negative)"
must_refuse "negative stripping cross section" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build bad_total)"
must_refuse "total is not stripping+diffractive" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build wrong_seref)"
must_refuse "result S_N+Ex disagrees with the deck Eref (substituted deck)" run "$D" 1s11p; rm -rf "$D"

D="$(make_stub_build good)"
must_refuse "requested config name has no deck (0d99z)" run "$D" 0d99z; rm -rf "$D"

echo
echo "run_cnok.sh: input that must be ACCEPTED (stub)"
D="$(make_stub_build good)"
must_accept "a well-formed stub result" run "$D" 1s11p; rm -rf "$D"

echo
echo "verify_cnok.sh: must FAIL when the result does not match the reference"
D="$(make_stub_build wrong_result)"
must_refuse "verify rejects a build whose cross sections differ from the pinned reference" verify "$D"; rm -rf "$D"

D="$(make_stub_build good)"
must_accept "verify accepts a stub that reproduces the pinned reference" verify "$D"; rm -rf "$D"

echo
echo "end-to-end on the REAL install (build + run + verify)"
must_accept "verify_cnok.sh passes on the real cnok build" bash "$HERE/verify_cnok.sh"

echo
echo "selftest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
