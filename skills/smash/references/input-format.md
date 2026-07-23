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

`Format` values are content-specific and case-sensitive, and the spelling is not
what you would guess: it is `Root`, not `ROOT`. Depending on the output block,
SMASH accepts `Oscar2013`, `Oscar2013_bin`, `Oscar1999`, `Binary`, `Root`,
`VTK`, `ASCII`, **`HepMC`**, `HepMC_asciiv3`, `HepMC_treeroot`, **`YODA`**,
**`YODA-full`**, `For_vHLLE`, `Lattice_ASCII` and `Lattice_Binary`; the ROOT,
HepMC and Rivet/YODA ones exist only if those optional libraries were found at
configure time, and SMASH aborts at startup naming the format when they were
not. The bare `HepMC`, `YODA` and `YODA-full` spellings were missing from this
list until the round-3 audit; the authority is the validation in
`src/include/smash/experiment.h`, and the per-block list is in
`src/include/smash/input_keys.h`. Do not assume one global set.

`Only_Final: Yes` writes just the final state, which is what you want unless you
are studying the time evolution. The three values (`Yes`, `IfNotEmpty`, `No`)
change the BLOCK STRUCTURE of the file, not only its size: see
`output-format.md`.

## Configurations that do not run from their own directory

`run_smash.sh` runs SMASH from the configuration's directory, so that a Modus
resolving paths relative to the config finds them. The shipped `List` example
assumes a different cwd: `input/list/config.yaml` sets
`File_Directory: "../input/list"`, which resolves only from the BUILD directory,
so running it in place fails with `External particle list does not exist`. Pass
the cwd it expects:

```bash
scripts/run_smash.sh --config "$SMASH_ROOT/input/list/config.yaml" \
  --seed 1 --end-time 10.0 --workdir "$SMASH_ROOT/build"
```

This is a property of that configuration, not a defect in SMASH: a relative
`File_Directory` is resolved against the working directory, so it only ever
worked from one place.

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
built-in tables, and SMASH does NOT pick them up implicitly: they must be passed
with `-p` and `-d` or the run silently uses the defaults.

Which examples actually ship them, checked in the SMASH-3.3 tree rather than
assumed:

| example | ships |
|---|---|
| `input/box/` | `particles.txt`, `decaymodes.txt` |
| `input/multi_particle_box/` | `particles.txt`, `decaymodes.txt` |
| `input/photons/` | `particles.txt`, `decaymodes.txt` |
| `input/dileptons/` | `decaymodes.txt` only |
| `input/stochastic_box/` | `particles_only_pi0.txt`, `decaymodes_all_off.txt` |
| `input/sphere/` | **nothing**: config.yaml only |
| `input/` itself | `particles.txt`, `decaymodes.txt`, **and these ARE the built-in defaults** |

That last row matters for the shipped collider config, which lives in `input/`:
auto-staging passes `-p input/particles.txt -d input/decaymodes.txt`, and that
changes nothing, because `src/CMakeLists.txt` calls
`generate_headers(particles.txt decaymodes.txt)` on exactly those two files to
compile the default tables into the binary. Passing them explicitly is the same
physics, not a silent override.

`run_smash.sh` auto-stages by exact filename, so it covers the first four rows
and does nothing for `sphere`, which needs nothing. **`stochastic_box` is the
trap**: its tables are real but differently named, so auto-staging misses them
and the run quietly uses the defaults. Pass them explicitly:

```bash
scripts/run_smash.sh --config .../input/stochastic_box/config.yaml --seed 1 \
  --particles  .../input/stochastic_box/particles_only_pi0.txt \
  --decaymodes .../input/stochastic_box/decaymodes_all_off.txt
```
