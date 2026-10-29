# YAHFC output reference

Layouts as written by the pinned commit 18af2fe, read from real runs (n+90Zr,
n+235U) and the manual's "Data Libraries" section. All numbers are in MeV and
barns unless `cs_units mb`.

## Run directory

| file | content |
|---|---|
| `yahfc.stdout` | stdout (name given by `run_yahfc.sh`). **Contains NUL bytes: use `grep -a`.** Per energy: `Incident energy =`, `Center-of-momentum E =`, `Reaction cross section =`, then for incident neutrons `Total cross section =`, `Total Reaction cross section =`, `Compound cross section =`, `Direct excitation cross section =`, `Shape Elastic cross section =`, a table of events per channel, and the accounting check (`Check_sum`, `All events are accounted for`). At the end: the energy-conservation line and `That's all Folks`. |
| `yahfc.stderr` | harmless `mkdir: ... File exists` and `rm: ... No such file or directory` from YAHFC's shell calls; anything else is an error. |
| `<file>.out` | calculation log (`write_outfile y`): models, parameters, per-nucleus data. Several MB. |
| `YAHFC-commands.txt` | first line `#YAHFC commands in order of execution`, then the default seed information, then the executed commands in YAHFC's order (an explicit `ran_seed` among them; `run_yahfc.sh` checks it). |
| `<proj><target>.tcoef` | transmission coefficients, one per particle and residual (`nZr90.tcoef`, `pY90.tcoef`). Computed by Frescox, unless a `.tcoef` and its `-CC.data` were both staged (see `input-format.md`). |
| `<proj><target>-CC.data` | coupled-channels data written or staged. |
| `Fresco-files/` | the Frescox decks and outputs, one per energy point (`nZr90-ie_0103.in/.out`). |
| `<A><Sym>-CLD-exp.dat`, `-CLD-modeled.dat` | cumulative level distributions, experimental and model, for every nucleus in the calculation. |
| `provenance.txt` | written by `run_yahfc.sh`: deck hash, commit, seed, staged files with hashes, which `.tcoef` were staged and which computed. |

## Library tree

`<A><Sym>/<proj>/` (for example `90Zr/n/`, `235U/n/`), refreshed at each run
unless `clean_library n`.

Top level:

| file | columns |
|---|---|
| `Total_cs.dat` | E_in, sigma_tot (neutrons only) |
| `Reaction_cs.dat` | E_in, sigma_R |
| `Absorption_cs.dat` | E_in, absorption cross section (equal to sigma_R in the L1 run) |
| `Direct_cs.dat` | E_in, direct components |
| `Preequilibrium_cs.dat` | E_in, pre-equilibrium cross section |
| `Particle-properties.dat`, `<A><Sym>-decay-properties.dat` | masses, separation energies, decay data |
| `Spectra/` | per energy: `<proj>+<target>_Ein_<E>-Preeq-Spectrum.dat`, `-xParticle-Spectrum.dat` |
| `Primary-decay/` | first-step cross sections (`primary_decay y`) |

One directory per channel, named by the emitted particles (`g`, `n`, `2n`, `p`,
`np`, `2p`, `f`, ...; with `explicit_channels y`, ordered: `nn`, `np`, `pn`).
In a channel directory `c`:

| file | content |
|---|---|
| `Channel_c_cs_Tot.dat` | E_in, sigma_c, then mean multiplicities of g, n, p, d, t, h, a |
| `Channel_c_cs_LXXX.dat` | E_in, sigma for decays ending in level XXX of the residual (000 = ground state, others = isomers) |
| `Channel_c_Eout_G_Ein_LXXX.dat` | per E_in block (`# E_in = ... Cross Section = ...`): E_in, E_out, P(E_out, particle given E_in) for g n p d t h a; normalised to 1 over E_out; COM frame |
| `Channel_c_Ang_G_Ein_LXXX.dat` | E_in, x = cos(theta), P(x given E_in) |
| `Channel_c_Eout_Ang_G_Ein_LXXX.dat`, `..._Leg_...` | joint E_out, angle densities; angle as Legendre coefficients in the `Leg` file |
| `Channel_c_fission_cs.dat` | fission following emission in this channel (fissioning systems) |

The inelastic directory (`n` for incident neutrons) also holds:

| file | content |
|---|---|
| `Shape_Elastic_cs.dat`, `Shape_Elastic_Ang.dat`, `..._Leg.dat` | shape elastic: cross section, angular density per E_in (header carries the cross section) |
| `Compound_Elastic_cs.dat`, `_Ang`, `_Ang_Leg` | compound elastic |
| `Elastic_cs.dat`, `Elastic_Ang.dat`, `_Leg` | shape plus compound |
| `Inelastic_cs_Total.dat` | all inelastic |
| `Inelastic_cs_LXXX.dat`, `Inelastic_Ang_LXXX.dat` | manual: primary emission straight to discrete level XXX of the target (from L001), direct and pre-equilibrium included. None were written in the L1 n+90Zr run. |
| `Channel_n_cs_entry_to_LXXX.dat` | inelastic cascades entering the discrete spectrum at level XXX |
| `Channel_n_cs_Tot.dat` | manual: inelastic not reaching a discrete level by direct primary emission. Smaller than `Inelastic_cs_Total` (below). |

The fission directory `f` holds `fission_cs.dat` (E_in, sigma_f) and
`Fission-Stats.dat`. sigma_f is not printed on stdout.

## Checked identities

From the n+90Zr L1 run (both energies, to the printed 8 digits):

- sigma_tot = sigma_R + sigma_shape-el (YAHFC computes sigma_tot as that sum).
- sigma_R = compound elastic + `Inelastic_cs_Total` + sum of `Channel_c_cs_Tot`
  over the non-inelastic channels (agreement 3e-8). For a fissioning target add
  sigma_f. `verify_yahfc.sh` checks this from the library files, which is the
  quickest way to catch a parser reading the wrong column or file.
- `Channel_n_cs_Tot` is smaller than `Inelastic_cs_Total` (0.90971 vs 0.92753
  b at 13.92 MeV), and only `Inelastic_cs_Total` closes the flux sum, so use it
  for (n,n'). The manual says the channel file plus the `entry_to` files equal
  `Channel_n_cs_Tot`; in this run they do not (0.90971 + 0.85387 vs 0.90971),
  so the `entry_to` files are a different view of the same flux (where cascades
  enter the discrete spectrum), not an additive piece. Do not sum them with the
  channel files.

## Events

With `dump_events y a` (or `event_generator y`), every event is written with a
header (event number, number of particles, incident energy, initial kinetic
energy, Monte Carlo weight) and 25 numbers per particle (initial and final
states, kinematics in the rest, COM and lab frames). With MPI there is one file
per process. Weights are not unity under the default sampling (see
`biased_sampling` in `input-format.md`).
