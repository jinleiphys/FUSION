# Thermal-FIST examples

No input decks are stored here. Thermal-FIST ships its own example programs and
reference outputs, and this skill drives those in place rather than copying them,
so there is nothing to fork out of sync.

## The shipped cpc programs (the CPC 244, 295 figures)

After `install_thermalfist.sh`, the binaries live in `$TFIST_EXAMPLES`
(`build/bin/examples/`). Each writes its table into the current directory.

Do NOT `eval` the installer output: its lines are `KEY=value` with filesystem
paths that can contain spaces or shell metacharacters (the cache root is
user-settable via `TFIST_ROOT_DIR`), and `eval` would execute them. Extract the
one variable you need instead:

```bash
INSTALL_OUT="$(scripts/install_thermalfist.sh)"
TFIST_EXAMPLES="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^TFIST_EXAMPLES=//p')"
TFIST_ROOT="$(printf '%s\n' "$INSTALL_OUT" | sed -n 's/^TFIST_ROOT=//p')"
export TFIST_EXAMPLES TFIST_ROOT

# cpc1: HRG thermodynamics vs temperature at mu = 0, three model variants
scripts/run_thermalfist.sh --example cpc1 --config 0 --outdir /tmp/idHRG    # ideal
scripts/run_thermalfist.sh --example cpc1 --config 1 --outdir /tmp/evHRG    # excluded volume
scripts/run_thermalfist.sh --example cpc1 --config 2 --outdir /tmp/vdwHRG   # van der Waals

# cpc2: chi^2 of the ALICE 2.76 TeV thermal fit vs T
scripts/run_thermalfist.sh --example cpc2 --config 0 --outdir /tmp/cpc2

# cpc3: equilibrium (0) vs chemically-frozen (1) freeze-out fit
scripts/run_thermalfist.sh --example cpc3 --config 0 --outdir /tmp/cpc3
```

## The reference outputs

The shipped `test/ReferenceOutput/` under `$TFIST_ROOT` holds the expected output
of every cpc/EoS example. `verify_thermalfist.sh` reproduces them through the
code's own ctest suite (serial). The fast anchor pins one row of
`cpc1.Id-HRG.TDep.out`:

```
T = 150 MeV, ideal HRG, mu = 0:  p/T^4 = 0.647513,  e/T^4 = 3.846843,  s/T^3 = 4.494356
```

## What is NOT wrapped

- `cpc4mcHRG` (Monte Carlo sampler): not reproducible without pinning the event
  count and RNG, so it is exercised only inside the ctest suite, not through
  `run_thermalfist.sh`.
- `example-ThermodynamicsBQS`, `example-SusceptibilitiesBQS`,
  `example-NeutronStars-CSHRG`: these take a multi-argument (muB, muQ, muS) scan
  file and are covered by the ctest suite. Run them directly from `$TFIST_EXAMPLES`
  if you need a custom scan; see their `add_test` lines in `test/CMakeLists.txt`
  for the argument order.
