# SMASH output

Everything goes into the directory given with `-o`, which SMASH creates. It also
copies the configuration it actually used into that directory, so a run records
its own input.

## Files

| file | when | content |
|---|---|---|
| `particle_lists.oscar` | `Output: Particles: Format: ["Oscar2013"]` | the particle list, the main result |
| `collisions_custom.bin` | `Collisions:` with `Binary` format | every interaction, for reaction-by-reaction analysis |
| `collisions_oscar2013.bin` | `Collisions:` with `Oscar2013_bin` | the same, in binary OSCAR |
| `config.yaml` | always | the configuration as SMASH parsed it |
| `thermodynamics.dat`, `*.vtk` | on request | densities and fields on a grid |

The accepted `Format:` values, from the validation in
`src/include/smash/experiment.h`, are `Oscar1999`, `Oscar2013`, `Oscar2013_bin`,
`Binary`, `Root`, `VTK`, `ASCII`, `HepMC`, `HepMC_asciiv3`, `HepMC_treeroot`,
`YODA`, `YODA-full` and `For_vHLLE`. Not every content accepts every format, and
several (`Root`, the `HepMC` family, `YODA`) require SMASH to have been built
against an optional dependency; without it SMASH aborts at startup naming the
format. Only `Oscar2013` particle lists are structurally validated by this
skill. A run that requests any of the others is still accepted by
`run_smash.sh`, which then says plainly that its output was NOT validated
rather than failing for a missing `particle_lists.oscar`.

SMASH logs to stdout; there is no configurable log FILE. `run_smash.sh` captures
that stream as `smash.log`, alongside `stderr.txt`, `config_used.yaml`,
`structure.txt` (the structural verdict) and, when a shipped example carries its
own tables, `particles_used.txt` and `decaymodes_used.txt`.

## OSCAR2013 particle lists

```
#!OSCAR2013 particle_lists t x y z mass p0 px py pz pdg ID charge
# Units: fm fm fm fm GeV GeV GeV GeV GeV none none e
# SMASH-3.3
# event 0 ensemble 0 out 497
      20.0   1.23  -4.56   7.89  0.938   1.02   0.11  -0.05   0.30  2212   17   1
...
# event 0 ensemble 0 end 0 impact   0.000 scattering_projectile_target yes
```

Twelve columns, in the order named on the first line: time, three positions,
mass, four-momentum, PDG code, particle ID within the event, and electric charge
in units of e. **The header line is the authority on the column order**, since it
changes with the output content requested; parse it rather than assuming.

### The block grammar, in full

There are exactly three marker shapes, from `at_eventstart`,
`at_intermediate_time` and `at_eventend` in `src/oscaroutput.cc`:

```
# event N ensemble E in  COUNT      once, at the start of an event
# event N ensemble E out COUNT      at each Output_Interval, and at the event end
# event N ensemble E end 0 impact X scattering_projectile_target yes|no
```

Each `in` and `out` line DECLARES how many records follow, and those records are
a COMPLETE list of the particles present at that moment, not an interaction.
Which markers appear is decided by `Output: Particles: Only_Final`:

| `Only_Final` | blocks per event |
|---|---|
| `Yes` (the shipped default) | one `out`, then `end` |
| `IfNotEmpty` | one `out` if the event was not empty, **or none at all**, then `end` |
| `No` | one `in`, one `out` per `Output_Interval`, a final `out`, then `end` |

Three consequences that are easy to get wrong, and were:

- **`out` and `end` do not pair one-to-one.** Under `Only_Final: No` a single
  event holds one `in` and several `out` blocks; under `IfNotEmpty` an event can
  hold none. Only the `end` markers count events.
- **An event is `(event, ensemble)`, not `event`.** With `Ensembles: K` each
  parallel ensemble is an independent system with its own initialisation and its
  own `end` marker, so a configuration with `Nevents: 1, Ensembles: 20` completes
  **20** systems, not one. Matching only `# event N out` misses the output
  entirely.
- **Every block must balance on its own.** Baryon number and charge are the same
  in the `in` block, in each intermediate `out` and at the end, even though the
  particle COUNT grows as resonances decay. Checking only the last block would
  miss a violation that appears and heals between intervals.

`scripts/check_conservation_smash.py` is the single implementation of this
grammar; `run_smash.sh` calls it with `--structure-only` rather than re-parsing
the output in shell, because two copies of a grammar drift apart.

Under `Only_Final: No` the same particle appears in many blocks, so
multiplicities must be taken from the final block only.

## What is reproducible, and what is not

SMASH is Monte Carlo. Three statements, kept apart on purpose:

1. **With a pinned `Randomseed`, the output is bit-reproducible on one build.**
   Measured: two runs of the same seeded Au+Au configuration produced a
   byte-identical `particle_lists.oscar`.
2. **Across builds it is not**, and should not be expected to be. Different
   compilers, libm implementations and Pythia builds reorder floating-point
   operations, and a transport code amplifies that into different collision
   histories.
3. **Conservation laws hold exactly regardless.** Baryon number and electric
   charge are integers fixed by the initial nuclei, so they are the same on
   every platform and for every seed. That is why the skill anchors on them
   rather than on multiplicities: see `scripts/check_conservation_smash.py`.

A consequence worth internalizing: a multiplicity from a 2-event run is not a
benchmark of anything. If you want a physics number to compare, run enough
events that the statistical error is smaller than the effect you care about, and
quote that error.

## Reading a run quickly

```bash
# number of events actually completed (an 'end' per (event, ensemble) pair)
grep -cE '^# event [0-9]+ ensemble [0-9]+ end' particle_lists.oscar

# final-state multiplicities by species. Correct ONLY for Only_Final: Yes;
# with Only_Final: No this sums every intermediate block as well.
awk '!/^#/ {print $10}' particle_lists.oscar | sort -n | uniq -c | sort -rn | head

# structural check plus the conservation laws, without hand-parsing anything
scripts/check_conservation_smash.py particle_lists.oscar --structure-only
```

PDG codes you will meet immediately: 2212 proton, 2112 neutron, 211/-211/111
charged and neutral pions, 321/-321/311 kaons, 3122 Lambda, 221 eta.
