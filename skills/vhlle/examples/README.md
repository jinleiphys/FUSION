# vHLLE examples

Two self-contained parameter decks. Neither needs an `-ISinput` initial-state
file; both draw their EoS/hadron tables from the companion repo `vhlle_params`,
which `install_vhlle.sh` clones and links.

## gubser.params (analytic benchmark, SIMPLE EoS)

Ideal (inviscid) conformal Gubser flow, `icModel 4`. Must be run with the SIMPLE
(conformal p=e/3) binary, because the analytic Gubser solution assumes conformal
symmetry. This is the paper's Section 4.1 test and the skill's physics anchor.

```bash
scripts/run_vhlle.sh --params examples/gubser.params --eos simple --outdir /tmp/gub
python3 scripts/check_gubser.py /tmp/gub/outx.dat --tau 1.5 --xcut 5.0 \
  --max-eps-reldiff 0.03 --max-vx-absdiff 0.02 \
  --center-eps 0.157676 --center-tol 1e-3
```

`check_gubser.py` compares vHLLE cell by cell against the closed-form solution

    v_r(tau,r) = 2 tau r / (1 + tau^2 + r^2)
    eps(tau,r) = 4^(4/3) / (tau^(4/3) D^(4/3)),  D = 1 + 2(tau^2+r^2) + (tau^2-r^2)^2

and checks the pinned central energy density and exact left-right symmetry.

Deck notes (see `references/failure-modes.md`): `tau0` MUST be 1.0 (the Gubser IC
is written at reference time 1); `nz 15` with a real eta extent is required or the
freeze-out surface finder returns zero and the run stops after one step; `e_crit
0.04` lets the diluting blob reach `tauMax`.

## glauber.params (production run, TABLE EoS)

Optical-Glauber viscous run (`icModel 1`, eta/s = 0.08) with the Laine lattice
EoS, the production code path for realistic collisions. No analytic reference;
the check is a completed, finite run with a sensible central QGP temperature.

```bash
scripts/run_vhlle.sh --params examples/glauber.params --eos table --outdir /tmp/gla
```

At the last timestep (tau=3.05) the central cell has eps = 3.211810 GeV/fm^3 and
T = 0.213454 GeV, identical on macOS/ARM and Linux/x86-64.

## Other initial states

For Glissando, Trento, SMASH or UrQMD initial states, supply the corresponding
table from `vhlle_params/ic/` via `--is-input`, and (for Glissando/Trento) a
`--system` label such as `RHIC200` or `LHC276`. See `references/input-format.md`.
