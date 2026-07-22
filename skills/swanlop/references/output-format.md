# SWANLOP output format

All output filenames start with `zz.` and are written to the current working
directory. On a normal run the program prints `STOP SWANLOP [OK]` and exits 0, but
the verdict is the content of the `zz.*` files, not that string.

## `zz.xaq` : angular observables (primary numeric output)

A commented header block (projectile, target, energy, CM momentum, grid) followed
by the reaction cross section and an angular table:

```
# Reactn xSectn  :  1.66084E+00 b
#  Theta  q[1/fm]  q[MeV/c]   dS/dW[mb/sr]        Ay         Q   Sigma/SRuth
   1.000  0.02099  0.004142   0.164907E+10 -0.000002  0.000013   9.97890E-01
   2.000  0.04198  0.008283   0.104143E+09  0.000001 -0.000101   1.00816E+00
   ...
```

Columns: scattering angle (deg), momentum transfer q (1/fm and MeV/c), the
differential cross section dsigma/dOmega (mb/sr), analyzing power Ay, spin
rotation Q, and the ratio to Rutherford. The `Reactn xSectn` line carries the
integrated reaction cross section (barns). `run_swanlop.sh` reads that value
(finite and positive) and counts the angular rows; `verify_swanlop.sh` matches the
whole file against `zz.xaq.REF`.

## `zz.dsdt` : dsigma/dt

The differential cross section versus Mandelstam t, same header style, matched
against `zz.dsdt.REF` by verify.

## `zz.main` : run summary

The full text summary of the calculation (parameters, potential, partial-wave
information, integrated quantities). Identical to `zz.main.REF` except the
`Date:`/`Time:`/`UTC` line, which varies per run.

## Timestamps

Every `zz.*` file carries a `Date:`/`Time:`/`UTC` header line stamped at run time,
so a raw `diff` against the shipped `.REF` always shows that one line. The
verification strips `Date:`/`Time:`/`UTC` (and any `CPU` timing line) before
comparing, so the match is on the physics content, not the clock.

## Reproducibility and the runs directory

`swanlop.x` reads `fort.1`, `NucChart` and any experimental data file from the
current directory and writes its `zz.*` outputs there, so it is launched from a
directory holding those inputs. The wrappers run it in a scratch copy of `runs/`
so the shipped tree and its `.REF` files are never overwritten.
