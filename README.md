<p align="center">
  <img src="assets/brand/fusion-github-logo.png" alt="FUSION" width="760">
</p>

<p align="center">
  <b>F</b>ramework for <b>U</b>nified <b>S</b>cientific <b>I</b>ntelligence in <b>O</b>pen <b>N</b>uclear physics
  <br>
  <code>FU ▸◂ SION</code>
  <br><br>
  <a href="https://vibeinscience.com/">vibeinscience.com</a>
  ·
  <a href="LICENSE">MIT</a>
  ·
  23 skills
  ·
  61,167 offline literature pages
</p>

---

An agent that already knows how to drive the open-source codes nuclear
physicists actually use, and that carries the nucl-th literature with it,
offline.

Running a nuclear-physics code for the first time is mostly not physics. It is
finding the source, getting it to compile, learning an input format documented
in a 300-page manual or not at all, and then not knowing whether the number that
came out is right.

A general-purpose coding agent fails at this in a specific and dangerous way.
Ask one for a FRESCO deck and it will hand you a plausible file with the wrong
radius convention. The deck runs. The cross section is 20% wrong. Nothing warns
you.

FUSION ships one expert skill per code. Each teaches an agent to install that
code from its own upstream source, write its inputs correctly, run it, parse the
output, recognise its failure modes, and check the answer against a benchmark
with a stated tolerance.

## Quickstart

```bash
# 1. an agent to run it in
curl -fsSL https://opencode.ai/install | bash

# 2. FUSION
git clone https://github.com/jinleiphys/FUSION.git && cd FUSION

# 3. work
opencode
```

**There is no configuration step.** Started from inside the clone, the agent
finds all 23 skills on its own. Ask it something and it will reach for the right
one.

**On the first run it offers to set itself up**, and never asks again once you
have. Accept and it walks you through your model, the areas you work in, the
colour theme, and a private space seeded from your own papers: the topics your
work carries, who you write with, who cites you inside the corpus. Decline and
it gets straight to what you asked. That private space is created outside this
repository, so nothing personal can reach a public clone.

You can also run it whenever you like by saying *set up fusion*, or directly:

```bash
python3 scripts/fusion_init.py        # --dry-run to watch it decide without writing
```

Then ask for what you want, in words:

> run a CDCC calculation for d+58Ni at 21.6 MeV and compare the elastic angular
> distribution with whatever EXFOR data exists

It handles the rest, building FRESCO from source if your machine lacks it.

The clone is about 229 MB, nearly all of it the knowledge base. If you want the
skills without it, skip the clone and point your agent at the index instead:

```jsonc
// ~/.config/opencode/opencode.json
{ "skills": { "urls": ["https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/"] } }
```

Requirements: `git`, `make`, `gfortran`, a C++ compiler, `python3`. Individual
skills pull their own extra dependencies and say so before they do.

## What is in it

**23 skills.** Twenty drive a specific code, one is a fitting companion, one
retrieves experimental data, one sets FUSION up.

| Area | Codes |
|---|---|
| Reactions, optical model | FRESCO (+ SFRESCO fitting), COLOSS, CCFULL, pikoe, NLAT, CNOK, SIDES, SWANLOP |
| Structure, ab initio | GSM, KSHELL, NuclearToolkit.jl, Sky3D |
| Fission, statistical | CGMF, TALYS |
| Astrophysics, R-matrix | AZURE2, SkyNet |
| Heavy-ion, equation of state | SMASH, GiBUU, Thermal-FIST, vHLLE |
| Experimental data | EXFOR retrieval and parsing |

Each skill's `SKILL.md` states what it covers and how it was verified. What is
in, what was dropped, and why: [skills-catalog.md](skills-catalog.md).

**61,167 pages of literature**, offline, in [`kb-wiki/`](kb-wiki/): one page per
paper for 61,059 arXiv nucl-th papers, 108 topic pages, and citation and
semantic-relation layers connecting them. The agent reads it with plain grep. No
server, no API key, no network.

