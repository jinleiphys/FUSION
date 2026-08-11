# How to run a fit that means something

Chi-squared minimization is easy to do and easy to do wrong. Everything here is about the second part.

## Before the first fit

**Converge the deck.** Vary `hcm`, `rmatch`, `jtmax` on the starting parameters until the observable is stable to better than the data's precision. If the numerics move the cross section by 2% and the data have 3% errors, the fit will spend its freedom on the 2%. This is not a formality: an unconverged deck produces a converged fit.

**Check what the data actually are.** Ratio to Rutherford or absolute? cm or lab? Relative or absolute errors? Each is one flag (`idir`, `lab`, `abserr`) and each is silent when wrong. The quickest test is a `show` at the starting point: if the theory column is within a factor of a few of the data column, the flags are probably right; if it is off by 10^3, they are not.

**Count the points.** SFRESCO prints "N data points" per dataset when it reads them. If that number is not what you wrote, the read stopped early, and everything after that line is being ignored.

## Choosing what to vary

Start from the physics, not from the parameter count. For a nucleon optical potential fitted to one elastic angular distribution:

1. **V and W first**, geometry fixed at a global parameterization (KD02, CH89). Two parameters against 30 points is a fit; eight against 30 is a decoration.
2. **Then release r_V** if the diffraction pattern's phase is still wrong. V and r_V will come out strongly anticorrelated (-0.92 in the shipped `p-cd` example) because the elastic cross section mostly constrains the product V*r^n. That is the Igo ambiguity, not a bad fit.
3. **Then release W_d against W** only if the data reach far enough back in angle to separate surface from volume absorption. They too will anticorrelate (-0.93 in `p-cd`).
4. **Diffusenesses last, and bounded.** A fit that walks `a` to 0.3 or 1.2 fm is telling you the model is wrong somewhere else.

For a phase-shift fit (type=4), the same rule holds in a harsher form: `nalpha` fits two strengths to 78 phase shifts and still ends with a correlation of -0.996, because the two potentials act on the same partial waves in nearly the same way. Two numbers, one constraint.

For transfer, fit the potentials to the elastic data of both channels first, then let only the spectroscopic amplitude (kind=2) float. Fitting an optical potential and a spectroscopic factor to the same transfer angular distribution is not a determination of either.

## Steps and bounds

- `step` should be about the precision you care about, not the size of the parameter. 0.1 MeV on a 50 MeV depth, 0.01 fm on a radius. Too large and MIGRAD's numerical derivatives step out of the valley; too small and they drown in the FRESCO integration noise.
- Numerical noise sets a floor. If chi-squared changes at the sixth digit when a parameter moves by `step`, the derivative is noise, and MIGRAD will wander. Tighten `hcm` or enlarge `step`.
- Bound geometry (`valmin`, `valmax`), not strengths. A strength that runs to a bound is physics telling you something; a radius that runs to a bound is usually a sign convention or a units error.

## After the fit

**The three things that decide whether the fit is real:**

1. `ERROR MATRIX ACCURATE` after `hesse`. Anything else and the error column is decorative.
2. The correlation matrix. `|rho| > 0.95` means the pair is one direction in parameter space; report the combination or fix one.
3. The residual pattern. Look at `show` or the plot. Random scatter about the data means the model fits; a systematic miss of the first minimum with good chi-squared elsewhere means the fit bought agreement in the easy region.

**A low chi-squared is not automatically good.** chi2/N well below 1 usually means the errors were entered as absolute when they were relative (or the other way), or that `abserr` is wrong. Check before celebrating.

**A high chi-squared is not automatically bad.** With 3% errors on 30 points, a chi2/N of 9 is normal for an optical model at the second and third diffraction minima, where the model genuinely fails. Say that instead of adding parameters until the number falls.

**MINUIT is local.** Restart from two or three different starting points and compare. In the shipped `nalpha` case the distribution's own reference run ends at chi2/N = 414.94 and the run here ends at 392.80, from the same search file: different MIGRAD path, different minimum. The starting chi-squared is reproducible, the final one is not.

## Fitting a normalisation

A `kind=5` variable multiplies the **data**, not the theory: chi-squared uses `datanorm*datum` and `datanorm*error`. A fitted `datanorm` of 1.08 means the published data sit 8% below the model. Use it when the experiment quotes a separate normalisation uncertainty, and then either

- constrain it with a type=6 dataset (`par=<variable number>`, `value=1.0`, `error=0.05`, `abserr=T`), so the fit pays for moving it, or
- report it as a fitted quantity with its own error.

Letting a normalisation float free against a single angular distribution absorbs exactly the information that determines the potential depth. Constrain it or fix it.

## What to report

- Parameters with errors, and which ones were fixed and at what values.
- chi2/N with N stated, and that N is the number of points (SFRESCO does not subtract parameters).
- The correlation matrix, or at minimum every pair above 0.9.
- The starting point, since the minimum is local.
- Whether `hesse` ran and what the error-matrix status was.
- The convergence parameters of the underlying deck.

That list is short because it is the minimum that lets someone else repeat the fit. If the user needs uncertainty bands rather than error bars, MINUIT parabolic errors are the wrong tool and the DREAM Bayesian line is the right one.
