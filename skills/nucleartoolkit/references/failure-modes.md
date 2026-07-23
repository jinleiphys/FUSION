# NuclearToolkit.jl failure modes

Notes from building this skill. A Julia package needs no source patches, so the
issues are provisioning, isolation, and result interpretation, not compilation.

## Provisioning and isolation

- **Do not pollute the user's global Julia environment.** A naive `Pkg.add`
  installs into `~/.julia` and can upgrade or conflict with the user's own
  packages. This skill sets a dedicated `JULIA_DEPOT_PATH` and project under
  `~/.cache/fusion/nucleartoolkit` and pins the version, so the user's global
  depot is never touched. Consequence: **every `julia` call in every script must
  set `JULIA_DEPOT_PATH`** (install, run, verify, selftest stub). If one call
  omits it, that call silently uses `~/.julia` and may load a different
  NuclearToolkit version, giving numbers that do not match the pinned benchmark.

- **First install is slow and pulls a plotting stack.** NuclearToolkit depends on
  Makie/CairoMakie/Plots, so a cold `Pkg.add` + `Pkg.precompile` compiles ~400
  packages (a few minutes on a fast machine). This is expected, not a hang. The
  fast path (stamp match + CKpot probe) re-checks an existing install in ~15 s,
  dominated by Julia startup, not real work.

- **Version pin, not "latest".** `install_*` uses `Pkg.add(name=..., version=...)`
  and records the pin in a stamp. The fast path serves the cached build only if
  the stamp matches the requested pin, so bumping the pin forces a reinstall
  rather than silently serving an old version. Reproducibility of the benchmark
  numbers depends on the pin.

## Content is the verdict

- **A Julia run can exit nonzero after a partial calculation, or print a NaN.**
  `run_*` parses the eigenvalues, requires them finite, ascending, and with a
  negative ground state, and treats a nonzero exit with no eigenvalues as a
  failure. `verify_*` L2 parses the `Pkg.test` summary (`NuclearToolkit.jl | pass
  total`) and requires Pass == Total, the trailing "tests passed" line, AND a
  zero exit, so an aborted or partial suite cannot look like success.

- **The CKpot L1 tolerance is 1e-3, not 1e-6.** The shipped test writes
  `(Eref - E)^2 < 1e-6`, which is |dE| < 1e-3; the reference eigenvalues are
  quoted to three decimals. The measured agreement is much tighter (max |dE| =
  4.1e-4), but the gate matches the reference's own precision. Do not mistake the
  squared form for a 1e-6 energy tolerance. The tight ab initio anchor (IMSRG
  ground state to 1e-6 absolute) lives in L2, not L1.

## Argument safety (run wrapper)

- The `run_*` wrapper validates its arguments before any Julia call: the
  interaction must be `ckpot` or `usdb` (a fixed allowlist, so no path can be
  injected as an interaction file), the nucleus must be alphanumeric, and
  `n_eigen` a positive integer. The nucleus/interaction/count are passed to Julia
  as `ARGS` values (not interpolated into code), so a crafted nucleus string
  cannot inject Julia; the allowlist and alphanumeric check are belt-and-braces.

## Interpreting results

- **Shell-model energies are valence-space (core-subtracted).** They are not
  total binding energies; they are relative to the interaction's core with its
  single-particle energies. Cross-interaction energy comparisons are meaningless
  unless the core and space match.
- **CKpot and USDB are fitted effective interactions**; agreement with experiment
  is a property of the interaction, not of the code. The benchmark checks that
  the code reproduces the package's own shipped reference numbers, which is the
  build-integrity claim, separate from physics accuracy.
- **emax drives cost, and default emax may be small.** The ab initio anchors use
  emax=2 (He-4), which is light; realistic calculations need larger emax and much
  more memory/time, and should run with `julia -t N` threads on a remote box.
