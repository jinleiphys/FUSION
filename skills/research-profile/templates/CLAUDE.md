# <wiki>/CLAUDE.md — vocabulary + style overrides

This file is the per-wiki schema authority for the research-profile skill. The skill reads it on every operation that touches tags. Edit it deliberately; tag drift breaks indexing.

The same file works for both Claude Code (which reads `CLAUDE.md`) and Codex CLI (which reads `AGENTS.md` of the same directory). If your harness is Codex, save this file as `AGENTS.md` instead, or keep both as identical copies.

---

## Controlled vocabulary

Six axes. The skill normalizes any tag value through `aliases` to its canonical `slug` at log time. New tags require explicit user approval before being added.

```yaml
vocabulary:
  methods:
    # Example entries — replace / extend with your actual methods.
    cdcc:
      canonical: "Continuum-Discretized Coupled Channels"
      aliases: [CDCC, "continuum-discretized", "continuum discretized coupled channels"]
    iav-cdcc:
      canonical: "Ichimura-Austern-Vincent CDCC for transfer/breakup"
      aliases: [IAV-CDCC, "IAV CDCC"]
      parent: cdcc
    monte-carlo:
      canonical: "Monte Carlo (generic)"
      aliases: [MC, "monte carlo"]
    # uncategorized is reserved across all axes for genuinely novel content.
    uncategorized:
      canonical: "Uncategorized — defer until taxonomy decision"

  observables:
    breakup-cs:
      canonical: "Breakup cross section"
      aliases: ["breakup cross section", "breakup σ"]
    fusion-suppression-factor:
      canonical: "Complete-fusion suppression factor"
      aliases: ["CF suppression", "fusion suppression"]
    uncategorized:
      canonical: "Uncategorized"

  codes:
    fresco:
      canonical: "FRESCO (Thompson)"
      aliases: [Fresco, FRESCO]
    julia-nucleartoolkit:
      canonical: "NuclearToolkit.jl"
      aliases: ["NuclearToolkit.jl"]
    uncategorized:
      canonical: "Uncategorized"

  topics:
    icf:
      canonical: "Incomplete fusion"
      aliases: [ICF, 不完全融合]
    cf-suppression:
      canonical: "Complete-fusion suppression in weakly-bound projectiles"
      aliases: ["CF suppression"]
    weakly-bound:
      canonical: "Weakly-bound projectile reactions"
      aliases: ["weakly bound", "weakly-bound projectile"]
    uncategorized:
      canonical: "Uncategorized"

  systems:
    # Use the chemical/isotopic notation you actually write in papers.
    # Examples below — replace.
    "d+93Nb":
      canonical: "deuteron + Nb-93"
      aliases: ["d+Nb93", "d+93Nb"]
    "6Li+209Bi":
      canonical: "Li-6 + Bi-209"
      aliases: ["Li6+Bi209"]
    uncategorized:
      canonical: "Uncategorized"

  collaborators:
    # slug = lowercase last name (or last+first when ambiguous)
    moro:
      canonical: "A.M. Moro"
      aliases: [Moro, "Antonio Moro"]
      institution: "Universidad de Sevilla"
    phillips:
      canonical: "Daniel Phillips"
      aliases: [Phillips, "Daniel R. Phillips"]
      institution: "Ohio University"
    furnstahl:
      canonical: "Dick Furnstahl"
      aliases: [Furnstahl, "R.J. Furnstahl"]
      institution: "Ohio State University"
    uncategorized:
      canonical: "Uncategorized"
```

### Conventions

- **Slug format**: lowercase, hyphenated, no underscores. Avoid embedded version numbers when the axis is conceptual (use `cdcc` not `cdcc-2018`); use full identifiers when the axis is specific (`d+93Nb`, `julia-nucleartoolkit`).
- **Aliases are case-insensitive** at lookup time. List the spellings you actually type, including Chinese / Japanese / Korean variants.
- **`parent:`** declares hierarchical inclusion. A page tagged with the child slug is automatically included in indices for the parent. Use sparingly — only when one is a strict refinement of the other.
- **`uncategorized`** is reserved. Use it as a temporary holding tag when you do not yet know the right slug; the skill's `lint` operation warns if uncategorized usage exceeds 30% of an axis (signal that the taxonomy needs work).

### How to extend

The skill will propose vocabulary diffs during `log`. Approve, edit, and save the diff back to this file. Avoid inventing tags by hand-editing this file out of band — the skill's tag-resolution cache assumes the file is the single source of truth at session start. If you do edit by hand, run `update-index --rebuild` to flush.

---

## Personal style overrides (optional)

Anything you want every research-profile operation to respect (formatting rules, language conventions, methodological priors). The skill reads this section on every invocation.

Examples:
- Citation style: `\cite{}` BibTeX in TeX; `[[...]]` wikilinks within wiki.
- Date format: `YYYY-MM-DD` ISO everywhere.
- (Add yours.)

---

## Cross-skill notes

If you also run the literature-wiki skill, these vocabulary axes (especially `methods`, `systems`, `observables`, `collaborators`) should use the SAME slugs across both wikis. Two ways to share:

1. **Manual mirroring**: maintain identical entries in both `<personal-wiki>/CLAUDE.md` and `<literature-wiki>/CLAUDE.md`. Easy at small scale, prone to drift.
2. **Symlinked source**: keep one `~/research-vocabulary.yml` and `include:` it from both wikis' CLAUDE.md (skill supports `include: <path>` directive in the vocabulary block). True single source of truth.
