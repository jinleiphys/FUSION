#!/usr/bin/env python3
"""FUSION KB: L3-semantic relation layer -- extract, classify, inject.

Citation-context extraction + DeepSeek relation classifier + page injection.
Builds on kb_citegraph.py's resolution logic and digest_paper.py's API pattern.
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import time
import urllib.request
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
KB_WIKI = PROJECT_ROOT / "kb-wiki"
PAPERS_DIR = KB_WIKI / "papers"
CITATIONS_TSV = KB_WIKI / "citations.tsv"
RELATIONS_TSV = KB_WIKI / "relations-sample.tsv"

DB = Path.home() / "literature-corpus/corpus.db"
AUTH = Path.home() / ".local/share/opencode/auth.json"
MODEL = "deepseek-chat"

TEX_ROOT = Path("/Volumes/KINGSTON/nucl-th_tex_files")

# --- cite-key patterns ---
RE_CITE = re.compile(r'\\cite\{([^}]+)\}')
RE_CITE_KEY_CONVENTIONAL = re.compile(r'^([a-zA-Z][a-zA-Z]*(?:[-_][a-zA-Z]+)*?)(\d{2})([a-zA-Z]?)$')
RE_CITE_KEY_COLON = re.compile(r'^([a-zA-Z][a-zA-Z]*(?:[-_][a-zA-Z]+)*):(\d{4})([a-zA-Z]*)$')
RE_BARE_ARXIV = re.compile(r'(?<!\d)(\d{4}\.\d{4,5})(?!\d)')
RE_OLD_ARXIV = re.compile(
    r'(?:nucl-th|nucl-ex|hep-ph|hep-th|hep-ex|hep-lat|astro-ph|cond-mat|quant-ph|physics|math-ph|gr-qc)/\d{7}',
    re.IGNORECASE,
)
RE_NEW_ARXIV = re.compile(
    r'(?:arXiv|arxiv)[:\s=]*\{?(\d{4}\.\d{4,5}(?:v\d+)?)\b\}?',
    re.IGNORECASE,
)
RE_DOI = re.compile(r'(?:DOI|doi)[:\s]*\{?(10\.\d{4,}/[^\s,;\"\)\}\]]+)\b')


def load_api_key():
    return json.load(open(AUTH))["deepseek"]["key"]


def build_corpus_index():
    """Build lookup maps from corpus.db: arxiv_id -> metadata, DOI map, author index."""
    conn = sqlite3.connect(DB)
    rows = conn.execute(
        "SELECT arxiv_id, authors, title, abstract, date, doi, tex_dir FROM papers"
    ).fetchall()

    arxiv_meta = {}
    doi_to_aid = {}
    arxiv_id_set = set()
    surname_year_index = defaultdict(list)
    given_year_index = defaultdict(list)

    for arxiv_id, authors_str, title, abstract, date_str, doi, tex_dir in rows:
        arxiv_meta[arxiv_id] = {
            "title": title or "",
            "authors": authors_str or "",
            "abstract": abstract or "",
            "date": date_str or "",
            "doi": doi or "",
            "tex_dir": tex_dir or "",
        }
        arxiv_id_set.add(arxiv_id)
        if doi:
            doi_to_aid[doi.lower().strip()] = arxiv_id

        if not authors_str:
            continue
        year = date_str[:4] if date_str and len(date_str) >= 4 else ""
        parts = authors_str.split(";")
        if not parts:
            continue
        first_author = parts[0].strip()
        if "," in first_author:
            surname = first_author.split(",")[0].strip().lower()
            given = first_author.split(",")[1].strip().lower() if len(first_author.split(",")) > 1 else ""
        else:
            words = first_author.split()
            surname = words[-1].lower() if words else ""
            given = words[0].lower() if words else ""
        if surname and year:
            surname_year_index[(surname, year)].append(arxiv_id)
        if given and year:
            for gpart in given.replace(".", " ").split():
                gpart = gpart.strip()
                if gpart and len(gpart) > 1:
                    given_year_index[(gpart, year)].append(arxiv_id)

    conn.close()
    return arxiv_meta, doi_to_aid, arxiv_id_set, surname_year_index, given_year_index


def resolve_arxiv_for_id(candidate, arxiv_id_set):
    """Resolve an arXiv ID candidate to canonical form."""
    c = candidate.lower().strip()
    if c in arxiv_id_set:
        return c
    if "/" in c and c in arxiv_id_set:
        return c
    return None


def parse_tex_cite_keys(tex_text):
    """Return list of (cite_key, start_pos, end_pos) tuples from tex text."""
    results = []
    for m in RE_CITE.finditer(tex_text):
        full_key_str = m.group(1)
        base_pos = m.start()
        for key in full_key_str.split(","):
            key = key.strip()
            if key:
                results.append((key, base_pos, m.end()))
    return results


def extract_citation_context(tex_text: str, key: str) -> str:
    """Extract the citation context: sentences around \\cite{key}."""
    pattern = re.compile(
        r'\\cite\s*\{[^}]*' + re.escape(key) + r'[^}]*\}'
    )
    matches = list(pattern.finditer(tex_text))
    if not matches:
        return ""

    relation_words = re.compile(
        r'\b(extend|previous|our work|recent work|our recent|we show|we showed|'
        r'we demonstrate|we extend|we apply|we use|we compare|we find|'
        r'restricted to|was restricted|extends|applies|improve|generaliz|'
        r'build on|based on|following|show|compare|contrast|disagree|correct|refute)\b',
        re.IGNORECASE,
    )

    # Score each match: prefer ones near relation words AND prefer
    # occurrences that are not in big multi-cite groups (more specific)
    best_match = matches[0]
    best_score = -1
    for m in matches:
        cite_str = m.group(0)
        num_keys = cite_str.count(",") + 1  # how many keys in this cite
        window_start = max(0, m.start() - 500)
        window_end = min(len(tex_text), m.end() + 500)
        window = tex_text[window_start:window_end]
        rel_score = len(relation_words.findall(window))
        # Prefer fewer co-cited keys (more specific mention)
        score = rel_score * 3 + (10 - min(num_keys, 10))
        if score > best_score:
            best_score = score
            best_match = m

    cite_pos = best_match.start()

    # Also look for the preceding sentence before this citation
    # by searching backward for a sentence-ending period
    lead_start = max(0, cite_pos - 600)
    sent_search = tex_text[lead_start:cite_pos]
    # Find the last full stop before the citation
    last_period = sent_search.rfind(". ")
    if last_period > 0:
        # Back one more period for the preceding sentence
        prev_period = sent_search[:last_period].rfind(". ")
        if prev_period > 0:
            lead_start = lead_start + prev_period + 2
        else:
            lead_start = lead_start + last_period + 2

    start = lead_start
    end = min(len(tex_text), cite_pos + 500)

    # Extend to next sentence end for completeness
    rest = tex_text[cite_pos:end]
    next_period = rest.find(". ")
    if next_period > 50:
        end = cite_pos + next_period + 1

    raw = tex_text[start:end]

    # Strip comments
    raw = re.sub(r'(?<!\\)%.*', ' ', raw)

    # Replace \cite{...} with [CITE]; mark the target key specially
    raw = re.sub(
        r'\\cite\s*\{([^}]*)\}',
        lambda m: ' [TARGET] ' if key in [k.strip() for k in m.group(1).split(',')] else ' [cite] ',
        raw
    )

    # Handle common LaTeX formatting: preserve text content
    for cmd in ['textit', 'textbf', 'emph', 'mathrm', 'text']:
        raw = re.sub(r'\\' + cmd + r'\{([^}]*)\}', r'\1', raw)

    # Strip \ref, \label
    raw = re.sub(r'\\(?:ref|label)\{[^}]*\}', '', raw)

    # Strip remaining simple LaTeX commands
    raw = re.sub(r'\\[a-zA-Z]+\b', '', raw)
    raw = re.sub(r'\\[a-zA-Z]+\{[^}]*\}', '', raw)

    # Remove remaining braces
    raw = re.sub(r'[{}]', '', raw)

    # Collapse whitespace
    raw = re.sub(r'\s+', ' ', raw).strip()
    return raw[:900]


def resolve_cite_key_to_arxiv(cite_key, arxiv_id_set, surname_year_index, given_year_index, arxiv_meta):
    """Try to resolve a cite key to an arXiv ID.

    Returns list of (arxiv_id, confidence) tuples.
    """
    results = []

    # Pattern 1: conventional SurnameYYsuffix (e.g., Jin15b, Li84)
    m = RE_CITE_KEY_CONVENTIONAL.match(cite_key)
    if m:
        author_hint = m.group(1).lower()
        year_suffix = m.group(2)
        year_full = "20" + year_suffix if int(year_suffix) <= 30 else "19" + year_suffix
        surname_cands = set(surname_year_index.get((author_hint, year_full), []))
        given_cands = set(given_year_index.get((author_hint, year_full), []))
        all_cands = (surname_cands | given_cands)
        for aid in all_cands:
            if aid in arxiv_id_set:
                results.append((aid, "medium"))
        return results

    # Pattern 2: Name:YYYYsuffix (e.g., Potel:2015eqa, Moro2016)
    m = RE_CITE_KEY_COLON.match(cite_key)
    if m:
        author_hint = m.group(1).lower()
        year_full = m.group(2)
        surname_cands = set(surname_year_index.get((author_hint, year_full), []))
        given_cands = set(given_year_index.get((author_hint, year_full), []))
        all_cands = (surname_cands | given_cands)
        for aid in all_cands:
            if aid in arxiv_id_set:
                results.append((aid, "medium"))
        return results

    # Pattern 3: SurnameYearYYYY (e.g., Moro2016)
    m_s4 = re.match(r'^([a-zA-Z]+)(\d{4})([a-zA-Z]?)$', cite_key)
    if m_s4:
        author_hint = m_s4.group(1).lower()
        year_full = m_s4.group(2)
        surname_cands = set(surname_year_index.get((author_hint, year_full), []))
        for aid in surname_cands:
            if aid in arxiv_id_set:
                results.append((aid, "medium"))
        return results

    return results


def find_arxiv_in_text(tex_text, arxiv_id_set):
    """Find arXiv IDs present in tex text and resolve to canonical IDs."""
    found = set()
    for m in RE_BARE_ARXIV.finditer(tex_text):
        aid = resolve_arxiv_for_id(m.group(0), arxiv_id_set)
        if aid:
            found.add(aid)
    for m in RE_OLD_ARXIV.finditer(tex_text):
        aid = resolve_arxiv_for_id(m.group(0), arxiv_id_set)
        if aid:
            found.add(aid)
    for m in RE_NEW_ARXIV.finditer(tex_text):
        nid = m.group(1).split("v")[0] if "v" in m.group(1) else m.group(1)
        aid = resolve_arxiv_for_id(nid, arxiv_id_set)
        if aid:
            found.add(aid)
    return found


def find_doi_in_text(tex_text, doi_to_aid):
    """Find DOIs in tex text and map to arXiv IDs."""
    found = set()
    for m in RE_DOI.finditer(tex_text):
        doi_raw = m.group(1).strip().rstrip(".,;:)}")
        doi_lower = doi_raw.lower()
        if doi_lower in doi_to_aid:
            found.add(doi_to_aid[doi_lower])
    return found


def extract_contexts_for_citing(citing_aid, cited_aids, arxiv_meta, arxiv_id_set,
                                 surname_year_index, given_year_index, doi_to_aid):
    """For a citing paper A, extract citation context for each cited paper B.

    Returns dict: {cited_aid: context_string}
    """
    meta = arxiv_meta.get(citing_aid)
    if not meta:
        return {}
    tex_dir = meta.get("tex_dir")
    if not tex_dir or not os.path.isdir(tex_dir):
        return {b: "" for b in cited_aids}

    # Read all tex files
    full_text = ""
    for tf in sorted(os.listdir(tex_dir)):
        if tf.lower().endswith(".tex"):
            try:
                with open(os.path.join(tex_dir, tf), encoding="utf-8", errors="replace") as f:
                    full_text += f.read(2000000)
            except Exception:
                continue

    # Build cite key -> list of (arxiv_id, confidence) mapping
    cite_entries = parse_tex_cite_keys(full_text)
    cite_key_map = {}
    for key, spos, epos in cite_entries:
        if key not in cite_key_map:
            resolved = resolve_cite_key_to_arxiv(
                key, arxiv_id_set, surname_year_index, given_year_index, arxiv_meta
            )
            cite_key_map[key] = resolved

    # Also find arXiv IDs / DOIs directly in text
    text_arxiv_ids = find_arxiv_in_text(full_text, arxiv_id_set)
    text_doi_ids = find_doi_in_text(full_text, doi_to_aid)
    text_direct_ids = text_arxiv_ids | text_doi_ids

    # For each cited paper, try to find context
    contexts = {}
    for cited_aid in cited_aids:
        context = ""

        # Strategy 1: direct citation via cite key
        citing_keys = []
        for key, resolved_list in cite_key_map.items():
            for raid, _ in resolved_list:
                if raid == cited_aid:
                    citing_keys.append(key)
                    break

        if citing_keys:
            # Use the first key found
            context = extract_citation_context(full_text, citing_keys[0])

        # Strategy 2: if context empty, try the cited paper's arXiv ID appearing in text
        if not context and cited_aid in text_direct_ids:
            # Look for the arXiv ID in the text and extract context
            aid_str = cited_aid  # e.g., "1511.03214"
            idx = full_text.find(aid_str)
            if idx >= 0:
                # Extract surrounding sentence
                start = max(0, idx - 2000)
                end = min(len(full_text), idx + 200)
                snippet = full_text[start:end]
                # Try to find a sentence boundary
                context = _extract_sentence_snippet(snippet, aid_str)

        # Strategy 3: if still empty, search for author surname near "cite" context
        if not context:
            cited_meta = arxiv_meta.get(cited_aid)
            if cited_meta:
                author_surname = ""
                authors_str = cited_meta.get("authors", "")
                if authors_str:
                    first_auth = authors_str.split(";")[0].strip()
                    if "," in first_auth:
                        author_surname = first_auth.split(",")[0].strip()
                    else:
                        parts = first_auth.split()
                        author_surname = parts[-1] if parts else ""
                if author_surname:
                    # Search for sentences mentioning this author near citation marks
                    pat = re.compile(
                        r'([^.]*?\b' + re.escape(author_surname)
                        + r'\b[^.]*?\\cite\{[^}]*\}[^.]*\.)',
                        re.IGNORECASE,
                    )
                    m = pat.search(full_text)
                    if m:
                        raw = m.group(1)
                        raw = re.sub(r'\s+', ' ', raw)
                        raw = re.sub(r'\\[a-zA-Z]+(\{[^}]*\})*', '', raw)
                        raw = re.sub(r'[{}]', '', raw)
                        raw = re.sub(r'\s*~?\s*\\cite\s*\{[^}]*\}', ' [CITE] ', raw)
                        raw = re.sub(r'\s+', ' ', raw).strip()
                        context = raw[:800]

        contexts[cited_aid] = context

    return contexts


def _extract_sentence_snippet(text, target_str):
    """Extract the sentence-like region around target_str."""
    idx = text.find(target_str)
    if idx < 0:
        return ""
    # Walk back to sentence start
    start = idx
    for i in range(idx - 1, max(0, idx - 1500), -1):
        if text[i] in ".!?":
            start = i + 1
            break
    # Walk forward to sentence end
    end = idx + len(target_str)
    for i in range(end, min(len(text), end + 1500)):
        if text[i] in ".!?":
            end = i + 1
            break
    snippet = text[max(0, start - 500):end]
    snippet = re.sub(r'(?<!\\)%.*', '', snippet)
    snippet = re.sub(r'\s+', ' ', snippet)
    snippet = re.sub(r'\\[a-zA-Z]+(\{[^}]*\})*', '', snippet)
    snippet = re.sub(r'[{}]', '', snippet)
    snippet = re.sub(r'\s+', ' ', snippet).strip()
    return snippet[:800]


def load_citation_edges():
    """Load citation edges from citations.tsv and group by citing paper."""
    out_edges = defaultdict(set)
    with open(CITATIONS_TSV) as f:
        header = f.readline()
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) >= 2:
                out_edges[parts[0]].add(parts[1])
    return out_edges


def classify_relations(citing_aid, cited_entries, api_key, arxiv_meta):
    """Classify relations for one citing paper's citations via DeepSeek.

    cited_entries: list of (cited_aid, title, context_snippet)
    Returns: list of {cited, type, confidence, rationale}
    """
    citing_meta = arxiv_meta.get(citing_aid, {})
    citing_title = citing_meta.get("title", citing_aid)
    citing_abstract = citing_meta.get("abstract", "")

    items_text = []
    for i, (cited_aid, cited_title, context) in enumerate(cited_entries):
        ctx = context if context else "(no citation context extracted from tex)"
        # Clean up context: remove multiple [TARGET] markers (keep just one)
        ctx_clean = re.sub(r'\[TARGET\]\s*\[TARGET\]', '[TARGET]', ctx)
        items_text.append(
            f"{i + 1}. Paper: \"{cited_title}\"\n"
            f"   Citation context in {citing_aid}: {ctx_clean}"
        )

    prompt = f"""Task: classify the author-asserted relationship between a citing paper and each cited paper, based on the citation context from the citing paper's body text.

