# High-level CDCC input format

FRESCO accepts a compact CDCC front end that auto-builds the continuum bins, their overlaps, and the breakup couplings, then expands internally into the standard namelist deck (written to fort.301, alias fort.305 for column format). Use it only for a textbook two-body-projectile CDCC breakup. For anything with transfer channels, hand-tuned bins, or custom couplings, write the standard format instead (see `examples/*-lowlevel.nin`).

## Structure

```
<heading>
CDCC
 &CDCC hcm= rmatch= rintp= absend= rasym= accrcy=
       elab=
       jbord= ...   jump= ...
       thmax= thinc= smats= xstabl= cutr= cutc=
       nk= ncoul1= reor= q= /
 &NUCLEUS part='Proj'   name= spin= parity= be= n= l= j= /
 &NUCLEUS part='Core'   name= charge= mass= /
 &NUCLEUS part='Valence' name= charge= mass= spin= /
 &NUCLEUS part='Target' name= charge= mass= /
 &BIN spin= parity= step= end= energy=F l= j= /     ! one line per partial-wave bin set
 &BIN /                                              ! empty ends bins
 &POTENTIAL part='Proj' a1= a2= rc= /               ! projectile-target (defines radii)
 &POTENTIAL part='Core' a1= a2= rc= V= vr0= a= W= wr0= aw= /   ! core-target optical
 &POTENTIAL part='Valence' a1= rc= V= vr0= a= W= wr0= aw= /    ! valence-target optical
 &POTENTIAL part='Gs' a1= v= vr0= a= vso= rso0= aso= /         ! projectile binding potential
```

## Key &CDCC variables (differ from &FRESCO aliases)

- `cdccc` is an alias for `cdcc`.
- `q = ip1` = maximum multipole for the projectile single-particle couplings.
- `ncoul1 = ip2` = select nuclear and/or Coulomb couplings.
- `reor = ip3` = diagonal and/or off-diagonal (reorientation) couplings.
- `qc = ip4` = Qmax for the deformed-core potential multipoles.
- `la = ip5` = Λmax for the form-factor reduction.
- `hat` = use mean bin energies (default true) vs midpoint.
- `quasi` = force all channel energies to one value (adiabatic / quasi-static limit, e.g. set to the binding energy).
- `hktarg` = target value of h·K (K = elastic wave number), default 0.2; if `hcm=0` in &CDCC, the step is chosen from `elab` and `hktarg`.
- `sumform` = bin form-factor reduction level (0 none, 1 sum into new Λ multipole, 2 sum into composite projectile state; 2 is incompatible with spin-orbit or transfer couplings).
- `trans` = number of transfer partitions (0 none, <0 ejectile≡core, >0 independent).

## &NUCLEUS

One line per body, `part=` tag identifies its role: P/Proj (projectile), C/Core, V/Valence, T/Target, E/Ejectile, R/Residue. The number of bodies (4/5/6) depends on `trans`. `name/mass/charge` as in &partition; `spin/parity` as Jp/Bandp in &states; `be,n,l,j,ia,a,kind,lmax,nch` prescribe the projectile bound state (and residue R for transfers). `nce` = number of core-excited states; if `nce>0`, read that many `&CORESTATES spin= parity= ex= /`.

## &BIN

`spin, parity, step, start, end, energy, n, l, j, isc, ipc, kind, lmax, nch, ia, il, ampl`. Each line is one set of continuum bins in the (l,j) partial wave. Energy range `(end-start)/step` bins; `energy=F` (false) spaces bins evenly in momentum (k ∝ √E) which is usually what you want, `energy=T` spaces evenly in energy. `isc/ipc/kind/lmax` carry the &overlap meanings; `il` selects the incoming channel (0 = default channel with quantum numbers l,j,ia). Empty `&BIN /` ends the list.

## &POTENTIAL

`part=` tag as in &NUCLEUS: P (projectile-target), C (core-target), V (valence-target), T (projectile ground state), B (projectile excited channels), transfer/ejectile/residue. Fields: `a1,a2,rc,v,vr0,a,w,wr0,aw,wd,wdr0,awd,vso,rso0,aso,shape,l,parity,nosub,beta2,beta3,...`. `nosub` means the projectile optical potential is added as a diagonal in all projectile-state channels (not subtracted). `beta2m/beta3m` = nuclear fractional deformations, `beta2c/beta3c` = Coulomb equivalents. `idef` restricts to Coulomb+nuclear (0) / nuclear (1) / Coulomb (2).

## Worked example (from the manual, 11Be+4He CDCC)

```
11Be+4He spdf; 1+5*10+2*5 chs 0-10 MeV, q=0-3 2200 MeV, 30/100 fm
CDCC
 &CDCC hcm=0 rmatch=-30 absend=-50 rasym=100 accrcy=0.001
       elab=2200
       jbord= 0  60 200 2500    jump = 4  5  20
       thmax=30 thinc=.05 smats=2 xstabl=1  cutr=-10 cutc=0
       nk=50 ncoul1=0 reor=0 q=3 /
 &NUCLEUS part='Proj' name='11Be' spin=0.5 parity=+1 be=0.500 n=2 l=0 j=0.5 /
 &NUCLEUS part='Core' name='10Be' charge=4 mass=10 /
 &NUCLEUS part='Valence' name='neutron' charge=0 mass=1 spin=0.5 /
 &NUCLEUS part='Target' name='4He' charge=2 mass=4 /
 &BIN spin=0.5 parity=+1 step=0.5 end=10. energy=F l=0 j=0.5 /
 &BIN spin=0.5 parity=-1 step=0.5 end=10. energy=F l=1 j=0.5 /
 ... (one &BIN per (l,j) partial wave up to spdf) ...
 &BIN /
 &POTENTIAL part='Proj' a1=11 a2=4 rc=1.0 /
 &POTENTIAL part='Core' a1=10 a2=4 rc=1.0 V=46.92 vr0=1.204 a=0.53 W=23.46 wr0=1.328 aw=0.53 /
 &POTENTIAL part='Valence' a1=4 rc=1.3 V=37.14 vr0=1.17 a=0.75 W=8.12 wr0=1.26 aw=0.58 /
 &POTENTIAL part='Gs' a1=10 v=51.51 vr0=1.39 a=.52 vso=0.38 rso0=1.39 aso=0.52 /
```

## When to leave this format

- You need **transfer channels alongside breakup**: use the standard format.
- You need **non-uniform or resonance bins**, or bins with custom weighting: standard `&overlap` with explicit `isc`.
- You need to **read the expanded deck** FRESCO built: look at fort.301 after a &CDCC run. Reading and adapting that expanded deck is often the fastest way to get a standard-format CDCC deck.
