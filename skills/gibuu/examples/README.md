# GiBUU examples

The distribution ships **84 job cards** in `testRun/jobCards/`, and they are the
example set: this skill deliberately does not copy them here, because they are
version-matched to the release the installer pins and a stale copy would drift.

List them with:

```bash
eval "$(scripts/install_gibuu.sh | grep '^GIBUU')"
ls "$GIBUU_ROOT/testRun/jobCards/"
```

## Where to start

| card | what it does | cost |
|---|---|---|
| `000_minimal.job` | starts up and prints the particle database, no physics; used as the installer's probe | seconds |
| `002_Pion.job` | pion induced at 50 MeV, the case this skill's regression uses | about 19 s |
| `001_HIC.job` | heavy ion collision | minutes |
| `000_ELE.job` | electron induced | minutes |

Every card needs its `path_To_Input` pointed at the real database and its seed
pinned; `run_gibuu.sh` does both:

```bash
scripts/run_gibuu.sh --jobcard "$GIBUU_ROOT/testRun/jobCards/002_Pion.job" \
  --outdir /tmp/pion --seed 20260723
```

## A caution about statistics

The shipped cards are configured for a quick demonstration, not for a physics
result. `002_Pion.job` runs once, and with one run GiBUU writes sentinel values
(`9999.`) into every error column, so the result carries **no uncertainty at
all**. Raising `num_runs_SameEnergy` to 5 costs about 72 s and still leaves the
individual columns unphysical in isolation (`absorption_xSection` is negative by
construction; see `references/output-format.md`).

Treat any single-run number as a reproducibility probe, never as a cross
section.
