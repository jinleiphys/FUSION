# FUSION first-run onboarding (user design, 2026-07-09)

The core product insight (user's): the private layer must not start empty. First launch runs a wizard that bootstraps a working environment in about five minutes, reusing artifacts FUSION already ships. Cold start is the number-one adoption killer for wiki-style tools; this converts two years of the maintainer's personal workflow (literature-wiki + research-profile) into every user's day-one default.

## The wizard (v1 = `fusion init` CLI dialog; v2 = TUI popup via opencode plugin slots)

**Step 0: model + key.** Pick a provider (DeepSeek / Qwen / GLM / Anthropic / OpenAI), paste an API key, fire one test call. Nothing else works without this, so it goes first.

**Step 1: pick research areas.** Present the PhySH Nuclear Physics subtree grouped by its 31 top concepts; user checks their areas (multi-select, e.g. Nuclear reactions > Breakup reactions + Nuclear astrophysics). Free-text box for areas PhySH misses.

**Step 2: mount the knowledge base slice.** Copy (or symlink) the kb-wiki topic pages + paper pages for the selected concepts into the user's workspace. Full kb-wiki is ~250 MB / 61k pages; a typical 5-concept slice is a few thousand pages. Option "give me everything" for the greedy.

**Step 3: seed the personal wiki.** User enters the arXiv ids of their own publications (or an ORCID / INSPIRE author id to fetch the list). For each id found in the corpus:
- pull its kb-wiki paper page as the seed entry;
- aggregate the concept tags of their papers into a "methods and topics I work on" page;
- extract co-author names into collaborator stubs;
- via the L2 citation graph, list the citation neighborhood: papers that cite the user (who builds on my work) and highly-cited neighbors the user has not written (what I should probably read). This last list is the single highest-value output for students.
Papers not in the corpus (outside nucl-th, or before 1992) get metadata stubs via the literature-search path.

**Step 4: recommend and install skills.** From a `concept-skill-map.yaml` (PhySH concept -> skills-catalog entries): reactions concepts pull FRESCO/THOx/CCFULL/TALYS, structure pulls KSHELL/BIGSTICK, astro pulls SkyNet/AZURE2, plus the always-on research skills (literature, writing, figures). For each accepted per-code skill, offer to run its benchmark case immediately so the local install is verified on day one (the skill quality bar already requires a benchmark, so this is free).

**Closing move:** offer one end-to-end demo task in the user's own area (e.g. reactions: reproduce a FRESCO elastic-scattering benchmark and plot it). First session ends with a real calculation, not a config file.

## What each step consumes (all already built or planned)

| Step | Data source | Status |
|---|---|---|
| 1 | PhySH subtree (CC0 dump) | in hand |
| 2 | kb-wiki pages | full run armed tonight |
| 3 | kb-wiki + L2 citation graph + corpus lookup | L2 on TODO (Phase 3) |
| 4 | skills-catalog.md + concept-skill-map.yaml | catalog done; map is new, small |

New components to build: the wizard itself (v1 CLI), concept-skill-map.yaml, ORCID/INSPIRE author-id lookup (optional sugar on step 3). Everything else is wiring.

## Post-onboarding loops (keep users coming back)

1. **Monthly personal digest.** The corpus already updates monthly by cron. Filter new papers by the user's concepts, digest them (pennies), and greet the user on next launch with "12 new papers in your areas this month, 3 cite you." Subscription = one line in the user config.
2. **Personal wiki grows by use.** When the user asks FUSION to read or discuss a paper, the summary lands in their personal wiki (lite version of the maintainer's literature-wiki ingest flow). The wizard seeds; usage feeds.
3. **Group mode (v2).** A research group shares one curated config: group concept set, group skill set, group compute docs. The advisor curates once; students inherit on init. The natural adoption unit for FUSION is the research group, not the individual.

## Scoping guard

v1 is a CLI question-and-answer (`fusion init`), plain text, no TUI work. The TUI popup, ORCID lookup, and group mode are v2+. Do not let the wizard grow features before the four core steps work end to end on one real student.
