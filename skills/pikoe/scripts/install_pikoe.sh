#!/bin/bash
# install_pikoe.sh
#
# Provision the pikoe binary: fetch the upstream archive from the author's RCNP
# page, unpack, build with gfortran, and verify the binary actually runs.
# Prints "PIKOE=<path>" on success; that line is what run_pikoe.sh parses.
#
# Two upstream facts this script encodes:
#
#   1. The plain archive URLs on the RCNP page (.../pikoe1.1.zip) return 403/404.
#      Only the PukiWiki attach-plugin URL serves the file. Do not "simplify"
#      the URL below.
#   2. The archive unpacks to pikoe1.1/ and the source file is pikoe1.1.f90,
#      even though the shipped readme.txt calls it pikoe1.f90. The build globs
#      for the real name rather than hardcoding either.
set -euo pipefail

ROOT="${PIKOE_ROOT:-$HOME/.cache/fusion/pikoe}"
FC="${PIKOE_FC:-gfortran}"
FFLAGS="${PIKOE_FFLAGS:--O2}"
URL="${PIKOE_URL:-https://www.rcnp.osaka-u.ac.jp/~kazuyuki/pikoe/index.php?plugin=attach&refer=files&openfile=pikoe1.1.zip}"

# sha256 of pikoe1.1.zip as fetched 2026-07-21. Upstream may reissue the
# archive under the same name, so a mismatch is a warning, not a failure: it
# means the benchmark values in references/verification.md were established
# against a different build and must be re-checked.
KNOWN_SHA="747119fbaeeb04fe6378346f2610a8cd64c67986b97a87f2ded3fcadd53c38fa"

SRCDIR="$ROOT/pikoe1.1"
BIN="$SRCDIR/pikoe"

# A cached binary counts only if the data tables it needs are there too. The
# executable bit alone is not evidence of a usable install.
if [ -x "$BIN" ] && [ -d "$SRCDIR/elem" ] && [ -d "$SRCDIR/pot" ] && [ -z "${PIKOE_FORCE:-}" ]; then
  echo "PIKOE=$BIN"
  exit 0
fi

command -v "$FC" >/dev/null || { echo "install_pikoe: no $FC on PATH" >&2; exit 1; }
command -v curl >/dev/null || { echo "install_pikoe: curl required" >&2; exit 1; }
command -v unzip >/dev/null || { echo "install_pikoe: unzip required" >&2; exit 1; }

mkdir -p "$ROOT"
ZIP="$ROOT/pikoe1.1.zip"

if [ ! -s "$ZIP" ]; then
  echo "install_pikoe: fetching source from RCNP" >&2
  curl -sSL --fail -o "$ZIP" "$URL" || { echo "install_pikoe: download failed" >&2; exit 1; }
fi

# An HTML error page is also a successful HTTP 200, so check the file type.
case "$(file -b "$ZIP")" in
  Zip*) ;;
  *) echo "install_pikoe: downloaded file is not a zip archive:" >&2
     file -b "$ZIP" >&2
     rm -f "$ZIP"
     exit 1 ;;
esac

got_sha="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
if [ "$got_sha" != "$KNOWN_SHA" ]; then
  echo "install_pikoe: WARNING archive sha256 differs from the pinned one." >&2
  echo "  expected $KNOWN_SHA" >&2
  echo "  got      $got_sha" >&2
  echo "  The benchmark numbers in references/verification.md were established" >&2
  echo "  against the pinned archive. Re-run verify_pikoe.sh before trusting them." >&2
fi

# Re-extract when the tree is missing OR incomplete. Testing only for the
# directory made a half-extracted tree permanently unrecoverable: every later
# run skipped the unzip and then failed on the missing data tables.
if [ ! -d "$SRCDIR/elem" ] || [ ! -d "$SRCDIR/pot" ] || [ -z "$(ls "$SRCDIR"/pikoe*.f90 2>/dev/null)" ]; then
  unzip -q -o -d "$ROOT" "$ZIP" || { echo "install_pikoe: unzip failed" >&2; exit 1; }
fi
[ -d "$SRCDIR" ] || { echo "install_pikoe: archive did not unpack to $SRCDIR" >&2; exit 1; }

# The external data tables the sample decks reference by relative path.
for d in elem pot; do
  [ -d "$SRCDIR/$d" ] || { echo "install_pikoe: missing $d/ in $SRCDIR after extraction" >&2; exit 1; }
done

SRCF="$(ls "$SRCDIR"/pikoe*.f90 2>/dev/null | head -1 || true)"
[ -n "$SRCF" ] || { echo "install_pikoe: no pikoe*.f90 in $SRCDIR" >&2; exit 1; }

echo "install_pikoe: building $(basename "$SRCF") with $FC $FFLAGS" >&2
# The source uses deleted Fortran 2018 features (arithmetic IF, non-CONTINUE DO
# termination). gfortran warns and compiles; that is expected, not a problem.
#
# -J is not optional. gfortran writes .mod files for every module into the
# CURRENT WORKING DIRECTORY, so building from wherever the caller happens to
# stand litters that directory with angmom.mod, array.mod, consts.mod and the
# rest. Direct them into the install tree instead.
#
# Clearing them first is also not optional, and is a separate bug from the one
# above. .mod files are gfortran-version-specific, so a rebuild after ANY
# compiler upgrade reads the stale ones and dies with
#   Fatal Error: Cannot read module file 'dims.mod' ...
#   because it was created by a different version of GNU Fortran
# which names neither the cause nor the fix. Found by building the same source
# with gfortran 15.2 (macOS) and 13.3 (Linux) for the cross-platform check.
rm -f "$SRCDIR"/*.mod
"$FC" $FFLAGS -J "$SRCDIR" -o "$BIN" "$SRCF" 2> "$ROOT/build.log" || {
  echo "install_pikoe: build failed, see $ROOT/build.log" >&2
  tail -20 "$ROOT/build.log" >&2
  exit 1
}
[ -x "$BIN" ] || { echo "install_pikoe: no binary produced" >&2; exit 1; }

# Prove the binary runs, rather than writing a check that asserts nothing.
# Fed an empty stdin, pikoe reaches its first read of the control file and dies
# with a Fortran end-of-file error at a known line. Seeing that diagnostic
# proves the executable loaded and started executing its own code; seeing
# anything else (a dynamic-link failure, a signal, silence) does not.
probe_err="$ROOT/probe.err"
set +e
"$BIN" </dev/null >/dev/null 2>"$probe_err" &
probe_pid=$!
( sleep 20; kill -9 "$probe_pid" 2>/dev/null ) &
watchdog=$!
wait "$probe_pid" 2>/dev/null
probe_rc=$?
kill "$watchdog" 2>/dev/null
set -e

if ! grep -q "Fortran runtime error: End of file" "$probe_err" 2>/dev/null; then
  echo "install_pikoe: the built binary did not produce the expected end-of-file" >&2
  echo "  diagnostic on empty input (exit $probe_rc). The build is suspect." >&2
  head -5 "$probe_err" >&2
  exit 1
fi
rm -f "$probe_err"

echo "PIKOE=$BIN"
