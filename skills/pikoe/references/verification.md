# pikoe verification

Established 2026-07-21 on macOS 15 (arm64), gfortran 15.2.0 (Homebrew GCC),
`-O2`, pikoe 1.1 (source file dated 2025-03-14, archive dated 2025-03-18,
sha256 `747119fb...c38fa`).

## Benchmark tier, stated honestly

The FUSION standard for a per-code skill is to reproduce the code's **own**
documented reference values. **pikoe cannot meet that standard as distributed.**
Its `readme.txt` documents a `tbl_*.dat` table and a `*.outlist` record inside
every `sampleN/` directory. Neither is in the archive. This was checked in both
releases: v1.1 contains 22 entries, v1.0 contains 13, and in both the sample
directories hold only the `.cnt` control file. The defect is upstream's and the
authors may not know.

What this skill does instead, in descending order of strength:

1. **Comparison against the published figures.** The five shipped decks are
   exactly the five figures of the CPC paper. The figures carry numeric axes, so
   peak positions and peak heights can be read off and compared. This is a real
   quantitative check on the physics, limited by figure-reading precision of a
   few percent. It is the strongest statement available for this code.
2. **Internal consistency across the samples.** Samples 1 and 4 are the same
   reaction in normal and inverse kinematics; samples 2 and 3 are the same
   observable at 392A and 100A MeV; sample 5 is the well-behaved counterpart of
   sample 4 at identical kinematics.
3. **The code's own printed cross-checks.** The outlist prints the integrated
   TDX beside the NN total cross section at the same energy, and prints the
   fitted s.p. potential depth that reproduces the requested separation energy.
4. **Regression pins.** `check_pikoe.py` compares against values established
   here. This catches a broken build or a changed upstream, and nothing more.
   It is not an independent check and must not be described as one.

Upgrade path: ask the authors for the missing reference output. Kazuki Yoshida
is a co-author and is the person who invited Lei to QFS-RB 2026, so this is a
one-line email, and it would also fix a packaging defect for everyone else.

## Figure comparison

All cases are `12C(p,2p)11B` ground state, 1p3/2 orbit, separation energy 15.96
MeV, spectroscopic factor 1.77, EDAD1 Dirac-phenomenology potentials, Perey
nonlocality range 0.85 fm.

| case | figure | quantity | pikoe (this build) | read off the figure |
|---|---|---|---|---|
| TDXnorm | Fig. 1(a) | first TDX peak | 127.03 at 40.5 deg | about 130 at about 40 deg |
| TDXnorm | Fig. 1(a) | dip between peaks | 8.05 at 50.5 deg | near zero at about 51 to 53 deg |
| TDXnorm | Fig. 1(a) | second TDX peak | 128.32 at 61.0 deg | about 135 at about 61 deg |
| TDXnorm | Fig. 1(b) | `Ay` range over 20 to 80 deg | -0.409 to +0.470 | about -0.4 to +0.5, with the sharp swing at the dip |
| QDXinv | Fig. 5 | low-`T2` peak | 0.18147 at 185 MeV | about 0.175 at about 190 MeV |
| QDXinv | Fig. 5 | high-`T2` peak | 0.17408 at 325 MeV | about 0.168 at about 330 MeV |
| MD100 | Fig. 3 | LG distribution peak | 36.724 at 9.87 MeV/c | about 37, flat-topped near zero |
| MD100 | Fig. 3 | LG asymmetry | centroid -63.97 MeV/c, sharp fall above +100 MeV/c | visibly asymmetric, sharp fall above +100 MeV/c |
| TDXinv | Fig. 4 | divergence structure | two `isol` branches, steep rise to 1049 (isol=1, 31.50 deg) and 1422 (isol=2, 32.25 deg) | both branches rising past 1000 at the right edge, about 32.3 deg |

TDX in ub/(MeV sr^2), QDX in ub/(MeV^2 sr rad).

Reading a curve off a printed figure is good to a few percent at best, so the
cross-section agreement above is stated as "a few percent", not as N
significant figures. Peak **positions** are sharper: they match to the plotted
resolution.

The Fig. 4 comparison is qualitative by nature. The quantity diverges at a
double root, so the largest tabulated value depends on how close the angular
grid happens to land to the singularity, and is not a stable number to compare.
What is checked there is the structure: two solution branches, both rising
steeply, meeting near 32.3 degrees.

## Regression anchors

`scripts/verify_pikoe.sh` runs the three fast cases in a clean room (fresh
workdir that cannot contain a reference file, banner asserted, stderr read) and
checks these with 1 percent tolerance. Full run takes about 35 seconds including
the build.

TDXnorm:
- s.p. central potential depth 54.34231 MeV (the depth found for `ebind` = 15.96 MeV)
- integrated TDX 23.44 ub (printed beside NN total cross section 25.31 mb)
- first peak 127.03 at 40.5 deg, dip 8.0529 at 50.5 deg, second peak 128.32 at 61.0 deg

TDXinv:
- `isol=1` maximum 1049.2 at 31.50 deg
- `isol=2` maximum 1421.6 at 32.25 deg

QDXinv:
- low-`T2` peak 0.18147 at 185.0 MeV
- high-`T2` peak 0.17408 at 325.0 MeV

MD100 (opt-in, about 31 minutes of CPU):
- LG peak value 36.724, centroid -63.9691 MeV/c, sum over the grid 905.855

