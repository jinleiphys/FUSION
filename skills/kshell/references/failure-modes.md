# KSHELL failure modes

Hit while building and verifying the skill on macOS/ARM64 gfortran 15.2 against
the Linux/x86_64 gfortran 13.3 reference.

## License and fork choice

- **KSHELL is GPL-3.0, declared in the README, not in a LICENSE file.** There is
  no standalone LICENSE file and GitHub reports `license: None`, but the upstream
  README's CPC-style header states `Licensing provisions: GPLv3`, so the code is
  GPL-3.0 by the authors' declaration. GitHub's detector and a LICENSE-file check
  both miss that, which is why an initial read called it unlicensed; grep the
  README and the paper for a license before concluding otherwise. The skill still
  only clones from upstream and does not redistribute the source.

- **Use the maintained GaffaSnobb fork, not the jorgenem mirror.** jorgenem's
  README says it is unmaintained and its `gen_partition.py` / `kshell_ui.py` are
  Python 2 (`print "..."` statements) that will not run on a modern Mac. GaffaSnobb
  ported the tooling to Python 3 and pre-set the build flags.

## Build (gfortran 10+)

- **Rank/type mismatch is a hard error on gfortran 10+.** `lib_matrix.F90` passes
  a scalar where an array is expected (and similar), which older gfortran demoted
  to a warning. gfortran 10+ makes it an error and the build stops at
  `lib_matrix.o`. Fix: `-fallow-argument-mismatch` in FFLAGS (the GaffaSnobb
  Makefile already carries it; the installer passes it explicitly to be safe).

- **The Makefile has several uncommented FC/FFLAGS/LIBS blocks; the last wins.**
  Rather than depend on that, the installer overrides FFLAGS and LIBS on the make
  command line. On macOS LIBS is `-framework Accelerate -lm` (Accelerate provides
  BLAS and LAPACK and is always present); on Linux it is `-llapack -lblas -lm`.
  The default `-llapack -lblas` does NOT find Homebrew's LAPACK on macOS without a
  `-L`, which is why Accelerate is used there.

- **The binary is `kshell.exe`** in the GaffaSnobb fork (the jorgenem mirror named
  it `kshell`). `make` also builds `transit` (transitions) and `count_dim`.

## Run

- **`gen_partition.py` is mandatory and needs Python 3.10+ (gen_partition.py and kshell_ui.py use 3.10+ syntax such as `int | None`).** The `.ptn` shipped in
  the test directories can be a zero-byte placeholder; the real partition is
  generated. The generator prompts on stdin for a truncation scheme; feed `0` for
  the full (untruncated) space. An empty `.ptn` is a silent failure, so the
  wrappers assert it is non-empty.

- **Valence numbers are relative to the interaction's core, not Z and N.** For
  ^20Ne with USDA the core is ^16O, so it is 2 valence protons and 2 valence
  neutrons, not 10 and 10. Passing the full Z/N generates a partition outside the
  model space and the run fails or is meaningless.

- **`mtot` is 2*M.** Use 0 for even-A (M=0) and 1 for odd-A (M=1/2). It is not the
  spin J; J comes out of the diagonalization (`<JJ>` in the summary).

- **Success is the eigenvalue summary, not the exit status.** A run can exit 0
  with a truncated or missing summary (e.g. non-convergence at a too-small
  `max_lanc_vec`). The wrappers require a finite negative ground state, ascending
  energies, and the requested number of states, parsed from the summary.

## Verification

- **Not framed as bit-identical, but it happens to match to the printed
  precision.** The Lanczos eigenvalues converge to the same five printed decimals
  on gfortran 13.3 and 15.2, so the pin is gated at 1e-4 (a regression gate); a
  different toolchain could in principle perturb the last digit, in which case
  fall back to the J-sequence physics (0+, 2+, 4+ band) as the anchor.

- **The eigenvalue depends on the interaction and model space, not on `hw_type`
  or the charges.** If a "wrong energy" appears, check `fn_int`, the valence
  numbers and `mtot` first; `hw_type`, `eff_charge`, `gl`, `gs` change only the
  transition operators.
