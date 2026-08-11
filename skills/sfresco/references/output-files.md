# What SFRESCO writes, and how to read it

Everything lands in the current directory, which is why runs belong in a scratch dir.

| File | Unit | Contents |
|------|------|----------|
| `<output_file>` | 308 | the main FRESCO output for the current parameters, plus every SFRESCO report (`SET`, `SCAN`, `SHOW`, chi-squared lines) |
| `<output_file>-init` | 307 | the FRESCO output of the very first, unfitted run. Keep it: it is the "before" state |
| `<output_file>-trace` | 105 | one line per FCN call: call number, chi2/N, and chi2/N per dataset (up to 6). The convergence history |
| `<output_file>-snap` | 106 | same, plus all parameter values (`5e12.5` per line). Restart a fit from here with `READ <snapfile>` |
| `search.plot` or the name given to `PLOT` | 304 | xmgrace file: fitted parameters as comments, then per dataset the data with errors and the theory curve |
| `minuit-saved.dat` | 33 | MINUIT's own save file |
| `fort.3` | 3 | the deck expanded into standard `&potl` records. Ground truth for `pline` counting |
| `fort.16`, `fort.13`, `fort.40`, `fort.71`, `fort.35`, `fort.75`, ... | | the usual FRESCO outputs at the current parameters. `ESCAN` fills 71 (phase shifts), 40 (fusion, reaction, non-elastic), 35 and 75 (S-factors in cm and lab energies) |

## Reading `search.plot`

Header comments carry the parameters that produced the curves, which makes the plot file self-documenting:

```
#   Var   1=r0         value     1.181411, step   0.0100, error   0.0018
#   Var   2=V          value    52.183571, step   0.1000, error   0.1790
...
# ChiSq/N =     8.935 from      8.935
@subtitle "Search file: p-cd.search; Fresco input: p-cd.nin"
@TYPE xydy          <- data block: x, y, dy
...
&
@TYPE xy            <- theory block: x, y
...
&
```

One `xydy` block plus one `xy` block per dataset, in order. Tensor ranks above 0 (analysing powers) go to separate files with the rank appended to the name.

`python3 scripts/fitreport.py case-fit.plot --dat case` splits it into `case-<n>-data.dat` and `case-<n>-theory.dat` with plain columns. Plot those through the `nature-figure` skill; do not hand-roll a plot here.

`READ <plotfile>` reads the parameter comments back, which is how you resume from a previous fit. If the file name contains `snap`, SFRESCO instead scans to the last snapshot in a `-snap` file, so a fit killed halfway is recoverable. It prints one `Reading snap at #n with Chisq =` line per snapshot as it winds forward, and restores the parameters at the last one; those carry only the file's `5e12.5` precision, so restart, do not report, from a snap. Verified on the closure example: reading its snap restores V = 49.0229, W_d = 7.2155 and chi2/N = 0.000.

```
case.search
read case.frout-snap
min
set strategy 2
migrad
hesse
end
q
show
plot case-fit2.plot
ex
```

## Reading the trace

`-trace` is two or three columns of numbers and answers one question quickly: did the minimizer walk downhill smoothly, jump around, or stall? A trace that oscillates between two chi-squared values at the same amplitude means the step size is fighting numerical noise in the FRESCO calculation. A trace with occasional jumps of 10000/N means a bound state or the iteration failed at that trial point (see `failure-modes.md`).

## The `SHOW` table

```
   Angle   Datum      Abs. error  Theory         Chi
   22.000 0.54800     0.44000E-01 0.57591          0.4023
   34.000 0.50200     0.10000E-01 0.51656          2.1198
```

The last column is the chi-squared contribution of that point, not chi. Sorting by it tells you which points the fit is paying for, which is more informative than the total. Note that `Datum` and `Abs. error` are printed already multiplied by any fitted `datanorm`.
