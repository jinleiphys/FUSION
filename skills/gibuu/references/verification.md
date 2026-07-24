# GiBUU verification

**Tier 2.** Measured 2026-07-23/24 on GiBUU release 2025 (patch 5, April 24
2026), with **no source patches on either platform**.

## Why tier 2, stated before anything else

GiBUU ships **no reference output**. There is no `.ref` file, no expected-result
table, and the `testRun` directories in the source tree hold test PROGRAMS, not
comparison data. So the tier-1 route used by SMASH, SWANLOP and CGMF, "reproduce
the numbers the distribution shipped", does not exist for this code. This skill
is tier 2 in exactly the sense pikoe is: its goal is **input alignment**, and it
is verified as builds, runs, reproduces itself, and stays internally consistent.

**No number in this skill is a physics benchmark, and none should be quoted as
one.** Build integrity is carried by cross-build reproduction, per the
2026-07-21 project ruling. Physics correctness is NOT established here, and
saying so plainly is the point.

## Identity

| | |
|---|---|
| paper | Buss et al., *Transport-theoretical description of nuclear reactions*, Phys. Rept. **512**, 1-124 (2012), `10.1016/j.physrep.2011.12.001` (CrossRef-verified) |
| licence | GPL-2.0, the LICENSE file in the distribution is the GPL v2 text |
| pin | `Release 2025, patch 5 (April 24, 2026)` per `version.txt` |
| source SHA-256 | `bed77e069e657254a2e474d304722f568e57c3b4591559c5d132680c83fa3eed` |
| input SHA-256 | `99a5fee2abc7648e69a0fa3a102b1c9e8450e92995c164c6d0ccaeeffd16d067` |

**The pin is weaker than SMASH's and is not dressed up.** GiBUU is distributed
as release tarballs from hepforge and anonymous svn was switched off in 2018, so
there is no commit to pin. What the checksums establish is that the bytes are
the ones this skill was verified against; they do not give the "clean tree at
commit X" property a git pin does. Both checksums were computed independently
from the macOS and the Linux download of the same URLs and agree.

## Builds compared

| | macOS | Linux |
|---|---|---|
| machine | Apple Silicon | heliumx, x86-64 |
| compiler | gfortran 15.2.0 (Homebrew GCC) | gfortran 13.3.0 (Ubuntu 24.04) |
| libbz2 | the macOS SDK | conda-forge prefix |
| GNU find | findutils 4.11.0 as `gfind` | the system `find` |

Neither platform needed a source patch, so the CNOK question of proving a patch
behaviour-preserving does not arise here.

## Cross-build reproduction, and what it is actually worth

The same job card (`002_Pion.job`, pion-induced at 50 MeV) with the same
explicit seed was run on both platforms and **all 8 output files are
bit-identical**. That headline would overstate the result, so it is decomposed
by FILE, which is the robust unit: files were classified as deterministic or
Monte-Carlo-dependent **by measurement**, running the same case with a second
seed and seeing which files changed.

| class | files | roughly how many numbers |
|---|---|---|
| deterministic tables | `ReAdjust.PlotPot`, `massass_nBody`, `DensTab_target` | ~342,000 |
| **MC-dependent output** | `pionInduced_dTheta`, `massAssStatus`, `pionInduced_QE_generation`, `pionInduced_xSections`, `pionInduced_xSections_all` | ~1,000 |

So the honest claim is: **GiBUU's Monte Carlo path is bit-reproducible across
two architectures and two gfortran major versions**, on the five files the seed
actually drives. That is stronger than SkyNet (libm-limited, bit-identity
unattainable) and the same shape as pikoe. It is NOT ~343,000 numbers of
evidence, because 99.7 per cent of those are lookup tables no random number
touches.

**The number counts are approximate on purpose.** An exact "343,039" was
quoted in an earlier version and was false precision: how many numbers a file
holds depends on the tokenizer (a Fortran line-wrapped record can be counted as
one field per token or per wrapped line), and three counting methods gave three
answers. What is exact and reproducible is the per-file classification: **5 of
8 files change with the seed, 3 do not, and all 8 are bit-identical across the
two platforms at a fixed seed.**

## The seed trap, measured in both directions

GiBUU's `initRandom` namelist defaults to `Seed = 0`, and zero does **not** mean
"use zero": `code/numerics/random.f90` reads it as "draw one from
`SYSTEM_CLOCK()`".

| | |
|---|---|
| same explicit seed, twice | physics output **bit-identical** |
| `Seed = 0`, twice | seeds 735342345 and 1426869522, output **differs** |

`run_gibuu.sh` therefore refuses a zero or absent seed unless
`--allow-random-seed` is given. Both directions are checked in `verify_gibuu.sh`
stage 1, and the second one matters: without it, an implementation that ignored
the seed entirely and wrote a constant would pass the first check perfectly.

## The identity that was demoted, and why

The pion output writes the total by two routes, column 7 `sigma Total` and
column 8 `sigma Total(check)`, and they agree. It is tempting to present that as
an independent physics identity, the way the SIDES skill uses the optical
theorem. **It is not, and this was checked rather than assumed.** From
`code/analysis/LoPionAnalysis.f90`:

```
sigma_Absorption = totalPerweight - (perweight of ALL escaping pions)
sigmaTotal       = totalPerweight - (perweight of NON-INTERACTING pions)
sigTot           = sum(sigma_QE) + absorption_xSection
```

The quasi-elastic set is exactly "escaped after interacting", so the two routes
are set complements and agree **by construction**. The identity would hold with
the physics entirely wrong. It is still checked, because catching a lost or
double-counted event is worth having, but it is labelled as a bookkeeping check
everywhere it appears. This is the AZURE2 lesson applied to an identity instead
of a benchmark: audit what produces the number before believing what it seems
to show.

**A related trap.** With modest statistics `absorption_xSection` comes out
**negative** (measured: -8153 mb at one run, -8530 mb at five). That follows
directly from the definition above and is not a bug, but it means the individual
columns are meaningful only in combination. Do not quote column 6 as a cross
section.

## Harness

`scripts/selftest_gibuu.sh`, **50 cases**, seconds, no GiBUU build required
(the runs use a stub executable). Every guard has a negative case that fails
only that guard and asserts WHICH guard fired.

Two rules were applied from the first version rather than after an adversarial
pass, because the SMASH skill spent five rounds learning them:

1. **Every fixture asserts that its own edit applied.** The `Seed=0`,
   no-`initRandom` and no-`path_To_Input` fixtures each check the substitution
   took effect before being used. A fixture that silently failed to change
   anything produces a test that proves the opposite of what it claims.
2. **Every guard was shown to flip.** Disabled in turn, each fails exactly its
   own case:

| guard disabled | case that flipped |
|---|---|
| `Seed = 0` refusal | a card with Seed=0 is refused |
| completion-banner check | a missing banner fails |
| all-zero vacuity check | an all-zero table does not pass vacuously |
| column-count check | a row with the wrong column count is rejected |

**Two defects were found by that discipline during construction**, not by an
adversarial pass afterwards:

- `run_gibuu.sh` captured a python exit status with `rc=$?` on the line after
  the command, which under `set -e` is dead code: the script exited 2 silently
  and the intended message never printed. Restructured into `if ! python3 ...`.
- A selftest marker used a regex alternation (`non-numeric\|not finite`) inside
  a `case` statement, which matches globs, not regexes. It could never fire.

## What the adversarial pass found

One Codex pass, run against the shipped scripts and the real binary. It found
one blocker and eight lesser defects, all fixed, and confirmed the demoted
identity and the eventtype table were right.

- **BLOCKER: `--seed` could be silently ignored.** The effective-seed readback
  grepped the first `SEED=` line anywhere in the file, but GiBUU reads the first
  `&initRandom` namelist. A card with an empty first `&initRandom` and a seeded
  second one, or a stray `SEED=` outside any block, made the wrapper report a
  seeded run while GiBUU used the clock. Both seed injection and readback now
  operate strictly on the first `&initRandom` block. Verified against the real
  binary: the injected seed lands in the first block and GiBUU echoes it.
- **HIGH: `Inf` slipped past the non-finite guard**, which matched only `nan`
  and `infinity`. Fortran writes `Inf`; now matched.
- **HIGH: GiBUU's own fatal line was missed.** Its format is `--- !!!!! ERROR
  while reading namelist "X" !!!!! STOPPING !!` (output.f90:426), and the guard
  required `ERROR` at the start of the line. Now matches the decoration.
- **HIGH: the install fast path could certify a shell-script stub** named
  `GiBUU.x`, because it checked only the stamp and the completion banner, both
  forgeable. A native Mach-O/ELF check now rejects a stub. A compiled fake that
  prints the banner remains indistinguishable without rebuilding; that is
  inherent to by-checksum provenance and is stated, not papered over.
- **MEDIUM: the seed range was int64, but GiBUU's Seed is a 32-bit Fortran
  integer** and aborts above 2147483647 (measured, exit 134). The wrapper now
  bounds the seed to signed int32, so it never accepts a value the code rejects.
- **MEDIUM: the checker read only the last data row and only one sum rule.** It
  now validates every row, and checks both `col2+col3+col4 = col5` and
  `col5+col6 = col7`, so a component-column shift the total-only rule survived is
  caught.
- **LOW: the vacuity guard was exact-zero only**, and the pion-absorption card
  produces totals like -3.7e-11 that are numerically zero; now floored.
- **LOW: the number counts were false precision** (see the note above); replaced
  with the tokenizer-independent per-file split.

The seed blocker is the same shape as everything the SMASH skill kept hitting: a
rule (here "the seed is the first SEED= line") that held for the sample in front
of me and not for the inputs the code actually accepts. It was caught here in
one pass rather than five because the harness ran on the real binary, but it was
NOT caught by construction, which is the honest limit of writing tests against
your own mental model of a Fortran namelist reader.

The verification of the seed injection deserves its own note: it does not stop
at checking that the job card now contains the seed. It checks that **GiBUU
reported using it** (`Seed: 5150` in the run log), because a misspelled Fortran
namelist is silently ignored and a card that looks right can still run with
default physics.
