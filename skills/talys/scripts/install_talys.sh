#!/bin/bash
# install_talys.sh [--force]
#
# Fetch and build TALYS.
#
# Source:  https://github.com/arjankoning1/talys  (MIT License)
#          A. Koning, S. Hilaire, S. Goriely, "TALYS: modeling of nuclear
#          reactions", Eur. Phys. J. A 59, 131 (2023).
#          Frozen release also at https://nds.iaea.org/talys/talys.tar
#
# Two non-obvious build requirements are handled here; both fail confusingly
# if you build TALYS by hand:
#
#   1. LC_ALL=C is MANDATORY. source/Makefile collects sources with the glob
#      [A-z]*.f90 evaluated by /bin/sh. That is a collation range, not an
#      ASCII range: in a UTF-8 locale 'a' sorts before 'A', so every file
#      whose name starts with a lowercase 'a' is silently dropped (abundance,
#      adjust, adjustf, aldmatch, angdis, angdisrecoil, angleout, arraysize,
#      astro*, plus afold.f). The build then dies at link time with a wall of
#      undefined symbols. LC_ALL=C makes the range ASCII again: 349 -> 362.
#
#   2. The install path must be SHORT. TALYS stores the code directory in a
#      character(len=132) variable and appends relative paths up to 69 chars
#      (structure/fission/ff/langevin4d/...). A long root silently truncates
#      the filename, and you get "TALYS-error: Error in <truncated>, IOSTAT=2"
#      at run time. This script refuses to install above the safe budget.
#
# Disk: about 11 GB (structure database 8.6 GB, samples 432 MB).
#
# Config (env overrides):
#   TALYS_ROOT   install dir (default: ~/.cache/fusion/talys). MUST be short.
#   TALYS_FC     Fortran compiler (default: gfortran)
#   TALYS_FFLAGS compiler flags   (default: -O2 -w)
#
# Exit 0 = usable binary in place. Prints: TALYS=/path/to/bin/talys
set -euo pipefail

FORCE=0
for a in "$@"; do case "$a" in --force) FORCE=1 ;; *) echo "unknown arg: $a" >&2; exit 2 ;; esac; done

ROOT="${TALYS_ROOT:-$HOME/.cache/fusion/talys}"
FC="${TALYS_FC:-gfortran}"
FFLAGS="${TALYS_FFLAGS:--O2 -w}"
REPO="https://github.com/arjankoning1/talys.git"

# ------------------------------------------------------- path length guard
# codedir is ROOT + "/talys/" and must leave room for a 69-char relative path
# inside a 132-char buffer.
CODEDIR="$ROOT/talys/"
MAXLEN=63
if [ "${#CODEDIR}" -gt "$MAXLEN" ]; then
  echo "ERROR: TALYS install path is too long." >&2
  echo "  codedir would be: $CODEDIR" >&2
  echo "  length ${#CODEDIR}, maximum $MAXLEN." >&2
  echo "TALYS keeps paths in a character(len=132) buffer and appends relative" >&2
  echo "paths up to 69 characters, so a longer root truncates filenames and" >&2
  echo "fails at run time with 'IOSTAT = 2'. Set TALYS_ROOT to something short," >&2
  echo "for example /tmp/talys or ~/talys." >&2
  exit 5
fi

BIN="$ROOT/talys/bin/talys"

