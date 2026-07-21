---
name: nlat
description: >-
  Drive NLAT (nonlocal adiabatic transfer), the transfer-reaction code of L.J. Titus, A. Ross and F.M. Nunes (Comput. Phys. Commun. 207, 499 (2016); GPLv3). Build, run and verify NLAT decks for single-nucleon transfer (d,p), (d,n), (p,d), (n,d) with explicitly NONLOCAL optical potentials, solved by iteration rather than by the Perey correction factor, within the adiabatic distorted wave approximation. Also does deuteron and nucleon bound states and elastic scattering. Use for 跑NLAT, NLAT input, nonlocal transfer, 非定域, nonlocality, Perey-Buck, Perey factor, ADWA, adiabatic distorted wave, (d,p) transfer, 转移反应, DWBA transfer, Johnson-Tandy.
---

# Driving NLAT

NLAT computes single-nucleon transfer cross sections with **explicitly nonlocal**
nucleon-target optical potentials, inside the adiabatic distorted wave
approximation. That is its whole reason for existing. The standard treatment of
nonlocality in transfer is the Perey correction factor, a local wave-function
correction; the same group's earlier work (Titus and Nunes, PRC 89, 034609
(2014)) showed that correction to be inaccurate, so NLAT drops it and solves the
integro-differential equation directly, by iteration from a local seed.

Reference: L.J. Titus, A. Ross, F.M. Nunes, *Transfer reaction code with nonlocal
interactions*, Comput. Phys. Commun. **207**, 499-517 (2016), DOI
`10.1016/j.cpc.2016.06.022`, GPLv3, CPC catalogue identifier AFAY_v1_0.
The ADWA formalism is Johnson-Tandy (Nucl. Phys. A 235, 56 (1974)), extended to
nonlocal interactions in Titus, Nunes and Potel, PRC 93, 014604 (2016).

**Source location.** The paper points at the Queen's University Belfast CPC
Program Library, which is retired and returns HTTP 502. The code lives on
Mendeley Data: `https://data.mendeley.com/datasets/xnwjvk86bs/1`, DOI
`10.17632/xnwjvk86bs.1`, free, no login. `install_nlat.sh` handles this.

## Prime rules (do not skip)

1. **Never run a shipped deck inside the install tree.** Each deck names its own
   output directory, and that name is the sample directory itself, so running in
   place overwrites the distributed reference output and every later comparison
   passes trivially. `run_nlat.sh` always uses a fresh workdir and refuses a
   workdir inside the install tree; `verify_nlat.sh` sha256-fingerprints the
   reference contents before and after the run and aborts if anything changed.
2. **Do not add or remove lines in a deck.** The input is a conditional
   interview, not a fixed layout: `front_end.f90` decides what to read next from
   what it has already read, and every read is list-directed, so a shifted line
   raises no error and silently reinterprets the rest. Edit values in place.
3. **Empty output files are normal and are not evidence.** NLAT creates every
   enabled output file whether or not that calculation ran; a local run leaves
   five nonlocal files at zero bytes, and the distributed reference contains
   those same five empty files. An empty-versus-empty comparison is not a pass.
4. **`beta = 0.05` fm for the local limit, never 0** (the kernel divides by it).
   And beware `StepSize = 0.01` fm, which the paper recommends: the paper also
   says that step needs the small-radius cutoff raised from 2 to 3, but **the
   released code exposes no such input**. AFAY_v1_0 hardcodes the equivalent of
   2 in `SOURCE/nm.f90` (`nmin = int(2*L)`), so using the recommended step means
   editing that line. Detail in `references/failure-modes.md`.
