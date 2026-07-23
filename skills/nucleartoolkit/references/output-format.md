# NuclearToolkit.jl output

Outputs are Julia return values plus a few written files. The skill parses the
return values (printed by the run/verify wrappers); the files are for a user's own
analysis.

## Shell model (`main_sm`)

Returns the vector of the lowest eigenvalues (MeV), lowest first:

```
E = main_sm("ckpot.snt", "Be8", 10, Int[]; q=2, is_block=true)
# E[1] = -31.1194 (ground state), E[2] = -27.2997, ...
```

`run_nucleartoolkit.sh` prints them as `EIGEN <i> <energy>` lines and reports the
spectrum. The console also shows a per-state table (energy, excitation energy,
and, when requested, J, moments, occupations). With `save_wav=true` the wave
functions are written to `.wav` files; `transit_main` and the EC routines write
transition-density and matrix files used by follow-up calls.

Energies are absolute in the valence space (relative to the interaction's core
with its single-particle energies), in MeV; excitation energies are E_i - E_1.

## HFMBPT / IMSRG (`hf_main`)

With `return_obj=true`, returns an object whose fields are the observables:

| field | meaning |
|---|---|
| `HFobj.E0` | Hartree-Fock ground-state energy (MeV) |
| `HFobj.EMP2`, `.EMP3` | 2nd/3rd-order MBPT corrections (MeV) |
| `IMSRGobj.H.zerobody[1]` | IMSRG ground-state energy (MeV) |
| `IMSRGobj.ExpectationValues["Rp2"]` | requested operator expectation (e.g. Rp^2, fm^2) |

A VS-IMSRG run (`valencespace=...`) additionally writes a `.snt` effective
interaction for the chosen core/valence space, which is the input to a subsequent
`main_sm` shell-model calculation. This chaining (ab initio interaction ->
shell-model spectrum) is the package's signature workflow.

## Chiral EFT (`make_chiEFT`)

Writes the generated interaction as `.snt` / `.snt.bin` files in the working
directory (names encode the interaction, hw and emax, e.g.
`tbme_em500n3lo_barehw20emax2.snt.bin`). These are read by `hf_main`.

## Units and conventions

- Energies in MeV, radii in fm, `hw` in MeV, lengths of the model space set by
  `emax` (max 2n+l). Molar/occupation quantities are dimensionless.
- Shell-model energies are in the valence space (core-subtracted); ab initio
  IMSRG energies are total binding-like ground-state energies for the light
  nuclei at the given interaction and model space.

## Plotting

The package pulls a plotting stack (Makie/Plots) for its own figures (level
schemes, flows). That is why the first install precompiles ~400 packages. The
skill does not drive plotting; use the returned arrays or the written files.
