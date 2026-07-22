# FUSION devlog archive

Older entries moved out of devlog.md to keep the auto-loaded portion under ~5 KB. NOT auto-imported.

## 2026-07-21: four skills, one failure shape, consolidated

Full text of all four entries in `devlog-archive.md`. Consolidated here because
they repeat one theme; every distinct mechanism is preserved below.

**The shape: a failed run that looks successful.** Six distinct mechanisms found
so far, each in a new costume:

| code | how a failure looked like success |
|---|---|
| CCFULL | leaves a stale reference file behind |
| GSM | exits 139 with empty stderr |
| TALYS | exits 0 on a fatal error |
| pikoe | opens every output file at zero bytes before computing |
| GEF | memoizes completed cases in `ctl/done.ctl`, silently skips, exits 0 |
| codex plugin (2026-07-22) | orchestration broker dies, task still reports "running" |

**Rule: verify content, never presence, and never status.** Corollary from GEF: a
scientific code may carry state between runs, so a clean room means clearing that
state (`ctl/`, a stale `Fitpar.dat`), not just the output directory.

**The second shape: destructive-command guards written against the wrong path.**
pikoe's `rm -rf` guard tested `$WORK/case` while deleting `$WORK`. NLAT's tested
whether the install contained the workdir when the danger was the reverse, in a
function whose comment cited the pikoe incident. AZURE2's (2026-07-22) escaped
through a symlinked path component. Three times, the third while quoting the
lesson from the first. **Writing a lesson down, and even citing it at the point
of use, does not transfer it. What caught all three was an adversarial agent
running the script with a hostile argument.** The guard must name the same
operand as the command, and the repro must be written before the guard.

**Verification philosophy, settled 2026-07-21:** the author's reference output is
produced by the SAME source as your run, so it certifies build integrity only,
never physics; a genuine physics bug sits in their reference too. Cross-build
reproduction certifies that same property over more configurations. Measured on
pikoe: bit-identical across macOS ARM64 gfortran 15.2 and Linux x86_64 gfortran
13.3, at `-O2`, `-O0` and `-finit-real=snan`, 5642 numbers. Consequence: do not
email authors for missing reference output. Physics correctness must be carried
separately, by published figures or tables.

**Other findings that must survive:** GEF is FreeBASIC and Linux-only, the first
platform-pinned row. `pkill -f GEF64` on a remote one-liner matches the ssh
session's own command line and self-kills silently. gfortran writes `.mod` files
into the caller's cwd unless given `-J`, which poisons a rebuild after any
compiler upgrade with an error naming neither cause nor fix. NLAT carries three
genuine upstream defects (a `(8,3)`/`(9,3)` index error at `front_end.f90:476`,
swapped print flags 16/17, a tolerance labelled "percent" that is dimensionless)
plus a paper recommendation that cannot be followed in the released code; worth
an email to Nunes. When a benchmark disagrees, find out whose fault it is before
deciding what to do about it, and encode any upstream exception narrowly enough
that a real regression still fails.

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

## 2026-07-20: the TALYS skill's own verification harness had the false-positive bug it was written to prevent

**Why we tried it:** User directive to run Codex adversarial cross-validation on each finished skill instead of shipping on Claude's self-check alone.

**What failed:** Codex falsified six claims in the just-finished TALYS skill. The serious one: `run_talys.sh` staged the deck with `cp "$SRC"/* "$WORK"/ 2>/dev/null || true` and never cleaned the workdir. Given an empty or malformed source directory plus a workdir holding a previous run's `talys.inp`, the copy failed silently and TALYS ran the STALE deck, exiting 0 and printing a success banner. Codex demonstrated it with a two-command repro. Separately, the headline benchmark number was wrong: 1419 of 1438 files reproduce exactly, not the 1415 written; the error was a shell filter matching "date" as a bare substring, so lines containing "update" were dropped and four spurious differences appeared. Also: 61 sample cases not 62; a GNU-only `grep -v 'a\|b'` alternation that BSD grep ignores, leaking README and verify into the case listing; the 132-char limit attributed to `path` in A0_talys_mod.f90 when the one that matters is `codedir` in machine.f90; and the locale claim stated as "any UTF-8 locale" when `C.UTF-8` actually globs correctly.

