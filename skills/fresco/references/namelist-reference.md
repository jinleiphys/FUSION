# FRESCO namelist reference (by task)

Distilled from the FRES 3.4 namelist manual. Variable names are case-insensitive. Every namelist is terminated by `/`. Trailing `!` comments are allowed. Real/imaginary parts of potentials use `p1,p2,p3` and `p4,p5,p6` respectively.

Standard input structure, in order:

```
<heading line, <=120 chars, identifies the run>
NAMELIST
 &FRESCO ... /              ! numerical + physical control (one block)
 &PARTITION ... /   &STATES ... /   [more &STATES]   ! repeat per mass partition
 &partition /               ! empty: ends the partition list
 &POT ... /                 ! repeat per potential component; empty &pot / ends it
 &pot /
 &OVERLAP ... /             ! bound/scattering form factors; empty ends it
 &overlap /
 &COUPLING ... /            ! transfer/excitation couplings; empty ends it
 &coupling /
```

Minimal elastic deck needs only `&FRESCO`, one `&PARTITION`+`&STATES`, the `&POT` block, and empty `&overlap` / `&coupling`. See `examples/B1-elastic.in`.

---

## &FRESCO: numerical and physical control

**Radial grid.** `hcm` = integration step (fm). `rmatch` = matching radius (fm); the CC equations are integrated to here. Set `rmatch<0` (e.g. `-60`) to integrate the nuclear part to `|rmatch|` numerically and then match to CRCWFN Coulomb functions out to `rasym` (needed for long-range Coulomb, i.e. Coulomb breakup/Coulex). `rintp` = interpolation step for nonlocal kernels. `hnl, rnl, centre` = nonlocal step / range / centre for transfer kernels. `accrcy` = accuracy target for the CRCWFN matching. `cutl, cutr, cutc` = lower radial cutoffs: `cutr` (fm) is a flat lower cutoff (negative puts it inside the Coulomb turning point, e.g. `cutr=-20`); `cutl` gives an L-dependent cutoff `max(cutl*L*hcm, cutr)`; `cutc` removes off-diagonal couplings inside that radius.

Typical: light-ion `hcm≈0.1`, heavy-ion / halo `hcm≈0.05`; `rmatch≈60` for short-range, `rmatch=-50` with `rasym≈100-340` for Coulomb-dominated breakup.

**Partial waves.** `jtmin, jtmax` = min/max total angular momentum J. `absend` = convergence-on-absorption threshold (mb): stop when the elastic absorption is below `absend` for three consecutive Jπ sets; `absend<0` forces the full J range. `jump(i), jbord(i)` (i=1..5) = J-step blocks: use step `jump(i)` between `jbord(i)` and `jbord(i+1)`, interpolating scattering amplitudes across the skipped J. Essential for the thousands of partial waves in intermediate-energy Coulomb breakup (e.g. `jbord=0 200 300 1000 9000`, `jump=1 10 50 200`). `jtmin<0` restricts J<|jtmin| to elastic only (fast, for accurate elastic when transfers/excitations do not matter there).

**Angular distributions.** `thmin, thmax, thinc` = angle range/step (deg) for cross sections. `pp`, `koords`, `nearfa` = frame/near-far options.

**Coupled equations / solving.** `iter` = number of iterations (`iter=0` with `iblock=N` blocks the first N channels for exact CC; `iter>0` gives multistep DWBA). `iblock` = number of channels solved exactly (coupled) rather than iteratively. `pade` = Padé acceleration for divergent iterations. `smallchan, smallcoup` = thresholds to drop weak channels/couplings (speeds large CDCC). `nnu` = Gaussian points for transfer angular integrals. `inh` = nonlocality handling for transfers.

**R-matrix.** `nrbases, nrbmin, pralpha, pcon, rmatr, btype, ...` = internal R-matrix (Lagrange-mesh) option.

**Trace / output.** `chans` (print coupled partial waves per Jπ), `listcc` (coupling coefficients), `smats` (S-matrix: `>=1` reaction/absorption per partition, `>=2` elastic S-matrix elements), `xstabl` (`>0` prints cross sections + tensor analysing powers up to rank `xstabl` to fort.16), `cdetr`, `treneg`.

**Incident channel / energy.** `elab(i)` = lab energy of the projectile (MeV); array `elab(1:n)` with `nlab(1:n-1)` gives several energies (intermediate points interpolated). `pel, exl, lab, lin, lex` = which partition/excitation is the incident channel; `lin=2` switches to inverse kinematics.

---

## &PARTITION and &STATES

`&PARTITION namep= massp= zp= namet= masst= zt= qval= nex= /`
- `namep/massp/zp` = projectile name/mass/charge; `namet/masst/zt` = target; `qval` = reaction Q-value (MeV) for this partition relative to the incident one; `nex` = number of excited-state pairs in this partition.

`&STATES jp= bandp= ep= cpot= jt= bandt= et= /`  (repeat `nex` times)
- `jp/bandp(=ptyp)/ep` = projectile spin / parity band (+1 or -1) / excitation energy; `jt/bandt(=ptyt)/et` = target spin/parity/excitation. `cpot` = the `kp` index of the optical potential for this pair's distorted wave. `copyp`/`copyt` = reuse a previously defined projectile/target state (do not re-declare its spin/parity).

