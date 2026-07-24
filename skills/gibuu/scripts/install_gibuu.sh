#!/bin/bash
# install_gibuu.sh
#
# Provision GiBUU and its input database, then print
#   GIBUU=<path to the GiBUU.x executable>
#   GIBUU_ROOT=<source tree root>
#   GIBUU_INPUT=<buuinput directory, needed by every job card>
#   GIBUU_LIBPATH=<extra library path, or empty>
# on the last four lines. run_gibuu.sh and verify_gibuu.sh parse those.
#
# GiBUU is the Giessen Boltzmann-Uehling-Uhlenbeck transport model of
# O. Buss et al., Phys. Rept. 512, 1-124 (2012),
# DOI 10.1016/j.physrep.2011.12.001 (CrossRef-verified). GPL-2.0, see the
# LICENSE file in the distribution.
#
# IDENTITY IS BY TARBALL CHECKSUM, NOT BY COMMIT. GiBUU is distributed as
# release tarballs from hepforge and anonymous svn access was switched off in
# 2018, so there is no commit hash to pin the way the SMASH skill does. What is
# pinned instead: the SHA-256 of both tarballs and the release string in
# version.txt. That is weaker provenance than a git pin and is stated as such
# rather than dressed up; it does establish that the bytes are the ones this
# skill was verified against.
#
# THE BUILD MUST START FROM A FRESH EXTRACTION. GiBUU generates a per-directory
# Makefile in every source directory by recursively copying Makefile.SUBlink.
# A build that dies partway leaves that distribution half-finished (measured:
# 49 of 97 directories), and a later `make` in the same tree then fails with
# "No rule to make target 'iterate'" for reasons that have nothing to do with
# the real problem. This script therefore always extracts into a clean
# directory and never tries to repair one.
set -euo pipefail

ROOT_DIR="${GIBUU_ROOT_DIR:-$HOME/.cache/fusion/gibuu}"
mkdir -p "$ROOT_DIR"
ROOT_CANON="$(cd "$ROOT_DIR" && pwd -P)"

RELEASE="${GIBUU_RELEASE:-2025}"
BASE_URL="${GIBUU_BASE_URL:-https://gibuu.hepforge.org/downloads}"
SRC_TGZ="$ROOT_DIR/release${RELEASE}.tar.gz"
INP_TGZ="$ROOT_DIR/buuinput${RELEASE}.tar.gz"
BUILD="$ROOT_DIR/build"
SRCROOT="$BUILD/release${RELEASE}"
BIN="$SRCROOT/testRun/GiBUU.x"
INPUT="$ROOT_DIR/buuinput${RELEASE}"
STAMP="$SRCROOT/.fusion_build_stamp"
JOBS="${GIBUU_JOBS:-$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4 )}"

# Pinned checksums for release 2025 (patch 5, April 24 2026), measured on both
# macOS/ARM and Linux/x86-64 downloads of the same URLs.
SRC_SHA_PINNED="bed77e069e657254a2e474d304722f568e57c3b4591559c5d132680c83fa3eed"
INP_SHA_PINNED="99a5fee2abc7648e69a0fa3a102b1c9e8450e92995c164c6d0ccaeeffd16d067"
SRC_SHA="${GIBUU_SRC_SHA:-$SRC_SHA_PINNED}"
INP_SHA="${GIBUU_INPUT_SHA:-$INP_SHA_PINNED}"
VERSION_EXPECTED="${GIBUU_VERSION_STRING:-Release 2025, patch 5 (April 24, 2026)}"

log () { echo "install_gibuu: $*" >&2; }
die () { log "$*"; exit 1; }

sha256_of () {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else echo nohash; fi
}

