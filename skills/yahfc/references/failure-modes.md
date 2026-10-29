# YAHFC failure modes

Each entry was observed on the pinned commits (YAHFC 18af2fe, Frescox eca88f3)
or read in the source where cited. `run_yahfc.sh` (with `yahfc_check.py`)
refuses or fails the ones marked with a guard tag in brackets;
`selftest_yahfc.sh` proves each of those guards fires for its own case.

## Silent wrong answers (the dangerous ones)

| symptom | cause | guard / what to do |
|---|---|---|
| A rerun gives the old optical model's answer, no warning | YAHFC reuses `<proj><target>.tcoef` from the run directory when the matching `-CC.data` is there too (`optical_setup.f90:184-199`) | [nonempty] fresh workdir only; stage a `.tcoef` + `-CC.data` pair deliberately; provenance.txt says whether each staged `.tcoef` was used or recomputed |
| A staged `.tcoef` was silently recomputed | staged without its `-CC.data`, so Frescox ran and overwrote it | provenance.txt reports `RECOMPUTED`; stage both halves |
| A command is silently ignored | the line starts with a space: YAHFC skips any line whose first character is a space (`YAHFC-Master.f90:888`) | [indent] |
| Two words read as one unknown command, or a value lost | a tab (YAHFC splits on spaces only), a `#` glued to a word, or a line over 132 characters | [tab] [glued] [long] |
| The energy list read from a file named after your comment | `proj_e_file` takes the last word of the raw line up to column 100, comment included | [pecomment] |
| A setting after `end` has no effect | reading stops at `end` | [afterend] |
| A command given twice: either value may run | YAHFC ranks the commands with a sort that is not stable (`YAHFC-Master.f90:950-960`), so two `projectile` lines executed in the opposite order from the text in a real run | [dupcmd] refuses duplicates of projectile, target, cs_units, file, the energy commands, num_mc_samp and similar |
| Library numbers read in the wrong units | a library header declaring units other than the run's | [units] every `xs( b)` / `xs(mb)` header must match |
| Two runs of one deck disagree | no `ran_seed`: the seed comes from the clock | seed injected and recorded; [seedrun] requires `YAHFC-commands.txt` to show it executed |
| Numbers 1000 times too large | `cs_units mb` | units reported with every table and checked per block [units] |
| A "converged" number that is one Monte Carlo draw | one seed, few events. Manual: about 5% fluctuation at 1e5 events, under 1% at 1e6. Seed-to-seed sd for 235U(n,f), 2e4 events, LLNL deck: 0.4 to 1.6% | run 5 or more seeds, quote mean and spread; never repeat one seed |
| Comparison with data at the wrong energy | requested energies are moved onto excitation-bin centres through the relativistic lab/COM conversion (`fix-incident-energies.f90:107-130`): 0.5 -> 0.4607, 5.0 -> 4.9501 MeV for n+235U, delta_e 0.1; very low energies are kept; coinciding points are merged | read E_in from the output; interpolate data to it |
| (n,n') too small by a few percent | summing `Channel_n_cs_Tot`, or channel plus `entry_to` files | use `Inelastic_cs_Total.dat`; `output-format.md`, "Checked identities" |
| A Frescox failure goes unnoticed | YAHFC runs Frescox through `system()` and never checks its status (`run_fresco.f90:355`); its stderr goes to `Fresco-files/*_fresco_err.out` | [fxexit] a recording wrapper logs every Frescox exit status; [fxfiles] error files must be empty and every deck must have an output |
| The documented `global_lev_fit_aparam` does nothing | read from the source: it sets a global flag the fit never reads (see `input-format.md`) | not guarded; verify the effect in `<file>.out` before relying on it |

## Loud failures

| symptom | cause | guard / what to do |
|---|---|---|
| `COMMAND NOT RECOGNIZED -- CHECK`, exit 101 | misspelled command. Several manual spellings are among them: `f_lev_barrier_symmetry`, `f_ecut`, `f_beta_2`, `f_scale_beta_2`, `f_max_J`, `preeq_v`, `preeq_v_n`, `preeq_v_p` (see `input-format.md` for the real names) | [rc] |
| `Invalid value using default - num_mc_samp = 1000000`, then NaN | `num_mc_samp` < 1: the code says it uses the default and then sets the invalid value (`parse-command.f90:2262`) | [nsamp] |
| `Cannot open file '/mass-frdm95.dat'`, exit 2 | `YAHFC_DATA` unset: the first blank becomes `/`, so the code's "not set" check cannot fire (`YAHFC-Master.f90:799-807`) | the wrappers always set it |
| n or p runs die at `fresco_make_tco.f90:372` with `Cannot open file ''` | long data path: YAHFC appends `/` and `Coupled-Channels.txt` (20 characters) in a 132-character buffer (`YAHFC-Master.f90:800-801`, `fresco_make_tco.f90:367`). Measured 2026-10-29: a 110-character data path (trailing slash included) runs, 111 fails. A local `cc_file` avoids the concatenation; paths containing spaces are cut at the first space | [datapath] limit 110, checked at install and at run |
| Runs "fail" with no incident-energy blocks although they finished | `verbose_output n` (the manual says y suppresses; it is the other way round) | [quiet] |
| A different `frescox` (or Ian Thompson's fresco) answers | YAHFC calls `frescox` by bare name | [fxname]; the resolved binary's directory, behind the recorder, goes first on PATH |
| `COMMAND NOT RECOGNIZED` on `time YAHFC.x << input`, exit 101 | an example `.com` file passed as a deck | [wrapper]; extract the lines between `<< input` and `input` |
| `proj_e_file` or `cc_file` not found | opened relative to the run directory | [unstaged]; pass the file to `run_yahfc.sh` |
| Photon or population run "fails" after finishing | they print `Reaction cross section` / `Initial energy` instead of the particle-run layout | [mode] refused up front: `run_yahfc.sh` certifies particle-induced library runs only; `event_generator y` likewise [evgen] |

## Noise that is not a failure

- stderr carries exactly three kinds of chatter from YAHFC's own shell calls:
  `mkdir` of `Fresco-files`, `rm` of `fort.*`, and `rm` of the target library
  directory (for example `90Zr`), each in BSD or GNU wording. `run_yahfc.sh`
  runs YAHFC under `LC_ALL=C` so the wording is English, accepts exactly those
  operands, and fails on anything else, including other `mkdir`/`rm` messages.
- `grep` reports stdout as a binary file: it contains NUL bytes. Use `grep -a`.
- On Linux x86-64, Frescox's proton runs end with gfortran's note `Note: The
  following floating-point exceptions are signalling: IEEE_DENORMAL` in
  `Fresco-files/*_fresco_err.out` (56 lines in the L1 run; none on the Mac).
  The verdict and the install probe accept that note for IEEE_DENORMAL,
  IEEE_UNDERFLOW_FLAG and IEEE_INEXACT_FLAG only; INVALID, DIVIDE_BY_ZERO or
  OVERFLOW fail [fxfiles].
- `Use input commands to specify all Fission parameters!!!` and
  `Default Fission Barriers are overridden` in the U235 run are informational.
- `Hung bins are forced to decay to discrete states randomly` with 0% hung is
  informational; a large hung fraction deserves a look at the level scheme.

## Build differences

Measured on the L1 n+90Zr case only (two energies, seed 12345): `-O0` to
`-Ofast` changes library numbers by at most ~2e-7 relative, through fused
multiply-add in three print routines and a cancellation in the
centre-of-momentum energy (`YAHFC-Master.f90:5947`); event counts, sigma_tot and
sigma_R identical. Mac (Apple Silicon, gfortran 15.2) against Linux (x86-64,
gfortran 13.3): pinned values within 1.0e-7, identical event counts and seed
means. Other projectiles, fission decks and rare channels were not swept, so
treat these as properties of the measured cases, and the verify tolerance 1e-6
as a regression bar for its pins, not a precision guarantee. An uninitialised
`Exit_Channel%num_particles` (`decay-chain.f90:503`) toggles one header line in
6 (n,g) files at -O2. A patch removing these effects was tested and not adopted;
see the FUSION devlog of 2026-10-28. `do_dwba` results are tied to the delta_e
grid they were computed on (manual) and cannot be reused with another delta_e.
