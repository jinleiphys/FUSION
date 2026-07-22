# SWANLOP verification

**Status: TIER 1.** The distribution ships reference outputs for its quick-start
case and this build reproduces them line for line (modulo the per-run timestamp).

Source: H.F. Arellano and G. Blanchon, *SWANLOP: Scattering waves off nonlocal
optical potentials in the presence of Coulomb interactions*, Comput. Phys. Commun.
**259**, 107543 (2021), DOI 10.1016/j.cpc.2020.107543, verified live against
CrossRef. Distributed on Mendeley Data, DOI 10.17632/89gw9jdfv4.1 (the code is the
8 MB `swanlop.tar.gz`; the 530 MB `SupplementaryMaterial.tar.xz` is precomputed
potential tables, not needed for the benchmark).

## The benchmark case (shipped quick-start)

p + 208Pb elastic scattering at 30.3 MeV with the Tian-Pang-Ma (TPM) nonlocal
optical potential, Rmax = 16 fm, NRP = 160, angles 0 to 180 deg. From `runs/`:

```
cp fort.quick-start fort.1
../sources/swanlop.x
```

Outputs (all named `zz.*`): `zz.main` (run summary), `zz.xaq` (angular
observables: Theta, q, dsigma/dOmega, Ay, Q, sigma/sigma_Ruth, plus the reaction
cross section), `zz.dsdt` (dsigma/dt).

## L1: reproduction of the shipped reference output

The package ships `zz.main.REF`, `zz.xaq.REF`, `zz.dsdt.REF`. This build
reproduces them:

| file | result |
|---|---|
| zz.xaq  (dsigma/dOmega, Ay, Q, reaction xsec) | **IDENTICAL** to zz.xaq.REF, 193 lines |
| zz.dsdt (dsigma/dt) | **IDENTICAL** to zz.dsdt.REF, 192 lines |
| zz.main (run summary) | identical except the Date/Time/UTC header line |

Measured on macOS/ARM64 gfortran 15.2. The only differences are the per-run
timestamp lines (`Date:`, `Time:`, `UTC`), which legitimately vary; excluding
those, the numeric content matches byte for byte. `verify_swanlop.sh` strips the
timestamp lines and requires a line-for-line match against the shipped `.REF`.

This is a genuine tier-1 reproduction of the code's OWN distributed reference
output. What is established, and what is not, stated precisely:

- **Established:** this build reproduces the Arellano-Blanchon shipped reference
  byte for byte (modulo timestamp) on macOS/ARM.
- **Not established as bit-identical across compilers:** the `.REF` files carry no
  toolchain metadata, so this is a reproduction of the shipped reference on this
  build, not a proven cross-compiler result. A different gfortran could perturb
  the last digits; if a future build stops matching, suspect the toolchain and
  confirm the physics with the reaction cross section rather than a line diff.

## L2: numeric anchor

`zz.xaq` reports `Reactn xSectn : 1.66084E+00 b`. `verify_swanlop.sh` asserts this
equals the shipped reference value 1.66084 b to 5e-6, independently of the
line-for-line diff, so a reformatting that preserved the diff but corrupted the
headline number would still be caught.

## Reproducing

```bash
bash ../scripts/install_swanlop.sh    # download the 8 MB code, build (~8 s)
bash ../scripts/verify_swanlop.sh     # L1 (zz.*.REF reproduced) + L2 (reaction xsec)
bash ../scripts/selftest_swanlop.sh   # the harness guards (10 cases)
```
