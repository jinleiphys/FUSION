#!/usr/bin/env python3
"""fusion init: set up FUSION for one person, by asking.

Run it after cloning the repository:

    python3 scripts/fusion_init.py

It asks a short series of questions and then does four things:

  1. writes an opencode config that points at this repository's skills and
     knowledge base, merging into whatever config you already have;
  2. recommends the skills that match the research areas you pick;
  3. seeds a PRIVATE layer, outside this repository, from your own papers:
     the topics you actually work on, who you write with, who cites you, and
     what your citation neighbourhood suggests you should read;
  4. tells you what it did and what to try first.

Two things it deliberately does NOT do:

  - It never writes your API key. Keys live in opencode's own auth.json and
    that file's format belongs to opencode, not to us; a wizard that writes
    secrets into someone else's schema is one upstream change away from
    silently producing an unusable file, and one bug away from clobbering the
    credentials of every other provider you use. It runs `opencode auth login`
    for you instead, which is the supported path.
  - It never writes your private layer inside this repository. Personal notes
    are yours and must not end up in a public clone.

Stdlib only, no install step. `--dry-run` prints every write without making it.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MAP_FILE = REPO / "data" / "concept-skill-map.json"
CLASSIFICATION = REPO / "kb-wiki" / "classification.json"
PAPERS = REPO / "kb-wiki" / "papers"
CITATIONS = REPO / "kb-wiki" / "citations.tsv"

PROVIDERS = [
    ("deepseek", "DeepSeek", "deepseek/deepseek-chat"),
    ("alibaba", "Qwen (Alibaba)", "alibaba/qwen-max"),
    ("zhipuai", "GLM (Zhipu)", "zhipuai/glm-4.6"),
    ("anthropic", "Claude (Anthropic)", "anthropic/claude-sonnet-5"),
    ("openai", "GPT (OpenAI)", "openai/gpt-5.4"),
]

DRY_RUN = False


# ---------------------------------------------------------------- io helpers

def say(msg=""):
    print(msg)


def head(title):
    print(f"\n\033[1m{title}\033[0m\n" + "-" * max(28, len(title)))


def ask(prompt, default=None):
    suffix = f" [{default}]" if default else ""
    try:
        got = input(f"{prompt}{suffix}: ").strip()
    except (EOFError, KeyboardInterrupt):
        say("\naborted, nothing was written")
        sys.exit(1)
    return got or (default or "")


def ask_yes(prompt, default=True):
    d = "Y/n" if default else "y/N"
    got = ask(f"{prompt} ({d})").lower()
    if not got:
        return default
    return got.startswith("y")


def ask_multi(prompt, options, default_none_ok=True):
    """options: list of (key, label). Returns the chosen keys."""
    for i, (_, label) in enumerate(options, 1):
        say(f"  {i:2d}. {label}")
    while True:
        raw = ask(f"{prompt} (numbers separated by spaces or commas, blank for none)")
        if not raw:
            if default_none_ok:
                return []
            say("  pick at least one")
            continue
        picks, bad = [], []
        for tok in raw.replace(",", " ").split():
            if tok.isdigit() and 1 <= int(tok) <= len(options):
                picks.append(options[int(tok) - 1][0])
            else:
                bad.append(tok)
        if bad:
            say(f"  not a valid choice: {' '.join(bad)}")
            continue
        return list(dict.fromkeys(picks))


def write_file(path: Path, text: str):
    if DRY_RUN:
        say(f"  [dry-run] would write {path} ({len(text)} bytes)")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    say(f"  wrote {path}")


# ------------------------------------------------------------------ opencode

def find_opencode():
    return shutil.which("opencode") or shutil.which("fusion")


def config_dir() -> Path:
    """Where opencode keeps its config, honouring its own override."""
    if os.environ.get("OPENCODE_CONFIG_DIR"):
        return Path(os.environ["OPENCODE_CONFIG_DIR"])
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg) if xdg else Path.home() / ".config"
    return base / "opencode"


def load_config(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        say(f"\n  {path} exists but is not valid JSON ({e}).")
        say("  Refusing to overwrite a file I cannot parse; fix or move it, then rerun.")
        sys.exit(1)


def merge_config(existing: dict, skills_dir: Path, model: str) -> dict:
    """Add what FUSION needs, keep everything the user already had.

    Merged rather than replaced, and the skills path is appended only if absent,
    so rerunning the wizard is idempotent and someone else's settings survive.
    """
    cfg = json.loads(json.dumps(existing))  # deep copy
    if model:
        cfg["model"] = model
    skills = cfg.setdefault("skills", {})
    paths = skills.setdefault("paths", [])
    entry = str(skills_dir)
    if entry not in paths:
        paths.append(entry)
    return cfg


# ------------------------------------------------------------ knowledge base

def load_areas():
    m = json.loads(MAP_FILE.read_text())
    counts = {}
    if CLASSIFICATION.exists():
        cls = json.loads(CLASSIFICATION.read_text())
        for area in m["areas"]:
            want = set(area["concepts"])
            counts[area["id"]] = sum(
                1 for tags in cls.values() if any(t["slug"] in want for t in tags)
            )
    return m, counts


def read_frontmatter(path: Path) -> dict:
    """Minimal frontmatter reader: flat key: value, enough for these pages."""
    out = {}
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError:
        return out
    if not lines or lines[0].strip() != "---":
        return out
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        v = v.strip()
        if v.startswith('"') and v.endswith('"') and len(v) > 1:
            v = v[1:-1]
        if v.startswith("[") and v.endswith("]"):
            try:
                v = json.loads(v)
            except json.JSONDecodeError:
                pass
        out[k.strip()] = v
    return out


def find_my_papers(ids):
    found, missing = [], []
    for pid in ids:
        p = PAPERS / f"{pid.replace('/', '_')}.md"
        if p.exists():
            fm = read_frontmatter(p)
            fm["_id"] = pid
            found.append(fm)
        else:
            missing.append(pid)
    return found, missing


def citation_neighbourhood(my_ids):
    """Who cites me, and what my own references point at most often.

    In-corpus only: these edges are nucl-th to nucl-th, so the counts are a
    floor, never a citation record. Said plainly in the generated page too.
    """
    mine = set(my_ids)
    citers, cited_by_me = {}, {}
    if not CITATIONS.exists():
        return citers, cited_by_me
    with CITATIONS.open(errors="replace") as fh:
        next(fh, None)
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            citing, cited = parts[0], parts[1]
            if cited in mine and citing not in mine:
                citers[citing] = citers.get(citing, 0) + 1
            if citing in mine and cited not in mine:
                cited_by_me[cited] = cited_by_me.get(cited, 0) + 1
    return citers, cited_by_me


def title_of(pid):
    p = PAPERS / f"{pid.replace('/', '_')}.md"
    fm = read_frontmatter(p) if p.exists() else {}
    return fm.get("title") or "(no title on that page)", fm.get("authors", "")


# ------------------------------------------------------------- private layer

def seed_private_layer(home: Path, papers, areas_picked, area_labels):
    """Build the starter pages. Everything here is derived from the user's own
    paper list plus the shipped corpus; nothing is invented."""
    import collections

    concepts = collections.Counter()
    coauthors = collections.Counter()
    for fm in papers:
        for c in fm.get("concepts") or []:
            concepts[c] += 1
        for a in str(fm.get("authors", "")).split(";"):
            a = a.strip()
            if a:
                coauthors[a] += 1

    my_ids = [p["_id"] for p in papers]
    citers, cited_by_me = citation_neighbourhood(my_ids) if my_ids else ({}, {})

    stamp = time.strftime("%Y-%m-%d")
    lines = [
        "---",
        f"generated_by: fusion_init.py",
        f"generated: {stamp}",
        "---",
        "",
        "# My research profile",
        "",
        "Seeded by `fusion init` from the papers you listed. It is a starting point,",
        "not a record: edit it freely, it will not be regenerated behind your back.",
        "",
        "## Areas I selected",
        "",
    ]
    lines += [f"- {area_labels[a]}" for a in areas_picked] or ["- (none selected)"]

    if papers:
        lines += ["", f"## My papers in the corpus ({len(papers)})", ""]
        for fm in papers:
            t = fm.get("title", "(title not found)")
            lines.append(f"- [{fm['_id']}](../kb-wiki/papers/{fm['_id']}.md) {t}")

    if concepts:
        lines += ["", "## Topics my own papers carry", "",
                  "From the corpus concept tags on those papers, most frequent first.", ""]
        lines += [f"- {c} ({n})" for c, n in concepts.most_common(15)]

    if coauthors:
        lines += ["", "## People I write with", ""]
        lines += [f"- {a} ({n} paper{'s' if n > 1 else ''})" for a, n in coauthors.most_common(20)]

    if citers:
        lines += ["", f"## Who builds on my work ({len(citers)} papers cite you in-corpus)", "",
                  "Two caveats, both real. Edges are counted inside the nucl-th corpus only, so",
                  "this is a FLOOR and not a citation count; anything outside nucl-th is invisible.",
                  "And part of the citation graph is matched heuristically by author and year, so",
                  "an occasional entry here will be a false positive. Check anything surprising",
                  "against the paper itself before believing it.", ""]
        for pid, n in sorted(citers.items(), key=lambda kv: -kv[1])[:20]:
            t, _ = title_of(pid)
            lines.append(f"- [{pid}](../kb-wiki/papers/{pid}.md) {t}" + (f"  (cites {n} of your papers)" if n > 1 else ""))

    repeated = {pid: n for pid, n in cited_by_me.items() if n >= 2}
    if repeated:
        lines += ["", "## What my own work leans on repeatedly", "",
                  "Papers cited by at least TWO of your listed papers, so this is a recurring",
                  "dependency rather than a one-off reference. With only a few papers listed",
                  "the section is short or absent by design: a list where everything scores 1",
                  "is your bibliography in arbitrary order, not a reading list.", ""]
        for pid, n in sorted(repeated.items(), key=lambda kv: (-kv[1], kv[0]))[:20]:
            t, _ = title_of(pid)
            lines.append(f"- [{pid}](../kb-wiki/papers/{pid}.md) {t}  (cited by {n} of your papers)")
    elif cited_by_me:
        lines += ["", "## What my own work leans on repeatedly", "",
                  f"Nothing yet: your {len(papers)} listed paper(s) cite {len(cited_by_me)} corpus papers",
                  "but none twice, so there is no recurring dependency to report. List more of",
                  "your papers and rerun to make this meaningful.", ""]

    write_file(home / "profile.md", "\n".join(lines) + "\n")

    readme = f"""# Your FUSION private layer

