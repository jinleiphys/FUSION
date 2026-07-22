# SIDES failure modes

Hit while building and verifying the skill on macOS/ARM64 gfortran 15.2 against
the Linux/x86_64 gfortran 13.3 reference.

## Build / packaging

- **The Makefile links to `../sides`, a path OUTSIDE the source directory.** The
  README describes a `SIDES/src/` layout with the executable one level up, but the
  released archive is flat (`SIDES/*.f90`), so `exe = ../sides` points out of the
  package. On some extraction layouts `../sides` resolves onto an existing
  directory and the link dies with `ld: open() failed, errno=21` (EISDIR),
  leaving `make` at a nonzero status even though every object compiled. Fix:
  override the target, `make exe=sides.x`, keeping the executable inside the
  source directory. `install_sides.sh` does this and never writes to `..`.

- **gfortran warns about deleted Fortran-2018 features but still builds.** The
  code uses labelled `DO` termination and arithmetic `IF`; gfortran 13/15 emit
  "deleted feature" warnings and compile cleanly. These are warnings, not errors,
  and are expected; do not treat them as a build failure.

- **The download is a Mendeley Data zip, not a git repo.** `install_sides.sh`
  fetches `SIDES.zip` from the dataset's public file URL and checks it is a valid
  archive (`unzip -t`) before extracting, so an HTML error page returned in place
  of the zip is caught rather than fed to the build.

## Run

- **`sides.x` reads its inputs from stdin, in order, with no keyword names.** A
  deck is a bare sequence of answers; a missing or extra line shifts every
  subsequent answer and silently changes the calculation. Always start from a
  known-good deck (the shipped `INPUT`) and change one field at a time.

- **Branch-dependent line count.** The energy block is one line (`Elab Lmax`)
  only when line 3 is `1`; the User-Choice grid lines consume an extra value each
  when set to `1`. A deck written for the pre-defined grid will misparse if a
  grid line is switched to User Choice without adding its value line.

- **Output is not on stdout.** The cross sections go to
  `INTEGRAL-CROSS-SECTION-<system>`; stdout carries only the echoed inputs and a
  cpu-time line. Reading stdout for the answer finds nothing. Assert success from
  the integral-cross-section file.

- **Output filenames are derived from the case and can be stale.** A killed or
  earlier run leaves an `INTEGRAL-CROSS-SECTION-*` behind; clear stale ones before
  a run (the wrappers do) and take the newest afterward.

## Verification

- **Not bit-identical across compilers.** The integro-differential iteration
  makes the last few digits toolchain-dependent (~1e-11 relative between gfortran
  13.3 and 15.2). The pin is gated at 1e-6 relative, which certifies the physics
  is reproduced while tolerating that FP noise. Do not tighten the gate to
  bit-identity: a legitimate compiler-version change would then read as a failure.

- **The optical-theorem check is neutron-only.** TOTAL = ELASTIC + REACTION holds
  because a neutron has no Coulomb interaction. For a proton deck the identity is
  false by construction, so applying it would wrongly reject a correct run; the
  wrappers gate it on projectile == neutron.
