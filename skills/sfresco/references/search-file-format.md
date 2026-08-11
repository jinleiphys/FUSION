# The SFRESCO search file, field by field

Ground truth is `source/sfresco.f` of the FRESCO distribution (the namelist declarations at lines 54 to 61, the variable reader around line 130, the data reader around line 205). Where the printed manual and the code disagree, the code is what runs; those cases are flagged below.

## Header

```
'input_file' 'output_file'
nvariables ndatasets
```

Free format, so the two strings and the two integers may be on one line or two. `input_file` is the FRESCO deck. `output_file` is written fresh; SFRESCO also writes `output_file-init` (the first, unfitted run), `output_file-trace` and `output_file-snap` (fort.105 and fort.106, one line per FCN call).

Comment lines starting with `!` are tolerated **between** namelists. They are not tolerated inside a data block: the numeric read hits the comment, backspaces, and ends the dataset there, silently. A stray comment in the middle of 29 points leaves you fitting 6.

## `&variable` (repeated `nvariables` times)

Common fields:

| field | default | meaning |
|-------|---------|---------|
| `name` | `VarNN` | up to 10 characters, appears in every report and in MINUIT |
| `kind` | 0 | 0 ignore, 1 potential, 2 spectroscopic amplitude, 3 R-matrix energy, 4 R-matrix width, 5 dataset normalisation |
| `step` | 0.01 | initial trial step. **`step=0` fixes the variable.** For widths, a step smaller than `|width|` is scaled automatically |
| `valmin`, `valmax` | 0, 0 | hard bounds. Both or neither. Bounds distort MINUIT's error estimate near the edge |

Bounds are worth using on radii and diffusenesses (a fit that walks a to 0.05 fm is not a fit) and worth avoiding on strengths, where hitting a bound is the information you wanted.

### kind=1, potential parameter

| field | meaning |
|-------|---------|
| `kp` | potential index, as in `&pot kp=` |
| `pline` | which record of that `kp`, counting **expanded** `&potl` records from 1 |
| `col` | index into `p(1:7)` of that record |
| `potential` | starting value; omit to inherit the deck's value (SFRESCO then prints "value from Fresco input") |

`col` by record TYPE:

| TYPE | col 1 | 2 | 3 | 4 | 5 | 6 |
|------|-------|---|---|---|---|---|
| 0 Coulomb | `at` | `ap` | `rc` | `ac` | | |
| 1 volume | V | r_V | a_V | W | r_W | a_W |
| 2 surface | V_d | r_Vd | a_Vd | W_d | r_Wd | a_Wd |
| 3 spin-orbit (projectile) | V_so | r_so | a_so | W_so | r_soi | a_soi |
| 4 spin-orbit (target) | same layout, target | | | | | |
| 10-17 deformations | def(1) | def(2) | def(3) | ... | | |

Note the TYPE=0 order: `p1` is the **target** mass number and `p2` the projectile one (frxx0.f, `p1=at; p2=ap; p3=rc; p4=ac`, and the manual says "AT = p1 and AP = p2"). Do not trust a memory that says otherwise.

**How `pline` is really counted.** SFRESCO expands the deck into standard `&potl` records first (they end up in `fort.3`), and the counter in `frxx2.f:237` increments once per record with a matching `kp`. **It also increments once per `&step` namelist** that follows a TYPE 12 to 17 record of that `kp` (`frxx2.f:331`), because those coupling strengths are searchable too. A variable whose `pline` lands on a `&step` varies that step's `str` and ignores `col`; a variable whose `pline` lands on a `&potl` varies `p(col)`. So in a deck with matrix-element couplings, count potential records and their steps together. A `&pot` namelist that carries any explicit `p(k)` or `def(k)` is passed through as one record. A namelist written only with alias keywords expands, in this fixed order:

1. TYPE 0, from `at, ap, rc, ac`, if `rc` is nonzero
2. TYPE 10 from `mnep`, TYPE 11 from `mnet`, if nonzero
3. TYPE 1, from `v, rv, av, w, rw, aw`, if `v` or `w` is nonzero
4. TYPE 2, from `vd, vdr, vda, wd, wdr, wda`, if `vd` or `wd` is nonzero
5. TYPE 10 from `defp`, TYPE 11 from `deft`, if nonzero
6. TYPE 3, from `vso, rso, aso, vsoi, rsoi, asoi`, if `vso` or `vsoi` is nonzero

Alias spellings equivalenced in the code: `r0` = `vr0` = `rv`; `a` = `av`; `wr0` = `r0w` = `rw`; `aw` = `wa`; `rso` = `rso0`; `awd` = `wda`; `wdr` = `wdr0`.

