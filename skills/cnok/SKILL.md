---
name: cnok
description: >-
  Drive CNOK, the C++ Glauber-model single-nucleon knockout code of Y.Z. Sun and S.T. Wang (Comput. Phys. Commun. 288, 108726 (2023); GPL-3.0, gitee.com/asiarabbit/cnok). Compute single-particle removal cross sections (stripping + diffractive dissociation) and parallel (longitudinal) momentum distributions of the heavy residue (core) in one-nucleon knockout from intermediate-energy (30 MeV/u to 2 GeV/u) stable and radioactive beams on a light composite target, via the eikonal/sudden Glauber model with a t-rho-rho optical potential; supports batch mode over valence configurations (C2S-weighted inclusive cross sections and momentum distributions, spectroscopic-factor / quenching studies). Use for 跑CNOK, CNOK input, Glauber, 敲出, knockout, single-nucleon removal, stripping, diffractive dissociation, 动量分布, momentum distribution, sigma_sp, single-particle cross section, spectroscopic factor, 谱因子, C2S, quenching, eikonal, sudden approximation, t-rho-rho, 16C knockout, exotic nuclei knockout, MOMDIS.
---

# Driving CNOK

CNOK implements the Glauber reaction model for single-nucleon knockout. It builds
the valence-nucleon bound state in a Woods-Saxon well (searching the well
parameters to reproduce a chosen separation energy and rms radius), builds the
core+target and valence+target optical potentials from nucleon densities by the
t-rho-rho prescription, and evaluates the stripping and diffractive-dissociation
cross sections and the core's parallel momentum distribution. The single-particle
cross section sigma_sp is the "unit" cross section from which experimental
spectroscopic factors (and their quenching) are extracted.

Upstream: `gitee.com/asiarabbit/cnok`, GPL-3.0, C++ and CMake, needs yaml-cpp
(ROOT optional, for plotting only). It targets Linux + gcc; two small, proven
behaviour-preserving edits let it build under Apple clang / libc++ (below).

## Prime rules (do not skip)

1. **Content is the verdict, never the exit status.** `mom` prints a long
   integrand trace to stdout and writes the answer to a timestamped result file
   `<basedir>/<name>_<YYYYMMDD>_<HHMM>.txt`. Success means: a zero exit, a result
   file, three finite positive cross sections, `TOTAL == STRIP + DIFF`, and the
   file's `S_N+Ex` equal to the deck's `Eref` (a substituted-deck guard).
   `run_cnok.sh` asserts all of these from the file.
