# <wiki>/CLAUDE.md — vocabulary + style overrides

This file is the per-wiki schema authority for the literature-wiki skill. The skill reads it on every operation that touches tags. Tag drift breaks indexing; edit deliberately.

The same file works for both Claude Code (which reads `CLAUDE.md`) and Codex CLI (which reads `AGENTS.md` of the same directory). If your harness is Codex, save this file as `AGENTS.md` instead, or keep both as identical copies.

---

## Controlled vocabulary

Four axes for the literature-wiki (narrower than research-profile's six because field-level wikis don't need user-specific axes like `topics`, `codes`, or `collaborators`).

```yaml
vocabulary:
  entities:
    # Authors, groups, experiments, code packages encountered in source papers.
    # Slug = lowercase last name, lowercase group/lab abbreviation, or lowercase code name.
    moro-group:
      canonical: "A.M. Moro group, Universidad de Sevilla"
      aliases: ["Moro group", "Sevilla group", "Moro et al."]
    fresco-code:
      canonical: "FRESCO code package (Thompson)"
      aliases: ["FRESCO", "Fresco"]
    uncategorized:
      canonical: "Uncategorized — defer until taxonomy decision"

  methods:
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
    ab-initio:
      canonical: "Ab initio nuclear theory"
      aliases: ["ab initio", "first principles"]
    uncategorized:
      canonical: "Uncategorized"

  systems:
    # Use the chemical/isotopic notation source papers use.
    "d+93Nb":
      canonical: "deuteron + Nb-93"
      aliases: ["d+Nb93", "d+93Nb"]
    "6Li+209Bi":
      canonical: "Li-6 + Bi-209"
      aliases: ["Li6+Bi209"]
    uncategorized:
      canonical: "Uncategorized"

  observables:
    breakup-cs:
      canonical: "Breakup cross section"
      aliases: ["breakup cross section", "breakup σ"]
    fusion-suppression-factor:
      canonical: "Complete-fusion suppression factor"
      aliases: ["CF suppression factor"]
    polarization:
      canonical: "Polarization observables (Ay, T20, ...)"
      aliases: ["analyzing power", "Ay", "T20"]
    uncategorized:
      canonical: "Uncategorized"
```

### Conventions

- **Slug format**: lowercase, hyphenated, no underscores. Embedded version numbers only when the axis is specific (`d+93Nb`, `fresco-code`).
- **Aliases are case-insensitive** at lookup time. List the spellings you actually see in papers, including original-language variants.
- **`parent:`** declares hierarchical inclusion. A page tagged with the child slug is automatically included in indices for the parent. Use sparingly — only when one is a strict refinement of the other.
- **`uncategorized`** is reserved per axis. The skill's `lint` operation warns if uncategorized usage exceeds 30%.

### Cross-skill alignment

If you also run **research-profile** for your own work, the slugs for `methods`, `systems`, and `observables` should be the SAME across both wikis. Two ways:

1. **Manual mirroring**: keep identical entries in `<personal-wiki>/CLAUDE.md` and `<literature-wiki>/CLAUDE.md`. Easy small-scale; prone to drift.
2. **Symlinked source** (recommended): keep one `~/research-vocabulary.yml` and `include:` it from both wikis' CLAUDE.md.

---

## Field customization

The default category names (`entities`, `methods`, `systems`, `observables`) suit physical-science research. If your field needs different axes, adjust here:

| Field example | Suggested axes |
|---|---|
| Physics / chemistry | entities, methods, systems, observables |
| ML research | datasets, methods, models, benchmarks |
| Biology | organisms, mechanisms, pathways, assays |
| History | actors, events, sources, debates |
| Law | parties, doctrines, cases, statutes |

Rename the directories under `<wiki>/` and rename the keys here in lockstep. The skill reads from this file as the axis-name authority.

---

## Personal style overrides (optional)

Anything you want every literature-wiki operation to respect (citation format, prose tone, language conventions). Examples:

- BibTeX-grade provenance on every non-trivial claim — link to a `sources/` page or external DOI.
- Use `[[wikilinks]]` for internal references (Obsidian-renders).
- Prose in English; technical terms remain in English even within Chinese commentary.
- Add yours.
