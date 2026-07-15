#!/usr/bin/env python3
"""FUSION KB: backfill in-corpus citation edges from the INSPIRE references API.

The .tex-only citation extractor (kb_citegraph.py) misses recent preprints that
use an external \\bibliography{} with no inline refs (the corpus stores only .tex).
INSPIRE holds structured reference lists for those papers. This script, for each
target paper, fetches its INSPIRE references, keeps the ones whose arXiv id or DOI
maps to a corpus paper, and writes new edges. Zero LLM tokens.

Writes to a SEPARATE file (kb-wiki/citations-inspire.tsv) so the main graph is
never corrupted mid-run; merge into citations.tsv at the end with kb_citegraph's
existing dedup, or the --merge step here.

Usage:
  kb_inspire_backfill.py --targets <file> [--workers 5] [--out kb-wiki/citations-inspire.tsv]
  kb_inspire_backfill.py --merge     # dedup-merge citations-inspire.tsv into citations.tsv
Resumable: skips target ids already present in the out file's first column.
"""
import argparse
import json
import sqlite3
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KB = ROOT / "kb-wiki"
DB = Path.home() / "literature-corpus" / "corpus.db"
CITATIONS = KB / "citations.tsv"
OUT_DEFAULT = KB / "citations-inspire.tsv"
API = "https://inspirehep.net/api/literature"


def build_corpus_maps():
    con = sqlite3.connect(DB)
    id_set = set()
    doi_to_aid = {}
    for aid, doi in con.execute("SELECT arxiv_id, doi FROM papers"):
        id_set.add(aid)
        if doi:
            doi_to_aid[doi.strip().lower()] = aid
    con.close()
    return id_set, doi_to_aid


def fetch_references(arxiv_id, retries=4):
    q = urllib.parse.quote(f"arxiv:{arxiv_id}")
    url = f"{API}?q={q}&fields=references&size=1"
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, headers={"Accept": "application/json", "User-Agent": "fusion-kb-backfill/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                d = json.load(resp)
            hits = d.get("hits", {}).get("hits", [])
            if not hits:
                return None  # not in INSPIRE
            return hits[0].get("metadata", {}).get("references", [])
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(5 * (attempt + 1))
                continue
            if e.code == 404:
                return None
            time.sleep(2 * (attempt + 1))
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


def map_refs_to_corpus(refs, id_set, doi_to_aid):
    out = set()
    for r in refs or []:
        rr = r.get("reference", {})
        arx = rr.get("arxiv_eprint")
        if arx and arx in id_set:
            out.add(arx)
            continue
        for doi in (rr.get("dois") or []):
            aid = doi_to_aid.get(doi.strip().lower())
            if aid:
                out.add(aid)
                break
    return out


def run(targets_file, out_path, workers):
    id_set, doi_to_aid = build_corpus_maps()
    targets = [l.strip() for l in open(targets_file) if l.strip()]

    done = set()
    if Path(out_path).exists():
        with open(out_path) as f:
            for line in f:
                p = line.split("\t", 1)
                if p and p[0] != "citing":
                    done.add(p[0])
    todo = [a for a in targets if a not in done]
    print(f"backfill: {len(targets)} targets, {len(done)} done, {len(todo)} to go, {workers} workers", flush=True)

    lock = threading.Lock()
    stats = {"n": 0, "edges": 0, "hit": 0, "miss": 0}
    header = not Path(out_path).exists()
    out_f = open(out_path, "a")
    if header:
        out_f.write("citing\tcited\tsource\n")

    pace = threading.Semaphore(workers)

    def work(aid):
        with pace:
            time.sleep(0.2)  # gentle on the public API
            refs = fetch_references(aid)
        if refs is None:
            return aid, None
        return aid, map_refs_to_corpus(refs, id_set, doi_to_aid)

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(work, a): a for a in todo}
        for fut in as_completed(futs):
            aid, cited = fut.result()
            with lock:
                stats["n"] += 1
                if cited is None:
                    stats["miss"] += 1
                else:
                    stats["hit"] += 1
                    for c in cited:
                        if c != aid:
                            out_f.write(f"{aid}\t{c}\tinspire\n")
                            stats["edges"] += 1
                out_f.flush()
                if stats["n"] % 200 == 0:
                    print(f"  {stats['n']}/{len(todo)} done, {stats['edges']} new edges, "
                          f"inspire-hit={stats['hit']} miss={stats['miss']}", flush=True)
    out_f.close()
    print(f"DONE: {stats['n']} targets, {stats['edges']} new in-corpus edges, "
          f"hit={stats['hit']} miss={stats['miss']}", flush=True)


def merge(out_path):
    """Dedup-merge inspire edges into citations.tsv (both ends already in-corpus)."""
    existing = set()
    header = "citing\tcited\n"
    with open(CITATIONS) as f:
        header = f.readline()
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) >= 2:
                existing.add((p[0], p[1]))
    added = 0
    with open(CITATIONS, "a") as cf:
        for line in open(out_path):
            p = line.rstrip("\n").split("\t")
            if len(p) < 2 or p[0] == "citing":
                continue
            key = (p[0], p[1])
            if key not in existing:
                existing.add(key)
                cf.write(f"{p[0]}\t{p[1]}\n")
                added += 1
    print(f"merged {added} new edges into {CITATIONS}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--targets")
    ap.add_argument("--out", default=str(OUT_DEFAULT))
    ap.add_argument("--workers", type=int, default=5)
    ap.add_argument("--merge", action="store_true")
    args = ap.parse_args()
    if args.merge:
        merge(args.out)
    elif args.targets:
        run(args.targets, args.out, args.workers)
    else:
        ap.print_help()
