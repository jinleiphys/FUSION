# vHLLE verification

**Code:** vHLLE, Karpenko, Huovinen, Bleicher, *A 3+1 dimensional viscous
hydrodynamic code for relativistic heavy ion collisions*, Comput. Phys. Commun.
**185**, 3016-3027 (2014), DOI `10.1016/j.cpc.2014.07.010` (arXiv:1312.4160).
CrossRef-verified 2026-07-24. GPL-2.0 (`LICENSE.txt`, GNU GPL v2).

**Repo / pins:** `github.com/yukarpenko/vhlle` main @ `c3480d62b22ba8333015808c9188474ddea311df`
(2026-06-23); EoS/IC companion `github.com/yukarpenko/vhlle_params` @
`ae2ba98609ff1203e6ab6e9d201db0e708322717` (2025-11-20).

**Tier: 2 with an analytic physics benchmark.** vHLLE ships no reference output
file, so the benchmark is not "reproduce a distributed reference". Instead it is
pinned by two independent anchors: (1) a CODE-INDEPENDENT analytic solution
(ideal conformal Gubser flow), and (2) cross-platform reproduction of the
production code path. The first is stronger than a mere build-integrity check; it
tests the physics of the solver, not just that two builds agree.

## Build

Simple `make`, `g++`/`clang++`, C++17 (`std::filesystem`), GSL. No source
patches. The equation of state is a compile-time toggle in `src/eos.cpp`
(`#define TABLE` vs `SIMPLE`), documented by the code itself; `install_vhlle.sh`
flips only those two lines and restores the file, so the tree stays pristine.

- macOS 15 / Apple clang 21, GSL 2.8 (Homebrew): builds clean.
- Linux (heliumx) / gcc 13.3, GSL 2.8 (conda-forge): builds clean. The binary is
  linked with `-Wl,-rpath,<gsl>/lib` so a conda GSL is found at runtime.

## Stage 1: analytic Gubser flow (physics)

The ideal conformal Gubser solution (q = 1 fm^-1, reference tau0 = 1) is known in
closed form. `examples/gubser.params` (SIMPLE conformal EoS, icModel 4, ideal)
is evolved from tau = 1 and compared cell by cell along the x-axis against

    v_r(tau, r) = 2 tau r / (1 + tau^2 + r^2)
    eps(tau, r) = 4^(4/3) / ( tau^(4/3) D^(4/3) ),
                  D = 1 + 2(tau^2 + r^2) + (tau^2 - r^2)^2

At tau = 1.5, over |x| <= 5 fm (`check_gubser.py`):

| quantity | value |
|---|---|
| eps vs analytic, max reldiff | 0.0247 |
| eps vs analytic, rms | 0.0092 |
| vx vs analytic, max absdiff | 0.0127 |
| left-right symmetry, max reldiff | 0.0 (exact) |
| central eps(1.5, 0) | 0.157676 GeV/fm^3 (analytic 0.159564, 1.18%) |

The agreement degrades monotonically with time as numerical viscosity accumulates
(max eps reldiff 0.010 / 0.020 / 0.032 / 0.044 at tau 1.25 / 1.5 / 1.75 / 2.0),
exactly as expected for a finite-volume ideal-hydro solver, and matches the
quality of the paper's Section 4.1 Figures 5-6. The exact left-right symmetry is
a hard structural invariant that a broken solver would violate.

## Stage 2: optical-Glauber production run

`examples/glauber.params` (TABLE Laine EoS, icModel 1, etaS 0.08) is a realistic
viscous run on the production code path students use. No analytic reference; the
check is completion, finite output, and a pinned central anchor at the last
timestep tau = 3.05:

| quantity | value |
|---|---|
| central eps | 3.211810 GeV/fm^3 |
| central T | 0.213454 GeV (213 MeV, a sensible QGP temperature) |

## Cross-platform reproduction

The same two decks on macOS/ARM (clang 21) and Linux/x86-64 (gcc 13.3):

