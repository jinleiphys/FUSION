# CNOK failure modes

Every entry here was hit while building or verifying the skill on macOS/ARM64
against the Linux/gcc reference. "Content is the verdict" for CNOK too: a run that
prints its integrand trace and exits 0 has not necessarily produced a correct
cross section.

## Build (macOS / Apple clang / libc++)

- **`fabs(std::complex<double>)` does not compile.** The templated Romberg
  integrator and polynomial interpolator (`cnok/inc/TAIntegrate.hpp`,
  `TAInterpolate.hpp`) call `fabs` on the template type, which is instantiated
  with `std::complex<double>` for the diffractive channel. libstdc++ (gcc)
  accepts this and returns the magnitude; libc++ has no such overload and the
  build stops with "no matching function for call to 'fabs'". Fix: `fabs ->
  std::abs`, which is the magnitude for complex and identical to `fabs` for the
  real instantiations. Proven behaviour-preserving: the Linux gcc build gives
  bit-identical output with and without this edit (see verification.md).

- **`ulong` is an unknown type.** The FCI library header `fci/inc/TABit.h` uses
  the BSD/glibc alias `ulong`, which libc++ in C++ mode does not expose (macOS
  ships only `u_long`, and even `<sys/types.h>` does not define `ulong` here).
  Fix: a `typedef unsigned long ulong;` guarded by `#ifdef __APPLE__`, inert on
  Linux.

- **`.dylib` link fails with "Undefined symbols" for `TAException::*`,
  `TADiagonalize::*`.** CNOK's FCI shared library references symbols defined in
  the CNOK (`momd`) library but does not link it. A Linux `.so` allows undefined
  symbols (resolved at final link); a macOS `.dylib` rejects them by default. Fix
  is a link flag, not a source edit: build with
  `-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-undefined,dynamic_lookup` on Darwin only (the
  `mom` executable supplies every symbol). This flag is a macOS ld spelling; do
  NOT pass it on Linux, where gcc's ld does not understand it and the default
  already permits undefined symbols in a shared object.

- **yaml-cpp is mandatory and not found by CMake automatically.** CNOK's CMake
  does `target_link_libraries(momd yaml-cpp)` with a bare name and no
  `find_package`, so Homebrew's `/opt/homebrew/{include,lib}` (not on the default
  clang search path) must be fed in via `CPATH`/`LIBRARY_PATH`. `install_cnok.sh`
  resolves yaml-cpp (Homebrew on macOS; system or a source build on Linux) and
  sets those.

- **BSD `sed` has no `\b`.** The `fabs->std::abs` rewrite must not use
  `sed 's/\bfabs(/.../'`: BSD sed silently matches nothing and the patch appears
  to succeed while doing nothing. The installer uses `perl` for the substitution
  and asserts `std::abs(` is present afterward.

## Run

- **`mom` must run from the build directory.** It resolves `config/basedir.yaml`
  and the deck path relative to the current working directory, so a run from any
  other cwd fails to find its input. The wrappers `cd` into the build tree.

- **Runtime loader cannot find `libyaml-cpp`.** `mom` links yaml-cpp and the
  build-tree `libmomd`/`libsunny`. The latter two are found by baked build-tree
  rpaths; yaml-cpp may need `DYLD_LIBRARY_PATH` (macOS) / `LD_LIBRARY_PATH`
  (Linux) pointed at its lib dir. The wrappers export `CNOK_YAMLLIB` into both.

- **The result file is timestamped to the minute and can be stale.** Re-running
  the same case within a minute overwrites one file; a killed run can leave a
  previous case's file in place. Clear `<name>_*.txt` before each run (the
  wrappers do) and take the newest afterward, so a stale file is never read as a
  fresh result.

- **`ZEROR` too small diverges, too large truncates.** If the bound-wave solver
  reports "ODEIntegrator: Too many steps occurred", set `ZEROR` in the deck (the
  ODE origin). The deck's own comment warns 1e-4 diverges and 0.1 drops the inner
  cross section; the shipped decks omit it (default is fine for the benchmark).

## Documentation drift (not a bug in the build)

- **The paper's diffractive/total differ from the released code by ~0.03%.** The
  paper (Feb 2023) documents (60.087, 18.050, 78.136) mb; the current Gitee code
  gives (60.087, 18.056, 78.143). Stripping matches exactly. The two independent
  builds (gcc-unpatched, clang-patched) agree bit-for-bit, so the drift is on the
  paper side and is smaller than the paper's own CNOK-vs-MOMDIS spread (0.09%).
  `verify_cnok.sh` gates on the code's actual cross-build value and reports the
  paper comparison, rather than failing on the drift.
