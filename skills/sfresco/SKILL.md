---
name: sfresco
description: >-
  Fit FRESCO calculations to data with SFRESCO, the MINUIT chi-squared search front end: build the .search file, choose search variables, run the batch fit, read the errors and correlations, and report the result honestly. Use for 拟合光学势, 用sfresco拟合, 卡方拟合, sfresco search file, fit optical potential to elastic data, MINUIT MIGRAD fit, phase-shift fit, R-matrix width fit, dataset normalisation fit, search.plot.
---

# Fitting data with SFRESCO

SFRESCO wraps FRESCO in a MINUIT chi-squared minimizer. You give it a working FRESCO deck, a list of parameters to vary, and one or more experimental data sets; it repeats the whole FRESCO calculation at each trial point and searches for the chi-squared minimum. The binary contains FRESCO, so there is no separate call and no coupling file: `sfresco` alone runs everything.

This skill covers the fitting layer only. Building and verifying the deck itself is the `fresco` skill's job, and you must go through it first.

## Prime rules (do not skip)

1. **Never fit a deck you have not run and converged.** A fit on an unconverged deck moves the physics parameters to absorb numerical error, and it will succeed at doing so: chi-squared drops, the potential is wrong. Fix `hcm`, `rmatch`, `jtmax`, bin counts first, per `fresco/references/verification.md`. Convergence is checked once, before the fit, not after.
2. **`ChiSq/N` printed by SFRESCO is per data point, not per degree of freedom.** N is the total number of points over all datasets, with no subtraction of the number of free parameters. Say which N you used when you quote it.
3. **An error bar is only real after `hesse` says `ERROR MATRIX ACCURATE`.** SFRESCO calls MINUIT with `set strategy 0`, so a plain `migrad` leaves `ERR MATRIX APPROXIMATE`, and those errors mean nothing. See the standard session below.
4. **Always report the correlations.** Optical-potential fits are degenerate by construction: in the shipped `p-cd` example the fitted V and r0 come out correlated at -0.921 and W against W_d at -0.930, and in `nalpha` the two strengths reach -0.996. A parameter pair at |rho| > 0.95 is one number, not two, no matter what the error column says.
5. **Verify the fitted parameters actually landed where you think.** `pline` is not the input line number (see below). The single most common failure is fitting the wrong parameter, and the fit still converges, so nothing warns you. Run `scripts/potmap.py` instead of counting by eye.
6. **Do not quote a fit as "the" potential.** Chi-squared minimization gives one point in a valley. If the user needs uncertainties that mean something, that is Bayesian territory (the DREAM line), not MINUIT parabolic errors.
7. **No em-dashes in any prose you write** (user's flat rule).

## Environment

- **Binary, and what to do when there is none.** `sfresco` contains FRESCO, so this one binary runs everything. `scripts/run_sfresco.sh` looks at `$SFRESCO_BIN`, then `~/bin/sfresco`, then `PATH`, and if none exists it calls the fresco skill's `install_fresco.sh`, which clones https://github.com/I-Thompson/fresco and builds `fresco` and `sfresco` together with `gfortran` (about 2 minutes, needs `gfortran`, `git`, `make`; macOS: `brew install gcc`). Verified cold start: from an empty bin dir the installer produced both binaries and the `p90zr-closure` fit then recovered its true parameters. The installer is not called with `--force`, so it never overwrites binaries you already have.
- **Versions.** A fresh build today is **FRES 3.5**; the binary in `~/bin` on this machine is **3.4 from 2023**. Both reproduce the example anchors (chi-squared and fitted parameters agree; the MINUIT error column differs in the last digits because the two versions walk the valley differently). To upgrade, run `install_fresco.sh --force` yourself: it overwrites `~/bin/fresco` and `~/bin/sfresco`, so that is a decision to make deliberately, not a side effect of a fit.
- SFRESCO writes the FRESCO output, `<out>-init`, `<out>-trace`, `<out>-snap`, `search.plot`, `minuit-saved.dat` and about 20 `fort.*` files into the current directory. **Always run in a scratch dir**, which `scripts/run_sfresco.sh` does for you.
- Batch, not interactive: pipe a command file (`sfresco < case.min`). Interactive mode exists but is not reproducible.
- Cost: the standard session below costs 134 FRESCO runs for the 2-parameter closure example, 185 for the 2-parameter `nalpha` fit and 344 for the 4-parameter `p-cd` fit, so budget roughly 60 to 90 runs per free parameter including `hesse`. Time the deck first (`fresco < deck > out`) and multiply. Anything above a few seconds per FRESCO run belongs on a remote box, not this laptop.
- **`type=9` (ANC) needs the new binary.** The 2023 FRES 3.4 in `~/bin` rejects it with `Unrecognised data type 9` and then fits nothing; FRES 3.5 reads it (verified: `test/b8-gs-fit.search`, an 8B = 7Be + p ANC fit, starts at chi2/N = 10.3593). Types 7 and 8 (Brune-basis pole energy and formal width) are marked not implemented in the source of both. If a fit needs ANC data, build 3.5 first.

## The three files

```
deck.in       FRESCO input, already verified by the fresco skill
case.search   what to vary + the data          <- the fitting problem
case.min      the command sequence for sfresco  <- the fitting session
```

`case.search` starts with the deck name and the counts, then one `&variable` per parameter and one `&data` (plus its data) per dataset:

```
'deck.in' 'deck.frout'                  <- FRESCO input, FRESCO output to write
4 1                                     <- nvariables, ndatasets
 &variable kind=1 name='V'  kp=1 pline=2 col=1 potential=52.5 step=0.1 /
 &variable kind=1 name='r0' kp=1 pline=2 col=2 potential=1.17 step=0.01 valmin=0.9 valmax=1.5 /
 &variable kind=1 name='W'  kp=1 pline=2 col=4 potential=3.5  step=0.1 /
 &variable kind=1 name='WD' kp=1 pline=3 col=4 potential=8.5  step=0.1 /
 &data type=0 idir=1 iscale=-1 lab=F abserr=T energy=27.90 /
   22.  0.548 0.044
   26.  0.475 0.024
   ...
&                                        <- ends the data block
```

Omit `potential=` and the starting value is taken from the deck. `step=0` fixes a variable. `valmin`/`valmax` must both be present or both absent.

**`pline` is the order of the expanded `&potl` records for that `kp`, not the line number in your file.** One alias-style `&pot kp=1 v=... w=... wd=... vso=... /` expands into four records, so `pline` runs 1 to 4 for what looks like one line. A second subtlety: for deformed potentials read in as matrix elements (TYPE 12 to 17), **each following `&step` namelist also advances the counter** (`frxx2.f:331`), and a variable that lands on a `&step` varies that step's strength `str`, with `col` ignored. Get the mapping from the deck with

```bash
python3 scripts/potmap.py deck.in                 # table of kp / pline / col / value
python3 scripts/potmap.py deck.in --emit 2.1 3.4  # ready-to-paste &variable lines
python3 scripts/potmap.py deck.in --emit 2.3.4    # KP.PLINE.COL when the deck has several kp
python3 scripts/potmap.py fort.3 --fort3          # ground truth, from a completed run
```

## What can be varied (`&variable kind=`)

| kind | varies | fields it needs | typical use |
|------|--------|-----------------|-------------|
| 1 | a potential parameter | `kp`, `pline`, `col`, `potential` | optical-model fits, binding potentials, deformation lengths |
| 2 | a spectroscopic amplitude | `nafrac` (which `&cfp` in the deck), `afrac` | transfer strengths, SF extraction |
| 3 | an R-matrix pole energy | `term`, `jtot`, `par`, `energy`, `nopot` | resonance positions |
| 4 | an R-matrix partial width | `term`, `channel`, `width` | resonance widths, ANCs via reduced widths |
| 5 | a dataset normalisation | `dataset`, `datanorm` | absolute-scale uncertainty of an experiment |

`col` indexes `p(1:7)` of that record, so for a `type=1` line col 1,2,3 are V, r_V, a_V and col 4,5,6 are W, r_W, a_W; for `type=2` col 4,5,6 are W_d, r_d, a_d; for `type=3` col 1,2,3 are V_so, r_so, a_so. Full table in `references/search-file-format.md`.

## What can be fitted to (`&data type=`)

| type | data are | x column | notes |
|------|----------|----------|-------|
| 0 | angular distribution at one energy | angle | the common case; `energy=` sets the lab energy |
| 1 | angle and energy distribution | energy, then angle per row | four columns: E, theta, value, error |
| 2 | excitation function at fixed angle | lab energy | `angle=` gives the angle |
| 3 | integrated cross section vs energy | lab energy | `ic=0`: `ia=0` fusion, `ia=1` reaction, `ia=-1` angle-integrated elastic, `ia=-2` total |
| 4 | phase shift vs energy | lab energy | `jtot=`, `par=`, `channel=` select the partial wave |
| 5 | bound-state search factor | state index | binding energy or potential scale, per `isc` |
| 6 | a constraint on a search parameter | (no data) | `par=` which variable, `value=`, `error=` |
| 9 | ANC of a bound state | state index | rejected by the 2023 binary, needs a current build |

Units and frames are set per dataset by four flags, and getting them wrong is silent:

- `idir`: 0 absolute, 1 ratio to Rutherford, 2 absolute converted to ratio, -1 S-factors converted to absolute.
- `iscale`: -1 dimensionless, 0 fm^2/sr, 1 b/sr, 2 mb/sr (default), 3 microbarn/sr. Note `idir=1` forces `iscale=-1`.
- `abserr`: **`T` means the third column is an absolute error; the default `F` means it is a fraction of the datum.** Forgetting `abserr=T` on data with absolute errors turns a 5% measurement into a 0.05% one, and chi-squared explodes by 10^4 with no message.
- `lab`: `T` for lab angles and cross sections, default `F` for cm.

## Standard session

`scripts/run_sfresco.sh` generates exactly this when you do not pass a `.min`:

```
case.search          <- line 1 is always the search file name
q                    <- echo the starting parameters
plot case-init.plot  <- data + starting theory, for the before/after figure
min                  <- enter MINUIT
set strategy 2       <- accurate derivatives; strategy 0 is SFRESCO's default
migrad               <- the actual minimization
hesse                <- recompute the covariance properly: this is what makes errors real
end                  <- leave MINUIT
q                    <- fitted parameters WITH errors (before `end` you get the starting values)
show                 <- per-point data, theory, chi contribution
plot case-fit.plot   <- data + fitted theory
ex
```

Add `minos` after `hesse` for asymmetric errors on a hard case. Full command list, including `scan`, `set`, `fix`, `step`, `read`, `escan`, in `references/commands.md`.

## Workflow

1. **Verify the deck.** Run it through the `fresco` skill, converge it, check the cross section is physical. Note the runtime.
2. **Map the parameters.** `python3 scripts/potmap.py deck.in`, and cross-check against `fort.3` from step 1 if the deck uses alias-style `&pot` lines.
3. **Write `case.search`.** Data go inline after `&data` (`data_file='='`, the default) or in a separate file (`data_file='exp.dat'`). Set `idir`, `iscale`, `abserr`, `lab` deliberately, and state in a comment what the source of the data was.
4. **Check the starting point before fitting.** Run with a `.min` of just `q` / `show` / `plot init.plot` / `ex`. Confirm the theory column in `show` is neither zero nor absurd, and that the number of data points read equals what you wrote. A silent truncation here is common (see failure modes).
5. **Fit staged, not all at once.** Strengths first with radii and diffusenesses fixed, then release the geometry. Releasing 8 parameters against one angular distribution produces a converged fit to a meaningless point.
6. **Run it**: `scripts/run_sfresco.sh case.search [case.min]`.
7. **Read the summary** from `scripts/fitreport.py`: chi2 before and after, parameters with errors, `ERROR MATRIX ACCURATE`, correlations. If the matrix is not accurate, the fit is not finished.
8. **Look at the fit, do not just read chi-squared.** `fitreport.py case-fit.plot --dat case` writes plain columns; plot them through the `nature-figure` skill. A chi2/N of 9 that follows the diffraction pattern and a chi2/N of 9 that misses the first minimum are different results.
9. **Report**: parameters with errors, chi2/N with N, which parameters were fixed and at what, the correlation matrix, and the starting point (MINUIT is local; a different start can land elsewhere). If one pair is degenerate, say so and quote the combination.

## Verified examples

All three run with `bash scripts/run_sfresco.sh examples/<case>.search examples/<case>.min` on `~/bin/sfresco` (FRES 3.4, 2023 build).

| Case | Physics | Fitted | Anchor |
|------|---------|--------|--------|
| `examples/p-cd-manual.*` | **published reference case**: p + 112Cd at 27.9 MeV, the 12 points of *FRESCO: getting started* Boxes 7 and 8 | V, r0, W, W_d | reproduces every digit the manual prints: V = 52.5280 (published 52.53), r0 = 1.17958 (1.179), W = 3.46041 (3.46), W_d = 7.42937 (7.43), chi2/N 643.19 -> 2.1910 (2.19). Started from r0 = 1.0, a 15% displacement, so this is a fit and not a re-echo |
| `examples/p-cd.*` | the same system as the distribution's own test case, 28 points | V, r0, W, W_d | chi2/N 20.5232 -> 8.935; V = 52.184, r0 = 1.1814, W = 2.8957, W_d = 8.1819; corr(V,r0) = -0.921, corr(W,W_d) = -0.930 |
| `examples/nalpha.*` | n + 4He phase shifts, 3 partial waves, 78 points | V, V_so | chi2/N 26021.14 -> 392.80; V = 44.210, V_so = 9.727; corr = -0.996 (degenerate pair) |
| `examples/p90zr-closure.*` | closure test: KD02 p + 90Zr at 30 MeV fitted to pseudo-data generated from itself | V, W_d | recovers V = 49.0229 (true 49.023171) and W_d = 7.2155 (true 7.215552), chi2/N 463.58 -> 0.000 |

Two of these are worth running for different reasons. **`p-cd-manual` is the published-work check**: the target numbers are in print, in the code author's own manual, so agreeing with them tests the skill against the literature rather than against the code. **`p90zr-closure` is the internal check** to run after any change to the scripts or the environment: it proves the whole chain (pline/col mapping, units flags, minimizer) end to end, because the right answer is known exactly.

`p-cd` is the same system as `p-cd-manual` but with the distribution's own 28-point test file and start values, and it reproduces the distribution's reference output `test/Outputs/ss-fit.plot`: chi2/N = 8.935 exactly, r0 and V to 5 digits, W and W_d to 4 (that reference ran at MINUIT strategy 0 without `hesse`, so the last digits follow a different path down the same valley). Keep both: one anchors to the paper, the other to the shipped code. `nalpha` reproduces the distribution's initial chi2 (26021.11) to 6 digits but ends at a **different, better minimum** than the reference (392.80 against 414.94): MIGRAD is path dependent, so the converged parameters of a multi-minimum fit are not a reproducibility anchor, only the starting chi2 is.

## Scripts

- `scripts/potmap.py <deck.in> [--kp N] [--emit [KP.]PLINE.COL ...] [--fort3]`: maps every potential parameter to its `(kp, pline, col)` triple, emulating FRESCO's `&pot` to `&potl` expansion, and emits `&variable` lines. It reproduces the awkward parts of the Fortran on purpose: `p(0:8)` indexing, null array elements (`p(1:3)=50,,0.65` puts 0.65 in col 3), `n*value` repeats, `kp=-4` counting as `kp=4`, and `&step` records taking their own `pline`. Use `--fort3 fort.3` to read the expansion FRESCO itself produced, and compare the two on any deck you did not write yourself.
- `scripts/run_sfresco.sh <case.search> [case.min] [runname]`: copies the search file, the deck named on its first line, and any external data files into a fresh scratch dir, runs SFRESCO with the standard session if no `.min` is given, and prints the fit summary.
- `scripts/fitreport.py <run.log>`: chi2 history, fitted parameters, MINUIT table, error-matrix verdict, correlations, and warnings when the errors are not trustworthy or two parameters are degenerate. `--dat PREFIX` on a `search.plot` splits it into data and theory columns for plotting.

## Reference map

- `references/search-file-format.md`: every field of `&variable` and `&data`, with defaults, ground-truthed against `sfresco.f`, plus where the printed manual disagrees with the code.
- `references/commands.md`: SFRESCO commands and the MINUIT subset that matters, with what each one costs in FRESCO runs.
- `references/fitting-strategy.md`: how to stage a fit, what the optical-model ambiguities do to it, when a low chi-squared is lying, normalisation fitting, and what to report.
- `references/failure-modes.md`: symptom to cause to fix, each entry observed rather than guessed.
- `references/output-files.md`: what SFRESCO writes and how to read `search.plot`, `-trace`, `-snap`.

## Scope

SFRESCO does chi-squared minimization with MINUIT over FRESCO parameters. It does not do Bayesian inference, model selection, or emulation: for posteriors on a CDCC calculation use the user's DREAM line, not this. It does not fit anything FRESCO cannot compute, so inclusive non-elastic breakup (IAV/NEB) is out of scope; that is `smoothie`. For building or debugging the underlying deck, use the `fresco` skill.
