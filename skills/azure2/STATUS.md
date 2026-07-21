# azure2 skill: INCOMPLETE, do not treat as shipped

There is deliberately **no `SKILL.md` here yet**, so nothing loads this as a
skill. What exists is the hard part of the port: a tested, clean-room
`scripts/install_azure2.sh` that goes from nothing to a working headless AZURE2
binary in about 19 seconds.

## Why this was built ahead of the rest of the Wave 1b queue

The fusion-paper benchmark (`/Users/jinlei/Desktop/code/fusion-paper`) gates
submission on **one completed skill per subfield row**. Reactions and Structure
are already satisfied. The remaining Wave 1b codes (NLAT, CNOK, SIDES, SWANLOP)
are all reaction codes, so they deepen a satisfied row and move the gate by
nothing. AZURE2 completes the **astro / R-matrix** row and, of the four
candidates for the two empty rows, has the cleanest openness story: public repo,
GPL-3.0, published paper (Azuma et al., Phys. Rev. C 81, 045805 (2010)).
GEMINI++'s two known distribution URLs both return 404.

## What works

`scripts/install_azure2.sh`, verified from a wiped cache. It encodes six fixes,
four of which report symptoms pointing away from their cause; each is documented
inline at the top of the script. The two worth repeating here:

- `coul/include/complex_functions.H` calls the legacy BSD `finite()`, removed
  from POSIX in 2008 and absent on macOS. **This is the same upstream pattern
  that breaks the GSM book codes**, where it manifested as unbounded recursion
  rather than a compile error. Two independent nuclear codes, one dead function.
- AZURE2 requires OpenMP, Apple clang's `-Xclang -fopenmp` shim gets mangled by
  this build, and switching to GNU then forces Minuit2 to be rebuilt with GNU
  as well, because libc++ (`std::__1`) and libstdc++ (`std::__cxx11`) will not
  link against each other.

Minuit2 is built standalone from the GooFit fork rather than pulled in as part
of a 1 to 2 GB ROOT install.

## What is missing, and the blocker

**No test case.** The AZURE2 repo ships no `.azr` configuration file, and
`azure.nd.edu` currently serves a 3 kB placeholder. So Level 1 (build) is solid
while Level 2 (reproduce the author's reference case) has nothing to reproduce.

This is the pikoe situation again, and it decides the benchmark tier. Options,
in preference order:

1. Ask R.J. deBoer for the standard example set. He is the repo owner and the
   AZURE2 corresponding author, and the request also fixes a distribution gap
   for everyone else.
2. Recover an example from the AZURE2 manual, if it contains a fully specified
   configuration with published output.
3. Build a case from a published R-matrix analysis with tabulated numbers, and
   state plainly that the comparison is against the paper rather than against a
   distributed reference.

Until one of those lands, this cannot claim tier 1, and the honest label is
"builds and runs, no reference reproduction".

## Remaining work

- `SKILL.md`, `references/` (input format from the manual, failure modes,
  verification), `examples/`, `scripts/run_azure2.sh` with positive-assertion
  success checks, `scripts/verify_azure2.sh`.
- Codex adversarial pass, mandatory before shipping.
