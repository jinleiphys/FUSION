#!/bin/bash
# selftest_yahfc.sh [--real]
#
# Prove the guards of run_yahfc.sh and yahfc_check.py fire, each for its own
# reason. A stub YAHFC.x writes a small synthetic run in the real layout (stdout
# with a NUL byte, per-energy blocks, Frescox called through PATH, a library,
# YAHFC-commands.txt); each negative case mutates exactly one thing.
#
#   1. Positive controls pass: clean neutron run; stderr carrying only YAHFC's
#      own mkdir/rm chatter (BSD and GNU wording); cs_units mb (reported as
#      mb); a charged projectile (stdout carries sigma_R only); a ran_seed line
#      with a trailing comment; a Frescox path containing `$` (must run as is).
#   2. Every negative case fails AND its message carries its own guard's tag,
#      so a case that trips some other guard first is caught as wrong.
#   3. Flip test: for each guard, a copy of the scripts with that guard disabled
#      (G("x", ...) -> G("x", True or ...); `refuse x` -> `: x`) must let that
#      guard's flip cases pass. The edit is asserted to have applied, and every
#      guard tag in the two scripts must have a case. Other cases are not rerun:
#      step 2 shows each fails at its own guard first, and disabling a different
#      guard only skips a check that case already passed. Cases marked fire-only cannot flip by
#      construction (with the guard off the run cannot go on: no deck file, no
#      binary, no workdir, no target, no particle library, no energy to
#      compare), so step 2 is their proof. The proof is per tag, not per call
#      site, and assumes guard conditions have no side effects.
#
# --real: perturb expectations in a copy of verify_yahfc.sh (one L1 cross
# section by 2e-6, one event count, the L2 energy grid at E#1, one EXFOR value
# beyond 6%) and require exactly the five FAILs they imply from the real
# install. About 45 s.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAILS=0
ok () { echo "  PASS  $*"; }
no () { echo "  FAIL  $*"; FAILS=$((FAILS+1)); }

# ---------------------------------------------------------------- stubs
mkdir -p "$T/bin" "$T/bin2" "$T/src"
# the stub never reads nuclear data, but run_yahfc.sh enforces the 110-character
# data-path limit, so the stub data dir must be short whatever TMPDIR is
SD="$(mktemp -d /tmp/ysd.XXXXXX)"
trap 'rm -rf "$T" "$SD"' EXIT
cat > "$T/bin/YAHFC.x" <<'EOF'
#!/bin/bash
# Stub YAHFC: read the deck, write a two-energy run in YAHFC's layout.
M="${STUB_MODE:-good}"
cat > stub-input.txt
U="b"; grep -qiE '^cs_units +mb' stub-input.txt && U="mb"; [ "$M" = units ] && U="mb"
CH=0; grep -qiE '^projectile +p' stub-input.txt && CH=1
mkdir -p Fresco-files
{ echo "#YAHFC commands in order of execution"
  echo "# Default Random iseed_32 =         -3157113"
  if [ "$M" = seedrun ]; then grep -v '^ran_seed' stub-input.txt; else cat stub-input.txt; fi; } > YAHFC-commands.txt
