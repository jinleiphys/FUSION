#!/usr/bin/env python3
"""B2: Inject concepts frontmatter, B3: Generate topic pages, B4: Generate index."""

import json
import re
import yaml
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_WIKI = PROJECT_ROOT / "kb-wiki"
PAPERS_DIR = KB_WIKI / "papers"
TOPICS_DIR = KB_WIKI / "topics"
INDEX_MD = KB_WIKI / "index.md"
PHYSH_YAML = KB_WIKI / "physh-nuclear.yaml"
CLASSIFICATION_JSON = KB_WIKI / "classification.json"
PAPER_LIST = KB_WIKI / "paper-list-full.txt"


def slugify(text):
    s = text.lower().strip()
    s = re.sub(r'[^a-z0-9\s-]', '', s)
    s = re.sub(r'\s+', '-', s)
    s = re.sub(r'-+', '-', s)
    return s.strip('-')


def load_classification():
    with open(CLASSIFICATION_JSON) as f:
        return json.load(f)


def load_physh():
    with open(PHYSH_YAML) as f:
        return yaml.safe_load(f)


def load_paper_list():
    with open(PAPER_LIST) as f:
        return [line.strip() for line in f if line.strip()]


def inject_frontmatter():
    """Inject concepts: [...] into every existing paper page. Idempotent."""
    classification = load_classification()
    paper_ids = set(load_paper_list())

    existing_pages = sorted(PAPERS_DIR.glob("*.md"))
    print(f"Existing paper pages: {len(existing_pages)}")

    updated = 0
    skipped = 0

    for md_path in existing_pages:
        arxiv_id = md_path.stem
        if arxiv_id not in paper_ids:
            continue

        concepts = classification.get(arxiv_id, [])
        concepts_list = json.dumps([c['slug'] for c in concepts])

        with open(md_path, 'r') as f:
            content = f.read()

        # Check if concepts line already exists
        new_line = f"concepts: {concepts_list}"

        if re.search(r'^concepts:', content, re.MULTILINE):
            # Replace existing line
            old_line = re.search(r'^concepts:.*$', content, re.MULTILINE).group(0)
            if old_line == new_line:
                skipped += 1
                continue
            content = content.replace(old_line, new_line)
        else:
            # Insert before closing --- of frontmatter
            end_fm = content.find('---\n', 3)
            if end_fm == -1:
                skipped += 1
                continue
            # Insert before the closing ---
            content = content[:end_fm] + new_line + '\n' + content[end_fm:]

        with open(md_path, 'w') as f:
            f.write(content)
        updated += 1

    print(f"Frontmatter: updated {updated}, skipped (already correct) {skipped}")


def parse_date(date_str):
    """Parse YYYY-MM-DD or YYYY-MM or YYYY to sortable string."""
    if not date_str:
        return "0000"
    return date_str.strip()


def get_paper_meta(arxiv_id):
    """Read date and title from paper's frontmatter. Returns (date, title)."""
    md_path = PAPERS_DIR / f"{arxiv_id}.md"
    if not md_path.exists():
        return "0000", arxiv_id
    try:
        with open(md_path) as f:
            content = f.read(4096)
        m = re.search(r'^date:\s*(.+)$', content, re.MULTILINE)
        date_str = parse_date(m.group(1)) if m else "0000"
        m = re.search(r'^title:\s*(.+)$', content, re.MULTILINE)
        title_str = m.group(1).strip().strip('"') if m else arxiv_id
        return date_str, title_str
    except Exception:
        return "0000", arxiv_id


def generate_topic_pages():
    """Generate kb-wiki/topics/<slug>.md for concepts with >= 5 papers."""
    classification = load_classification()
    physh = load_physh()

    slug_to_concept = {c['slug']: c for c in physh['concepts']}
    slug_to_label = {c['slug']: c['label'] for c in physh['concepts']}

    # Build slug -> {paper_id: tier}
    slug_papers = defaultdict(dict)
    for arxiv_id, concepts in classification.items():
        for entry in concepts:
            slug_papers[entry['slug']][arxiv_id] = entry['tier']

    TOPICS_DIR.mkdir(parents=True, exist_ok=True)

    # Determine which slugs have >= 5 papers
    generated = 0
    for slug, papers in sorted(slug_papers.items(), key=lambda x: -len(x[1])):
        count = len(papers)
        if count < 5:
            continue

        concept = slug_to_concept.get(slug)
        if not concept:
            continue

        label = concept['label']
        broader_slugs = concept.get('broader', [])
        narrower_slugs = concept.get('narrower', [])

        # Sort papers by date (newest first), capped at 100
        paper_dates = []
        for pid in papers:
            date, title = get_paper_meta(pid)
            tier = papers[pid]
            paper_dates.append((pid, date, title, tier))

        paper_dates.sort(key=lambda x: x[1], reverse=True)
        capped = len(paper_dates) > 100
        paper_dates = paper_dates[:100]

        # Build markdown
        # PhySH lineage
        lineage_parts = []
        current = concept
        max_depth = 20
        while current.get('broader') and max_depth > 0:
            max_depth -= 1
            parent_slug = current['broader'][0]
            parent = slug_to_concept.get(parent_slug)
            if parent:
                lineage_parts.insert(0, f"[{parent['label']}]({parent_slug}.md)")
                current = parent
            else:
                break
        lineage_parts.append(label)

        lineage_str = ' > '.join(lineage_parts) if len(lineage_parts) > 1 else label

        lines = []
        lines.append(f"# {label}")
        lines.append("")
        lines.append(f"**PhySH lineage:** {lineage_str}")
        lines.append("")
        if broader_slugs:
            lines.append("**Broader:** " + ", ".join(f"[{slug_to_label.get(s, s)}]({s}.md)" for s in broader_slugs))
            lines.append("")
        if narrower_slugs:
            lines.append("**Narrower:** " + ", ".join(f"[{slug_to_label.get(s, s)}]({s}.md)" for s in narrower_slugs))
            lines.append("")
        lines.append(f"**Papers:** {count}" + (f" (showing first 100 of {len(papers)})" if capped else ""))
        lines.append("")

        for pid, date, title, tier in paper_dates:
            year = date[:4] if date and len(date) >= 4 else "????"
            title_short = title[:120] + ("..." if len(title) > 120 else "")
            lines.append(f"- [{pid}](../papers/{pid}.md) ({year}) [{tier}] {title_short}")

        lines.append("")

        with open(TOPICS_DIR / f"{slug}.md", 'w') as f:
            f.write('\n'.join(lines))
        generated += 1

    print(f"Topic pages generated: {generated}")


