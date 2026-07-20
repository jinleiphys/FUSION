#!/usr/bin/env python3
"""FUSION KB: write a grounded landscape synthesis into each PhySH topic page.

For each topic page, rank its papers by in-corpus cited-by count, feed the top
~15 titles+abstracts to DeepSeek, and inject a `## Landscape` section (after the
PhySH lineage, before the papers list). Grounded in the provided abstracts; no
independent claims. Resumable: skips topics whose page already has `## Landscape`.

Usage: kb_topic_synthesis.py [--workers 8] [--only <slug>]
"""
import argparse
import json
import re
import sqlite3
import sys
import threading
import time
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KB = ROOT / "kb-wiki"
TOPICS = KB / "topics"
DB = Path.home() / "literature-corpus" / "corpus.db"
AUTH = Path.home() / ".local/share/opencode/auth.json"
MODEL = "deepseek-chat"

PROMPT = """You are writing the landscape section of a nuclear-physics topic page in a professional literature wiki. Topic: "{topic}".

Below are the most-cited papers in this topic (title + abstract). Write a concise landscape synthesis in English markdown, 3 short paragraphs:
1. What this topic is about and why it matters.
2. The main approaches / methods / sub-threads, naming the specific papers or authors where the abstracts support it.
3. Open questions or active directions visible in the recent papers.

Rules: ground every statement in the abstracts below; do not invent results or numbers not present; use physics terminology; no em-dashes anywhere; do not use a bulleted list, write flowing prose; about 150-220 words total.

PAPERS:
{papers}
"""


def load_key():
    return json.load(open(AUTH))["deepseek"]["key"]


def cited_by_counts():
    counts = defaultdict(int)
    with open(KB / "citations.tsv") as f:
        next(f, None)
        for line in f:
            p = line.split("\t")
            if len(p) >= 2:
                counts[p[1].strip()] += 1
    return counts


def topic_papers(slug, classification):
    out = []
    for aid, tags in classification.items():
        if any(t["slug"] == slug for t in tags):
            out.append(aid)
    return out


def call_deepseek(prompt, key):
    req = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=json.dumps({"model": MODEL, "temperature": 0.3,
                         "messages": [{"role": "user", "content": prompt}]}).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    for attempt in range(3):
        try:
            resp = json.load(urllib.request.urlopen(req, timeout=90))
            return resp["choices"][0]["message"]["content"], resp.get("usage", {})
        except Exception:
            if attempt == 2:
                raise
            time.sleep(5)


def strip_emdash(t):
    return re.sub(r"\s*[—―⸺⸻]+\s*", ", ", t)


def synthesize_one(page, classification, counts, con_path, key):
    slug = page.stem
    text = page.read_text()
    if "## Landscape" in text:
        return slug, "skip", 0, 0
    papers = topic_papers(slug, classification)
    if len(papers) < 5:
        return slug, "too-few", 0, 0
    con = sqlite3.connect(con_path)
    ranked = sorted(papers, key=lambda a: counts.get(a, 0), reverse=True)[:15]
    rows = []
    for aid in ranked:
        r = con.execute("SELECT title, abstract FROM papers WHERE arxiv_id=?", (aid,)).fetchone()
        if r and r[1]:
            rows.append(f"- {r[0]}\n  {r[1][:600]}")
    con.close()
    if not rows:
        return slug, "no-abstracts", 0, 0
    topic_name = text.split("\n", 1)[0].lstrip("# ").strip()
    prompt = PROMPT.format(topic=topic_name, papers="\n".join(rows))
    body, usage = call_deepseek(prompt, key)
    body = strip_emdash(body.strip())
    # Insert after the lineage block (before the first "- [" paper line or "**Papers:**")
    lines = text.split("\n")
    insert_at = len(lines)
    for i, ln in enumerate(lines):
        if ln.startswith("**Papers:**") or ln.startswith("- ["):
            insert_at = i
            break
    section = ["## Landscape", "", body, ""]
    new = lines[:insert_at] + section + lines[insert_at:]
    page.write_text("\n".join(new))
    return slug, "ok", usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--only")
    args = ap.parse_args()
    classification = json.load(open(KB / "classification.json"))
    counts = cited_by_counts()
    key = load_key()
    pages = sorted(TOPICS.glob("*.md"))
    if args.only:
        pages = [p for p in pages if p.stem == args.only]
    lock = threading.Lock()
    stats = {"ok": 0, "skip": 0, "in": 0, "out": 0}
    def work(p):
        try:
            return synthesize_one(p, classification, counts, str(DB), key)
        except Exception as e:
            return p.stem, f"ERR {repr(e)[:60]}", 0, 0
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        for fut in as_completed([ex.submit(work, p) for p in pages]):
            slug, status, ti, to = fut.result()
            with lock:
                if status == "ok":
                    stats["ok"] += 1; stats["in"] += ti; stats["out"] += to
                else:
                    stats["skip"] += 1
                if status not in ("ok", "skip"):
                    print(f"  {slug}: {status}", flush=True)
                if (stats["ok"] + stats["skip"]) % 20 == 0:
                    print(f"  {stats['ok']} written, {stats['skip']} skipped/other, in={stats['in']} out={stats['out']}", flush=True)
    print(f"DONE: {stats['ok']} syntheses written, {stats['skip']} skipped, in={stats['in']} out={stats['out']}")


if __name__ == "__main__":
    main()