2. **The benchmark is tier 1 and cross-build bit-identical.** `./mom 1s11p`
   (neutron removal from ^16C's `1s1/2 (x) 1/2+`) gives
   (sigma_str, sigma_diff, sigma_sp) = (60.086689, 18.056073, 78.142761) mb,
   identical to every printed digit across macOS/clang (patched, -O2 and -O0) and
   Linux/gcc (unpatched and patched). Stripping matches the paper's documented
   60.087 mb exactly. See `references/verification.md`.
3. **`mom` must run from the build directory.** It resolves `config/basedir.yaml`
   and the deck path relative to the cwd. The wrappers `cd` into the build tree
   and set `basedir.yaml` for you.
4. **The `<name>` argument is both the YAML basename and the valence
   configuration.** `1s11p` = `1s1/2 (x) 1/2+`, `0d55p` = `0d5/2 (x) 5/2+`
   (half-integer core spin as `2J`; integer J drops the trailing `i`). Prepare
   `<basedir>/<name>.yaml` first; batch mode deduces the per-config names from
   this convention.
5. **`-m` gives the parallel momentum distribution instead of the cross
   section.** CNOK computes the stripping, the diffractive, and the total
   distribution of the core (writing `*_strT.txt`, `*_difT.txt`, `*_totT.txt`);
   including the diffractive part, which most Glauber codes drop, is one of its
   selling points. `-mc` convolves with `config/expres.yaml`.
6. **The result file is timestamped to the minute.** Clear stale `<name>_*.txt`
   before a run and take the newest after (the wrappers do), so a leftover file
   from a killed or earlier run is never read as a fresh result.
7. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_cnok.sh` clones CNOK, resolves yaml-cpp (Homebrew on macOS;
system or a source build on Linux), applies the portability patches, builds with
CMake, runs the benchmark deck as a probe, and prints three lines:

```
CNOK=<path to the mom executable>
CNOK_BUILD=<build dir; mom runs from here>
CNOK_YAMLLIB=<yaml-cpp lib dir, for the runtime loader>
```

About 7 s once yaml-cpp is present (`brew install yaml-cpp` on macOS). Requires
`git`, `cmake`, a C++11 compiler, and yaml-cpp.

The macOS build applies, only where needed and all proven behaviour-preserving by
the four-build cross check: `fabs -> std::abs` in the templated Romberg /
interpolation headers (libc++ has no `fabs(complex)`), a `__APPLE__`-guarded
`ulong` typedef, and the link flag `-Wl,-undefined,dynamic_lookup` (a macOS
`.dylib` rejects the cross-library undefined symbols a Linux `.so` allows). On
Linux the code builds unpatched. Details in `references/failure-modes.md`.

## Command line

```
./mom <name>              # cross sections for one valence configuration
./mom <name> -m           # parallel momentum distribution instead
./mom <name> -mc          # ... convolved with experimental resolutions
./mom -b rs.yaml          # batch: inclusive c.s. summed over configs (C2S-weighted)
./mom -b batch.yaml       # super-batch: many nuclei in one run
```

Field-level deck reference: `references/input-format.md`; outputs:
`references/output-format.md`. Both are written from the shipped decks and the
code's comments, not from memory.

## Workflow

```bash
bash scripts/install_cnok.sh                 # prints CNOK=, CNOK_BUILD=, CNOK_YAMLLIB=
bash scripts/run_cnok.sh 1s11p               # the benchmark case (basedir default config/C/C16)
bash scripts/run_cnok.sh 0d55p config/C/C16  # another 16C valence configuration
bash scripts/verify_cnok.sh                  # tier-1 benchmark (cross-build pin + paper anchor)
bash scripts/selftest_cnok.sh                # test the harness guards (11 cases)
```

## Verified benchmark

**^16C(-1n) at 239 MeV/nucleon, the `1s1/2 (x) 1/2+` configuration** (paper Sec. 5.5):

| check | result |
|---|---|
| L1 stripping / diffractive / total | (60.086689, 18.056073, 78.142761) mb, **bit-identical across 4 builds** (macOS clang -O2/-O0, Linux gcc unpatched/patched) |
| L2 stripping vs paper's documented 60.087 mb | **exact** to the paper's precision |

L1 is the tier-1 build-integrity result (two compilers, two architectures,
identical output; -O0 == -O2 rules out optimization-sensitive UB, and the
gcc-unpatched vs clang-patched match proves the libc++ patch is
behaviour-preserving). The paper's diffractive/total (18.050, 78.136) sit 0.03% /
0.009% below the released code; since the two independent builds agree bit-for-bit
that drift is on the paper side (manuscript predates the final commit) and is
smaller than the paper's own CNOK-vs-MOMDIS spread (0.09%). The physics is
anchored independently by that MOMDIS cross-check. Full account:
`references/verification.md`.

## Failure modes

See `references/failure-modes.md`. The ones that bite: `fabs(complex)` and
`ulong` will not compile under libc++ (patched); the FCI `.dylib` needs
`-undefined dynamic_lookup` on macOS; yaml-cpp must be fed to CMake via
`CPATH`/`LIBRARY_PATH` (no `find_package`); `mom` must run from the build dir; and
the minute-stamped result file can be stale, so clear it before each run.