Created by `fusion init` on {stamp}. **This directory is yours.** It lives
outside the FUSION repository on purpose, so nothing here can be committed to a
public clone by accident.

- `profile.md`: seeded from your own papers. Edit it; it is not regenerated.
- Add whatever else you want. Reading notes, running notes, a wiki of your own.

Point an agent at this directory when you want it to know who you are and what
you work on.
"""
    write_file(home / "README.md", readme)


# ------------------------------------------------------------------ the flow

def main():
    global DRY_RUN
    ap = argparse.ArgumentParser(description="Set up FUSION by asking a few questions.")
    ap.add_argument("--dry-run", action="store_true", help="show every write without making it")
    args = ap.parse_args()
    DRY_RUN = args.dry_run

    say("\n\033[1mFUSION init\033[0m")
    say("A few questions, then a working setup. Ctrl-C aborts without writing anything.")
    if DRY_RUN:
        say("\n(dry run: nothing will actually be written)")

    # ---- 0. engine
    head("1. The engine")
    oc = find_opencode()
    if oc:
        say(f"Found opencode at {oc}")
    else:
        say("opencode is not on your PATH. FUSION's skills run inside it.")
        say("Install it first (see https://github.com/anomalyco/opencode), then rerun this.")
        if not ask_yes("Continue anyway and just write the config?", default=False):
            sys.exit(1)

    # ---- 1. model
    head("2. Model")
    say("Which provider do you want as the default?")
    opts = [(p[0], f"{p[1]}  ({p[2]})") for p in PROVIDERS] + [("other", "something else, I will set it myself")]
    for i, (_, label) in enumerate(opts, 1):
        say(f"  {i:2d}. {label}")
    choice = ""
    while not choice:
        raw = ask("Pick one", default="1")
        if raw.isdigit() and 1 <= int(raw) <= len(opts):
            choice = opts[int(raw) - 1][0]
        else:
            say("  not a valid choice")
    model = ""
    if choice != "other":
        default_model = dict((p[0], p[2]) for p in PROVIDERS)[choice]
        model = ask("Model id", default=default_model)
    else:
        say("Fine. Set `model` in your opencode config yourself later.")

    # ---- 2. areas
    head("3. What do you work on?")
    m, counts = load_areas()
    area_labels = {a["id"]: a["label_en"] for a in m["areas"]}
    opts = [(a["id"], f"{a['label_en']}   ({counts.get(a['id'], 0):,} papers in the corpus)")
            for a in m["areas"]]
    picked = ask_multi("Pick your areas", opts)
    if not picked:
        say("  none picked; skill recommendations will be the always-on set only")

    # ---- 3. skills
    head("4. Skills")
    want = list(m.get("always_on", {}).get("skills", []))
    empty_areas = []
    for a in m["areas"]:
        if a["id"] in picked:
            if not a["skills"]:
                empty_areas.append(a["label_en"])
            want += a["skills"]
    want = [s for s in dict.fromkeys(want) if (REPO / "skills" / s).is_dir()]
    say(f"Recommended for your areas ({len(want)}): {', '.join(want) or '(none)'}")
    for lab in empty_areas:
        say(f"  note: no skill covers \"{lab}\" yet. Saying so rather than pretending otherwise.")
    all_skills = sorted(p.name for p in (REPO / "skills").iterdir() if p.is_dir())
    say(f"\nAll {len(all_skills)} skills in this clone are loaded regardless; the list above is")
    say("just what is most likely to matter to you. Skills cost nothing until used.")

    # ---- 4. write config
    head("5. Configuration")
    cfg_dir = config_dir()
    cfg_path = cfg_dir / "opencode.json"
    existing = load_config(cfg_path)
    if existing:
        say(f"You already have {cfg_path}; I will merge, not replace.")
    merged = merge_config(existing, REPO / "skills", model)
    if existing and not DRY_RUN:
        backup = cfg_path.with_suffix(f".json.bak-{time.strftime('%Y%m%d-%H%M%S')}")
        shutil.copy2(cfg_path, backup)
        say(f"  backed up to {backup}")
    write_file(cfg_path, json.dumps(merged, indent=2) + "\n")

    # ---- 5. auth
    head("6. Your API key")
    if choice == "other":
        say("Skipped: you are configuring the provider yourself.")
    else:
        say("Keys are stored by opencode, not by this script, so I will hand you over to it.")
        if oc and ask_yes(f"Run `opencode auth login` now for {choice}?", default=True):
            if DRY_RUN:
                say(f"  [dry-run] would run: {oc} auth login")
            else:
                try:
                    subprocess.run([oc, "auth", "login"], check=False)
                except OSError as e:
                    say(f"  could not launch it ({e}); run `opencode auth login` yourself")
        else:
            say(f"  When you are ready: opencode auth login")

    # ---- 6. private layer
    head("7. Making it yours")
    say("FUSION can seed a private space from your own papers: the topics you actually")
    say("work on, who you write with, who cites you, and what to read next.")
    home = None
    if ask_yes("Set that up?", default=True):
        home = Path(ask("Where should it live?", default=str(Path.home() / ".fusion"))).expanduser()
        try:
            home.resolve().relative_to(REPO.resolve())
            say("  That is inside the FUSION clone. Personal notes must not sit in a repo")
            say("  that gets published, so pick somewhere else.")
            home = Path(ask("Where instead?", default=str(Path.home() / ".fusion"))).expanduser()
        except ValueError:
            pass
        say("\nList the arXiv ids of your own papers, space separated (e.g. 2603.24253 nucl-th/0703083).")
        say("Blank is fine, you can rerun this later.")
        raw = ask("Your arXiv ids")
        ids = raw.replace(",", " ").split()
        papers, missing = find_my_papers(ids) if ids else ([], [])
        if ids:
            say(f"  found {len(papers)} of {len(ids)} in the corpus")
            if missing:
                say(f"  not in the nucl-th corpus (outside nucl-th, or pre-1992): {', '.join(missing)}")
            if papers:
                say("  building your citation neighbourhood, this reads a 16 MB table and takes a moment")
        seed_private_layer(home, papers, picked, area_labels)

    # ---- 7. done
    head("Done")
    say(f"  config      {cfg_path}")
    say(f"  skills      {REPO / 'skills'}  ({len(all_skills)} available)")
    say(f"  knowledge   {REPO / 'kb-wiki'}  (browse offline, no key needed)")
    if home:
        say(f"  private     {home}")
    say("")
    say("Try this first, in a scratch directory:")
    say("")
    say("  opencode")
    say('  > run a FRESCO elastic scattering calculation for n+90Zr at 50 MeV,')
    say("  > then compare it with whatever EXFOR data exists near that energy")
    say("")
    say("It will build FRESCO from source if you do not have it. If something breaks,")
    say("that is worth reporting: https://github.com/jinleiphys/FUSION/issues")
    say("")


if __name__ == "__main__":
    main()
