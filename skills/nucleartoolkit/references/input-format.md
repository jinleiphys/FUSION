# NuclearToolkit.jl input authoring

NuclearToolkit.jl is a Julia library: a calculation is a short Julia script that
calls the package functions. There are two workflows.

## Workflow A: shell model with a shipped interaction (self-contained)

The fast, self-contained path. `main_sm` diagonalizes the valence-space shell
model for a nucleus given an interaction file:

```julia
using NuclearToolkit
E = main_sm(sntf, nuc, n_eigen, Js; q=2, is_block=true)
```

- `sntf`   path to a `.snt` interaction file. Shipped ones live under the package
  `test/interaction_file/`: `ckpot.snt` (Cohen-Kurath, p-shell), `usdb.snt`
  (USDB, sd-shell). `run_nucleartoolkit.sh` resolves these from `NTK_PKGDIR`.
- `nuc`    nucleus name string, e.g. `"Be8"`, `"Li6"`, `"O18"`, `"Ne20"`.
- `n_eigen` number of lowest eigenstates to return.
- `Js`     target 2*J values as an `Int[]` (empty for all J; `[0]` for 0+ only).
- `q=2, is_block=true` select the block-Lanczos solver (the benchmark settings).

Useful keywords (from the shipped tests): `truncation_scheme="jocc"` with
`truncated_jocc=Dict(...)` for occupation-number truncation; `calc_moment=true`,
`calc_entropy=true`, `save_wav=true`. Transitions: `transit_main(sntf, nuc, jl2,
jr2, wfs; calc_EM=true)`. Electron capture: `prepEC(...)` / `solveEC(...)`.

## Workflow B: ab initio to shell model (chiral EFT -> IMSRG -> shell model)

The headline pipeline (the distribution's `example/sample_script.jl`):

```julia
using NuclearToolkit

# 1. Generate a chiral-EFT interaction (settings from optional_parameters.jl).
make_chiEFT()

# 2. HFMBPT and IMSRG. hw = oscillator frequency, emax = model-space cutoff.
#    doIMSRG=true runs the flow; add valencespace to emit a VS effective interaction.
hf_main(["O16"], sntf, 20, 4; doIMSRG=true, Operators=["Rp2"],
        corenuc="O16", ref="nuc", valencespace="sd-shell")

# 3. Shell model with the IMSRG-derived effective interaction.
main_sm(effective_sntf, "Mg24", 10, Int[])
```

- `make_chiEFT()` reads its parameters from a `parameters/optional_parameters.jl`
  file in the working directory (emax, hw, chiral order, SRG lambda, mesh). The
  shipped tests generate, e.g., `tbme_em500n3lo_barehw20emax2.snt.bin`.
- `hf_main(nucs, sntf, hw, emax; kwargs)` returns the HF/MBPT/IMSRG object when
  `return_obj=true`; `HFobj.E0`, `.EMP2`, `.EMP3` are the HF and MBPT energies,
  `IMSRGobj.H.zerobody[1]` the IMSRG ground-state energy,
  `IMSRGobj.ExpectationValues["Rp2"]` the operators requested via `Operators`.
- `emax` controls cost sharply: emax=2 (He-4) is seconds, emax=4 (O-16/Mg-24) is
  minutes, higher emax grows fast. Use `julia -t N` for N threads.

## The .snt / .snt.bin interaction format

`.snt` is a text single-particle + two-body matrix-element file (the same family
KSHELL uses); `.snt.bin` is its binary form. `make_chiEFT` and the VS-IMSRG write
these; `main_sm` reads them. A VS-IMSRG run produces the effective interaction for
a chosen core and valence space, which then feeds `main_sm`.

## What changes the result vs the cost

- Result: the interaction (shipped vs chiral-EFT-generated, and its chiral order /
  SRG lambda), the nucleus and valence space, `hw`, `emax`, `doIMSRG`,
  `valencespace`, the operators requested.
- Cost only: threads (`julia -t N`), the Lanczos block size `q`, `is_block`,
  the IMSRG flow step. These do not change the converged numbers.

Isolation note: always run through the skill's env (`JULIA_DEPOT_PATH` + project
from `install_nucleartoolkit.sh`) so the pinned version is used and the user's
global Julia environment is untouched.
