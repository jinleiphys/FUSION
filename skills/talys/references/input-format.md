# TALYS input format

Everything here is taken from the shipped tutorial, `talys/doc/talys.pdf`
(TALYS-2.22, IAEA NDS Document Series IAEA(NDS)-0255, January 2026), Chapter 3
"Input description" and the Part III keyword reference. Section numbers below
point back into that document. Do not extend this file from memory; the manual
is 890 pages and is the authority.

## How TALYS is invoked

```
talys < talys.inp > talys.out
```

The deck is read from stdin, the main report goes to stdout, and several hundred
data files are written into the current working directory. There is no
command-line option to name the input file.

## The seven basic rules (manual Sec. 3.1, verbatim in substance)

1. One input line contains one keyword. Some model-parameter keywords also take
   indices (usually Z and A) on the same line.
2. A keyword and its value must be separated by at least one blank.
3. Keywords may be given in any order. If the same keyword appears twice, the
   **last** occurrence wins (except for keywords indexed by different Z and A).
4. Case does not matter, upper or lower.
5. A keyword must have a value. To get a default, omit the keyword entirely
   rather than giving it an empty value.
6. A line with `#` in column 1 is ignored, which is how you comment or disable
   a keyword.
7. **A minimal input file is four lines**: `projectile`, `element`, `mass`,
   `energy`. These four are mandatory in every deck.

So this is a complete, valid TALYS calculation:

```
projectile n
element al
mass 27
energy 14.
```

TALYS validates keywords and stops with a message on the first problem: a
misspelling like `projjectile n` is reported as not being in the keyword list.

## The `energy` keyword has four forms (manual, keyword reference, p.305)

This one matters more than the rest because two of its forms depend on a file
existing next to the deck.

| form | example | meaning |
|---|---|---|
| single value | `energy 14.` | one incident energy in MeV |
| **your own file** | `energy energies` | **a file in the working directory**, one incident energy per line. Any name is allowed provided it starts with a letter |
| predefined grid | `energy n0-200.grid` | a grid hardwired into TALYS, named `pE1-E2.grid` (projectile, start, end). `n0-200.grid` is the TENDL neutron grid |
| range | `energy 0.5 20. 0.5` | start, end, step; equidistant grid |

The second form is why several distributed sample cases ship an extra file
called `energies` beside `talys.inp`. Copying only `talys.inp` out of such a
sample makes TALYS abort with

```
TALYS-error: give a single incident energy in the input file using the energy keyword
             or specify a range of incident energies in a file
             or give a correct name for a pre-defined energy grid energies
```

The file form is also **mandatory** when `projectile 0`, that is, when you start
from a populated excited nucleus instead of a reaction.

## Commonly used output keywords

From the sample decks; all are `y`/`n` flags unless noted.

| keyword | effect |
|---|---|
| `outbasic y` | basic output blocks (the usual starting point) |
| `outpreequilibrium y` | pre-equilibrium details |
| `outspectra y` | emission spectra |
| `outangle y` | angular distributions |
| `outlegendre y` | Legendre coefficients |
| `outgamdis y` | gamma-ray discrete-level population |
| `ddxmode 2` | double-differential cross section mode |
| `partable y` | table of all model parameters actually used |
| `filepsf y` | write photon strength functions to file |

A representative full deck (this is `examples/n-Nb093-14MeV-full.inp`, the
distributed sample that the verification record reproduces):

```
projectile n
element nb
mass 93
energy 14.
outbasic            y
outpreequilibrium   y
outspectra          y
outangle            y
outlegendre         y
ddxmode             2
outgamdis           y
filepsf             y
partable            y
```

## Physics-model keywords worth knowing

TALYS's whole point is that the model choice is a keyword, so a sensitivity
study is a loop over decks. The distributed samples are organised around exactly
this, and their names tell you what is varied:

| sample family | what it varies |
|---|---|
| `n-Sn120-omp-KD03`, `-KD03disp`, `-KD03global`, `-JLM` | optical model: Koning-Delaroche local, dispersive, global, and JLM microscopic |
| `n-Nb093-WFC-HF`, `-Moldauer`, `-HRTW`, `-GOE` | width-fluctuation correction model |
| `n-Tc099-ld1`, `-ld2`, `-ld5` | level-density model |
| `a-Ho165-omp1`, `-omp2`, `-omp5`, `-omp6` | alpha optical model |
| `n-Th232-fis-wkb`, `n-Pu239-fy-gef`, `-hf3d` | fission barrier and fission-yield model |
| `n-Os187-astro-ng`, `-astro-rate` | astrophysical reaction rates (`astro y`) |

For `astro y` the manual notes that `energy` must still be given but its value is
irrelevant, because an internal energy grid is used.

## Output files

`talys.out` is the human-readable report. The data files follow a naming scheme:

| pattern | contents |
|---|---|
| `cross_n.tot`, `cross_p.tot`, ... | inverse reaction cross sections per ejectile |
| `nn.L08`, `ng.L00`, ... | exclusive channel cross sections by residual level |
| `nspec0014.000.tot`, `aspec...` | emission spectra at a given incident energy |
| `populationE0014.000.out` | population of the compound system |
| `binE0014.000.out` | binary reaction details |
| `parameters.dat` | every model parameter actually used (with `partable y`) |
| `astrorate.*` | astrophysical rates (with `astro y`) |

All of them carry a YANDF-0.4 style header block:

```
# header:
#   title: Nb93 neutron  inverse reaction cross sections
#   source: TALYS-2.2
#   user: Arjan Koning
#   date: 2026-07-20
#   format: YANDF-0.4
```

The `user:` field comes from `path_change.bash` at install time and the `date:`
field from the run, which is why any comparison against a reference must ignore
those two lines.

## Sample cases as documentation

`talys/samples/` holds 62 cases, each with `new/` (the input) and `org/` (the
authors' reference output). They are the practical keyword reference: find the
sample nearest your problem, copy its `new/` directory, and edit. The upstream
harness `talys/samples/verify` runs all of them and takes about an hour;
`scripts/verify_talys.sh` in this skill runs one, in a clean directory.
