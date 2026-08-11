<p align="center">
  <img src="assets/brand/fusion-github-logo.png" alt="FUSION" width="760">
</p>

# FUSION

**F**ramework for **U**nified **S**cientific **I**ntelligence in **O**pen **N**uclear physics

A coding agent that already knows how to drive the open-source codes nuclear
physicists actually use, and that carries the nucl-th literature with it.

Built on [opencode](https://github.com/anomalyco/opencode) (MIT), so it runs on
whatever model you can reach: DeepSeek, Qwen and GLM as readily as Claude or
GPT. Not affiliated with the opencode project.

**[vibeinscience.com](https://vibeinscience.com/)** has the illustrated tour:
architecture, benchmark numbers, worked case studies and a corpus citation map.

---

## What problem this solves

Running a nuclear-physics code for the first time is mostly not physics. It is
finding the source, getting it to compile on your machine, learning an input
format documented in a 300-page manual or not at all, and then not knowing
whether the number that came out is right.

A general coding agent is bad at this in a specific way: it will confidently
write you a FRESCO deck with the wrong radius convention, and the deck will
run, and the cross section will be wrong by 20% with nothing to warn you.

FUSION ships one expert skill per code. Each skill teaches the agent to install
that code from its own upstream source, write its inputs correctly, run it,
parse its output, recognise its failure modes, and check the result against a
benchmark with a stated tolerance.

## What is in it today

**22 skills.** 20 drive a specific code, one is a fitting companion, one
retrieves experimental data.

| Area | Codes covered |
|---|---|
| Reactions, optical model | FRESCO (+ SFRESCO fitting), COLOSS, CCFULL, pikoe, NLAT, CNOK, SIDES, SWANLOP |
| Structure, ab initio | GSM, KSHELL, NuclearToolkit.jl, Sky3D |
| Fission, statistical | CGMF, TALYS |
| Astrophysics, R-matrix | AZURE2, SkyNet |
| Heavy-ion, equation of state | SMASH, GiBUU, Thermal-FIST, vHLLE |
| Experimental data | EXFOR retrieval and parsing |

Each skill's own `SKILL.md` states what it covers and how it was verified.
Roadmap and the reasoning behind what is in and what is out:
[skills-catalog.md](skills-catalog.md).

**A knowledge base of 61,167 pages** under [`kb-wiki/`](kb-wiki/): one page per
paper in the arXiv nucl-th corpus (61,059 of them), 108 topic pages, plus
citation and semantic-relation layers connecting them. The agent reads it with
plain grep, offline, with no server and no API key. The pages are
machine-generated summaries and can be wrong; read
[kb-wiki/README.md](kb-wiki/README.md) before relying on one.

## How a skill is verified, and how much to trust it

Every skill is built from the code's public source and its own manual, then
made to reproduce something. Skills state their evidence honestly rather than
implying more:

- **Tier 1** (14 skills, including FRESCO, TALYS, CGMF, SMASH, SkyNet,
  Thermal-FIST): the distribution ships reference values and the skill
  reproduces them, in several cases byte for byte.
- **Tier 2** (6 skills, including AZURE2, KSHELL, GiBUU, vHLLE): the code
  ships no reference output, so the skill is pinned by cross-platform
  reproduction, physics invariants such as the optical theorem, or an
  independent analytic solution. vHLLE, for instance, is checked against the
  closed-form Gubser flow rather than against its own output.

Beyond that, most skills are built and verified on **two platforms**
(macOS/ARM and Linux/x86-64), and every skill goes through an adversarial
review pass by a second AI before it ships. That pass is not a formality: it
has caught skills that reported success while running a stale deck, harnesses
whose guards had never been shown to fire, and one that fabricated its own test
input. What each pass found is written down in each skill's
`references/verification.md`.

**What this does not mean.** A benchmark certifies that the build reproduces a
known result. It does not certify that your calculation is right. The physics
is still yours.

## Trying it

FUSION runs inside [opencode](https://github.com/anomalyco/opencode), so install
that first, then clone this repository and let the setup wizard ask you a few
questions:

```bash
git clone https://github.com/jinleiphys/FUSION.git      # ~229 MB, the knowledge base is most of it
cd FUSION
python3 scripts/fusion_init.py                          # add --dry-run to see it decide without writing
```

The wizard picks your model, wires the skills and the knowledge base into your
opencode config (merging, never clobbering, and it backs up what was there),
hands you to `opencode auth login` for your API key, and then seeds a private
space from your own papers: the topics your work actually carries, who you write
with, who cites you inside the corpus. That private space is created outside
this repository, so nothing personal can end up in a public clone.

Then ask for what you want in plain language: *"run a CDCC calculation for
d+58Ni at 21.6 MeV and compare the elastic angular distribution with the EXFOR
data"*. The skill handles the rest, including building FRESCO from source if it
is not already on your machine.

**Skills only, without the knowledge base.** If you do not want the clone, point
opencode at the skill index and it pulls and caches them itself:

```jsonc
// ~/.config/opencode/opencode.json
{ "skills": { "urls": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/"] } }
```

Skills are plain directories of Markdown and shell scripts, so they work with
any agent that can read a `SKILL.md` and run a command. Nothing is locked to
one vendor.

Requirements: `git`, `make`, a Fortran compiler (`gfortran`) and a C++
compiler. Individual skills pull their own extra dependencies and say so.

## Status, honestly

This is a working platform in daily use by its author, released early to find
out what other people need from it.

Known rough edges, all of them things you may hit:

- `fusion_init.py` sets you up, but there is no packaged installer and no
  FUSION binary: you run stock opencode with FUSION's skills and knowledge base.
- Cold-start installs are under-tested. Every skill's install path works on a
  machine that already has the code; only FRESCO's has been exercised from a
  genuinely empty cache. Expect the occasional missing dependency and please
  report it.
- TALYS wants about 11 GB of disk, 8.6 GB of it a structure database.
- Documentation is in English only so far.

## Contributing, and what would help most

Bug reports about a skill that misbehaves are the most useful thing right now,
especially cold-start install failures and any case where a skill produced a
plausible but wrong result. The second most useful thing is telling us which
code you wish had a skill.

If you want to add a skill, read
[CLAUDE.md](CLAUDE.md) first: it carries the rules a skill must satisfy,
including that the code be publicly obtainable, buildable from source on the
target platform, and backed by a published paper.

## Licence

MIT, see [LICENSE](LICENSE), which also explains the three things it cannot
cover: the physics codes themselves (you get those from their authors, under
their own terms, several of them GPL and one non-commercial), the opencode fork
in [fusion-core](https://github.com/jinleiphys/fusion-core), and the
third-party papers summarised in `kb-wiki/`.

## Author

Jin Lei (金磊), Tongji University. `jinl@tongji.edu.cn`