**Root cause:** The skill carries three prime rules about never trusting exit status, written the same afternoon after the CCFULL and GSM traps. The harness enforcing those rules was then written with `|| true` on its own staging step. Knowing the failure mode in prose does not prevent implementing it fifty lines later; the rule was applied to TALYS's exit code and not to the wrapper's own file operations. The wrong file count has the same shape: a quick shell one-liner was used to produce a number that then got written into a document as a verified result, without the filter itself being checked.

**Lesson:** Two. First, the verification harness needs the same adversarial treatment as the code under test, and specifically: any `|| true`, `2>/dev/null`, or unchecked `cp` in a benchmark script is a false-positive vector and should be treated as a defect on sight. Second, a number that goes into a verification document must come from the same checked code path that the shipped tool uses, not from an ad-hoc shell loop written to answer the question once. Both fixes are in place, and fixing the first introduced a self-destruct bug (the new `rm -rf "$WORK"` deleted the input when source and workdir are the same path, which is exactly how verify_talys.sh calls it), caught only by re-running the regression, which is itself the argument for keeping a regression suite rather than spot-checking.

**Status:** Resolved. All six fixed and re-verified; the 5-case benchmark re-run clean after the fixes. Cross-AI validation promoted to a hard rule in CLAUDE.md.

## 2026-07-20: TALYS, three independent traps that each produce a confident-looking wrong result

**Why we tried it:** Fifth per-code skill, the headline community code of the statistical-model tier.

**What failed, in order:**
(1) The build died at link with a wall of undefined symbols (`_abundance_`, `_adjust_`, `_afold_`, `_angdis_`, `_astro_`). Cause: `source/Makefile` collects sources with `$(shell echo [A-z]*.f90)`. `[A-z]` is a **collation** range, not an ASCII range, and under `en_US.UTF-8` lowercase `a` collates before uppercase `A`, so the range beginning at `A` excludes all 13 files starting with lowercase `a`, plus `afold.f`. Measured: 349 files vs 362 under `LC_ALL=C`. I got this diagnosis right first, then talked myself out of it by testing the glob in zsh and bash (both return 362) instead of in `/bin/sh`, which is what make actually uses. Testing in the wrong shell cost a round.
(2) With that fixed, every run aborted with `TALYS-error: Error in <path>/structure/op, IOSTAT = 2` after a flood of Duflo-Zuker mass warnings. Not a missing database: TALYS keeps paths in `character(len=132)` and appends relative paths up to 69 characters, and the scratchpad directory alone is 120 characters, so the filename was being truncated at exactly 132. Entirely self-inflicted by the working directory, and invisible unless you count the characters in the error message.
(3) A sample deck referencing an auxiliary `energies` file aborted after producing 4 files instead of 451, **and still exited 0**.

**Root cause worth naming:** (3) is the CCFULL false-positive in a new costume. TALYS reports fatal errors only inside `talys.out` and always exits 0, so any harness keying on `$?` records a calculation that produced nothing as a success. That is the same shape as the CCFULL trap (a crash that leaves a plausible-looking output file behind) and the same shape as the GSM trap the day before (silent exit 139). Three consecutive per-code skills, three different ways for a failed run to look successful.

**Lesson:** stop treating "check the exit code" as the verification step. For scientific codes the exit code is frequently decorative. The real check is a positive assertion about the output: the expected files exist, the success banner is present, and the error string is absent. `run_talys.sh` asserts all three. Second lesson, from (1): when reproducing a build bug, reproduce it in the **exact shell the build system uses**; `make` uses `/bin/sh`, and testing the same glob in an interactive shell gave the opposite answer and nearly buried a correct diagnosis.

**Cross-validation:** citations were fetched live (CrossRef + INSPIRE agree; EPJA 59, 131 (2023), and note the code is MIT, not GPL as the catalog had recorded), and the input reference was written from the shipped 890-page manual rather than from memory, after the user pointed out that the GSM skill had been written without either check. Codex adversarial review commissioned on both skills.

