# The `.azr` file format

**Derived from the AZURE2 parser source, not from a manual.** The repository
ships no format documentation, so every claim below cites the code that
establishes it. Paths are relative to the AZURE2 source tree. Verified against
AZURE2 as cloned from `github.com/rdeboer1/AZURE2` in July 2026.

## Section order

The GUI writer defines the canonical order (`gui/src/AZURESetup.cpp:471-509`):

```
<config>        ... </config>
<levels>        ... </levels>
<segmentsData>  ... </segmentsData>
<segmentsTest>  ... </segmentsTest>
<targetInt>     ... </targetInt>
<lastRun>       ... </lastRun>        (GUI only, optional)
```

**Marker lines are compared with exact string equality** by the console reader
(`src/Config.cpp:40`, `src/CNuc.cpp:109`, `src/EData.cpp:43,144,291`). No leading
or trailing whitespace, Unix line endings only. The console re-scans from the
top for each section, so order does not strictly matter for `--no-gui`, but keep
it canonical.

Blank lines inside a section are skipped. **Comments do not exist**: a `#` line
inside `<levels>` is parsed as a level line and fails.

`<targetInt></targetInt>` is **required even when empty**. Its absence is a fatal
"Could not fill data object from file" (`src/EData.cpp:126-129`, `291-292`).

`<externalCapture>` is legacy, GUI-only, never written, ignored by the console.
Do not use it; put the multipolarity mask in field 31 of the level lines.

## `<config>`

Eleven lines, one value each (`src/Config.cpp:35-94`):

| # | Field | Values |
|---|---|---|
| 1 | isAMatrix | `true` / `false` |
| 2 | outputDirectory | path, **must end in `/`**, must already exist |
| 3 | checksDirectory | same |
| 4-11 | compound, boundary, data, lMatrix, legendre, coulAmp, pathways, angDists checks | `screen` / `file` / `none` |

Text after the last `#` on lines 2 and 3 is stripped (`src/Config.cpp:45-64`), so
a trailing comment is allowed there. Neither directory is created by AZURE2
(`src/Config.cpp:101-114`).

## `<levels>`: 31 fields, one line per CHANNEL

The level's own information repeats on every channel line belonging to it. The
authoritative field order is the single `operator>>` at `include/NucLine.h:18-26`:

```cpp
stream >> levelJ_ >> levelPi_ >> levelE_ >> levelFix_ >> aa_ >> ir_
       >> s_ >> l_ >> levelID_ >> isActive_ >> channelFix_ >> gamma_ >> j1_ >> pi1_
       >> j2_ >> pi2_ >> e2_ >> m1_ >> m2_ >> z1_ >> z2_
       >> entranceSepE_ >> sepE_ >> j3_ >> pi3_ >> e3_
       >> pType_ >> chRad_ >> g1_ >> g2_ >> ecMultMask_;
s_/=2.;  l_/=2;
```

| # | Name | Units / convention |
|---|---|---|
| 1 | levelJ | ħ, half-integers allowed |
| 2 | levelPi | `+1` / `-1` |
| 3 | levelE | **MeV, excitation energy in the compound nucleus** |
| 4 | levelFix | `1` = fixed in fit |
| 5 | aa | deprecated, GUI writes `1` |
| 6 | **ir** | **1-based pair key** of this channel |
| 7 | **s** | **2 x channel spin** |
| 8 | **l** | **2 x orbital angular momentum**; for a gamma channel, 2 x multipolarity |
| 9 | levelID | GUI bookkeeping |
| 10 | isActive | `1` = include, else the line is skipped |
| 11 | channelFix | `1` = fixed in fit |
| 12 | **gamma** | **meaning depends on channel type, see below** |
| 13-14 | j1, pi1 | light particle spin, parity |
| 15-16 | j2, pi2 | heavy particle spin, parity |
| 17 | e2 | **MeV**, excitation energy of the heavy particle |
| 18-19 | m1, m2 | **amu** |
| 20-21 | z1, z2 | charges |
| 22 | entranceSepE | deprecated, unused (`include/NucLine.h:119-121`) |
| 23 | sepE | **MeV**, separation energy of pair `ir` |
| 24-26 | j3, pi3, e3 | deprecated, GUI writes `0 0 0.0` |
| 27 | **pType** | `0` particle-particle, `10` particle-gamma, `20` beta decay |
| 28 | chRad | **fm** |
| 29-30 | g1, g2 | g-factors |
| 31 | **ecMultMask** | external-capture multipolarity bitmask: `1`=E1, `2`=M1, `4`=E2, OR-combined (`include/Constants.h:15-17`) |

All 31 are mandatory for the console path; a short line sets `failbit` and
`CNuc` returns -1 (`src/CNuc.cpp:126`). Column widths in the GUI writer are
cosmetic; parsing is whitespace-delimited.

### Field 12 changes meaning with the channel

Under the default transform (`src/CNuc.cpp:403-478`):

