# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

## 2026-07-21: "email the authors for the missing reference output" was the wrong plan for two skills at once

**Why we tried it:** pikoe and AZURE2 both ship without reference output, and the
2026-07-20 tier ruling treated that as the thing separating a tier-2 skill from a
tier-1 one. The plan that followed was to ask the authors: Yoshida for pikoe's
missing `tbl_*.dat` / `*.outlist`, deBoer for an AZURE2 `.azr` example set. Both
were written into TODO as actions, and the AZURE2 one was recorded as the
**top** action unblocking a paper-gating row.

**What failed:** the reasoning, not a run. The user pushed back twice, and both
pushes were right.

The first: a reference output is produced by the **same source** as your own run,
so it cannot certify physics. If pikoe has a genuine physics bug, that bug is in
the authors' reference too, and reproducing their numbers to 12 digits confirms
only that both builds executed the same wrong code. What a reference output
actually certifies is **build integrity**, and cross-compiler reproduction
certifies that same property across strictly more configurations. Measured:
macOS ARM64 gfortran 15.2.0 against Linux x86_64 gfortran 13.3.0, at `-O2`,
`-O0`, and `-finit-real=snan -finit-integer=-99999`, produced **bit-identical
output across all six builds**, 5642 numbers per comparison. `-O0` vs `-O2`
agreement rules out optimization-sensitive UB. The snan run plus a comparator
that rejects non-finite values rules out any uninitialized variable reaching the
output. No single reference file states anything that strong.

The second: an R-matrix case is **fully specified by published numbers**, so the
input is constructed from the paper rather than obtained from the authors. The
AZURE2 paper devotes Sec. IV to three worked examples and tabulates the complete
fits (Table V for ¹⁶O(p,γ)¹⁷F, Table I for ¹²C+p, Table IV for ¹⁴N(p,γ)¹⁵O S
factors totalling 1.81 keV b). Table IV is the valuable one: it is a table of
**results**, so it supports comparing digits rather than reading a plot, which is
a better anchor than pikoe has ever had. A fourth fully specified case sits in
deBoer's TALENT material with levels from TUNL/NNDC and data from EXFOR.

**Root cause:** the tier framework from 2026-07-20 quietly conflated two separate
properties, "did my build come out right" and "is the physics right", and made a
distributed reference file the single gate for both. Once they are separated, the
reference file is revealed as the weaker instrument for the first and no evidence
at all for the second. The framing then propagated into two skills and into a
paper-gating TODO before anyone questioned it.

**Lesson:** when a dependency on an external party appears in a plan, check what
property it is actually supposed to establish before writing the email. Here the
answer was "build integrity", which is obtainable locally in about ten minutes of
compute across two machines, and "physics correctness", which the authors' own
output could never have supplied. Two blockers dissolved and neither email needs
sending. Generalized into the Key decisions in CLAUDE.md.

**Also caught, by the cross-build test rather than by review:** `install_pikoe.sh`
wrote `.mod` files into the source directory, so a rebuild after any gfortran
upgrade dies on "Cannot read module file ... created by a different version of
GNU Fortran", which names neither cause nor fix. That is a live user-facing bug
on every compiler upgrade, and it surfaced only because the same source was
compiled by two gfortran versions. Fixed and verified against a deliberately
corrupted module file.

**Status:** Abandoned (both emails). Replaced by cross-build reproduction plus
published-table anchoring.

## 2026-07-21: GEF clears the fission row, and brings a fifth way for a failed run to look successful

**Why we tried it:** GEMINI++ was dropped that morning for failing the
publicly-obtainable rule, leaving GEF as the only candidate for the paper's
fission/statistical row. If GEF had also failed, the paper's cross-subfield
claim would have had to narrow from four subfields to three, so this was a
gate-deciding check rather than routine catalog work.

**Result: it clears, on every criterion.** GPL-3.0 (`License.txt` in the
tarball), anonymous direct download with no registration wall, actively
maintained (24 archived versions, 2025/1.4 released three weeks before the
check), and the citation verified live against CrossRef rather than from memory:
Nucl. Data Sheets **131**, 107-221 (2016). It was then actually run, not merely
licence-checked, and ²⁵²Cf(SF) gave nu-bar 3.8207 against the evaluated 3.7676.

**The new false-success mode, and it is a good one.** A rerun of an
already-completed case produced no output, printed "GEF is terminated", and
**exited 0**. The cause is `ctl/done.ctl`, a memo file listing finished cases,
which GEF silently skips on a later run. A wrapper keying on exit status, or on
the presence of the banner, would have recorded a calculation that did nothing as
a success. There is a second, quieter version of the same hazard: a `Fitpar.dat`
left behind by any earlier `FIT(...)` run is picked up on the next run and
silently overrides the shipped defaults, so a "clean" run can be using fitted
parameters from an unrelated earlier job.