**Status:** Resolved. 1415 of 1438 distributed reference files reproduce byte for byte across 5 samples; the remaining 18 data files agree to ~6 significant figures, which is the precision of TALYS's own output format.

## 2026-07-20: GSM would not run anywhere on macOS; the cause was an upstream infinite recursion, not the input

**Why we tried it:** Build the Gamow Shell Model book codes (github.com/GSMUTNSR/book_codes) for the fourth per-code skill and reproduce the book's own exercise outputs.

**What failed:** Three separate walls, in order.
(1) Apple clang refuses to compile numlib at all: it eagerly checks out-of-line template definitions against their declarations, and two in `total_diagonalization.hpp` genuinely do not match (a stray parameter, and `X.table` for `X.r_table`). GCC never noticed because those templates are never instantiated. GCC 15 then rejected the same code for the same reason via its new `-Wtemplate-body`.
(2) Homebrew GCC could not find `_bounds.h`: its private fixincludes copy of the macOS headers went stale after an Xcode SDK bump.
(3) With those cleared, every run died at `Pole basis states` with **exit 139 and a completely empty stderr**.

**Root cause of (3):** `numlib/complex_add.cpp` defines `finite(const complex<double>&)` and, inside it, calls `finite(x)` on a `double`, intending the legacy BSD `finite(double)` from `<math.h>`. POSIX removed that function in 2008 and macOS does not ship it, so overload resolution implicitly converts the `double` back to `complex<double>` and the function calls itself forever. It is invisible on Linux, where glibc still exposes `finite`. The crash lands in the function *prologue* writing to the stack guard page, so it reads as a memory bug deep in the physics.