Citing paper: "{citing_title}"
Abstract: {citing_abstract[:2000]}

Below are the papers cited by this paper, with the citation context (the actual sentence from the citing paper's body text plus one preceding sentence). In each context, [TARGET] marks the citation to the paper being classified; [cite] marks citations to other papers.

For each item, output a JSON object with:
- type: one of "extends", "applies", "uses", "compares", "contrasts", "background"
- confidence: "high", "medium", or "low"
- rationale: one short clause quoting or paraphrasing the evidence (no em-dashes)

Rules:
- "extends": citing paper builds on / improves / generalizes the cited work's method or result. Examples: "we extend the method of [TARGET]", "building on [TARGET]", "unlike [TARGET] which was restricted to X, we generalize to Y", "our recent work [TARGET] showed".
- "applies": citing paper applies the cited framework/method to a new system or case. Example: "we apply the formalism of [TARGET] to".
- "uses": citing paper uses the cited work as a tool (code, potential, data, benchmark input). Examples: "data taken from [TARGET]", "using the potential of [TARGET]".
- "compares": citing paper benchmarks or compares against the cited work, neutrally.
- "contrasts": citing paper explicitly disagrees with, corrects, refutes, or finds tension with [TARGET]'s OWN claims, results, or conclusions. TWO cautions, both mean NOT contrasts for [TARGET]: (1) if the sentence says "Although [TARGET] claimed X, we showed Y", the contrast is the citing paper vs [TARGET], that IS contrasts; but if it says "Although some OTHER ref claimed X, [TARGET] showed Y", the contrast is with that other ref, and for [TARGET] the relation is 'extends' or 'uses'. (2) if [TARGET] is cited as EVIDENCE or SUPPORT for a claim against a THIRD party ("the HM formula is incomplete, as [TARGET] demonstrates"), the relation to [TARGET] is 'uses', not 'contrasts'; the disagreement is with the third party, not with [TARGET]. Only label 'contrasts' when the disagreement is with [TARGET] itself.
- "background": generic prior-art or contextual mention with no specific relationship asserted (DEFAULT when context is empty or a bare mention).
- No em-dashes in any rationale text.

Cited papers:
{chr(10).join(items_text)}

Return a JSON array of objects, one per cited paper, in the same order. Format: [{{"type": "...", "confidence": "...", "rationale": "..."}}, ...].
Return ONLY the JSON array, no other text."""

    req = urllib.request.Request(
        "https://api.deepseek.com/chat/completions",
        data=json.dumps({
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.0,
        }).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    resp = json.load(urllib.request.urlopen(req, timeout=60))
    content = resp["choices"][0]["message"]["content"]
    usage = resp.get("usage", {})

    # Parse the JSON response
    json_match = re.search(r'\[.*\]', content, re.DOTALL)
    if json_match:
        try:
            results = json.loads(json_match.group(0))
        except json.JSONDecodeError:
            results = []
    else:
        results = []

    # Map back to cited IDs
    output = []
    for i, (cited_aid, _, _) in enumerate(cited_entries):
        if i < len(results):
            r = results[i]
            output.append({
                "cited": cited_aid,
                "type": r.get("type", "background"),
                "confidence": r.get("confidence", "low"),
                "rationale": r.get("rationale", ""),
            })
        else:
            output.append({
                "cited": cited_aid,
                "type": "background",
                "confidence": "low",
                "rationale": "failed to parse response",
            })

    return output, usage


def inject_relations(relations_tsv_path, papers_dir, arxiv_meta):
    """Inject ## Related work sections into paper pages from relations tsv."""
    # Load relations
    relations = defaultdict(list)  # citing -> list of (cited, type, confidence, evidence)
    reverse = defaultdict(list)    # cited -> list of (citing, type, confidence, evidence, inverted type)

    type_inverse = {
        "extends": "Extended by",
        "applies": "Applied by",
        "uses": "Used by",
        "compares": "Compared by",
        "contrasts": "Contrasted by",
    }
    type_label = {
        "extends": "Extends",
        "applies": "Applies",
        "uses": "Uses",
        "compares": "Compares with",
        "contrasts": "Contrasts with",
    }

    with open(relations_tsv_path) as f:
        header = f.readline()
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) >= 5:
                citing, cited, rel_type, confidence, evidence = parts[0], parts[1], parts[2], parts[3], parts[4]
                if rel_type == "background":
                    continue
                relations[citing].append((cited, rel_type, confidence, evidence))
                inv_label = type_inverse.get(rel_type, "Related to")
                reverse[cited].append((citing, inv_label, confidence, evidence))

    all_touched = set(relations.keys()) | set(reverse.keys())
    updated = 0

    for arxiv_id in all_touched:
        safe_id = arxiv_id.replace("/", "_")
        md_path = papers_dir / f"{safe_id}.md"
        if not md_path.exists():
            continue

        with open(md_path) as f:
            content = f.read()

        # Build the Related work section
        section_lines = ["## Related work", ""]
        outgoing = relations.get(arxiv_id, [])
        incoming = reverse.get(arxiv_id, [])

        if outgoing:
            by_type = defaultdict(list)
            for cited, rel_type, conf, evid in outgoing:
                by_type[rel_type].append((cited, conf))
            for rel_type in ["extends", "applies", "uses", "compares", "contrasts"]:
                items = by_type.get(rel_type, [])
                if items:
                    label = type_label.get(rel_type, rel_type)
                    section_lines.append(f"**{label}:**")
                    for cited, conf in items:
                        cited_safe = cited.replace("/", "_")
                        cited_title = ""
                        cm = arxiv_meta.get(cited, {})
                        if cm:
                            cited_title = cm.get("title", cited)[:100]
                        conf_mark = {"high": "", "medium": " ~", "low": " ?"}.get(conf, "")
                        section_lines.append(
                            f"- [{cited}](../papers/{cited_safe}.md){conf_mark} -- {cited_title}"
                        )
                    section_lines.append("")

        if incoming:
            by_type = defaultdict(list)
            for citing, inv_label, conf, evid in incoming:
                by_type[inv_label].append((citing, conf))
            for inv_label in sorted(by_type.keys()):
                items = by_type[inv_label]
                section_lines.append(f"**{inv_label}:**")
                for citing, conf in items:
                    citing_safe = citing.replace("/", "_")
                    citing_title = ""
                    cm = arxiv_meta.get(citing, {})
                    if cm:
                        citing_title = cm.get("title", citing)[:100]
                    conf_mark = {"high": "", "medium": " ~", "low": " ?"}.get(conf, "")
                    section_lines.append(
                        f"- [{citing}](../papers/{citing_safe}.md){conf_mark} -- {citing_title}"
                    )
                section_lines.append("")

        if not outgoing and not incoming:
            section_lines.append("No typed semantic relations in sample.")
            section_lines.append("")

        new_section = "\n".join(section_lines)

        # Idempotent: replace existing section or insert before In-corpus citations
        if "## Related work" in content:
            pattern = r'## Related work\n.*?(?=\n## |\Z)'
            old_section = re.search(pattern, content, re.DOTALL)
            if old_section and old_section.group(0).rstrip() != new_section.strip():
                content = content.replace(old_section.group(0), new_section.strip())
                updated += 1
        elif "## In-corpus citations" in content:
            content = content.replace(
                "## In-corpus citations", new_section + "\n## In-corpus citations"
            )
            updated += 1
        else:
            content = content.rstrip() + "\n\n" + new_section
            updated += 1

        with open(md_path, "w") as f:
            f.write(content)

    return updated


