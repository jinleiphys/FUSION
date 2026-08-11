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

## Ask ONE question at a time

**Never present the whole thing at once.** A four-part questionnaire with ten
numbered options is a form, and nobody wants to fill in a form. Ask one short
question, wait for the answer, ask the next. Four exchanges of one line each
feel faster than one wall of text, even though they take longer.

Say how many there are at the start so it does not feel open-ended. "四个问题"
is enough; do not add 我会逐一为您确认 or any other padding.

**Never paste the area list.** Do not dump ten ids and paper counts on someone.
Ask what they work on in their own words. A nuclear physicist will say "我做核
反应,主要是破裂" or "shell model mostly", and mapping that to an area id is your
job, not theirs. Say which one you matched, and move on. Only show the list if
they ask for it or genuinely cannot say, and even then show four or five likely
ones, not all ten. `python3 scripts/fusion_init.py --list-areas` gives the ids
with live paper counts when you need them.

### Step 1, model

**Do not read their config to find out what they are using.** It lives outside
the project directory, so reading it triggers a permission prompt, and a
permission prompt as the first thing that happens after someone asks for help
setting up is a bad first move. Measured: in non-interactive mode the read is
auto-rejected outright and the skill stalls.

Just ask, and offer the default: 「模型用 deepseek/deepseek-chat?便宜,够用。」
If they say 不变 or 就用现在这个, pass no `--model` flag at all and their
existing setting survives untouched, which is the same outcome as reading the
file would have given you.

`alibaba/qwen-max`, `zhipuai/glm-4.6`, `anthropic/claude-sonnet-5` and
`openai/gpt-5.4` also work. Do not list them unless asked.

### Step 2, what they work on

Free text, then map it yourself. Multiple areas are fine. If they say something
outside the ten, say so plainly rather than forcing it into the nearest box, and
tell them which skills exist for it if any do.

### Step 3, theme

One yes or no. "配色换成 FUSION 的?" Default yes.

### Step 4, their own papers

Explain in one sentence what it buys them: a private page showing the topics
their work carries, their co-authors, and who cites them inside the corpus.
Ask for arXiv ids. Blank is a perfectly good answer and skips it. Say that it
lives outside the repository, because people are right to be careful about
where their own work gets written.

If at any point they say 随便 or "you pick", take the defaults, tell them what
you took, and stop asking.

### How to word it

Talk like a colleague, not like an assistant. In Chinese: no 首先/其次/另外/
值得注意的是, no three-part parallel phrases, no summarising close, no
「让我们」. Do not open a question with 看起来 or 关于这个问题. Do not sell the
step ("只需一分钟", "非常简单"). Ask, then stop.

Wrong: 「关于模型的选择,我建议您可以考虑使用 DeepSeek,它在性价比方面表现优异。」
Right: 「模型用 deepseek/deepseek-chat?便宜,够用。」

Same in English: ask the question, drop the cushioning.

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

One command at the end, not one per answer. The questions are a conversation;
the writing is a single step.

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
