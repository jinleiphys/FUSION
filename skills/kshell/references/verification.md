# KSHELL verification

**Status: TIER 2.** KSHELL ships interaction files and runnable test scripts but no
reference eigenvalue for a fixed case, so the benchmark is input alignment plus
build integrity by cross-build agreement plus a physics anchor, on the 20Ne USDA
case. Legitimate tier-2 ship per the 2026-07-20 ruling; honestly NOT a
reproduction of a distributed reference number, because the distribution ships
none.

Source: N. Shimizu, T. Mizusaki, Y. Utsuno, Y. Tsunoda, *Thick-restart block
Lanczos method for large-scale shell-model calculations*, Comput. Phys. Commun.
**244**, 372-384 (2019), DOI 10.1016/j.cpc.2019.06.011, verified live against
CrossRef (original code paper arXiv:1310.5431). Public on GitHub; KSHELL is GPL-3.0
(declared in the README, no standalone LICENSE file), and the skill clones from
upstream rather than redistributing (see `failure-modes.md`).

## The benchmark case

^20Ne in the sd shell with the USDA interaction: 2 valence protons and 2 valence
neutrons above the ^16O core, M-scheme M=0, five lowest states. Partition built
by `gen_partition.py usda.snt p.ptn 2 2 1`, then `kshell.exe` on the namelist.

## L1: cross-build agreement (build integrity)

The five lowest M=0 eigenvalues:

| state | E (MeV) | J^pi | Ex (MeV) |
|---|---|---|---|
| 1 | -40.46689 | 0+ | 0.0000 |
| 2 | -38.77105 | 2+ | 1.6958 |
| 3 | -36.37577 | 4+ | 4.0911 |
| 4 | -33.91870 | 0+ | 6.5482 |
| 5 | -32.88208 | 2+ | 7.5848 |

These five numbers are **identical to all five printed decimals across two builds**:

| build | ground state | first 2+ |
|---|---|---|
| macOS ARM64 gfortran 15.2 | -40.46689 | -38.77105 |
| Linux x86_64 gfortran 13.3 (heliumx) | -40.46689 | -38.77105 |

The Lanczos diagonalization converges to the same eigenvalues at the printed
precision on both toolchains, so `verify_kshell.sh` pins the macOS value and gates
at 1e-4 (well inside the exact printed-precision match, far under the percent-level
shift a real bug makes). The Linux leg was run on heliumx and is the
build-integrity evidence; `verify` runs on the local platform only.

## L2: physics anchor (the 20Ne rotational band)

The spectrum is the known 20Ne ground-state band: a J=0+ ground state, a J=2+
first excited state at Ex = 1.70 MeV, and a J=4+ at 4.09 MeV, the K=0 rotational
sequence. The experimental 2+ sits at 1.634 MeV; USDA is a fitted sd-shell
interaction, so 1.70 MeV (about 4% high) is the expected agreement.
`verify_kshell.sh` asserts J=0+ ground, J=2+ first excited, and Ex(2+) in
[1.4, 2.0] MeV, so the physics is anchored independently of the pinned numbers.

## What is NOT claimed

No shipped reference number is reproduced (none exists). The USDA g.s. energy is
relative to the ^16O core with the USDA single-particle energies; it is KSHELL's
deterministic output for this interaction and model space, cross-build verified,
not matched to an external published value (that would require pinning the exact
energy convention). Upgrade path: reproduce a published USDA/USDB 20Ne value once
the core-energy convention is confirmed, or the repo's v2-to-v4 regression fixtures.

## Reproducing

```bash
bash ../scripts/install_kshell.sh    # clone GaffaSnobb fork, build (~20 s)
bash ../scripts/verify_kshell.sh     # L1 (cross-build spectrum) + L2 (band physics)
bash ../scripts/selftest_kshell.sh   # the harness guards (13 cases)
```
