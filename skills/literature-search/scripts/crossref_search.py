#!/usr/bin/env python3
"""Search CrossRef by title, journal, author, and year. Print normalized JSON.

Usage:
    python crossref_search.py --title "19F p alpha 16O" --journal "Physical Review Letters"
    python crossref_search.py --title "CNO breakout first stars" --journal "Nature" --year-from 2020
    python crossref_search.py --author "La Cognata" --year-from 2024

CrossRef's API is canonical for DOI metadata and is indispensable when INSPIRE-HEP
has not yet indexed a recent paper or does not cover the venue (e.g., Nature, Science,
Nature Astronomy for nuclear astrophysics). Exits 0 on success. Emits a JSON array
of normalized records sorted by relevance.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


API = "https://api.crossref.org/works"


def build_url(args) -> str:
    params = []
    if args.title:
        params.append(("query.title", args.title))
    if args.journal:
        params.append(("query.container-title", args.journal))
    if args.author:
        params.append(("query.author", args.author))
    filters = []
    if args.year_from:
        filters.append(f"from-pub-date:{args.year_from}")
    if args.year_to:
        filters.append(f"until-pub-date:{args.year_to}")
    if filters:
        params.append(("filter", ",".join(filters)))
    params.append(("rows", str(args.size)))
    params.append(("select", "DOI,title,author,container-title,volume,page,published-print,published-online,issued,type"))
    qs = urllib.parse.urlencode(params)
    return f"{API}?{qs}"


def fetch(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "literature-search-skill/1.0"
            + (f" (mailto:{os.environ['CROSSREF_MAILTO']})" if os.environ.get("CROSSREF_MAILTO") else "")
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def normalize(item: dict) -> dict:
    authors = []
    for a in item.get("author", []) or []:
        family = (a.get("family") or "").strip()
        given = (a.get("given") or "").strip()
        if family:
            authors.append(f"{family}, {given}" if given else family)
    issued_parts = (item.get("issued") or {}).get("date-parts", [[None]])[0]
    year = issued_parts[0] if issued_parts else None
    # Prefer print year over online year if both present
    if item.get("published-print"):
        ppp = item["published-print"].get("date-parts", [[None]])[0]
        if ppp and ppp[0]:
            year = ppp[0]
    return {
        "doi": item.get("DOI"),
        "title": (item.get("title") or [""])[0],
        "authors": authors,
        "n_authors": len(authors),
        "journal": (item.get("container-title") or [""])[0],
        "volume": item.get("volume"),
        "pages": item.get("page"),
        "year": year,
        "type": item.get("type"),
        "url": f"https://doi.org/{item.get('DOI')}" if item.get("DOI") else None,
    }


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--title", help="title keywords")
    p.add_argument("--journal", help="journal / container-title")
    p.add_argument("--author", help="author surname")
    p.add_argument("--year-from", type=int, help="earliest publication year")
    p.add_argument("--year-to", type=int, help="latest publication year")
    p.add_argument("--size", type=int, default=10, help="max results (default 10)")
    args = p.parse_args(argv[1:])

    if not (args.title or args.journal or args.author):
        p.error("at least one of --title, --journal, --author is required")

    try:
        data = fetch(build_url(args))
    except urllib.error.HTTPError as e:
        print(f"HTTP error {e.code}: {e.reason}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"Network error: {e.reason}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"Invalid JSON from CrossRef: {e}", file=sys.stderr)
        return 2

    items = (data.get("message") or {}).get("items", [])
    records = [normalize(it) for it in items]
    print(json.dumps(records, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
