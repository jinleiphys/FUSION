# CNOK output format

## Screen output and the result file

In cross-section mode `mom` prints a long per-impact-parameter integrand trace to
stdout (the `b: ... bint: ...` lines, useful for spotting a non-converged
integral) and ends with a summary table:

```
       M       STRIP        DIFF       TOTAL
       0   60.086689   18.056073   78.142761
In total:
Stripping c.s.:         60.086689 mb
Diffractive c.s.:       18.056073 mb
Total knockout c.s.:    78.142761 mb
```

The same summary is written to a timestamped file in the deck's directory,
`<basedir>/<name>_<YYYYMMDD>_<HHMM>.txt`, which is the machine-parseable output:

```
Run at 2026-07-22_21:24
Orbit: 1s1/2_15C_n
S_N+Ex: 4.250300 MeV

The calculated total knockout cross sections (in mb)
       M       STRIP        DIFF       TOTAL
       0   60.086689   18.056073    78.142761

In total:
Stripping c.s.:         60.086689 mb
Diffractive c.s.:       18.056073 mb
Total knockout c.s.:    78.142761 mb
```

- `sigma_str` (stripping / inelastic breakup): valence nucleon absorbed by the
  target, core survives.
- `sigma_diff` (diffractive / elastic breakup): valence and core both at most
  elastically scatter.
- `sigma_sp` = STRIP + DIFF: the single-particle cross section, the "unit" cross
  section from which experimental spectroscopic factors are extracted via
  sigma(E*a, nlj) = (A/(A-1))^N C2S sigma_sp.
- `Orbit` and `S_N+Ex` echo the valence configuration and effective separation
  energy from the deck, tying the output to its input.

`run_cnok.sh` parses this file: it requires three finite, positive cross
sections, `TOTAL == STRIP + DIFF` to the printed precision, and `S_N+Ex` equal to
the deck's `Eref` (a substituted-deck guard). Cross sections are read from the
result FILE, never inferred from the exit status.

## Momentum mode (`-m`)

`-m` computes the parallel (longitudinal) momentum distribution `d sigma / d k_z`
of the core instead of the cross section. CNOK computes all three channels, the
stripping, the diffractive and the total, and writes `<name>_strT.txt`,
`<name>_difT.txt` and `<name>_totT.txt` (two columns, `k_z [MeV/c]  value`) to the
deck's directory, copying them to `build/vis/` for the ROOT macro `vis/mom.C`.
Including the diffractive momentum distribution, which most Glauber codes omit
because it is more time-consuming, is a distinguishing feature of the code; the
diffractive distribution is much flatter (wider) than the stripping one.
Distributions are also available per `m` and, in batch mode, C2S-weighted over
configurations. `-mc` additionally convolves with `config/expres.yaml`.

## Intermediate outputs (all in `build/vis/`, for inspection)

- `Rl.txt`, `rRl.txt`, `rRl2.txt` : the bound radial wavefunction R_l(r) (macro `Rl.C`).
- `c.txt`, `v.txt`, `t.txt`, `ct.txt`, `vt.txt` : Fourier transforms of the
  densities rho_c(q), rho_v(q), rho_T(q) and the folded integrands (macro `rhoq.C`).
- `sc.txt`, `sv.txt` : the core and valence S-matrices S_c(b_c), S_v(b_v) (macro `sm.C`).
- `str.txt`, `diff.txt` : the impact-parameter integrands d sigma_str/db_v,
  d sigma_diff/db, for convergence inspection (macro `str.C`).

ROOT is optional and used only to plot these; the physics numbers do not need it.

## Result-file / stdout gotchas

- The stdout integrand trace is verbose (thousands of `b: ... bint:` fields, no
  trailing newline per line). Do not parse stdout for the answer; parse the
  result file.
- The result file is timestamped to the MINUTE. Two runs of the same case inside
  one minute overwrite the same file; the run wrapper clears stale
  `<name>_*.txt` before each run and takes the newest afterwards.
- `mom` must be launched from the build directory: it resolves `config/` and the
  `basedir.yaml` path relative to the current working directory.
