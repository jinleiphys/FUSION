---
name: nucleartoolkit
description: >-
  Drive NuclearToolkit.jl, the Julia nuclear-structure package of Sota Yoshida (J. Open Source Softw. 7(79), 4694 (2022); DOI 10.21105/joss.04694; MIT; github.com/SotaYoshida/NuclearToolkit.jl). One package spanning the ab initio to shell-model chain: generate chiral-EFT NN(+3N) interactions, run Hartree-Fock many-body perturbation theory (HFMBPT), the in-medium similarity renormalization group (IMSRG) and valence-space IMSRG (VS-IMSRG), and valence-space shell-model diagonalization (energies, spins, transitions, electron capture). Use for 跑NuclearToolkit, NuclearToolkit.jl, Julia nuclear structure, ab initio, 从头计算, IMSRG, VS-IMSRG, in-medium SRG, HFMBPT, Hartree-Fock, MBPT, chiral EFT interaction, 手征有效场论, shell model, 壳模型, valence space, effective interaction, CKpot, USDB, Cohen-Kurath, sd shell, p shell, ground-state energy, spectrum, He4, Be8, O18, binding energy, nuclear structure Julia.
---

# Driving NuclearToolkit.jl

NuclearToolkit.jl covers the whole structure pipeline in one Julia package:
generate a chiral-EFT interaction, softening it and mapping it into a
harmonic-oscillator basis; run HFMBPT and the (VS-)IMSRG to produce either an
ab initio ground-state energy or a valence-space effective interaction; and
diagonalize the shell model to get spectra, spins, transitions and electron
capture. It is the ab-initio + shell-model counterpart to the phenomenological
shell-model code KSHELL already in this catalog.

Upstream: `github.com/SotaYoshida/NuclearToolkit.jl`, MIT (Sota Yoshida), a
registered Julia package. Paper: JOSS 7(79), 4694 (2022), DOI 10.21105/joss.04694.

## Prime rules (do not skip)

1. **Content is the verdict, never the exit status.** A Julia run can throw and
   still leave a nonzero exit, or print a spectrum with a `NaN`. `run_*` parses
   the eigenvalues and requires them finite, ascending, negative ground state;
   `verify_*` pins the CKpot Be-8 reference and parses the `Pkg.test` Pass/Total.
2. **This is a TIER 1 skill.** The package ships a test suite whose `@test`
   assertions compare against the authors' own reference values, and this
   reproduces them: the CKpot Be-8 shell-model spectrum to the shipped tolerance
   |dE| < 1e-3, and the full `Pkg.test` (30/30) including the He-4 IMSRG ground
   state -4.05225276 to 1e-6. See `references/verification.md`.
3. **The install is ISOLATED.** Everything goes into a dedicated
   `JULIA_DEPOT_PATH` and project under `~/.cache/fusion/nucleartoolkit`, pinned
   to a fixed version, so the user's own global Julia environment and packages
   are never touched or upgraded. Every `julia` call in every script sets
   `JULIA_DEPOT_PATH`; do not drop it, or a run could pick up a different
   NuclearToolkit from `~/.julia`.
4. **Valence numbers are implicit in the interaction + nucleus.** You pass a
   nucleus name (`Be8`, `O18`, ...) and a shipped interaction (`ckpot` p-shell,
   `usdb` sd-shell); the model space comes from the interaction file. Pick an
   interaction whose space contains the nucleus.
5. **No source patches.** Unlike the compiled C/Fortran skills, a Julia package
   is cross-platform through Julia itself; the only provisioning is a pinned
   `Pkg.add` + precompile. Do not vendor or patch the package.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_nucleartoolkit.sh` resolves `julia`, creates an isolated depot +
project, `Pkg.add`s the pinned NuclearToolkit version, precompiles, runs a CKpot
Be-8 probe, and prints five lines:

```
NTK_JULIA=<julia binary>
NTK_DEPOT=<isolated JULIA_DEPOT_PATH>
NTK_PROJ=<isolated project dir>
NTK_PKGDIR=<installed package source root>
NTK_VERSION=<version>
```

`run_*` and `verify_*` parse those (or take them from the environment). Requires
Julia >= 1.7. The first install precompiles ~400 dependencies (it pulls a
plotting stack), several minutes; the fast path re-probes an existing install in
about 15 seconds (Julia startup dominates).

## Command line

```bash
bash scripts/install_nucleartoolkit.sh                 # provision, print NTK_* vars
bash scripts/run_nucleartoolkit.sh [nucleus] [interaction] [n_eigen]   # shell model (default Be8 ckpot 10)
bash scripts/verify_nucleartoolkit.sh                  # tier-1 benchmark (CKpot anchor + full Pkg.test); NTK_FAST=1 for L1 only
bash scripts/selftest_nucleartoolkit.sh                # harness guards (17 cases, stubbed, no package needed)
```

`run` examples: `Be8 ckpot 10` (p-shell, the benchmark case), `Li6 ckpot 3`,
`O18 usdb 5` (sd-shell), `Ne20 usdb 5`.

## Ab initio pipeline

The headline capability is the chiral-EFT -> IMSRG chain, exercised end to end by
`verify_*` (the full `Pkg.test`). To author it yourself: `make_chiEFT()` builds
the interaction, `hf_main(nucs, sntf, hw, emax; doIMSRG=true, ...)` runs HFMBPT
and the IMSRG (add `valencespace=...` for VS-IMSRG to emit an effective
interaction), and `main_sm(sntf, nuc, n_eigen, Js)` diagonalizes the shell model
with that interaction. Field-by-field construction is in
`references/input-format.md`; outputs (energies, .snt effective interactions,
observables) in `references/output-format.md`.

## Benchmark

Tier, anchors, and what is and is not claimed are in `references/verification.md`.
Headline: the CKpot Be-8 spectrum reproduces the shipped reference to |dE| < 1e-3
(g.s. -31.1194 vs -31.119), and `Pkg.test` is 30/30 including the ab initio He-4
IMSRG ground state to 1e-6.
