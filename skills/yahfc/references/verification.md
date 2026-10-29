# YAHFC verification (DRAFT, skill under construction)

Status 2026-10-28: measurements below were taken during the feasibility pass on
macOS 26 / Apple Silicon, gfortran 15.2.0 (Homebrew), YAHFC 18af2fe, Frescox
eca88f3, upstream default flags (YAHFC `-Ofast`, Frescox `-O2`). They are the
values `verify_yahfc.sh` pins. On 2026-10-29 `verify_yahfc.sh --seeds` passed on the same Mac build,
reproducing every pinned value below exactly (L1, L2 seed 12345) and the seed means to 1e-4. Reproduced on Linux on 2026-10-29 (section at the end); not yet
through the Codex adversarial pass. Nothing here may be quoted as shipped.

## Tier

**Tier 2, with a physics anchor.** YAHFC ships no reference output of any kind:
the examples (`YAHFC-Examples/`, `Runs/`) are input decks only, and the
documentation (manual, technical report LLNL-TR-824700, the deleted CPC draft in
git history) has no figures and no result tables. The only numbers it gives are
timings and "about 5% Monte Carlo fluctuation at 1e5 events, below 1% at 1e6".
Third-party papers that used YAHFC (KDUQ, arXiv:2211.07741; arXiv:2602.12428)
state "default models" without a complete input set, so a benchmark cannot be
reconstructed from them without inventing parameters.

## L1: fixed-seed regression, n+90Zr

Deck `examples/zr90-n.inp` (2 energies, 2000 events, about 8 s including Frescox):

```
file Zr90
target Zr90
projectile n
all_discrete_states y
delta_e 0.1
proj_eminmax 1.0 14.0 13.0
wf_model 1
preeq_model 1
num_mc_samp 2000
ran_seed 12345
end
```

YAHFC snaps the requested energies onto its own grid: 0.96188550 and 13.921512 MeV.

| E (MeV) | sigma_tot (b) | sigma_R (b) | sigma_shape-el (b) |
|---|---|---|---|
| 0.96188550 | 6.4621054 | 2.6804315 | 3.7816739 |
| 13.921512 | 3.9052591 | 1.7440681 | 2.1611910 |

sigma_tot = sigma_R + sigma_shape-el holds to all printed digits at both energies,
and the library flux sum (compound elastic + `n/Inelastic_cs_Total` + every
non-inelastic `Channel_*_cs_Tot`) equals sigma_R to 3e-8; `verify_yahfc.sh` checks both.
Per-channel event counts at 13.92 MeV: g 233, n 582, 2n 110, p 806, np 262, 2p 0.

Same build, same seed: 87 of 87 library files byte-identical (two runs, and
confirmed independently by Codex). A different seed changes 66 of 87.

## L2: physics anchor, n+235U fission with LLNL's tuned deck

Deck: `YAHFC-Examples/U235/U235.com` from the clone (LLNL's tuned fission
barriers, level densities and strength functions), with `num_mc_samp 20000`,
`proj_e_file` = 0.5, 1.0, 2.0, 5.0, 14.0 MeV, `ran_seed 12345`, and the shipped
`Data/Trans-coeff/CC-DWBA/nU235.tcoef` + `nU235-CC.data` copied into the run
directory (so Frescox is not exercised here). About 15 s.

| E (MeV) | YAHFC seed 12345 (b) | mean of seeds 1-5 (b) | seed sd | measured (b) | source |
|---|---|---|---|---|---|
| 0.4607 | 1.1808 | 1.1717 | 0.40% | 1.137 +- 2.4% | Wasson et al., EXFOR 10950.002 (bins, keV) |
| 0.9709 | 1.1831 | 1.1554 | 1.60% | 1.185 +- 2.3% | Wasson et al., EXFOR 10950.002 |
| 1.9912 | 1.3145 | 1.2920 | 1.14% | not in these two entries | |
| 4.9501 | 1.1053 | 1.0999 | 1.55% | 1.072 +- 1.2% | Lisowski et al., EXFOR 14016.002 |
| 14.031 | 2.0097 | 1.9840 | 0.66% | 2.065 +- 1.9% | Lisowski et al., EXFOR 14016.002 |

Mean-of-seeds deviation from measurement: +3.0%, -2.5%, +2.6%, -3.9%. Measured
values are linear interpolations at the YAHFC energies (rows and rule in `exfor-u235-nf.tsv`), retrieved 2026-10-28 with
the exfor-data skill from the IAEA GitHub mirror. `exfor.py verify` could not run
(dataexplorer returned 403), so the parse is single-route. Any gate on this
comparison is a pre-fixed regression bar, not a statement of physics accuracy.