End all partitions with an empty `&partition /`.

---

## &POT: potentials, by TYPE and SHAPE

First `&POT` of a given `kp` has `TYPE=0` (Coulomb + defines radii): `&POT kp= type=0 ap= at= rc= /` (or `p1=ap p2=at p3=rc`). Radii use `R = r0*(ap^1/3 + at^1/3)`. Then add components with `TYPE>0`, same `kp`, cumulatively. `kp<0` or empty `&pot /` ends the block.

`&POT kp= type= shape= p1= p2= p3= p4= p5= p6= /`

**TYPE** (the interaction term):
| TYPE | meaning |
|------|---------|
| 0 | Coulomb (defines radii, charge) |
| 1 | central volume |
| 2 | central derivative (surface) |
| 3 | spin-orbit, projectile |
| 4 | spin-orbit, target |
| 5,6,7 | tensor (proj / target / L·(proj+targ)) |
| 8 | spin-spin |
| 9 | effective-mass reduction |
| 10,11 | deformed projectile / target (ROTOR matrix elements) |
| 12,13 | proj / target coupled by matrix elements read in (need `&step`) |
| 14-17 | second-order / all-order deformation couplings |
| 20,21 | N-N potentials (SSC(C) / user NNPOT), KIND=1 states only |

Negative TYPE adds numerically into the previous potential.

**SHAPE** (radial form for TYPE=1,8,15; parenthetical is with `R=p2*CC`, `E=exp((r-R)/p3)`):
0 = Woods-Saxon, 1 = WS-squared, 2 = Gaussian, 3 = Yukawa, 4 = exponential, 5/6 = Reid soft core T=0/1, 7 = read real, 8 = read imaginary, 9 = read complex (from fort.4/datafile), -1 = Fourier-Bessel. Surface (TYPE=2) and spin-orbit (TYPE=3,4) use the derivative forms of the same shapes. SHAPE>=10 and deformation forms (10-13) build deformed multipoles; SHAPE 40-43 give π/L/J-dependent potentials.

Standard optical-model term set for a WS potential:
```
&POT kp=1 type=0 ap=<Ap> at=<At> rc=<r_c> /
&POT kp=1 type=1 p1=<V> p2=<r_V> p3=<a_V> p4=<W> p5=<r_W> p6=<a_W> /   ! volume real+imag
&POT kp=1 type=2 p4=<W_s> p5=<r_s> p6=<a_s> /                          ! surface imag
&POT kp=1 type=3 p1=<V_so> p2=<r_so> p3=<a_so> /                       ! spin-orbit
&pot /
```

**Deformations** (TYPE 10-13): `P(k)=DEF(k)` nuclear deformation length (fm) for k>0, or `Mn(Ek)` Coulomb reduced matrix element. `&step IB,IA,k,STR /` selects couplings from state IA to IB of multipolarity k, strength STR. See manual §3.4.4 for the M(Ek)/RDEF conventions.

---

## &OVERLAP: bound and scattering form factors, by KIND

`&OVERLAP kn1= [kn2=] ic1= ic2= in= kind= nn= l= lmax= sn= ia= jn= ib= kbpot= krpot= be= isc= nk= er= /`
- `kn1` (or range `kn1..kn2` for two-particle) = form-factor index. `ic1/ic2` = core and composite partition numbers; `in`=1 projectile overlap, 2 target. Particle mass = mass difference of composite and core (relativistic correction if `in<0`).
- `kind` = coupling order: **0 = (LN,SN)JN, use for typical one-particle transfers**; 1 = LS coupling; 2 = eigenstate in deformed potential; 3 = sum over coupled core + (ls)j; 6-9 = two-particle states. 
- `nn` = number of radial nodes (include origin, so nn>0); `l`=LN orbital angular momentum of the bound cluster relative to core; `sn` = intrinsic spin of the bound nucleon; `jn` = LN+SN.
- `kbpot` = `kp` index of the binding potential; `be` = binding energy (positive bound, negative for continuum bins). `isc` = binding adjustment: 0 = fixed potential, >0 = vary TYPE=isc component to give BE. **For continuum bins, `isc=2` (default) is recommended** (near-real coupled-channels bins); `isc=4` for resonances; the normalise-to-unity options (`isc=-1,1,3`) are "not recommended for physics reasons".
- Warning: imaginary parts of bins give imaginary long-range Coulomb couplings that are **ignored** between `|rmatch|` and `rasym`. Use `isc=2` so bins are near-real.

