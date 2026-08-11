# SFRESCO failure modes: symptom, cause, fix

Every entry below was observed on this machine with `~/bin/sfresco` (FRES 3.4, 2023 build), not inferred. Add to this file whenever a new one is diagnosed.

## Reading the search file

**Fewer data points than you wrote, no error message.**
A comment line, a blank field, or any non-numeric text inside a data block ends that dataset there. The reader hits the bad line, backspaces, and closes the set. A `!` comment dropped into the middle of 29 points leaves 6 points and a fit that still converges, to the wrong answer.
Fix: comments only between namelists, never inside data. Always check the "N data points" line SFRESCO prints for each set.

**A row with the wrong number of columns swallows the next row.**
The data read is list-directed (`read(inf,*) x,val,err`), which keeps consuming records until all three items are filled. A line carrying only two numbers therefore takes the first number of the following line as its error, and the reader resumes on the line after that. Observed: a stray `2 1` header line left in a 29-point data file produced 29 points and a chi-squared of 462.79 instead of 463.58, with no message. Count the points and check the first row in the `SHOW` table against your file.

**`ONLY ROOM FOR n SEARCH VARIABLES` / `n DATASETS`, then stop.**
Compiled-in limits (`mvars`, `mds`). Reduce the fit or rebuild FRESCO with larger parameters.

**`NO DATA POINTS !! Stop`.**
`data_file` points at a file that is empty, missing, or in the wrong directory. SFRESCO looks in the current directory only. Use `scripts/run_sfresco.sh`, which copies referenced data files into the scratch dir.

**`Unrecognised data type 9`.**
The 2023 FRES 3.4 binary predates ANC fitting; FRES 3.5 accepts `type=9`. Rebuild with `skills/fresco/scripts/install_fresco.sh --force` (it overwrites `~/bin/fresco` and `~/bin/sfresco`, so decide that deliberately). Types 7 and 8 are marked "not yet implemented" in the source of both versions.

**`sfresco: command not found`, or the installer says it is already installed and there is still no `sfresco`.**
Older copies of `install_fresco.sh` detected only `fresco` and returned success, leaving the machine with no `sfresco` at all and no way to trigger a build except `--force`. The current installer requires both binaries before it will skip the build. If you hit the old behaviour, build by hand: `git clone --depth 1 https://github.com/I-Thompson/fresco && make -C fresco/source FC=gfortran && cp fresco/source/sfresco ~/bin/`.

**Build fails at link time with `nagstub.o: No such file`.**
You are building from a source copy that is missing `nagstub.f` (the NAG interpolation stubs). The official repository ships it; some local trees do not. Clone fresh from https://github.com/I-Thompson/fresco rather than patching around it.

**A `&variable` field is silently ignored.**
The namelist in this version does not contain `reffile` (documented in the manual for matching datasets by name). Unknown names in a namelist are a read error in some compilers and ignored in others; either way you do not get the behaviour the manual describes.

## Wrong parameter varied

**Chi-squared moves, the fitted number is nonsense, the fit converges.**
`pline` counted by input lines instead of expanded `&potl` records. One alias-style `&pot` with `v=`, `w=`, `wd=`, `vso=` becomes four records.
Fix: `python3 scripts/potmap.py deck.in`, or `--fort3 fort.3` for what FRESCO actually built.

**Every column is shifted by one.**
A bare `p= a b c` in the deck. `p` is declared `p(0:8)`, so the first value lands in `p(0)`. Write `p(1:3)=` or `p1= p2= p3=`.

**`value from Fresco input` printed for a variable you meant to set.**
`potential=` was omitted, so the starting value came from the deck. Harmless if that is what you wanted; check the echoed value.

## Units, frames, and scale

**chi2/N of order 10^4 at a starting point that looks right on the plot.**
`abserr` left at its default `F`, so a column of absolute errors was read as fractional errors: a 5% measurement became 0.05%. Set `abserr=T` for absolute errors.

