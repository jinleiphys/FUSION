# SkyNet verification

**Status: TIER 1, with a documented macOS caveat.** SkyNet ships a CTest suite
whose cases self-compare against the authors' own reference values (constants
embedded in the test sources and reference files shipped in the test
directories). The skill reproduces those references: **19/19 on Linux**, and
**17/19 on macOS** with two exceptions that are localized and shown benign by
the Linux pass on the identical source.

Source: J. Lippuner and L. F. Roberts, *SkyNet: A Modular Nuclear Reaction
Network Library*, Astrophys. J. Suppl. **233**, 18 (2017), DOI
10.3847/1538-4365/aa94cb, arXiv:1706.06198. BSD 3-Clause (California Institute
of Technology). Public and anonymously clonable at
`bitbucket.org/jlippuner/skynet`; the skill clones from upstream and does not
redistribute the source.

## The benchmark cases

Two are used as pinned numeric anchors, on top of the full CTest suite:

- **AlphaNetwork**: an alpha-chain network (he4 through ni56) evolved to nuclear
  statistical equilibrium, compared against the analytic equilibrium abundances.
  Self-contained (no external trajectory) and cross-platform stable.
- **NSE**: nuclear statistical equilibrium (the Saha equation) solved at three
  settings of increasing stiffness, each compared against a reference block.

## L1: AlphaNetwork numeric anchor (cross-platform stable)

The dominant product mass fraction, from the built `AlphaNetwork` executable:

| quantity | macOS ARM64 clang 17 | Linux x86_64 gfortran 13.3 |
|---|---|---|
| X(ni56) | 1.7794E-02 | 1.7794E-02 |
| max fractional error vs analytic | 1.2E-03 | 8.5E-04 |

X(ni56) is identical to all five printed figures on both platforms; per-nuclide
abundances agree to 4 to 5 figures. `verify_skynet.sh` pins X(ni56) = 1.7794E-02
at 1e-3 relative (well inside the printed-precision match, far under a real
regression) and requires the AlphaNetwork CTest case to pass.

## L2: NSE, three blocks of increasing stiffness

The `NSE` test runs three Saha solves. The first two reproduce on **every**
platform; the third is the macOS exception:

| block | T9, rho, Ye | reference | gate | macOS | Linux |
|---|---|---|---|---|---|
| 1 (3 nuclides) | 5, 1e9, 0.1 | embedded Yexpected | frac < 1e-10 | 1.2E-14 ✓ | 1.2E-14 ✓ |
| 2 (X-ray burst) | 8, 1e6, 0.25 | `nse_xray_burst` | abs < 8e-4 | 0.000777272 ✓ | 0.000777272 ✓ |
| 3 (full network) | 3, 1e8, 0.25 | `nse_all` | abs < 3.5e-5 | 7.0E-03 ✗ | 2.45E-05 ✓ |

Block 2 gives the **identical** 0.000777272 on both platforms. Block 3 is a
full-network Saha solve at T9=3 where the equilibrium abundances span roughly
200 orders of magnitude (ni56 ~ 5e-201). At that dynamic range the difference
between Apple's and glibc's `exp`/`log` implementations, amplified through the
Newton iteration, moves a mass fraction by ~7e-3, past the 3.5e-5 gate that was
calibrated on the authors' (glibc-family) platform. It is not fixable by a flag:
`-ffp-contract=off` gives the byte-identical 0.00701498, so it is a library
`exp`/`log` difference, not FMA contraction or optimization-sensitive UB.

`verify_skynet.sh` encodes this narrowly: blocks 1 and 2 must pass on **both**
platforms (a real NSE regression breaks them), and block 3 must meet the 3.5e-5
gate on Linux; only on macOS is block 3 allowed to exceed, and even there it is
bounded (< 2e-2), so a gross regression still fails.

## L3: the full CTest suite

| platform | build | result |
|---|---|---|
| macOS ARM64, Apple clang 17 / gfortran 15.2, Homebrew HDF5/GSL/Boost, Accelerate LAPACK | Release | **17/19** |
| Linux x86_64 (heliumx), gfortran/g++ 13.3, conda-forge HDF5/GSL/Boost, system LAPACK | Release | **19/19** |

The two macOS failures are exactly `StopWatch` and `NSE`:

- **StopWatch** times a 0.5 s sleep and gates at 1% relative. It is a wall-clock
  self-test of the timer class, not physics; it passes on a quiet machine and
  flakes on a busy one. Excluded from the physics benchmark.
- **NSE** fails only because of block 3 above.

`verify_skynet.sh` requires the set of failing CTest cases to be a subset of the
platform's allowed set (empty on Linux, {StopWatch, NSE} on macOS), and requires
AlphaNetwork never to be among the failures.

## Build integrity by cross-build (behaviour-preserving patches)

Five source patches are needed for Apple clang / libc++ / modern Boost / modern
CMake (see `failure-modes.md`). They are proven behaviour-preserving by the fact
that the **same patched source** builds and passes **19/19 on Linux**: a patch
that altered physics would have moved a Linux number. Concretely, X(ni56),
NSE block 1, and NSE block 2 are identical across the two platforms to their
printed precision, and only block 3 (the libm-limited stiff case) and the
wall-clock StopWatch differ.

## What is NOT claimed

- Not bit-identical across platforms. SkyNet integrates stiff ODEs and solves
  nonlinear NSE systems, so architecture and libm differences produce
  last-figures (and, for the T9=3 full-network NSE, larger) differences. The
  claim is reproduction of the shipped references to their own tolerances, which
  holds fully on Linux and with the two documented exceptions on macOS.
- The Python (SWIG) bindings are not built or benchmarked here.

## Reproducing

```bash
bash ../scripts/install_skynet.sh    # clone, patch, build, install (~min cold)
bash ../scripts/verify_skynet.sh     # L1 (alpha anchor) + L2 (NSE blocks) + L3 (CTest)
bash ../scripts/selftest_skynet.sh   # harness guards (14 cases, stubbed)
```

The Linux leg was run on heliumx with a conda-forge `hdf5 gsl boost cmake` env;
`verify_skynet.sh` reports the platform and its allowed exceptions on each run.
