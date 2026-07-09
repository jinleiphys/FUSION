# Task brief: FUSION knowledge-base 500-paper pilot

You are running inside opencode in `/Users/jinlei/Desktop/code/FUSION`. Execute this brief exactly, top to bottom. Work autonomously; do not stop to ask questions unless a step is impossible. Everything you write must contain no em-dashes (no long horizontal-bar characters, Chinese or English).

## Goal

Digest ~500 nuclear-reaction papers from the local corpus into markdown wiki pages, as the pilot for the full 62k-paper FUSION knowledge base. Design context (read first, 5 minutes): `kb-design.md` in this directory, section L3.

## Resources

- Corpus: SQLite at `~/literature-corpus/corpus.db`. Table `papers` (metadata) + FTS5 table `papers_fts` (has `fulltext`). Query helper: `/Users/jinlei/anaconda3/bin/python ~/literature-corpus/query.py` (subcommands text/abs/author/show, all accept `-n N --json`).
- Digest script (single paper, working, validated): `scripts/digest_paper.py`. Reads the DeepSeek API key from `~/.local/share/opencode/auth.json`. NEVER print or commit that key.
- Python: `/Users/jinlei/anaconda3/bin/python` (has sqlite3, urllib; no extra installs needed).

## Step 1: select ~500 papers

Collect arXiv ids with these corpus queries (dedupe, keep order of first appearance):

```bash
PY=/Users/jinlei/anaconda3/bin/python; Q=~/literature-corpus/query.py
$PY $Q text "inclusive breakup" -n 200 --json
$PY $Q text "complete fusion suppression weakly bound" -n 150 --json
$PY $Q text "elastic breakup CDCC continuum" -n 150 --json
$PY $Q abs "trojan horse method" -n 60 --json
$PY $Q text "incomplete fusion breakup fusion" -n 100 --json
```

Parse the JSON (top-level key `results`), dedupe by `arxiv_id`, truncate to 500. Save the list to `kb-wiki-pilot/paper-list.txt` (one id per line). Report how many unique ids each query contributed.

These ids MUST be present in the final list (they are the calibration set; add them if the queries missed any): 1511.03214, 1711.07540, 2101.09497, 1705.07782, 1508.04822, 2604.11226, 2605.03342, 2605.16890.

## Step 2: add batch mode to the digest script

Extend `scripts/digest_paper.py` (do not create a new file) with a batch entry point:

- `--list <file> --outdir kb-wiki-pilot/papers --workers 8`
- Skip ids whose output .md already exists (resumability).
- Retry each failure once after 30 s; collect final failures instead of crashing.
- Accumulate token usage (prompt_tokens, completion_tokens) across all calls.
- Print one progress line every 25 papers.

Keep the change minimal; the single-paper behavior must keep working unchanged.

## Step 3: run the batch

Run the 500-paper batch with 8 workers into `kb-wiki-pilot/papers/`. Expect roughly 8 s per paper per worker (about 10-15 minutes wall clock). If more than 5% of papers fail after retry, stop and record the pattern in the report instead of hammering the API.

## Step 4: quality checks

1. Structural: every generated page has the four sections (Key claim / Method / Key numbers / Context) and valid frontmatter. Count violations.
2. No-fabrication spot check: for the 8 calibration papers, verify every number and named result in the digest appears in (or is directly computable from) the paper's own abstract/fulltext in the corpus. Use the corpus fulltext, not memory.
3. Em-dash scan: `grep -rn $'\xe2\x80\x94' kb-wiki-pilot/papers/` must return nothing; fix any hits by regenerating those pages.
4. Truncation audit: count papers whose fulltext exceeded the 40k-char cap; list the 10 largest.

## Step 5: report and commit

Write `kb-wiki-pilot/pilot-report.md`:

- Papers attempted / succeeded / failed (with failure reasons)
- Total tokens in/out, measured cost estimate (deepseek-chat pricing), extrapolation to 62,714 papers
- Quality-check results (all four checks above)
- The 5 pages you judge best and 3 you judge worst, with one line each on why
- Concrete template improvements you recommend before the full run

Then: `git checkout -b kb-pilot && git add kb-wiki-pilot scripts/digest_paper.py && git commit` with message "KB pilot: 500-paper digestion run". Do NOT push. Do NOT touch corpus.db in write mode at any point.

## Done criteria

`kb-wiki-pilot/` contains ~500 .md pages + paper-list.txt + pilot-report.md, committed on branch kb-pilot, working tree clean, report honest about failures.
