#!/usr/bin/env python3
"""Search INSPIRE-HEP via its public REST API and print normalized JSON.

Usage:
    python inspire_search.py "a:Lei and a:Moro and de:2018"
    python inspire_search.py --size 5 "t:trojan horse and de > 2020"
    python inspire_search.py --recid 1643611
    python inspire_search.py --doi 10.1103/PhysRevC.97.011601

The INSPIRE query syntax is documented at
https://help.inspirehep.net/knowledge-base/inspire-search/

Exits 0 on success. Emits a JSON list of normalized records to stdout.
Each record has: control_number, title, authors, journal, volume, pages,
year, doi, arxiv_id, abstract, url.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request


API = "https://inspirehep.net/api/literature"
FIELDS = "titles,authors,publication_info,arxiv_eprints,dois,control_number,abstracts"


def fetch(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "literature-search-skill/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def normalize(metadata: dict) -> dict:
    titles = metadata.get("titles") or []
    title = titles[0].get("title", "") if titles else ""
    authors = []
    for a in metadata.get("authors") or []:
        name = a.get("full_name") or a.get("last_name", "")
        if name:
            authors.append(name)
    pub = (metadata.get("publication_info") or [{}])[0]
    dois = metadata.get("dois") or []
    doi = dois[0].get("value") if dois else None
    arxs = metadata.get("arxiv_eprints") or []
    arxiv_id = arxs[0].get("value") if arxs else None
    abstracts = metadata.get("abstracts") or []
    abstract = abstracts[0].get("value") if abstracts else None
    recid = metadata.get("control_number")
    return {
        "control_number": recid,
        "title": title,
        "authors": authors,
        "journal": pub.get("journal_title"),
        "volume": pub.get("journal_volume"),
        "pages": pub.get("page_start") or pub.get("artid"),
        "year": pub.get("year"),
        "doi": doi,
        "arxiv_id": arxiv_id,
        "abstract": abstract,
        "url": f"https://inspirehep.net/literature/{recid}" if recid else None,
    }


def search(query: str, size: int) -> list[dict]:
    q = urllib.parse.quote(query)
    url = f"{API}?q={q}&size={size}&fields={FIELDS}&format=json"
    data = fetch(url)
    hits = (data.get("hits") or {}).get("hits") or []
    return [normalize(h.get("metadata", {})) for h in hits]


def fetch_by_recid(recid: str) -> list[dict]:
    url = f"{API}/{recid}?fields={FIELDS}&format=json"
    data = fetch(url)
    return [normalize(data.get("metadata", {}))]


def fetch_by_doi(doi: str) -> list[dict]:
    # INSPIRE supports /api/doi/<DOI> for direct resolution
    url = f"https://inspirehep.net/api/doi/{urllib.parse.quote(doi, safe='/:')}"
    try:
        data = fetch(url)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []
        raise
    return [normalize(data.get("metadata", {}))]


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("query", nargs="?", help="INSPIRE search query")
    p.add_argument("--size", type=int, default=10, help="max results (default 10)")
    p.add_argument("--recid", help="fetch a single record by INSPIRE control number")
    p.add_argument("--doi", help="fetch a single record by DOI")
    args = p.parse_args(argv[1:])

    try:
        if args.recid:
            records = fetch_by_recid(args.recid)
        elif args.doi:
            records = fetch_by_doi(args.doi)
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
    except json.JSONDecodeError as e:
        print(f"Invalid JSON from INSPIRE: {e}", file=sys.stderr)
        return 2

    print(json.dumps(records, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