## Build variance (why the gate tolerance can be loose)

Fixed seed, n+90Zr, nine builds. Against `-O0`: `-O2 -ffp-contract=off` differs
only by one header line in 6 (n,g) files; FMA (`-O2`, `-O3`) changes 21 numeric
files, all through `print_channels.o`, `print_elastic.o` (exact zeros become
~1e-17) and `eig_eis.o` (Gauss nodes one ulp); `-ffast-math` changes more
through the `KE_com` energy grid, up to 15 printed units (~2e-7 relative).
Events per channel, sigma_tot and sigma_R identical in every build. All of it is
far below the Monte Carlo noise at the event counts used here, so the
regression tolerance is 1e-6 relative, not byte identity. Root causes and the
two upstream bugs (uninitialised `num_particles`; cancellation in `KE_com` and
`KE_lab`) are in `devlog.md`, 2026-10-28.

## Harness self-test

`selftest_yahfc.sh` (about 50 s; `--real` about 100 s): a stub YAHFC.x writing
the real layout, 7 positive controls (clean neutron run; stderr chatter in BSD
and GNU wording; `cs_units mb`, reported as mb; a charged projectile; a seed
line with a trailing comment; a Frescox path containing `$`, which must run
literally; Frescox writing gfortran's harmless IEEE_DENORMAL note) and 62
negative cases over the 44 guard tags of `run_yahfc.sh` and
`yahfc_check.py`. Every negative case must fail with its own guard's tag;
every tag is then disabled in a copy and must let its own cases through (6
cases are fire-only by construction: no deck, no binary, no workdir, no
target, no particle library to check, no energy to compare). `--real`, in a
scratch copy of the skill, perturbs `verify_yahfc.sh` (one L1 cross section by
2e-6, one event count, the L2 energy grid at E#1, one EXFOR value beyond 6%)
and requires exactly the five FAILs that implies. The proof is per guard tag,
not per call site, and assumes guard conditions have no side effects. It covers
the listed cases, not every way a run can go wrong. Passed 2026-10-29 on the
Mac build above, also with a long TMPDIR.

**Exact-zero pins.** Five L1 pins are exactly 0 (closed channels at 0.96 MeV,
no compound elastic or 2p events at 13.92 MeV) and are compared exactly. They
are event-count zeros, not cancellations: a channel with no events tallies
nothing, and the event counts were identical across all builds and both
platforms. The ~1e-17 to 1e-19 values that appear between builds sit in
angular and spectral densities, which no pin reads.

## Linux cross-platform run (2026-10-29)

heliumx, Ubuntu 24.04 x86-64, gfortran 13.3.0, cold install into a throwaway
root through a proxy tunnel: 59 s, 303 MB, probe passed. Same pinned commits,
same upstream flags as the Mac.

- `verify_yahfc.sh --seeds`: VERIFY OK, 43 checks. Worst pinned cross section
  1.0e-7 relative (gate 1e-6). Event counts per channel identical to the Mac.
  The five-seed U235 means are identical to the Mac's to all six printed
  digits, so the same seed follows the same Monte Carlo path on both
  architectures. 2 min 7 s.
- `selftest_yahfc.sh --real`: all guards proven, 44 s.
- Frescox transmission coefficients (`nZr90.tcoef`, `pY90.tcoef`) are not
  byte-identical across architectures but agree to 5e-12 of the largest value
  in each file; the entries that differ in relative terms are ~1e-12 against 0.
- Library, all 87 files: no structural mismatch, worst difference 1.4e-9 of the
  file's largest value. Entries off by more than 1e-6 relative are exact zeros
  on one platform against ~1e-19 on the other (the same last-bit effect seen
  between optimisation levels). Measured with `skills/pikoe/scripts/xbuild_compare.py`
  (extended with `--glob` and a file-scaled column for this).
- One harness defect found and fixed: heliumx runs `zh_CN.UTF-8`, so the
  mkdir/rm chatter on stderr arrived in Chinese and the noise filter rejected
  every run. `run_yahfc.sh` now runs YAHFC under `LC_ALL=C`, and the self-test's
  noise case carries both the BSD and the GNU wording.

## Codex adversarial pass 1 (2026-10-29)

Codex (codex-cli 0.165.0) read the skill and the Fortran source and attacked
the harness with stubs and real runs. 22 confirmed findings (9 rated blocker)
and 3 suspected; each was reproduced or read in the source before acting.
What changed:

- Verdict rebuilt per energy block in `yahfc_check.py`: accounting per block
  (a global count passed a run with one energy unaccounted), required fields
  exactly once by projectile, finite non-negative values and energies, units
  checked (a `cs_units mb` run had been reported as barns), the library's
  `Reaction_cs.dat` matched to stdout row by row (a staged `.dat` had counted as
  "a library"), overflow detection that catches gfortran's adjacent `****`
  fields, and a stderr filter anchored to the exact three operands YAHFC uses.
- Frescox exit status now recorded by a wrapper on PATH (YAHFC never checks it)
  and its error files required empty.
- Deck preflight reproduces YAHFC's reader: indented lines, tabs, long lines,
  glued comments, commented `proj_e_file` lines and text after `end` are
  refused (an indented `ran_seed` had been "found" by the wrapper and ignored
  by YAHFC, so provenance claimed a seed the run never used); the executed seed
  is now read back from `YAHFC-commands.txt`.
- Staging rejects reserved names and whitespace; `.tcoef` provenance judged
  from the Frescox decks actually written, which exposed the `-CC.data`
  pairing rule.
- `verify_yahfc.sh` reads each value only if its row's energy and the file's
  row count match the expected grid (a run with every energy overwritten by
  999 had passed).
- Installer fast path requires both trees at the pinned commits, clean; probe
  checks energy conservation and stderr.
- Docs: eight manual command names the parser does not know, five defaults
  corrected against the source, `global_lev_fit_aparam` flagged as probably
  ineffective, the sampling and path-limit descriptions made exact.

Not changed, by decision: the 6% EXFOR bar and 1e-6 regression tolerance
(Codex found both appropriately labelled). Suspected item 25 (no raw EXFOR rows
in the skill): `references/exfor-u235-nf.tsv` now carries the bracketing rows
and the interpolation rule, re-retrieved 2026-10-29; all four pinned values
reproduce from it to the printed digits (1.1372, 1.1851, 1.0723, 2.0650). The
live citation check that Codex could not complete from its sandbox was done
separately (OSTI and DataCite records, see SKILL.md).

## Codex adversarial pass 2 (2026-10-29)

Codex rechecked its 25 round-1 items (15 fixed, 9 partly, 1 rejected
correctly) and found 10 new defects, 7 rated blocker. All reproduced before
fixing; every attack in its kit was then replayed against the new code and is
caught by the intended guard. Changes:

- Seed mean: a failed read had been averaged in as 0, so a compensated
  mutation passed `--seeds`; every read must now be a finite number on the
  right grid. Grid tolerance widened from 1e-7 to 1e-6, since builds move the
  energies by ~2e-7 and a wrong energy moves them far more.
- Frescox recorder built with `printf %q`, so a path containing `$` runs
  literally (it had run a different binary).
- Duplicate projectile (and other single-valued commands) refused [dupcmd]:
  YAHFC's rank sort is not stable and a real run executed them in the opposite
  order from the text.
- Library unit headers checked [units]; negative numbers in `*_cs*.dat`
  rejected [libvalues]; the library must sit under the deck's target and
  projectile [library] (a renamed tree had passed).
- Finite check parses numbers (`1e999`), is case-insensitive for nan/inf,
  covers every Frescox output file, and digit-adjacent asterisks there except
  the page-rule decoration; missing Frescox error files fail [fxfiles].
- Malformed duplicate cross-section lines counted [xsfields]; a commented
  `ran_seed` line read back correctly [seedrun].
- Deck reader: lines limited to 131 bytes (a word reaching column 132 crashed
  a real run), `proj_e_file` names to 50 [pename], referenced files must be
  staged plain names [unstaged], the `file` output name cannot be staged
  [reserved].
- Path limit measured instead of derived: 110 runs, 111 fails; both earlier
  derivations (111 and 112) were wrong.
- Installer re-fetches a dirty tree even at the pinned commit; probe checks
  Frescox error files.
- Self-test: stub data directory short whatever TMPDIR is; `--real` works in a
  scratch copy instead of writing into the skill.

**Linux rerun after pass 2 (heliumx, 2026-10-29).** Cold install, `verify
--seeds` VERIFY OK (2 min 14 s), `selftest --real` all guards (116 checks). It
found one more thing the Mac could not: Linux Frescox writes gfortran's
IEEE_DENORMAL exit note into its error files on proton runs, which the new
empty-error-file rule rejected. The note is now accepted for the three harmless
flags only, with a positive and a negative self-test case.