That makes five distinct mechanisms across five codes: CCFULL leaves a stale
reference file, GSM exits 139 with empty stderr, TALYS exits 0 on a fatal error,
pikoe opens every output file at zero bytes, and now GEF memoizes completed work
and skips it. The rule stated after pikoe (**verify content, never presence, and
never status**) survives contact with a fifth instance, but GEF adds a corollary
worth stating separately: **a scientific code may carry state between runs, so a
clean room means clearing that state, not just clearing the output directory.**
The first attempt here removed `out` and `.ctl` and missed that the directory is
`ctl/`, which is exactly how the trap fired.

**A self-inflicted one worth recording too:** a remote cleanup used
`pkill -f GEF64`, which matched the ssh session's own command line (it contained
the string `GEF64`) and killed the shell before it did any work, producing a
completely silent no-op. `pkill -f` matches the invoking command too; on a remote
one-liner that is a self-kill.

**Cost of the row, honestly stated:** GEF is **Linux-only** for our purposes.
The source is FreeBASIC (33 `.bas` files), `fbc` is not installed and has no
Homebrew formula, and the shipped binaries are ELF Linux plus a Windows `.exe`
with no macOS build. Running the shipped `GEF64` on heliumx sidesteps the
toolchain question entirely and is where heavy compute belongs anyway, but it
makes this the first platform-pinned row in the benchmark, which the harness
design has to absorb rather than assume away. And like pikoe and AZURE2, GEF
ships plenty of input decks (97) and **no reference output**, so tier 1 is not
reachable from the distribution alone.

