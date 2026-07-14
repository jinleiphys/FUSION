---
name: fresco
description: >-
  Drive Ian Thompson's FRESCO coupled-channels reaction code: write, run, debug, and verify FRESCO input decks for elastic, inelastic, transfer/DWBA, breakup, CDCC, and capture calculations. Use for 跑fresco, 写fresco输入, FRESCO input, CDCC calculation, coupled-channels, breakup, transfer DWBA, optical model scattering, fort.16/fort.13 output, sfresco fitting.
---

# Driving FRESCO

FRESCO is a coupled-channels reaction code (I.J. Thompson, Comput. Phys. Rep. 7 (1988) 167). It solves the CC / CRC equations for any number of mass partitions and nuclear excitations, and covers elastic, inelastic, transfer (DWBA and CRC), breakup, and CDCC. This skill lets you build a correct input deck, run it, read the output, and prove the answer against a reference before trusting it.

The hard part of FRESCO is never the physics. It is the arcane namelist input and the convergence parameters. This skill's whole job is to make the input correct on the first or second try and to force a numerical check before any result is reported.

## Prime rules (do not skip)

1. **Never report a FRESCO number you have not verified.** The user's standing rule is "compare against a reference and tell me the agreement to N digits". For any new deck, either reproduce a known case or run the built-in convergence checks in `references/verification.md`. State the agreement explicitly.
2. **Generate and review input locally. Do not fire large jobs onto shared machines.** Workflow is: build deck → run a fast/small version locally → inspect convergence → only then scale up (and heavy runs go remote, per the user's compute rules). Never `空跑` a cluster.
3. **Start from a verified example, do not hand-write a deck from memory.** The `examples/` directory holds real decks that reproduce published outputs to 6+ significant figures. Copy the closest one and modify it. This is the anti-hallucination move: FRESCO syntax is easy to get subtly wrong, and a wrong deck often still runs and prints plausible garbage.
4. **No em-dashes in any prose or comments you write** (user's flat rule).

## Environment (auto-install)

- **Binary is auto-provisioned.** Before running, ensure a binary exists with `scripts/install_fresco.sh`: it checks `~/bin/fresco` (override `FRESCO_BIN_DIR`) and then `PATH`; if neither has it, it clones the source from https://github.com/I-Thompson/fresco, compiles with `gfortran` (`make FC=gfortran`, ~1-2 min), and copies `fresco` + `sfresco` into the bin dir. `scripts/run_fresco.sh` calls this automatically on first use, so you normally never install by hand. Requires `gfortran`, `git`, `make` (macOS: `brew install gcc`).
- The installer builds the current source tree (**FRES 3.4**). If the machine already has an older binary on `~/bin` or `PATH` (e.g. an existing **FRES 2.9**), the installer detects it and does NOT rebuild; force a fresh 3.4 build with `scripts/install_fresco.sh --force`.
- Version note: the manuals describe **FRES 3.4**. The namelist format is backward compatible for everything in `examples/`, but new 3.x variables may be silently ignored by an older 2.9 binary. If a 3.x-only feature is needed, flag it. See `references/failure-modes.md`.
- Run pattern: `fresco < input > output` in a clean working directory (FRESCO writes many `fort.*` files into cwd; always run in a scratch dir, never in a shared source tree).
- `timeout`/`gtimeout` are **absent on this macOS**. To cap a run, background it and `kill`, or run on a Linux box. Do not paste `timeout ...` into a command.

## Decision: which input format

FRESCO has two input styles. Pick before writing anything.

- **Standard namelist** (`&FRESCO &PARTITION &STATES &POT &OVERLAP &COUPLING`): full control, required for transfer, custom couplings, and anything non-standard. Default to this for research work.
- **High-level CDCC format** (`&CDCC &NUCLEUS &BIN &POTENTIAL`): a compact front end that auto-generates the bin states and overlaps for a standard CDCC breakup calculation, then expands into the standard format internally (writes the expanded deck to fort.301). Use it only for textbook two-body-projectile CDCC. The moment you need non-standard bins, transfer channels, or hand-built couplings, drop to the standard format. See `references/cdcc-format.md`.

## Calculation types (routing)

FRESCO is a general coupled-channels code, not a CDCC tool. The same binary does elastic, inelastic, transfer, breakup/CDCC, and capture. What changes between them is which namelists you populate, which example to start from, and a few key parameters. Pick the row first.

| Type | Physics | Namelists beyond the elastic minimum | Start from | Key parameters | Read result from |
|------|---------|--------------------------------------|-----------|----------------|------------------|
| **Elastic** | optical model, one channel | none (just `&POT` TYPE 0/1/2/3) | `examples/B1-elastic.in` | `hcm`, `rmatch`, `jtmax`, `absend` | fort.16 (ratio to Rutherford); reaction σ |
| **Inelastic** | collective excitation of a bound state | extra `&STATES` (the excited level, `copyp`/`copyt`), deformed `&POT` TYPE=10/11 (rotor) or 12/13 + `&step` | `examples/B2-inelastic.in` | `iter=1` (DWBA) vs `iblock=2` (full CC); deformation length (`p2` of the TYPE 11 term) | outgoing σ per state; fort.201+ |
| **Transfer** | (d,p), (p,d), stripping/pickup; see sub-types below | 2nd `&PARTITION`, `&OVERLAP` bound states, `&COUPLING kind=7`/`5`, `&CFP` amplitudes | `examples/B5-transfer.in` | nonlocal grid `rintp/hnl/rnl/centre`, `nnu`, post vs prior (`ip1`) | outgoing σ; fort.13 |
| **Breakup / CDCC** | coupling to the continuum | continuum-bin `&STATES`/`&OVERLAP` (`isc=2`, negative `be`), `&COUPLING kind=3` | `examples/be11-`, `b8ex-`, `dex-*cdcc*.nin` | `rmatch<0` + `rasym`, `jump/jbord`, `iblock=Nbins+1`, `smallchan/smallcoup` | breakup σ; fort.16 via `sumbins`, fort.13 via `sumxen` |
| **Capture** | radiative capture, astrophysical S-factor | `&OVERLAP` final bound state, `&COUPLING kind=2` (Eλ/Mλ) | `examples/B6-capture.in` | `ip1=λ` multipolarity, `ip4` direct/semidirect | fort.35 (S-factor); outgoing σ |

Two axes cut across all rows: number of mass partitions (1 for elastic/inelastic/breakup within a partition, 2+ for transfer/capture) and iteration mode (`iter>0` perturbative DWBA vs `iter=0 iblock=N` exact coupled channels). See `references/namelist-reference.md` for every variable and `references/cdcc-format.md` for the compact CDCC front end.

### Transfer is not one thing

"Transfer" splits along two independent axes: how many nucleons move, and whether it is solved perturbatively (DWBA) or to all orders (CRC). These are different inputs, not a naming preference.

| Sub-type | What changes in the deck | Start from | Anchor |
|----------|--------------------------|-----------|--------|
| **One-nucleon transfer (DWBA)** | `&OVERLAP kind=0` (or 1) single-particle form factor; `&COUPLING kind=7` (finite range) or `kind=5` (zero range); one `&CFP` amplitude. `iter=1` (one step, forward couplings only). | `examples/B5-transfer.in` | outgoing σ = 0.26397 |
| **Two-nucleon transfer** | two-particle overlaps `&OVERLAP kind=6-9` built from a `&TWONT` pair wavefunction (`NT(1:4)`, `COEF`); needs both the **simultaneous** (direct 2N) and **sequential** (via an intermediate one-nucleon partition) paths, so 3 partitions and a chain of `kind=6/7` + `kind=9` couplings. | `examples/2n-transfer-li9tp-simseq.nin` (9Li(t,p), sim+seq) | outgoing σ = 6.15287 |
| **CRC (coupled reaction channels)** | same transfer couplings as DWBA but solved to all orders: `iter=0` with `iblock` spanning the coupled partitions, and reverse couplings kept (`icto>0`, not negative). Multi-step chains across several partitions (elastic ↔ inelastic ↔ transfer) are CRC. | `examples/crc-16O-208Pb-multistep.nin` (16O+208Pb, 17O/15N/12C channels) | outgoing σ = 70.97471 |

DWBA vs CRC is the solution mode (`iter`/`iblock` + reverse-coupling sign), not a different set of namelists: the same deck run with `iter=1` is one-step DWBA and with `iter=0 iblock=<N>` is CRC. Check DWBA validity by turning on CRC and seeing if the cross section moves. One- vs two-nucleon is a genuinely different `&OVERLAP`/`&TWONT` setup. CCBA (coupled-channels Born approximation, e.g. transfer between deformed/inelastically-coupled states) sits between them: inelastic couplings to all orders, the transfer step in Born; see `f19xfs` in the FRESCO test set.

## Workflow

1. **Pick the calculation type** from the routing table above. This fixes which namelists you populate and which example to copy.
2. **Copy the nearest verified deck** from `examples/` (table below).
3. **Edit only what the physics requires**: masses, charges, energies, potentials, states, coupling. Keep the numerical/grid block from the reference deck until you have a reason to change it.
4. **Set the grid and partial waves** using `references/namelist-reference.md` (radial: `hcm`, `rmatch`/`rasym`; partial waves: `jtmin`, `jtmax`, `jump`/`jbord`; cutoffs: `cutr`, `cutl`).
5. **Run locally** with `scripts/run_fresco.sh <deck>`; it runs in a scratch dir and pulls out the integrated cross sections.
6. **Verify convergence** per `references/verification.md`: vary `hcm`, `rmatch`, `jtmax`, bin count; the observable must be stable to the precision you quote. If you have a published number or a reference deck, compare to N digits with `scripts/check_xsec.py`.
7. **Extract observables** from the right `fort.*` file (`references/output-files.md`): fort.13 (total xsec per channel), fort.16 (angular distributions, xmgrace-ready), fort.56 (xsec per J and partition: reaction/nonelastic), fort.201+ (per-state).
8. **If a step fails**, go to `references/failure-modes.md` (symptom to cause to fix) before guessing.

## Verified example decks

All reproduce their reference output on `~/bin/fresco` (FRES 2.9) to the digits noted in `references/verification.md`.

| File | Reaction | Method | Anchor (integrated) |
|------|----------|--------|---------------------|
| `examples/B1-elastic.in` | p + 78Ni, 3 energies | Optical-model elastic | reaction σ = 1575.175 mb |
| `examples/B2-inelastic.in` | α + 12C → 12C*(2+, 4.43) | Inelastic, rotor deformation, DWBA | outgoing σ = 31.67415 mb |
| `examples/B5-transfer.in` | one-nucleon (d,p)-type | Finite-range DWBA transfer | outgoing σ = 0.26397 mb |
| `examples/2n-transfer-li9tp-simseq.nin` | 9Li(t,p), sim + seq | Two-neutron transfer (kind 6/7/9, &TWONT) | outgoing σ = 6.15287 mb |
| `examples/crc-16O-208Pb-multistep.nin` | 16O+208Pb, 17O/15N/12C | Multi-step CRC (4 partitions) | outgoing σ = 70.97471 mb |
| `examples/B6-capture.in` | radiative capture | E1/M1 capture (kind=2) | outgoing σ = 0.00330 mb |
| `examples/be11-cdcc-lowlevel.nin` | 11Be + 197Au @ 42 MeV | CDCC Coulex, standard format | reaction 2758.687, absorption 423.915 |
| `examples/b8ex-cdcc-lowlevel.nin` | 8B + 208Pb s-wave | CDCC breakup, standard format | breakup σ = 58.36164 mb |
| `examples/dex-deuteron-cdcc.nin` | d + target | Deuteron CDCC | absorption 2154.845, outgoing 1234.089 |

The `-lowlevel` CDCC decks are in the fully expanded standard namelist format (explicit `&States`/`&Pot`/`&Overlap` bins), which is what you want to read and adapt for research. For the compact `&CDCC` front end, see `references/cdcc-format.md`.

## Reference map

- `references/namelist-reference.md`: every namelist and its frequently-used variables, organized by task (grid, partial waves, potentials by TYPE/SHAPE, states, overlaps by KIND, couplings by KIND). This is the distilled dictionary; the 45-page manual is the fallback for rare options.
- `references/cdcc-format.md`: the high-level `&CDCC`/`&NUCLEUS`/`&BIN`/`&POTENTIAL` format and when to use it.
- `references/output-files.md`: the fort.* file allocation table and how to pull each observable.
- `references/failure-modes.md`: symptom → cause → fix, seeded from the manual footnotes and real gotchas. Grow this file every time a new failure is diagnosed.
- `references/verification.md`: the anchor cases with exact expected numbers, and the convergence-check protocol.

## Scripts

- `scripts/install_fresco.sh [--force] [--verify]`: ensures a `fresco`/`sfresco` binary exists, building it from https://github.com/I-Thompson/fresco with `gfortran` if missing (see Environment above). `--verify` runs the B1-elastic anchor and checks it reproduces σ_R = 1575.175 mb. Idempotent; safe to call before any run.
- `scripts/run_fresco.sh <deck.in> [runname]`: copies the deck into a fresh scratch dir, runs the fresco binary (auto-installing it via `install_fresco.sh` on first use), and prints the integrated cross sections. Keeps you from polluting source trees with fort.* files.
- `scripts/check_xsec.py <output> [--ref <refoutput>] [--sigfig N]`: parses the cumulative reaction / outgoing / absorption cross sections from a FRESCO output and, given a reference, reports agreement to N significant figures.

## Scope

FRESCO computes elastic, inelastic, transfer (DWBA and CRC), breakup, CDCC, and capture. It does **not** compute inclusive non-elastic breakup (IAV / NEB); that is a separate calculation done by the user's own `smoothie` code. If the task is really an IAV / inclusive-breakup problem, this is the wrong tool. This skill is for direct FRESCO work: optical-model fits, elastic/inelastic, plain CDCC breakup, transfer/DWBA, and capture.