- **Gubser (SIMPLE):** every physically meaningful column (tau, x, vx, eps, T) is
  **bit-identical** across platforms. The SIMPLE EoS path is pure double
  arithmetic (no GSL spline), and with no FMA contraction the KT scheme gives
  identical IEEE results on both architectures. The ONLY cross-platform
  difference is the numerically-zero `vy` column (~1e-18), which differs at the
  last-bit ~4e-16 level; this shifts the printed field widths (so `cmp` and `diff`
  flag the file) but changes no physics. Confirmed by a column-wise numeric
  compare: max relative difference over all significant columns = 0.
- **Glauber (TABLE):** central eps and T identical to 6 significant figures across
  platforms (this path DOES use the GSL spline EoS, GSL 2.8 on both).

## Certification

`verify_vhlle.sh` with no preset builds BOTH binaries from the SHA-pinned pristine
source in the run (force re-clone + make), so the binaries are produced by make
here and cannot be a hand-forged drop-in; it ends in `VERIFY OK`. Presetting
`VHLLE_TABLE_BIN`/`VHLLE_SIMPLE_BIN` validates handed-in binaries but ends in
`VERIFY PASSED-NOT-CERTIFIED`.

- **macOS:** `VERIFY OK` (full clean-rebuild certification), ~85 s.
- **Linux (heliumx, gcc 13.3):** `VERIFY OK` (full clean-rebuild certification),
  every benchmark number identical to macOS. GitHub access from that host is
  intermittent, so the certifying clone used `VHLLE_URL`/`VHLLE_PARAMS_URL`
  pointing at a local mirror at the same pinned commits; the pin and pristine
  checks are unchanged by the URL source.

## What the adversarial pass found

One Codex (`codex exec`) adversarial pass, which built and ran the real code and
mutation-tested the guards. Its report was truncated by the provider's safety
filter (as on SMASH and Thermal-FIST), but the experiments it left behind named
the findings precisely. Six acted on:

1. **(major) verify certified with a non-canonical `VHLLE_PARAMS_PIN`.** Codex
   built against a different `vhlle_params` commit and still got `VERIFY OK`. The
   EoS/hadron tables are physics inputs, so certification must pin them too; the
   CERTIFIED check now downgrades on either a non-canonical `VHLLE_PIN` OR a
   non-canonical `VHLLE_PARAMS_PIN`.
2. **(major) run_vhlle passed on STALE output.** A no-op binary plus a leftover
   `outx.dat` in the output directory validated clean. `run_vhlle.sh` now clears
   `out*.dat`/`vhlle.log` in the target dir before the run, so a run that writes
   nothing produces no files and fails. A selftest case (no-op fake binary +
   pre-seeded output) locks this in.
3. **(minor) `--min-cols 19` accepted a 19-column file** while a real profile has
   20; tightened to 20 in `run_vhlle.sh` and the Glauber check.
4. **(gap) the vx-threshold and Glauber-anchor guards were not flip-tested.**
   Disabling the vx check left the selftest green. The Glauber anchor was
   extracted from a verify heredoc into `check_glauber.py`, and selftest now
   flip-tests the vx threshold and all four Glauber-anchor guards (wrong last-tau,
   wrong eps, wrong T, non-finite). selftest grew to 39 cases.
5. **(minor) check_gubser reported a bare PASS with no thresholds given**, when
   only the symmetry invariant was enforced. It now labels that case
   "symmetry only ... informational".
6. **(minor, preempted) `git clone` took the URL without `--`.** A `-`-leading
   `VHLLE_URL` could inject a git flag; added `--`.

Confirmed CLEAN by the pass (survived attack): the git-ignored `.git/info/exclude`
source-injection is caught by the untracked-stray guard AND cannot compile anyway
(the Makefile uses a fixed `SRC` list, not a glob); a table binary run on the
Gubser deck is correctly REJECTED by the analytic check (0.44 reldiff); the
symmetry and non-finite guards flip when disabled; the install probe rejects a
`true`-stub binary. Every fix was re-verified `VERIFY OK` on both platforms and
selftest 39/39.
