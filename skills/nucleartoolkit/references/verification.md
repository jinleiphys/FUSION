# NuclearToolkit.jl verification

**Status: TIER 1.** The package ships a test suite whose `@test` assertions
compare against the authors' own reference values (embedded constants and
generated interactions); the skill reproduces them. Two levels:

- **L1** the CKpot Be-8 valence shell-model spectrum, self-contained and fast.
- **L2** the full `Pkg.test("NuclearToolkit")`, the ordered ab initio pipeline.

Source: S. Yoshida, *NuclearToolkit.jl: A Julia package for nuclear structure
calculations*, J. Open Source Softw. **7**(79), 4694 (2022), DOI
10.21105/joss.04694, verified live against CrossRef. MIT license (Sota Yoshida).
Registered Julia package; the skill installs it with `Pkg.add` into an isolated
depot, pinned to a fixed version, and does not redistribute the source.

## L1: CKpot Be-8 shell-model spectrum (fast anchor)

`main_sm(ckpot.snt, "Be8", 10, []; q=2, is_block=true)` with the shipped
Cohen-Kurath p-shell interaction. The ten lowest eigenvalues against the shipped
reference (`test/ShellModel_test.jl`):

| state | ref (MeV) | this build (MeV) | \|dE\| |
|---|---|---|---|
| 1 | -31.119 | -31.1194 | 4.1e-4 |
| 2 | -27.300 | -27.2997 | 2.8e-4 |
| 3 | -19.162 | -19.1618 | 1.8e-4 |
| ... | ... | ... | ... |
| 10 | -13.478 | -13.4781 | 7.8e-5 |

The shipped test gate is `(Eref - E)^2 < 1e-6`, i.e. **|dE| < 1e-3**, matching the
references quoted to three decimals. Measured max |dE| = 4.1e-4 over all ten
states, well inside the gate. `verify_nucleartoolkit.sh` pins all ten and gates
at 1e-3. Deterministic; about 15 s including Julia startup.

## L2: full Pkg.test (ab initio pipeline)

`Pkg.test("NuclearToolkit")` runs the ordered suite and reproduces every shipped
`@test`: **30/30 passed in ~3.5 min** on this build. The ab initio anchors
(`test/HFMBPT_IMSRG_test.jl`, He-4, EM500 N3LO, hw=20, emax=2):

| observable | reference | gate |
|---|---|---|
| HF energy | 1.493 MeV | \|dE\|^2 < 1e-4 |
| MBPT2 | -5.805 MeV | \|dE\|^2 < 1e-4 |
| MBPT3 | 0.395 MeV | \|dE\|^2 < 1e-4 |
| IMSRG ground state | -4.05225276 MeV | \|dE\| < 1e-6 |
| VS-IMSRG ground state | -4.05225276 MeV | \|dE\| < 1e-6 |
| Rp^2 (charge radius) | 1.559825^2 fm^2 | tight |

plus VS-IMSRG Be-8 shell-model energies, the USDB O-18 occupation truncation,
transitions (Li-6, He-6), and electron capture (O-20). `verify_nucleartoolkit.sh`
requires the `Pkg.test` summary to report Pass == Total (>= 25) and the trailing
"tests passed" line, with a zero exit; a partial or aborted suite fails.

## Why this is tier 1

The benchmark reproduces the code's OWN documented reference values (the shipped
`@test` constants) to their stated tolerances, which is the FUSION tier-1
definition. Unlike a compiled code, there is no cross-build question: a registered
Julia package is built by Julia's own toolchain on any platform, and the pinned
version fixes the numerics. The IMSRG ground state is pinned to 1e-6, a strong
ab initio anchor.

## What is NOT claimed

- No cross-platform bit-identity is asserted (the many-body flow and
  diagonalization are floating-point iterative); the claim is reproduction of the
  shipped `@test` references to their tolerances at the pinned version.
- Physics values are the package's outputs for its shipped interactions and
  settings, not independently validated against experiment (USDB/CKpot are fitted
  effective interactions; the ab initio He-4 uses the shipped EM500 interaction).

## Reproducing

```bash
bash ../scripts/install_nucleartoolkit.sh    # isolated depot, pinned Pkg.add + precompile
bash ../scripts/verify_nucleartoolkit.sh     # L1 (CKpot anchor) + L2 (full Pkg.test)
NTK_FAST=1 bash ../scripts/verify_nucleartoolkit.sh   # L1 only (fast)
bash ../scripts/selftest_nucleartoolkit.sh   # harness guards (17 cases, stubbed)
```
