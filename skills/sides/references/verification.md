# SIDES verification

**Status: TIER 2.** SIDES ships no reference output, so the benchmark is input
alignment plus build integrity by cross-build agreement plus a physics-consistency
identity, on the shipped example. This is a legitimate tier-2 ship per the
2026-07-20 ruling (an input manual plus a working sample deck is enough to build
the skill); it is honestly NOT a reproduction of a distributed reference number,
because the distribution ships none.

Source: G. Blanchon, M. Dupuis, H.F. Arellano, R.N. Bernard, B. Morillon, *SIDES:
Nucleon-nucleus elastic scattering code for nonlocal potential*, Comput. Phys.
Commun. **254**, 107340 (2020), DOI 10.1016/j.cpc.2020.107340, verified live
against CrossRef. Distributed on Mendeley Data, DOI 10.17632/cmpjgyrngr.1.

## The benchmark case (shipped `INPUT`)

n + 40Ca elastic scattering at 20 MeV with the Tian-Pang-Ma (TPM) nonlocal
optical potential, relativistic kinematics, Numerov, Rmax = 15 fm. Run:

```
./sides.x < INPUT
```

Integral cross sections written to `INTEGRAL-CROSS-SECTION-nCa40`:

| quantity | value (mb) |
|---|---|
| reaction | 1115.7176002621441 |
| elastic  | 769.20018156053038 |
| total    | 1884.9177818226751 |

## L1: cross-build agreement (build integrity)

The three cross sections agree across two toolchains:

| build | reaction | elastic | total |
|---|---|---|---|
| macOS ARM64 gfortran 15.2 | 1115.7176002621441 | 769.20018156053038 | 1884.9177818226751 |
| Linux x86_64 gfortran 13.3 | 1115.7176002621225 | 769.20018156060860 | 1884.9177818227311 |

Agreement is to **~12 significant figures** (~1e-11 relative), not bit-identical:
the integro-differential iteration accumulates floating-point differences between
gfortran 13.3 and 15.2. That is the expected size of cross-compiler-version FP
noise for an iterative solver; a miscompilation or undefined behaviour would
diverge at the percent level, not the eleventh digit. `verify_sides.sh` pins the
macOS value and gates at **1e-9 relative**: two orders of margin over the observed
1e-11 cross-version agreement, and far tighter than a real regression. (Contrast
CNOK, which is bit-identical across builds because its integrand path does not
iterate; SIDES's does, so 12 figures is the honest claim.)

Note what `verify_sides.sh` actually does: it is a **regression gate** comparing a
fresh local run to the pinned reference, not a re-run of the cross-build. The
Linux gfortran 13.3 leg was run once on heliumx and its numbers are the
build-integrity evidence recorded in the table above; the local `verify` does not
recompute them. A single-platform install therefore certifies "reproduces the pin
here", and the cross-build agreement is the documented, not re-executed, half of
the claim.

## L2: physics-consistency anchor (neutron optical theorem)

For a neutron projectile there is no Coulomb interaction, so the optical theorem
gives TOTAL = ELASTIC + REACTION exactly:

```
769.20018156053038 + 1115.7176002621441 = 1884.9177818226745  vs  total 1884.9177818226751
```

which holds to ~3.6e-16 (machine precision). `verify_sides.sh` asserts this to
1e-9. It is a code-internal identity, not an external reference, but it certifies
that the elastic and reaction channels are mutually consistent rather than each
independently wrong by a compensating amount.

## What is NOT claimed

No shipped reference number is reproduced (none exists). The TPM potential is a
phenomenological nonlocal OMP; the SIDES paper's headline benchmarks use chiral
N3LO and AV18 folding potentials, which the shipped example does not exercise.
Upgrade path to a stronger anchor: feed SIDES and NLAT (already a FUSION skill)
the SAME Perey-Buck potential and compare, since SIDES is explicitly designed as
the seedless alternative to NLAT's iterative method; that is the intended
cross-code comparison, not convention archaeology, and would promote this to a
numeric physics benchmark.

## Reproducing

```bash
bash ../scripts/install_sides.sh    # download from Mendeley, build (~2 s)
bash ../scripts/verify_sides.sh     # L1 (cross-build pin) + L2 (optical theorem)
bash ../scripts/selftest_sides.sh   # the harness guards (11 cases)
```
