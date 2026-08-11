---
name: fusion-setup
description: Set up or reconfigure FUSION for this user: choose a model, pick research areas, wire the skills and the offline knowledge base into the agent's config, and seed a private layer from the user's own papers. Use when the user says 配置 FUSION, 初始化, set up FUSION, fusion init, configure fusion, 我第一次用, first time, 重新配置, or asks how to point this agent at the knowledge base. Also use when a skill fails to load and the cause may be configuration.
---

# Setting up FUSION

The setup is a script, `scripts/fusion_init.py`, and your job is to run it and
interpret what it says. **Do not reimplement it in conversation.** It writes
config files, merges rather than clobbers, backs up what was there, and refuses
to put personal notes inside the repository. Re-deriving that by hand in a chat
loses every one of those protections.

## Before you run anything

The user is already talking to you, so the agent and the skills are working.
That means setup is NOT required for the skills to function; it adds the model
default, the theme, the knowledge-base wiring, and the private layer. Say so, so
the user knows what they are getting rather than assuming it was mandatory.

Find the repository root: it is the directory containing `skills/`, `kb-wiki/`
and `scripts/fusion_init.py`. If you cannot find it, ask where FUSION was
cloned rather than guessing.

## Running it

The script is interactive: it asks about six questions and needs a real
terminal. You cannot answer for the user, and you must not try.

**Tell the user to run it themselves**, in their own terminal:

```bash
cd <fusion-repo>
python3 scripts/fusion_init.py
```

Offer `--dry-run` first if they want to see every write before it happens.

If your harness lets the user run a command inline (Claude Code's `!` prefix,
for example), suggest that. Otherwise plain instructions are correct. Running an
interactive prompt inside a tool call and answering it yourself would silently
pick their model, their research areas and their private-layer location for
them.

## What it does, in the order it asks

1. **The engine.** Checks for `fusion` first, then `opencode`. If neither is on
   PATH it says so and stops short of writing a broken config.
2. **Model.** Provider and model id, written into the config. It does NOT write
   the API key; keys go through `opencode auth login`, because that file's
   format belongs to the agent and a wizard writing secrets into someone else's
   schema breaks the first time upstream changes it.
3. **Research areas.** Ten areas built from the concept tags the corpus actually
   assigns, with live paper counts. Areas with no skill say so plainly.
4. **Skills.** Recommends by area, and reports that every skill in the clone
   loads regardless.
5. **Theme.** Optional. Installs the FUSION palette into `<config>/themes/`.
6. **Private layer.** Optional, and the interesting one. Give it the arXiv ids
   of the user's own papers and it builds a starting profile: the concepts their
   work carries, their co-authors, and who cites them inside the corpus. It
   refuses to write this inside the repository.

It finishes by asking the agent what it can now see and reporting any skill that
did not load, separating "shadowed by a same-named skill elsewhere" from "did
not load at all, cause unknown". Read that back to the user; it is the only part
that can reveal a broken install.

## Reading the result

- `Every skill in this clone loaded.` Setup worked.
- `N skill(s) came from somewhere else instead of this clone.` The user has
  another skill by the same name, and the agent silently preferred it. Tell them
  which, and that renaming or removing the other copy is the fix.
- `N skill(s) in this clone did not load at all.` Something is wrong with those
  skills. Worth reporting as a bug, with the names.
- `Could not read the skill list back.` The self-check failed, not necessarily
  setup. Suggest `opencode debug skill`.

## Reconfiguring later

Rerunning is safe and idempotent: the skills path is appended only if absent,
and the config is merged. The private layer is regenerated, so tell the user to
copy anything they hand-edited out of `profile.md` first, or to point the rerun
at a different directory.

## What NOT to do

- Do not write `auth.json` or any API key, by any route.
- Do not create the private layer inside the FUSION repository, and do not
  suggest a path there. It gets published.
- Do not claim setup succeeded because the script exited zero. Read its
  final report.
- Do not edit the user's `opencode.json` by hand to "fix" something the script
  would have done. If the script is wrong, that is a bug worth reporting.
