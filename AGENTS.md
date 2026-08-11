# FUSION

You are running inside a FUSION clone. All 23 skills in `skills/` are already
available to you: reaction, structure, fission, astrophysics and heavy-ion
codes, plus experimental-data retrieval. A knowledge base of 61,167 offline
literature pages sits in `kb-wiki/`, one page per arXiv nucl-th paper, readable
with plain grep, no network and no key.

## First run

**Before answering the user's first request in a session, check whether
`~/.fusion/.initialized` exists.**

If it does, say nothing about setup and get on with the work.

If it does not, this is a first run. Say so briefly, then offer setup before
anything else:

> This looks like your first time here. Want me to set FUSION up? It takes about
> a minute: your model, the areas you work in, and a private space built from
> your own papers showing who cites you and what to read. Or say skip and I will
> get straight to what you asked.

If they accept, invoke the `fusion-setup` skill. If they skip, do not ask again
in this session, and do not create the marker file: they may want it later.

Never let the offer block the actual request. If the user asked for something
concrete, do it after they answer either way.

## Language

The user may work in Chinese or English. Match whichever they use. A Chinese
README is at `README.zh-CN.md`; point Chinese-speaking users there rather than
translating the English one on the fly. Skill documentation itself is English,
so translate what you quote from it rather than making the user read it.

## Working here

- **Reach for the skill.** These codes have conventions that punish guesses. The
  standing example: FRESCO builds radii as `R = r0*(Ap^1/3 + At^1/3)` while KD02
  and CH89 are defined on `R = r0*At^1/3`, so a deck written from memory runs
  fine and returns a cross section around 20% wrong. Read the skill.
- **Never report a calculation as verified because it exited zero.** Several of
  these codes print a fatal error and exit 0 anyway; TALYS is the documented
  case. Check the output, not the status.
- **Say what was actually verified.** If a number reproduces a published value,
  say which and to how many figures. If it does not, say that instead of
  rounding the claim.
- The knowledge base pages are machine-generated summaries and can be wrong.
  Cite the paper, never the page.

## Maintaining FUSION itself

If you are here to change the platform rather than to use it, the development
rules, the hard constraints and the decision log are in `CLAUDE.md`. Read that
first; this file is for people using FUSION, not building it.
