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
  ·
  <a href="README.zh-CN.md">中文</a>
</p>

---

> ### This is a beta. It is being tested in the open.
>
> v0.1.0 is the first public build. It works, it is used daily by its author,
> and it has not been used by anyone else. **What breaks for you is the point.**
>
> **Three things you will probably hit**
>
> - **macOS blocks the first run.** The binary is not signed. Run
>   `xattr -d com.apple.quarantine fusion` and it will start.
> - **Do not begin with TALYS.** It downloads about 11 GB. Try FRESCO or CCFULL
>   first; they build in a minute or two.
> - **Cold-start installs are the least tested part.** Of the twenty codes, only
>   FRESCO has been installed from a genuinely empty cache. If a code fails to
>   build on your machine, that is the single most useful thing you can report.
>
> **What to report, in order of value**
>
> 1. **A result that looked right and was wrong.** The whole reason this project
>    exists is that a general agent writes a plausible FRESCO deck with the wrong
>    radius convention. If FUSION does something of that kind, we want the deck,
>    the number, and what it should have been. This is the failure we are most
>    afraid of and the one users are least likely to report.
> 2. **A code that will not install**, with the error and your OS and compiler.
> 3. **Anything that felt stupid.** Every awkward thing in the first-run flow was
>    found by one person trying it and saying so plainly. That works.
> 4. **Which code you wish had a skill.**
>
> [Open an issue](https://github.com/jinleiphys/FUSION/issues), or write to
> `jinl@tongji.edu.cn`. Chinese or English, whichever you prefer.


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
# 1. FUSION itself
git clone https://github.com/jinleiphys/FUSION.git && cd FUSION

# 2. the CLI, into the clone (pick your platform from the releases page)
curl -fsSL https://github.com/jinleiphys/FUSION/releases/latest/download/fusion-darwin-arm64.tar.gz | tar -xz
xattr -d com.apple.quarantine fusion          # macOS only, see below

# 3. work
./fusion
```

That is the whole thing: `./fusion` run inside the clone finds all 23 skills
and the knowledge base with no configuration at all.

To run it from anywhere instead of `./fusion`, move it onto your PATH:

```bash
mkdir -p ~/.local/bin && mv fusion ~/.local/bin/

# if `fusion` is then "command not found", ~/.local/bin is not on your PATH.
# macOS does not put it there by default:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```

Builds for macOS and Linux, x64 and arm64, are on the
[releases page](https://github.com/jinleiphys/FUSION/releases). They are not
signed or notarised, so macOS blocks the first run until you clear the
quarantine attribute as above. If you would rather not run an unsigned binary,
`fusion` is a rebranded [opencode](https://github.com/anomalyco/opencode) and
everything here works under a stock `opencode` install too.

**There is no configuration step.** Started from inside the clone, the agent
finds all 23 skills on its own. Ask it something and it will reach for the right
one.

**The first time you ask it anything, it offers to set itself up**, and never
asks again once you have. The offer arrives with your first message rather than
at the splash screen, and it does not hold up the thing you actually asked for. Accept and it walks you through your model, the areas you work in, the
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

Verified: on a machine with no clone, that pulls and caches all 23 skills.

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

- The macOS and Linux binaries are unsigned, so the first run needs the
  quarantine attribute cleared. Windows is not built.
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
