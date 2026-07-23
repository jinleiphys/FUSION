# Sky3D examples

No deck is vendored here. Sky3D is CPC non-profit licensed rather than open
source, so this skill redistributes none of its files; the decks below come from
the clone that `scripts/install_sky3d.sh` makes, under `$SKY3D_TESTS`.

## 1. Static 16O (the benchmark)

`$SKY3D_TESTS/Static/for005.static`. SV-bas, no pairing, 24^3 grid at 1.0 fm,
`serr=1D-6`, cap 2000 iterations. Converges in 370 iterations to a binding energy
of -116.6577 MeV and an rms radius of 2.6884 fm, and writes the wavefunction file
`O16`. About 20 seconds on one modern core.

```bash
eval "$(scripts/install_sky3d.sh | grep '^SKY3D')"
scripts/run_sky3d.sh --deck "$SKY3D_TESTS/Static/for005.static" --workdir /tmp/o16
python3 scripts/compare_sky3d.py /tmp/o16/for006 "$SKY3D_TESTS/Static/for006.static"
```

This is the case `verify_sky3d.sh` runs, and it is a genuine reproduction of the
authors' distributed output.

## 2. 16O + 16O collision

`$SKY3D_TESTS/Collision/for005.coll`. E_cm = 100 MeV, impact parameter 2 fm,
48 x 24 x 48 grid, 1000 steps of 0.2 fm/c, i.e. 200 fm/c of evolution. It reads
two copies of the O16 wavefunction from example 1 through
`filename=2*'../Static/O16'`, so run example 1 first and stage its output:

```bash
scripts/run_sky3d.sh --deck "$SKY3D_TESTS/Collision/for005.coll" \
  --workdir /tmp/coll --fragment /tmp/o16/O16:../Static/O16
```

About 45 minutes (943 time steps). **Its shipped `.res` tables are not a benchmark**: their real
input is a binary wavefunction the distribution does not ship, so an independently
converged O16 does not reproduce them. Read `references/verification.md` before
drawing any conclusion from a comparison against them.

## 3. Giant-resonance strength function

`$SKY3D_TESTS/GR/for005.gr` boosts a converged ground state with a multipole
field (`&main texternal=T` plus `&extern`), and `$SKY3D_TESTS/GR/spectral_analysis.f90`
Fourier-transforms the resulting moment series into a strength function. Also
needs a wavefunction file from a static run.

## Writing your own

Start from example 1 and change one thing at a time. The two changes that most
often break a first deck are forgetting that `nprot`/`nneut` are full particle
numbers rather than valence occupations, and putting a grid too small around a
heavy nucleus, which shows up as particle number leaking away from its integer
value in the moments table.
