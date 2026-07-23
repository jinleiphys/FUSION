# EXFOR format reference

Consult this when a reaction code, column name, or unit in a retrieved entry is unfamiliar.

## Contents

- [The REACTION string](#the-reaction-string)
- [Process codes (SF3)](#process-codes-sf3)
- [Quantity codes (SF6)](#quantity-codes-sf6)
- [Modifiers (SF5, SF8)](#modifiers-sf5-sf8)
- [Column names](#column-names)
- [Units](#units)
- [Physical record layout](#physical-record-layout)
- [Entry numbering](#entry-numbering)
- [Verified example entries](#verified-example-entries)

## The REACTION string

```
(SF1(SF2,SF3)SF4,SF5,SF6,SF7,SF8,SF9)
```

| Field | Meaning | Example |
|-------|---------|---------|
| SF1 | target | `40-ZR-90` (Z-symbol-A; `A=0` means natural) |
| SF2 | projectile | `N`, `P`, `D`, `A`, `HE3`, `G` |
| SF3 | process | `EL`, `INL`, `F`, `G`, `TOT` |
| SF4 | product | `40-ZR-90`, or a residual nuclide |
| SF5 | branch/modifier | `PAR` (partial), `SEQ`, `CUM` |
| SF6 | quantity | `SIG`, `DA`, `DA/DE` |
| SF7 | particle considered | `N`, `G` |
| SF8 | modifier | `RAT`, `MSC`, `REL` |
| SF9 | data type | `EXP`, `DERIV` |

Read `(40-ZR-90(N,EL)40-ZR-90,,DA)` as: elastic neutron scattering on ⁹⁰Zr, differential cross section in angle, SF5 empty.

## Process codes (SF3)

| Code | Meaning |
|------|---------|
| `EL` | elastic scattering |
| `INL` | inelastic scattering |
| `TOT` | total cross section |
| `NON` | nonelastic |
| `ABS` | absorption |
| `F` | fission |
| `G` | radiative capture, as in `(N,G)` |
| `N`, `2N`, `3N` | neutron emission channels |
| `P`, `D`, `T`, `A` | charged-particle emission |
| `X` | inclusive production, as in `(N,X)` |

## Quantity codes (SF6)

| Code | Meaning | Typical units |
|------|---------|---------------|
| `SIG` | integrated cross section | `B`, `MB` |
| `DA` | differential in angle | `MB/SR` |
| `DE` | differential in energy | `MB/MEV` |
| `DA/DE` | double differential | `MB/SR/MEV` |
| `POL/DA` | analysing power or polarization | `NO-DIM` |
| `RI` | resonance integral | `B` |
| `WID`, `EN` | resonance width, energy | `EV` |
| `ARE` | resonance area | `B*EV` |

## Modifiers (SF5, SF8)

`PAR` means partial, so a discrete level is involved and an `E-LVL` column will normally be present. `RAT` means the data are a ratio. `REL` means relative data, not absolute, which makes them unusable for a direct comparison without renormalization. `MSC` flags miscellaneous or unusual definitions, so read the BIB text before trusting the numbers.

## Column names

| Name | Meaning |
|------|---------|
| `EN` | incident energy |
| `EN-RSL` | energy resolution |
| `EN-ERR` | uncertainty on the energy |
| `ANG` | scattering angle, **laboratory frame** |
| `ANG-CM` | scattering angle, **centre-of-mass frame** |
| `ANG-ERR` | angular uncertainty or acceptance |
| `DATA` | the measured value, **laboratory frame** if a frame applies |
| `DATA-CM` | the measured value, **centre-of-mass frame** |
| `DATA-ERR` | uncertainty; check the unit, it is often a percentage |
| `+DATA-ERR`, `-DATA-ERR` | asymmetric uncertainties |
| `ERR-S`, `ERR-T` | statistical and total uncertainty |
| `E-LVL` | excitation energy of the populated level |
| `E-EXC` | excitation energy |
| `MONIT` | monitor reaction value used for normalization |

A `-CM` suffix appears on both the angle and the value independently. It is legal, and it happens, for an entry to give `ANG-CM` with a laboratory `DATA`, so check both names rather than assuming they match.

## Units

| Unit string | Meaning |
|-------------|---------|
| `MB/SR` | millibarn per steradian |
| `B`, `MB`, `MICRO-B` | barn, millibarn, microbarn |
| `ADEG` | angle in degrees |
| `MEV`, `KEV`, `EV` | energy |
| `PER-CENT` | percent, used mainly for uncertainties |
| `NO-DIM` | dimensionless |
| `B*EV` | barn electronvolt |

Uncertainty columns switch between absolute units and `PER-CENT` from entry to entry, and occasionally between subentries of one entry. This is the single most common way to corrupt a comparison, so read the units line every time.

## Physical record layout

Data and COMMON blocks are fixed width: **6 fields of 11 characters** per physical line, wrapping onto continuation lines when a table has more than 6 columns.

```
DATA                 3         39
ANG-CM     DATA-CM    DATA-ERR
ADEG       MB/SR      MB/SR
 15.3      1453.27      43.60
```

The header line gives the number of columns and a line count, which is a free consistency check that `scripts/exfor.py` performs and warns about on stderr. Be aware that **EXFOR does not use that second number consistently**: in `COMMON` it counts the heading and units records as well, so `COMMON 2 3` carries a single line of values, while in `DATA` it counts only the data lines, so `DATA 3 37` is 37 points and the closing `ENDDATA` reports 39. The script checks each block against its own convention rather than accepting either one. Accepting both looks tolerant but is unsound: on a table with two lines per record, losing one entire wrapped record moves the count to exactly `declared - 2`, which a permissive test reads as the COMMON convention and waves through. It also flags a partial wrapped record via the record-alignment test.

A field of all spaces means "no value" and must be preserved as blank, since collapsing it shifts every subsequent column. `scripts/exfor.py` handles this; hand-rolled whitespace splitting does not.

`COMMON` blocks have the same layout and hold quantities constant over the subentry, most often `EN` for a single-energy measurement.

## Entry numbering

| Range | Compilation centre |
|-------|--------------------|
| `1xxxx` | NNDC, United States |
| `2xxxx` | NEA Data Bank, Europe and Japan |
| `3xxxx` | IAEA NDS, other countries |
| `4xxxx` | CJD, Russia and former Soviet Union |
| `Oxxxx`, `Cxxxx`, `Dxxxx` | other compilations, including charged-particle sets |

Measurements from one group tend to cluster, so nearby numbers are a reasonable place to look for related data.

## Verified example entries

These were retrieved and parsed successfully and are useful for testing the tooling.

| Entry | Content |
|-------|---------|
| `13160` | Wang and Rapaport, neutron scattering on ⁹⁰⁻⁹⁴Zr; elastic and inelastic at 8.0, 10.0, 24.0 MeV; enriched samples; `ANG-CM` / `DATA-CM` in `MB/SR` |
| `13160004` | ⁹⁰Zr elastic at 24.0 MeV, 39 points, full angular range from 15° to 159° |
| `22480` | Ibaraki et al., TIARA; neutron elastic on natural C, Si, Fe, Zr, Pb at 55, 65, 75 MeV; `EN` is a data column |
| `22480005` | natural Zr, 75 points across three energies, forward angles 2.6° to 53.5° |
| `22480007` | ¹²C elastic at 75 MeV; note `DATA-ERR` here is in `PER-CENT`, unlike the rest of the entry |