def run_extract_and_classify(citing_aids, output_tsv, arxiv_meta, arxiv_id_set,
                              surname_year_index, given_year_index, doi_to_aid, api_key):
    """Extract contexts and classify relations for a list of citing papers."""
    out_edges = load_citation_edges()
    all_edges = []
    total_in = 0
    total_out = 0
    processed = 0

    with open(output_tsv, "w") as out_f:
        out_f.write("citing\tcited\ttype\tconfidence\tevidence\n")
        for citing_aid in citing_aids:
            cited_set = out_edges.get(citing_aid, set())
            if not cited_set:
                continue

            # Gather metadata for cited papers
            cited_entries = []
            for cited_aid in cited_set:
                cm = arxiv_meta.get(cited_aid, {})
                if not cm:
                    continue
                cited_entries.append((cited_aid, cm.get("title", cited_aid), ""))

            if not cited_entries:
                continue

            # Extract contexts
            contexts = extract_contexts_for_citing(
                citing_aid, cited_set, arxiv_meta, arxiv_id_set,
                surname_year_index, given_year_index, doi_to_aid
            )

            # Update entries with contexts
            entries_with_ctx = []
            for cited_aid, title, _ in cited_entries:
                entries_with_ctx.append((cited_aid, title, contexts.get(cited_aid, "")))

            # Classify
            for attempt in range(3):
                try:
                    results, usage = classify_relations(citing_aid, entries_with_ctx, api_key, arxiv_meta)
                    total_in += usage.get("prompt_tokens", 0)
                    total_out += usage.get("completion_tokens", 0)
                    break
                except Exception as e:
                    if attempt == 2:
                        print(f"  FAILED {citing_aid}: {e}", file=sys.stderr)
                        results = [{"cited": c, "type": "background", "confidence": "low",
                                    "rationale": f"API error: {str(e)[:100]}"}
                                  for c, _, _ in entries_with_ctx]
                    else:
                        time.sleep(15)

            for r in results:
                ev = r.get("rationale", "").replace("\t", " ").replace("\n", " ")
                out_f.write(f"{citing_aid}\t{r['cited']}\t{r['type']}\t{r['confidence']}\t{ev}\n")
                all_edges.append((citing_aid, r["cited"], r["type"], r["confidence"], ev))

            processed += 1
            if processed % 10 == 0:
                print(f"  Processed {processed}/{len(citing_aids)} papers, "
                      f"edges: {len(all_edges)}, tokens in={total_in} out={total_out}",
                      file=sys.stderr)

    return all_edges, total_in, total_out


