# azure2 skill: INCOMPLETE, do not treat as shipped

There is deliberately **no `SKILL.md` here yet**, so nothing loads this as a
skill. What exists is the hard part of the port: a tested, clean-room
`scripts/install_azure2.sh` that goes from nothing to a working headless AZURE2
binary in about 19 seconds.

## Distribution and licence: resolved 2026-07-21, use the open-source channel

AZURE2 was briefly questioned on the grounds that it "is not freely
downloadable". That doubt was correct about one channel and wrong about the
other, so it is worth writing the distinction down rather than leaving it to
memory:

| Channel | Status | Usable? |
|---|---|---|
| `github.com/rdeboer1/AZURE2` | **GPL-3.0, public, anonymous `git ls-remote` succeeds with no credentials, actively pushed** | **Yes, this is what the installer uses** |
| `azure.nd.edu` | Redirects to `login.php`, registration-gated | No, and nothing here touches it |

**Decision (user): build from the open-source channel.** The FUSION private-code
boundary requires a code to be both publicly open-source and backed by a
published paper. AZURE2 satisfies both: the repo is public and GPL-3.0, and the
paper is Azuma et al., Phys. Rev. C **81**, 045805 (2010), DOI
`10.1103/physrevc.81.045805`, verified live against CrossRef rather than quoted
from memory.

This is **not** the GEMINI++ case. GEMINI++ was dropped because *both* of its
known distribution URLs return 404 and no public repo exists anywhere, so nobody
can obtain it. AZURE2 has a working public source of truth; only a secondary
web-facing service is gated. A registration wall on one channel does not make a
code unobtainable when another channel is GPL-3.0 and open.

Keep the two questions separate when reading the rest of this file: **licensing
is settled, availability of a test case is not.** The remaining blocker below is
entirely the latter.

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

## What is missing, and the actual path (revised 2026-07-21)

**The repo ships no `.azr` file, and that turns out not to be the blocker it was
first written up as.** An earlier version of this file said Level 2 "has nothing
to reproduce" and made emailing R.J. deBoer for an example set the top action.
That framing was wrong, on a user observation: an R-matrix case is fully
specified by numbers that are already published, so the case is **constructed**
from the paper rather than **obtained** from the authors.

The AZURE2 paper itself (Azuma et al., PRC **81**, 045805 (2010)) devotes
Sec. IV to three worked examples and tabulates the complete fit parameters:

| Source | Content | Use |
|---|---|---|
| **Table V**, ¹⁶O(p,γ)¹⁷F | 5 levels, `Eλ`, `Ep`, `γp`, both `γγ(int)`; clean values with no uncertainty spread | **Best first case.** The paper calls this reaction completely dominated by external capture, so it is the simplest of the three |
| **Table I**, ¹²C+p | 4 levels plus the ground-state ANC `Cp1/2 = 1.87 fm^-1/2`, channel radius `ac = 3.4 fm` | Second case; also exercises elastic scattering (Figs. 4 and 5) |
| **Table IV**, ¹⁴N(p,γ)¹⁵O | Astrophysical S factors: 0.28 / 0.01 / 0.10 / 0.12 / 1.30, **total 1.81 keV b** | **Numeric anchor.** This is a table of results, not a figure, so it supports a digit comparison rather than a plot read |
| **Figs. 3, 4, 5, 15** | The published AZURE fits | Curve-level check |

A second fully specified case exists outside the paper, in deBoer's IAEA/TALENT
teaching material: ¹²C(n,n₀) through the ¹³C compound nucleus, with `mn = 1.0087`,
`Jπ(n) = 1/2+`, `Jπ(¹²C) = 0+`, `Sn = 4.946 MeV`, `ac = 1.4(A₁^⅓+A₂^⅓) = 4.6 fm`,
levels from the TUNL/NNDC compilations, and data from Auchampaugh et al. (1979)
via EXFOR. Every input is in a public database.

**So the verification architecture is the same one validated empirically on
pikoe**, and it does not require anything from the authors:

1. **Physics anchor**: reproduce Table IV's S factors and the published fit
   figures. Note this is *better* than pikoe's anchor, which was figure-only:
   Table IV supports comparing digits.
2. **Build integrity**: cross-platform, cross-compiler, cross-optimization
   reproduction. On pikoe this returned bit-identical output across ARM64/macOS
   gfortran 15.2 and x86_64/Linux gfortran 13.3 at `-O2`, `-O0` and
   `-finit-real=snan`, which is a stronger statement than any single reference
   file could make.

The residual risk is honest and worth stating: **hand-building an `.azr` from a
parameter table can encode a format mistake that produces a wrong but plausible
result.** The Table IV digit comparison is what catches that, which is exactly
why the numeric anchor matters more than the figures.

Emailing deBoer is therefore a nice-to-have, not a prerequisite, and is better
spent asking whether an official example set exists at all than asking him to
unblock us.

## Remaining work

- `SKILL.md`, `references/` (input format from the manual, failure modes,
  verification), `examples/`, `scripts/run_azure2.sh` with positive-assertion
  success checks, `scripts/verify_azure2.sh`.
- Codex adversarial pass, mandatory before shipping.