**The `p(0)` trap.** `p` is declared `p(0:8)`, so a bare `p= 52.5 1.17 0.75` in a namelist fills from `p(0)` and every value lands one column too low. Always write `p(1:3)=` or `p1= p2= p3=`. `scripts/potmap.py` reproduces this behaviour rather than correcting it, so if the map looks shifted, the deck is shifted.

### kind=2, spectroscopic amplitude

`nafrac` = which `&cfp` namelist in the deck, counting from 1. `afrac` = starting amplitude (omit to inherit). SFRESCO prints which overlap it resolved to; check that line, it is the only confirmation you get.

### kind=3 and 4, R-matrix terms

`term` (default 1) selects the pole. kind=3 varies `energy` (cm MeV in the entrance channel) at the given `jtot`, `par`; `nopot=T` disables the potential and Buttle correction for that J/pi set. kind=4 varies `width` in channel `channel`, numbered in the order FRESCO generates them, in MeV^(1/2) if reduced widths are in use, else MeV.

### kind=5, dataset normalisation

`dataset` selects which dataset (1 to ndatasets), `datanorm` is the starting factor (default 1.0). The theory is compared to `datanorm * data`, so a fitted `datanorm` of 1.08 means the data as given sit 8% below the model, not above. The manual mentions a `reffile` field for matching several datasets by name; **it is not in this version's namelist** and will be rejected.

## `&data` (repeated `ndatasets` times, each followed by its data)

| field | default | meaning |
|-------|---------|---------|
| `type` | 0 | see the table below |
| `data_file` | `'='` | `'='` reads inline from the search file, `'<'` from stdin, otherwise a file name |
| `points` | all | stop after this many points |
| `delta`, `xmin` | -1, 0 | if `delta > 0`, build the x axis as `xmin + (i-1)*delta` and read only value and error; the default reads x from the file |
| `energy` | `elab(1)` | lab energy for a type=0 set. New energies are added to the run automatically |
| `lab` | F | T for lab angles and lab cross sections |
| `idir` | 0 | 0 absolute, 1 ratio to Rutherford, 2 absolute converted to ratio, -1 S-factor converted to absolute |
| `iscale` | 2 in the manual, **-1 in the code** | -1 dimensionless, 0 fm^2/sr, 1 b/sr, 2 mb/sr, 3 microbarn/sr. Set it explicitly and the disagreement never bites you |
| `abserr` | F | T = column 3 is an absolute error, F = it is a fraction of the datum |
| `ic`, `ia` | 1, 1 | partition and excitation-pair index of the cross section |
| `k`, `q` | 0, 0 | tensor rank and component; `k=0` is the cross section, `k>0` are analysing powers |
| `jtot`, `par`, `channel` | -1, 0, 1 | which partial wave, for type=4 phase shifts |
| `value`, `error` | | the constraint itself, for type=6 |
| `pel, exl, labe, lin, lex` | from the deck | incoming channel specification, as in the FRESCO `&fresco` namelist |
| `ib` | 0 | gamma decay to state `ib`, for types 0 to 3 |

Data types, and what the columns mean:

| type | rows are | comment |
|------|----------|---------|
| 0 | angle, value, error | angular distribution at `energy` |
| 1 | energy, angle, value, error | double distribution |
| 2 | energy, value, error | fixed `angle=` |
| 3 | energy, value, error | integrated cross section. With `ic=0`: `ia=0` fusion, `ia=1` reaction, `ia=-1` angle-integrated elastic, `ia=-2` total. (The printed manual lists a different `ia` convention here; the code comment above is what runs.) |
| 4 | energy, value, error | phase shift in degrees for the wave selected by `jtot`, `par`, `channel` |
| 5 | state index, value, error | bound-state search factor |
| 6 | (none) | constraint: `par=` variable number, `value=`, `error=`, `abserr=` |
| 7, 8 | | Brune-basis pole energy and formal width, marked "not yet implemented" in the source |
| 9 | state index, value, error | ANC. Rejected by the 2023 binary with `Unrecognised data type 9`; works in a build from current source |

Terminate each data block with a line containing `&`.

`ndof` is accumulated as the plain sum of the dataset lengths (`sfresco.f`: `ndof = ndof + datalen(id)`), so every `ChiSq/N` in every output file is chi-squared per point. MINUIT is then given `ERRORDEF = 1/ndof`, which is exactly what makes its parameter errors correspond to delta-chi-squared = 1 on the unnormalized chi-squared. That is why the printed `ERR DEF` is a small number like 0.0357 and not 1.

## Data in a separate file

```
 &data type=0 data_file='pcd_27.9.dat' idir=1 iscale=-1 abserr=T energy=27.9 /
```

with `pcd_27.9.dat` holding the three columns and nothing else. `scripts/run_sfresco.sh` copies any such file into the scratch dir automatically. Prefer this over inline data when the same measurement feeds several fits, so there is one copy to correct.
