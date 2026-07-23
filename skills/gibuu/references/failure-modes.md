# GiBUU failure modes

Ordered by how much time each costs before you work out what happened. The
first two are build problems whose error message points away from the cause.

## 1. On macOS the build dies in `clean`, and the real requirement is GNU find

The first failure is

```
/bin/bash: gfind: command not found
make[1]: *** [cleanEXE] Error 127
```

GiBUU's own `Makefile` selects `gfind` on Darwin. That is not a quirk to work
around: `Makefile.SUBlink` line 42 calls

```make
SUBDIR := $(sort $(notdir $(shell $(FIND) -maxdepth 1 ! -name ".*" -type d)))
```

with **no path argument**. GNU find defaults to `.` there; BSD find exits with a
usage error. Fix with `brew install findutils`.

**Do not "fix" it with `make FIND=find`.** Nine of the ten `$(FIND)` uses are
POSIX and only appear in clean targets, so the override looks like it works and
gets much further. It then breaks the one pathless call above, the per-directory
Makefile distribution silently stops partway, and the build fails later with a
completely unrelated-looking message (see the next entry). Surveying three of
the four makefiles and generalising from them is exactly how this trap is
sprung.

## 2. `No rule to make target 'iterate'` means the tree is half-built, not broken

GiBUU does **not** ship a Makefile in each source directory: the tarball
contains one, and the build generates the other ninety-odd by recursively
copying `Makefile.SUBlink`. A build that dies partway leaves that distribution
half-finished (measured: 49 of 97 directories), and every later `make` in that
tree fails with

```
make[4]: *** No rule to make target `iterate'.  Stop.
```

which says nothing about the actual cause. **Do not debug a half-built tree.**
Extract the tarball fresh and build once. `install_gibuu.sh` always does this
and never tries to repair an existing tree.

## 3. Linux: `cannot find -lbz2` after everything has compiled

GiBUU links `-lbz2` unconditionally. On a machine where libbz2 exists only
inside a conda prefix, every source file compiles and the final link fails,
which reads as a GiBUU problem and is an environment one. gfortran honours
`LIBRARY_PATH`, so no Makefile change is needed.

**Add the hint only when the link has already failed on it.** Adding it
unconditionally is actively harmful: on macOS libbz2 comes from the SDK and
needs no hint, and injecting a conda lib directory into `LIBRARY_PATH` there
turned a clean link into a wall of undefined arm64 symbols. Measured, not
hypothesised. `install_gibuu.sh` builds plain first and retries once with a
detected prefix only if the log mentions `-lbz2`.

The path that worked must also be remembered: a reused build still needs it in
`LD_LIBRARY_PATH` at RUNTIME, or the install looks green and the first real run
fails to load libbz2.

## 4. `Seed = 0` does not mean "use zero", it means "use the clock"

`code/numerics/random.f90`: if `Seed` is zero, GiBUU calls `SYSTEM_CLOCK()` and
prints `Resetting Seed via system clock`. Measured: two runs of the same card
with `Seed = 0` used 735342345 and 1426869522 and produced different physics
output. A card with no `initRandom` block at all behaves the same way.

With an explicit non-zero seed the output is bit-identical, and not only on one
machine: it matched across macOS/ARM and Linux/x86-64. `run_gibuu.sh` refuses a
zero or absent seed unless `--allow-random-seed` is given.

## 5. A misspelled namelist is silently ignored

Fortran namelist input is not validated: a block GiBUU does not recognise is
skipped, and the run proceeds with defaults. So a job card that *looks* like it
sets something can produce entirely default physics with a zero exit status.
Never verify a setting by reading the job card; verify it from the run log,
which echoes what GiBUU actually used (`Seed:` is the easy one).

## 6. Every shipped job card points at the authors' own input directory

All 84 cards carry `path_To_Input = '~/GiBUU/buuinput'`. Unless rewritten, GiBUU
fails while reading its database rather than saying the path is wrong.
`run_gibuu.sh` rewrites it into the copy it runs, and refuses a card that has no
`path_To_Input` entry at all rather than running one that cannot work.

## 7. `absorption_xSection` is negative, and that is not a bug

Measured: -8153 mb at one run, -8530 mb at five. From
`code/analysis/LoPionAnalysis.f90`, absorption is defined as the total flux
minus the weight of ALL escaping pions, so it is meaningful only in combination
with the quasi-elastic column. **Do not quote it as a cross section.** The same
arithmetic is why the two total columns agree by construction: see
`verification.md`.

## 8. The shipped `List` modus and other cards need their own working directory

Some cards resolve paths relative to a directory other than their own. If a card
fails on a missing input file, check what working directory it assumes before
concluding the installation is broken.

## 9. Licensing

GPL-2.0. The `LICENSE` file in the distribution is the GNU GPL v2 text. The
README carries no conflicting statement.