# --- CLI ---

def cmd_extract(args):
    """Validate citation-context extractor on a specific edge (Step 1)."""
    meta_index = build_corpus_index()
    arxiv_meta, doi_to_aid, arxiv_id_set, surname_year_index, given_year_index = meta_index

    citing_aid = args.citing
    cited_aid = args.cited

    if citing_aid not in arxiv_id_set:
        sys.exit(f"Error: {citing_aid} not in corpus")
    if cited_aid not in arxiv_id_set:
        sys.exit(f"Error: {cited_aid} not in corpus")

    contexts = extract_contexts_for_citing(
        citing_aid, {cited_aid}, arxiv_meta, arxiv_id_set,
        surname_year_index, given_year_index, doi_to_aid
    )

    context = contexts.get(cited_aid, "")
    print(f"Citing: {citing_aid} -- {arxiv_meta[citing_aid].get('title', '')}")
    print(f"Cited:  {cited_aid} -- {arxiv_meta[cited_aid].get('title', '')}")
    print()
    print("Citation context extracted:")
    print("-" * 60)
    print(context if context else "(EMPTY -- context could not be located)")
    print("-" * 60)

    if not context:
        print("\nDEBUG: Context is empty. This may indicate the citation was resolved")
        print("through an external bibliography. Let's show the tex file analysis:")
        tex_dir = arxiv_meta[citing_aid].get("tex_dir", "")
        if tex_dir and os.path.isdir(tex_dir):
            full_text = ""
            for tf in sorted(os.listdir(tex_dir)):
                if tf.lower().endswith(".tex"):
                    with open(os.path.join(tex_dir, tf), encoding="utf-8", errors="replace") as f:
                        full_text += f.read(2000000)
            # Show cite keys found
            cite_entries = parse_tex_cite_keys(full_text)
            cite_keys = list(set(k for k, _, _ in cite_entries))
            print(f"\n  Found {len(cite_keys)} unique cite keys in tex")
            # Try to match each against cited paper's author
            cited_authors = arxiv_meta[cited_aid].get("authors", "")
            cited_first = cited_authors.split(";")[0].strip() if cited_authors else ""
            cited_year = (arxiv_meta[cited_aid].get("date", ""))[:4]
            print(f"  Cited paper first author: {cited_first}, year: {cited_year}")
            for key in sorted(cite_keys):
                resolved = resolve_cite_key_to_arxiv(
                    key, arxiv_id_set, surname_year_index, given_year_index, arxiv_meta
                )
                if resolved:
                    raids = [r[0] for r in resolved]
                    if cited_aid in raids:
                        print(f"  MATCH: \\cite{{{key}}} -> {cited_aid}")
                        ctx = extract_citation_context(full_text, key)
                        print(f"  Context: {ctx[:200]}")
                else:
                    # Show unresolved keys that might be relevant
                    if cited_year and cited_year in key:
                        print(f"  PARTIAL: \\cite{{{key}}} (contains year {cited_year})")