blk () {  # blk <E> <tot> <R> <SE> <accounted: y | n | 2>
  printf 'Incident energy =   %s MeV\n' "$1"
  printf 'Reaction cross section =    %s  %s\n' "$3" "$U"
  if [ "$CH" = 0 ]; then
    printf 'Total cross section =   %s  %s\n' "$2" "$U"
    [ "$M" = xsdup ] && printf 'Total cross section =   %s  %s\n' "$2" "$U"
  fi
  printf 'Total Reaction cross section =   %s  %s\n' "$3" "$U"
  printf 'Compound cross section =   %s  %s\n' "$3" "$U"
  [ "$CH" = 0 ] && printf 'Shape Elastic cross section =   %s  %s\n' "$4" "$U"
  [ "$M" = malformeddup ] && [ "$CH" = 0 ] && printf 'Total cross section = -99 b extra\n'
  printf ' Check that all events are accounted for\n Check_sum =   1.00000000\n'
  [ "$5" = n ] || printf ' All events are accounted for\n'
  [ "$5" = 2 ] && printf ' All events are accounted for\n'
  printf '\n'
}
E1=1.0000000E+00; [ "$M" = nanenergy ] && E1=NaN
T1=6.0000000E+00; R1=2.5000000E+00; S1=3.5000000E+00
[ "$M" = identity ] && T1=6.1000000E+00
TOTNEG=4.0000000E+00; [ "$M" = libvalues ] && TOTNEG=-4.0000000E+00
[ "$M" = overflowexp ] && TOTNEG=1e999
XU="xs( b)"; [ "$U" = mb ] && XU="xs(mb)"; [ "$M" = libunits ] && XU="xs(mb)"
[ "$M" = xsvalues ] && { T1=-1.0000000E+00; S1=-3.5000000E+00; }
{
  printf ' *************************************************************\n'
  printf 'Memory used\000 for all arrays = 1.0 kbytes'; [ "$M" = stdoutnan ] && printf ' NaN'; printf '\n'
  [ "$M" = lowernan ] && printf ' diagnostic = nan\n'
  case "$M" in noloop) ;; loop) printf ' Starting energy loop with            3  values\n' ;;
    *) printf ' Starting energy loop with            2  values\n' ;; esac
  for i in 1 2; do
    c="frescox < Fresco-files/nZr90-ie_000$i.in > Fresco-files/nZr90-ie_000$i.out 2>> Fresco-files/nZr90_fresco_err.out"
    echo "x" > "Fresco-files/nZr90-ie_000$i.in"
    echo "$c"; eval "$c"
  done
  A1=y; A2=y; [ "$M" = account ] && { A1=n; A2=2; }
  blk "$E1" "$T1" "$R1" "$S1" "$A1"
  blk 1.4000000E+01 4.0000000E+00 1.8000000E+00 2.2000000E+00 "$A2"
  if [ "$M" = econs ]; then printf ' There were            3  events violated energy conservation during primary sampling\n'
  else printf ' There were no events that violated energy conservation at 0.1 keV level\n'; fi
  [ "$M" = banner ] || printf " That's all Folks\n"
}
LIB=90Zr; [ "$M" = wrongtarget ] && LIB=235U
PD=n; [ "$CH" = 1 ] && PD=p
mkdir -p $LIB/$PD
if [ "$M" != nolib ]; then
  LE=1.0000000E+00; [ "$M" = libenergy ] && LE=999.0
  { printf '#******************************************************************\n#         E_in              %s\n' "$XU"
    printf '       %s      %s\n       1.4000000E+01      1.8000000E+00\n' "$LE" "$R1"; } > $LIB/$PD/Reaction_cs.dat
fi
{ printf '#******************************************************************\n'
  [ "$M" = hdroverflow ] && printf '# E_in = ****************\n'
  printf '#         E_in              %s\n       1.0000000E+00      6.0000000E+00\n' "$XU"
  case "$M" in
    nan)      printf '       1.4000000E+01                NaN\n' ;;
    overflow) printf '       1.40E+01****************\n' ;;
    *)        printf '       1.4000000E+01      %s\n' "$TOTNEG" ;;
  esac; } > $LIB/$PD/Total_cs.dat
[ "$M" = missingerr ] && rm -f Fresco-files/nZr90_fresco_err.out
[ "$M" = fxoverflow ] && printf '    1.00********\n' >> Fresco-files/nZr90-ie_0001.out
[ "$M" = frescodat ] && printf '1 NaN\n' > Fresco-files/results.dat
printf '   1   0.5   0.25\n' > nZr90.tcoef
case "$M" in
  noise)  echo "mkdir: Fresco-files: File exists" >&2
          echo "rm: fort.*: No such file or directory" >&2
          echo "rm: 90Zr: No such file or directory" >&2
          echo "mkdir: cannot create directory 'Fresco-files': File exists" >&2
          echo "rm: cannot remove 'fort.*': No such file or directory" >&2
          echo "rm: cannot remove '90Zr': No such file or directory" >&2 ;;
  stderr) echo "mkdir: important-results: File exists" >&2 ;;
esac
[ "$M" = rc ] && exit 3
exit 0
EOF
cat > "$T/bin/frescox" <<'EOF'
#!/bin/bash
cat > /dev/null
echo "frescox stub output"
[ "${STUB_MODE:-}" = fxfiles ] && echo "Fortran runtime error: stub" >&2
[ "${STUB_MODE:-}" = fxnote ] && echo "Note: The following floating-point exceptions are signalling: IEEE_DENORMAL" >&2
[ "${STUB_MODE:-}" = fxinvalid ] && echo "Note: The following floating-point exceptions are signalling: IEEE_INVALID_FLAG IEEE_DENORMAL" >&2
[ "${STUB_MODE:-}" = fxexit ] && exit 9
exit 0
EOF
cp "$T/bin/frescox" "$T/bin2/fresco"; cp "$T/bin/frescox" "$T/bin2/frescox"
chmod +x "$T/bin/YAHFC.x" "$T/bin/frescox" "$T/bin2/fresco" "$T/bin2/frescox"
LONGDATA="$T/data-$(printf 'x%.0s' $(seq 1 110))"; mkdir -p "$LONGDATA"
echo "0.5" > "$T/elist.txt"; echo "x" > "$T/input.txt"; echo "x" > "$T/name with space.txt"
mkdir -p "$T/dup1" "$T/dup2"; echo 1 > "$T/dup1/a.txt"; echo 2 > "$T/dup2/a.txt"

