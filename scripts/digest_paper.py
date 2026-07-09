#!/usr/bin/env python3
"""FUSION KB: digest one corpus paper into a wiki md page via DeepSeek.

Prototype for the bulk pre-generation pipeline (kb-design.md L3).
Usage: digest_paper.py <arxiv_id> [outdir]
Reads fulltext from ~/literature-corpus/corpus.db, key from opencode auth.json.
"""
import json
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path

DB = Path.home() / "literature-corpus/corpus.db"
AUTH = Path.home() / ".local/share/opencode/auth.json"
MODEL = "deepseek-chat"
FULLTEXT_CAP = 40000  # chars, ~10k tokens

TEMPLATE = """You are building a professional nuclear-physics literature wiki. Digest the paper below into a wiki page body in English markdown with EXACTLY these sections:

## Key claim
One or two sentences, one level deeper than the abstract: include the actual hedge, qualifier, or condition the abstract glosses over.

## Method
What was actually done, in the field's standard terminology (2-4 sentences).

## Key numbers
Bullet list of the specific numerical results worth remembering, each with its context (system, energy, precision). If the paper is formal with no numerics, say so in one line.

## Context
2-3 sentences: what line of work this extends or contradicts, and what it enables next. Name specific prior approaches or papers where the text does.

Rules: no em-dashes anywhere; physics terms over CS jargon; do not invent numbers not present in the text; if the full text is truncated, work with what is shown.

TITLE: {title}
AUTHORS: {authors}
DATE: {date}
ABSTRACT: {abstract}

FULL TEXT (may be truncated):
{fulltext}
"""


def digest(arxiv_id: str, outdir: Path) -> dict:
    key = json.load(open(AUTH))["deepseek"]["key"]
    con = sqlite3.connect(DB)
    row = con.execute(
        "SELECT p.title, p.authors, p.abstract, p.date, p.doi, p.categories, f.fulltext "
        "FROM papers p JOIN papers_fts f ON p.arxiv_id = f.arxiv_id WHERE p.arxiv_id = ?",
        (arxiv_id,),
    ).fetchone()
    if not row:
        sys.exit(f"{arxiv_id} not in corpus")
    title, authors, abstract, date, doi, cats, fulltext = row
    prompt = TEMPLATE.format(
        title=title, authors=authors, date=date, abstract=abstract,
        fulltext=(fulltext or "")[:FULLTEXT_CAP],
    )
    t0 = time.time()
    req = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=json.dumps({
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
        }).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    resp = json.load(urllib.request.urlopen(req, timeout=300))
    body = resp["choices"][0]["message"]["content"]
    usage = resp.get("usage", {})
    page = (
        f"---\narxiv: {arxiv_id}\ntitle: \"{title}\"\nauthors: \"{authors}\"\n"
        f"date: {date}\ndoi: {doi or '-'}\ncategories: {cats}\n"
        f"digest_model: {MODEL}\ndigest_date: {time.strftime('%Y-%m-%d')}\n---\n\n"
        f"# {title}\n\n> {abstract}\n\n{body}\n"
    )
    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / f"{arxiv_id.replace('/', '_')}.md"
    out.write_text(page)
    return {"file": str(out), "seconds": round(time.time() - t0, 1),
            "in_tokens": usage.get("prompt_tokens"), "out_tokens": usage.get("completion_tokens"),
            "cache_hit": usage.get("prompt_cache_hit_tokens")}


if __name__ == "__main__":
    aid = sys.argv[1]
    outdir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.cwd() / "kb-sample"
    print(json.dumps(digest(aid, outdir), indent=1))
