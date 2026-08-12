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

**Never present the whole thing at once.** A questionnaire with ten numbered
options is a form, and nobody wants to fill in a form. Ask one short question,
wait for the answer, ask the next. Two exchanges of one line each feel faster
than one wall of text, even though they take longer.

There are only two questions, because everything else is either opencode's job
or reversible with one command. Keep it that way: a setup that grows questions
is a setup nobody finishes.

Say how many there are at the start so it does not feel open-ended. "两个问题"
is enough; do not add 我会逐一为您确认 or any other padding.

**Never paste the area list.** Do not dump ten ids and paper counts on someone.
Ask what they work on in their own words. A nuclear physicist will say "我做核
反应,主要是破裂" or "shell model mostly", and mapping that to an area id is your
job, not theirs. Say which one you matched, and move on. Only show the list if
they ask for it or genuinely cannot say, and even then show four or five likely
ones, not all ten. `python3 scripts/fusion_init.py --list-areas` gives the ids
with live paper counts when you need them.

### Not our business: the model and the API key

**Do not ask about either.** If the user is talking to you, a model is already
running and its key is already stored, both handled by opencode before FUSION
is involved. Asking again re-opens a solved problem and makes the setup look
longer than it is.

Switching models is `/model` in the TUI, and changing provider is
`opencode auth login`. Say so only if the user brings it up. The
`--model` flag on the script exists for scripted installs; leave it off and
their setting stays untouched.

### Question 1, what they work on

Free text, then map it yourself. Multiple areas are fine. If they say something
outside the ten, say so plainly rather than forcing it into the nearest box, and
tell them which skills exist for it if any do.

### Not a question either: the colours

Install the theme, do not ask. Changing it back is `/theme`, one command the
user already has, so asking permission spends one of your two questions on a
decision that costs nothing to reverse. Mention it in one clause when you
report what you did: 「配色换成 FUSION 的了,不喜欢 /theme 换回去。」

### Question 2, their own papers

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

### If there is nobody to answer

You may be running non-interactively, where your reply goes nowhere and no
answer will ever come back. **Then do not run the setup at all.** Say that
setup needs an interactive session and stop.

Measured, because this went wrong: in `run` mode the agent asked its questions
into the void and then invoked `--apply` anyway, choosing a research area and a
paper on the user's behalf and writing a config, a theme and a private profile
they had never agreed to. Asking and then answering for them is worse than not
asking, because it looks like consent.

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

## Check it worked

Run `opencode debug skill` (or `fusion debug skill`) and count how many skills
came from this repository's `skills/` directory. There are 26. If some are
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

- Do not write `auth.json` or any API key, by any route, and do not ask the
  user to paste a key into the chat. A key in a transcript is a leaked key.
- Do not create the private layer inside the FUSION repository. The script
  refuses, but do not propose it either: this repository is public.
- Do not invent the user's answers. If they have not said, ask, or take a stated
  default and tell them which one you took.
- Do not claim setup succeeded because the exit code was zero. Read the report.