GOOD='file Zr90\ntarget Zr90\nprojectile n\nnum_mc_samp 10\nend\n'
mk () { printf "$2" > "$T/$1.inp"; }
mk good "$GOOD"
mk mb 'file Zr90\ntarget Zr90\nprojectile n\ncs_units mb\nend\n'
mk charged 'file Zr90\ntarget Zr90\nprojectile p\nend\n'
mk wrapper "time YAHFC.x << input\n$GOOD"
mk afterend "${GOOD}num_mc_samp 20\n"
mk indent 'file Zr90\ntarget Zr90\nprojectile n\n num_mc_samp 10\nend\n'
mk tab 'file Zr90\ntarget Zr90\nprojectile n\nxs_only\ty\nend\n'
printf 'file Zr90%140s\ntarget Zr90\nprojectile n\nend\n' ' ' > "$T/long.inp"
mk glued 'file Zr90\ntarget Zr90\nprojectile n\nxs_only y#note\nend\n'
mk dupseed 'ran_seed 7\nran_seed 7\nfile Zr90\ntarget Zr90\nprojectile n\nend\n'
mk seedval 'ran_seed x\nfile Zr90\ntarget Zr90\nprojectile n\nend\n'
mk nsamp 'file Zr90\ntarget Zr90\nprojectile n\nnum_mc_samp 0\nend\n'
mk quiet 'file Zr90\ntarget Zr90\nprojectile n\nverbose_output n\nend\n'
mk mode 'file Zr90\ntarget Zr90\nprojectile g\nend\n'
mk evgen 'file Zr90\ntarget Zr90\nprojectile n\nevent_generator y\nend\n'
mk dunits 'file Zr90\ntarget Zr90\nprojectile n\ncs_units kb\nend\n'
mk pecomment 'file Zr90\ntarget Zr90\nprojectile n\nproj_e_file elist.txt # elist.txt\nend\n'
mk unstaged 'file Zr90\ntarget Zr90\nprojectile n\nproj_e_file elist.txt\nend\n'
mk extpath 'file Zr90\ntarget Zr90\nprojectile n\nproj_e_file ../elist.txt\nend\n'
LONGNAME="e$(printf 'x%.0s' $(seq 1 50)).txt"; echo 0.5 > "$T/$LONGNAME"
mk pename "file Zr90\ntarget Zr90\nprojectile n\nproj_e_file $LONGNAME\nend\n"
mk dupcmd 'file Zr90\ntarget Zr90\nprojectile n\nxs_only y\nxs_only y\nend\n'
mk notarget 'file Zr90\nprojectile n\nend\n'
mk seedcomment 'ran_seed 12345 # fixed seed\nfile Zr90\ntarget Zr90\nprojectile n\nend\n'
echo x > "$T/Zr90.out"
mkdir -p "$T/bin4/\$FXC" "$T/bin4/other"; cp "$T/bin/frescox" "$T/bin4/\$FXC/frescox"
printf '#!/bin/bash\necho substituted\nexit 9\n' > "$T/bin4/other/frescox"; chmod +x "$T/bin4/other/frescox"

