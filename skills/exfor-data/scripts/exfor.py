#!/usr/bin/env python3
"""
exfor.py - retrieve and parse experimental nuclear reaction data from the IAEA
EXFOR database.

Three subcommands:
    fetch <ACC>        download entry ACC (5 digits) and cache the raw EXFOR text
    list  <ACC>        show every subentry: ID, REACTION, energies, number of points
    data  <SUBENT>     print one subentry's data table as clean numeric columns

Why this exists: EXFOR's interactive search servlet cannot be driven from a
script (it always answers "Define Search Criteria!"), but the per-entry
retrieval servlet works fine over plain HTTP. So the workflow is: find the
accession number some other way, then pull the entry with this tool.

The parser uses EXFOR's real fixed-width layout (6 fields of 11 characters per
line, wrapping for wider tables). This matters: a blank field means "no value"
and whitespace-splitting silently shifts every later column into the wrong slot.

No third-party dependencies.
"""

import argparse
import math
import os
import re
import sys
import urllib.request

def warn(msg):
    """Parse-integrity warnings go to stderr so they never contaminate piped data."""
    print(f"warning: {msg}", file=sys.stderr)


BASE = "https://www-nds.iaea.org/exfor//servlet/X4sGetEntry?acc={acc}&reqx=1"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Safari/537.36"
FIELD = 11          # EXFOR field width
PER_LINE = 6        # fields per physical line
DEFAULT_CACHE = os.path.expanduser("~/.cache/exfor")


# --------------------------------------------------------------------------
# retrieval
# --------------------------------------------------------------------------
def strip_html(raw):
    raw = re.sub(r"(?is)<(script|style).*?</\1>", " ", raw)
    raw = re.sub(r"(?s)<[^>]*>", "", raw)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"),
                 ("&gt;", ">"), ("&quot;", '"')):
        raw = raw.replace(a, b)
    return raw


