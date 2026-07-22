---
name: cgmf
description: >-
  Drive CGMF, the LANL fission-fragment de-excitation Monte Carlo code of Talou, Stetcu, Jaffke, Rising, Lovell and Kawano (Comput. Phys. Commun. 269, 108087 (2021); BSD-3-Clause). Run and analyse event-by-event simulations of prompt fission neutrons and gammas emitted by excited fission fragments, for spontaneous fission (Cf-252/254, Pu-238/240/242/244) and neutron-induced fission (U-233/234/235/238, Np-237, Pu-239/241) from thermal to 20 MeV: average and distributional neutron and gamma multiplicities, spectra, fragment mass/charge/TKE yields, and n-gamma correlations. Use for 跑CGMF, CGMF input, 裂变, fission, prompt fission neutrons, PFNS, prompt fission gammas, nu-bar, 中子多重性, neutron multiplicity, fission fragment yields, Hauser-Feshbach fission, 252Cf spontaneous fission, event-by-event fission.
---

# Driving CGMF

CGMF simulates the de-excitation of fission fragments event by event. It samples
the initial fragment distribution in mass, charge, kinetic energy, excitation
energy and spin at scission, then follows each fragment down through a Monte
Carlo Hauser-Feshbach cascade, emitting prompt neutrons and gammas. The output
is a history file, one record per fission event, from which all fission
observables are computed in post-processing.

Upstream: `github.com/lanl/CGMF`, BSD-3-Clause, C++ and CMake. It builds clean on
macOS and Linux with no patches, which is why it is the fission/statistical code
in FUSION and GEF (FreeBASIC, no Apple-Silicon toolchain) is not.

## Prime rules (do not skip)

1. **CGMF is deterministic, which is the whole benchmark.** Event `i` is seeded
   from `i` (plus the `-s` offset), so the same build and args give
   bit-identical output. The repo ships byte-exact `.reference` history files,
   and this skill's `verify_cgmf.sh` reproduces them exactly. That is a genuine
   **tier 1** benchmark, unusual for a Monte Carlo code.
2. **Content is the verdict; the exit status is necessary but not sufficient.**
   cgmf.x can fail to find its data tables and `exit(-1)`, but it can also exit
   0 having written a truncated or diverged history, so a clean exit alone
   proves nothing. `run_cgmf.sh` requires all of: a zero exit, empty stderr, a
   header matching the request, exactly 2*nevents fragment blocks, and a finite
   positive `<nu>_tot`.
3. **cgmf.x never reads the current directory for its data.** It resolves the
   102 MB data path as `-d`, then `$CGMFDATA`, then two compiled-in paths. The
   wrappers export `CGMFDATA` from the installer so a run works from any cwd.
4. **The ZAID is the TARGET, not the compound nucleus.** For n+235U use
   `-i 92235`, not 92236. For spontaneous fission the ZAID is the fissioning
   nucleus and the incident energy is `-e 0.0`.
5. **Results are statistical.** Observables carry a Monte Carlo error ~ σ/√N.
   Quote agreement statistically and pin the event count; never call a physics
   number exact. (The regression reproduction of the reference file IS exact,
   because it fixes the event count and the seed. Keep the two ideas separate.)
6. **All distributional observables come from the Python post-processor**
   CGMFtk (`tools/CGMFtk`), not from cgmf.x, which prints only run averages to
   stdout. See `references/output-format.md`.
7. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_cgmf.sh` clones CGMF, builds it with CMake, verifies the binary
runs a 2-event probe cleanly, and prints two lines:

```
CGMF=<path to cgmf.x>
CGMFDATA=<path to the data directory>
```

About 10 s from a cold cache. Requires `git` and `cmake` and a C++ compiler.
Disk is ~100 MB of data tables plus the build, far lighter than TALYS.

## Command line

```
cgmf.x -i <ZAID> -e <Einc_MeV> -n <nevents> [-s <start>] [-f <base>] [-t <window>] [-d <datadir>]
```

- `-i` ZAID = 1000*Z+A of the target (or fissioning nucleus for SF). Required.
- `-e` incident neutron energy in MeV; **`0.0` = spontaneous fission**. Required.
- `-n` number of events; **negative n** switches to initial-yields mode
  (writes `yields.cgmf` instead of histories).
- `-s` starting-event offset (seed skip-ahead), default 1.
- `-f` output base name; **the MPI rank is always appended**, so `-f h` writes
  `h.0`.
- `-t` isomer time-coincidence window in seconds (default 1e-8); **`-1`** means
  an infinite window and adds a gamma emission-age column, other negatives are
  rejected.
- `-d` data directory, overriding `$CGMFDATA`.

There is no `-h`: an unknown flag makes getopt print `illegal option` to stderr
and the run then continues, so with valid `-i -e -n` it still completes, but
`cgmf.x -h` alone (no required args) segfaults. There is no seed flag;
reproducibility is structural (rule 1).

Full field-level reference: `references/input-format.md` and
`references/output-format.md`, both derived from the source and the shipped
manual, not from memory.

## Workflow

```bash
bash scripts/install_cgmf.sh                     # prints CGMF= and CGMFDATA=
bash scripts/run_cgmf.sh 98252 0.0 1000 h        # 252Cf(sf), 1000 events -> h.0
bash scripts/verify_cgmf.sh                       # the benchmark
bash scripts/selftest_cgmf.sh                     # test the harness guards
```

To compute observables from a history file, use CGMFtk:

```python
from CGMFtk import histories as fh
h = fh.Histories('h.0')
h.nubartot()     # average neutrons per fission event (incl. pre-fission)
h.nubarg()       # average gammas per fragment
h.nubarA()       # nu-bar as a function of fragment mass
```

## Verified benchmark

**252Cf spontaneous fission and thermal n+235U**, against the reference history
files shipped in `utils/cgmf/tests/`:

| check | result |
|---|---|
| L1a 252Cf(sf), 40-event history | **bit-exact** vs the shipped reference |
| L1b n(thermal)+235U, 40-event history | **bit-exact** vs the shipped reference |
| L2 nu-bar_tot(252Cf sf), n=500 | 3.78, within MC error of the manual's 3.82 |

L1 is tier 1: the distribution ships reference output and this build reproduces
it byte for byte, on macOS/ARM, because the code is integer-deterministic. The
match is stable across Release and Debug builds here; the reference's origin
platform is not documented, so this is a reproduction of the LANL-shipped file,
not a proven cross-platform result. The manual quotes nu-bar_tot = 3.82 for 252Cf(sf) at 1e6
events; a fixed-seed run converges to that (see `references/verification.md`),
while low event counts scatter around it (3.80 at 40, 3.78 at 500, 3.72 at 3000)
as Monte Carlo noise.

## Failure modes

See `references/failure-modes.md`. The ones that bite: the data path is not the
cwd (rule 3); the output filename gains a `.0` rank suffix; the ZAID is the
target not the compound; and a run with an unsupported ZAID or energy fails
through stderr, so the exit status alone will mislead you.
