# SWANLOP failure modes

Hit while building and verifying the skill on macOS/ARM64 gfortran 15.2.

## Download / build

- **The Mendeley dataset has two files; only the small one is the code.**
  `swanlop.tar.gz` (~8 MB) is the sources, quick-start and reference outputs;
  `SupplementaryMaterial.tar.xz` (~530 MB) is precomputed potential tables, not
  needed to build or to run the quick-start. `install_swanlop.sh` fetches only the
  code tarball. Downloading the 530 MB file to build the skill would be a large
  waste.

- **The makefile declares `SHELL = /bin/csh`.** The recipes are simple enough that
  this does not bite on macOS (csh is present), but a system without csh would
  fail the build for a reason unrelated to the code. gfortran with the shipped
  flags (`-O2 -g -fbounds-check -fbacktrace -ffpe-trap=invalid,zero,overflow`)
  builds clean.

- **`-ffpe-trap=invalid,zero,overflow` is on by default.** The build traps
  floating-point exceptions, so a genuinely divergent calculation aborts with a
  backtrace rather than writing NaNs. That is a feature (a failed run fails
  loudly), but it means a marginal user potential can abort where a laxer build
  would have limped on; read the backtrace rather than assuming a build problem.

## Run

- **`swanlop.x` reads and writes the current directory.** It needs `fort.1`,
  `NucChart`, and any experimental data file present in the cwd, and writes its
  `zz.*` outputs there. Running it in the shipped `runs/` directory overwrites the
  distributed outputs; the wrappers run in a scratch copy instead so the tree and
  its `.REF` files stay pristine.

- **The KPOT choice dictates which extra files are required.** KPOT=3/4/5 need a
  potential in `fort.2`; KPOT=0 needs a local potential in `fort.22`; KADD=1 needs
  `fort.22`. A deck that selects a read-from-file potential without providing the
  file fails at read time. The quick-start (KPOT=2, TPM built-in) needs neither.

- **Success is not the `STOP SWANLOP [OK]` string.** A run can print progress and
  still produce an incomplete `zz.xaq`; assert the reaction cross section is finite
  and positive and that angular rows were written, from the file.

## Verification

- **A raw `diff` against the `.REF` always shows the timestamp line.** Every `zz.*`
  file stamps `Date:`/`Time:`/`UTC` at run time, so the comparison must strip those
  lines (and any `CPU` timing line) before matching. `verify_swanlop.sh` does.

- **The `.REF` files carry no toolchain metadata.** The match is a reproduction of
  the shipped reference on this gfortran build, not a proven cross-compiler
  result; a different gfortran could perturb the last digits. If a future build
  stops matching the `.REF`, suspect the toolchain and fall back to the reaction
  cross section (1.66084 b) as the physics anchor rather than the line diff.
