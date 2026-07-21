# pikoe failure modes

Each entry is a way to get a wrong or missing result that looks like a normal
one. All of these were hit or verified while building this skill on 2026-07-21,
except where marked as an upstream statement.

## 1. The exit status is not a verdict

pikoe's physics record goes to the outlist file named by the `kibout` field of
L16 (unit 6 in every shipped deck), not to stdout. A harness keying on `$?` can
call a run successful when nothing physical was produced. **Positive assertions
only**: the `>>> calculation completed` banner is present, at least one
**non-empty** table was written, and stderr holds nothing beyond the `STOP 0`
that pikoe prints on every normal exit. `run_pikoe.sh` checks all three.

This is the third distinct shape of this trap in the FUSION per-code skills
(CCFULL leaves a stale reference file behind, TALYS exits 0 on fatal error,
pikoe hides the verdict in a redirected unit). Assume it is present in the next
code too.

## 2. The decks reference their data tables by relative path

Every shipped deck opens a table under `../elem/` (`nnampFL.dat` for the TDX and
QDX decks, `FLtbl_rede.dat` for the momentum-distribution decks) and one under
`../pot/`, because upstream expects the binary and the deck to sit in a `sampleN/`
subdirectory of the unpacked tree. Copy a deck into a flat scratch directory and
the open fails. `run_pikoe.sh` reproduces the layout with symlinks rather than
rewriting the deck or copying 50 MB of tables.

## 3. The input is fixed-format

Formats such as `[i5,f10.0,i5]` are declared per line in `input_man.txt`. A
value shifted by one column is read as a different quantity, and the run
completes. Start from a shipped deck in `examples/` and edit values in place.

## 4. `ielm` must match the observable you want

The momentum-distribution decks use `ielm=3` (free NN differential cross
section, `FLtbl_rede.dat`) while the TDX and QDX decks use `ielm=4` (on-shell NN
t-matrix, `nnampFL.dat`). This is not interchangeable bookkeeping. The paper
(Sec. 2.4, after Eq. 30) states that the approximation made to the azimuthal
integration in the t-matrix route deviates from the exact Eq. (25) result by
**typically 10 to 20 percent**, and that the approximation is not needed when
the NN cross section rather than the transition amplitude is factorized, which
is the Sec. 2.5 formalism selected by `ielm=3`. So for momentum distributions,
`ielm=3` is the accurate route and `ielm=4` carries a 10 to 20 percent penalty.
`ielm=4` is also restricted to coplanar kinematics.

## 5. TDX genuinely diverges in inverse kinematics

Not a numerical bug. For given `(T1, Omega1, Omega2)` there can be two solutions
for `T2`, and where they merge into a double root the TDX diverges (paper
Sec. 2.4; visible in sample 4 as a steep rise near `th2l = 32.3` degrees). The
integrated TDX stays finite, so an experiment sees an enhancement rather than a
divergence, but the correspondence between TDX and the residue momentum
distribution is lost there. The QDX (`ivar=3`) is the observable to use in
inverse kinematics, and is what sample 5 computes. The mirror statement also
holds: **QDX is ill-behaved in normal kinematics**, where `E1` and `E2` are
strongly correlated.

## 6. Momentum-distribution runs are an hour, not seconds

The `ivar=9` decks add Gauss-Legendre quadratures over `K1` and `phi_1Q`
(`ngk1`, `ngph1q` on L18) on top of a two-dimensional output grid. On one core
of an M-series laptop, samples 1, 4 and 5 (TDX and QDX) each finish in 5 to 8
seconds, while samples 2 and 3 (momentum distributions, 81 by 41 grid with 15
nodes in each of the two extra quadratures) take roughly 40 and 75 minutes.

The `tbl_` file is written row by row, so progress is visible there. The `LG_`,
`PX_`, `TR_` and `TL_` files are **created empty at startup** and filled only at
the end, because pikoe opens every output unit named in the header before it
computes anything. Their existence therefore proves nothing about progress or
success; only their size does. This is a live false-positive vector for any
harness that checks for output by presence, and it is why `run_pikoe.sh` counts
non-empty tables. `verify_pikoe.sh` runs the three fast cases by default and
takes the momentum-distribution cases only on request.

## 7. Upstream ships no reference output

