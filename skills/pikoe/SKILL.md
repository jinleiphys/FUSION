---
name: pikoe
description: >-
  Drive pikoe, the proton-induced knockout reaction code of K. Ogata, K. Yoshida and Y. Chazono (Comput. Phys. Commun. 297, 109058 (2024); MIT). Write, run and verify pikoe control files for (p,pN) quasi-free knockout in the distorted-wave impulse approximation: triple- and quadruple-differential cross sections, vector analyzing power, and residue momentum distributions, in normal and inverse kinematics with relativistic three-body kinematics. Use for 跑pikoe, pikoe input, DWIA, (p,2p), (p,pn), quasi-free scattering, QFS, 敲出反应, knockout reaction, TDX, QDX, 动量分布, momentum distribution, inverse kinematics knockout.
---

# Driving pikoe

pikoe computes exclusive proton-induced nucleon knockout, `(p,pN)`, in the
distorted-wave impulse approximation. The elementary process is a free NN
collision described by an on-shell NN transition amplitude (or the free NN cross
section), the incoming proton and the two outgoing nucleons move in one-body
optical potentials, and the kinematics are relativistic so the three-body
scattering wave has the correct plane-wave asymptotics. It is the successor to
Chant and Roos's THREEDEE, and its reason for existing is **inverse kinematics**:
the standard observable of the field, the triple-differential cross section,
misbehaves there, and pikoe adds the quadruple-differential cross section that
does not.

Reference: K. Ogata, K. Yoshida, Y. Chazono, *pikoe: A computer program for
distorted-wave impulse approximation calculation for proton induced nucleon
knockout reactions*, Comput. Phys. Commun. **297**, 109058 (2024), DOI
`10.1016/j.cpc.2023.109058`, MIT licence. Source: the author's RCNP page,
`https://www.rcnp.osaka-u.ac.jp/~kazuyuki/pikoe/`. The formalism follows
T. Wakasa, K. Ogata, T. Noro, Prog. Part. Nucl. Phys. **96**, 32 (2017), whose
Sec. 3.1 the paper cites as its notation source. Citation verified against
CrossRef; see `references/verification.md`.

## Prime rules (do not skip)

1. **The exit status is not a verdict.** pikoe's calculation record, including
   the `>>> calculation completed` banner, goes to the outlist file named by the
   `kibout` field of L16, not to stdout. Every shipped deck sets `kibout` to 6,
   which is why the record lands in a `.outlist` file; the unit number is a
   convention of the decks, not the mechanism. Assert the banner, assert that
   a table was written, and read stderr. `run_pikoe.sh` does all three.
2. **Decks reference their data tables by relative path** (`../elem/...`,
   `../pot/...`). Run them in the upstream layout or the open fails.
   `run_pikoe.sh` recreates that layout with symlinks; it never rewrites a deck.
3. **The input is fixed-format.** A value shifted one column is read as a
   different quantity and the run still completes. Start from a deck in
   `examples/` and edit in place. The authority is `input_man.txt` as shipped,
   transcribed in `references/input-reference.md`.
4. **Match `ielm` to the observable.** `ielm=4` (on-shell NN t-matrix) for TDX
   and QDX; `ielm=3` (free NN cross section) for momentum distributions, where
   the t-matrix route carries a stated 10 to 20 percent penalty from its
   azimuthal-integration approximation. Details in `references/failure-modes.md`.
5. **Upstream ships no reference output.** The readme documents one per sample
   directory; the archive contains none. This skill's benchmark is anchored on
   the CPC paper's published figures instead, and says so. Do not claim a
   reference-value reproduction for pikoe.
