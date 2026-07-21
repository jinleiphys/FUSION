# AZURE2 failure modes

Every entry below was hit for real while building this skill. Grouped by whether
the failure is loud (build stops, run stops) or quiet (you get a number and the
number is wrong).

---

# Quiet: you get an answer and it is wrong

These are the dangerous ones.

## A stale `param.par` silently replaces your deck's parameters

If `param.par` exists in the output directory, AZURE2 reads the parameters back
from it instead of transforming the ones in the `.azr` (`src/AZUREMain.cpp:73-79`).
Edit a width, rerun, and nothing changes. Nothing warns you.

`run_azure2.sh` removes `param.par` and `parameters.out` before every run unless
`AZURE2_KEEP_PARAMS` is set. If you drive AZURE2 by hand, delete them yourself.

The same trap has a second edge: a calibration loop that reads `parameters.out`
without deleting it first will, if AZURE2 fails, happily read the **previous**
run's numbers and declare convergence. That is not hypothetical; it was
demonstrated against an earlier version of `calibrate_widths.py` by substituting
`/usr/bin/false` for the binary.

## `--no-transform` destroys the ANC normalisation

Reaching for `--no-transform` so you can type published reduced-width amplitudes
directly is a natural move and it is wrong for any case with external capture.
The flag skips the ANC-to-amplitude conversion, so the bound state's asymptotic
normalisation is no longer set by its ANC.

There are two distinct failures here. The blunt one: typing Table V's ANCs in
literally under `--no-transform` makes AZURE2 read fm^(-1/2) values as
MeV^(1/2) amplitudes, giving S(90 keV) = 19.66 keV b instead of 7.61. The subtle
one, which survives even after substituting the correct formal amplitudes, is
the loss of radius invariance described next.

The tell is channel-radius dependence. With the ANC live, S(90 keV) on the
benchmark case varies by 0.4% over `ac` = 4.5 to 5.5 fm, as ANC-normalised
external capture must. Under `--no-transform` it varies by a factor of 4 over
4.0 to 6.0 fm. **The two modes agree at the radius where the amplitudes were
converted**, so checking one radius cannot distinguish them.

## Missing entrance partial waves, with no message

AZURE2 enumerates external-capture pathways only over Jπ groups that exist among
the supplied levels (`src/CNuc.cpp:740-800`). If your paper says capture proceeds
through li = 1 and li = 3, but no level in your deck has a Jπ reachable by
li = 3, that half of the physics is simply absent. No warning is printed;
channels that violate the selection rules are `continue`d silently
(`src/CNuc.cpp:764-777`).

The fix is a "dummy" level carrying the needed Jπ. deBoer's FRIB/TALENT lecture:
*"AZURE2 eccentricity, need to add 'dummy' levels to tell code which angular
momenta to include in hard sphere phase shift calculations."* Confirm any dummy
is inert by moving it in energy: on the benchmark case, 4.711 / 10 / 20 MeV give
identical results to five decimals.

## Nothing validates a channel's physics

`src/AChannel.cpp:17-19` has no `else`. Any parity combination yields a valid
channel, just labelled E or M. An `l = 0` gamma channel produces a nonsense
"E0/M0" with penetrability `(E/hbarc)^1` and no complaint. The GUI enforces
triangle rules when it generates channels (`gui/src/LevelsTab.cpp:397`) but
**nothing re-checks them on load**, so a hand-written deck is unpoliced.

## A diverging solve writes `nan` and exits 0

Standard for iterative solvers, and the reason `run_azure2.sh` greps result
files for non-finite values rather than trusting the exit status.

## The channel-spin field of a capture channel is not used

For a `pType=10` channel the engine never uses the channel's own `s`
(`src/CNuc.cpp:696-731` matches only the entrance channel spin; the angular
distribution uses `pair->GetJ(2)` directly at `src/CNuc.cpp:1063`). So a wrong
`s` on a capture line changes nothing. But two capture lines differing **only**
in `s` become two distinct channels (`src/JGroup.cpp:80`) and double-count. Set
`s` to twice the residual nucleus spin and keep the lines distinct in something
that matters.