| Channel | Field 12 is |
|---|---|
| particle, unbound (`levelE - e2 - sepE > 0`) | **partial width in eV** (`:423`) |
| particle, bound | **ANC in fm^(-1/2)** (`:435`) |
| gamma E/M, normal transition | **partial width in eV** (`:468`) |
| M1 to the pair's own heavy state | magnetic moment in nuclear magnetons (`:446-457`) |
| E2 to the pair's own heavy state | quadrupole moment in barns (`:458-460`) |

The **sign is preserved** into the reduced-width amplitude. With
`--no-transform`, field 12 is the formal reduced-width amplitude in MeV^(1/2)
throughout, and the ANC conversion does not happen (see `failure-modes.md`).

### Radiation type is derived, not declared

`src/AChannel.cpp:11-24`: for `pType == 10`, the type is `E` if
`levelPi * pi2 == (-1)^l`, else `M`. There is no `else` branch and no validation,
so any combination is accepted.

### Capture pairs

For a gamma pair, fields 13-14 and 18/20 describe the **gamma** (`j1 = 1.0`,
`pi1 = +1`, `m1 = 0`, `z1 = 0`, `g1 = 0`; `gui/src/AddPairDialog.cpp:151-168`),
and 15-17/19/21 the residual nucleus. **`sepE = 0.0`** and **`e2` = the
excitation energy of the final bound state** (`src/CNuc.cpp:190,196`); a nonzero
`sepE` corrupts every gamma energy (`src/CNuc.cpp:408-410`).

Set `s` to twice the residual nucleus spin. The engine does not use it, but two
capture lines differing only in `s` become distinct channels and double-count.

### External capture and the final state

`CNuc::ParseExternalCapture` (`src/CNuc.cpp:182-259`) reuses an explicitly
supplied bound level if one exists at the right energy (tolerance 1e-3 MeV,
`src/JGroup.cpp:35`), and **auto-creates one with a dummy reduced width of 0.1
if not**. An auto-created level is outside the R-matrix and its field-12 value is
never transformed, so **always supply the bound final state explicitly** with its
ANC, and match its energy to the capture pair's `e2`.

EC pathways are enumerated only over Jπ groups present among the supplied levels
(`src/CNuc.cpp:740-800`). See `failure-modes.md` on dummy levels.

## `<segmentsData>`

One line per segment (`include/SegLine.h:18-30`):

```
isActive entranceKey exitKey minE maxE minA maxA isDiff [phaseJ phaseL] dataNorm varyNorm dataNormError dataFile
```

- Keys are **1-based pair keys**; `exitKey = -1` means total capture.
- `minE`/`maxE` in **lab MeV**, `minA`/`maxA` in **lab degrees**.
- `isDiff`: `0` angle-integrated, `1` differential, `2` phase shift (then
  `phaseJ phaseL` follow), `3` total capture.
- **`isDiff = 0` ignores the angle cuts.**
- `dataFile` is the rest of the line, may contain spaces, and is resolved
  **against the process cwd**, not the `.azr` location (the GUI chdirs at
  `gui/src/AZURESetup.cpp:283`; the console does not).
- All three of `dataNorm varyNorm dataNormError` are mandatory for the console
  reader, unlike the GUI's tolerant path.

Data files are four columns: **energy, angle, cross section, error**
(`include/DataLine.h:17-19`), lab MeV, lab degrees, barns.

## `<segmentsTest>`

```
isActive entranceKey exitKey minE maxE eStep minA maxA aStep isDiff [extra]
```

(`include/ExtrapLine.h:18-24`). `eStep = 0.0` or `aStep = 0.0` means exactly one
point. **`isDiff` codes differ from `<segmentsData>`**: `3` is angular
distribution (then `maxAngDistOrder` follows), `4` is total capture.

## Output

`.extrap` files have five columns (`src/EData.cpp:817-821`):

| # | Quantity | Units |
|---|---|---|
| 1 | CM energy | **MeV** |
| 2 | excitation energy | MeV |
| 3 | CM angle | degrees |
| 4 | cross section | **barns** |
| 5 | **S factor** | **MeV b** |

`.out` files (runs with data) append four more: data cross section, its error,
data S factor, its error. Note the input energies are **lab** while column 1 is
**CM**.

`param.par` holds the formal reduced-width amplitudes, one per line as
`j=<j>_la=<la>_ch=<ch>_rwa` (`src/CNuc.cpp:1163-1164`,
`src/AZUREParams.cpp:66-78`). `parameters.out` holds the **physical** parameters
in the observable basis, with `C = ... fm^(-1/2)` for bound channels and
`g_int` / `g_ext` per channel (`src/CNuc.cpp:1407-1473`). For matching a
published table, `parameters.out` is usually what you want.

## Command line

```
AZURE2 --no-gui [options] file.azr
```

Options (`src/AZURE2.cpp:65-140`): `--no-transform`, `--use-brune`,
`--ignore-externals`, `--use-rmc`, `--gsl-coul`, `--no-readline`, `--help`.

**It is interactive.** The menu is `1` calculate with data, `2` fit, `3`
calculate without data, `4` MINOS, `5` reaction rate, `6` exit; then it prompts
for an external parameter file and possibly an external capture amplitude file.
Drive it as `printf '3\n\n\n6\n' | AZURE2 --no-gui file.azr`.
