# Thermal-FIST output reference

The cpc and EoS example programs write plain whitespace-delimited tables to the
CURRENT WORKING DIRECTORY (there is no `-o` flag), under fixed names. The first
line is always a header that NAMES the columns; the remaining lines are data.
`check_output_thermalfist.py` parses exactly this shape.

## Table shape

- **Line 1 is a header.** Column names, whitespace-separated, sometimes with a
  leading `#`. Never a data row.
- **Data rows are numeric**, except that some tables carry LEADING LABEL columns.
  cpc3 writes a dataset name first (`NA49-30GeV-4pi`, `ALICE-2_76-0-5`, ...) then
  the numbers. Any parser that assumes every token is a float will break on cpc3;
  `check_output_thermalfist.py` strips leading non-numeric tokens as labels and
  requires the count of them to be consistent across rows, and requires every
  token AFTER the first number to be numeric (a label in the middle of a row is a
  real defect, not a label column).
- Numbers are printed fixed or in `E` notation (`8.610235E-02`), typically to six
  significant figures. That print precision is the ceiling on any comparison.

## The specific outputs

| program | output file(s) | columns |
|---|---|---|
| `cpc1HRGTDep 0/1/2` | `cpc1.{Id,EV,QvdW}-HRG.TDep.out` | `T[MeV]  p/T^4  e/T^4  s/T^3  chi2B  chi4B  chi2B-chi4B`, 181 rows (T = 20..200 MeV) |
| `cpc2chi2 0..3` | `cpc2.<model>.ALICE2_76.chi2.TDep.out` | chi^2 of the ALICE 2.76 TeV fit vs T |
| `cpc3chi2NEQ 0/1` | `cpc3.EQ.chi2.out`, `cpc3.NEQ.chi2.out` | `Dataset  T[MeV]  muB[MeV]  R[fm]  gammaq  gammaS  chi2  chi2/dof  Q/B  S/|S|`, one row per dataset (label column first) |
| `cpc4mcHRG 0` | `cpc4.montecarlo.dat`, `cpc4.analyt.dat` | Monte Carlo vs analytic multiplicities; the MC file is NOT reproducible without pinning the event count and RNG |
| `example-ThermodynamicsBQS ...` | `Thermodynamics-<model>-output-N.dat` | thermodynamics scanned over a (muB, muQ, muS) range |
| `example-SusceptibilitiesBQS ...` | `Susceptibilities-<model>-output-N.dat` | conserved-charge susceptibilities over the same range |

## The fast anchor

`cpc1.Id-HRG.TDep.out` at T = 150 MeV (ideal HRG, mu = 0):

```
T[MeV]     p/T^4      e/T^4      s/T^3      chi2B          chi4B          chi2B-chi4B
150.000000 0.647513   3.846843   4.494356   8.610235E-02   8.600520E-02   9.715029E-05
```

`p/T^4 ~ 0.65` at T = 150 MeV is the expected order for an ideal hadron gas just
below the QCD crossover, and rises steeply with T as heavier resonances switch on.
`verify_thermalfist.sh --anchor-only` pins p/T^4, e/T^4 and s/T^3 here.

## How the shipped comparator reads these

`test/test_CompareOutputs.cpp` skips the header line, then reads doubles from each
line with `istringstream >> double` and compares column by column with an ABSOLUTE
tolerance (1e-6 by default). Two consequences worth knowing:

1. A row whose first token is a LABEL (cpc3) makes `>> double` fail on that token,
   so the comparator reads NO numbers from that row and compares nothing on it. So
   the shipped cpc3 comparison only checks that the row counts match, not the
   numeric columns. This is an upstream comparator limitation, not something this
   skill can fix; it is why cpc3 always "passes" its Compare test. The tier-1
   evidence rests on the cpc1/cpc2/EoS tables, which are fully numeric and fully
   compared.
2. The comparison is a TOLERANCE, not a byte match. Upstream itself marks cpc1 as
   possibly non-deterministic across compilers (the `INCLUDE_ALL_TESTS` option
   switches cpc1 to exact `compare_files` and warns about it), which is why the
   default is the tolerance comparator. State the benchmark as "reproduces the
   shipped reference within the code's own 1e-6 comparator", never as bit-identical.