# case:expected guard tag:flip|fire
CASES="
seedenv:seedenv:flip wrapper:wrapper:flip afterend:afterend:flip indent:indent:flip tab:tab:flip
long:long:flip glued:glued:flip dupseed:dupseed:flip seedval:seedval:flip nsamp:nsamp:flip
quiet:quiet:flip mode:mode:fire evgen:evgen:flip dunits:units:flip pecomment:pecomment:flip
unstaged:unstaged:flip nodeck:deck:fire binary:binary:fire datapath:datapath:flip fxname:fxname:flip
workdir:workdir:fire nonempty:nonempty:flip stagemissing:stagemissing:fire stagename:stagename:flip
reserved:reserved:flip stagedup:stagedup:flip
rc:rc:flip stderr:stderr:flip banner:banner:flip loop:loop:flip noloop:loop:flip account:account:flip
xsdup:xsfields:flip units:units:flip xsvalues:xsvalues:flip nanenergy:xsvalues:fire identity:identity:flip
econs:econs:flip seedrun:seedrun:flip fxexit:fxexit:flip fxfiles:fxfiles:flip
nolib:library:flip libenergy:library:flip nan:finite:flip overflow:finite:flip hdroverflow:finite:flip
stdoutnan:finite:flip lowernan:finite:flip overflowexp:finite:flip fxoverflow:finite:flip frescodat:finite:flip
extpath:unstaged:flip pename:pename:flip dupcmd:dupcmd:flip notarget:target:fire outname:reserved:flip
libunits:units:flip libvalues:libvalues:flip malformeddup:xsfields:flip wrongtarget:library:flip
missingerr:fxfiles:flip fxinvalid:fxfiles:flip"
POS="good noise mb charged seedcomment dollarpath fxnote"

runcase () {  # runcase <scriptdir> <case>; leaves the log in $LASTLOG
  local d="$1" c="$2" deck="$T/good.inp" bin="$T/bin/YAHFC.x" fx="$T/bin/frescox" data="$SD/"
  local w="$T/w-$c-$RANDOM" seed="" mode=good; local -a st=()
  [ -f "$T/$c.inp" ] && deck="$T/$c.inp"
  case "$c" in
    rc|stderr|banner|loop|noloop|account|xsdup|units|xsvalues|nanenergy|identity|econs|seedrun|fxexit|fxfiles|nolib|libenergy|nan|overflow|hdroverflow|stdoutnan|noise|lowernan|overflowexp|fxoverflow|frescodat|libunits|libvalues|malformeddup|wrongtarget|missingerr|fxnote|fxinvalid) mode="$c" ;;
    pename) st=("$T/$LONGNAME") ;; outname) st=("$T/Zr90.out") ;;
    dollarpath) fx="$T/bin4/\$FXC/frescox" ;;
    seedenv) seed=abc ;; nodeck) deck="$T/absent.inp" ;; binary) bin="$T/absent.x" ;;
    datapath) data="$LONGDATA/" ;; fxname) fx="$T/bin2/fresco" ;;
    workdir) : > "$w" ;; nonempty) mkdir -p "$w"; echo old > "$w/nZr90.tcoef" ;;
    stagemissing) st=("$T/absent.txt") ;; stagename) st=("$T/name with space.txt") ;;
    reserved) st=("$T/input.txt") ;; stagedup) st=("$T/dup1/a.txt" "$T/dup2/a.txt") ;;
    pecomment) st=("$T/elist.txt") ;;
  esac
  LASTLOG="$w.log"
  env FXC=other YAHFC_BIN="$bin" FRESCOX="$fx" YAHFC_DIR="$T/src" YAHFC_DATA="$data" STUB_MODE="$mode" \
    ${seed:+YAHFC_SEED=$seed} bash "$d/run_yahfc.sh" "$deck" "$w" ${st[@]+"${st[@]}"} > "$LASTLOG" 2>&1
}

echo "1-2  positive controls pass; every negative case fails with its own guard's tag"
for c in $POS; do
  runcase "$HERE" "$c"; rc=$?
  if [ $rc -eq 0 ] && grep -q '^run_yahfc: OK' "$LASTLOG"; then ok "$c passes"; else no "$c should pass"; tail -3 "$LASTLOG" | sed 's/^/        /'; fi
  if [ "$c" = mb ]; then grep -q '(units: mb)' "$LASTLOG" && ok "mb: reported in mb" || no "mb: units not reported as mb"; fi
  if [ "$c" = good ]; then
    grep -q '^seed injected: ran_seed 12345' "$(sed -n 's/^work directory: \([^ ]*\).*/\1/p' "$LASTLOG")/provenance.txt" \
      && ok "good: ran_seed 12345 injected and recorded" || no "good: seed not recorded"
  fi
done
for spec in $CASES; do
  IFS=: read -r c g kind <<< "$spec"
  runcase "$HERE" "$c"; rc=$?
  if [ $rc -ne 0 ] && grep -q "\[$g\]" "$LASTLOG"; then ok "$c fails on [$g]"
  else no "$c: rc=$rc, expected [$g], got: $(grep -E 'REFUSED|FAIL' "$LASTLOG" | head -1 | cut -c1-120)"; fi
done

