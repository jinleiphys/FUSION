#!/usr/bin/env python3
"""Search arXiv via its Atom API and print normalized JSON.

Usage:
    python arxiv_search.py "ti:post-prior AND au:Lei"
    python arxiv_search.py --id 1712.02005
    python arxiv_search.py --size 5 "cat:nucl-th AND abs:trojan horse"

The arXiv query syntax is documented at
https://info.arxiv.org/help/api/user-manual.html

Exits 0 on success. Emits a JSON list of normalized records to stdout.
Each record has: arxiv_id, title, authors, abstract, published, updated,
primary_category, journal_ref (if published), doi (if known), url.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


API = "https://export.arxiv.org/api/query"
ATOM_NS = {"a": "http://www.w3.org/2005/Atom", "arxiv": "http://arxiv.org/schemas/atom"}


def fetch(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "literature-search-skill/1.0"},
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read().decode("utf-8")


def _text(elem, path: str) -> str | None:
    node = elem.find(path, ATOM_NS)
    if node is None or node.text is None:
        return None
    return re.sub(r"\s+", " ", node.text).strip()


def _all_text(elem, path: str) -> list[str]:
    out = []
    for node in elem.findall(path, ATOM_NS):
        if node.text:
            out.append(re.sub(r"\s+", " ", node.text).strip())
    return out


def extract_arxiv_id(id_url: str) -> str:
    # id is of form http://arxiv.org/abs/1712.02005v1
    m = re.search(r"arxiv\.org/abs/([\d\.]+)(v\d+)?", id_url)
    if m:
        return m.group(1)
    return id_url


def parse_atom(xml_text: str) -> list[dict]:
    root = ET.fromstring(xml_text)
    out = []
    for entry in root.findall("a:entry", ATOM_NS):
        id_url = _text(entry, "a:id") or ""
        arxiv_id = extract_arxiv_id(id_url)
        authors = _all_text(entry, "a:author/a:name")
        primary_cat = None
        cat_node = entry.find("arxiv:primary_category", ATOM_NS)
        if cat_node is not None:
            primary_cat = cat_node.attrib.get("term")
        doi = _text(entry, "arxiv:doi")
        journal_ref = _text(entry, "arxiv:journal_ref")
        out.append(
            {
                "arxiv_id": arxiv_id,
                "title": _text(entry, "a:title"),
                "authors": authors,
                "abstract": _text(entry, "a:summary"),
                "published": _text(entry, "a:published"),
                "updated": _text(entry, "a:updated"),
                "primary_category": primary_cat,
                "journal_ref": journal_ref,
                "doi": doi,
                "url": f"https://arxiv.org/abs/{arxiv_id}",
            }
        )
    return out


def search(query: str, size: int) -> list[dict]:
    q = urllib.parse.quote(query)
    url = f"{API}?search_query={q}&start=0&max_results={size}"
    return parse_atom(fetch(url))


def fetch_by_id(arxiv_id: str) -> list[dict]:
    url = f"{API}?id_list={urllib.parse.quote(arxiv_id)}"
    return parse_atom(fetch(url))


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("query", nargs="?", help="arXiv search query")
    p.add_argument("--size", type=int, default=10, help="max results (default 10)")
    p.add_argument("--id", dest="arxiv_id", help="fetch one preprint by arXiv ID")
    args = p.parse_args(argv[1:])

    try:
        if args.arxiv_id:
            records = fetch_by_id(args.arxiv_id)
        elif args.query:
            records = search(args.query, args.size)
        else:
            p.print_help(sys.stderr)
            return 2
    except urllib.error.HTTPError as e:
        print(f"HTTP error {e.code}: {e.reason}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"Network error: {e.reason}", file=sys.stderr)
        return 2
    except ET.ParseError as e:
        print(f"Invalid Atom XML from arXiv: {e}", file=sys.stderr)
        return 2

    print(json.dumps(records, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
