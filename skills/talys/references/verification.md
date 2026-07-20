# TALYS verification record

Clean-room protocol: fresh `git clone` of the public repository, fresh build,
fresh working directory containing only the deck (never the reference), stderr
captured, and the output actively checked for `TALYS-error` rather than trusting
the exit status.

Date: 2026-07-20. Platform: macOS 15 (Darwin 24.6.0), arm64.
Toolchain: Homebrew gfortran (GCC 15.2.0), `-O2 -w`, built under `LC_ALL=C`.
Source: `github.com/arjankoning1/talys`, shallow clone of `main` (beta of the
TALYS-2.2 series; output headers report `source: TALYS-2.2`).
Reference outputs: the `org/` directories distributed with the code, dated
2026-07-16, i.e. generated from essentially the same revision.

## Verified citations

Both fetched live and cross-checked; CrossRef and INSPIRE agree on every field.

- **Code paper (cite this one).** Arjan Koning, Stephane Hilaire, Stephane
  Goriely, *TALYS: modeling of nuclear reactions*, Eur. Phys. J. A **59**, 131
  (2023). DOI `10.1140/epja/s10050-023-01034-3`.
  Verified: CrossRef 200 (authors, title, journal, volume, year) and INSPIRE
  recid 2669334 (adds article number 131, which CrossRef returns as null).
  The repository README names this as the reference to use.
- **Manual.** Koning, Hilaire, Goriely, *TALYS-2.2 - Simulation of nuclear
  reactions*, IAEA NDS Document Series IAEA(NDS)-0255. DOI
  `10.61092/iaea.jk8k-mm54`, resolved through CrossRef, which returned the title,
  the three authors, and IAEA Nuclear Data Section as publisher. Note this DOI is
  NOT printed inside the PDF and is not findable by plain web search, so CrossRef
  is the only corroboration; an adversarial review pass could not confirm it by
  those two routes. Ships as `talys/doc/talys.pdf`,
  890 pages, tutorial for version 2.22.
- **Historical, superseded.** Koning, Hilaire, Duijvestijn, *TALYS-1.0*, ND2007
  proceedings, DOI `10.1051/ndata:07767`. Verified via CrossRef. This is the
  citation most older papers use. The TALYS-1.x series ended with TALYS-1.97 in
  2023 and development continues only on TALYS-2, so new work should cite the
  2023 EPJA paper instead. Cite the ND2007 one only when referring specifically
  to a TALYS-1.x result.

Note the earlier `AIP Conf. Proc. 769, 1154 (2005)`, *TALYS: Comprehensive
Nuclear Reaction Modeling*, DOI `10.1063/1.1945212`, is indexed by CrossRef with
Koning as sole author; it is a conference talk, not the code reference.

## Result

Five sample cases spanning different physics were run in clean directories and
compared file by file against the distributed `org/` references.

"Exact" below means identical line for line once the `date:` / `user:` headers
and the execution-time line are excluded.

| sample | physics exercised | reference files | exact | differing |
|---|---|---|---|---|
| `n-Nb093-14MeV-full` | full output set: spectra, angular distributions, Legendre, gamma, DDX | 750 | 750 | 0 |
| `n-Sn120-omp-KD03` | Koning-Delaroche optical model over an energy grid | 449 | 430 | 19 |
| `n-Th232-fis-wkb` | fission, WKB barrier penetration | 128 | 128 | 0 |
| `n-Os187-astro-ng` | astrophysical (n,gamma) reaction rates | 37 | 37 | 0 |
| `p-Mo100-medical` | proton-induced medical isotope production | 74 | 74 | 0 |
| **total** | | **1438** | **1419** | **19** |

Of the 1438 reference files, **1419 are byte-for-byte identical** once the
`date:` / `user:` header lines and the reported execution time are excluded.

The remaining 19 are all in the `n-Sn120-omp-KD03` case: its `talys.out` (which
differs only in the reported execution time) and 18 data files. Those 18 were
compared numerically:

| magnitude class | numbers | max relative difference | agreement |
|---|---|---|---|
| physical observables, abs > 1e-2 | 4633 | 1.0e-06 | ~6 significant figures |
| abs > 1e-4 | 6509 | 1.4e-03 | ~3 significant figures |
| everything, including near-zero | 17217 | 1.0 | meaningless |

The ~6-significant-figure figure on genuine observables is exactly the precision
of TALYS's `1.234567E+00` output format, so those files agree to the last printed
digit or one unit in it. The apparent total disagreement in the bottom row is a
single class of entries: populations that are numerically zero, where one
platform writes `0.000000E+00` and the other `-7.629395E-06`. That constant is
exactly 2^-17, a float32 rounding residue, not a physics difference.

Honest summary: **TALYS reproduces its own distributed reference output
bit-for-bit on four of five cases, and to the last printed digit on the fifth.**
(Count independently re-derived by an adversarial review pass, which corrected an
earlier draft figure of 1415; the discrepancy was a sloppy shell filter matching
"date" as a substring, not a physics difference.)

## Adversarial review (Codex, 2026-07-20)

An independent falsification pass was run against this skill. It confirmed the
three traps below, the path-length arithmetic, the Sn120 numerical agreement, and
that `input-format.md` matches the shipped manual on the seven rules and the four
`energy` forms. It found six real defects, all since fixed:

1. **`run_talys.sh` could run a stale deck and report success.** With an empty
   source directory and a workdir left over from a previous run, the copy failed
   silently (`|| true`) and TALYS ran the OLD `talys.inp`, exiting 0. This is the
   same false-positive class the skill is written to prevent, in the skill's own
   harness. Fixed: the copy is checked, the workdir is wiped, and a missing
   `talys.inp` in the source is a hard error. (Fixing this then introduced a
   self-destruct bug, because `verify_talys.sh` passes the same path as both
   source and workdir and the wipe deleted the input; now guarded by comparing
   resolved absolute paths.)
2. **Sample count was wrong**: 61 case directories, not 62. The 62nd is `plots`,
   which is not a case.
3. **The no-argument listing used a GNU-only grep alternation**
   (`grep -v '^verify$\|^README$\|^plots$'`), which BSD grep does not honour, so
   `README` and `verify` leaked into the list. Replaced by selecting directories
   that actually contain `org/` and `new/`.
4. **The exact-file count was wrong**: 1419, not the 1415 first written here. The
   error was mine: a shell comparison filter matched "date" as a substring
   (catching words like "update") and manufactured four spurious differences.
   Re-derived independently and corrected throughout.
5. **Attribution imprecision**: the 132-character limit that matters for the
   install root is `codedir` in `source/machine.f90`, not `path` in
   `A0_talys_mod.f90`. Both are `len=132`; the citation was to the wrong one.
6. **The locale claim was too broad.** It is not "any UTF-8 locale": `C.UTF-8`
   uses byte collation and globs correctly. It is locales with case-insensitive
   collation, such as `en_US.UTF-8`.

One point remains open rather than fixed: the review could not corroborate the
manual's DOI `10.61092/iaea.jk8k-mm54` by web search or from the PDF text. Our
CrossRef resolution did return a full record for it, so it is recorded here as
CrossRef-verified and single-source, not as independently confirmed.

## Three traps, all of which produce a confident-looking wrong result

### 1. The build silently drops 13 source files unless LC_ALL=C is set

`source/Makefile` collects its sources with

```make
fsub = $(shell echo [A-z]*.f90)
```

`[A-z]` is a **collation range**, not an ASCII range, and `$(shell ...)` runs it
through `/bin/sh`. The behaviour is locale-specific, and not simply "UTF-8": under
`en_US.UTF-8` the collation is case-insensitive so lowercase `a` sorts before
uppercase `A` and the range starting at `A` excludes every file beginning with a
lowercase `a`, whereas under `C.UTF-8` (byte collation) the glob is complete.
Measured in this tree under `en_US.UTF-8`:

```
/bin/sh -c 'echo [A-z]*.f90'            -> 349 files
LC_ALL=C /bin/sh -c 'echo [A-z]*.f90'   -> 362 files
ls *.f90                                -> 362 files
```

The 13 lost files are `abundance`, `adjust`, `adjustf`, `aldmatch`, `angdis`,
`angdisrecoil`, `angleout`, `arraysize`, `astro`, `astroinit`, `astroout`,
`astroprepare`, `astrotarget`, plus `afold.f` from the companion `.f` glob. The
build then fails at link with undefined symbols `_abundance_`, `_adjust_`,
`_afold_`, `_aldmatch_`, and so on, which reads like a broken source tree rather
than a locale problem.

`install_talys.sh` builds under `LC_ALL=C` and additionally asserts that the
glob sees all sources, refusing to build if it does not.

### 2. The install path must be short, or TALYS fails at run time

TALYS stores its code directory in
`character(len=132) :: codedir` (`source/machine.f90:23`, which then builds
`path` in `A0_talys_mod.f90:190`, also `len=132`) and appends relative paths of
up to 69 characters
(`structure/fission/ff/langevin4d/Sg288/Sg288_1.00e+01MeV_langevin4d.ff`). Install
somewhere deep and the filename is silently truncated, producing

```
TALYS-error: Error in /very/long/path/.../talys/structure/op
             IOSTAT =      2
```

The truncation lands at exactly 132 characters. This was hit for real: a
120-character install root left 12 characters for the filename. The budget is
therefore **63 characters for the code directory**, meaning `$TALYS_ROOT/talys/`
rather than `$TALYS_ROOT` alone, and `install_talys.sh`
refuses to install above that rather than letting it fail later.

A related symptom that appears first: a flood of `TALYS-warning: Duflo-Zuker
mass for ...` lines, which means the mass tables could not be read and TALYS is
falling back to a mass formula.

### 3. TALYS exits 0 even when it aborts

This is the dangerous one, and it is the same class of trap as the CCFULL
false-positive.

```
$ talys < talys.inp > talys.out; echo $?
0
$ grep -c TALYS-error talys.out
1
```

A fatal error is reported **only in the output file**. A harness that checks
`$?` will record a calculation that produced nothing as a success. In the run
that exposed this, the deck used `energy energies` and the auxiliary `energies`
file had not been copied; TALYS aborted after writing 4 files instead of 451,
and still exited 0.

`run_talys.sh` therefore greps for `TALYS-error` on every run and fails on it
regardless of the exit status, and also warns if the success banner
("The TALYS team congratulates you with this successful calculation") is absent.

Corollary, which caused the above: **copy the whole `new/` directory of a sample
case, not just `talys.inp`.** Several cases ship an `energies` grid file that the
deck references by name (manual, keyword reference p.305, option 2: the file must
be "present in your working directory").

## Cost

The clone is about **11 GB**: the nuclear structure database is 8.6 GB and the
sample set 432 MB. This is by far the largest FUSION per-code skill footprint and
is unavoidable, since TALYS cannot run without the structure database. A shallow
clone does not help because the size is in the working tree, not the history.
Build time is about 25 seconds. The n-Nb093 full sample runs in ~2.4 seconds.
