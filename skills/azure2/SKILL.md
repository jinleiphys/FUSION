---
name: azure2
description: >-
  Drive AZURE2, the Notre Dame multichannel R-matrix code of Azuma et al. (Phys. Rev. C 81, 045805 (2010); GPL-3.0). Write, run and verify .azr configuration files for low-energy charged-particle reactions in nuclear astrophysics: radiative capture, elastic scattering, resonance and subthreshold contributions, external (direct) capture normalised by ANCs, S-factor extrapolation to stellar energies, and reaction rates. Use for 跑AZURE2, AZURE2 input, .azr, R-matrix, R矩阵, 天体物理S因子, astrophysical S factor, direct capture, external capture, ANC, 渐近归一化系数, subthreshold state, CNO cycle capture, resonance analysis.
---

# Driving AZURE2

AZURE2 solves the multichannel, multilevel R-matrix equations for low-energy
reactions. It handles resonant capture, external (direct) capture normalised by
an asymptotic normalisation coefficient, subthreshold states, and the
interference between them, and it extrapolates to the sub-keV energies where the
cross section cannot be measured. That extrapolation is the point of the code.

Upstream: `github.com/rdeboer1/AZURE2`, GPL-3.0, anonymously clonable. The
project's other channel, `azure.nd.edu`, is registration-gated and this skill
never touches it.

## Prime rules (do not skip)

1. **This is a TIER 2 skill and must be described as one.** AZURE2 ships **no
   example input and no reference output**, so nothing here reproduces a
   distributed file. The benchmark case is *constructed* from a published
   parameter table. It reproduces the published **inputs** exactly and the
   published **S factor to 4 to 6 percent**. Never claim it reproduces the
   paper's S factor. `examples/16O_pg_17F/verification.md` states exactly what
   is and is not established.
2. **AZURE2 is interactive and will hang, not fail, if unanswered.** It prints a
   menu on stdin and then asks for an external parameter file. Always drive it
   through `scripts/run_azure2.sh`, or pipe the answers yourself.
3. **A stale `param.par` silently overrides your deck.** If the file exists in
   the output directory, AZURE2 reads the parameters back from it and ignores
   the widths in the `.azr`. The deck you are reading is then not the
   calculation you are getting. `run_azure2.sh` clears it unless
   `AZURE2_KEEP_PARAMS` is set.
4. **Content is the verdict, never exit status and never file existence.** The
   run wrapper asserts that this run wrote a non-empty result file containing
   only finite numbers. A diverging R-matrix solve writes `nan` and exits 0.
5. **The output and checks directories must already exist.** AZURE2 will not
   create them; it stops with "Could not find output directory".
6. **`--no-transform` destroys the ANC normalisation. Do not reach for it** to
   enter reduced-width amplitudes directly. It agrees with transform mode at one
   channel radius and diverges by a factor of 4 across a 2 fm range, because it
   bypasses the ANC-to-amplitude conversion. Details below.
7. **There are no comments in a `.azr`.** A `#` line inside `<levels>` is parsed
   as a level line and fails. Section markers must match byte-exactly, with no
   leading or trailing whitespace and Unix line endings.
8. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_azure2.sh` clones AZURE2, builds the standalone Minuit2 it
needs, builds AZURE2 headless, and prints `AZURE2=<path>`. About 19 s from a
cold cache. Requires `git`, `cmake`, `gsl`, and a GNU `g++` (AZURE2 requires
OpenMP and this build mangles Apple clang's shim).

It encodes **seven** fixes, five of which report symptoms pointing away from
their cause; they are documented inline at the top of the script and in
`references/failure-modes.md`. The one most likely to bite again: Homebrew GCC
bakes in an SDK path that goes stale after an Xcode upgrade, and the resulting
error names a missing `_bounds.h` rather than a sysroot.

## Workflow

```bash
bash scripts/install_azure2.sh                          # prints AZURE2=<path>
bash scripts/run_azure2.sh mycase.azr 3                 # 3 = calculate, no data
bash scripts/verify_azure2.sh                           # run the benchmark
bash scripts/selftest_azure2.sh                         # test the harness itself
```

`selftest_azure2.sh` feeds the wrapper deliberately broken inputs and asserts it
refuses each one: a malformed marker, a missing data file, a locked output
directory, six shapes of exit-0-with-bad-output, and an unsupported menu choice,
plus two cases it must NOT refuse (a stale file from an earlier run, an output
path containing a space). Run it after touching either script. Every case in it
was added after an adversarial pass found the harness accepting that failure, so
a guard that quietly stops firing is caught rather than assumed. It is verified
to be capable of failing: disabling any single guard flips exactly one case.

Menu choices: `1` calculate using data, `2` fit, `3` calculate without data
(uses `<segmentsTest>`). `run_azure2.sh` refuses 4 and 5, which ask further
questions it does not answer.

## Writing a `.azr`

The format is undocumented in the repo. `references/azr-format.md` is the
authority here and was derived **from the parser source**, not from a manual or
from memory. Read it before editing a deck. The essentials:

- Sections in order: `<config>`, `<levels>`, `<segmentsData>`, `<segmentsTest>`,
  `<targetInt>`. An empty `<targetInt></targetInt>` is required, not optional.
- One line per **channel**, with the level's own information repeated on every
  channel line of that level. 31 whitespace-separated fields.
- **`s` and `l` are stored as twice their physical value.** For a gamma channel
  `l` is twice the multipolarity, so E1 is written `2`.
- Particle pairs are defined implicitly by the channel lines; the pair key is
  field 6 and is 1-based.
- Field 12 changes meaning with the channel: **ANC in fm^(-1/2)** for a bound
  particle channel, **partial width in eV** for an unbound one and for a capture
  channel. This mixing is why converting a published table takes care.

### The two traps that cost the most time

**Entrance partial waves exist only if a level carries them.** AZURE2 enumerates
external-capture pathways over the Jπ groups present among the supplied levels
(`src/CNuc.cpp:740-800`). A partial wave your paper says contributes is silently
absent unless some level has that Jπ. deBoer's FRIB/TALENT lecture states the
workaround outright: *"AZURE2 eccentricity, need to add 'dummy' levels to tell
code which angular momenta to include in hard sphere phase shift
calculations."* Such levels carry no fitted physics, which is exactly why
published parameter tables omit them. Verify any dummy is inert by moving it in
energy and confirming the result does not change.

**Use transform mode, not `--no-transform`.** Measured on the benchmark case:

| `ac` | transform (ANC live) | `--no-transform` |
|---|---|---|
| 4.5 fm | 7.6328 keV b | 5.28 keV b |
| 5.0 fm | 7.6080 keV b | 7.60 keV b |
| 5.5 fm | 7.6173 keV b | 10.72 keV b |

ANC-normalised external capture *must* be nearly independent of the channel
radius, because the ANC fixes the asymptotic tail. Transform mode is flat to
0.4%. The two modes agree at 5.0 fm, so **a check at a single radius cannot tell
them apart**; vary the radius.

The `--no-transform` column is measured with the bound-state entries replaced by
the **formal amplitudes** AZURE2 itself reports (0.805998 and 1.174864
MeV^(1/2)), not with Table V's ANCs typed in literally. That distinction is
worth stating because the literal-ANC version is *worse*, not merely different:
it gives S(90 keV) = 19.66 keV b at ac = 5.0 fm, since fm^(-1/2) values are then
read as MeV^(1/2) amplitudes. So the honest summary is that `--no-transform`
fails in two separate ways, and the radius sweep above isolates the subtler one.


## Converting a published parameter table

Papers quote reduced-width amplitudes (MeV^(1/2)); AZURE2 wants partial widths
in eV. Do **not** convert by hand: your own penetrability calculation between the
paper and the benchmark can hide a format error behind a compensating arithmetic
error. Invert AZURE2's own transform instead, as
`examples/16O_pg_17F/calibrate_widths.py` does: run, read `g_int` back from
`parameters.out`, drive each width to its published value by secant iteration.

Two things that script learned the hard way, both worth reusing:

- The target is `g_int` in `parameters.out`, not the formal amplitude in
  `param.par`. For a capture channel with external capture on, the two differ.
- **Do not fix the input sign from the sign of the published amplitude.** A
  capture channel's reported `g_int` carries a large negative offset set by the
  resonant external-capture term, so a *negative* published amplitude can require
  a *positive* input width. Search the width signed, over the whole real line.

## Verified benchmark

**¹⁶O(p,γ)¹⁷F**, constructed from Azuma et al., PRC 81, 045805 (2010), Sec. IV C
and Table V. `scripts/verify_azure2.sh` checks three levels:

| level | what is checked | result |
|---|---|---|
| L1 | all 9 published parameters of Table V | **exact** |
| L2a | this deck's own pinned S(90 keV) | 7.6080 keV b, 0.2% |
| L2b | the paper's published S(90 keV) = 8.07 | within 8%, **actual −5.7%** |
| L2c | measured Rolfs (1973) data, nothing fitted | **χ²/N = 1.53** |

L2c is the only check independent of the paper's own number, and it is the
strongest evidence the external-capture machinery is wired correctly.

**14N(p,gamma)15O, the 6.79 MeV transition**, from Tables II and III of the same
paper: S_6.79(0) = **1.257 keV b** against the published **1.30**, i.e. **-3.2%**.
That is inside the 0.1 keV b data-selection sensitivity the paper's own Table IV
caption puts on this number. Deliberately partial: it is one transition of seven,
because the rest are not reconstructable (below). It is the largest one, 72% of
the total, and is tractable precisely because the paper says its resonance term
is "added incoherently", so no relative sign is needed. Checks: dummy levels
inert across 15/20/30 MeV, channel radius flat to 1.6% over 5.0-6.0 fm, ANC
scaling within 2% of exact C^2, and the resonance worth 0.6% at E -> 0, which
bounds the paper's unstated M1-vs-E2 multipolarity to an immaterial effect.
Note ac = **5.5 fm** here, not the 5.0 fm of the 16O case.

The −5.7% is real and its causes were bounded, not waved away: the channel
radius (0.4%), the resonance parameters (0.02 keV b), the li = 3 pathway
(0.07%), nuclear masses, lab-vs-CM energy, GSL Coulomb functions and the
evaluated excitation energy were each tested and none closes it. The dominant
sensitivity is the proton separation energy, which the paper never states and
which moves S by 13% per 3 keV. See `examples/16O_pg_17F/verification.md`.

## Cases that cannot be built from a paper

**¹⁴N(p,γ)¹⁵O from the same paper is NOT reconstructable**, and the reason
generalises. Table IV publishes S(0) per transition, which looks like an ideal
numeric anchor, but the input side is incomplete: Table II covers γ widths for
"the three strongest transitions" only, the 5.18 MeV final state has neither an
ANC nor a γ width anywhere, and, decisively, **the signs of the reduced-width
amplitudes are not published** while the ground-state S(0) is set by destructive
interference among four 3/2+ components. Choosing those signs would be inventing
the answer.

The lesson to carry: **a table of results is only an anchor if the table of
inputs is complete, including signs and phases.** Check the input side before
promising a benchmark. The tractable subset, the 6.79 MeV transition (72% of the total, dominated by
external capture, explicitly "added incoherently" so no sign ambiguity), **is
built**: see `examples/14N_pg_15O_679/`.

## References

- `references/azr-format.md`: the file format, field by field, with source
  citations. Written from `include/NucLine.h`, `src/Config.cpp`, `src/EData.cpp`
  and the GUI writer, never from memory.
- `references/failure-modes.md`: build failures, silent-wrong-answer modes, and
  what each misleading error message actually means.
- `examples/16O_pg_17F/`: the benchmark deck, its data variant, the calibration
  script, and `verification.md`.
- `examples/talent/`: measured data from FRIB/TALENT Course 6, with sources.