def fetch(acc, cache=DEFAULT_CACHE, refresh=False):
    """Download entry `acc`, cache the de-HTMLed EXFOR text, return it."""
    acc = str(acc).strip()
    os.makedirs(cache, exist_ok=True)
    path = os.path.join(cache, f"{acc}.txt")
    if os.path.exists(path) and not refresh:
        return open(path, encoding="utf-8", errors="replace").read(), path
    req = urllib.request.Request(BASE.format(acc=acc), headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        raw = r.read().decode("utf-8", errors="replace")
    text = strip_html(raw)
    if "SUBENT" not in text:
        raise SystemExit(
            f"No SUBENT found in the response for accession '{acc}'.\n"
            "Check the accession number. Note the EXFOR *search* servlet cannot be\n"
            "scripted; accession numbers must be found via literature or web search."
        )
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return text, path


# --------------------------------------------------------------------------
# parsing
# --------------------------------------------------------------------------
def split_fields(chunk, ncols):
    """Split one logical record of `ncols` fixed-width fields, honouring blanks.

    `chunk` is the list of physical lines making up the record. A field that is
    all spaces stays empty rather than disappearing, which is the whole point:
    EXFOR uses blanks for "not measured", and collapsing them shifts columns.
    """
    out = []
    for i in range(ncols):
        li, fi = divmod(i, PER_LINE)
        seg = chunk[li][fi * FIELD:(fi + 1) * FIELD] if li < len(chunk) else ""
        out.append(seg.strip())
    return out


def _block(lines, i, ncols, nrec):
    """Read `nrec` records of `ncols` fixed-width fields starting at lines[i]."""
    per = math.ceil(ncols / PER_LINE)
    recs = []
    for r in range(nrec):
        chunk = lines[i + r * per: i + (r + 1) * per]
        if len(chunk) < per:
            break
        recs.append(split_fields(chunk, ncols))
    return recs, i + nrec * per


def parse_subentries(text):
    """Return a list of subentry dicts with bib, common and data tables."""
    lines = text.splitlines()
    subs, cur = [], None
    i = 0
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("SUBENT"):
            cur = {"id": ln.split()[1], "bib": {}, "common": {}, "data": {}}
            subs.append(cur)
            i += 1
            continue
        if cur is None:
            i += 1
            continue

        # BIB keywords: keyword starts in column 1, continuation lines are indented
        if ln.startswith(("REACTION", "TITLE", "SAMPLE", "STATUS", "INC-SOURCE",
                          "AUTHOR", "REFERENCE", "MONITOR", "ERR-ANALYS")):
            key = ln.split()[0]
            val = [ln[len(key):].strip()]
            j = i + 1
            while j < len(lines) and lines[j].startswith(" " * 11) and lines[j].strip():
                val.append(lines[j].strip())
                j += 1
            cur["bib"].setdefault(key, []).append(" ".join(v for v in val if v))
            i = j
            continue

        m = re.match(r"^(COMMON|DATA)\s+(\d+)\s+(\d+)", ln)
        if m:
            kind, ncols, declared = m.group(1), int(m.group(2)), int(m.group(3))
            per = math.ceil(ncols / PER_LINE)
            names, k = _block(lines, i + 1, ncols, 1)
            units, k = _block(lines, k, ncols, 1)
            names, units = names[0], units[0]
            # count real records up to END{kind}
            end = k
            while end < len(lines) and not lines[end].startswith("END" + kind):
                end += 1
            found = end - k
            nrec = max(0, found // per)
            rows, _ = _block(lines, k, ncols, nrec)
            # The header count is a free integrity check, and the only cheap way to
            # catch a truncated or misaligned table: a wrapped record missing its
            # continuation line otherwise just disappears, leaving a short table
            # that looks perfectly well formed.
            #
            # EXFOR does not use N2 consistently, so the expectation depends on the
            # block. COMMON counts the heading and units records too ("COMMON 2 3"
            # carries a single line of values), while DATA counts only the data lines
            # ("DATA 3 37" is 37 points, with ENDDATA reporting 39).
            #
            # These are checked separately rather than by accepting either reading.
            # Accepting both looks tolerant but is unsound: on a table with two lines
            # per record, losing one entire wrapped record moves `found` to exactly
            # declared - 2, which the permissive test reads as the COMMON convention
            # and waves through. Being specific is what makes the check load-bearing.
            expected = declared - 2 if kind == "COMMON" else declared
            if found != expected or nrec * per != found:
                warn(f"{cur['id']} {kind}: header declares {declared} data line(s) "
                     f"but {found} found ({ncols} columns, {per} line(s) per record, "
                     f"{len(rows)} record(s) parsed). Table may be truncated; "
                     f"verify against the raw entry before using these numbers.")
            tbl = {"names": names, "units": units, "rows": rows,
                   "declared_lines": declared, "found_lines": found}
            cur[kind.lower()] = tbl
            i = end + 1
            continue
        i += 1
    return [s for s in subs if s["bib"] or s["data"]]


def col(tbl, name):
    """Index of a column by exact name, else None."""
    return tbl["names"].index(name) if name in tbl["names"] else None


def entry_common(subs):
    """COMMON block of subentry xxx001, which applies to every subentry in the entry.

    EXFOR hoists quantities that are constant across a whole experiment (often the
    incident energy, or a monitor normalization) into the first subentry. Ignoring
    it makes those values look missing everywhere they actually matter.
    """
    for s in subs:
        if s["id"].endswith("001") and s.get("common"):
            return s["common"]
    return None


def merged_common(sub, shared):
    """Subentry COMMON plus any entry-level COMMON fields it does not override."""
    own = sub.get("common")
    if not shared or not shared.get("rows"):
        return own
    if not own or not own.get("rows"):
        return shared
    names = list(own["names"])
    units = list(own["units"])
    row = list(own["rows"][0])
    for n, u, v in zip(shared["names"], shared["units"], shared["rows"][0]):
        if n not in names:
            names.append(n); units.append(u); row.append(v)
    return {"names": names, "units": units, "rows": [row]}


def energies_of(sub, shared=None):
    """All incident energies in a subentry, from COMMON EN or a DATA EN column."""
    vals = []
    c = merged_common(sub, shared)
    if c and "EN" in c["names"] and c["rows"]:
        v = c["rows"][0][col(c, "EN")]
        if v:
            vals.append(v)
    d = sub.get("data")
    if d and "EN" in d["names"]:
        j = col(d, "EN")
        seen = []
        for r in d["rows"]:
            if r[j] and r[j] not in seen:
                seen.append(r[j])
        vals += seen
    return vals


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------
def cmd_fetch(a):
    text, path = fetch(a.accession, a.cache, a.refresh)
    print(f"cached: {path}  ({len(text)} chars, {len(parse_subentries(text))} subentries)")


def cmd_list(a):
    text, _ = fetch(a.accession, a.cache, a.refresh)
    subs = parse_subentries(text)
    shared = entry_common(subs)
    title = next((s["bib"]["TITLE"][0] for s in subs if "TITLE" in s["bib"]), "")
    if title:
        print(f"TITLE: {title}\n")
    print(f"{'SUBENT':<12} {'N':>5}  {'ENERGY (as given)':<28} REACTION")
    print("-" * 100)
    for s in subs:
        rx = "; ".join(s["bib"].get("REACTION", [])) or "-"
        d = s.get("data")
        n = len(d["rows"]) if d else 0
        en = ", ".join(energies_of(s, shared)) or "-"
        if len(en) > 27:
            en = en[:24] + "..."
        print(f"{s['id']:<12} {n:>5}  {en:<28} {rx}")
    print("\nUnits for the energy column are in the subentry itself; run "
          "`data <SUBENT>` to see them.")


def cmd_data(a):
    sub_id = str(a.subent).strip()
    acc = sub_id[:5]
    text, _ = fetch(acc, a.cache, a.refresh)
    subs = parse_subentries(text)
    sub = next((s for s in subs if s["id"] == sub_id), None)
    if sub is None:
        raise SystemExit(f"Subentry {sub_id} not found in entry {acc}. "
                         f"Available: {', '.join(s['id'] for s in subs)}")
    d = sub.get("data")
    if not d:
        raise SystemExit(f"Subentry {sub_id} has no DATA table.")

    for k in ("REACTION", "SAMPLE", "INC-SOURCE"):
        for v in sub["bib"].get(k, []):
            print(f"# {k}: {v}")
    c = merged_common(sub, entry_common(subs))
    if c and c["rows"]:
        for nm, un, vv in zip(c["names"], c["units"], c["rows"][0]):
            if vv:
                print(f"# COMMON {nm} = {vv} {un}")
    print("# columns: " + " | ".join(f"{n} [{u}]" for n, u in
                                     zip(d["names"], d["units"])))

    rows = d["rows"]
    if a.energy is not None and "EN" in d["names"]:
        j = col(d, "EN")
        rows = [r for r in rows if r[j] and abs(float(r[j]) - a.energy) < 1e-6]
        if not rows:
            avail = sorted({r[j] for r in d["rows"] if r[j]}, key=float)
            raise SystemExit(f"No rows at EN={a.energy}. Available: {', '.join(avail)}")
    keep = [i for i, n in enumerate(d["names"])
            if not a.columns or n in a.columns]
    if a.header:
        print("\t".join(d["names"][i] for i in keep))
    for r in rows:
        if all(not r[i] for i in keep):
            continue
        print("\t".join(r[i] if r[i] else "nan" for i in keep))


def main():
    p = argparse.ArgumentParser(description="Retrieve and parse IAEA EXFOR data.")
    p.add_argument("--cache", default=DEFAULT_CACHE, help="cache directory")
    p.add_argument("--refresh", action="store_true", help="re-download even if cached")
    sub = p.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("fetch", help="download and cache an entry")
    f.add_argument("accession")
    f.set_defaults(func=cmd_fetch)

    l = sub.add_parser("list", help="list subentries with reaction and energies")
    l.add_argument("accession")
    l.set_defaults(func=cmd_list)

    g = sub.add_parser("data", help="print one subentry's data table")
    g.add_argument("subent", help="8-digit subentry id, e.g. 13160004")
    g.add_argument("--energy", type=float, default=None,
                   help="keep only rows with this EN value")
    g.add_argument("--columns", nargs="*", default=None,
                   help="keep only these column names")
    g.add_argument("--header", action="store_true", help="print a column-name row")
    g.set_defaults(func=cmd_data)

    a = p.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
