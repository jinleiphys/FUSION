# SMASH input format

SMASH reads one YAML configuration, given with `-i`, and writes into the
directory given with `-o`. Everything below comes from the source
(`src/experiment.cc`, `src/include/smash/input_keys.h`, which is the
authoritative key list) and from the configurations the distribution ships in
`input/`, not from memory.

```
smash -i config.yaml -o output_dir
```

## The five modi

`General: Modus:` selects the physics setup, and `src/experiment.cc` accepts
exactly five values; anything else throws `InvalidModusRequest`:

| Modus | what it is | shipped example |
|---|---|---|
| `Collider` | two nuclei at an impact parameter, the heavy-ion case | `input/config.yaml` |
| `Box` | a periodic box of thermal matter, for equilibration studies | `input/box/config.yaml` |
| `Sphere` | an expanding thermalized sphere | `input/sphere/config.yaml` |
| `List` | replay externally supplied particles | `input/list/config.yaml` |
| `ListBox` | as `List`, but with box boundaries | |

Each modus reads its own sub-block under `Modi:`, and only that one.

## `General`

```yaml
General:
    Modus:          Collider
    Time_Step_Mode: Fixed
    Delta_Time:     0.1        # fm/c
    End_Time:       200.0      # fm/c
    Randomseed:     -1
    Nevents:        1
```

**`Randomseed: -1` means "draw a fresh seed from the system"**, which is what
every shipped config carries. A run made with it cannot be reproduced, compared
with a reference, or compared with itself. Pin an integer seed for anything you
intend to check. `run_smash.sh` refuses `-1` unless you pass
`--allow-random-seed`, precisely because the default is the irreproducible one.

`End_Time` dominates the run time: the shipped collider config uses 200 fm/c,
while 20 fm/c is enough for a smoke test and runs in about 25 s for 2 events.

## `Modi: Collider`

```yaml
Modi:
    Collider:
        Projectile:
            Particles: {2212: 79, 2112: 118}   # 79 protons, 118 neutrons = Au197
        Target:
            Particles: {2212: 79, 2112: 118}
        E_Kin: 1.23                            # GeV per nucleon, beam kinetic energy
        Fermi_Motion: "frozen"
```

Nuclei are given as PDG-code counts, not as a name and mass number: `2212` is the
proton and `2112` the neutron. This is worth stating because it is also what
makes the conservation check possible, since the expected baryon number and
charge follow directly from these counts (see `verification.md`).

The beam energy can be given as `E_Kin` (kinetic energy per nucleon in the
target frame), `E_Tot`, `P_Lab` or `Sqrtsnn`; give exactly one.

## `Output`

```yaml
Output:
    Output_Interval: 10.0
    Particles:
        Format: ["Oscar2013"]
        Only_Final: No
```

`Format` chooses among `Oscar2013`, `Oscar1999`, `Binary`, `ROOT`, `VTK` and
`HepMC` (the last two need optional libraries found at configure time).
`Only_Final: Yes` writes just the final state, which is what you want unless you
are studying the time evolution. Content of the file: see `output-format.md`.

## `Collision_Term`

```yaml
Collision_Term:
    Collision_Criterion: "Covariant"
```

The main physics switch. Others in the shipped examples include `Strings`,
`Two_to_One`, `Included_2to2`, `Multi_Particle_Reactions` and the potentials
block; `input/potentials/config.yaml` is the worked example for mean-field
potentials.

## Overriding keys from the command line

SMASH accepts `-c "Key: value"` to override configuration entries, and
`run_smash.sh` instead rewrites the copied YAML so the output directory keeps a
`config_used.yaml` recording exactly what ran. Prefer that: a run whose input you
cannot reconstruct is not a measurement.

## Particle and decay data

`particles.txt` and `decaymodes.txt` next to a configuration override the
built-in tables. The box and sphere examples ship their own copies, which is why
their multiplicities differ from a collider run using the defaults.