safe_rmrf () {
  local target="$1" parent canon
  [ -n "$target" ] || { log "refusing to delete an empty path"; return 1; }
  case "$target" in /*) : ;; *) log "refusing to delete relative path '$target'"; return 1 ;; esac
  [ -e "$target" ] || return 0
  parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || { log "cannot resolve '$target'"; return 1; }
  canon="$parent/$(basename "$target")"
  case "$canon" in "/"|"$HOME"|"/usr"|"/etc"|"/var"|"/tmp") log "refusing to delete '$canon'"; return 1 ;; esac
  [ "${#canon}" -ge 12 ] || { log "refusing to delete short path '$canon'"; return 1; }
  case "$canon/" in "$ROOT_CANON"/*) : ;; *) log "refusing to delete '$canon' outside $ROOT_CANON"; return 1 ;; esac
  rm -rf "$canon"
}

# A hepforge download that returned an HTML error page would otherwise only
# surface later as "tar: Unrecognized archive format", so check the magic bytes.
fetch () {   # fetch <url> <dest> <what> <expected sha or empty>
  local url="$1" dest="$2" what="$3" want="$4" got
  if [ -f "$dest" ]; then
    got="$(sha256_of "$dest")"
    if [ -z "$want" ] || [ "$got" = "$want" ]; then log "reusing $what"; return 0; fi
    log "$what on disk has SHA-256 $got, not the pinned $want; re-downloading"
    rm -f "$dest"
  fi
  log "downloading $what (this is 14 MB for the code, 53 MB for the input database)"
  curl -fL --retry 3 --max-time 3600 -o "$dest" "$url" 2>/dev/null || {
    log "download of $what failed: $url"; rm -f "$dest"; return 1; }
  local magic; magic="$(od -An -tx1 -N2 "$dest" | tr -d ' \n')"
  [ "$magic" = "1f8b" ] || {
    log "$what did not download as a gzip archive (first bytes: $magic, $(wc -c < "$dest") bytes)"
    head -c 120 "$dest" | tr -d '\0' >&2; echo >&2
    rm -f "$dest"; return 1; }
  got="$(sha256_of "$dest")"
  if [ -n "$want" ] && [ "$got" != "$want" ]; then
    log "$what has SHA-256 $got but the pin expects $want"
    log "upstream may have re-rolled the release; set GIBUU_SRC_SHA / GIBUU_INPUT_SHA to re-pin deliberately"
    rm -f "$dest"; return 1
  fi
}

# ------------------------------------------------------------------ toolchain
command -v make >/dev/null || die "GNU make not found"
FC="${FC:-gfortran}"
command -v "$FC" >/dev/null || die "no Fortran compiler found (looked for '$FC'; set FC)"
command -v perl >/dev/null || command -v makedepf90 >/dev/null \
  || die "GiBUU needs perl or makedepf90 to generate dependencies; neither was found"

# macOS needs GNU find. This is NOT optional and NOT a FUSION invention: GiBUU's
# own Makefile selects `gfind` on Darwin, and Makefile.SUBlink line 42 calls
#     $(FIND) -maxdepth 1 ! -name ".*" -type d
# with NO PATH ARGUMENT. GNU find defaults to "." there; BSD find exits with a
# usage error, and the resulting build failure appears much later and elsewhere,
# as a missing per-directory Makefile. Overriding FIND=find on the command line
# looks like it works (the other nine uses are POSIX) and then breaks exactly
# this one. Do not do it; install findutils.
if [ "$(uname -s)" = "Darwin" ] && ! command -v gfind >/dev/null 2>&1; then
  die "GiBUU on macOS requires GNU find as 'gfind' (its own Makefile asks for it). Install it with: brew install findutils"
fi

# ------------------------------------------------------------------- download
fetch "$BASE_URL?f=release${RELEASE}.tar.gz"  "$SRC_TGZ" "the GiBUU source"        "$SRC_SHA" || exit 1
fetch "$BASE_URL?f=buuinput${RELEASE}.tar.gz" "$INP_TGZ" "the GiBUU input database" "$INP_SHA" || exit 1

if [ ! -d "$INPUT" ]; then
  log "unpacking the input database"
  ( cd "$ROOT_DIR" && tar xzf "$INP_TGZ" ) || die "unpacking the input database failed"
fi
[ -d "$INPUT" ] || die "the input database is missing from $INPUT after unpacking"

# --------------------------------------------------------------- library path
# GiBUU links -lbz2 unconditionally. On a machine where libbz2 exists only
# inside a conda prefix (measured on the group's Linux box) the link fails with
# "cannot find -lbz2" after everything has already compiled, which reads as a
# GiBUU problem and is an environment one. gfortran honours LIBRARY_PATH, so it
# is fixable without touching the Makefile.
#
# But the hint is added ONLY WHEN THE PLAIN BUILD HAS ALREADY FAILED ON IT.
# Adding it unconditionally is worse than useless: on macOS libbz2 comes from
# the SDK and needs no hint, and injecting a conda lib directory into
# LIBRARY_PATH there broke an otherwise clean link with a wall of undefined
# arm64 symbols. Measured, not hypothesised. Detect the prefix, keep it in
# reserve, and only use it if the linker actually asks.
find_libpath () {
  local p
  [ -n "${GIBUU_LIBPATH:-}" ] && { echo "$GIBUU_LIBPATH"; return 0; }
  for p in "${CONDA_PREFIX:-/nonexistent}" "$HOME"/miniforge3 "$HOME"/miniconda3 \
           /opt/homebrew /usr/local /usr; do
    p="${p%/}"
    if [ -f "$p/lib/libbz2.so" ] || [ -f "$p/lib/libbz2.dylib" ] || [ -f "$p/lib/libbz2.a" ]; then
      echo "$p/lib"; return 0
    fi
  done
  return 1
}
LIBPATH=""            # stays empty unless the link demands it, see below
LIBPATH_RESERVE="$(find_libpath || true)"

# ----------------------------------------------------------------- build
build_identity () {
  echo "$SRC_SHA|$INP_SHA|$($FC --version 2>/dev/null | head -1)|$(uname -s)|$(uname -m)"
}

# A native executable, not a script wearing GiBUU.x's name. This does not make
# identity adversarial: with by-checksum provenance a compiled fake that prints
# the banner is inherently indistinguishable without rebuilding, and the header
# says so. What it does close is the cheap impostor, a shell stub, which the
# stamp's identity string (writable, copyable) would otherwise wave through on
# the fast path.
# -L follows the symlink: GiBUU.x is a link to objects/GiBUU.x, and GNU file does
# NOT follow it by default (macOS file does), so without -L this reported
# "symbolic link to ..." on Linux and wrongly rejected a real ELF build.
is_native_exe () { case "$(file -bL "$1" 2>/dev/null)" in Mach-O*|ELF*) return 0 ;; *) return 1 ;; esac; }

fast_path_ok () {
  [ -x "$BIN" ] || return 1
  [ -f "$STAMP" ] || return 1
  is_native_exe "$BIN" || { log "'$BIN' is not a native executable, rebuilding"; return 1; }
  [ "$(head -1 "$STAMP")" = "$(build_identity)" ] || { log "build identity changed, rebuilding"; return 1; }
  return 0
}

if fast_path_ok; then
  log "reusing the build at $SRCROOT"
  # Line 2 records the library path the build actually needed. Without reading
  # it back, a reused Linux build would run with an empty LD_LIBRARY_PATH and
  # fail to load libbz2 at RUNTIME, long after a green install.
  LIBPATH="$(sed -n 2p "$STAMP" 2>/dev/null || true)"
else
  # Always from scratch: see the header note on the half-generated Makefile tree.
  log "extracting into a clean build directory (GiBUU cannot recover a half-built tree)"
  safe_rmrf "$BUILD" || die "could not clear the build directory"
  mkdir -p "$BUILD"
  ( cd "$BUILD" && tar xzf "$SRC_TGZ" ) || die "unpacking the source failed"
  [ -d "$SRCROOT" ] || die "the source tree is missing from $SRCROOT after unpacking"

  local_version="$(cat "$SRCROOT/version.txt" 2>/dev/null || echo none)"
  [ "$local_version" = "$VERSION_EXPECTED" ] || {
    log "version.txt reads '$local_version', expected '$VERSION_EXPECTED'"
    log "set GIBUU_VERSION_STRING to re-pin deliberately"
    exit 1; }

  do_build () {   # do_build <extra library path or empty>
    ( cd "$SRCROOT" && LIBRARY_PATH="${1:+$1:}${LIBRARY_PATH:-}" \
        LD_LIBRARY_PATH="${1:+$1:}${LD_LIBRARY_PATH:-}" \
        make -j"$JOBS" ) > "$ROOT_DIR/build.log" 2>&1
  }
  log "building with -j$JOBS (several minutes, once)"
  if ! do_build ""; then
    # Retry ONLY for the one failure a library path can fix, and only once.
    if grep -qE "cannot find -lbz2|library not found for -lbz2|-lbz2" "$ROOT_DIR/build.log" \
       && [ -n "$LIBPATH_RESERVE" ]; then
      log "the link could not find libbz2; retrying once with $LIBPATH_RESERVE on the library path"
      if do_build "$LIBPATH_RESERVE"; then
        LIBPATH="$LIBPATH_RESERVE"
      else
        log "build failed again, last 20 lines of $ROOT_DIR/build.log:"; tail -20 "$ROOT_DIR/build.log" >&2
        exit 1
      fi
    else
      log "build failed, last 20 lines of $ROOT_DIR/build.log:"; tail -20 "$ROOT_DIR/build.log" >&2
      log "if this says 'cannot find -lbz2', install libbz2 or set GIBUU_LIBPATH to a prefix that has it"
      exit 1
    fi
  fi
  [ -x "$BIN" ] || die "the build reported success but $BIN is missing"
  is_native_exe "$BIN" || die "the build produced '$BIN' but it is not a native executable"
  { build_identity; printf '%s\n' "$LIBPATH"; } > "$STAMP"
fi

# ------------------------------------------------------------------- probe
# Content AND exit status. A crash after printing a plausible banner would
# otherwise pass. The minimal job card does no physics; it just starts the code
# and prints the particle database, which is enough to prove the binary runs
# and can read the input database.
probe () {
  local work out
  work="$(mktemp -d)"
  sed "s|'~/GiBUU/buuinput'|'$INPUT'|" "$SRCROOT/testRun/jobCards/000_minimal.job" > "$work/probe.job"
  grep -q "$INPUT" "$work/probe.job" || { log "could not point the probe job card at $INPUT"; rm -rf "$work"; return 1; }
  if ! ( cd "$work" && LD_LIBRARY_PATH="${LIBPATH:+$LIBPATH:}${LD_LIBRARY_PATH:-}" \
         "$BIN" < probe.job > out.log 2> err.log ); then
    log "the probe run exited nonzero; last lines:"; tail -5 "$work/out.log" >&2; rm -rf "$work"; return 1
  fi
  out="$(cat "$work/out.log")"
  case "$out" in
    *"BUU simulation: finished"*) : ;;
    *) log "the probe run did not report a finished simulation"; tail -5 "$work/out.log" >&2; rm -rf "$work"; return 1 ;;
  esac
  rm -rf "$work"
}
probe || die "the built executable failed its probe"
log "probe: GiBUU.x runs and reads the input database"

echo "GIBUU=$BIN"
echo "GIBUU_ROOT=$SRCROOT"
echo "GIBUU_INPUT=$INPUT"
echo "GIBUU_LIBPATH=${LIBPATH:-}"