5. **The abstract's "4% accuracy" is not a verified figure.** It appears only in
   the abstract and is never derived in the body. Quote the three component
   checks instead (see `references/verification.md`).
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_nlat.sh` fetches AFAY_v1_0 from Mendeley Data, unpacks, builds
with gfortran, verifies the binary runs, and prints `NLAT=<path>`. Requires
`gfortran`, `make`, `curl`.

- Archive 15 MB, install about 49 MB (the sample directories carry reference
  output). Build takes a few seconds.
- Default install root `~/.cache/fusion/nlat`; override with `NLAT_ROOT`.
- The archive sha256 is pinned, and its byte count independently matches the
  15253066 printed in the paper's own program summary.
- `-std=legacy` is required and already in the upstream gfortran makefile: the
  package mixes free-form `.f90` with fixed-form `.f` and `.for`.

## Workflow

1. Start from a deck in `examples/`: `dp48Ca_10-0_DWBA.in` (local, DWBA,
   48Ca(d,p) at Ed = 10 MeV) or `dp48Ca_20-0_NL.in` (nonlocal, ADWA, same
   reaction at Ed = 20 MeV).
2. Edit values in place. Never insert or delete lines (rule 2). To build a deck
   with a different structure, use upstream's `make-input` generator, which asks
   the questions in the order `front_end.f90` reads them.
3. Run: `scripts/run_nlat.sh <deck.in> <workdir>`. Builds on first use, runs in a
   clean workdir, and asserts that an output directory was created holding at
   least one non-empty result file.
4. Verify: `scripts/verify_nlat.sh` reproduces both distributed samples in a
   clean room and compares numerically against the shipped reference output.

## What it calculates

`WhatCalc` on the first line selects the job:

| value | calculation |
|---|---|
| 1 | n+p bound state (the deuteron) |
| 2 | N+A bound state |
| 3 | d+A scattering state |
| 4 | N+A scattering state |
| 5 | **(d,N) transfer** |
| 6 | **(N,d) transfer** |

`(p,d)` and `(n,d)` come from the corresponding `(d,N)` calculation **by detailed
balance**, not by a separate reaction calculation.

The T-matrix is exact post-form with the **remnant term neglected**, which the
paper justifies for intermediate-mass and heavy targets. The deuteron is treated
in the Johnson-Tandy ADWA with a **single Weinberg state** and an **s-wave-only**
deuteron, so there is no d-state. For the pre-defined Perey-Buck and TPM potentials, nonlocality is applied to the
**volume and surface** terms with spin-orbit and Coulomb local, which is how
those potentials are defined. The code itself does accept a nonlocal spin-orbit
term on the user-defined route, which also carries an upstream parser bug; see
`references/input-reference.md`.

## Potentials

- Local, pre-defined: **Daehnick** for the deuteron; **Koning-Delaroche** or
  **Chapel Hill CH89** for a nucleon.
- Nonlocal, pre-defined: **Perey-Buck** or **TPM** (Tian-Pang-Ma), both
  Woods-Saxon form factors with a Gaussian nonlocality of range `beta`.
- Nonlocal, read in: an external kernel from `NLpotBound.txt` or
  `NLpotScat.txt`, which is the hook for a microscopic or dispersive optical
  potential. The scattering kernel needs one block per `LJ` partial wave in the
  order NLAT loops, L outer and J inner, for every combination even when the
  potential depends only on L. Format in `references/input-reference.md`.
- Nonlocal DWBA is accepted by the code but the paper notes **no nonlocal
  deuteron parametrization exists**, so in practice the nonlocal route means
  ADWA built from nonlocal nucleon potentials.

## Relation to the rest of the field

Worth knowing when comparing codes, because the treatments genuinely disagree:

- **Against the Perey factor.** NLAT exists because the Perey correction was
  found inaccurate for transfer. Codes that apply a Perey factor to a local
  calculation, including the knockout code pikoe in this same skill pack, are
  making the approximation NLAT was written to avoid. That is a live
  methodological difference, not a formatting detail.
- **Against direct-inversion solvers.** SIDES (Blanchon et al., CPC 254, 107340
  (2020)) and SWANLOP (Arellano and Blanchon, CPC 259, 107543 (2021)) solve the
  same class of nonlocal equation by direct matrix inversion and explicitly
  define themselves against iterative schemes, citing NLAT: "without resorting to
  any ad-hoc seed as required in iterative methods". NLAT's own position is that
  convergence takes fewer than 10 iterations in most cases, more at small L.
  Those codes do elastic scattering only; NLAT does transfer.
- **Validation partners.** The paper checks local elastic and bound states
  against **FRESCO**, and the local adiabatic potential against **TWOFNR**. The
  exact three-body benchmark for ADWA is Faddeev (Deltuva; Nunes and Deltuva).

## Verified benchmarks

Clean room: fresh fetch, fresh build, fresh workdir, references fingerprinted and
confirmed untouched. Numeric comparison rather than `diff`, because full
double-precision output differs in the last digit across compilers. Detail in
`references/verification.md`.

| sample | physics | result |
|---|---|---|
| `local` | 48Ca(d,p) at Ed = 10 MeV, local DWBA | 14 files, 1,863,151 numbers, worst relative difference 2.1e-11 (on a value of magnitude 6e-22, i.e. the noise floor), nothing above 1e-6 |
| `nonlocal` | 48Ca(d,p) at Ed = 20 MeV, nonlocal ADWA | 11 files, worst relative difference 8.4e-07 (the two nonlocal S-matrices, which carry the iteration's stopping tolerance); TransferCS agrees to 1.3e-12. 1 h 26 min |

This is a **tier 1** benchmark: the distribution ships reference output and the
skill reproduces it to essentially machine precision.

One declared deviation, pinned and evidence-backed: the nonlocal reference
`TransferCS.txt` carries 180 angles where the shipped deck and code produce 179.
Its reference files are dated a month before the deck they ship with, so they
are stale upstream; the 179 shared angles agree to 1.3e-12. See
`references/verification.md`.
