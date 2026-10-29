---
name: yahfc
description: >-
  Drive YAHFC (Yet Another Hauser-Feshbach Code), W. E. Ormand's LLNL Monte Carlo Hauser-Feshbach code (LLNL-TR-824700, DOE CODE doi 10.11578/dc.20211209.1; MIT), with its optical-model engine Frescox. Event-by-event statistical decay of a compound nucleus formed by n, p, d, t, 3He, alpha or gamma on a target, or from a given initial population: reaction, capture, (n,n'), (n,2n), (n,p), (n,np) and other channel cross sections, neutron-induced fission cross sections with double-humped barriers, emission spectra, angular distributions, gamma multiplicities, width-fluctuation corrections, two-component exciton pre-equilibrium, coupled-channels/DWBA direct inelastic, and full nuclear-data libraries per channel. Use for 跑YAHFC, YAHFC input, Hauser-Feshbach 蒙特卡罗, 统计模型, 复合核衰变, 中子俘获截面, (n,2n), 裂变截面, fission barrier, 核数据库, event-by-event Hauser-Feshbach, Monte Carlo HF, gamma cascade, population decay, fission fragment de-excitation input. For a deterministic Hauser-Feshbach evaluation with the widest model menu use the `talys` skill; reach for YAHFC when you want correlated event-by-event output, explicit gamma cascades, or LLNL's tuned actinide decks.
---

# Driving YAHFC

YAHFC samples the decay of a compound nucleus event by event. For each
incident energy it gets transmission coefficients from an optical-model
calculation (it writes FRESCO-style decks and calls **Frescox**, LLNL's fork of
FRESCO), forms the compound nucleus with pre-equilibrium and direct
(coupled-channels or DWBA) components removed, and then follows Monte Carlo
cascades of particle and gamma emission (and fission) to the ground state or
an isomer. Every channel's cross section, spectrum and angular distribution is
tallied from the events and written to a per-channel library tree.

Upstream: `github.com/LLNL/Yet-Another-Hauser-Feshbach-Code` (MIT, stated in the
README) and `github.com/LLNL/Frescox` (GPL-2.0-or-later, per its LICENSE). Fortran 90, plain Makefiles,
builds unpatched on macOS/Apple Silicon and Linux with gfortran. The paper of
record is the technical report W. E. Ormand, *Monte Carlo Hauser-Feshbach computer
code system to model nuclear reactions: YAHFC*, LLNL-TR-824700 (2021),
doi:10.2172/1808762; the code itself is DOE CODE doi:10.11578/dc.20211209.1 (both
checked live on OSTI and DataCite, 2026-10-29). No journal article exists;
the manual is `Documentation/YAHFC-Manual.pdf` in the clone.

**Status (2026-10-29): verified on macOS/Apple Silicon and Linux x86-64 (cold
install, all pins within 1.0e-7, identical event counts). Two Codex
adversarial passes (2026-10-29) found 22 and then 10 defects, all addressed and
each attack replayed; see `references/verification.md`.**

**Scope of the harness:** `run_yahfc.sh` certifies particle-induced library runs
(projectile n, p, d, t, h or a). Photon and population runs and
`event_generator` mode print a different layout and are refused, not certified.

## Prime rules (do not skip)

1. **Fix the seed, and say which one.** Without `ran_seed` YAHFC seeds from the
   clock, so two runs of one deck differ. `run_yahfc.sh` adds `ran_seed 12345`
   (or `$YAHFC_SEED`) when the deck has none and records it. Same seed, same
   build: byte-identical libraries. **To estimate Monte Carlo noise run several
   seeds**; repeating one seed measures nothing.
2. **Results are Monte Carlo estimates.** The manual quotes about 5%
   fluctuation in cross sections at 1e5 events and under 1% at 1e6. Quote a
   physics number as a seed mean with its spread, and state the event count.
   Build-to-build differences measured on the L1 case (at most ~2e-7
   relative, `-O0` to `-Ofast`, and 1.0e-7 Mac against Linux) are far below
   that; they are properties of the measured cases, not a general guarantee.
3. **Fresh directory for every run.** YAHFC silently reuses a
   `<proj><target>.tcoef` from the run directory, instead of calling Frescox,
   when the matching `-CC.data` is there too, so a stale pair from another
   optical model is used without a word. `run_yahfc.sh` refuses a non-empty
   workdir; stage a pair deliberately (for example LLNL's shipped
   coupled-channels files) by passing both as arguments, and provenance.txt
   says whether each staged `.tcoef` was used or recomputed.
4. **It must be Frescox, not FRESCO.** YAHFC calls a binary named `frescox` from
   PATH. The installer builds Frescox into this skill's own cache; the
   `fresco` skill's binary is a different code and must not answer.
5. **Content is the verdict.** A clean exit is necessary, not sufficient.
   `run_yahfc.sh` requires, per energy block, one successful event-accounting
   check and each required cross section exactly once, finite, non-negative and
   in the declared units (sigma_tot = sigma_R + sigma_SE for neutrons); plus
   the closing banner, no energy-conservation violation, the seed shown as
   executed, every Frescox run recorded with exit 0 and an empty error file, a
   generated library whose `Reaction_cs.dat` matches stdout row by row, no NaN
   or overflow fields, and nothing on stderr except YAHFC's own mkdir/rm chatter.