---

# Loud: the run or the build stops

## "Could not find output directory: output/. Check that it exists."

AZURE2 does not create the directories named in `<config>` (`src/Config.cpp:101-114`).
Exit code 255. Create them, and note the paths must end in `/` because filenames
are concatenated directly.

## The run hangs forever

AZURE2 is interactive. After reading the file it prints a menu and blocks on
`getline(std::cin,...)`, then asks for an external parameter file, and possibly
an external capture amplitude file. Pipe `printf '3\n\n\n6\n'` or use
`run_azure2.sh`.

## A level line fails to parse, or a section is not found

- **Section markers are compared with exact string equality** in the console
  path (`src/CNuc.cpp:109`, `src/EData.cpp:43`). Leading or trailing whitespace,
  or a CRLF line ending, and the section is not found.
- **There are no comments.** A `#` line inside `<levels>` is read as a level
  line and fails on the first field.
- A short level line sets `failbit` and `CNuc` returns -1 (`src/CNuc.cpp:126`).
  All 31 fields are mandatory for the console path.
- `<targetInt></targetInt>` is **required** even when empty; its absence is a
  fatal "Could not fill data object from file" (`src/EData.cpp:126-129`).

## Build: "fatal error: _bounds.h: No such file or directory"

Homebrew GCC bakes in the macOS SDK path it was built against, and its private
`include-fixed/_stdio.h` includes `<_bounds.h>`. After an Xcode SDK upgrade that
path is stale, and the error names a header the **current** SDK does ship while
pointing at gcc's own directory. It reads like a broken gcc install; it is not.

Fix: export `SDKROOT="$(xcrun --show-sdk-path)"`. `install_azure2.sh` probes for
this and applies it only when needed.

## Build: "g++-15: fatal error: no input files"

Caused by fixing the previous item the obvious way. AZURE2's `CMakeLists.txt:20`
reads

```cmake
set (CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS})
```

unquoted, so CMake builds a **list** and writes `-isysroot /path;-fopenmp` into
`flags.make`. Make passes that unquoted to the shell, the `;` terminates the
command, and g++ runs with a sysroot and no source file. Any non-empty
`CMAKE_CXX_FLAGS` triggers it. Pass the SDK via `SDKROOT` instead, which does not
go through that variable.

## Build: Minuit2 not found, or link fails on missing vtables

- AZURE2's `FindMinuit2.cmake` probes for `Minuit2/MnUserFcn.h`, which modern
  Minuit2 no longer installs, even though all six headers AZURE2 actually
  includes are present. Seed `MINUIT2_INCLUDE_DIR` and `MINUIT2_LIBRARY`
  directly.
- Minuit2 installs **two** archives and the finder links one.
  `ROOT::Math::Util::TimingScope` lives in `libMinuit2Math.a`.
- A clang-built Minuit2 (libc++, `std::__1`) will not link against a GCC-built
  AZURE2 (libstdc++, `std::__cxx11`). Pin both to the same compiler.

## Build: `finite()` not declared

`coul/include/complex_functions.H` calls the legacy BSD `finite()`, removed from
POSIX in 2008. This is the **same upstream pattern that breaks the GSM book
codes**, where it manifested as unbounded recursion instead of a compile error.
Patch to `std::isfinite`.

---

# Gotchas that are not failures

- `WARNING: R-Matrix specified but --ignore-externals and --use-brune options
  require A-Matrix. A-Matrix will be used.` is expected whenever external
  capture is active, even with no such flag passed. Not a fault.
- `<segmentsTest>` energies are **lab**, while the `.extrap` output energy column
  is **CM**. 90 keV CM is entered as 0.095670 for p + ¹⁶O.
- The S factor column of a `.extrap` file is in **MeV b**, not keV b.
- Cross sections are in **barns**.
- `isDiff` codes differ between the two segment sections: in `<segmentsData>`
  `3` means total capture, in `<segmentsTest>` `3` means angular distribution
  and `4` means total capture.
- `isDiff = 0` **ignores the segment angle cuts**, so an angle-integrated segment
  pointed at a mixed-angle data file swallows every block in it.
