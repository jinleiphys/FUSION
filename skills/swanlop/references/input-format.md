# SWANLOP input format

SWANLOP is run from the `runs/` directory. The main input is a file named
`fort.1` (positional, one labeled value per line); a nonlocal potential read from
file goes in `fort.2` and a local one in `fort.22`. Documented from the shipped
`fort.quick-start` and `README_runs`, not from memory.

## Main input `fort.1` (from `fort.quick-start`)

```
SAMPLE:TPM:pPb208@ELab=30.3MeV...   : TITLE  single unbroken CHARACTER*70, no , ; /
p                 : PROJ        (p) proton  (n) neutron
Pb208             : TARGET      e.g. Be8 Ca40 Zr94 Pb208 ...
30.30d0           : ELAB        lab energy (MeV, real)
16.00             : RMAX        max radius (fm, real)
160               : NRP         number of radial points (integer)
-1                : LMAX        max partial wave; < 0 = automatic (under KPOT=0,1,2)
180d0 1.0d0       : ANGMAX DANG max scattering angle and step (deg); ANGMAX < 0 = automatic
0                 : KIN         0 non-relativistic, 1 relativistic
2                 : KPOT        0 local, 1 Perey-Buck, 2 Tian-Pang-Ma, 3 read VRR (r-space), 4 read VKK (q-space)
0                 : KADD        0 none, 1 read (fort.22), 2 user_vloc
0                 : KPRwave     print wave functions: 0 no, 1 yes
0                 : KPRpot      print potential: 0 no, 1 yes
dsdw.pPb208-30.3  : DATdsdw     CHARACTER*18 experimental dsigma/dOmega datafile (or none)
none              : DATay       CHARACTER*18 experimental Ay datafile (or none)
none              : DATqrot     CHARACTER*18 experimental Q datafile (or none)
```

The TITLE line is a single unbroken word of up to 70 characters using any US
keyboard character except `,` `;` `/`.

## Potential choice (KPOT) and the extra files

`README_runs` ships five templates `temp00`..`temp04` as starting points (it says
one per KPOT, but the shipped `temp00` actually sets KPOT=2 despite its title, so
check the KPOT line before use). The implemented KPOT values are 0..4 (the code
stops with "UNDEFINED KPOT OPTION" otherwise; note the inline comment in
`fort.quick-start` lists a KPOT=5 that the source does not implement):

| KPOT | meaning | fort.2 | fort.22 |
|---|---|---|---|
| 0 | local potential | not used | NEEDED |
| 1 | Perey-Buck built-in | not used | needed if KADD=1 |
| 2 | Tian-Pang-Ma built-in (quick-start) | not used | needed if KADD=1 |
| 3 | read VRR coordinate-space (r,r') nonlocal from file | NEEDED (fort.2) | needed if KADD=1 |
| 4 | read VKK momentum-space (k,k') nonlocal from file | NEEDED (fort.2) | needed if KADD=1 |

To feed an external nonlocal potential (KPOT=3 or 4), copy the chosen potential
table to `fort.2`:

```
cp ../udata/<potential-file> fort.2
```

Sample potentials ship in `../udata/` (about 21 MB), and larger tables
(80/200/700 MeV, 1 GeV for 12C/40Ca/90Zr/208Pb) are in the 530 MB
`SupplementaryMaterial.tar.xz` of the Mendeley dataset. Those are only needed for
KPOT=3 or 4 runs; the built-in TPM/PB potentials (KPOT=1,2) and therefore the
quick-start benchmark need none.

## Files present at run time

- `NucChart` (mass-excess table, Ame2003) must be in the run directory; it is
  always read.
- The experimental data files named in `DATdsdw`/`DATay`/`DATqrot` must exist if
  chi-square evaluation is requested (the quick-start reads `dsdw.pPb208-30.3`,
  which ships in `runs/`).
