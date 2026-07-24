# vHLLE failure modes

Each of these produces a wrong-but-plausible result or a confusing stop, and each
was hit while building this skill.

## 1. Gubser stops after ONE step on a thin eta grid

The main branch ends the timestep loop when the freeze-out surface finder returns
zero elements (`if (nelements == 0) break;`). With a thin spatial-rapidity grid
(small `nz`, narrow eta), the Cornelius finder produces no closed surface for the
boost-invariant Gubser blob, so `corona elements : 0` and the run halts at the
first step, silently writing only two timesteps. The fix is a real eta extent:
`examples/gubser.params` uses `nz 15`, `etamin -3 etamax 3`. This is not an
e_crit problem: it happens at every e_crit on a thin grid.

## 2. e_crit sets how long a Gubser run lives

The whole conformal Gubser blob dilutes through any given `e_crit` in a narrow
proper-time window. If `e_crit` is near the peak energy density (~1 GeV/fm^3 at
tau 1), the run stops almost immediately once the center cools below it. The
shipped deck uses `e_crit 0.04` so the run reaches `tauMax 1.55`. Raising it
shortens the run; there is nothing wrong with the build.

## 3. Analytic Gubser needs the SIMPLE (conformal) EoS

`icModel 4` sets the analytic conformal initial condition, but the EVOLUTION only
matches the analytic Gubser solution if `p = e/3`. Under the default TABLE build
(Laine lattice EoS) the same deck runs fine and produces sensible output, but it
does NOT reproduce the analytic reference, because the lattice EoS is not
conformal. Build with `VHLLE_EOS=simple` for the Gubser benchmark.

## 4. eos/eosHadronLog.dat is read unconditionally

`main()` constructs the hadronic EoS from `eos/eosHadronLog.dat` for EVERY run,
even a pure-hydro Gubser test that never particlizes. If that file is absent the
run exits with `I/O error with eos/eosHadronLog.dat`. It lives in the companion
repo `vhlle_params`; `install_vhlle.sh` links `eos/` so it is always present.

## 5. Runtime cannot find libgsl (Linux with conda GSL)

If GSL comes from a conda env, the binary links `libgsl.so.NN` from that env, and
a bare run fails with `error while loading shared libraries: libgsl.so.28:
cannot open shared object file`. `install_vhlle.sh` links with
`-Wl,-rpath,<gsl>/lib` so the binary finds it regardless of `LD_LIBRARY_PATH`.
If you build vHLLE by hand, either add that rpath or export `LD_LIBRARY_PATH`.

## 6. outdiag.dat is not a rectangular table

The diagonal-cut file wraps each 20-field record across two physical lines
(8 + 12). Parsing it as one-record-per-line yields ragged rows and silent column
shifts. Use `outx/outy/outz.dat`, which are clean 20-column tables.

## 7. tau0 must be 1.0 for Gubser

The Gubser IC formula in `icGubser.cpp` is written at reference proper time
`_t = 1.0`. Setting `tau0` to anything else starts the fluid at an inconsistent
time and the analytic comparison is meaningless.

## 8. Run from the repository root

vHLLE opens `eos/` and `ic/` relative to the current directory. Run it from
anywhere else and it cannot find the EoS. `run_vhlle.sh` always `cd`s to the repo
root and passes absolute paths for the param file and output directory.

## 9. A parameter typo is silently defaulted

Unknown or misspelled keys are ignored, keeping the compiled-in default. There is
no "unknown key" error, so a typo in `etaS` runs an ideal instead of a viscous
simulation with no warning. Diff your deck against `references/input-format.md`.

## 10. Non-deterministic event modes

The Glissando/Trento/SMASH initial states and any per-event run involve sampling;
their output is not reproducible without pinning the seed and event count. The
two shipped decks (Gubser, optical Glauber) are fully deterministic.
