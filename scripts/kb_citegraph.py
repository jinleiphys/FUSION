#!/usr/bin/env python3
"""Build within-corpus citation graph from raw .tex files on KINGSTON drive.

Strategy:
  Tier A: Scan tex files for arXiv IDs and DOIs in bibitems and text body.
  Tier B: For papers using \\bibliography{} (external bib), parse \\cite{} keys
          and resolve via author-year heuristic against the corpus.
"""

import os
import re
import sqlite3
import time
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_WIKI = PROJECT_ROOT / "kb-wiki"
CORPUS_DB = Path.home() / "literature-corpus" / "corpus.db"
PAPER_LIST = KB_WIKI / "paper-list-full.txt"
CITATIONS_TSV = KB_WIKI / "citations.tsv"
PAPERS_DIR = KB_WIKI / "papers"


def load_paper_set():
    with open(PAPER_LIST) as f:
        return set(line.strip() for line in f if line.strip())


def build_cite_graph():
    paper_ids = load_paper_set()
    print(f"Papers in list: {len(paper_ids)}")

    conn = sqlite3.connect(CORPUS_DB)

    # Build DOI-to-arxiv_id mapping
    print("Building DOI-to-arxiv_id map...")
    doi_map = {}
    rows = conn.execute("SELECT arxiv_id, doi FROM papers WHERE doi IS NOT NULL AND doi != ''").fetchall()
    for arxiv_id, doi in rows:
        if doi:
            doi_map[doi.lower().strip()] = arxiv_id
    print(f"  {len(doi_map)} DOI mappings")

    # Build old-style ID mapping: nucl-th/9608041 -> canonical
    old_to_canonical = {}
    for pid in paper_ids:
        if '/' in pid:
            old_to_canonical[pid.lower()] = pid

    def resolve_arxiv_by_id(candidate):
        """Resolve an arXiv ID string to a paper-list ID."""
        c = candidate.lower().strip()
        if c in paper_ids:
            return c
        if c in old_to_canonical:
            return old_to_canonical[c]
        return None

    def resolve_doi(doi_str):
        """Resolve a DOI string to a paper-list ID."""
        d = doi_str.lower().strip().rstrip('.,;:)}')
        if d in doi_map:
            aid = doi_map[d]
            if aid in paper_ids:
                return aid
        return None

    # Build first-author name index for Tier B resolution
    print("Building first-author name-year index...")
    first_author_surname_index = defaultdict(list)  # (surname, year) -> [arxiv_id]
    first_author_given_index = defaultdict(list)    # (given_name_part, year) -> [arxiv_id]

    rows = conn.execute("SELECT arxiv_id, authors, date FROM papers").fetchall()
    for arxiv_id, authors_str, date_str in rows:
        if not authors_str:
            continue
        year = date_str[:4] if date_str and len(date_str) >= 4 else ""
        parts = authors_str.split(';')
        if not parts:
            continue
        first_author = parts[0].strip()
        if ',' in first_author:
            surname = first_author.split(',')[0].strip().lower()
            given = first_author.split(',')[1].strip().lower() if len(first_author.split(',')) > 1 else ""
        else:
            words = first_author.split()
            surname = words[-1].lower() if words else ""
            given = words[0].lower() if words else ""

        if surname and year:
            first_author_surname_index[(surname, year)].append(arxiv_id)
        if given and year:
            # Index each given name part (e.g., "Jin" from "Jin")
            for gpart in given.replace('.', ' ').split():
                gpart = gpart.strip()
                if gpart and len(gpart) > 1:
                    first_author_given_index[(gpart, year)].append(arxiv_id)

    print(f"  First-author surname-index entries: {sum(len(v) for v in first_author_surname_index.values())}")
    print(f"  First-author given-index entries: {sum(len(v) for v in first_author_given_index.values())}")

    # Get all papers with tex_dir
    print("Loading tex_dir entries...")
    rows = conn.execute(
        "SELECT arxiv_id, tex_dir FROM papers WHERE tex_dir IS NOT NULL AND tex_dir != ''"
    ).fetchall()
    tex_entries = {row[0]: row[1] for row in rows}
    print(f"  {len(tex_entries)} papers have tex_dir")

    # Regex patterns for Tier A
    re_old_arxiv = re.compile(
        r'(?:nucl-th|nucl-ex|hep-ph|hep-th|hep-ex|hep-lat|astro-ph|cond-mat|quant-ph|physics|math-ph|gr-qc)'
        r'/\d{7}',
        re.IGNORECASE
    )
    re_new_arxiv = re.compile(
        r'(?:arXiv|arxiv)[:\s=]*\{?(\d{4}\.\d{4,5}(?:v\d+)?)\b\}?',
        re.IGNORECASE
    )
    re_doi = re.compile(r'(?:DOI|doi)[:\s]*\{?(10\.\d{4,}/[^\s,;\"\)\}\]]+)\b')
    # Also match bare new-style arXiv IDs: \b\d{4}\.\d{4,5}\b (but careful with DOIs)
    re_bare_arxiv = re.compile(r'(?<!\d)(\d{4}\.\d{4,5})(?!\d)')

    # Regex for Tier B: extract \cite{} keys
    re_cite = re.compile(r'\\cite\{([^}]+)\}')
    re_cite_key = re.compile(r'^([a-zA-Z]+)(\d{2})\w?$')

    edges = set()
    missing_dirs = 0
    processed = 0
    tier_a_edges = 0
    tier_b_edges = 0
    tier_b_candidates = 0

    start_time = time.time()

    for arxiv_id in sorted(paper_ids):
        processed += 1
        if processed % 5000 == 0:
            elapsed = time.time() - start_time
            eta = elapsed / processed * (len(paper_ids) - processed)
            print(f"  {processed}/{len(paper_ids)} ({elapsed:.0f}s, ETA {eta:.0f}s), "
                  f"edges: {len(edges)} (A:{tier_a_edges} B:{tier_b_edges}), "
                  f"missing dirs: {missing_dirs}")

        tex_dir = tex_entries.get(arxiv_id)
        if not tex_dir or not os.path.isdir(tex_dir):
            missing_dirs += 1
            continue

        cited_ids = set()
        full_text = ""

        tex_files = [f for f in os.listdir(tex_dir) if f.lower().endswith('.tex')]
        for tf in tex_files:
            fpath = os.path.join(tex_dir, tf)
            try:
                with open(fpath, encoding='utf-8', errors='replace') as f:
                    text = f.read(2000000)
            except Exception:
                continue
            full_text += text

            # Tier A: extract arXiv IDs and DOIs from text
            for match in re_old_arxiv.finditer(text):
                aid = resolve_arxiv_by_id(match.group(0))
                if aid and aid != arxiv_id:
                    cited_ids.add(aid)
                    tier_a_edges += 1

            for match in re_new_arxiv.finditer(text):
                nid = match.group(1).split('v')[0] if 'v' in match.group(1) else match.group(1)
                aid = resolve_arxiv_by_id(nid)
                if aid and aid != arxiv_id:
                    cited_ids.add(aid)
                    tier_a_edges += 1

            for match in re_doi.finditer(text):
                aid = resolve_doi(match.group(1))
                if aid and aid != arxiv_id:
                    cited_ids.add(aid)
                    tier_a_edges += 1

        # If no edges from Tier A, try Tier B (author-year heuristic for bibtex keys)
        if not cited_ids and full_text:
            cite_keys = set()
            for match in re_cite.finditer(full_text):
                for key in match.group(1).split(','):
                    key = key.strip()
                    if key:
                        cite_keys.add(key)

            for key in cite_keys:
                key_match = re_cite_key.match(key)
                if not key_match:
                    continue
                author_hint = key_match.group(1).lower()
                year_suffix = key_match.group(2)
                year_full = "20" + year_suffix if int(year_suffix) <= 30 else "19" + year_suffix

                # Try first-author surname match first (conventional)
                surname_candidates = set(first_author_surname_index.get((author_hint, year_full), []))
                given_candidates = set(first_author_given_index.get((author_hint, year_full), []))

                # Combine both candidate sets (author_hint might be surname OR given name)
                all_candidates = (surname_candidates | given_candidates)
                candidates = {c for c in all_candidates if c != arxiv_id and c in paper_ids}

                tier_b_candidates += 1

                if len(candidates) == 1:
                    aid = list(candidates)[0]
                    cited_ids.add(aid)
                    tier_b_edges += 1
                elif len(candidates) >= 2:
                    # Multiple candidates: group by first-author surname
                    surname_groups = defaultdict(set)
                    for aid in candidates:
                        row = conn.execute("SELECT authors FROM papers WHERE arxiv_id=?", (aid,)).fetchone()
                        if row and row[0]:
                            fa = row[0].split(';')[0].strip()
                            sn = fa.split(',')[0].strip().lower() if ',' in fa else fa.split()[-1].lower()
                            surname_groups[sn].add(aid)
                    if len(surname_groups) == 1:
                        # All same author, multiple papers: accept all
                        for aid in candidates:
                            cited_ids.add(aid)
                            tier_b_edges += 1
                    elif len(surname_groups) >= 2:
                        # Multiple different authors: prefer the largest group
                        # (author with most publications that year is most likely citation target)
                        best_group = max(surname_groups.values(), key=len)
                        for aid in best_group:
                            cited_ids.add(aid)
                            tier_b_edges += 1

        for cited in cited_ids:
            edges.add((arxiv_id, cited))

    elapsed = time.time() - start_time
    print(f"\nCitation extraction finished in {elapsed:.0f}s ({elapsed/60:.1f} min)")

    # Write citations.tsv
    with open(CITATIONS_TSV, 'w') as f:
        f.write("citing\tcited\n")
        for citing, cited in sorted(edges):
            f.write(f"{citing}\t{cited}\n")

    # Metrics
    papers_with_edges = set()
    for citing, cited in edges:
        papers_with_edges.add(citing)
        papers_with_edges.add(cited)

    out_degree = defaultdict(int)
    in_degree = defaultdict(int)
    for citing, cited in edges:
        out_degree[citing] += 1
        in_degree[cited] += 1

    mean_out = sum(out_degree.values()) / max(len(out_degree), 1)

    print(f"\n=== Citation Graph Metrics ===")
    print(f"Total edges: {len(edges)} (Tier A: {tier_a_edges}, Tier B: {tier_b_edges})")
    cite_esc = '\\cite{}'
    print(f"Tier B {cite_esc} candidates evaluated: {tier_b_candidates}")
    print(f"Papers with >= 1 edge: {len(papers_with_edges)}")
    print(f"Mean out-degree: {mean_out:.1f}")
    print(f"Missing tex_dirs: {missing_dirs}")

    # Calibration: 1711.07540 -> 1511.03214
    cal_edge = ("1711.07540", "1511.03214")
    present = cal_edge in edges
    print(f"\nCalibration: {cal_edge[0]} -> {cal_edge[1]}: {'PRESENT' if present else 'MISSING!'}")

    if not present:
        # Debug: why was it not found?
        print("  Debugging calibration edge...")
        tex_dir_citing = tex_entries.get("1711.07540")
        if tex_dir_citing and os.path.isdir(tex_dir_citing):
            for tf in os.listdir(tex_dir_citing):
                if tf.lower().endswith('.tex'):
                    with open(os.path.join(tex_dir_citing, tf), encoding='utf-8', errors='replace') as f:
                        debug_text = f.read()
                    # Check if there's a \cite{Jin15b} etc.
                    cite_keys = set()
                    for m in re_cite.finditer(debug_text):
                        for k in m.group(1).split(','):
                            k = k.strip()
                            if 'jin' in k.lower() or '15' in k:
                                cite_keys.add(k)
                    print(f"  \\cite keys matching 'jin'/'15': {cite_keys}")
                    for key in cite_keys:
                        km = re_cite_key.match(key)
                        if km:
                            ah = km.group(1).lower()
                            ys = km.group(2)
                            yf = "20" + ys if int(ys) <= 30 else "19" + ys
                            cand_surname = set(first_author_surname_index.get((ah, yf), []))
                            cand_given = set(first_author_given_index.get((ah, yf), []))
                            print(f"  Key {key}: author={ah}, year={yf}, "
                                  f"surname_candidates={cand_surname}, given_candidates={cand_given}")

    # Sanity samples
    for pid in ["2604.11226", "2101.09497"]:
        outs = sorted([cited for citing, cited in edges if citing == pid])
        ins = sorted([citing for citing, cited in edges if cited == pid])
        print(f"\n{pid}: cites={len(outs)}, cited-by={len(ins)}")
        for o in outs[:5]:
            print(f"  -> {o}")
        for i in ins[:5]:
            print(f"  <- {i}")

    conn.close()
    return edges


if __name__ == '__main__':
    build_cite_graph()
