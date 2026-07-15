# FUSION kb-wiki semantic relation layer (L3-semantic)

User directive 2026-07-15: give kb-wiki a typed semantic-relation layer so links carry meaning (A refutes B, A improves B), not just co-occurrence, closing the gap with the hand-curated literature-wiki.

## The honest ceiling: two tiers of semantic relation

**S1, author-asserted relations (BUILD NOW).** When paper A cites paper B, A's own body text states the relationship ("we extend", "in contrast to", "using the potential of"). This meaning lives in the *citation context*, the sentences around `\cite{B}` in A's .tex. We already have 351,338 in-corpus citation edges; each has extractable evidence text. An LLM classifying that context is grounded in real text, does not hallucinate the relationship, and scales to 61k. What it produces is honest: "the relation A's authors asserted about B."

**S2, independent-judgment relations (LATER, gated experiment).** literature-wiki's real power is a human who read two whole papers judging "A actually contradicts B", often when A and B never cite each other. An LLM asked to do this across 61k papers hallucinates contradictions and improvements wholesale. Not built in v1. Future gated experiment: within a single concept+system cluster (small, bounded), ask for candidate contradictions and verify each against both full texts before writing any edge. High calibration cost; deferred.

This layer is S1. Its links are labeled as author-asserted so no one mistakes them for independent expert judgment.

## Relation taxonomy (6 types, citation-intent aligned)

| type | meaning | keep in semantic layer |
|---|---|---|
| `extends` | A builds on / improves / generalizes B's method or result | yes |
| `applies` | A applies B's framework/method to a new system or case | yes |
| `uses` | A uses B as a tool: code, potential, data, benchmark input | yes |
| `compares` | A benchmarks or compares against B, neutral | yes |
| `contrasts` | A disagrees with, corrects, refutes, or finds tension with B | yes (highest value + highest risk) |
| `background` | generic prior-art or contextual mention | no, discard (stays as a plain citation edge only) |

Each typed edge also carries `confidence` (high/medium/low, from how explicit the context is) and an `evidence` snippet (the citation sentence, so any human can verify the call).

## Method (grounded, not all-pairs)

Candidate set = the existing 351k citation edges, NOT all pairs (all-pairs is ~2 billion and meaningless). For each citing paper A:

1. Parse A's .tex; for each in-corpus cited B, extract the citation context (the sentence containing `\cite{Bkey}` plus one sentence of lead-in).
2. One LLM call per citing paper (batches all of A's in-corpus citations together, ~10 on average): input = A title + abstract + list of (B title, citation-context snippet); output = per-edge {type, confidence, one-line rationale}.
3. Discard `background`. Write the rest to `kb-wiki/relations.tsv` (citing, cited, type, confidence, evidence).

Scale: ~49,570 citing papers with outgoing edges, one call each, batched. deepseek-chat (self-checkable classification, per the deepseek-delegate high-volume rule), ~2.5k in / 300 out per call, roughly 125M in / 15M out total, ~$25-50 off-peak. Resumable by skipping papers already in relations.tsv.

## Injection into pages

Add a `## Related work` section to each paper page (idempotent), grouping ONLY non-background relations, bidirectional:
- On A's page: "Extends: [B]", "Contrasts with: [B]", "Uses: [B]" ...
- On B's page (inverse): "Extended by: [A]", "Contrasted by: [A]", "Used by: [A]" ...
Plain citation edges (the `## In-corpus citations` section) stay as they are; the semantic section sits above it and shows only the meaningful, typed subset.

## Calibration (verify before trusting)

Ground truth from the maintainer's own corpus papers:
- `1711.07540 -> 1511.03214` MUST be `extends` or `applies` (the 2018 Lei-Moro paper extends the 2015 post-prior work to bound states), NOT background. Hard gate.
- Sample 20 `contrasts` edges for human spot-check (highest-risk label); each must have citation-context evidence that genuinely expresses disagreement, not a misread background cite.
- Report the type distribution; a healthy corpus is mostly background-discarded with a `contrasts` fraction in the low single-digit percent. If `contrasts` is more than ~15% of kept edges, the classifier is over-firing and needs tightening before the full run.

## Relation to the other layers

```
L1 concept tags     : lexical, "what this paper is about"
L2 citation edges   : structural, "A cites B"
L3-semantic (THIS)  : author-asserted, "A extends/contrasts/uses B"   <- new
literature-wiki     : independent expert judgment, hundreds of papers  <- still the private top layer
```

L3-semantic is the honest, scalable middle ground between a bare citation edge and a human's read-and-judge. It does not replace literature-wiki; it gives the shippable 61k wiki a meaning-bearing link layer it did not have.
