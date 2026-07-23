# SMASH examples

No configuration is vendored here. `scripts/install_smash.sh` clones SMASH, and
its own `input/` directory holds the worked examples; `$SMASH_ROOT` points at it.

```bash
out="$(scripts/install_smash.sh)"
SMASH="$(printf '%s\n' "$out" | sed -n 's/^SMASH=//p')"
SMASH_ROOT="$(printf '%s\n' "$out" | sed -n 's/^SMASH_ROOT=//p')"
export SMASH SMASH_ROOT
```

Parse those lines rather than `eval`ing the output: they are filesystem paths
that the environment can influence.

## 1. Au+Au, the anchor

`$SMASH_ROOT/input/config.yaml` is the shipped collider setup: Au+Au at
E_kin = 1.23 GeV per nucleon, the HADES energy. Shortened to 2 events and
20 fm/c it runs in about 25 s.

```bash
scripts/run_smash.sh --config "$SMASH_ROOT/input/config.yaml" \
  --outdir /tmp/auau --seed 20260723 --nevents 2 --end-time 20.0

python3 scripts/check_conservation_smash.py /tmp/auau/out/particle_lists.oscar \
  --baryons 788 --charge 316
```

788 = 2 events x 2 nuclei x 197 nucleons, 316 = 2 x 2 x 79 protons. Both must be
exact. If you change `--nevents` or the nuclei, recompute them; the script will
not guess for you, on purpose.

At the full 200 fm/c the same case takes minutes rather than seconds, and that is
what you want for physics, not for a check.

## 2. Thermal box

`$SMASH_ROOT/input/box/config.yaml` fills a periodic box with thermal
multiplicities at T = 0.15 GeV and lets it equilibrate. This is the setup for
detailed-balance and equilibration studies, and it ships its own `particles.txt`
and `decaymodes.txt`, so its species content differs from a collider run.

Note that the conservation anchor above does NOT transfer: a box created from
thermal multiplicities has whatever baryon number the sampling gave it, so read
it from the first event rather than computing it from a projectile and target.

## 3. The others

`sphere` (expanding thermalized sphere), `potentials` (mean-field potentials),
`dileptons` and `photons` (rare-particle output with their own weighting),
`list` (replay an external particle list, which is how SMASH is used as an
afterburner), `deformed_nucleus` and `custom_nucleus` (initial-state geometry).
Each directory carries the configuration and any auxiliary tables it needs.

## Writing your own

Start from `input/config.yaml`, pin `Randomseed`, and change one thing at a time.
The two mistakes that cost the most time are leaving `Randomseed: -1` in a run
you later want to compare with something, and reading multiplicities from a run
with `Only_Final: No`, where every particle appears once per output interval and
the totals are therefore meaningless unless you select the final block.