**Theory and data differ by a constant factor of 1000 or 10^-3.**
`iscale` mismatch (mb/sr against b/sr against fm^2/sr). Note the code default is `-1` (dimensionless) while the printed manual says 2 (mb/sr): set it explicitly every time.

**Ratio-to-Rutherford data fitted as absolute.**
`idir=1` also forces `iscale=-1`. If you set `idir=1` and leave `iscale=2`, the intent is contradictory; the code resolves it, your reading of the file does not.

**Angles look right, cross sections do not.**
`lab=T` gives lab angles **and** lab cross sections. Mixed conventions (lab angles, cm cross sections) are not supported; convert the data first. With `lab=T`, `search.plot` also carries the theory only at the data angles instead of on the fine `thmin/thinc` grid, because the continuous curve exists only in cm; SFRESCO prints a note saying so.

## The minimizer

**`ERR MATRIX APPROXIMATE` in the final report.**
SFRESCO enters MINUIT with `set strat 0`. Run `set strategy 2`, `migrad`, then `hesse`. Without `hesse` the errors are step-size artifacts.

**`ERR MATRIX NOT POS-DEF` or `MATRIX FORCED POS-DEF`.**
Not at a minimum, or two parameters are degenerate. Check the correlation matrix, fix one of the pair, refit.

**`MIGRAD FAILS TO FIND IMPROVEMENT` immediately.**
Either already at the minimum (check `EDM`, it will be tiny) or the derivatives are noise. If the latter: enlarge `step`, or tighten the deck's numerics so chi-squared is smooth at the scale of `step`.

**Fit runs, chi-squared never changes.**
Every `step` is 0 (all variables fixed), or the varied parameter does not affect the observable (for example a spin-orbit strength in a spin-0 channel, or a potential `kp` that no state's `cpot` points at). `SCAN` the variable: a flat scan says the parameter is not in the calculation.

**Fitted values reported are the starting values.**
`q` was issued before `end`. MINUIT hands the values back to SFRESCO only on `end`. Put a `q` (and a `show` or `plot`) after `end`.

**The last chi-squared in the log is not the fitted one.**
Nothing recomputed after `end`. Finish the session with `show` or `plot`, which rerun FRESCO at the final parameters.

## The FRESCO layer

**Bound-state, iteration, or R-matrix-basis failure inside a fit.**
Three sites add a penalty of `fine = 10000` (set in `sfresco.f:98`) to the total chi-squared, so chi2/N jumps by 10000/N per failing occurrence:

| site | when | gated by `number_calls>5`? |
|------|------|---------------------------|
| `frxx1.f:1933` | coupled-channels iteration fails to converge | **no**, the penalty is always added; the counter only gates the message and the `ABEND` |
| `frxx5.f:600` | `EIGCC` cannot bind a single-particle state (`IFAIL>0`) | yes |
| `frxx17.f:328` | R-matrix basis failure | yes |

**Within the first five FCN calls the last two are fatal instead of penalized**: `stop 'EIGCC FAILURE'` and `stop 'R-matrix basis failure'` (and `CALL ABEND(2)` for the CC case when `FATAL`). So a starting point that cannot bind its states kills the run rather than costing chi-squared, which is why a fit sometimes dies immediately and runs fine after you move the start. Later on, look for `At call n, ...  penalty =` lines: a fit walking into a wall of those is exploring a region where the state does not exist. Bound that variable.

**Chi-squared jumps discontinuously as a parameter crosses a value.**
A channel opened or closed, a bin structure changed, or `jtmax`/`absend` truncated differently. The objective is not smooth there and MIGRAD cannot work through it. Fix the truncation (larger `jtmax`, `absend=-1`) so the calculation is continuous in the parameters.

**Runtime explodes when a radius grows.**
`rmatch` and the partial-wave range were set for the starting geometry. Set them for the largest geometry the fit is allowed to reach, or bound the radius.