6. **Write decks the way YAHFC reads them.** It skips any line starting with a
   space (an indented command is silently ignored), splits words on spaces
   only (tabs glue words), reads 132 characters per line, and takes the last
   word of a `proj_e_file` line even if it is in a comment. `run_yahfc.sh`
   refuses all of these, and anything after `end`.
7. **Incident energies are moved.** YAHFC maps each requested energy onto the
   centre of an excitation-energy bin of width `delta_e`: 0.5 MeV becomes
   0.4607, 14.0 becomes 14.031 for n+235U. Compare with data at the energy
   YAHFC reports, not the one you asked for.
8. **stdout contains NUL bytes.** Plain `grep` calls it a binary file and
   prints nothing useful; always `grep -a`, or `tr -d '\000'` first.
9. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_yahfc.sh` clones YAHFC and Frescox at pinned commits into
`~/.cache/fusion/yahfc` (override with `YAHFC_ROOT`), builds both with the
upstream recipes, proves the pair on a 200-event n+90Zr probe, and prints:

```
YAHFC=<path to YAHFC.x>
FRESCOX=<path to frescox>
YAHFC_DIR=<YAHFC source tree>
YAHFC_DATA=<data directory, with trailing slash>
```

About 70 s and 300 MB from cold. Needs `git`, `make`, `gfortran`. Nothing goes
to `~/bin` or replaces anything on your PATH. The install root must keep the
data path (with its trailing slash) at 110 characters or fewer: YAHFC appends
`/Coupled-Channels.txt` to it in a 132-character buffer, and a measured 111
fails while 110 runs. The installer and `run_yahfc.sh` both enforce it.
The cache fast path is taken only when both source trees are at the pinned
commits with no tracked edits; otherwise the installer re-fetches and rebuilds.

## Input

A deck is a list of commands, one per line, any order, any case, read from
stdin and ended by `end` (or end of input). `#` or `!` starts a comment. The minimal deck:

```
file Zr90                   # output name: Zr90.out
target Zr90                 # or: target 40 90
projectile n                # g n p d t h a, or 0..6
proj_eminmax 1.0 14.0 13.0  # Emin Emax Estep (MeV); or proj_e_file <file>
num_mc_samp 100000          # default 1000000
end
```

A misspelled command stops the run (exit 101, `COMMAND NOT RECOGNIZED`). Full
command reference, defaults checked against the source, and the places where
the manual and the code disagree: `references/input-format.md`.

The examples under `$YAHFC_DIR/YAHFC-Examples/` (U235, U238, Pu239, U233, Y87,
Y88, Zr90) are shell scripts (`.com`) that pipe a heredoc into YAHFC.x. Extract
the lines between `<< input` and the closing `input` to get a deck. The actinide
ones carry LLNL's tuned fission barriers, level densities and strength
functions, and are the best starting point for any actinide work.

## Workflow

```bash
bash scripts/install_yahfc.sh                          # prints the four paths
bash scripts/run_yahfc.sh my.inp run1                  # fresh dir run1
bash scripts/run_yahfc.sh u235.inp run2 elist.txt \
     "$YAHFC_DATA/Trans-coeff/CC-DWBA/nU235.tcoef" \
     "$YAHFC_DATA/Trans-coeff/CC-DWBA/nU235-CC.data"   # stage files explicitly
YAHFC_SEED=7 bash scripts/run_yahfc.sh my.inp run3     # another seed
bash scripts/verify_yahfc.sh [--seeds]                 # the benchmark
bash scripts/selftest_yahfc.sh [--real]                # prove the harness guards
```

`run_yahfc.sh` prints sigma_tot, sigma_R and sigma_shape-el per energy, and the
fission cross section when there is one. Everything else is in the library tree
`<A><Sym>/<proj>/<channel>/` in the workdir (`90Zr/n/2n/`, `235U/n/f/`); file
layouts in `references/output-format.md`.

## Verified benchmark

Tier 2: YAHFC ships no reference output, and its report has no result tables.

| check | result (macOS gfortran 15.2; Linux x86-64 gfortran 13.3 agrees to 1.0e-7) |
|---|---|
| L1 n+90Zr, 0.96 and 13.92 MeV, 2000 events, seed 12345 | 19 cross sections reproduce the pinned values exactly (gate 1e-6), event counts per channel exact, library flux sum equals sigma_R to 3e-8 |
| L2 n+235U fission, LLNL tuned deck, 20000 events, seed 12345 | sigma_f at 5 energies reproduces the pins exactly (gate 1e-6) |
| L2 vs experiment (EXFOR 10950.002, 14016.002) | seed mean of 5 within 2.5 to 3.9% of measured sigma_f at 0.46, 0.97, 4.95, 14.0 MeV; gate 6% fixed before the run |

The 6% gate is a regression bar on a deck LLNL tuned to fission data, not a
statement of YAHFC's predictive accuracy. Numbers, provenance and the
build-variance analysis: `references/verification.md`.

## Failure modes

See `references/failure-modes.md`. The ones that bite: a stale `.tcoef` pair
reused silently (rule 3); a clock seed (rule 1); an indented command ignored
(rule 6); energies moved onto the bin grid (rule 7); `cs_units mb` making every
number 1000 times larger; several command names in the manual that the code
does not parse (`input-format.md` lists the real ones); `num_mc_samp 0` running
with zero events and writing NaN although YAHFC says it uses the default; and
Frescox failures that YAHFC itself never checks.
