#!/usr/bin/env python3
"""SessionStart hook: hand FUSION's user-facing instructions to the agent.

In a clone, agents read AGENTS.md from the working directory. Installed as a
plugin they never see it, so this hook reads the same file (the single source)
and passes it on as session context, minus two sections:

- "Maintaining FUSION itself", which is for developers of the platform;
- "First run", once setup has been done on this machine (~/.fusion/.initialized,
  written by scripts/fusion_init.py). Checking the file here costs nothing,
  where asking the model to check it would cost a tool call every session.

Prints nothing and exits 0 on any problem: a broken hook must never block a
session.
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sections(text):
    """Split markdown into (heading, body) at '## ' headings; heading '' is the preamble."""
    parts = re.split(r"(?m)^(## .*)$", text)
    out = [("", parts[0])]
    for i in range(1, len(parts), 2):
        out.append((parts[i], parts[i + 1]))
    return out


def main():
    try:
        text = (ROOT / "AGENTS.md").read_text()
    except OSError:
        return
    configured = (Path.home() / ".fusion" / ".initialized").exists()
    keep = []
    for head, body in sections(text):
        if head.startswith("## Maintaining FUSION itself"):
            continue
        if head.startswith("## First run") and configured:
            continue
        keep.append(head + body)
    context = "".join(keep).strip()
    out = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}}
    sys.stdout.write(json.dumps(out))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