def cmd_calibrate(args):
    """Run classifier on the 5 calibration papers (Step 3)."""
    meta_index = build_corpus_index()
    arxiv_meta, doi_to_aid, arxiv_id_set, surname_year_index, given_year_index = meta_index
    api_key = load_api_key()

    cal_papers = ["1711.07540", "2101.09497", "2604.11226", "2605.03342", "1508.04822"]
    out_edges = load_citation_edges()

    print("=== FUSION L3-semantic: Calibration Run ===\n")

    all_results = []
    total_in = 0
    total_out = 0

    for citing_aid in cal_papers:
        cited_set = out_edges.get(citing_aid, set())
        if not cited_set:
            print(f"{citing_aid}: no in-corpus citations, skipping")
            continue

        entries_with_ctx = []
        for cited_aid in cited_set:
            cm = arxiv_meta.get(cited_aid, {})
            if not cm:
                continue
            entries_with_ctx.append((cited_aid, cm.get("title", cited_aid), ""))

        contexts = extract_contexts_for_citing(
            citing_aid, cited_set, arxiv_meta, arxiv_id_set,
            surname_year_index, given_year_index, doi_to_aid
        )

        full_entries = []
        for cited_aid, title, _ in entries_with_ctx:
            full_entries.append((cited_aid, title, contexts.get(cited_aid, "")))

        empty_count = sum(1 for _, _, c in full_entries if not c)
        print(f"\n{citing_aid}: {citing_aid in arxiv_meta and arxiv_meta[citing_aid].get('title', citing_aid)[:80]}")
        print(f"  {len(full_entries)} in-corpus citations ({empty_count} empty context)")

        results, usage = classify_relations(citing_aid, full_entries, api_key, arxiv_meta)
        total_in += usage.get("prompt_tokens", 0)
        total_out += usage.get("completion_tokens", 0)

        for r in results:
            evidence = r.get("rationale", "")
            all_results.append((citing_aid, r["cited"], r["type"], r["confidence"], evidence))
            print(f"  -> {r['cited']} | {r['type']} | {r['confidence']} | {evidence[:120]}")

    # Hard gate check
    print("\n=== HARD GATE ===")
    gate = False
    for citing, cited, rtype, conf, ev in all_results:
        if citing == "1711.07540" and cited == "1511.03214":
            print(f"1711.07540 -> 1511.03214: type={rtype} confidence={conf}")
            if rtype in ("extends", "applies"):
                print("GATE PASSED: type is extends or applies")
                gate = True
            else:
                print(f"GATE FAILED: type is {rtype}, expected extends or applies")
    if not gate:
        print("GATE NOT FOUND: edge 1711.07540 -> 1511.03214 was not classified")

    print(f"\nToken usage: in={total_in} out={total_out}")
    return gate


