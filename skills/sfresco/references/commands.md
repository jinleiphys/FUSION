# SFRESCO and MINUIT commands

Line 1 of the command file is always the search file name. Every line after it is one command, upper or lower case (mixed case is not recognized). Reaching end of file exits.

## SFRESCO commands

| Command | What it does | Cost in FRESCO runs |
|---------|--------------|---------------------|
| `Q` | print each variable with value, step, and error | 0 |
| `SHOW` | recompute, then list every point: x, datum, absolute error, theory, chi^2 contribution | 1 |
| `SET var val` | set variable number `var` to `val`, then recompute and print chi2 | 1 |
| `FIX var` | fix variable `var` (step = 0) | 0 |
| `STEP var step` | release `var` with the given step | 0 |
| `SCAN var v1 v2 step` | walk `var` from `v1` to `v2`, printing chi2 at each point, then restore | one per point, plus one |
| `PLOT [file]` | recompute and write data + theory curves to `file` (default `search.plot`) | 1 |
| `LINE [file]` | same but theory only, no data | 1 |
| `READ file` | read parameters back from a plot file; if the name contains `snap`, read the last snapshot of a `-snap` file | 1 |
| `ESCAN emin emax estep` | excitation function in the incident channel, into fort.71 (phase shifts), fort.40 (fusion, reaction, non-elastic), fort.35 and fort.75 (S-factors). Negative `estep` gives a logarithmic grid | one per energy |
| `MIN` | enter MINUIT; SFRESCO first issues `set nogradient`, `set strat 0`, `set errordef 1/ndof` | 0 |
| `EX` | exit | 0 |

`Q` before `END` reports the starting values, not the fit. Put a second `Q` after `END`.

`SCAN` is the honest way to look at a chi-squared surface before trusting a minimum. Ten points per parameter costs ten FRESCO runs and tells you whether the valley is single, flat, or double.

## MINUIT commands (between `MIN` and `END`)

| Command | What it does | When |
|---------|--------------|------|
| `set strategy 2` | more careful derivatives and covariance | always, before `migrad`, unless each FRESCO run is expensive |
| `migrad` | the variable-metric minimization | the workhorse |
| `hesse` | recompute the covariance matrix from second derivatives | after `migrad`, always. Without it the errors stay `APPROXIMATE` and mean nothing |
| `minos` | asymmetric errors by profiling chi-squared | when a parameter is bounded, correlated, or the valley is not parabolic |
| `simplex` | derivative-free minimization | when `migrad` fails to find improvement from a bad start |
| `set print 0` | quieten the per-iteration output | long fits |
| `set limits N lo hi` | bound parameter N from inside MINUIT | when you did not set `valmin`/`valmax` |
| `fix N` / `release N` | freeze or release parameter N | staged fitting without editing the search file |
| `scan N` | MINUIT's own one-dimensional scan | quick look at one direction |
| `end` | return to SFRESCO | required, or the fitted values never reach SFRESCO |

MINUIT sees `ERRORDEF = 1/ndof` because SFRESCO minimizes chi2/N, so its "1 sigma" contour is delta-chi-squared = 1 on the unnormalized chi-squared. That is the standard convention; you do not need to rescale the printed errors.

Read the status line, not just the numbers:

- `STATUS=CONVERGED` with `ERROR MATRIX ACCURATE`: a real minimum with real errors.
- `ERR MATRIX APPROXIMATE`: run `hesse`.
- `ERR MATRIX NOT POS-DEF` or `MATRIX FORCED POS-DEF`: you are not at a minimum, or two parameters are degenerate. Fix one and refit.
- `MIGRAD FAILS TO FIND IMPROVEMENT`: either converged already (check `EDM`) or stuck. `simplex` then `migrad` often clears it.
- `CALL LIMIT EXCEEDED`: raise it with `migrad 5000` or reduce the number of free parameters.

## Two sessions worth remembering

Standard fit, what `run_sfresco.sh` writes for you:

```
case.search
q
plot case-init.plot
min
set strategy 2
migrad
hesse
end
q
show
plot case-fit.plot
ex
```

Explore before fitting, when the starting point is doubtful:

```
case.search
q
show
scan 1 40. 60. 2.
scan 2 2. 12. 1.
plot case-init.plot
ex
```
