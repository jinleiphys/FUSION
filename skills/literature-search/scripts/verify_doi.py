#!/usr/bin/env python3
"""Verify a DOI against the CrossRef API and print canonical metadata.

Usage:
    python verify_doi.py <DOI>

Exits 0 on success and prints a JSON block with verified fields.
Exits 1 if the DOI is invalid or CrossRef returns no record.
Exits 2 on network or parsing errors.
"""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import sys
import urllib.error
import urllib.parse
import urllib.request


CROSSREF_WORKS = "https://api.crossref.org/works/"
CACHE_DIR = pathlib.Path(
    os.environ.get("LITSEARCH_CACHE", pathlib.Path.home() / ".cache" / "literature-search")
)


def cache_path(doi: str) -> pathlib.Path:
    h = hashlib.sha256(doi.encode("utf-8")).hexdigest()[:16]
    return CACHE_DIR / f"crossref_{h}.json"


def fetch_crossref(doi: str, use_cache: bool = True) -> dict:
    if use_cache:
        cp = cache_path(doi)
        if cp.exists():
            return json.loads(cp.read_text())
    url = CROSSREF_WORKS + urllib.parse.quote(doi, safe="/:")
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "literature-search-skill/1.0"
            + (f" (mailto:{os.environ['CROSSREF_MAILTO']})" if os.environ.get("CROSSREF_MAILTO") else "")
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = resp.read().decode("utf-8")
    parsed = json.loads(data)
    if use_cache:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache_path(doi).write_text(data)
    return parsed


def normalize(record: dict) -> dict:
    msg = record.get("message", {})
    authors = []
    for a in msg.get("author", []) or []:
        given = a.get("given", "").strip()
        family = a.get("family", "").strip()
        if family:
            authors.append(f"{family}, {given}" if given else family)
    issued = msg.get("issued", {}).get("date-parts", [[None]])[0]
    year = issued[0] if issued else None
    return {
        "doi": msg.get("DOI"),
        "title": (msg.get("title") or [""])[0],
        "authors": authors,
        "journal": (msg.get("container-title") or [""])[0],
        "volume": msg.get("volume"),
        "pages": msg.get("page"),
        "year": year,
        "publisher": msg.get("publisher"),
        "url": msg.get("URL"),
    }


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: python verify_doi.py <DOI>", file=sys.stderr)
        return 2
    doi = argv[1].strip()
    # Strip common prefixes users paste
    for prefix in ("https://doi.org/", "http://doi.org/", "doi:"):
        if doi.lower().startswith(prefix):
            doi = doi[len(prefix):]
    try:
        record = fetch_crossref(doi)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"DOI not found in CrossRef: {doi}", file=sys.stderr)
            return 1
        print(f"HTTP error {e.code} from CrossRef: {e.reason}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"Network error: {e.reason}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"CrossRef returned non-JSON: {e}", file=sys.stderr)
        return 2
    info = normalize(record)
    print(json.dumps(info, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