def cmd_sample(args):
    """Run classifier on 200 papers spanning reaction/structure/QCD (Step 4)."""
    n_papers = args.n or 200

    meta_index = build_corpus_index()
    arxiv_meta, doi_to_aid, arxiv_id_set, surname_year_index, given_year_index = meta_index
    api_key = load_api_key()
    out_edges = load_citation_edges()

    # Load classification.json to spread across concept areas
    concepts_path = KB_WIKI / "classification.json"
    if concepts_path.exists():
        with open(concepts_path) as f:
            classification = json.load(f)
    else:
        classification = {}

    # Define concept groups
    reaction_slugs = {
        "direct-reactions", "transfer-reactions", "breakup-reactions", "elastic-scattering-reactions",
        "knockout-reactions", "fusion-evaporation-reactions", "charge-exchange-reactions",
        "coulomb-excitation", "coulomb-dissociation", "photonuclear-reactions",
        "radiative-capture", "nuclear-reactions", "few-body-systems",
    }
    structure_slugs = {
        "shell-model", "ab-initio-calculations", "nuclear-forces", "nucleon-nucleon-interactions",
        "energy-levels", "collective-models", "cluster-models", "nuclear-binding",
        "shape-coexistence", "giant-resonances", "high-spin-states", "electromagnetic-transitions",
        "alpha-decay", "beta-decay", "double-beta-decay", "proton-emission",
        "nuclear-radii", "nuclear-charge-radii", "nuclear-matter", "symmetry-energy",
        "equations-of-state-of-nuclear-matter", "asymmetric-nuclear-matter",
        "neutron-skin-thickness", "effective-field-theory", "chiral-perturbation-theory",
    }
    qcd_slugs = {
        "quantum-chromodynamics", "perturbative-qcd", "lattice-qcd", "lattice-gauge-theory",
        "qcd-phenomenology", "quark-gluon-plasma", "jet-quenching", "hard-scattering",
        "parton-distribution-functions", "generalized-parton-distributions",
        "transverse-momentum-dependent-distribution", "spin-dependent-parton-distribution-functions",
        "fragmentation-functions", "heavy-quark-effective-theory", "nonrelativistic-qcd",
        "color-deconfinement", "color-confinement", "quark-model",
        "relativistic-heavy-ion-collisions", "hydrodynamic-models", "transport-in-heavy-ion-collisions",
        "qcd-phase-transitions", "electron-ion-collisions", "spin", "nucleon-spin-structure",
    }

    def categorize(aid):
        tags = classification.get(aid, [])
        slugs = {t["slug"] for t in tags}
        reaction = bool(slugs & reaction_slugs)
        structure = bool(slugs & structure_slugs)
        qcd = bool(slugs & qcd_slugs)
        if reaction and not structure and not qcd:
            return "reaction"
        elif structure and not qcd:
            return "structure"
        elif qcd and not structure:
            return "qcd"
        elif reaction:
            return "reaction"
        elif structure:
            return "structure"
        else:
            return "other"

    # Get all citing papers with outgoing edges
    citing_with_edges = sorted(out_edges.keys())
    categorized = defaultdict(list)
    for aid in citing_with_edges:
        categorized[categorize(aid)].append(aid)

    print(f"Citing papers with edges: {len(citing_with_edges)}")
    for cat in ["reaction", "structure", "qcd", "other"]:
        print(f"  {cat}: {len(categorized[cat])}")

    # Pick balanced sample
    per_cat = n_papers // 3
    sample = []
    for cat in ["reaction", "structure", "qcd"]:
        sample.extend(categorized[cat][:per_cat])
    # Fill with other if needed
    while len(sample) < n_papers:
        remaining = n_papers - len(sample)
        sample.extend(categorized["other"][:remaining])

    sample = list(dict.fromkeys(sample))[:n_papers]
    print(f"\nSample: {len(sample)} papers")

    # Run
    output_tsv = RELATIONS_TSV
    all_edges, total_in, total_out = run_extract_and_classify(
        sample, output_tsv, arxiv_meta, arxiv_id_set,
        surname_year_index, given_year_index, doi_to_aid, api_key
    )

    # Write report
    report_path = KB_WIKI / "semantic-report.md"
    type_counts = defaultdict(int)
    conf_counts = defaultdict(int)
    contrasts = []
    empty_ctx = 0
    for e in all_edges:
        type_counts[e[2]] += 1
        conf_counts[e[3]] += 1
        if not e[4] or e[4].startswith("(no citation context"):
            empty_ctx += 1
        if e[2] == "contrasts":
            contrasts.append(e)

    total_edges = len(all_edges)
    background_count = type_counts.get("background", 0)
    kept = total_edges - background_count
    bg_pct = background_count / max(total_edges, 1) * 100

    # Cost extrapolation
    # deepseek-chat pricing: $0.14/1M in, $0.28/1M out (standard); $0.07/$0.14 off-peak
    full_edges = 351338
    scale_factor = full_edges / max(total_edges, 1)
    est_cost_standard = (total_in / 1e6 * 0.14 + total_out / 1e6 * 0.28) * scale_factor
    est_cost_offpeak = (total_in / 1e6 * 0.07 + total_out / 1e6 * 0.14) * scale_factor

    report = f"""# FUSION L3-semantic sample run report

## Summary

- Edges processed: {total_edges}
- Citing papers: {len(sample)}
- Type distribution:
"""
    for t in ["extends", "applies", "uses", "compares", "contrasts", "background"]:
        c = type_counts.get(t, 0)
        pct = c / max(total_edges, 1) * 100
        report += f"  - {t}: {c} ({pct:.1f}%)\n"

    report += f"""
- Discarded as background: {background_count} ({bg_pct:.1f}%)
- Kept (non-background): {kept} ({100 - bg_pct:.1f}%)

## Confidence distribution

- High: {conf_counts.get('high', 0)} ({conf_counts.get('high', 0) / max(total_edges, 1) * 100:.1f}%)
- Medium: {conf_counts.get('medium', 0)} ({conf_counts.get('medium', 0) / max(total_edges, 1) * 100:.1f}%)
- Low: {conf_counts.get('low', 0)} ({conf_counts.get('low', 0) / max(total_edges, 1) * 100:.1f}%)

## Calibration edges

"""
    # Rerun calibration to show in report
    cal_papers = ["1711.07540", "2101.09497", "2604.11226", "2605.03342", "1508.04822"]
    for citing_aid in cal_papers:
        cited_set = out_edges.get(citing_aid, set())
        if not cited_set:
            report += f"{citing_aid}: no in-corpus citations\n\n"
            continue
        report += f"### {citing_aid}\n\n"
        for e in all_edges:
            if e[0] == citing_aid:
                report += f"- {e[0]} -> {e[1]} | {e[2]} | {e[3]} | {e[4][:200]}\n"
        report += "\n"

    report += f"""## Contrasts edges (spot-check)

"""
    if contrasts:
        for e in contrasts[:20]:
            report += f"- {e[0]} -> {e[1]} | {e[3]} | {e[4][:200]}\n"
        report += "\n"
    else:
        report += "No contrasts edges found.\n\n"

    report += f"""## Token usage and cost

- Sample tokens: in={total_in} out={total_out}
- Extrapolated full 351k-edge run:
  - Standard price: ${est_cost_standard:.1f}
  - Off-peak price: ${est_cost_offpeak:.1f}

## Failure modes

- Edges with empty context (external bibliography / unresolved key): {empty_ctx} ({empty_ctx / max(total_edges, 1) * 100:.1f}%)
"""

    report_path.write_text(report)
    print(f"\nReport written to {report_path}")
    print(report)