**Two-nucleon overlaps (KIND 6-9).** Two-particle bound states are built from pairs of previously defined one-particle states. In the `&overlap`, the fields change meaning: `nn`→NPAIRS (number of pair products summed), `l`→ℓ_min, `lmax`→ℓ_max, `sn`→S_min, `jn`→J₁₂ (total angular momentum outside the core), `kbpot`→T (isospin, enforce ℓ+S₁₂+T odd), `krpot`→KNZR (the KN index of the single-particle NN relative-motion state). The pair structure itself is given by a following `&TWONT NT(1:4,:)= COEF(:)= /` namelist: `Σ_I COEF(I) |(l₁,s₁)j₁,(l₂,s₂)j₂;J₁₂,T⟩` with `NT(1,I)=KN1` and `NT(2,I)=KN2` the two single-particle states, transformed (Moshinsky) into the (r,R) two-nucleon form factor. Use this for (t,p)/(p,t)/(³He,n) two-neutron/two-proton transfer. Both simultaneous (direct 2N) and sequential (through an intermediate one-nucleon partition) paths are usually needed; see `examples/2n-transfer-li9tp-simseq.nin`.

---

## &COUPLING: couplings, by KIND

`&COUPLING icto= icfrom= kind= ip1= ip2= ip3= p1= p2= [ip4= ip5=] /`  Coupling from all states in partition `icfrom` to all in `icto` (reverse included unless `icto<0`). End with empty `&coupling /`.

**KIND**:
| KIND | meaning | key params |
|------|---------|-----------|
| 1 | general spin transfer (external form factors) | ip1 local/nonlocal, ip3 folding source |
| 2 | electromagnetic one-photon (Eλ/Mλ) | ip1=λ multipolarity, ip2 E/M, P1/P2 g-factors, ip4 direct/semidirect capture |
| 3 | single-particle excitation of projectile | ip1=Q multipole, ip2 Coul/nuc, ip3 reorientation, p1/p2 = KP indices |
| 4 | single-particle excitation of target | as KIND=3 |
| 5 | zero-range / LEA transfer | p1=D0, p2=finite-range param |
| 6 | LEA transfer using D0 & D from bound states | |
| 7 | finite-range transfer | ip1 post(0,-2)/prior(1); ip3=KPCORE remnant potential |
| 8 | non-orthogonality supplement to a KIND 5,6,7 | ip1 post/prior |

For KIND 3 (projectile breakup in CDCC): `ip1=Q` max multipole, `ip2=0` Coulomb+nuclear / `1` nuclear / `2` Coulomb, `ip3=0` all couplings (see manual for reorientation options), `p1`=fragment-target KP, `p2`=core-target KP.

Spectroscopic amplitudes for transfer come from `&CFP in= ib= ia= kn= a= /` namelists (read after the first coupling that needs them). `A` is the signed amplitude (root of the spectroscopic factor, with the √N antisymmetrisation factor already folded in), sign consistent with the `(l,s)j,Jcore;Jcom` coupling order.

**DWBA vs CRC is a solution mode, not a coupling KIND.** What sets them apart is whether the transfer channel is inside the exactly-solved block (`iblock`) or treated by iteration:
- **DWBA** (one step, perturbative): the transfer channel is left OUTSIDE the exact block, so only the elastic (and any inelastic) channels are blocked (`iblock` small, e.g. 1 per partition) and the transfer coupling is applied by iteration to first order (`iter=1`), forward direction only (`icto<0` suppresses the reverse). Setting `iter=1` alone is not enough; if `iblock` reaches the transfer channel it is no longer DWBA.
- **CRC** (all orders): `iblock` is large enough to block the coupled partitions together so the transfer channel is solved exactly (`iter=0`), reverse couplings kept (`icto>0`). Multi-step chains across several partitions (e.g. elastic ↔ inelastic ↔ transfer, or A → B → C sequential two-nucleon) are CRC by construction. Validate a DWBA result by switching to CRC and checking the cross section is stable.

---

## Quick sanity defaults (per calculation type)

- **Elastic** optical model: `hcm=0.1 rmatch=~40-60 jtmax=~50 absend=1e-3`, one partition, TYPE 0/1/2/3 potential, empty `&overlap`/`&coupling`.
- **Inelastic** collective excitation: add the excited level as a second `&STATES` (`copyp=1` if the projectile stays in its ground state), deform the potential with TYPE=10 (project.) / 11 (target) giving the deformation length in `p2`, or TYPE=12/13 + `&step IB,IA,k,STR`. `iter=1` for DWBA, `iter=0 iblock=2` for full CC. Same single partition.
- **Transfer**: needs `rintp, hnl, rnl, centre` for nonlocal kernels, `nnu` Gaussian points, a second `&PARTITION`, `&overlap` bound states, `&coupling kind=7` (finite range) or `kind=5` (zero range) + `&cfp` amplitudes. Watch post vs prior (`ip1`).
- **Breakup / CDCC** (heavy-ion / halo): `hcm=0.05 rmatch=-50 rasym=~100-340 accrcy=1e-3`, `jump/jbord` blocks, `cutr` negative, `smallchan/smallcoup` to prune, `iter=0 iblock=<Nbins+1>` for full CC; continuum bins as `&overlap` with `isc=2` and negative `be`, `&coupling kind=3`.
- **Capture**: `&overlap` for the final bound state, `&coupling kind=2` with `ip1=λ` (multipolarity), `ip4` = 0 direct / 1 semidirect / 2 both; S-factor in fort.35.