`readme.txt` documents a `tbl_*.dat` and a `*.outlist` inside every `sampleN/`
directory. **Neither is in the archive.** Verified for both releases: v1.1 has
22 entries, v1.0 has 13, and in both the sample directories contain only the
`.cnt` control file. This is a packaging defect, not a misunderstanding of the
layout, and it is why this skill's benchmark is anchored on the CPC paper's
published figures instead of on distributed reference numbers. See
`verification.md`.

**This is less of a loss than it first appears, and asking the authors for the
files was considered and dropped.** A reference output is produced by the same
source as your own run, so it can certify only that your *build* is sound; a
genuine physics error sits in their reference too, and matching it proves
nothing. Build soundness is better established by reproducing across compilers
and architectures, which covers more configurations than a single reference
file. Measured here: macOS ARM64 gfortran 15.2.0 against Linux x86_64 gfortran
13.3.0, at `-O2`, `-O0`, and `-finit-real=snan -finit-integer=-99999`, gives
**bit-identical output across all six builds** (5642 numbers, TDXnorm + TDXinv +
QDXinv). Physics correctness is carried separately by the figure anchoring.

## 8. `.mod` files break the next rebuild after a compiler upgrade

gfortran module files are version-specific, and the installer writes them into
the source directory (`-J "$SRCDIR"`, so that they land somewhere deliberate
rather than in whatever directory the caller happens to stand in). After
upgrading gfortran, or after copying an already built tree to a machine with a
different gfortran, the build dies with:

```
Fatal Error: Cannot read module file '.../dims.mod' opened at (1),
because it was created by a different version of GNU Fortran
```

which names neither the cause nor the fix. `install_pikoe.sh` now clears
`$SRCDIR/*.mod` before every build. If you build by hand, do the same. Found by
building the same source under gfortran 15.2 and 13.3 for the cross-platform
check above.

## 9. Only the attach-plugin URL serves the archive

The plain URLs on the RCNP page (`.../pikoe1.1.zip`, `.../pikoe1.1.f90`) return
403 or 404. The PukiWiki attach-plugin URL works:
`index.php?plugin=attach&refer=files&openfile=pikoe1.1.zip`. `install_pikoe.sh`
uses it and rejects a downloaded file that is not a zip archive, because an
error page also arrives with HTTP 200.

## 10. The readme names a source file that is not in the archive

`readme.txt` says the source is `pikoe1.f90`; the v1.1 archive ships
`pikoe1.1.f90`. `install_pikoe.sh` globs `pikoe*.f90` rather than trusting
either name.

## 11. gfortran warnings at build are expected

The source uses features deleted in Fortran 2018 (arithmetic `IF`, `DO`
termination on a non-`CONTINUE` labelled statement). gfortran 15 warns and
compiles. Treat warnings as normal; treat a link failure as real.

## 12. `ulimit -s unlimited` fails on macOS

`readme.txt` recommends an unlimited stack. macOS caps the hard limit well below
unlimited, so the request is refused. The distributed sample cases run inside
the default stack; `run_pikoe.sh` asks for the hard limit and continues if
refused. If a much larger case segfaults with no diagnostic, raise the stack
first before suspecting the deck.

## 13. `ielm=6` is referenced but undocumented

`input_man.txt` documents `ielm` values 0, 3 and 4, yet lists `ielm=6` as an
exclusion in the L10 (`iex`) and L16 (`kibtmd`) entries. The code settles it:
anything other than 0, 3 or 4 is rejected outright with
`ERROR: ielm must be 0, 3, or 4`. So `ielm=6` cannot run at all, and the
exclusion notes are vestigial.

## 14. The phase volume convention differs from the review article

pikoe evaluates the phase volume in the output frame, not in the G-frame as in
Eq. (3.30) of the Wakasa-Ogata-Noro review (Prog. Part. Nucl. Phys. 96, 32
(2017)), whose Jacobian is an approximation accurate to better than 99 percent
for normal kinematics but not guaranteed in inverse kinematics. The paper also
notes that its Eq. (2) for the initial NN relative momentum differs slightly
from the review's definition, with negligible effect except for very light
nuclei, and that the factor `1/(2j+1)` in the review's Eq. (3.33) should sit
after the sum over `j`. When comparing pikoe against numbers computed from the
review's formulae, these three differences are the places to look first.
