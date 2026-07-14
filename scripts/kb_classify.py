#!/usr/bin/env python3
"""Classify all papers against PhySH nuclear concepts using tiered FTS5 queries."""

import json
import sqlite3
import sys
import time
import yaml
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_WIKI = PROJECT_ROOT / "kb-wiki"
CORPUS_DB = Path.home() / "literature-corpus" / "corpus.db"
PHYSH_YAML = KB_WIKI / "physh-nuclear.yaml"
CLASSIFICATION_JSON = KB_WIKI / "classification.json"
PAPER_LIST = KB_WIKI / "paper-list-full.txt"

def load_physh():
    with open(PHYSH_YAML) as f:
        return yaml.safe_load(f)


def classify():
    physh = load_physh()
    reaction_family_slugs = set(physh.get('negative_filter', {}).get('reaction_family_slugs', []))

    with open(PAPER_LIST) as f:
        paper_ids = [line.strip() for line in f if line.strip()]

    print(f"Papers: {len(paper_ids)}")
    print(f"Concepts: {len(physh['concepts'])}")

    conn = sqlite3.connect(CORPUS_DB)
    conn.row_factory = sqlite3.Row

    # Pre-load paper metadata
    print("Loading metadata...")
    id_to_meta = {}
    batch_size = 1000
    for i in range(0, len(paper_ids), batch_size):
        batch = paper_ids[i:i + batch_size]
        placeholders = ','.join('?' * len(batch))
        rows = conn.execute(
            f"SELECT arxiv_id, title, abstract, primary_cat FROM papers WHERE arxiv_id IN ({placeholders})",
            batch
        ).fetchall()
        for row in rows:
            id_to_meta[row[0]] = {
                'title': (row['title'] or '').lower(),
                'abstract': (row['abstract'] or '').lower(),
                'primary_cat': (row['primary_cat'] or '').lower(),
            }

    print(f"Metadata for {len(id_to_meta)} papers loaded")

    # Build arxiv_id index for fast lookup from FTS5 results
    paper_id_set = set(paper_ids)

    def resolve_aid(fts_aid):
        """Map an FTS5 arxiv_id (may have version suffix) back to our canonical id."""
        if fts_aid in paper_id_set:
            return fts_aid
        canonical = fts_aid.split('v')[0] if 'v' in fts_aid else fts_aid
        if canonical in paper_id_set:
            return canonical
        return None

    # Classification result
    classification = defaultdict(dict)  # arxiv_id -> {slug: tier}

    # For tier-3 validation: track which papers matched which phrases in fulltext
    concept_fulltext_hits = {}  # slug -> {paper_id: set(phrases)}

    start_time = time.time()
    for ci, concept in enumerate(physh['concepts']):
        slug = concept['slug']
        matches = concept.get('match', [])
        is_reaction_family = slug in reaction_family_slugs

        if (ci + 1) % 20 == 0:
            elapsed = time.time() - start_time
            eta = elapsed / (ci + 1) * (len(physh['concepts']) - ci - 1)
            print(f"  Concept {ci + 1}/{len(physh['concepts'])}: {concept['label']} "
                  f"({elapsed:.0f}s elapsed, ETA {eta:.0f}s)")

        # Collect distinct phrases and their tier assignments
        tier1_phrases = []
        tier2_phrases = []
        tier3_phrases = []

        for m in matches:
            query = m['query']
            tiers = m['tiers']
            phrase = query.strip('"')
            if 1 in tiers:
                tier1_phrases.append(phrase)
            if 2 in tiers:
                tier2_phrases.append(phrase)
            if 3 in tiers:
                tier3_phrases.append(phrase)

        matched_papers = set()

        # Tier 1: title
        for phrase in tier1_phrases:
            try:
                rows = conn.execute(
                    'SELECT arxiv_id FROM papers_fts WHERE papers_fts MATCH ?',
                    (f'title:"{phrase}"',)
                ).fetchall()
                for row in rows:
                    aid = resolve_aid(row[0])
                    if aid and aid not in matched_papers:
                        matched_papers.add(aid)
                        if slug not in classification[aid]:
                            classification[aid][slug] = 1
            except Exception:
                pass

        # Tier 2: abstract (only for papers not already matched)
        for phrase in tier2_phrases:
            try:
                rows = conn.execute(
                    'SELECT arxiv_id FROM papers_fts WHERE papers_fts MATCH ?',
                    (f'abstract:"{phrase}"',)
                ).fetchall()
                for row in rows:
                    aid = resolve_aid(row[0])
                    if aid and aid not in matched_papers:
                        matched_papers.add(aid)
                        if slug not in classification[aid]:
                            classification[aid][slug] = 2
            except Exception:
                pass

        # Tier 3: fulltext. Track per-paper matched phrases.
        ft_hits = defaultdict(set)  # paper_id -> set(phrases)
        for phrase in tier3_phrases:
            try:
                rows = conn.execute(
                    'SELECT arxiv_id FROM papers_fts WHERE papers_fts MATCH ?',
                    (f'fulltext:"{phrase}"',)
                ).fetchall()
                for row in rows:
                    aid = resolve_aid(row[0])
                    if aid and aid not in matched_papers:
                        ft_hits[aid].add(phrase.lower())
            except Exception:
                pass

        # Tier 3 validation: >= 2 distinct match phrases hitting in fulltext
        # (The "one phrase 3+ times" clause is not enforced here -- would require
        # per-paper fulltext scans; documented as a known limitation in the report.)
        for aid, phrases in ft_hits.items():
            if len(phrases) < 2:
                continue

            # Apply negative filter
            if is_reaction_family:
                meta = id_to_meta.get(aid)
                if meta:
                    pc = meta['primary_cat']
                    if pc.startswith('hep-') or pc.startswith('astro-ph'):
                        continue

            if slug not in classification[aid]:
                classification[aid][slug] = 3

    elapsed = time.time() - start_time
    print(f"\nClassification finished in {elapsed:.0f}s ({elapsed / 60:.1f} min)")

    # Write classification.json
    output = {}
    for pid in sorted(classification.keys()):
        concepts = classification[pid]
        entries = [{"slug": slug, "tier": tier} for slug, tier in sorted(concepts.items(), key=lambda x: x[1])]
        output[pid] = entries

    with open(CLASSIFICATION_JSON, 'w') as f:
        json.dump(output, f, indent=2)

    # ---- Metrics ----
    classified_papers = set(classification.keys())
    unclassified = [pid for pid in paper_ids if pid not in classified_papers]
    unclassified_rate = len(unclassified) / len(paper_ids) * 100

    print(f"\n=== Classification Metrics ===")
    print(f"Classified papers: {len(classified_papers)}")
    print(f"Unclassified: {len(unclassified)} ({unclassified_rate:.1f}%)")

    # Per-concept counts
    concept_counts = defaultdict(int)
    for pid, concepts in classification.items():
        for slug in concepts:
            concept_counts[slug] += 1

    print(f"\nTop 20 concepts by paper count:")
    slug_to_label = {c['slug']: c['label'] for c in physh['concepts']}
    for slug, count in sorted(concept_counts.items(), key=lambda x: -x[1])[:20]:
        print(f"  {slug_to_label.get(slug, slug)}: {count}")

    # Tier distribution
    tier_dist = defaultdict(int)
    for pid, pid_concepts in classification.items():
        if isinstance(pid_concepts, dict):
            for slug, tier in pid_concepts.items():
                tier_dist[tier] += 1
    print(f"\nTier distribution: tier-1={tier_dist[1]}, tier-2={tier_dist[2]}, tier-3={tier_dist[3]}")

    if unclassified_rate > 30:
        print(f"\nWARNING: unclassified rate exceeds 30%. Sample unclassified titles:")
        for pid in unclassified[:10]:
            meta = id_to_meta.get(pid, {})
            print(f"  {pid}: {meta.get('title', 'N/A').capitalize()}")

    # Per-concept paper counts for the report
    concept_paper_counts = []
    for slug, count in sorted(concept_counts.items(), key=lambda x: -x[1]):
        concept_paper_counts.append({
            "slug": slug,
            "label": slug_to_label.get(slug, slug),
            "count": count,
        })

    conn.close()
    return classification, concept_counts, tier_dist, unclassified_rate, concept_paper_counts


if __name__ == '__main__':
    classify()
