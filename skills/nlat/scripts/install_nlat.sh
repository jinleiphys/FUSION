#!/bin/bash
# install_nlat.sh
#
# Provision the NLAT binary: fetch the CPC Program Library distribution from
# Mendeley Data, unpack, build with gfortran, verify the binary runs.
# Prints "NLAT=<path>" on success; run_nlat.sh parses that line.
#
# Where the source lives, and why it is not where the paper says:
# The paper's program summary points at http://cpc.cs.qub.ac.uk/summaries/
# AFAY_v1_0.html, which now returns HTTP 502. Elsevier retired the Queen's
# University Belfast CPC Program Library and migrated all 3089 programs
# published 1969 to 2016 to Mendeley Data. AFAY_v1_0 lives at
# https://data.mendeley.com/datasets/xnwjvk86bs/1 (DOI 10.17632/xnwjvk86bs.1),
# freely downloadable with no login. The dead summary URL is a broken pointer to
# a live artifact, not a lost code.
set -euo pipefail

ROOT="${NLAT_ROOT:-$HOME/.cache/fusion/nlat}"
FC="${NLAT_FC:-gfortran}"
URL="${NLAT_URL:-https://data.mendeley.com/public-files/datasets/xnwjvk86bs/files/f4229b51-5533-41a0-bbc0-9f576aac04d1/file_downloaded}"
DATASET_PAGE="https://data.mendeley.com/datasets/xnwjvk86bs/1"

# Pinned from the fetch of 2026-07-21. The byte count also matches the figure
# printed in the paper's own program summary (15253066), which is an independent
# confirmation that this is the genuine AFAY_v1_0 distribution rather than a
# repackaging.
KNOWN_SHA="f2b4441d73a00b085c382c9d0839ca10bc67798be5ea5b9f1c6aa25fced7c0d1"
KNOWN_BYTES=15253066

SRCDIR="$ROOT/NLAT"
BIN="$SRCDIR/NLAT"

if [ -x "$BIN" ] && [ -d "$SRCDIR/SOURCE" ] && [ -z "${NLAT_FORCE:-}" ]; then
  echo "NLAT=$BIN"
  exit 0
fi

command -v "$FC" >/dev/null || { echo "install_nlat: no $FC on PATH" >&2; exit 1; }
command -v make >/dev/null || { echo "install_nlat: make required" >&2; exit 1; }
command -v curl >/dev/null || { echo "install_nlat: curl required" >&2; exit 1; }

mkdir -p "$ROOT"
TARBALL="$ROOT/afay_v1_0.tar.gz"

if [ ! -s "$TARBALL" ]; then
  echo "install_nlat: fetching AFAY_v1_0 from Mendeley Data" >&2
  curl -sSL --fail -o "$TARBALL" "$URL" || {
    echo "install_nlat: download failed. The dataset page is:" >&2
    echo "  $DATASET_PAGE" >&2
    exit 1
  }
fi

case "$(file -b "$TARBALL")" in
  gzip*) ;;
  *) echo "install_nlat: downloaded file is not gzip data:" >&2
     file -b "$TARBALL" >&2
     echo "  fetch it by hand from $DATASET_PAGE" >&2
     rm -f "$TARBALL"
     exit 1 ;;
esac

got_bytes=$(wc -c < "$TARBALL" | tr -d ' ')
got_sha=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
# Enforce the pin, do not merely mention it. The previous version printed a
# warning and carried straight on to build and benchmark against an unknown
# archive, which makes the pin decorative. It also never compared the byte count
# it claimed to check.
if [ "$got_sha" != "$KNOWN_SHA" ] || [ "$got_bytes" != "$KNOWN_BYTES" ]; then
  echo "install_nlat: archive does not match the pinned distribution." >&2
  echo "  expected sha256 $KNOWN_SHA ($KNOWN_BYTES bytes)" >&2
  echo "  got      sha256 $got_sha ($got_bytes bytes)" >&2
  echo "  The benchmarks in references/verification.md were established against" >&2
  echo "  the pinned archive, so they no longer apply. Set NLAT_ALLOW_UNPINNED=1" >&2
  echo "  to proceed anyway, then re-run verify_nlat.sh and re-pin." >&2
  if [ -z "${NLAT_ALLOW_UNPINNED:-}" ]; then
    exit 1
  fi
  echo "  NLAT_ALLOW_UNPINNED set, continuing against an unpinned archive." >&2
fi

# Re-extract when the tree is missing or incomplete, never on directory
# existence alone: a half-extracted tree would otherwise be permanent.
if [ ! -d "$SRCDIR/SOURCE" ] || [ ! -f "$SRCDIR/makefile_gfortran" ]; then
  tar -xzf "$TARBALL" -C "$ROOT" || { echo "install_nlat: extraction failed" >&2; exit 1; }
fi
[ -d "$SRCDIR/SOURCE" ] || { echo "install_nlat: archive did not unpack to $SRCDIR" >&2; exit 1; }

# The sample directories carry the distributed reference output. They are what
# verify_nlat.sh compares against, so their absence is a broken install.
for d in LOCAL_SAMPLE NONLOCAL_SAMPLE; do
  [ -d "$SRCDIR/$d" ] || { echo "install_nlat: missing $d/ in $SRCDIR" >&2; exit 1; }
done

echo "install_nlat: building with $FC" >&2
# Upstream's own instruction: copy the compiler-specific makefile into SOURCE/
# and rename it. The gfortran makefile already carries -std=legacy, which the
# code needs (it mixes .f90, fixed-form .f and .for sources).
cp -f "$SRCDIR/makefile_gfortran" "$SRCDIR/SOURCE/makefile"
( cd "$SRCDIR/SOURCE" && make FC="$FC" F90C="$FC" install clean ) > "$ROOT/build.log" 2>&1 || {
  echo "install_nlat: build failed, see $ROOT/build.log" >&2
  tail -20 "$ROOT/build.log" >&2
  exit 1
}
# The makefile's install target does `mv NLAT ../`, so the binary lands beside
# SOURCE/. Its `cp -fp NLAT $(HOME)/bin` line is commented out upstream, so
# nothing is written outside the install root.
[ -x "$BIN" ] || { echo "install_nlat: no binary at $BIN after build" >&2; exit 1; }

# Prove the binary runs. Fed empty stdin it reaches its first read and dies with
# a Fortran end-of-file diagnostic; that proves it loaded and started executing.
probe_err="$ROOT/probe.err"
set +e
"$BIN" </dev/null >/dev/null 2>"$probe_err" &
probe_pid=$!
( sleep 20; kill -9 "$probe_pid" 2>/dev/null ) &
watchdog=$!
wait "$probe_pid" 2>/dev/null
probe_rc=$?
kill "$watchdog" 2>/dev/null
wait "$watchdog" 2>/dev/null || true
set -e
if ! grep -qi "end of file\|Fortran runtime error" "$probe_err" 2>/dev/null; then
  echo "install_nlat: the built binary did not produce the expected end-of-file" >&2
  echo "  diagnostic on empty input (exit $probe_rc). The build is suspect." >&2
  head -5 "$probe_err" >&2
  exit 1
fi
rm -f "$probe_err"

echo "NLAT=$BIN"
