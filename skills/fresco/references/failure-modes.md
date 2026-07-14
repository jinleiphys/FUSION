# FRESCO failure modes: symptom to cause to fix

Grow this file every time a new failure is diagnosed. The seed entries below come from the manual footnotes, the FRES 2.9-vs-3.4 version gap, and this machine's environment. Add a dated line when you learn a new one.

## Environment / running

| Symptom | Cause | Fix |
|---------|-------|-----|
| `timeout: command not found` (exit 127) | macOS has no `timeout`/`gtimeout` | Do not wrap runs in `timeout`. Background + `kill`, or run on Linux. |
| fort.* files appear in a source tree; git shows junk | FRESCO writes ~20 fort.* into cwd | Always run in a scratch dir (`scripts/run_fresco.sh` does this). |
| Deck uses a variable the manual documents but the run ignores it | Binary is FRES 2.9, manual is FRES 3.4; 3.x-only variables are silently skipped | Check the variable exists in 2.9. If it is essential (some &CDCC reductions, some 3.x couplings), flag that a newer binary is needed. |
| Run stops immediately, tiny output | namelist syntax error (missing `/`, stray token, wrong name) | FRESCO is unforgiving. Diff against the nearest `examples/` deck. Every namelist must end in `/`. |

## Convergence and grid

| Symptom | Cause | Fix |
|---------|-------|-----|
| Cross section changes when `hcm` is halved | integration step too coarse | Reduce `hcm` (0.1→0.05→0.02) until the observable is stable to your quoted precision. Heavy-ion/halo need finer. |
| Reaction σ keeps rising with `jtmax`; fort.56 not decayed | too few partial waves | Raise `jtmax`; for many partial waves use `jump/jbord` blocks. Confirm the per-J σ in fort.56 has died off before jtmax. |
| Coulomb-breakup / Coulex σ wrong or truncated | integrating only to `rmatch`, missing long-range Coulomb couplings | Set `rmatch<0` (integrate nuclear part numerically) and add `rasym` (match to CRCWFN Coulomb functions), tune `accrcy`. |
| Numerical blow-up / NaN at small radius, strong repulsion | short-range repulsion with many partial waves | Add a lower radial cutoff `cutr` (negative puts it inside the Coulomb turning point, e.g. `cutr=-20`), or `cutl` for L-dependent cutoff. |
| Iterations diverge (iter>0) with strong coupling | perturbative iteration cannot handle strong CC | Use exact CC: `iter=0` with `iblock=<#coupled channels>`; or enable `pade`. |
| CDCC run is extremely slow | too many weak channels/couplings kept | Prune with `smallchan` and `smallcoup`; drop high partial waves via `jump/jbord`. |

## Physics / bins / couplings

| Symptom | Cause | Fix |
|---------|-------|-----|
| Breakup / Coulex σ depends oddly on bin phase choice | bins normalised-to-unity (`isc=-1,1,3`) or `isc=-2` no-weighting | Use `isc=2` (default, near-real coupled-channels bins); `isc=4` for resonances. The manual calls unity-normalisation "not recommended for physics reasons". |
| Long-range Coulomb coupling seems to vanish for bins | imaginary parts of bins give imaginary Coulomb couplings that are ignored between `|rmatch|` and `rasym` | Keep bins near-real (`isc=2`); do not rely on imaginary bin couplings at long range. |
| Transfer σ zero or absurd | missing nonlocal-kernel grid or wrong overlap/coupling | Transfer needs `rintp,hnl,rnl,centre` in &FRESCO, bound states in &overlap, `&coupling kind=7` (finite range) or `kind=5` (zero range), and `&cfp` amplitudes. |
| Transfer amplitude off by √N or a sign | spectroscopic amplitude convention | `&cfp A` is the signed amplitude (root of the spectroscopic factor), with the √N antisymmetrisation factor already folded in; sign must match the `(l,s)j,Jcore;Jcom` order. |
| Deformed-coupling calc gives nothing | TYPE 12/13 needs explicit `&step` couplings; TYPE 10/11 needs the deformation on the immediately preceding potential | Order matters: the deformed TYPE must follow the potential it deforms; supply `&step IB,IA,k,STR`. |
| Capture (kind=2) gives only part of the strength | `ip4` selects mechanism | `ip4=0` direct only, `1` semidirect only, `2` direct+semidirect. |

## Verification discipline (not a failure, a rule)

- A FRESCO number is not trustworthy until it is (a) converged in `hcm`, `rmatch`/`rasym`, `jtmax`, bin count, and (b) checked against a reference or analytic limit. Report the agreement to N digits. See `verification.md`.
- If you cannot reproduce a published number, suspect the deck (masses, Q-value, potential convention, energy frame `lin`) before suspecting FRESCO.

## Personal gotchas (user to fill / AI to append with dates)

<!-- Append real diagnosed failures here as: [YYYY-MM] symptom -> cause -> fix (system, deck). -->
- (none yet)
