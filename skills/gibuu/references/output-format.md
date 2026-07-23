# GiBUU output

GiBUU writes its result files into the **current working directory**, not into a
directory named by an option. `run_gibuu.sh` therefore runs it inside the output
directory, and captures stdout as `out.log` and stderr as `err.log` alongside
`jobcard_used.job`.

## Knowing that a run finished

The exit status is not sufficient. GiBUU prints

```
########## BUU simulation: finished
```

on a completed run, and a run stopped early by a namelist problem can still
leave status 0. `run_gibuu.sh` requires that banner.

## Which files are physics and which are lookup tables

A pion-induced run writes eight `.dat` files, and most of the bytes are not
results. The classification below was **measured**, by running the same case
with two different seeds and seeing which files changed:

| file | numbers | changes with the seed? |
|---|---|---|
| `ReAdjust.PlotPot.*.dat` | 324,009 | no, potential plot |
| `massass_nBody.dat` | 10,000 | no, mass-assignment table |
| `DensTab_target.dat` | 8,004 | no, density table |
| `pionInduced_dTheta*.dat` | 906 | **yes** |
| `massAssStatus.dat` | 58 | **yes** |
| `pionInduced_QE_generation.dat` | 42 | **yes** |
| `pionInduced_xSections.dat` | 17 | **yes** |
| `pionInduced_xSections_all.dat` | 3 | **yes** |

So of 343,039 numbers only **1,026** are driven by the Monte Carlo. Any claim
about reproducibility should be stated over those, not over the total, or it
overstates the evidence by a factor of 300.

## The cross-section table, column by column

`pionInduced_xSections.dat` has **15 columns**, and its header is written by a
different code branch than the row, so reading the header alone will mislead
you. From the `write(140,'(20G12.4)')` in `code/analysis/LoPionAnalysis.f90`:

| # | quantity |
|---|---|
| 1 | elab |
| 2-4 | Sigma piMinus, piNull, piPlus |
| 5 | Sigma_QElastic = sum of 2-4 |
| 6 | absorption_xSection |
| 7 | sigma Total = column 5 + column 6 |
| 8 | sigma Total(check), accumulated independently |
| 9 | absorption events (integer) |
| 10 | number of runs (integer) |
| 11-13 | error of quasiElastic(-1:1) |
| 14 | error of absorption_xSection |
| 15 | error of sigma Total |

`scripts/check_gibuu_output.py` is the single implementation of this layout and
rejects a row whose column count is not 15, rather than silently reading the
wrong quantities.

**Columns 7 and 8 agree by construction, not as a physics check**, and
**column 6 goes negative** at modest statistics. Both follow from how the code
defines absorption; see `verification.md` before quoting either.

## Reading a run quickly

```bash
# what GiBUU actually used, as opposed to what the card says
grep -E "^ Seed:|BUU simulation" out.log

# the cross-section row, parsed and checked rather than eyeballed
scripts/check_gibuu_output.py pionInduced_xSections.dat
```
