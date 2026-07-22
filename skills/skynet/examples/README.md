# SkyNet examples

The benchmark is not a copied input deck. SkyNet is a library, and its
calculations are compiled drivers; the shipped `tests/*` drivers are real
network calculations that self-compare against the authors' reference values.
`run_skynet.sh` runs those drivers from the build tree (where CMake has copied
each case's input files), which is more faithful than a hand-copied input.

Run the default alpha network (fast, cross-platform stable):

```bash
bash ../scripts/run_skynet.sh alpha         # X(ni56) = 1.7794E-02
bash ../scripts/verify_skynet.sh            # tier-1 benchmark (alpha + NSE + CTest)
```

Other shipped network calculations:

```bash
bash ../scripts/run_skynet.sh nse           # NSE (Saha) at three settings
bash ../scripts/run_skynet.sh xrayburst     # full rp-process on an X-ray-burst trajectory
bash ../scripts/run_skynet.sh neutrino      # network with neutrino reactions
bash ../scripts/run_skynet.sh small         # small hand-checkable networks
```

Note on `nse` on macOS: its third block (full-network Saha at T9=3) is
libm-limited and does not meet the shipped 3.5e-5 gate on Apple's `exp`/`log`
(it passes on Linux with the identical source). `run_skynet.sh` reports this
honestly and still shows the finite abundances. See `../references/verification.md`.

## Authoring your own network

To build a new calculation (a different trajectory, nuclide set, or rate
libraries), write a driver following `../references/input-format.md`. The
canonical template is the distribution's `examples/r-process.py` (installed under
`$SKYNET_INSTALL/examples/`), which sets up an r-process in neutron-star-merger
ejecta: an NSE initial condition, an expanding density profile, strong + weak +
fission rate libraries, and self-heating evolution, then writes the final Y(A)
abundance pattern. Running it needs the Python (SWIG) bindings, which are OFF in
this build; `input-format.md` explains how to turn them on or use the C++ driver
route instead.

## The 25+ nuclear data sets

`ls $SKYNET_DATA` in the install prefix lists the shipped nuclear data: the
webnucleo nuclide database, the JINA REACLIB snapshot, fission rate sets
(`netsu_*`), FFN/MESA weak rates (`FFN_*`), and the Helmholtz EOS table. These
are the inputs every driver reads; a custom calculation picks the subset its
physics needs.
