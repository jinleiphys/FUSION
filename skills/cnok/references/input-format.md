# CNOK input format

CNOK reads YAML. The path to the active deck's directory is written in
`config/basedir.yaml` (`basedir: <dir relative to the build dir>`); `mom` finds
`<basedir>/<name>.yaml` from the command-line `<name>`. This documentation is
written from the shipped decks (`config/C/...`) and the code's own comments, not
from memory.

## Command forms

```
./mom 1s11p             # single mode: cross sections for one valence config
./mom 1s11p -m          # single mode: parallel momentum distribution instead
./mom 1s11p -mc         # ... convolved with experimental resolutions
./mom -b rs.yaml        # batch mode: inclusive c.s. summed over configs (C2S-weighted)
./mom -b rs.yaml -m     # batch inclusive momentum distribution
./mom -b batch.yaml     # super-batch: many nuclei in one run
```

The `<name>` argument doubles as the YAML basename and encodes the valence
configuration: `1s11p` = `1s1/2 (x) 1/2+` (valence orbit `1s1/2`, core state
`1/2+`), `0d55p` = `0d5/2 (x) 5/2+`. An integer core spin J drops the trailing
`i` disambiguator; a half-integer J is written as `2J` (`0d55p` -> `5/2+`). This
naming is mandatory in batch mode, where `mom` deduces the per-config YAML names
from the `ob` list.

## Single-mode deck (valence configuration)

From `config/C/C16/1s11p.yaml`, the benchmark case:

```yaml
# --- potential / bound state of the valence nucleon ---
Eref: 4.2503        # effective eigenenergy S*a (MeV), = the reaction Q used
RHFrms: 4.734       # Hartree-Fock rms radius (fm) of the sp orbit to reproduce
V0: -27.803111      # central Woods-Saxon depth (MeV)   } if omitted, mom SEARCHES
r0: 5.036125        # central WS radius (fm)             } (V0,r0) to reproduce
a: 0.7              # central WS diffuseness (fm)        } Eref and RHFrms and
VS: -7.5            # spin-orbit depth (MeV)             } prints the optimum
rS: 5.036125        # spin-orbit radius (fm)
aS: 0.7             # spin-orbit diffuseness (fm)
rC: 5.036125        # Coulomb radius (fm), usually = r0

# --- reaction: P + T -> C + n + X ---
ZP: 6               # projectile Z
AP: 16              # projectile A
ZT: 6               # target Z
AT: 12              # target A
Ek: 239.            # lab energy in MeV/nucleon
Zc: 6               # core Z
Ac: 15              # core A
n: 1                # valence orbit radial quantum number (nodes, origin excluded)
l: 0                # valence orbit orbital angular momentum
j: 0.5              # valence orbit total angular momentum

# --- densities (t-rho-rho optical potential) ---
densC: config/C/15C.den   # core point-nucleon density
densT: config/C/12C.den   # target point-nucleon density
alphav: 0.7         # valence-nucleon size (fm) in rho_n(r)=exp(-r^2/alpha^2)
alphaC: 0.          # core folding size (0 = point)
alphaT: 0.          # target folding size
isPauli: false      # Pauli blocking in sigma_NN
FNNParOpt: 0        # NN amplitude parameterisation: 0 Horiuchi, 1 Lenzi-Ray
# optC / optV       # OPTIONAL: read a precomputed c+T / v+T optical potential
# ZEROR: 0.02       # ODE origin for the bound wave; only touch on a solver error
```

The (V0, r0) block is optional: leave it out on the first run and `mom` searches
the central-well parameters (via a globally convergent Newton-Raphson) to
reproduce `Eref` and `RHFrms`, printing the optimised values.

## Density files (`.den`, `.rho`)

Plain two-column tables of `r [fm]  rho(r) [fm^-3]`, preceded by a single line
giving the number of rows:

```
200
  0.000000E+00  1.929456E-01
  1.000000E-01  1.926678E-01
  ...
```

## Batch-mode deck

From `config/C/C16/rs.yaml` (inclusive removal from ^16C, sums over configs):

```yaml
nu:  [16., 4.2503, 22.5531, 82.76, 8.37]   # [A, Sp, Sn, exp c.s., d(c.s.)]
ob:  ["1s1/2_1/2+", "0d5/2_5/2+"]          # valence(nlj)_core(jpi[_i])
ex:  [0., 0.74]                            # core excitation energies (MeV)
c2s: [0.734, 1.167]                        # spectroscopic factors
# ek / isPauli / FNNParOpt  (optional, override the per-config decks)
```

`ob`, `ex`, `c2s` are parallel arrays. For momentum-distribution runs the Sp/Sn/
exp-c.s. entries are unused and may be arbitrary. Super-batch decks
(`config/C/batch.yaml`) carry a single `nus` array of batch-deck paths.

## Experimental resolutions (`config/expres.yaml`)

Consumed only by `-mc`. Standard deviations: `DBG` sigma(beta*gamma) of the
core, `DCOSREL` angular-resolution term, `DBG0`/`SDBG0` the incident-beam and
beamline spreads. See the shipped file's comments for the exact convolution.
