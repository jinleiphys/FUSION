---
name: vhlle
description: >-
  Drive vHLLE, the 3+1D relativistic viscous hydrodynamic code of Iu. Karpenko, P. Huovinen and M. Bleicher (Comput. Phys. Commun. 185, 3016 (2014)). Evolve the second-order (Israel-Stewart) shear+bulk viscous hydrodynamics of the quark-gluon plasma from an initial state (optical Glauber, Gubser, Glissando, Trento, SMASH, UrQMD) to a particlization surface, with a choice of lattice or conformal equation of state. Build from source, run the shipped decks, and reproduce the analytic Gubser-flow test plus a production optical-Glauber run. Use for 跑vHLLE, 相对论流体力学, viscous hydrodynamics, relativistic hydro, heavy-ion collisions, quark-gluon plasma, QGP, Israel-Stewart, shear viscosity, bulk viscosity, eta/s, Gubser flow, Bjorken flow, elliptic flow, initial state, particlization, freeze-out surface, Cornelius, hydro evolution, CDCC 无关 hydrodynamics.
---

# Driving vHLLE

vHLLE solves 3+1D relativistic dissipative (second-order Israel-Stewart)
hydrodynamics on a Cartesian Milne (tau, x, y, eta) grid with the Kurganov-Tadmor
scheme. Given an initial energy-momentum profile, transport coefficients
(eta/s, zeta/s) and an equation of state, it evolves the fluid and locates the
constant-energy-density particlization hypersurface. It is a standard bulk-
evolution stage for modelling the quark-gluon plasma in heavy-ion collisions.

C++, a plain `make`, GSL, C++17. The EoS tables and sample initial states live in
the official companion repo `vhlle_params`.

## Prime rules (do not skip)

1. **The equation of state is a COMPILE-TIME switch** (`src/eos.cpp`:
   `#define TABLE` vs `SIMPLE`). The production build is TABLE (Laine lattice
   EoS); the analytic Gubser test needs SIMPLE (conformal p=e/3). This skill
   builds both, `hlle_visc_table` and `hlle_visc_simple`, from the same pinned
   source. Toggling the EoS changes only those two `#define` lines (the code's own
   documented switch) and the tree is restored pristine; it is NOT a modification
   of functional code.
2. **Run vHLLE from the repository root.** It opens `eos/` and `ic/` relative to
   the current directory. `run_vhlle.sh` handles this.
3. **A Gubser run on a thin eta grid stops after one timestep.** The surface
   finder returns zero elements and the loop breaks. The shipped Gubser deck uses
   `nz 15` for that reason (see `references/failure-modes.md`).
4. **`outdiag.dat` is not rectangular** (each record wraps 8 + 12 across two
   lines). Use `outx/outy/outz.dat`.
5. **Tier 2 with an analytic physics benchmark.** vHLLE ships no reference output,
   so the anchors are (a) the code-independent analytic Gubser solution and (b)
   bit-identical cross-platform reproduction. Do not claim it reproduces a
   distributed reference; it does not ship one.
6. **No em-dashes** in any prose you write (user's flat rule).

## Environment (auto-install)

`scripts/install_vhlle.sh` clones and pins vHLLE (main @ `c3480d62`) and
`vhlle_params` (@ `ae2ba98`), links `eos/` and `ic/`, builds ONE binary, and
prints:

```
VHLLE=<hlle_visc_table or hlle_visc_simple>
VHLLE_ROOT=<vhlle repo root; run from here>
VHLLE_PARAMS=<vhlle_params root>
VHLLE_BUILD=<same as VHLLE_ROOT; vHLLE builds in-tree>
VHLLE_EOS=<table|simple>
```

`VHLLE_EOS=table` (default) builds the Laine-EoS production binary; `simple`
builds the conformal-EoS Gubser binary. Needs `git`, `make`, a C++17 compiler and
GSL. GSL is auto-detected on PATH, else under `VHLLE_GSL_PREFIX`, else a conda env
(`conda install -c conda-forge gsl` if missing; `brew install gsl` on macOS). The
Linux binary is linked with an rpath to the GSL lib so it runs without
`LD_LIBRARY_PATH`. Overrides: `VHLLE_ROOT_DIR`, `VHLLE_PIN`, `VHLLE_PARAMS_PIN`,
`VHLLE_JOBS`, `VHLLE_FORCE_BUILD`.

## Running

```bash
scripts/run_vhlle.sh --params examples/gubser.params  --eos simple --outdir /tmp/gub
scripts/run_vhlle.sh --params examples/glauber.params --eos table  --outdir /tmp/gla
```

It resolves (or builds) the right binary, runs from the repo root, asserts a zero
exit, validates the rectangular `outx/outy/outz.dat` (finite, consistent columns),
and prints `RESULT_DIR=` / `RESULT_FILES=`. `--is-input FILE` and `--system SYS`
pass through vHLLE's `-ISinput` / `-system` for tabulated initial states.

## Verifying

```bash
scripts/verify_vhlle.sh                 # Gubser analytic + Glauber production, ~1.5 min
scripts/verify_vhlle.sh --gubser-only   # analytic Gubser physics check only
scripts/verify_vhlle.sh --glauber-only  # production-path regression only
scripts/selftest_vhlle.sh               # harness only, 32 cases, no build, seconds
```

STAGE 1 builds the SIMPLE binary and compares the Gubser run cell by cell against
the analytic ideal-conformal solution at tau=1.5 (eps within tolerance, exact
left-right symmetry, pinned central energy density). STAGE 2 builds the TABLE
binary and runs an optical-Glauber viscous deck to tau=3.05, checking finiteness
and a pinned central anchor.

A `VERIFY OK` requires verify to BUILD both binaries from the SHA-pinned pristine
source in the run (it force re-clones and makes them), so they cannot be a forged
drop-in. Presetting `VHLLE_TABLE_BIN`/`VHLLE_SIMPLE_BIN` validates handed-in
binaries but ends in `VERIFY PASSED-NOT-CERTIFIED`.

## Writing an input

`references/input-format.md`: the parameter-file keys, the EoS compile-time
switch, and the command-line options. The two shipped decks (Gubser, optical
Glauber) are self-contained; the other initial states need an `-ISinput` table
from `vhlle_params`.

## Reading the output

`references/output-format.md`: the 20-column `outx/outy/outz.dat` profile tables,
the two-line-wrapped `outdiag.dat`, `out.aniz.dat`, and the console scalars.

## Benchmark

| stage | what | result |
|---|---|---|
| Gubser (physics) | analytic ideal-conformal Gubser flow, tau=1.5, \|x\|<=5 | eps max reldiff 0.0247 / rms 0.0092 vs analytic; vx max 0.0127; exact symmetry; central eps 0.157676 |
| Glauber (production) | optical-Glauber viscous run to tau=3.05 | central eps 3.211810, T 0.213454 GeV; finite; identical both platforms |
| cross-platform | macOS/ARM clang 21 vs Linux/x86-64 gcc 13.3 | Gubser physical columns bit-identical; Glauber central identical to 6 sig figs |

Tier 2 with an analytic physics benchmark: the Gubser check is a code-independent
analytic reference, stronger than a build-only check, and the production path is
pinned by cross-platform reproduction. The third of the heavy-ion row after SMASH
and GiBUU, and the relativistic viscous-hydro branch of that row. Evidence and
what the adversarial pass found: `references/verification.md`.

## Failure modes

`references/failure-modes.md`, ten of them, starting with the one-step Gubser
stop on a thin eta grid and the unconditional read of `eos/eosHadronLog.dat`.
