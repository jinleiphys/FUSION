# KSHELL output format

`kshell.exe` writes everything to stdout (the run wrapper captures it to a log).
The physics is the eigenvalue summary near the end.

## The eigenvalue summary

One block per computed state:

```
   1  <H>:   -40.46689  <JJ>:     0.00000  J:  0/2  prty  1
                        <TT>:     0.00000  T:  0/2
 <p Nj>  0.201  1.064  0.735
 <n Nj>  0.201  1.064  0.735
   <Qp>    ...   <Qn>    ...   <eQ>   ...
```

- `<H>` is the eigenvalue (the shell-model energy in MeV, relative to the core
  with the interaction's single-particle energies). State 1 is the ground state.
- `<JJ>` is the expectation of J^2 = J(J+1); `J: 2J/2` prints twice the total
  angular momentum (so `J: 4/2` means J=2). `prty` is the parity (+1/-1).
- `<TT>` / `T` are isospin; `<p Nj>` / `<n Nj>` the proton/neutron orbit
  occupations; `<Qp>`, `<Qn>`, `<eQ>` the quadrupole moments.

`run_kshell.sh` parses each `N <H>: E <JJ>: JJ J: 2J/2 prty P` line into
(index, energy, 2J, parity), requires a finite negative ground state, ascending
energies, and at least the requested number of states, then prints the spectrum
with excitation energies. Success is read from these lines, never from the exit
status.

## The Lanczos convergence trace

Before the summary, KSHELL prints the Lanczos iteration history:

```
H  lanczos    38   38     -40.466888     -38.771054     -36.375770  ...
```

each row is one iteration, the columns the current estimates of the lowest
eigenvalues. Watching the first column stabilize confirms convergence. This trace
is diagnostic; the converged values are what the summary reports.

## Other outputs

- `fn_save_wave` (if set) writes the eigenvectors to a `.wav` file, used by the
  `transit` executable to compute E2/M1 transition strengths between states.
- `hw_type` and the oscillator length appear near the top
  (`hbar_omega = ... MeV; b = ... fm`); they set the length scale for transition
  operators and do NOT affect the eigenvalues.
- Temporary `tmp_snapshot_*` / `tmp_lv_*` files hold Lanczos restart data during
  the run; the shipped test scripts delete them afterward. The run wrapper works
  in a scratch directory, so they never accumulate in the source tree.

## count_dim

`count_dim.py` (Python) reports the M-scheme dimension of a case without
diagonalizing, useful to size a run before launching it. The skill does not need
it for the benchmark but it ships in `bin/`.
