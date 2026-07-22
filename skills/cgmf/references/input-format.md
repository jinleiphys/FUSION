# CGMF input and command line

Derived from the source (`utils/cgmf/cgmf.cpp`, `libcgmf/`) and the shipped
manual (`doc/rtd/`), not from memory. There is no input deck; CGMF is driven
entirely by command-line flags.

## Flags

The option string parsed by `getopt` is `"e:n:i:f:t:d:s:"` (`cgmf.cpp:379`); every
flag takes an argument.

| Flag | Meaning | Units | Default |
|---|---|---|---|
| `-i` | ZAID = 1000*Z + A of the **target** nucleus, or the fissioning nucleus for spontaneous fission. Required. | integer | 0 |
| `-e` | incident neutron energy; **`0.0` = spontaneous fission**. Required. | **MeV** | -1 |
| `-n` | number of Monte Carlo events; **negative = initial-yields mode** Y(Z,A,KE,U,J,p) | integer | 0 |
| `-s` | starting-event offset (seed skip-ahead) | integer | 1 |
| `-f` | output base name; **the MPI rank is appended** (`-f h` writes `h.0`) | string | `histories.cgmf` / `yields.cgmf` |
| `-t` | isomer time-coincidence window; **negative = infinite window** and adds a gamma emission-age column | seconds | 1e-8 |
| `-d` | data-directory path, overriding `$CGMFDATA` and the compiled-in default | path | "" |

No `-h`/help flag exists (unknown flags are silently ignored, `cgmf.cpp:402-403`),
and there is no random-seed flag: reproducibility is structural (below).

## ZAID and energy conventions

- `ZAID = 1000*Z + A`. Decoded as `Zt = ZAID/1000`, `At = ZAID - 1000*Zt`
  (`cgmf.cpp:319-320`). `98252` = Cf-252.
- **Neutron-induced: the ZAID is the TARGET.** For n+235U pass `-i 92235` (the
  U-235 target), not 92236. The shipped ctest uses exactly `-i 92235`
  (`utils/cgmf/tests/u235nf-th-events/CMakeLists.txt`).
- Incident energy is MeV. Thermal is passed as `-e 2.53e-8` (0.0253 eV).
- Spontaneous fission sentinel is `-e 0.0` (branch `if (incidentEnergy==0.0)`,
  `cgmf.cpp:322`).

## Supported reactions (`README.md:52`)

- Spontaneous fission: Cf-252, Cf-254, Pu-238, Pu-240, Pu-242, Pu-244.
- Neutron-induced, thermal to 20 MeV: U-233, U-234, U-235, U-238, Np-237,
  Pu-239, Pu-241.

A ZAID or energy outside this set is not silently corrected to a neighbour; the
run fails through stderr, which `run_cgmf.sh` treats as failure.

## Data-table path resolution (matters for running from any directory)

cgmf.x opens its ~30 data files as `datadir + filename`. `datadir` is resolved in
priority order (`cgmf.cpp:427-431`, `libcgmf/cgmfEvents.cpp:80-95`):

1. the `-d` flag;
2. else the `CGMFDATA` environment variable;
3. else the compiled-in `INSTALL_DATADIR`, then `BUILD_DATADIR` (baked at
   configure time in `libcgmf/CMakeLists.txt:30-31`);
4. else it prints `Cannot find valid path to CGMF data` and `exit(-1)`.

**The current working directory is never consulted.** `install_cgmf.sh` emits
`CGMFDATA=<path>` and the wrappers export it, so a run works from anywhere.

## Reproducibility (the benchmark rests on this)

There is no seed flag, but the run is deterministic. In the event loop the RNG
(`std::mt19937`) is re-seeded per event from the event index
(`cgmf.cpp:90-92`):

```cpp
for (int i=0; i<nevents; i++) {
  rng.set_seed(i + ip*nevents + startingEvent);
  ...
}
```

So event `i` on MPI rank `ip` always uses seed `i + ip*nevents + startingEvent`.
Two runs of the same build with the same args are bit-identical, and `-s` shifts
the sequence. The repo's CTest relies on this, comparing runs byte-for-byte
against shipped `.reference` files with `cmake -E compare_files`.
