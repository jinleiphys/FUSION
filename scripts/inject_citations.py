#!/usr/bin/env python3
"""Inject citation sections into existing paper pages. Idempotent."""

import re
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_WIKI = PROJECT_ROOT / "kb-wiki"
PAPERS_DIR = KB_WIKI / "papers"
CITATIONS_TSV = KB_WIKI / "citations.tsv"
PAPER_LIST = KB_WIKI / "paper-list-full.txt"


def load_citations():
    """Load citations.tsv and build out/in edge maps."""
    out_edges = defaultdict(set)  # citing -> {cited}
    in_edges = defaultdict(set)   # cited -> {citing}

    with open(CITATIONS_TSV) as f:
        header = f.readline()
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) >= 2:
                citing, cited = parts[0], parts[1]
                out_edges[citing].add(cited)
                in_edges[cited].add(citing)

    return out_edges, in_edges


def get_paper_date(arxiv_id):
    """Quickly read date from paper frontmatter (first 4KB only)."""
    md_path = PAPERS_DIR / f"{arxiv_id}.md"
    if not md_path.exists():
        return "0000"
    try:
        with open(md_path) as f:
            content = f.read(4096)
        m = re.search(r'^date:\s*(.+)$', content, re.MULTILINE)
        return m.group(1).strip() if m else "0000"
    except Exception:
        return "0000"


def get_paper_title(arxiv_id):
    """Quickly read title from paper frontmatter."""
    md_path = PAPERS_DIR / f"{arxiv_id}.md"
    if not md_path.exists():
        return arxiv_id
    try:
        with open(md_path) as f:
            content = f.read(4096)
        m = re.search(r'^title:\s*"?(.+?)"?$', content, re.MULTILINE)
        return m.group(1).strip().strip('"') if m else arxiv_id
    except Exception:
        return arxiv_id


def inject_citations():
    out_edges, in_edges = load_citations()
    print(f"Citing papers: {len(out_edges)}")
    print(f"Cited papers: {len(in_edges)}")

    # Pre-compute paper titles and dates (only for papers that appear in edges)
    all_edge_papers = set(out_edges.keys()) | set()
    for citing in out_edges:
        all_edge_papers.update(out_edges[citing])
    for cited in in_edges:
        all_edge_papers.update(in_edges[cited])

    # Load paper dates for sorting
    paper_dates = {}
    paper_titles = {}
    for pid in all_edge_papers:
        paper_dates[pid] = get_paper_date(pid)
        paper_titles[pid] = get_paper_title(pid)

    # Process all existing paper pages
    existing_pages = sorted(PAPERS_DIR.glob("*.md"))
    print(f"Existing pages: {len(existing_pages)}")

    updated = 0
    skipped = 0

    for md_path in existing_pages:
        arxiv_id = md_path.stem

        outs = out_edges.get(arxiv_id, set())
        ins = in_edges.get(arxiv_id, set())

        with open(md_path, 'r') as f:
            content = f.read()

        # Build citation section
        section_lines = []
        section_lines.append("## In-corpus citations")
        section_lines.append("")

        if outs:
            # Sort by date (newest first), cap at 30
            outs_sorted = sorted(outs, key=lambda x: paper_dates.get(x, "0000"), reverse=True)[:30]
            section_lines.append(f"Cites ({len(outs)}):")
            section_lines.append("")
            for cited in outs_sorted:
                title = paper_titles.get(cited, cited)
                year = paper_dates.get(cited, "????")[:4]
                section_lines.append(f"- [{cited}]({cited}.md) ({year}) {title[:100]}")
            section_lines.append("")
            if len(outs) > 30:
                section_lines.append(f"*(showing 30 of {len(outs)}; full list in citations.tsv)*")
                section_lines.append("")

        if ins:
            ins_sorted = sorted(ins, key=lambda x: paper_dates.get(x, "0000"), reverse=True)[:30]
            section_lines.append(f"Cited by ({len(ins)}):")
            section_lines.append("")
            for citing in ins_sorted:
                title = paper_titles.get(citing, citing)
                year = paper_dates.get(citing, "????")[:4]
                section_lines.append(f"- [{citing}]({citing}.md) ({year}) {title[:100]}")
            section_lines.append("")
            if len(ins) > 30:
                section_lines.append(f"*(showing 30 of {len(ins)}; full list in citations.tsv)*")
                section_lines.append("")

        if not outs and not ins:
            section_lines.append("None detected within the corpus.")
            section_lines.append("")

        new_section = "\n".join(section_lines)

        # Idempotent: replace existing section or append
        if "## In-corpus citations" in content:
            # Find and replace the entire section
            pattern = r'## In-corpus citations\n.*?(?=\n## |\Z)'
            existing = re.search(pattern, content, re.DOTALL)
            if existing:
                old_section = existing.group(0)
                if old_section == new_section.strip():
                    skipped += 1
                    continue
                content = content.replace(old_section, new_section.strip())
            else:
                skipped += 1
                continue
        else:
            # Append at end
            content = content.rstrip() + "\n\n" + new_section

        with open(md_path, 'w') as f:
            f.write(content)
        updated += 1

    print(f"Citation sections: updated {updated}, skipped {skipped}")


if __name__ == '__main__':
    inject_citations()
