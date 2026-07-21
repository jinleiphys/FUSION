# FRIB/TALENT Course 6 material for the AZURE2 exercise

**Source:** FRIB-TA TALENT Course 6, *Theory for exploring nuclear structure
experiments*, June 2019, Problem 7 (AZURE2), exercises page:
<https://indico.frib.msu.edu/event/15/page/98-exercises>

Lecture (R.J. deBoer), not vendored here, fetch from:
<https://indico.frib.msu.edu/event/15/attachments/41/208/TALENT6-JD-Lecture2.pdf>

## What is here, and what is deliberately not

Only the **data tables** are committed. They are measured cross sections, i.e.
experimental facts, and they are what the benchmark actually consumes.

The journal-article PDFs linked from the same page (Rolfs 1973, Auchampaugh
1979, Meyer 1976, Chow 1975, Vogl 1963, Burtebaev 2008, Amirikas 1993, Harris
1962, Dangle 1964) are **not** committed and should not be: an indico page being
publicly readable does not make a publisher's PDF redistributable, and FUSION is
publicly distributed. The lecture slides are the author's own teaching material
and are closer to shareable, but they are cited by URL rather than vendored, on
the same principle and because nothing here depends on having the file locally.

| file | content | used by |
|---|---|---|
| `Rolfs_GS.dat` | 16O(p,gamma0)17F, Rolfs (1973) | `../16O_pg_17F` data benchmark |
| `Rolfs_FES.dat` | 16O(p,gamma1)17F, first excited state, Rolfs (1973) | same |
| `vogl.dat` | Vogl (1963) | not yet used |
| `Chow_pp.dat` | elastic p+12C, Chow (1975) | not yet used |
| `Auchampaugh_12C_ntotal.dat` | 12C(n,total), Auchampaugh (1979) | the 12C(n,n0) case, not yet built |

## Format

AZURE2 data files are four whitespace-separated columns, **energy, angle, cross
section, error** (`include/DataLine.h:17-19`), with energy in **lab MeV**, angle
in **lab degrees** and cross section in **barns**.

Both Rolfs files contain two blocks: 38 points at angle 0.1 and ~38 at 90
degrees. **Both blocks are differential cross sections.** The 0.1-degree block
is not angle-integrated, despite what the near-zero angle suggests: treating it
as angle-integrated (`isDiff = 0`) makes the calculation overshoot the data by a
factor of 12.6, which is 4*pi. Select the blocks with the segment angle cuts and
set `isDiff = 1` for both.

## Reference result

With no fitting at all, using only the Table V parameters of Azuma et al.,
Phys. Rev. C 81, 045805 (2010), the `../16O_pg_17F` deck gives chi^2/N = 1.53
against `Rolfs_GS.dat` at 90 degrees. See `../16O_pg_17F/verification.md`.