6. **No em-dashes in any prose you write** (user's flat rule).

## Environment (auto-install)

`scripts/install_pikoe.sh` fetches the archive from the RCNP page, unpacks,
builds with gfortran, and prints `PIKOE=<path>`. Requires `gfortran`, `curl`,
`unzip`.

- Disk about 55 MB, nearly all of it `elem/nnampFL.dat` (50 MB of Franey-Love NN
  amplitudes). Build takes about 3 seconds.
- Default install root `~/.cache/fusion/pikoe`; override with `PIKOE_ROOT`.
  `PIKOE_FC` and `PIKOE_FFLAGS` override compiler and flags.
- Only the PukiWiki attach-plugin URL serves the archive; the plain `.zip` URL
  returns 403 or 404. The script pins the working URL and the archive sha256.
- gfortran warns about deleted Fortran 2018 features (arithmetic `IF`, labelled
  `DO` termination). That is expected; the code is old-style Fortran.

## Workflow

1. Pick the closest deck in `examples/`. The five shipped cases are exactly the
   five figures of the paper, all for `12C(p,2p)11B` ground state:
   `12Cp2pTDXnorm.cnt` (TDX, normal kinematics, 392 MeV, Fig. 1),
   `12Cp2pMD.cnt` (momentum distributions at 392A MeV, Fig. 2),
   `12Cp2pMD100.cnt` (same at 100A MeV, Fig. 3),
   `12Cp2pTDXinv.cnt` (TDX, inverse kinematics, Fig. 4),
   `12Cp2pQDXinv.cnt` (QDX, inverse kinematics, Fig. 5).
2. Edit the deck. The lines that change most often: L3 charges and masses, L4
   `ikin` and beam energy per nucleon, L5 separation energy, L6 the `(j, l)` of
   the struck orbit and its spectroscopic factor, L10 `ivar` (which observable),
   L11 to L15 the scan ranges, L19 to L21 the optical potentials.
3. Check the kinematics first with `ical=0` on L2, the survey mode: it prints
   the kinematics without computing observables, and it is cheap. **It does not
   work for `ivar=9`**: the source silently overrides `ical` back to 1 for the
   momentum-distribution decks, which are exactly the expensive ones, and notes
   the override in the outlist.
4. Run: `scripts/run_pikoe.sh <deck.cnt> <workdir>`. Builds on first use.
5. Verify: `scripts/verify_pikoe.sh` reproduces the three fast sample cases in a
   clean room and checks the anchors. `MD` and `MD100` are opt-in because they
   take about an hour each.

## Choosing the observable

This is the physics content of the code and the most common way to get a
meaningless number, so it is worth stating plainly.

| kinematics | use | why |
|---|---|---|
| normal | TDX, `ivar=1` | the standard `(p,2p)` observable; QDX is ill-behaved here because `E1` and `E2` are strongly correlated |
| inverse | QDX, `ivar=3` | for given `(T1, Omega1, Omega2)` there can be two `T2` solutions, and the TDX **diverges** where they merge into a double root |
| either | momentum distributions, `ivar=9` | longitudinal, p_x, transverse and total distributions of the residue in the A-frame |

The divergence is physical bookkeeping, not a bug: the integrated TDX stays
finite, so an experiment sees an enhancement. But at that point the TDX no
longer maps onto the residue momentum distribution, which is the entire reason
one measures it. The two solution branches are labelled by the `isol` column of
the output table and must be split before plotting.

## Potentials and structure input

- `ipot=1` on L19 to L21 gives the built-in global potential: Koning-Delaroche
  for a nucleon, Avrigeanu for an alpha, Coulomb included. Valid 1 keV to 200
  MeV for near-spherical nuclei with 24 <= A <= 209.
- `ipot>9` reads a tabulated optical potential from that unit. For unstable
  nuclei the authors recommend exactly this, since no accurate global nucleon
  parametrization exists there, and offer to supply microscopic potential files
  on request. The package ships Dirac-phenomenology (EDAD1) potentials for
  p+12C and p+11B, used by all five sample decks.
- The bound state comes from a Woods-Saxon central plus derivative spin-orbit
  potential, or from the Bohr-Mottelson parametrization (`ibmc=1`), or is read
  from a file (`ish>9`). With `ish=1` the depth is adjusted to reproduce the
  separation energy you supply, which is the normal mode.
- Nonlocality is handled by the **Perey factor** (`betasp` on L5, `beta` on L19
  to L21), and by the Darwin factor when a Dirac-phenomenology potential is
  used. Worth knowing when comparing against transfer codes: the nonlocal
  transfer line (Titus, Ross, Nunes, CPC 207, 499 (2016)) exists precisely
  because the Perey correction was found inaccurate for transfer, so a
  quantitative comparison of nonlocality treatments across the two families is
  not apples to apples.

## Beyond (p,pN)

The authors state that the same machinery handles `(p,palpha)`, `(p,pd)` and
`(alpha,2alpha)` given appropriate elementary-process and potential tables, and
ship a nucleon-alpha table (`elem/N4He_Mel_10-800MeV.dat`) for that purpose. The
paper deliberately restricts its formulation to `(p,pN)`, and the analyzing
power is implemented only for nucleon-induced nucleon knockout in coplanar
kinematics. Treat cluster knockout as supported but unbenchmarked.

## Verified benchmarks

Clean room: fresh fetch, fresh build, fresh workdir with no output present,
stderr inspected, completion banner asserted. Full detail and the honest tier
statement in `references/verification.md`.

| case | check | result |
|---|---|---|
| `TDXnorm` | Fig. 1(a) two-peak TDX and Fig. 1(b) `Ay` | peaks at 40.5 and 61.0 degrees, 127.0 and 128.3 ub/(MeV sr^2); figure reads about 130 and 135 at 40 and 61 |
| `QDXinv` | Fig. 5 two-peak QDX | 0.1815 at 185 MeV and 0.1741 at 325 MeV; figure reads about 0.175 at 190 and 0.168 at 330 |
| `TDXinv` | Fig. 4 divergence structure | two `isol` branches, TDX rising steeply to the double root near 32.3 degrees |

Agreement is at figure-reading precision, a few percent, with peak positions
matching to the plotted resolution. That is the strongest statement available
for this code, because it distributes no reference numbers.
