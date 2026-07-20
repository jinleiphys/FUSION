---
name: ccfull
description: >-
  Drive CCFULL, the all-order coupled-channels code for near-barrier heavy-ion fusion (K. Hagino, N. Rowley, A.T. Kruppa, CPC 123 (1999) 143). Write, run, and verify CCFULL input for fusion excitation functions, barrier distributions, and mean angular momenta with vibrational or rotational couplings and pair transfer. Use for 跑ccfull, CCFULL input, heavy-ion fusion, near-barrier fusion, coupled-channels fusion, fusion excitation function, barrier distribution, 熔合截面.
---

# Driving CCFULL

CCFULL solves the coupled-channels equations for heavy-ion fusion near the Coulomb barrier, keeping the nuclear couplings to all orders (not linearized). It computes the fusion excitation function, the fusion barrier distribution, and the mean angular momentum of the compound system, with the target and projectile treated as vibrational or rotational, plus an optional pair-transfer channel. Fusion is defined by the incoming-wave boundary condition at the potential-pocket minimum. Reference: K. Hagino, N. Rowley, A.T. Kruppa, Comput. Phys. Commun. 123 (1999) 143; source at Hagino's Kyoto page.

## Prime rules (do not skip)

1. **Never report a CCFULL number you have not verified.** The distributed 16O+144Sm example reproduces Hagino's reference `OUTPUT` bit for bit (`references/verification.md`); reproduce it after any build, and for a new case confirm the uncoupled barrier (Rb, Vb, curvature) is physical before trusting the cross sections.
2. **Start from the verified example.** `examples/16O_144Sm.inp` runs and matches the reference exactly. Copy it and edit the numbers; do not hand-write the 9-line free-format deck from memory (the line meanings are position-dependent and easy to shift). Format reference: `references/input-format.md`.
3. **The input file must be named `ccfull.inp`.** The code hard-codes that filename (unit 10) and writes `OUTPUT`, `cross.dat`, `spin.dat`, `s-wave.dat` into the current directory. Always run in a scratch dir; `run_ccfull.sh` handles the copy.
4. **CCFULL is interactive on stdin.** Besides `ccfull.inp`, it asks several y/n questions on stdin (standard Woods-Saxon, beta_N vs beta_C per mode, AHV couplings). With no stdin it crashes at line 196 with "End of file" and writes a truncated OUTPUT. Answer `n` to all for a standard run; `run_ccfull.sh` pipes `n` automatically (override with `ANSWERS`). Full list in `references/verification.md`. A run that "produced no OUTPUT" almost always means stdin was not fed.
5. **No em-dashes in any prose or comments you write** (user's flat rule).

## Environment (auto-install)

- **Binary is auto-provisioned.** `scripts/install_ccfull.sh` checks `~/bin/ccfull` (override `CCFULL_BIN_DIR`) and `PATH`; if absent it fetches the canonical FORTRAN77 source `ccfull.f` from Hagino's Kyoto page and builds it with `gfortran -std=legacy -O2`. `scripts/run_ccfull.sh` calls it on first use. Requires `gfortran` and `curl` (macOS: `brew install gcc`).
- FORTRAN77 fixed-form source; `-std=legacy` is required (modern gfortran otherwise rejects some constructs). Builds in a couple of seconds; runs are sub-second.
- Alternative sources if the Kyoto page is down: GitHub `shu-yusa/ccfull-qel` / `ccfull-rmt` (extended variants with quasi-elastic scattering and random-matrix noncollective couplings) and a Fortran90 port (Zehong Liao + Hagino). The skill targets the canonical Hagino-Rowley-Kruppa version.

## Input structure

Nine free-format lines; full table in `references/input-format.md`. The essentials:

- Line 1: `AP, ZP, AT, ZT` (masses and charges).
- Line 2: radius parameters + intrinsic-motion option for projectile/target (`IVIBROT` = -1 inert, 0 vibrational, 1 rotational).
- Lines 3 to 5: excitation modes (phonon energy / deformation / multipolarity / number, or rotational band).
- Line 6: optional pair transfer.
- Line 7: nuclear potential `V0, R0, A0` (Woods-Saxon; radius uses the AP^(1/3)+AT^(1/3) sum convention).
- Line 8: c.m. energy grid `EMIN, EMAX, DE` for the excitation function.
- Line 9: radial grid `RMAX, DR`.

## Workflow

1. Copy `examples/16O_144Sm.inp`. Edit line 1 for your system, lines 2 to 6 for the coupling scheme (which collective states to include), line 7 for the potential, line 8 for the energy range.
2. Run: `scripts/run_ccfull.sh <input.inp> <scratchdir>`. It auto-installs, runs, and prints `OUTPUT`.
3. **Verify:** check the uncoupled barrier (Rb, Vb, curvature) makes sense for the system; confirm the fusion cross section rises smoothly through the barrier; for the reference case, `diff OUTPUT references/16O_144Sm.OUTPUT.reference` must be empty.
4. The coupling effect is the whole point: compare a coupled run (IVIBROT >= 0) to an inert run (IVIBROT = -1) to see the sub-barrier fusion enhancement.

## Output

- `OUTPUT`: uncoupled barrier parameters, then the fusion excitation function (Ecm, sigma_fus in mb, mean l).
- `cross.dat`: Ecm vs sigma_fus (for plotting).
- `spin.dat`: compound-nucleus spin distribution.
- `s-wave.dat`: s-wave penetrability details.
- Barrier distribution D(E) = d^2(E sigma)/dE^2 is obtained by numerically differentiating the excitation function.

## Gotchas

- **Input filename** must be exactly `ccfull.inp` (rule 3).
- **`-std=legacy`** is mandatory to compile the FORTRAN77 source.
- **Radius convention** here is the AP^(1/3)+AT^(1/3) sum (standard for heavy-ion fusion), unlike COLOSS's target-only rule; do not carry a potential between the two codes without rescaling.
- **Coupling line shape depends on IVIBROT:** line 3/5 is read as (omega, beta, lambda, Nph) for vibrational but (E2, beta2, beta4, Nrot) for rotational. Setting IVIBROT wrong silently misreads the whole line.
- **Deterministic code:** the benchmark is an exact bit-for-bit match, not a tolerance; any diff means a real input or build difference.