# The structure database is 8.6 GB of the 11 GB install and TALYS cannot run
# without it, so the binary alone is NOT a complete install. Checking only the
# binary here would report success for a tree whose database was never cloned,
# was deleted to reclaim disk, or arrived truncated; TALYS then falls back to
# Duflo-Zuker masses and, for a partially missing database, still prints
# "successful calculation" while the numbers are wrong. One predicate, used by
# both the fast path and the post-clone check below, so the two cannot drift.
#
# Checking that a couple of directories exist does NOT detect that case, which
# is the one worth detecting: a complete database is 16 top-level directories
# and 47,537 files, and deleting a few subdirectories to reclaim disk leaves
# the top-level ones standing. The expected file count is read from the clone's
# own git index rather than hardcoded, so it follows the release instead of
# going stale, and the whole check costs about 0.06 s (index read plus one
# find), cheap enough to run on every invocation.
have_structure () {
  local d="$ROOT/talys/structure" want have
  [ -d "$d" ] || return 1
  want="$(git -C "$ROOT/talys" ls-files -- structure 2>/dev/null | wc -l | tr -d ' ')"
  if [ -z "$want" ] || [ "$want" -eq 0 ] 2>/dev/null; then
    # Not a git clone (for example the frozen nds.iaea.org tarball), so the
    # index cannot supply an expected count. Fall back to presence only, and
    # say so rather than implying the database was verified complete.
    echo "install_talys: no git index for the structure database; checking presence only" >&2
    [ -d "$d/optical" ] && [ -d "$d/masses" ]
    return
  fi
  have="$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$have" -lt "$want" ]; then
    echo "install_talys: structure database is INCOMPLETE: $have files present, $want expected." >&2
    echo "  TALYS would still run and print a successful calculation, using" >&2
    echo "  Duflo-Zuker fallback masses, and the numbers would be wrong." >&2
    echo "  Restore it with: git -C '$ROOT/talys' checkout -- structure" >&2
    return 1
  fi
  return 0
}

if [ "$FORCE" = 0 ] && [ -x "$BIN" ] && have_structure; then
  echo "talys already built: $BIN" >&2
  echo "TALYS=$BIN"; exit 0
fi
if [ "$FORCE" = 0 ] && [ -x "$BIN" ]; then
  echo "talys binary is present but the structure database is not; re-checking the install" >&2
fi

for tool in git make "$FC"; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 3; }
done

# ------------------------------------------------------------ fetch
if [ ! -d "$ROOT/talys/.git" ]; then
  mkdir -p "$ROOT"
  echo "cloning TALYS into $ROOT/talys (about 11 GB, this takes a while)" >&2
  git clone --depth 1 "$REPO" "$ROOT/talys" >&2
fi

# ------------------------------------------------------------ sanity check
# If the structure database is missing the run will fail later in a way that
# looks like a physics problem, so check now.
if ! have_structure; then
  echo "ERROR: the TALYS structure database is missing under $ROOT/talys/structure." >&2
  echo "Without it TALYS falls back to Duflo-Zuker masses and then aborts." >&2
  exit 4
fi

# ------------------------------------------------------------ build
cd "$ROOT/talys/source"
[ "$FORCE" = 1 ] && { rm -f ./*.o ./*.mod "$BIN"; } || true

# Verify the locale fix is actually needed/working before trusting the build.
n_default=$(/bin/sh -c 'echo [A-z]*.f90' | tr ' ' '\n' | grep -c 'f90$' || true)
n_c=$(LC_ALL=C /bin/sh -c 'echo [A-z]*.f90' | tr ' ' '\n' | grep -c 'f90$' || true)
n_all=$(ls ./*.f90 | wc -l | tr -d ' ')
if [ "$n_c" != "$n_all" ]; then
  echo "ERROR: even under LC_ALL=C the Makefile glob sees $n_c of $n_all sources." >&2
  echo "Upstream may have changed source naming; do not trust this build." >&2
  exit 6
fi
[ "$n_default" != "$n_all" ] && \
  echo "locale glob would drop $((n_all - n_default)) source files; building under LC_ALL=C" >&2

echo "building TALYS (FC=$FC FFLAGS=$FFLAGS)" >&2
LC_ALL=C make FC="$FC" FFLAGS="$FFLAGS" >&2

[ -x "$BIN" ] || { echo "build failed: $BIN not produced" >&2; exit 7; }
echo "built $BIN" >&2
echo "TALYS=$BIN"
