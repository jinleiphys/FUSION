# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-23: fresco skill unified across FUSION and the global copy; exfor-data is the first research skill

**Direction change (user ruling):** the 2026-07-14 decision that the auto-install
variant lives only in FUSION is **withdrawn**. The global skill and the FUSION copy
are now kept byte-identical and `diff -r` between them must be empty. Both check the
bin dir, then PATH, and build from upstream only if neither has a binary, so a deck
authored in one place runs unchanged in the other. CLAUDE.md line amended in place
rather than appended to, because a stale rule there actively misleads a later session.

**New in the fresco skill: `scripts/omp.py`.** Emits KD02 and CH89 global nucleon
optical potentials as ready-to-paste `&POT` blocks. Pure Python, standard library,
so it needs no Fortran toolchain even though it is a transcription of Fortran.

Why a generator rather than letting the model write the parameters: the formulas are
the easy part, the handoff into FRESCO is not. Three failure modes are silent, meaning
the deck runs and prints a plausible cross section that is wrong. FRESCO builds radii
as `R = r0*(Ap^1/3 + At^1/3)` while KD02 and CH89 are defined on `R = r0*At^1/3`, so
without `ap=0` every radius is ~22% too large. `W_d` must land in `p4` of the `type=2`
line, since `p1` makes it a real surface well and the absorption quietly drops. And a
`type=0` line is required even for neutrons because it is what declares the convention.

**Precision finding worth keeping.** `--selftest` pins 39 values against the reference
Fortran and passes at 2e-7, not machine epsilon. First diagnosis (single-precision cube
root) was wrong and Codex caught it: **every unsuffixed real literal in that kd02.f is
single precision**, so `59.30` enters as `59.2999992370605`. Proof that the cube root is
not the mechanism: neutron `V` contains no cube root at all yet still deviates, and
recompiling with `-fdefault-real-8` matches the Python to 16 digits. The reference
`ch89.f` suffixes everything with `d0` and reproduces exactly. So the Python is the more
accurate of the two and the residual belongs to the Fortran. End to end the generated
deck gives sigma_R = 1301.64017 mb for n+90Zr at 50 MeV, identical to a hand-built deck.

**First research skill embedded: `skills/exfor-data/`.** Drives no code, so the per-code
bar does not apply; see skills-catalog.md for the EXFOR-specific traps (unscriptable
search servlet, fixed-width blank-preserving records, `DATA-ERR` sometimes in per cent,
`COMMON` and `DATA` counting their header lines differently).

**Codex adversarial pass on both:** 3 defects, all confirmed and fixed. (1) the precision
diagnosis above; (2) `omp.py` accepted impossible nuclides, so `--target 90,40` silently
returned parameters for Z=90 A=40 when the user meant 90Zr, now rejected with a message
naming the correct spelling; (3) `exfor.py` documented a header-count consistency check
that the code never actually performed, so a truncated wrapped record vanished silently.
Fixing (3) then exposed that EXFOR counts `COMMON` and `DATA` header lines differently,
which caused 33 false warnings on real entries before both readings were accepted.

## 2026-07-23: SkyNet macOS NSE block-3 is libm-limited, not a flag fix

**Why we tried it:** the full-network NSE (Saha) block at T9=3 reproduced the
shipped reference to 7.0e-3 on macOS against a 3.5e-5 gate. FMA contraction is a
common cause of such cross-platform deltas, so `-ffp-contract=off` was the first
suspect, cheap to test.

**What failed:** `-ffp-contract=off` gave the byte-identical 0.00701498, and -O3
and -O0 also agree. So it is neither FMA contraction nor optimization-sensitive UB.

**Root cause:** Apple libm vs glibc `exp`/`log` differences, amplified through a
Newton iteration over abundances spanning ~200 decades (ni56 ~ 5e-201 at T9=3).
The reference tolerance was calibrated on the authors' glibc platform; the
identical patched source passes 19/19 on Linux, so it is a platform numerical
property, not a build or patch defect.

**Lesson:** a stiff nonlinear solve's tightest reference may not survive a libm
change. Do not chase it with flags or by loosening the passing platform's gate:
reproduce cross-platform, document the delta, and encode the exception narrowly
(other blocks pass on both platforms; the excepted case bounded to a window).
Full reasoning in the 2026-07-23 CLAUDE.md key decision.

**Status:** Parked (documented macOS caveat; SkyNet ships tier-1-with-caveat).
