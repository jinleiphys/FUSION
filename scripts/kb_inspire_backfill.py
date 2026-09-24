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


def map_refs_to_corpus(refs, id_set, doi_to_aid, pending=None):
    """In-corpus arXiv ids of a reference list: by eprint, else by DOI. A
    reference neither maps, but that INSPIRE matched to one of its records
    (common for journal-only citations such as "Phys.Rev.C 92, 044616", and
    for DOIs corpus.db does not carry), is collected in `pending` as the
    record's control number, for resolve_records(). A reference whose eprint
    is known but outside the corpus is not queued: the record carries the
    same eprint."""
    out = set()
    for r in refs or []:
        rr = r.get("reference", {})
        arx = rr.get("arxiv_eprint")
        if arx and arx in id_set:
            out.add(arx)
            continue
        hit = None
        for doi in rr.get("dois") or []:
            hit = doi_to_aid.get(doi.strip().lower())
            if hit:
                break
        if hit:
            out.add(hit)
        elif not arx and pending is not None:
            ref = (r.get("record") or {}).get("$ref", "")
            if ref.rstrip("/").split("/")[-1].isdigit():
                pending.add(ref.rstrip("/").split("/")[-1])
    return out


RECID_CACHE = KB / "inspire-recid-map.tsv"


def resolve_records(pending_path, out_path, id_set, doi_to_aid, batch=80):
    """Turn (citing, INSPIRE control number) rows into edges: look the records
    up in batches for their arXiv eprint or DOI, cache the answers in
    inspire-recid-map.tsv, and append in-corpus edges with source
    'inspire-record'."""
    rows = []
    with open(pending_path) as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) == 2 and p[0] != "citing":
                rows.append((p[0], p[1]))
    cache = {}
    if RECID_CACHE.exists():
        with open(RECID_CACHE) as f:
            for line in f:
                p = line.rstrip("\n").split("\t")
                if len(p) == 2:
                    cache[p[0]] = p[1]
    todo = sorted({r for _, r in rows} - set(cache))
    print(f"records: {len(rows)} pending refs, {len(todo)} records to look up", flush=True)
    with open(RECID_CACHE, "a") as cf:
        for i in range(0, len(todo), batch):
            chunk = todo[i:i + batch]
            q = urllib.parse.quote("control_number:(" + " or ".join(chunk) + ")")
            url = f"{API}?q={q}&fields=control_number,arxiv_eprints,dois&size={len(chunk)}"
            found = {}
            for attempt in range(5):
                try:
                    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "fusion-kb-backfill/1.0"})
                    with urllib.request.urlopen(req, timeout=60) as resp:
                        d = json.load(resp)
                    for h in d.get("hits", {}).get("hits", []):
                        m = h.get("metadata", {})
                        aid = ""
                        for e in m.get("arxiv_eprints") or []:
                            if e.get("value") in id_set:
                                aid = e["value"]
                                break
                        if not aid:
                            for doi in m.get("dois") or []:
                                aid = doi_to_aid.get(str(doi.get("value", "")).lower(), "")
                                if aid:
                                    break
                        found[str(m.get("control_number"))] = aid
                    break
                except Exception:
                    time.sleep(3 * (attempt + 1))
            else:
                continue  # leave this chunk uncached; a rerun retries it
            for r in chunk:
                cache[r] = found.get(r, "")
                cf.write(f"{r}\t{cache[r]}\n")
            cf.flush()
            time.sleep(0.3)
            if (i // batch) % 50 == 0:
                print(f"  {i + len(chunk)}/{len(todo)} records looked up", flush=True)
    added = 0
    seen = set()
    if Path(out_path).exists():  # edges already written from eprint/DOI
        with open(out_path) as f:
            for line in f:
                p = line.split("\t")
                if len(p) >= 2:
                    seen.add((p[0], p[1].rstrip("\n")))
    with open(out_path, "a") as of:
        for citing, r in rows:
            aid = cache.get(r, "")
            if aid and aid != citing and (citing, aid) not in seen:
                seen.add((citing, aid))
                of.write(f"{citing}\t{aid}\tinspire-record\n")
                added += 1
    print(f"records: {added} edges appended to {out_path}", flush=True)


def run(targets_file, out_path, workers, pending_path=None):
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

    pending_f = open(pending_path, "a") if pending_path else None
    pace = threading.Semaphore(workers)

    def work(aid):
        with pace:
            time.sleep(0.2)  # gentle on the public API
            refs = fetch_references(aid)
        if refs is None:
            return aid, None, set()
        pend = set()
        return aid, map_refs_to_corpus(refs, id_set, doi_to_aid, pend), pend

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(work, a): a for a in todo}
        for fut in as_completed(futs):
            aid, cited, pend = fut.result()
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
                    if pending_f:
                        for r in pend:
                            pending_f.write(f"{aid}\t{r}\n")
                        pending_f.flush()
                out_f.flush()
                if stats["n"] % 200 == 0:
                    print(f"  {stats['n']}/{len(todo)} done, {stats['edges']} new edges, "
                          f"inspire-hit={stats['hit']} miss={stats['miss']}", flush=True)
    out_f.close()
    if pending_f:
        pending_f.close()
    print(f"DONE: {stats['n']} targets, {stats['edges']} new in-corpus edges, "
          f"hit={stats['hit']} miss={stats['miss']}", flush=True)


def merge(out_path):
    """Dedup-merge inspire edges into citations.tsv.

    Only edges with a page at both ends are kept (INSPIRE maps references onto
    the whole corpus.db, which holds papers that have no kb-wiki page), and
    edges listed in edge-blacklist.tsv stay out, as in kb_citegraph."""
    pages = set(l.strip() for l in open(KB / "paper-list-full.txt") if l.strip())
    blacklist = set()
    bl = KB / "edge-blacklist.tsv"
    if bl.exists():
        with open(bl) as f:
            f.readline()
            for line in f:
                p = line.rstrip("\n").split("\t")
                if len(p) >= 2:
                    blacklist.add((p[0], p[1]))
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
            if p[0] not in pages or p[1] not in pages or key in blacklist:
                continue
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
    ap.add_argument("--pending", help="with --targets: also record references known only by INSPIRE record number")
    ap.add_argument("--resolve-records", metavar="PENDING", help="resolve a --pending file into edges appended to --out")
    args = ap.parse_args()
    if args.merge:
        merge(args.out)
    elif args.resolve_records:
        resolve_records(args.resolve_records, args.out, *build_corpus_maps())
    elif args.targets:
        run(args.targets, args.out, args.workers, args.pending)
    else:
        ap.print_help()
