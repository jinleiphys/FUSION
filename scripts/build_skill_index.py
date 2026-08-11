#!/usr/bin/env python3
"""Generate skills/index.json, the manifest opencode pulls skills from.

opencode's skill discovery (packages/opencode/src/skill/index.ts) accepts a URL
in `skills.urls`. It fetches `<url>/index.json`, expects

    {"skills": [{"name": ..., "files": [...], "version": ...}, ...]}

and downloads each listed file from `<url>/<name>/<file>` into
`~/.cache/opencode/skills/<name>/`, writing `version` to `.opencode-version`
so a later run can tell whether its cached copy is current. A skill entry with
no SKILL.md in `files` is skipped by opencode with a warning, so this script
refuses to emit one.

Host it straight from the repository, no copying:

    https://raw.githubusercontent.com/jinleiphys/FUSION/main/skills/

Usage:
    python3 scripts/build_skill_index.py            # write skills/index.json
    python3 scripts/build_skill_index.py --check    # verify it is up to date (CI)
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SKILLS = REPO / "skills"
INDEX = SKILLS / "index.json"

# Anything a skill needs at runtime travels; build leftovers and local caches do
# not. Kept as an exclusion list rather than an inclusion list because a new
# reference or example file must ship by default: forgetting to add it to an
# allowlist would silently deliver a broken skill.
EXCLUDE_DIRS = {".git", "__pycache__", ".pytest_cache", "node_modules", ".cache"}
EXCLUDE_SUFFIXES = {".pyc", ".pyo", ".o", ".mod", ".so", ".dylib", ".a"}
EXCLUDE_NAMES = {".DS_Store", "index.json"}


def skill_files(skill_dir: Path) -> list[str]:
    """Every shippable file in a skill, as paths relative to the skill root."""
    out = []
    for p in sorted(skill_dir.rglob("*")):
        if not p.is_file():
            continue
        if any(part in EXCLUDE_DIRS for part in p.relative_to(skill_dir).parts):
            continue
        if p.suffix in EXCLUDE_SUFFIXES or p.name in EXCLUDE_NAMES:
            continue
        if p.name.startswith(".") and p.name != ".gitignore":
            continue
        out.append(p.relative_to(skill_dir).as_posix())
    return out


def skill_version(skill_dir: Path) -> str:
    """The commit that last touched this skill.

    Content-derived rather than hand-maintained, so a version can never claim a
    skill is unchanged when it is not. Falls back to "0-uncommitted" outside a
    git checkout or for a skill with no commits yet, which is honest: opencode
    then re-pulls rather than trusting a stale cache.
    """
    try:
        sha = subprocess.run(
            ["git", "-C", str(REPO), "log", "-1", "--format=%H", "--", str(skill_dir)],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "0-uncommitted"
    return sha[:12] if sha else "0-uncommitted"


def build() -> dict:
    if not SKILLS.is_dir():
        sys.exit(f"no skills directory at {SKILLS}")

    skills = []
    for d in sorted(p for p in SKILLS.iterdir() if p.is_dir()):
        files = skill_files(d)
        if "SKILL.md" not in files:
            print(f"  skip {d.name}: no SKILL.md", file=sys.stderr)
            continue
        skills.append({"name": d.name, "version": skill_version(d), "files": files})

    if not skills:
        sys.exit("refusing to write an empty index")
    return {"skills": skills}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the committed index differs from a fresh build")
    args = ap.parse_args()

    index = build()
    text = json.dumps(index, indent=2, ensure_ascii=False) + "\n"

    if args.check:
        if not INDEX.exists():
            sys.exit("skills/index.json is missing; run this script without --check")
        if INDEX.read_text() != text:
            sys.exit("skills/index.json is stale; run scripts/build_skill_index.py")
        print("skills/index.json is up to date")
        return

    INDEX.write_text(text)
    total = sum(len(s["files"]) for s in index["skills"])
    print(f"wrote {INDEX.relative_to(REPO)}: {len(index['skills'])} skills, {total} files")


if __name__ == "__main__":
    main()