Those pages are machine-generated summaries and they can be wrong. Read
[kb-wiki/README.md](kb-wiki/README.md) before relying on one, and cite the
paper, never the page.

## It is not tied to one agent

Skills are directories of Markdown and shell scripts. Each ships both entry
files, so all three common agents can load them.

| Agent | Entry | Install | Verification status |
|---|---|---|---|
| opencode | `SKILL.md` | none, auto-found in the clone | **verified**, all 23 load with zero config |
| Claude Code | `SKILL.md` | `ln -s "$PWD"/skills/* ~/.claude/skills/` | **verified**, byte-identical to skills it already loads |
| Codex | `AGENTS.md` | `ln -s "$PWD"/skills/* ~/.codex/skills/` | format only, **not** tested end to end |

The Codex entry files are generated pointers rather than hand-written condensed
mirrors. Each names its skill, says when it applies, and tells Codex to read
`SKILL.md` with its file-read tool, which it must, because Codex does not inline
markdown imports. Functional, weaker than a mirror, and labelled as such at the
top of every one.

## How far to trust a skill

Every skill is built from the code's public source and its own manual, then made
to reproduce something. The evidence is stated rather than implied:

- **Tier 1** (14 skills, including FRESCO, TALYS, CGMF, SMASH, SkyNet,
  Thermal-FIST): the distribution ships reference values and the skill
  reproduces them, several byte for byte.
- **Tier 2** (6 skills, including AZURE2, KSHELL, GiBUU, vHLLE): the code ships
  no reference output, so the skill is pinned by cross-platform reproduction,
  physics invariants such as the optical theorem, or an independent analytic
  solution. vHLLE is checked against closed-form Gubser flow rather than against
  its own output.

Most skills are built and verified on **two platforms**, macOS/ARM and
Linux/x86-64, and every one goes through an adversarial review pass by a second
AI before shipping. That pass is not ceremony. It has caught skills that
reported success while running a stale deck, harnesses whose guards had never
been shown to fire, and a test that fabricated its own input. What each pass
found is written down in each skill's `references/verification.md`.

**A benchmark certifies that a build reproduces a known result. It does not
certify that your calculation is right.** The physics is still yours.

## Status

A working platform, in daily use by its author, released early to find out what
other people need from it. Things you may hit:

- No packaged installer and no FUSION binary. You run a stock agent with
  FUSION's skills and knowledge base. A branded CLI build exists in
  [fusion-core](https://github.com/jinleiphys/fusion-core) but has not been
  released.
- **Cold-start installs are under-tested.** Every skill's install path works on
  a machine that already has the code; only FRESCO's has been exercised from a
  genuinely empty cache. Expect a missing dependency somewhere.
- TALYS wants about 11 GB of disk, 8.6 GB of it a structure database.
- Documentation is English only.

## Contributing

The most useful thing right now is a bug report about a skill that misbehaved,
especially a cold-start install failure, or any case where a skill produced a
**plausible but wrong** result. The second most useful is telling us which code
you wish had a skill.

To add one, read [CLAUDE.md](CLAUDE.md) first. A code qualifies only if it is
publicly obtainable, builds from source on the target platform, and has a
published paper, and a skill ships only with an honest benchmark tier.

## Licence and identity

MIT, see [LICENSE](LICENSE), which also names the three things it cannot cover:
the physics codes themselves (you get those from their authors under their own
terms, several GPL and one non-commercial), the opencode fork in
[fusion-core](https://github.com/jinleiphys/fusion-core), and the third-party
papers summarised in `kb-wiki/`.

Built on [opencode](https://github.com/anomalyco/opencode) (MIT), so it runs on
whatever model you can reach, DeepSeek and Qwen and GLM as readily as Claude or
GPT. Not affiliated with the opencode project.

Palette, mark, and where each applies: [BRAND.md](BRAND.md).

## Author

Jin Lei (金磊), Tongji University. `jinl@tongji.edu.cn`
