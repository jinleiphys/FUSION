#!/usr/bin/env python3
"""Generate rules/fusion.md, FUSION's standing instructions for Antigravity.

Antigravity loads a plugin's rules/*.md as rules, and each must start with YAML
frontmatter naming a trigger; one without it is dropped silently. The content is
AGENTS.md (the single source, also what the Claude Code hook sends) minus the
maintainer section, which only concerns people developing FUSION.

    python3 scripts/build_rule.py           # write rules/fusion.md
    python3 scripts/build_rule.py --check   # exit 1 if it is stale
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "hooks"))
from session_start import sections  # noqa: E402

OUT = ROOT / "rules" / "fusion.md"
HEADER = """---
trigger: always_on
description: FUSION working rules (nuclear-physics skills): first-run setup offer, language, and how to use the skills and the knowledge base.
---
<!-- generated from AGENTS.md by scripts/build_rule.py; edit AGENTS.md, not this file -->

"""


def build() -> str:
    text = (ROOT / "AGENTS.md").read_text()
    keep = [h + b for h, b in sections(text) if not h.startswith("## Maintaining FUSION itself")]
    return HEADER + "".join(keep).strip() + "\n"


def main():
    want = build()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text() != want:
            sys.exit("rules/fusion.md is stale; run scripts/build_rule.py")
        print("rules/fusion.md is up to date")
        return
    if OUT.is_symlink():
        OUT.unlink()
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(want)
    print(f"wrote {OUT} ({len(want)} chars)")


if __name__ == "__main__":
    main()
