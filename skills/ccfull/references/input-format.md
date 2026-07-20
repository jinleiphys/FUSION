# CCFULL input format (ccfull.inp)

Free-format, one record per line, read from a file literally named `ccfull.inp` in the working directory. Nine data lines (comments after a blank line are ignored by the reader; keep them for humans).

| line | variables | meaning |
|---|---|---|
| 1 | `AP, ZP, AT, ZT` | projectile and target mass and charge (e.g. `16.,8.,144.,62.` for 16O + 144Sm) |
| 2 | `RP, IVIBROTP, RT, IVIBROTT` | coupling-Hamiltonian radius parameters and intrinsic-excitation option for projectile / target. IVIBROT = -1 inert, 0 vibrational, 1 rotational |
| 3 | target excitation: `OMEGAT, BETAT, LAMBDAT, NPHONONT` (vib) or `E2T, BETA2T, BETA4T, NROTT` (rot) | first target mode; irrelevant if IVIBROTT = -1 |
| 4 | `OMEGAT2, BETAT2, LAMBDAT2, NPHONONT2` | optional second target phonon mode; set NPHONONT2 = 0 to disable |
| 5 | projectile excitation, same shape as line 3 | irrelevant if IVIBROTP = -1 |
| 6 | `NTRANS, QTRANS, FTR` | pair-transfer channel: NTRANS 0 or 1; form factor FTRANS(R) = FTR * dVN/dR |
| 7 | `V0, R0, A0` | nuclear potential depth (MeV), reduced radius (fm), diffuseness (fm), Woods-Saxon |
| 8 | `EMIN, EMAX, DE` | center-of-mass energy grid for the fusion excitation function (MeV) |
| 9 | `RMAX, DR` | radial integration limit and step (fm) |

Notes:
- Numbers are comma or space separated; the trailing decimal point style (`16.`) is the code's convention, keep it.
- The nuclear potential uses R = R0 * (AP^(1/3) + AT^(1/3)) (the standard sum convention for heavy-ion fusion; different from COLOSS's target-only rule).
- Vibrational coupling (IVIBROT = 0) needs omega (phonon energy), beta (deformation), lambda (multipolarity), Nph (number of phonons). Rotational coupling (IVIBROT = 1) needs the 2+ energy, beta2, beta4, and the number of rotational levels.
- Outputs: `OUTPUT` (barrier + fusion excitation function), `cross.dat` (Ecm vs sigma), `spin.dat` (spin distribution), `s-wave.dat`.