def cmd_inject(args):
    """Inject ## Related work sections from relations tsv into paper pages (Step 5)."""
    meta_index = build_corpus_index()
    arxiv_meta = meta_index[0]

    relations_path = args.relations_tsv or RELATIONS_TSV
    if not Path(relations_path).exists():
        sys.exit(f"Relations file not found: {relations_path}")

    updated = inject_relations(relations_path, PAPERS_DIR, arxiv_meta)
    print(f"Updated {updated} paper pages with Related work sections")

    # Show 3 examples
    with open(relations_path) as f:
        lines = f.readlines()[1:]  # skip header

    # Find first few unique citing papers to show as examples
    shown = set()
    count = 0
    print("\n=== Example pages ===")
    for line in lines:
        parts = line.strip().split("\t")
        if len(parts) < 2:
            continue
        citing = parts[0]
        if citing not in shown:
            shown.add(citing)
            md_path = PAPERS_DIR / f"{citing}.md"
            if md_path.exists():
                content = md_path.read_text()
                if "## Related work" in content:
                    start = content.index("## Related work")
                    end = content.find("\n## ", start + 5)
                    if end == -1:
                        end = min(len(content), start + 1500)
                    snippet = content[start:end]
                    print(f"\n--- {citing}.md ---")
                    print(snippet[:600])
                    count += 1
                    if count >= 3:
                        break


