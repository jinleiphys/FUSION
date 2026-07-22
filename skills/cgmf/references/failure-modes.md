# CGMF failure modes

Grouped by whether the failure is loud (the run stops) or quiet (you get output
and it is wrong or misleading).

## Quiet

### The data path is not the current directory

cgmf.x resolves its data tables from `-d`, then `$CGMFDATA`, then compiled-in
paths, and **never from the cwd** (`libcgmf/cgmfEvents.cpp:80-95`). Run it from a
directory it was not built to know about, without `CGMFDATA` set, and it prints
`Cannot find valid path to CGMF data` and `exit(-1)`. This is loud on stderr but
easy to miss if you only check the exit status of a pipeline. The wrappers export
`CGMFDATA` from the installer to avoid it entirely.

### The output filename gains a rank suffix

`-f h` does not write `h`; it writes `h.0` (`cgmf.cpp:412`, the MPI rank is always
appended). A script that opens the exact name it passed to `-f` finds nothing.

### The ZAID is the target, not the compound

For n+235U the ZAID is `92235`, not 92236. Passing the compound produces either a
different reaction or a failure, not the case you meant. `run_cgmf.sh` asserts the
history-file header ZAID and energy match what was requested, so a mismatch is
caught rather than silently analysed.

### Statistical noise read as a discrepancy

Every observable carries a Monte Carlo error ~ σ/√N. nu-bar for 252Cf(sf) is 3.80
at 40 events, 3.78 at 500, 3.72 at 3000, converging to the manual's 3.82 only at
large N. A low-N value that differs from the reference by a few percent is usually
statistics, not a bug. The way to tell: the run is deterministic, so re-running
the same args gives the identical number; only a larger N moves it.

### "Deterministic" is per-build, not universal

Two runs of the same binary with the same args are bit-identical, and this build
reproduces LANL's shipped reference exactly. But a different compiler,
architecture or optimisation level can perturb the last floating-point digits of
a trajectory, which cascades into a different history. If a future build stops
matching the reference, suspect the toolchain before the code, and confirm with a
physics observable (nu-bar) rather than a byte diff.

## Loud

### Cannot find valid path to CGMF data

See above. Set `CGMFDATA` or pass `-d`.

### Build needs only CMake and a C++ compiler

No exotic dependencies, no patches on macOS or Linux. If the build fails, it is
almost always a missing compiler or an ancient CMake; the logs are in
`build/{cmake,build}.log`.

## Not failures

- A run writing only run-average numbers to stdout is normal; the physics lives
  in the history file, analysed by CGMFtk.
- 252Cf(sf) at `-e 0.0` prints `<nu>_prefission = 0.00`; spontaneous fission has
  no pre-fission neutrons by construction.
- Long run times are expected. CGMF is a full Hauser-Feshbach cascade per
  fragment; a few thousand events take a minute or two on one core. Heavy
  statistics belong on a cluster (and CGMF has an MPI build).
