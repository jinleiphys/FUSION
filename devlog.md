# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.

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