**Status:** Openness and feasibility resolved; skill not yet built. Fallbacks
(TALYS's fission channel carrying the row, or narrowing to three subfields) are
withdrawn.

## 2026-07-21: the same guard bug, in the script whose comment cites the same guard bug

**Why we tried it:** Seventh per-code skill, NLAT (Titus, Ross, Nunes, CPC 207,
499 (2016)), second of the Wave 1b batch, built the same day as pikoe.

**What failed:** Codex confirmed 21 defects. The one worth the entry: the
`rm -rf` guard in `run_nlat.sh` tested whether the **install contained the
workdir**, when the destructive case is the **workdir inside the install**.
Pointing the workdir at `LOCAL_SAMPLE` deleted the distributed reference output;
pointing it at `SOURCE/` deleted the source tree. Worse, after `SOURCE/` was
wiped the directory still existed, so `install_nlat.sh`'s
`[ -d "$SRCDIR/SOURCE" ]` short-circuit kept returning the broken install as
valid, making the damage unrecoverable without a manual purge.

This is the identical defect pikoe shipped with a few hours earlier, in a
function whose comment reads "Getting this wrong once destroyed 50 MB of data
tables in the pikoe skill."

Two more false-pass vectors in the same review. An all-NaN output file was
reported as a **perfect match**: every comparison against NaN is false, so
`d > worst` never fired and the worst-difference counter stayed at zero. NaN is
the characteristic output of a diverging iterative solve, and an iterative
nonlocal solve is precisely what NLAT does, so the comparator was blind to the
single most likely real failure. And the reference "fingerprint" that was
supposed to prove the run had not overwritten the references hashed `ls -l`
output, i.e. permissions, size and mtime, so a content change preserving size and
mtime was invisible.

**Root cause:** Writing a lesson down, and even citing it at the point of use,
does not transfer the lesson. The pikoe entry from the same day says "every
destructive command needs its guard written against its own literal argument".
The NLAT guard was then written against the wrong operand while quoting that
sentence. What actually caught it, both times, was an adversarial agent running
the script with a hostile argument. The written rule is worth keeping, but it
should be understood as a prompt for the test, not as a substitute for it.

**Lesson:** For any destructive operation, the test is cheap and the reasoning
is not. Write the repro first: point the workdir at the install, at the sample
directory, at the deck's own directory, and through a symlink, and confirm each
one refuses. Four `run_nlat.sh` invocations would have caught this before Codex
did. The same applies to the comparator: feed it NaN, feed it a truncated file,
feed it a real 1e-3 discrepancy, and check the exit status each time. All of
those are now in the skill's own repro set.

Second lesson, a repeat of the TALYS one: two numbers in `verification.md` were
wrong, a copy-pasted token count and a headline "worst 5.95e-14" that the table
two lines above contradicted with 2.067e-11. Both came from summarising by hand
rather than from re-deriving through the shipped comparator. The number in a
verification document must come out of the same code path the tool uses.

**A fifth upstream find, from the benchmark itself:** the nonlocal
`TransferCS.txt` reference has 180 angles where the shipped deck and code produce
179. Rather than wave it off as compiler noise, the mtimes settle it: the
nonlocal reference output is dated 2016-04-12, a month BEFORE the deck it ships
with (2016-05-13), while the local reference is same-day as its deck and matches
exactly. The 179 shared angles agree to 1.3e-12. The comparator was NOT relaxed
to absorb this; it takes one declared deviation with both counts pinned
(`--prefix-ok TransferCS.txt:360:358`), and refuses to fire on any other count.
The general principle: when a benchmark disagrees, find out whose fault it is
before deciding what to do about it, and if the answer is "upstream", encode the
exception narrowly enough that a real regression still fails.

**Also worth recording, on the code rather than the skill:** the review surfaced
three genuine upstream defects in NLAT, none of which affect the shipped
benchmarks but all of which affect a user driving the code themselves.
`front_end.f90:476` reads a neutron diffuseness into `DeuteronScatParameters(8,3)`
where `(9,3)` belongs, so a user-defined nonlocal ADWA deck silently gets zero
real-volume diffuseness for the neutron. Print flags 16 and 17 are swapped
between the parser's comments and `diffCS.f90`'s use of them. And the convergence
tolerance the decks label "percent" is a dimensionless relative tolerance, so the
default 0.001 means 0.1 percent, not 0.001 percent. Separately, the paper's
Sec. 6.4 advice to raise the small-radius cutoff from 2 to 3 at
`StepSize = 0.01` fm **cannot be followed in the released code**: there is no
such input, the value is hardcoded as `nmin = int(2*L)` in `nm.f90`, and the two
distributed decks both use 0.01. Worth an email to Nunes.

## 2026-07-21: pikoe, and a guard that watched the wrong path

**Why we tried it:** Sixth per-code skill, first of the Wave 1b optical-potential
batch, built the same day the user delivered the five CPC papers.

**What failed:** Codex's adversarial pass found 24 defects in a skill that had
already passed its own clean-room verification twice. Four were ship blockers,
and the worst is the one worth naming: `run_pikoe.sh` carried a comment saying it
had fixed "the self-destruct failure the TALYS wrapper hit", and it had, for the
exact case TALYS hit. The guard compared the deck's directory against `$WORK/case`
while the `rm -rf` two lines below deleted `$WORK`. So a deck sitting in the
workdir was destroyed before it could be read, and pointing the workdir at the
install tree deleted the binary and 50 MB of data tables. Second blocker: the
success test counted `.dat` files without testing size, and pikoe creates every
output file named in the deck header at zero bytes before computing anything, so
a run that produced nothing reported success. Third: `verify_pikoe.sh MD` printed
`VERIFY OK` having compared zero anchors, because no pin existed for that case.
Fourth: under `set -euo pipefail`, `ls *.dat` on an empty glob aborted the script
before the "no data table" message could print, so the most informative failure
mode produced silence.

**Root cause:** The first is the more instructive one. Knowing a failure shape
and having fixed it once produces a comment claiming immunity, and the comment
then discourages re-reading the code beneath it. The fix had been applied to the
path that appeared in the previous incident rather than to the path the
destructive command actually names. A guard is only meaningful against the exact
argument of the operation it guards.

The second is the fourth consecutive per-code skill where a failed run can look
successful, and each time in a new costume: CCFULL leaves a stale reference file
behind, GSM exits 139 with an empty stderr, TALYS exits 0 on a fatal error, pikoe
opens every output file empty at startup. The common shape is now clear enough to
state as a rule: **verify content, never presence, and never status.**

**Lesson:** Three. First, every destructive command needs its guard written
against its own literal argument, and a comment asserting a class of bug is fixed
should be treated as a claim to re-test, not as evidence. Second, "does the
output exist" is never a completion check for a scientific code; only size and
content are. Third, the review must run the scripts, not just read them: the
`.mod` pollution (gfortran writes module files into the caller's working
directory, so building from the skill directory littered it with six `.mod`
files, which then landed in the first commit) was invisible in review and
obvious in `git status`. Fixed with `-J`.

**Also worth recording:** the benchmark tier came out better than the 2026-07-20
ruling assumed. pikoe genuinely ships no reference output, so the FUSION standard
is unreachable, but its five sample decks are exactly the five figures of the CPC
paper and those figures carry numeric axes. Reading peaks off them gives a real
quantitative check (a few percent, positions to the plotted resolution) rather
than the "builds and looks sensible" of a plain tier-2 skill. Where a paper's
figures correspond one-to-one to its shipped decks, that is a benchmark, and it
is worth checking for before settling for tier 2. The MD case (392A MeV, over an
hour of CPU) was left explicitly unpinned rather than filled in from the figure
by eye; an early draft of the checker did carry two such eyeballed pins, which is
precisely the fabricated-anchor failure the clean-room rule exists to prevent.