echo "3    each disabled guard lets its own cases through"
GUARDS="$( { grep -oE 'G\("[a-z]+", ' "$HERE/yahfc_check.py" | sed -E 's/G\("([a-z]+)", /\1/'; grep -oE 'refuse [a-z]+ ' "$HERE/run_yahfc.sh" | awk '{print $2}'; } | grep -vxE 'name|tag' | sort -u)"
for g in $GUARDS; do
  d="$T/v-$g"; mkdir -p "$d"; cp "$HERE/run_yahfc.sh" "$HERE/yahfc_check.py" "$d/"
  if ! python3 - "$d" "$g" <<'EOF'
import sys
d, g = sys.argv[1], sys.argv[2]
n = 0
for f, pat, rep in [("yahfc_check.py", f'G("{g}", ', f'G("{g}", True or '),
                    ("run_yahfc.sh", f'refuse {g} ', f': {g} ')]:
    p = f"{d}/{f}"; s = open(p).read(); n += s.count(pat); open(p, "w").write(s.replace(pat, rep))
sys.exit(0 if n else 1)
EOF
  then no "guard $g: disable-edit did not apply"; continue; fi
  if cmp -s "$HERE/run_yahfc.sh" "$d/run_yahfc.sh" && cmp -s "$HERE/yahfc_check.py" "$d/yahfc_check.py"; then
    no "guard $g: copies unchanged"; continue; fi
  flipped=""; wrong=""; mine=0
  for spec in $CASES; do
    IFS=: read -r c cg kind <<< "$spec"
    [ "$cg" = "$g" ] || continue
    mine=1
    [ "$kind" = fire ] && continue
    runcase "$d" "$c"; rc=$?
    [ $rc -eq 0 ] && flipped="$flipped $c" || wrong="$wrong $c(still-fails)"
  done
  if [ "$mine" -eq 0 ]; then no "guard $g has no test case"
  elif [ -n "$wrong" ]; then no "guard $g: flipped [${flipped# }], wrong [${wrong# }]"
  elif [ -n "$flipped" ]; then ok "guard $g: disabling it lets through$flipped"
  else ok "guard $g: fire-only (proved in step 2)"; fi
done

if [ "${1:-}" = "--real" ]; then
  echo "4    verify_yahfc.sh expectations fire (real install)"
  # perturb a scratch copy of the skill, never the skill itself
  mkdir -p "$T/skill"; cp -R "$HERE" "$T/skill/scripts"; cp -R "$HERE/../examples" "$T/skill/examples"
  V="$T/skill/scripts/verify_yahfc.sh"
  if ! python3 - "$V" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
edits = [('"Total_cs.dat 1 6.4621054"', '"Total_cs.dat 1 6.4621183"'),              # +2.0e-6 rel
         ('want="g=233 n=582', 'want="g=234 n=582'),
         ('\n  GRID="0.46074054 ', '\n  GRID="0.46084054 '),                         # L2 grid E#1
         ('EXP=("1.137" "1.185" "" "1.072"', 'EXP=("1.137" "1.185" "" "1.000"')]       # E#4: 10.5%
for o, n in edits:
    if s.count(o) != 1: print("perturbation not applied:", o); sys.exit(1)
    s = s.replace(o, n)
open(p, "w").write(s)
EOF
  then no "could not perturb verify_yahfc.sh"
  else
    out="$(bash "$V" 2>&1)"; rc=$?
    nf="$(echo "$out" | grep -c '^  FAIL')"
    if [ $rc -ne 0 ] && [ "$nf" -eq 5 ] \
       && echo "$out" | grep -q 'FAIL  Total_cs.dat E#1' \
       && echo "$out" | grep -q 'FAIL  events per channel' \
       && echo "$out" | grep -q "FAIL  sigma_f seed 12345 E#1: no value (got 'energy=" \
       && echo "$out" | grep -q "FAIL  sigma_f seed 12345 E#1 vs EXFOR 10950.002: no value (got 'energy=" \
       && echo "$out" | grep -q 'FAIL  sigma_f seed 12345 E#4 vs EXFOR'; then
      ok "perturbed verify reports exactly the five implied FAILs (a moved energy reads as no value)"
    else
      no "perturbed verify: rc=$rc, $nf FAIL lines"; echo "$out" | grep '^  FAIL' | sed 's/^/        /'
    fi
  fi
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "selftest_yahfc: every listed guard fires for its own case (scope: see header)"; exit 0; fi
echo "selftest_yahfc: $FAILS problem(s)"; exit 1