def cmd_full(args):
    """Full-corpus classification, parallel + resumable (Step: maintainer run)."""
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading

    out_tsv = args.out or str(KB_WIKI / "relations.tsv")
    workers = args.workers
    out_edges = load_citation_edges()

    citing_all = [a for a, cited in out_edges.items() if cited]
    citing_all.sort()

    done = set()
    if Path(out_tsv).exists():
        with open(out_tsv) as f:
            next(f, None)
            for line in f:
                p = line.split("\t", 1)
                if p:
                    done.add(p[0])
    todo = [a for a in citing_all if a not in done]

    if getattr(args, "count_only", False):
        # Cheap resumability probe for the launcher; runs NO classification.
        print(f"{len(todo)} to go", flush=True)
        return
    print(f"full: {len(citing_all)} citing papers, {len(done)} done, {len(todo)} to go, {workers} workers", flush=True)

    meta_index = build_corpus_index()
    arxiv_meta, doi_to_aid, arxiv_id_set, surname_year_index, given_year_index = meta_index
    api_key = load_api_key()

    lock = threading.Lock()
    stats = {"n": 0, "edges": 0, "in": 0, "out": 0}
    header_needed = not Path(out_tsv).exists()
    out_f = open(out_tsv, "a")
    if header_needed:
        out_f.write("citing\tcited\ttype\tconfidence\tevidence\n")

    def work(citing_aid):
        cited_set = out_edges.get(citing_aid, set())
        entries = []
        for cited_aid in cited_set:
            cm = arxiv_meta.get(cited_aid, {})
            if cm:
                entries.append((cited_aid, cm.get("title", cited_aid), ""))
        if not entries:
            return citing_aid, [], 0, 0
        if getattr(args, "no_context", False):
            ewc = [(c, t, "") for c, t, _ in entries]
        else:
            contexts = extract_contexts_for_citing(
                citing_aid, cited_set, arxiv_meta, arxiv_id_set,
                surname_year_index, given_year_index, doi_to_aid)
            ewc = [(c, t, contexts.get(c, "")) for c, t, _ in entries]
        for attempt in range(3):
            try:
                results, usage = classify_relations(citing_aid, ewc, api_key, arxiv_meta)
                return citing_aid, results, usage.get("prompt_tokens", 0), usage.get("completion_tokens", 0)
            except Exception:
                if attempt == 2:
                    # Mark the paper done with a background fallback so it is not
                    # retried forever (poison papers otherwise block every window).
                    fallback = [{"cited": c, "type": "background", "confidence": "low",
                                 "rationale": "classification failed after retries"}
                                for c, _, _ in ewc]
                    return citing_aid, fallback, 0, 0
                time.sleep(5)

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(work, a): a for a in todo}
        for fut in as_completed(futs):
            citing_aid, results, ti, to = fut.result()
            with lock:
                for r in results:
                    ev = r.get("rationale", "").replace("\t", " ").replace("\n", " ")
                    out_f.write(f"{citing_aid}\t{r['cited']}\t{r['type']}\t{r['confidence']}\t{ev}\n")
                    stats["edges"] += 1
                out_f.flush()
                stats["n"] += 1
                stats["in"] += ti
                stats["out"] += to
                if stats["n"] % 100 == 0:
                    print(f"  {stats['n']}/{len(todo)} papers, {stats['edges']} edges, "
                          f"in={stats['in']} out={stats['out']}", flush=True)
    out_f.close()
    print(f"DONE full: {stats['n']} papers, {stats['edges']} edges, in={stats['in']} out={stats['out']}", flush=True)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="FUSION L3-semantic relation layer")
    sub = ap.add_subparsers(dest="command")

    p_extract = sub.add_parser("extract", help="Validate citation-context extractor")
    p_extract.add_argument("citing")
    p_extract.add_argument("cited")

    p_calibrate = sub.add_parser("calibrate", help="Calibrate on maintainer's 5 papers")

    p_sample = sub.add_parser("sample", help="Run 200-paper sample")
    p_sample.add_argument("--n", type=int, default=200)

    p_inject = sub.add_parser("inject", help="Inject Related work sections into pages")
    p_inject.add_argument("--relations-tsv", default=None)

    p_full = sub.add_parser("full", help="Full-corpus classify, parallel + resumable")
    p_full.add_argument("--workers", type=int, default=32)
    p_full.add_argument("--out", default=None)
    p_full.add_argument("--count-only", action="store_true", help="Print remaining count and exit, no classification")
    p_full.add_argument("--no-context", action="store_true", help="Skip .tex context extraction (titles+abstracts only); use for backfill papers whose .tex has no inline cites")

    args = ap.parse_args()

    if args.command == "extract":
        cmd_extract(args)
    elif args.command == "calibrate":
        ok = cmd_calibrate(args)
        sys.exit(0 if ok else 1)
    elif args.command == "sample":
        cmd_sample(args)
    elif args.command == "inject":
        cmd_inject(args)
    elif args.command == "full":
        cmd_full(args)
    else:
        ap.print_help()