The peak **position** is deliberately not pinned for the momentum-distribution
cases. The distribution has a flat top (three grid points sit within 1 percent
of the maximum), so the argmax can hop between them under a different compiler
while the physics is unchanged. The centroid is stable and carries the point the
figure is making, namely that the low-energy distribution is asymmetric.

**MD (392A MeV) is not pinned yet**: the run takes over an hour and had not
finished when this skill was written. `check_pikoe.py` reports SKIPPED for an
unpinned case rather than passing, and `verify_pikoe.sh` exits non-zero if every
requested case was skipped, so an unpinned run can never read as a green
verification.

## Runtimes

One core, Apple M-series. These are the CPU times pikoe prints in its own
banner (the source calls `cpu_time`), not wall clock; measured wall was about 4
percent higher on an otherwise busy machine:

| case | `ivar` | CPU time |
|---|---|---|
| TDXnorm | 1 | 7.7 s |
| TDXinv | 1 | 7.2 s |
| QDXinv | 3 | 5.2 s |
| MD100 | 9 | 1846.8 s (31 min) |
| MD | 9 | over an hour, not yet measured to completion |

The momentum-distribution cases are three orders of magnitude more expensive
because `ivar=9` adds Gauss-Legendre quadratures over `K1` and `phi_1Q` (15
nodes each in the shipped decks) on top of an 81 by 41 output grid. `MD` costs
more than `MD100` because it runs at 392A MeV with `lmax` 60 rather than 100A
MeV with `lmax` 30.

## Citation check

- **Code paper.** `10.1016/j.cpc.2023.109058` resolved live against CrossRef:
  K. Ogata, K. Yoshida, Y. Chazono, *pikoe: A computer program for
  distorted-wave impulse approximation calculation for proton induced nucleon
  knockout reactions*, Computer Physics Communications **297**, 109058,
  published 2024-04. Received 29 September 2023, revised 30 November 2023,
  accepted 11 December 2023, online 27 December 2023. Licence **MIT** (from the
  paper's program summary). CPC library link `10.17632/m594h58kck.1`.
- **INSPIRE has no record.** Both the DOI endpoint and a title search return
  nothing, so unlike TALYS this citation has a single authority (CrossRef).
  Flagged rather than glossed.
- **Formalism reference.** `10.1016/j.ppnp.2017.06.002` resolved against
  CrossRef: T. Wakasa, K. Ogata, T. Noro, *Proton-induced knockout reactions
  with polarized and unpolarized beams*, Progress in Particle and Nuclear
  Physics **96**, 32-87 (2017).

## What was not verified

- Cluster knockout (`(p,palpha)`, `(p,pd)`, `(alpha,2alpha)`). The authors say
  it works with appropriate tables; no case ships and none was run.
- `ielm=0` (isotropic free NN cross section) and the `ionsh` prescriptions other
  than 1 (final-state). All five shipped decks use `ionsh=1`.
- External s.p. wave-function input (`ish>9`) and external optical potentials
  beyond the shipped EDAD1 files.
- Any system other than `12C(p,2p)11B`. Every shipped deck is that one reaction,
  so nothing here constrains the code's behaviour for unstable projectiles,
  which is its stated design target.
- Comparison against THREEDEE. The paper says such comparisons were made with
  T. Noro's support, but reports no numbers, so there is nothing to reproduce.

## Adversarial review

A Codex adversarial falsification pass was run against the finished skill on
2026-07-21, per the FUSION rule that cross-AI validation is mandatory before a
per-code skill ships. It confirmed 24 defects, all fixed and re-verified here.
The four that would have blocked a ship:

1. **Data loss.** `run_pikoe.sh` guarded `$WORK/case` but its `rm -rf` deleted
   `$WORK`. A deck sitting in the workdir was destroyed before it could be read,
   and pointing the workdir at the install tree deleted the binary and the 50 MB
   of data tables. The guard now covers the directory that is actually removed,
   checks both the deck and the install tree against it, and only `$CASE` is
   ever removed.
2. **Empty tables counted as results.** The success test counted `.dat` files
   without testing size, and pikoe creates every output file at zero bytes when
   it reads the deck header. A run that produced nothing reported success. Now
   only non-empty tables count.
3. **A skipped check read as a pass.** `verify_pikoe.sh MD` printed `VERIFY OK`
   having compared zero anchors, because no pin existed. There is now a distinct
   SKIPPED status and an inconclusive exit.
4. **An unreachable diagnostic.** Under `set -euo pipefail`, `ls *.dat` on an
   empty glob aborted the script before the "no data table" message could print,
   so the failure mode with the most informative message produced silence.

Two further classes worth recording: the checker silently dropped rows it could
not parse, so a table full of Fortran `***` overflow markers passed every anchor
(now a hard failure); and the installer's "prove the binary runs" block was
`if ! "$BIN" ...; then : ; fi`, which asserts nothing. It now requires the
Fortran end-of-file diagnostic that a working binary produces on empty stdin.

The review also corrected eleven documentation facts against the source,
including the unit-number range (0 to 99, not 10 to 99), the kinematics-profile
format (`9f11.0`, not the manual's `9f10.0`), the fact that `ical=0` survey mode
is silently overridden for `ivar=9`, that `ielm=6` is rejected outright rather
than merely undocumented, that the runtimes pikoe prints are CPU and not wall
time, and that `pr` is always in MeV/c regardless of `kunt`.
