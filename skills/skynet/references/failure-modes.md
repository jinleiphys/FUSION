# SkyNet failure modes

Everything here was hit while building SkyNet from source on Apple Silicon and
cross-building on Linux. The five source patches live in
`scripts/skynet_macos_portability.patch` (generated against upstream commit
`e37ae9c`); `install_skynet.sh` applies it after resetting the tree to that
commit.

## The five portability patches (why each is behaviour-preserving)

1. **`std::pow` is not `constexpr` outside GCC's extension** (`Constants.hpp`).
   `TwoPiHbar2C2NA23 = TwoPiHbar2C2 * pow(N_A, 2/3)` is a `constexpr` member;
   GCC 4.9 accepted a constexpr `pow`, Apple clang rejects it. The upstream code
   already special-cases the Intel compiler with a hardcoded literal
   `7.13127680E15`, but that is only 9 figures and its 3.4e-10 relative error
   exceeds the NSE block-1 tolerance of 1e-10. The patch writes the literal
   `7131276797594583.0`, the correctly-rounded IEEE double of
   `pow(6.02214129E23, 2.0/3.0)` with the **double** exponent `2.0/3.0`
   (= 0.66666666666666663), which is exactly what GCC's compile-time `pow` folds
   to and what libm `pow(double,double)` returns. (Using the exact rational 2/3
   would round to a different double, `7131276797594598.0`, 15 ULP / 2.1e-15
   away, but the code's exponent is the double, so 583 is the faithful value and
   the difference is far below any physics tolerance anyway.) Verified by the
   Linux pass and the identical cross-platform NSE block-1 result.

2. **FPE trapping is guarded on the compiler, not on glibc**
   (`FloatingPointExceptions.hpp`). The code enables `feenableexcept` /
   `fedisableexcept` whenever `__GNUC__` is defined. Those are **glibc**
   extensions, absent on macOS libc, but Apple clang defines `__GNUC__` (it
   masquerades as GCC 4.2), so the build tried to call them and failed to link.
   The patch requires `__GLIBC__` as well. FPE trapping only raises SIGFPE on
   NaN/Inf during debugging; disabling it changes no computed value, so on macOS
   `Enable()`/`Disable()` become no-ops and results are unchanged. Linux keeps it.

3. **Boost.System is no longer a linkable component** (`CMakeLists_Requirements.txt`).
   `find_package(Boost REQUIRED system filesystem serialization)` fails on Boost
   >= 1.85 because `boost_system` is header-only (since 1.69) and modern Boost
   CMake configs ship no `boost_system` target. Boost.Filesystem no longer needs
   it linked. The patch drops `system`; `filesystem` and `serialization` remain.
   Works on both the macOS Homebrew Boost 1.90 and the Linux conda Boost 1.85.

4. **A dylib may not have undefined symbols on macOS** (`CMakeLists.txt`). The
   `SkyNet` shared library target lists no `target_link_libraries`, so its HDF5/
   GSL/Boost symbols are unresolved. Linux resolves them lazily at load time; the
   macOS linker refuses. The patch adds `target_link_libraries(SkyNet
   ${SKYNET_EXTERNAL_LIBS})`, which is correct on every platform (the tests link
   the static library, so this only fixes the shared one).

5. **`std::to_string` needs `<string>`, and `exp10` is glibc-only**
   (`NSE_screening.cpp` for `exp10`; a global `-include string` flag for the
   rest). Many files call `std::to_string` relying on libstdc++'s transitive
   includes, which libc++ does not provide. Rather than edit ~50 files, the build
   force-includes `<string>` with `-include string` (a compiler flag, not a
   source change). Separately, `NSE_screening.cpp` calls `exp10` without including
   SkyNet's own `Exp10.hpp` shim; on Linux glibc supplies `exp10`, on macOS it
   does not. The patch adds the one include (the shim is the canonical `exp10` on
   both platforms, so no numeric change).

## Build traps (confident-looking wrong results and hard stops)

- **Modern CMake refuses `cmake_minimum_required(VERSION 3.1)`.** CMake >= 4.0
  (Homebrew and conda-forge ship it) removed compatibility with `< 3.5` and
  aborts configuration. `install_skynet.sh` passes
  `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`. This is not a SkyNet bug, it is a CMake
  policy change; the code configures fine once the shim is set.

- **The install prefix must not be a case-insensitive match of the shipped
  `INSTALL` file.** SkyNet ships an `INSTALL` text file in the source root. On
  case-insensitive APFS, choosing `install/` as the CMake install prefix collides
  with that file and `make install` cannot create the directory ("Maybe need
  administrative privileges", misleadingly). The skill installs to a sibling
  named `skynet_install`, outside the source tree.

- **The tests abort until `make install` populates `data/`.** Every network case
  reads nuclear data (`webnucleo_nuc_v2.0.xml`, `helm_table.dat`, `reaclib`)
  from the install prefix baked into the binary as `SkyNetRoot`. Before
  `make install` runs, `SkyNetRoot/data` is empty and each test throws
  `std::invalid_argument: ... does not exist` (an abort, not a wrong number).
  `install_skynet.sh` always runs `make install`, not just `make`.

## Runtime and interpretation

- **CONTENT is the verdict.** A network binary can exit 0 having printed only a
  logo and progress lines, or print `nan`/`inf` if the integration diverges.
  `run_skynet.sh` parses the abundance rows and `max error` lines, rejects a run
  with no finite result, and flags any non-finite value (including a literal
  `nan` token, which a numeric-only regex would silently skip).

- **The macOS NSE block-3 delta is not a bug to chase.** See
  `verification.md`. It is a libm difference in a stiff T9=3 full-network Saha
  solve, identical under `-O3` and `-ffp-contract=off`, and the same source
  passes on Linux. Do not loosen the Linux gate or hand-pick a matching number.

- **Run cases from the build tree, not the install tree.** CMake copies each
  case's input files (trajectories, initial compositions) into
  `$SKYNET_BUILD/tests/<Case>/`; the install tree has only `data/` and
  `examples/`. `run_skynet.sh` runs from the build directory.
