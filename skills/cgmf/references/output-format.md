# CGMF output

Two outputs per run: a run-average summary on stdout, and a history file. All
distributional observables (spectra, yields, correlations, nu-bar as a function
of anything) come from post-processing the history file with the bundled Python
package CGMFtk, not from cgmf.x.

## stdout summary (`printSummaryEvents`, `cgmf.cpp:208-365`)

One block per run: reaction line; average light/heavy fragment Z and A; average
kinetic energies (LF, HF, TKE); excitation energies (TXE); fragment spins; then

```
*** Prompt Fission Neutrons ***
Multiplicities (n/f):  <nu>_LF = .. ; <nu>_HF = .. ; <nu>_prefission = .. ; <nu>_tot = ..
... c.o.m. and lab average energies ...
*** Prompt Fission Gammas ***
Multiplicities (g/f):  <nu_g>_LF = .. ; <nu_g>_HF = .. ; <nu_g>_tot = ..
```

`<nu>_tot` is the average total prompt-neutron multiplicity per fission event
(nu-bar), printed to two decimals. `run_cgmf.sh` reads it as the liveness check.

## History file (`printEventToFile`, `cgmf.cpp:444-565`)

Filename `<base>.<rank>`, e.g. `histories.cgmf.0`.

- **Line 1 (once):** `# ZAID Einc timewindow`, e.g. `# 98252 0 1e-08` or
  `# 92235 2.53e-08 1e-08`. `run_cgmf.sh` asserts this matches the request.
- **Per event: a light-fragment block, then a heavy-fragment block.** Each block:
  - fragment header: `A Z U(MeV) J(hbar) parity KE_pre(MeV) KE_post(MeV) nu_n nu_g X`
    where the trailing integer `X` is `0` for the light fragment and the
    **pre-fission neutron count** for the heavy fragment;
  - momentum line: pre-emission `(px,py,pz)` then post-emission `(px,py,pz)`;
  - if `nu_n>0`: a c.o.m. neutron line then a lab-frame neutron line, each
    neutron being four numbers `dircos_u dircos_v dircos_w energy(MeV)`;
  - if `nu_g>0`: a photon line, each photon four numbers (five with a trailing
    emission-age when `-t` is negative).
- Pre-fission neutrons, if any, follow the heavy block, four numbers each.

## Yields file (negative `-n`)

`yields.cgmf.<rank>`, **no header line** (the `Y(Z,A,KE,U,J,Pi,px,py,pz)` string
is printed to stdout, not written to the file). Each line is one scission
fragment: `Z A KE U J parity px py pz`, e.g.
`44 115 103.915 22.1845 10.5 1 4157.66 121.856 -2224.46`. Two lines per event
(light then heavy fragment).

## CGMFtk post-processing (`tools/CGMFtk`)

```python
from CGMFtk import histories as fh
h = fh.Histories('histories.cgmf.0')
h.nubartot()   # avg neutrons per fission event, incl. pre-fission (histories.py:614)
h.nubar()      # avg neutrons per fragment                          (histories.py:610)
h.nubarg()     # avg gammas per fragment                            (histories.py:618)
h.nubarA()     # nu-bar vs fragment mass                            (histories.py:915)
h.nubarTKE()   # nu-bar vs total kinetic energy                     (histories.py:999)
```

Install it with `pip install tools/` from the CGMF clone, or add `tools/` to
`PYTHONPATH`. Spectra (PFNS, PFGS) and yield distributions are further methods on
the same `Histories` object; see `doc/rtd/tools.rst`.
