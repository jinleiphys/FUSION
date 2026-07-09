#!/usr/bin/env python3
"""FUSION KB: digest one corpus paper into a wiki md page via DeepSeek.

Prototype for the bulk pre-generation pipeline (kb-design.md L3).
Usage: digest_paper.py <arxiv_id> [outdir]
Reads fulltext from ~/literature-corpus/corpus.db, key from opencode auth.json.
"""
import argparse
import json
import re
import sqlite3
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
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

Rules: no em-dashes anywhere; physics terms over CS jargon; do not invent numbers not present in the text; if the full text is truncated, work with what is shown. Every Key numbers bullet must contain at least one explicit number from the text with its units or context; if a claimed result has no number in the text, omit that bullet rather than paraphrasing qualitatively. If the paper is a review, white paper, or conference summary with no original numerical results, write "Review-type paper: no original numerics." under Key numbers and write Context as scope plus open questions. In Context, refer to prior work as Author (Year) in plain words; never output raw LaTeX citation keys such as [Jin15b] or [Potel:2015eqa].

TITLE: {title}
AUTHORS: {authors}
DATE: {date}
ABSTRACT: {abstract}

FULL TEXT (may be truncated):
{fulltext}
"""


def strip_references(text: str) -> str:
    """Cut the fulltext at the bibliography so the char cap covers body text.
    Only cuts if the marker sits past 30% of the document (guards against
    pathological early hits in concatenated multi-file sources)."""
    cut = len(text)
    for marker in (r"\begin{thebibliography}", r"\bibliography{", "\n[1] ", "\nReferences\n"):
        i = text.find(marker)
        if i != -1 and len(text) * 0.3 < i < cut:
            cut = i
    return text[:cut]


def strip_emdash(text: str) -> str:
    """Guarantee no long horizontal bars survive: em-dash, horizontal bar,
    two/three-em dashes all become a comma. Hyphen-minus and en-dash kept."""
    text = re.sub(r"\s*[\u2014\u2015\u2E3A\u2E3B]+\s*", ", ", text)
    return text


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
        fulltext=strip_references(fulltext or "")[:FULLTEXT_CAP],
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
    out.write_text(strip_emdash(page))
    return {"file": str(out), "seconds": round(time.time() - t0, 1),
            "in_tokens": usage.get("prompt_tokens"), "out_tokens": usage.get("completion_tokens"),
            "cache_hit": usage.get("prompt_cache_hit_tokens")}


def outpath(arxiv_id: str, outdir: Path) -> Path:
    return outdir / f"{arxiv_id.replace('/', '_')}.md"


def batch(list_file: Path, outdir: Path, workers: int) -> None:
    ids = [ln.strip() for ln in list_file.read_text().splitlines() if ln.strip()]
    outdir.mkdir(parents=True, exist_ok=True)
    todo = [i for i in ids if not outpath(i, outdir).exists()]
    skipped = len(ids) - len(todo)
    print(f"batch: {len(ids)} ids, {skipped} already done, {len(todo)} to digest, {workers} workers")

    lock = threading.Lock()
    stats = {"done": 0, "ok": 0, "in": 0, "out": 0}
    failures = []
    t_start = time.time()

    def work(aid):
        for attempt in (1, 2):
            try:
                r = digest(aid, outdir)
                return aid, r, None
            except (Exception, SystemExit) as e:
                if attempt == 1:
                    time.sleep(30)
                else:
                    return aid, None, repr(e)

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(work, aid): aid for aid in todo}
        for fut in as_completed(futs):
            aid, r, err = fut.result()
            with lock:
                stats["done"] += 1
                if err is None:
                    stats["ok"] += 1
                    stats["in"] += r.get("in_tokens") or 0
                    stats["out"] += r.get("out_tokens") or 0
                else:
                    failures.append((aid, err))
                if stats["done"] % 25 == 0 or stats["done"] == len(todo):
                    el = time.time() - t_start
                    print(f"  progress {stats['done']}/{len(todo)} ok={stats['ok']} "
                          f"fail={len(failures)} in={stats['in']} out={stats['out']} "
                          f"elapsed={el:.0f}s", flush=True)

    summary = {
        "attempted": len(todo), "skipped_existing": skipped,
        "succeeded": stats["ok"], "failed": len(failures),
        "in_tokens": stats["in"], "out_tokens": stats["out"],
        "elapsed_s": round(time.time() - t_start, 1),
        "failures": failures,
    }
    (outdir.parent / "batch-summary.json").write_text(json.dumps(summary, indent=1))
    print(json.dumps(summary, indent=1))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("arxiv_id", nargs="?")
    ap.add_argument("outdir_pos", nargs="?")
    ap.add_argument("--list")
    ap.add_argument("--outdir", default="kb-wiki-pilot/papers")
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args()

    if args.list:
        batch(Path(args.list), Path(args.outdir), args.workers)
    else:
        aid = args.arxiv_id
        outdir = Path(args.outdir_pos) if args.outdir_pos else Path.cwd() / "kb-sample"
        print(json.dumps(digest(aid, outdir), indent=1))
