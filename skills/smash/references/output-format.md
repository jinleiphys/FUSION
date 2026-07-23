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


SMASH logs to stdout; there is no configurable log FILE. `run_smash.sh` captures
that stream as `smash.log`, alongside `stderr.txt`, `config_used.yaml` and, when
a shipped example carries its own tables, `particles_used.txt` and
`decaymodes_used.txt`.

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

Events are delimited by `# event N ensemble E out COUNT` and
`# event N ensemble E end 0 impact X scattering_projectile_target yes|no`, the
grammar in `src/oscaroutput.cc`. The `out` line DECLARES how many particles
follow, which is worth checking against the records that actually follow.
Counting matched pairs of those markers is how `run_smash.sh` checks that the run
wrote every event it was asked for instead of stopping early with a zero exit
status. Note the `ensemble` field: matching only `# event N out` misses the real
output entirely.

`Only_Final: No` writes an intermediate list at each `Output_Interval`, so the
same particle appears many times and multiplicities must be taken from the final
block only. `Only_Final: Yes` writes just the end of each event.

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
# final-state multiplicities by species
awk '!/^#/ {print $10}' particle_lists.oscar | sort -n | uniq -c | sort -rn | head

# number of events actually completed
grep -c '^# event .* end' particle_lists.oscar
```

PDG codes you will meet immediately: 2212 proton, 2112 neutron, 211/-211/111
charged and neutral pions, 321/-321/311 kaons, 3122 Lambda, 221 eta.