def generate_index():
    """Generate kb-wiki/index.md with discipline tree navigation."""
    physh = load_physh()

    slug_to_concept = {c['slug']: c for c in physh['concepts']}
    slug_to_label = {c['slug']: c['label'] for c in physh['concepts']}

    # Build paper counts per slug from topic pages
    slug_counts = {}
    for tf in sorted(TOPICS_DIR.glob("*.md")):
        slug = tf.stem
        with open(tf) as f:
            content = f.read()
        m = re.search(r'\*\*Papers:\*\*\s*(\d+)', content)
        if m:
            slug_counts[slug] = int(m.group(1))

    # Build tree: top-level = concepts with no broader (or broader not in concept set)
    top_level = []
    for c in physh['concepts']:
        broader = c.get('broader', [])
        has_parent_in_set = any(b in slug_to_concept for b in broader)
        if not has_parent_in_set and not c.get('neighbor'):
            top_level.append(c)

    # Sort by label
    top_level.sort(key=lambda c: c['label'])

    # Find max depth to print
    def get_depth(concept, visited=None):
        if visited is None:
            visited = set()
        slug = concept['slug']
        if slug in visited:
            return 0
        visited.add(slug)
        narrower = concept.get('narrower', [])
        if not narrower:
            return 0
        max_child_depth = 0
        for ns in narrower:
            nc = slug_to_concept.get(ns)
            if nc:
                max_child_depth = max(max_child_depth, get_depth(nc, visited))
        return 1 + max_child_depth

    lines = []
    lines.append("# Nuclear Physics: PhySH concept tree")
    lines.append("")
    lines.append(f"**Total concepts:** {len(physh['concepts'])}")
    lines.append(f"**Concepts with topic pages:** {len(list(TOPICS_DIR.glob('*.md')))}")
    lines.append("")
    lines.append("## Core concepts")
    lines.append("")

    def print_tree(concepts_list, indent=0):
        result = []
        for c in concepts_list:
            slug = c['slug']
            label = c['label']
            count = slug_counts.get(slug, 0)
            narrower = c.get('narrower', [])
            has_topic = (TOPICS_DIR / f"{slug}.md").exists()

            prefix = "  " * indent + "- "
            if has_topic:
                link_part = f"[{label}](../topics/{slug}.md)"
            else:
                link_part = label

            if count > 0:
                result.append(f"{prefix}{link_part} ({count} papers)")
            else:
                result.append(f"{prefix}{link_part}")

            # Print children
            children = [slug_to_concept.get(ns) for ns in narrower if ns in slug_to_concept]
            children.sort(key=lambda x: x['label'] if x else '')
            if children:
                result.extend(print_tree(children, indent + 1))

        return result

    tree_lines = print_tree(top_level)
    lines.extend(tree_lines)

    # Neighbor topics section
    neighbors = [c for c in physh['concepts'] if c.get('neighbor')]
    if neighbors:
        lines.append("")
        lines.append("## Neighbor topics (cross-discipline)")
        for c in sorted(neighbors, key=lambda x: x['label']):
            slug = c['slug']
            label = c['label']
            count = slug_counts.get(slug, 0)
            has_topic = (TOPICS_DIR / f"{slug}.md").exists()
            if has_topic:
                lines.append(f"- [{label}](../topics/{slug}.md) ({count} papers)")
            else:
                lines.append(f"- {label} ({count} papers)")

    lines.append("")
    lines.append(f"*Index generated from PhySH v2.8.0 Nuclear Physics concept scheme. "
                 f"Data: kb-wiki/physh-nuclear.yaml.*")

    with open(INDEX_MD, 'w') as f:
        f.write('\n'.join(lines))

    print(f"Index generated: {INDEX_MD}")


def main():
    print("=== B2: Injecting concepts frontmatter ===")
    inject_frontmatter()
    print()
    print("=== B3: Generating topic pages ===")
    generate_topic_pages()
    print()
    print("=== B4: Generating index ===")
    generate_index()


if __name__ == '__main__':
    main()
