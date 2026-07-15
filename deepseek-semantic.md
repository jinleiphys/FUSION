# Task brief: build and validate the kb-wiki semantic relation layer (L3-semantic)

Running inside opencode in `/Users/jinlei/Desktop/code/FUSION`. Execute top to bottom, autonomously. No em-dashes anywhere. Design context: `semantic-layer-design.md` (read it first). This brief BUILDS AND VALIDATES the tool on a sample; it does NOT run the full 61k. The maintainer runs the full batch separately after reviewing your validation.

## What you are building

For each existing in-corpus citation edge A -> B, classify the relationship A's own text asserts about B, into one of six types (extends, applies, uses, compares, contrasts, background), grounded in the citation context extracted from A's .tex. Discard `background`. This is author-asserted relation typing, NOT independent judgment; do not invent relations not supported by the citation context.

## Environment

- Citation edges (READ): `kb-wiki/citations.tsv` (citing TAB cited, 351,338 edges, both ends in corpus).
- Raw .tex (READ, drive mounted): `/Volumes/KINGSTON/nucl-th_tex_files/<arxiv_id>/`. Citing paper A's context comes from A's tex.
- Corpus metadata (READ ONLY, never write): `~/literature-corpus/corpus.db`, `papers` table (title, abstract, doi).
- Paper pages: `kb-wiki/papers/*.md` (61,059).
- DeepSeek key: `~/.local/share/opencode/auth.json` key `deepseek`. NEVER print it. Use model `deepseek-chat` for the bulk classification (cheap, self-checkable), following scripts/digest_paper.py's API pattern.
- Python: `/Users/jinlei/anaconda3/bin/python`. New script: `scripts/kb_relations.py` (extend the digest_paper.py API pattern, do not fork it).

## Step 1: citation-context extractor

In `scripts/kb_relations.py`, write a function that, given citing paper A, returns for each in-corpus cited B the citation context: find B's cite key in A's .tex (resolve via the same arXiv-id / DOI matching kb_citegraph.py already does; reuse that logic, do not reinvent), then extract the sentence containing the `\cite{...}` plus one sentence of lead-in. If the context cannot be located (external bibliography, unresolved key), mark evidence as empty and let the classifier fall back to titles + abstracts only.

Validate the extractor on `1711.07540`: it must locate the context in which it cites `1511.03214`, and that context must mention post-prior / equivalence / IAV. Print it. If empty, debug before continuing.

## Step 2: relation classifier

One LLM call per citing paper, batching all its in-corpus citations. Prompt: give A's title + abstract, then a numbered list of (B title, citation-context snippet); ask for, per item, a JSON object {type, confidence, rationale} where type is one of the six, confidence is high/medium/low, rationale is one clause quoting or paraphrasing the evidence. Rules in the prompt: default to `background` when the context is a bare prior-art mention or is empty; only choose `contrasts` when the text explicitly expresses disagreement, correction, tension, or a different conclusion; no em-dashes in rationale.

## Step 3: calibrate on the maintainer's papers (HARD GATE)

Run the classifier on these citing papers and show every resulting typed edge with its evidence:
`1711.07540`, `2101.09497`, `2604.11226`, `2605.03342`, `1508.04822`.

Hard checks:
- `1711.07540 -> 1511.03214` must come back `extends` or `applies`, NOT background. If it does not, fix the extractor or prompt and rerun. Do not proceed until this passes.
- Print each edge as: citing -> cited | type | confidence | evidence. The maintainer will eyeball these.

## Step 4: 200-paper sample run

Pick 200 citing papers spanning reaction, structure, and QCD concepts (use classification.json to spread across areas). Run the classifier, write results to `kb-wiki/relations-sample.tsv` (citing, cited, type, confidence, evidence). Do NOT run the full corpus.

Report metrics in `kb-wiki/semantic-report.md`:
- edges processed, type distribution (counts + percent), fraction discarded as background
- the calibration edges and their verdicts
- 20 `contrasts` edges (or all, if fewer) with evidence, for human spot-check: this is the highest-risk label
- token usage and extrapolated cost for the full 351k-edge run at deepseek-chat pricing
- honest failure modes: what fraction had empty context (external bibliography), any systematic misclassification you noticed

## Step 5: injection tool (build, run only on the sample)

Add to `scripts/kb_relations.py` an inject mode that writes a `## Related work` section into paper pages from a relations tsv: group non-background edges by type, bidirectional (citing page shows "Extends: [title](../papers/ID.md)"; cited page shows "Extended by: ..."), idempotent (replace the section if present). Run it ONLY on the pages touched by relations-sample.tsv so the maintainer can see the result on real pages. Report 3 example pages to eyeball.

## Wrap-up

- Verify no em-dash in anything you wrote (scan the report, the tsv rationales, the injected sections).
- `git checkout -b kb-semantic && git add -A && git commit -m "KB semantic relation layer: extractor, classifier, calibration + 200-paper sample"`. Do NOT push. Do NOT run the full corpus. Do NOT write corpus.db. Never print keys.

## Done criteria

scripts/kb_relations.py (extract + classify + inject) exists and is resumable; the 1711.07540 -> 1511.03214 = extends gate passes; relations-sample.tsv + semantic-report.md written; sample pages show the Related work section; committed on kb-semantic; working tree clean. The full-corpus run is the maintainer's next step, not yours.
