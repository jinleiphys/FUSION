# NLAT failure modes

Ways to get a wrong or missing result that looks normal. Verified while building
this skill on 2026-07-21 unless marked as an upstream statement.

## 1. Running a shipped deck in place destroys the reference you would compare against

Each distributed deck names its own output **directory**, and that name is the
sample directory itself (`LOCAL_SAMPLE`, `NONLOCAL_SAMPLE`). Run the deck from
inside the unpacked tree and NLAT writes its results directly on top of the
distributed reference output. Every later comparison then compares the run
against itself and passes trivially.

This is the CCFULL false positive in a new costume, and it is more dangerous
here because NLAT genuinely ships reference output worth comparing against, so
the temptation to "just run it and diff" is real. `run_nlat.sh` always runs in a
fresh workdir, and refuses outright if the workdir is inside the install tree or
if the deck (after symlink resolution) lives inside the workdir.
`verify_nlat.sh` additionally fingerprints the reference files by **content**,
with sha256, before and after the run, and aborts the comparison if anything
changed. An earlier version hashed `ls -l` output, which would have missed an
overwrite that preserved size and mtime.

## 2. The deck is a conditional interview, not a fixed layout

`front_end.f90` decides what to read next based on what it has already read.
A transfer deck contains a Q-value line that a bound-state deck does not; a
nonlocal deck contains parameter blocks that a local deck does not. All reads
are list-directed, so inserting or deleting a line raises no error and silently
reinterprets everything after it. Edit decks value by value, never by adding or
removing lines, or regenerate with `make-input`. Detail in
`references/input-reference.md`.

## 3. The output directory name is passed to a shell

`main.f90` builds `'mkdir ' // trim(Directory)` and calls `system()` on it with
no quoting. A name with spaces or shell metacharacters misbehaves. Both
`Directory` and the `command` string it is spliced into are `character(LEN=50)`,
and the six-character `'mkdir '` prefix eats into the same buffer, so the
**effective limit is 44 characters**. Keep it plain and short.

## 4. Empty output files are normal, and they are a false-positive vector

NLAT creates every enabled output file whether or not the corresponding
calculation ran. A local-only run still leaves `NonlocalBoundWF.txt`,
`DeuteronNonlocalIntegral.txt`, `NucleonNonlocalIntegral.txt`,
`DeuteronNonlocalSmatrix.txt` and `NucleonNonlocalSmatrix.txt` at **zero bytes**,
and the distributed `LOCAL_SAMPLE` reference contains exactly those five empty
files. So "the file exists" proves nothing, and "empty reference equals empty
output" is not a passed check. `compare_nlat.py` reports an empty reference as
SKIPPED, never as a match, and fails outright if nothing was actually compared.

## 5. `beta` must be 0.05 fm, never 0, for the local limit

The analytic Gaussian nonlocality kernel divides by `beta`, so zero is a
division by zero rather than a clean local limit. The paper's own local-limit
test uses **0.05 fm**.

## 6. `CutL` does not exist in the released code, and the paper's advice cannot be followed as written

Wave functions are zeroed below `r = StepSize * CutL * L`. The paper (Sec. 6.4,
Fig. 6) reports that the default `CutL = 2`, calibrated for a 0.05 fm step, must
be raised to 3 at the recommended `StepSize = 0.01` fm or the transfer angular
distribution comes out wrong.

**But AFAY_v1_0 exposes no `CutL` input at all.** A case-insensitive search for
the string across the whole distribution returns nothing, and the value is
hardcoded in `SOURCE/nm.f90`:

```fortran
nmin = int(2*L)
```

So the released code is permanently at the equivalent of `CutL = 2`, and the
paper's own recommended step size is unsafe as shipped unless you edit that line
and rebuild. Treat this as an upstream inconsistency between paper and code, not
as a setting you can put in a deck. The two distributed decks both use
`StepSize = 0.01`, so the shipped benchmarks inherit whatever bias this causes;
that is a property of the reference output, and reproducing it is still the
right check for a skill.

## 7. The nonlocal reference output is stale relative to its own deck

`NONLOCAL_SAMPLE/TransferCS.txt` is dated 2016-04-12; the deck it ships with,
`dp48Ca_20-0_NL.in`, is dated 2016-05-13. The reference has 180 angles, the
current deck and code produce 179, and the 179 shared angles agree to 1.3e-12.
The `LOCAL_SAMPLE` reference is same-day as its deck and matches exactly.

So a strict file-level diff of the nonlocal case fails on a packaging fault, not
on physics. `verify_nlat.sh` declares this one deviation with both token counts
pinned, so the overlap is checked and any other length change still fails. Do
not generalise the exception: if a future run produces a different count, that is
a real regression.

## 8. The paper's headline accuracy is an abstract-only claim

The abstract states "cross sections with 4% accuracy" and a validity range
`Ed = 10` to `70` MeV. **Neither is derived or restated anywhere in the body.**
What the body actually reports is three separate component checks: local elastic
against FRESCO agreeing to better than 3 percent (Sec. 6.1), bound-state wave
functions against FRESCO to better than 2 percent (Sec. 6.2), and the nonlocal
adiabatic source against an independent Mathematica evaluation to better than 2
percent (Sec. 6.3). Quote those three; do not present 4 percent as an
established, independently verified figure.

## 9. Interactive input generation

`make-input` prompts on stdin. Any harness driving it must feed stdin explicitly
rather than letting it inherit a terminal, which is the CCFULL trap. This skill
sidesteps it entirely: the two shipped decks are used as templates and edited in
place, and `make-input` is never invoked by the wrapper.

## 10. Disk

The paper warns a full output set can reach **100 GB**. Even the shipped 48Ca
cases write about 48 MB, dominated by the scattering wave function and integral
dumps at 10 to 14 MB each. Turn off the print flags you do not need; the flags
are the last 19 lines of the deck.

## 11. Build notes

The gfortran makefile already carries `-std=legacy`, which is required: the
package mixes free-form `.f90` with fixed-form `.f` and `.for` sources. The
makefile's `install` target does `mv NLAT ../`, so the binary lands beside
`SOURCE/`; its `cp -fp NLAT $(HOME)/bin` line is commented out upstream, so
nothing is written outside the install root. Builds clean on gfortran 15.

## 12. The source URL in the paper is dead

The program summary points at `http://cpc.cs.qub.ac.uk/summaries/AFAY_v1_0.html`,
which returns HTTP 502. Elsevier retired the Queen's University Belfast CPC
Program Library and migrated all 3089 programs published 1969 to 2016 to
Mendeley Data. AFAY_v1_0 is at `https://data.mendeley.com/datasets/xnwjvk86bs/1`,
DOI `10.17632/xnwjvk86bs.1`, freely downloadable with no login. A dead pointer,
not a lost code. `install_nlat.sh` fetches from Mendeley and pins the sha256;
the archive's byte count also matches the 15253066 printed in the paper's own
program summary, which independently confirms it is the genuine distribution.
