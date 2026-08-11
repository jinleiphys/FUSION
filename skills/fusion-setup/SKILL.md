---
name: fusion-setup
description: Set up or reconfigure FUSION for this user: choose a model, pick research areas, wire the skills and the offline knowledge base into the agent's config, and seed a private layer from the user's own papers. Use when the user says 配置 FUSION, 初始化, 帮我配置, set up FUSION, fusion init, configure fusion, 我第一次用, first time, 重新配置, or accepts the first-run setup offer. Also use when a skill fails to load and the cause may be configuration.
---

# Setting up FUSION

**You run the setup. Do not send the user away to run a script.**

They are already talking to you, in a terminal, and you can run commands. Telling
them to open another terminal, run an interactive script and paste the output
back is a bad answer to a question they just asked you. Ask the questions here,
in conversation, which is the thing conversation is actually good at, then apply
the answers in one command.

The rule this replaces was "never answer the setup prompts on the user's
behalf". That rule is still right. It is enforced by asking them, not by making
a human type their answers into a second program.

## Ask these, in the user's language

Keep it to one short message, not five round trips. Offer sensible defaults and
let them answer in any form; you interpret. If they say "随便" or "you pick",
take the defaults and say which you took.

1. **Model.** Which provider. `deepseek/deepseek-chat` is the cheap default and
   the one most users here want; `alibaba/qwen-max`, `zhipuai/glm-4.6`,
   `anthropic/claude-sonnet-5`, `openai/gpt-5.4` also work. If they already have
   a model configured and are happy with it, skip this and pass nothing.
2. **Research areas.** Run `python3 scripts/fusion_init.py --list-areas` to get
   the ids with live paper counts, and present them in the user's language.
   Multiple are fine.
3. **Theme.** One yes or no question: the FUSION colour theme in the terminal.
4. **Private layer.** Explain what it is in one sentence, that it is built from
   their own arXiv ids, and that it lives outside the repository. Ask for the
   ids. Blank is a fine answer and means skip it.

## Then run it, once

```bash
python3 scripts/fusion_init.py --apply \
  --model <provider/model> \
  --areas <id,id> \
  --theme \
  --private-dir ~/.fusion \
  --papers "<arxiv ids>"
```

Omit any flag the user did not choose. Omit `--private-dir` entirely to skip the
private layer. Add `--dry-run` first if the user wants to see what it would
write.

It prints `SETUP OK` with the config path, the skill count, and whether
autoupdate was disabled. Report that back in plain words. If it exits non-zero,
show the user what it said; do not paper over it.

## The one thing you must hand back

**The API key.** After the run, tell the user to run `opencode auth login`
themselves, or `fusion auth login` if that is the binary they have. Do not offer
to take the key and store it for them, and do not ask them to paste it into the
chat: a key in a transcript is a leaked key. This is the only step that goes
back to them, and say why, because being sent away for no reason is what makes a
tool feel stupid.

## Check it worked

Run `opencode debug skill` (or `fusion debug skill`) and count how many skills
came from this repository's `skills/` directory. There are 23. If some are
missing, they were either shadowed by a same-named skill elsewhere, in which
case say which and where the winning one lives, or they failed to load, in which
case say so and that the cause is not visible from here. Do not report success
because a command exited zero.

## Reconfiguring later

Rerunning is safe: the config is merged, the skills path is appended only if
absent, and the existing config is backed up first. The private layer is
regenerated, so if they hand-edited `profile.md`, tell them to copy it aside or
point the rerun at a different directory.

## What NOT to do

- Do not write `auth.json` or any API key, by any route.
- Do not create the private layer inside the FUSION repository. The script
  refuses, but do not propose it either: this repository is public.
- Do not invent the user's answers. If they have not said, ask, or take a stated
  default and tell them which one you took.
- Do not claim setup succeeded because the exit code was zero. Read the report.