**Lesson:** Two of these. First, an empty stderr plus exit 139 is not "no information": `EXC_BAD_ACCESS code=2` at an address in the stack region, with the faulting frame being a prologue, is the signature of unbounded recursion, and `lldb -k "bt"` names the cycle in one shot. Chasing it as a stack-size problem wasted a round, and raising the stack (`ulimit -s`, then relinking with `-Wl,-stack_size`) only moved the crash and briefly changed the signal, which is exactly the misleading evidence to expect. Second, a code that has clearly worked for years for its authors can still be unbuildable on your platform for reasons that have nothing to do with your input; before assuming the deck is wrong, confirm the binary can complete *any* run. Compiler-version drift (clang vs GCC, GCC 15's new eager template diagnostics, SDK-vs-fixincludes skew) is now a routine porting cost for older scientific C++, so the install script pins the workarounds rather than leaving them to the user.

**Status:** Resolved. `install_gsm.sh` autodetects a real GNU g++, adds `-fpermissive` on GCC 15+, prepends the live SDK headers on macOS, and applies the `std::isfinite` patch idempotently. Benchmarks pass in a clean room: 11 / 9 / 8 significant figures on the Chapter 2, 3, and 5 exercises respectively. The `finite()` bug is worth reporting upstream (on the TODO); it breaks every macOS build of the package.

## 2026-07-20: CCFULL benchmark false-positive caught only by a clean-room build test

**Why we tried it:** Verify the CCFULL skill by running the 16O+144Sm example and diffing OUTPUT against Hagino's reference OUTPUT.
**What failed:** The first check reported "bit-identical PASS" but was a FALSE POSITIVE. CCFULL asks interactive y/n questions on stdin (not just reading ccfull.inp); with no stdin it crashes at line 196 ("End of file") BEFORE truncating/rewriting OUTPUT. So the OUTPUT file still held the previously downloaded reference, and diffing it against its own copy trivially matched. The code had not actually run.
**Root cause:** Two compounding traps: (1) CCFULL's hidden stdin interactivity, and (2) verifying in a directory that already contained the reference OUTPUT, so a no-op run looked like a perfect reproduction. The `2>/dev/null` in the run wrapper hid the crash.
**Lesson:** A benchmark is only real if run in a CLEAN ROOM: fresh build from public source, fresh working dir with NO pre-existing reference file, and the run's stderr inspected (never silently discarded). After the real run (stdin fed 'n' answers), the physics reproduced exactly for sub-barrier rows and to 4-5 sig figs at the tail (a code-version rounding difference, honestly stated), not a bogus bit-identical claim. This is now a hard rule for every per-code skill (see CLAUDE.md).
**Status:** Resolved; CCFULL skill ships with the honest benchmark and the stdin quirk documented.

## 2026-07-14: first per-code skill embedded in-repo (fresco), with binary auto-install; cp -R symlink trap

**Why we tried it:** Start the Phase 2 skill pack by pulling the reference fresco skill into the repo (`skills/fresco/`, the layout the README already anticipated) and giving it the missing capability every per-code skill will need: provision the underlying code itself, rather than assuming a pre-built binary at `~/bin/fresco`. Added `scripts/install_fresco.sh` (checks `~/bin`/`PATH`, else clones https://github.com/I-Thompson/fresco and builds `make FC=gfortran`, copies fresco+sfresco to the bin dir) and wired `run_fresco.sh` to call it on first use.

**What failed / trap caught:** The initial `cp -R ~/.claude/skills/fresco skills/fresco` did NOT embed the files. `~/.claude/skills/fresco` is itself a symlink to `~/Desktop/claude_skills/skills/fresco`, and BSD `cp -R` copies a command-line symlink AS a symlink, so `skills/fresco` became a dangling-on-clone symlink and every subsequent edit wrote THROUGH it into the shared live skill repo, not into FUSION. Codex cross-review flagged it (its finding #2). Verified: `ls -ld` showed the symlink; the edits had landed in `~/Desktop/claude_skills/skills/fresco` (untracked there, so nothing committed was clobbered).

**Root cause:** BSD vs GNU `cp` semantics on a symlinked source; on macOS `-R` alone preserves the top-level symlink (need `-RL` to dereference). Compounded by the fresco skill being a symlink, which was invisible until Codex checked the inode.

**Lesson:** When "embedding" a skill/dir into a shippable repo, use `cp -RL` (or verify with `find -type l` after) so the result is real files, not a symlink that dies on `git clone`. Build+verify against a published anchor before trusting a freshly compiled binary: the gfortran build reproduced B1-elastic sigma_R = 1575.17495 (ref 1575.175). Cross-AI review earns its keep on filesystem/portability bugs a single agent misses.

**Status:** Resolved. `skills/fresco/` is now a real self-contained copy with auto-install; the global skill was reverted to pristine (the auto-install variant lives only in FUSION). Applied Codex fixes #1 (preserve FRESCO exit code), #12 (absolutize binary path before cd), #4 (recheck both binaries post-install), #16 (EXIT-trap the verify tmpdir), #17 (validate deck before any clone). Deferred as over-engineering for a single-user research wrapper: install locking, atomic rename, pinned commit, unique scratch dir.

## 2026-07-20: semantic full run made ZERO progress for 3 nights; KINGSTON .tex read hung the batch

**Why we tried it:** Weekend auto-finish of the last 3,181 semantic-layer papers via the off-peak launcher.
**What failed:** Three consecutive off-peak windows (Fri/Sat/Sun) each opened, started `full --workers 40`, and produced ZERO new edges; relations.tsv was byte-identical Friday to Monday, stuck at 51,197/54,378 citing papers. A manual `full` run confirmed: the first ~20 papers classify fast, then all workers freeze, and after 4 minutes there were 0 API-timeout fallbacks (so the hang was NOT the API).
**Root cause:** The hang is in `extract_citation_context` reading each citing paper's .tex from the KINGSTON exFAT drive. File I/O has no timeout, so a pathological/slow .tex read blocks a worker forever. The remaining 3,181 papers are all recent (2025-2026) whose edges came from the INSPIRE backfill; their .tex uses external `\bibliography{}` with no inline cites, so context extraction was both useless (nothing to find) AND the thing that hung. The API 300s timeout was a red herring (never reached).
**Lesson:** File I/O in a worker pool needs a timeout or a size/skip guard, same discipline as network calls. For backfill papers there is no .tex context to extract by definition, so skip it. Fix: added `--no-context` (classify on titles+abstracts, no .tex read) which cleared the 3,181 in ~3 minutes at ~19 papers/s; also lowered the API timeout 300s->60s and made a 3-retry failure write a background fallback so a poison paper is marked done instead of re-poisoning every future window.
**Status:** Replaced by --no-context path; semantic layer completed 2026-07-20.

## 2026-07-15: newest papers have near-empty citation edges (external .bib not in corpus)

**Why we tried it:** User asked whether the overnight digest increment got cross-referenced. Spot-checked the newest paper (2606.18165) then the last 500 ids in the date-sorted list.

**What was found:** The increment IS structurally cross-referenced: all 61,059 pages carry `## In-corpus citations` sections (inject_citations ran over the full corpus this morning) and 43,489 carry concepts frontmatter. BUT the citation EDGES for the newest papers are largely empty: the last 500 ids show 27% citation-graph coverage vs 81% corpus-wide. Direct cause measured: of those 500, 360 (72%) use external `\bibliography{}` with no inline refs; only 134 have inline `\bibitem`, and 27% coverage matches that 134/500. 2606.18165's .tex has zero arXiv ids or DOIs.

**Root cause:** The corpus (KINGSTON) stores only .tex, no .bib/.bbl. Recent papers are preprints submitted with an external `\bibliography{refs}` + separate .bib, so their .tex contains nothing extractable. Older papers went through journal production and carry an expanded .bbl / inline `\bibitem`, so kb_citegraph extracts them fine. The gap is therefore concentrated in the newest ~2 years and is a source-availability limitation, not a processing bug. kb_citegraph correctly scanned all 61,357 tex dirs; there was simply nothing to find in the preprint sources.

**Lesson:** .tex-only citation extraction has a hard ceiling on recent preprints. Do not chase it in the parser. The right fix is a different source: INSPIRE references API (structured, zero LLM tokens) for the ~11,489 zero-edge papers, mapped to corpus ids and merged into citations.tsv. Logged as a TODO, not yet run. Also note: the semantic layer (L3) feeds on citations.tsv, so it inherits this gap for recent papers until the backfill runs.

**Status:** Parked (INSPIRE backfill is the fix, on the TODO; parser is working as designed).

## 2026-07-14: Night 3 digest QC passed; +16,893 pages committed (53,258/61,059 total)

**Why we tried it:** Third off-peak digest window (00:30-08:25) produced 16,893 new paper pages, untracked. Before committing them, ran the Phase 3 QC protocol (log check, structural conformance, failure-mode scan, cost reconciliation) rather than committing blind.

**What was found:** Clean. Run log shows fail=0 across the whole night and a clean 08:25 deadline stop. Of the 16,893 pages: 0 empty/truncated/corrupt, 100% carry frontmatter + digest_date 2026-07-14, 100% carry the digest sections. Failure-mode scan turned up only false positives: the 101 `\cite{}` hits are all inside quoted source abstracts (not digest prose; one is Lei's own four-body IAV paper), and the AI-refusal / API-error hits are substring collisions with physics text (Drude formula, rate parameter). Token rate in~10.3k/out~666 per paper matches the 500-paper pilot; ~$29 off-peak.

**Root cause of the one real blemish:** ~52 pages (0.3%) render the digest headings as h3/h1 instead of h2 (one merged the "Key claim" heading into the H1 title line). Cosmetic model-output variance in DeepSeek's markdown; this variant did NOT appear in the night-1/night-2 committed pages, so it is new to this batch. Content underneath is intact.

**Lesson:** Commit the corpus in per-night batches with a QC gate, not blind; the gate is cheap (grep-level) and catches structural drift early. The h2/h3 drift is worth a one-line normalizer in the digest post-step or template if it recurs; not worth a rewrite for 0.3%. Keep the corpus commit scoped (kb-wiki/papers only, logs .gitignored) and separate from code/skill commits.

**Status:** Committed (f53d123c) and pushed. Run INCOMPLETE: 7,801 papers remain (53,258/61,059); the self-looping launcher resumes next off-peak window on skip-existing, so the "morning verification" TODO stays open by design.

## 2026-07-09: KB wiki form pivoted from DB-rendered + digest-on-touch to pre-generated md

**Why we tried it:** The first L3 design rendered pages from SQLite on demand through an MCP server, digesting papers only when touched, on the assumption that bulk-digesting 62k papers was cost-without-demand.
**What failed:** Nothing failed technically; the premise was wrong. Measured on the 500-paper pilot: 10.7k tokens in / 0.6k out / 8 s per paper, $1.74 per 500, so the FULL corpus costs ~$218 standard / ~$109 off-peak. At that price pre-generation strictly dominates: plain md files, grep/read access identical to the personal literature-wiki workflow, no server dependency, trivially shippable.
**Root cause:** Cost estimate made before measuring; the design guarded against an expense that turned out to be two dinners.
**Lesson:** Run the 100-sample cost measurement BEFORE designing around cost. Also: the user calls this instinct correctly ("反正用deepseek做，成本也很低"); check premises against the cheapest available model first.
**Status:** Replaced by pre-generated md wiki (kb-design.md L3, revised 2026-07-09; MCP server demoted to optional sugar).
## 2026-07-13, disabled inherited upstream community-bot workflows on the fork

**Why we tried it:** The daily `close-issues` workflow on jinleiphys/fusion-core failed with `403 Forbidden` (run #4). Root cause: `script/github/close-issues.ts:3` hardcodes `const repo = "anomalyco/opencode"`, so the fork's cron was trying to auto-close *upstream* opencode's stale issues using the fork's `github.token`. Reading upstream issues is public (worked), but POSTing a comment returned 403 (fork has no write access to upstream, and shouldn't). The log's real opencode issue numbers (#27459, #12723) and opencode maintainers as "exempt" are the tell.

**Scope:** A whole inherited family of upstream community-management bots, none gated to skip forks: close-issues, close-prs (`close-prs.ts:5` same hardcode), compliance-close, duplicate-issues, triage, pr-management, pr-standards, review, notify-discord. (publish/deploy/stats/docs-update already self-gate with `if: github.repository == 'anomalyco/opencode' / 'sst/opencode'`, so they no-op on the fork.)

**Fix:** Disabled all 9 at the repo level via `gh workflow disable <name>.yml`. Chose disable over editing the files because `fusion-weekly-rebase` force-pushes `fusion-brand` onto `upstream/dev` weekly; editing would bloat the brand patch and invite rebase conflicts. Disabled state lives in Actions config keyed by workflow path, decoupled from file content, so it survives the weekly force-push. Files stay byte-identical to upstream (clean rebases); they just never fire. Verified: all 9 now `disabled_manually`; fusion-weekly-rebase / test / typecheck stay `active`. Reversible with `gh workflow enable`.

**Residual (not fixed, flagged):** the `anomalyco/opencode` hardcode still sits in close-issues.ts / close-prs.ts. Harmless while disabled. Permanent root-fix would add an `if: github.repository == 'jinleiphys/fusion-core'` guard into the brand patch (upstream's own pattern), traded against a larger, conflict-prone patch. Deferred until it actually bites.

**Status:** Resolved; daily 403 stopped.

## 2026-07-09, Phase 1 started: fork, brand patch, rebase CI; two decisions + one discovery

**Decisions:**
1. Internal identifiers, config paths (~/.config/opencode), and package names stay "opencode"; the brand patch touches only user-visible surfaces (TUI logo done; icons/name-strings later). Reason: config/skill compatibility with upstream and with existing user setups; a full internal rename would balloon the patch and break the weekly rebase.
2. Fork repo = jinleiphys/fusion-core, default branch fusion-brand (= upstream dev + brand commits); dev kept as pristine upstream mirror, synced by CI.

**Discovery (zero-fork alternative, recorded not chosen):** opencode's TUI has an official plugin slot `home_logo` with mode="replace" (packages/tui/src/routes/home.tsx), so the home logo could be replaced by a FUSION plugin without any fork. User already chose the rebrand fork (needed anyway for icons/desktop/web); the slot is the fallback if fork maintenance ever becomes too costly.

**Scope correction from user (same day):** per-code skills cover the WHOLE open-source nuclear ecosystem, not just reactions codes; skills-catalog.md added as the living roadmap (reactions / statistical-fission / R-matrix-astro / structure / scoped transport-data / Lei family), with openness-verification flags and wave ordering.

**Status:** Phase 1 core done (fork + logo patch + green weekly-rebase CI); remaining = icon graphics, name-string sweep, build/release pipeline.

## 2026-07-09, Phase 0 quality gate run and passed (same day as init)

**Why we tried it:** The whole platform premise rests on skills surviving the move to opencode + domestic models. Gate = 3 skill types on real cases vs Claude reference.

**What happened:** All three passed on deepseek-chat: literature-search reproduced the exact Typel-Baur 2003 BibTeX with wiki-first + INSPIRE + CrossRef chain; fresco built a correct n+90Zr deck (understood the FRESCO cube-root-sum radius convention and pre-scaled radii), agreed with an independent Claude-side FRESCO run to 4-5 significant figures with the residual fully explained by its 4-digit rounding; prc-writing produced a PRC introduction with 10/10 verified citations, zero hallucination, and ran the qu-ai-wei-en pass unprompted. Details in phase0/report.md.

**Lesson (caveats, not failures):** (1) non-interactive opencode auto-rejects out-of-cwd permissions and the run dies silently; FUSION needs a shipped permission config, `--auto` is test-only. (2) opencode's skill loading returned a skill description instead of the body once (literature-wiki call in test 3); cross-skill invocation semantics need verification. (3) BSD grep breaks `grep -P` checks in skills. (4) Benchmark prompts must pin masses and radius conventions.

**Status:** Gate passed on objective criteria; user sign-off pending for Phase 1.

## 2026-07-09, project initialized; naming + architecture decisions from the founding conversation

**Why we tried it:** User wants a nuclear-physics-specific research agent platform built on opencode (github.com/anomalyco/opencode, MIT, 184k stars), integrating the existing ~30 research skills, per-code skills for nuclear open-source software, and a self-contained knowledge base from the local 62k-paper arXiv nucl-th corpus.

**Decisions made (not failures, founding record):**
- Name: FUSION (Framework for Unified Scientific Intelligence in Open Nuclear physics). Rejected alternatives: PION (collides with pion/webrtc GitHub org), FERMI, NORA, CORE, HALO, MENTOR, SCATTER. EMPIRE and TALYS are forbidden as names (existing nuclear reaction codes).
- Architecture: rebrand fork (VSCodium model), NOT a functional fork. Only brand assets change (logo, name strings, icons); functional code stays upstream. CI auto-rebases weekly. All domain capability lives in the customization layer (skills, agents, MCP servers, config), which upstream opencode supports without source changes.
- Knowledge base: reuse the existing literature-corpus pipeline (corpus.db, SQLite FTS5, BM25, query.py) rather than building a new embedding index. Stats verified 2026-07-09: 62714 papers, 61357 with full text, 1992-09 to 2026-06. Lexical-first is a deliberate prior decision of the literature-corpus skill; do not re-propose pre-embedding the whole corpus.
- Personal wiki (~/research-wiki, ~/research-wiki-personal) stays a PRIVATE layer, never shipped. FUSION defines the plug-in interface; each user grows their own wiki.

**Protocol note:** research-planning Steps 3a/3b (literature-wiki query + literature-search) intentionally not run at init: this is a software platform project, the README carries no physics-paper citations, so the wiki coupling has no trigger. If a paper citation ever enters a FUSION file, run the Step 5-wiki ingest protocol at that moment.

**Status:** Active, Phase 0 (quality validation) not yet started.
