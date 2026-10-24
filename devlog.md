# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

**Keep this file under 100 lines.** CLAUDE.md imports it with `@devlog.md`, so
every line is loaded into every session in this project. When it grows past
that, move the oldest entries to `devlog-archive.md` in full, cutting at an
entry boundary, and consolidate what stays. `scripts/hooks/pre-commit` enforces
this; install it with `ln -sf ../../scripts/hooks/pre-commit .git/hooks/`.

## 2026-10-24: Gemini CLI support dropped

**User ruling: Gemini CLI is retired upstream (personal accounts cut off
2026-06-18, replaced by Antigravity), so nobody installs FUSION through it.**
`gemini-extension.json` is gone and the READMEs no longer mention it.
`fusion_init.py --agent gemini` became `--agent antigravity`: a canary line in
`~/.gemini/GEMINI.md` showed up in an `agy -p` session, so that file is still
where the setup marker belongs; Antigravity had no `--agent` value before. Plugin 0.3.1.

## 2026-10-24: BAND skill (rose, surmise, Taweret); the reviews earned their keep

**`skills/band/`, one umbrella skill (user ruling), surmise admitted without a journal paper
(user ruling).** rose's own solver reproduces the n+90Zr KD02 cross-code case (1299.19050 mb vs
FRESCO 1299.19061), confirming its spin-orbit convention is FRESCO's. Its emulator reproduces
the ROSE paper's typical Fig. 5 accuracy but not the worst-case "1%" on the paper's own metric
(0.7-5%), and the skill says so: an earlier version gated a softer metric and Codex rejected it.
The Codex pass found nine defects in all, including spin-orbit prose off by 2 (rose passes 2l.s)
and a `$HOME/.` bypass of the deletion guard. heliumx found four more, all install-side:
no python3-venv, uv off PATH, openbt needing MPI and Eigen (conda-forge fixes it, user's
suggestion), and the conda-built binary missing an rpath to libmpi. Mac and Linux VERIFY OK.

## 2026-10-23: FUSION is a plugin; the opencode fork is retired

**User ruling: stop maintaining the rebrand.** The fork only ever added a name
and a logo: stock opencode already reads `skills/index.json`, Codex and Gemini
read `.agents/skills` and `AGENTS.md`. Main now carries `.claude-plugin/`
(plugin + self-hosted marketplace), `.codex-plugin/` +
`.agents/plugins/marketplace.json`, `gemini-extension.json`, and a SessionStart
hook that hands `AGENTS.md` to Claude Code minus the maintainer section, and
minus the first-run offer once `~/.fusion/.initialized` exists.

**The knowledge base had to leave `main`.** A local-path test install was 620
MB because the plugin copy takes the whole tree; per install, per update, per
agent. It now lives on the `kb` branch (made with `commit-tree` from the
existing tree object, so the push sent no blobs), and `ensure_kb.sh` fetches it
on first use: 54 s, 791 MB on disk, verified against a MANIFEST, a deleted page
is refused. Install from a git-clean copy: 13 MB. Tested for real in all three
CLIs present: Claude Code (hook context and a kb query in a `-p` session), Codex
(skill used from an empty directory), Gemini (27 skills load). One near miss:
Gemini also loads `hooks/hooks.json`, where `$CLAUDE_PLUGIN_ROOT` is unset, so
the hook command is now a guarded no-op outside Claude Code.
Antigravity (`agy plugin install <repo>`) wants a root `plugin.json` and
`rules/*.md` with `trigger: always_on` frontmatter; a rule without it loads but
is never injected (the model had to go read it). It also dropped two skills
whose descriptions were invalid YAML that Claude Code had always tolerated.
Codex clones a GitHub marketplace with full history (290 MB, twice), so its
documented route is a shallow clone registered as a local marketplace (19 MB).

## 2026-09-24: the cite-key heuristic was wrong four times in five; the graph now takes INSPIRE

**Tier B of `kb_citegraph.py` is gone.** For a paper with an external .bib the
corpus holds only keys like `Wang11`, and the heuristic grouped authors by
surname (every 2011 "Wang" was one person, accepted wholesale) and let a
self-citation key take every paper its author wrote that year. Against INSPIRE
reference lists (record numbers resolved), 15,709 of 84,587 tier-B edges were
right, 18.6%. The same 5,931 papers now take their references from INSPIRE,
and the backfill resolves record-number-only references (40% of a sample),
which also recovered edges for the 27k earlier backfill papers. Graph
703,430 -> 809,632 edges (69,949 removed, 176,151 added, calibrations pass);
26,719 relation rows on removed edges dropped; the 176,151 new edges are
listed untyped in `relations-untyped.tsv` (typed 2026-09-25: 30,088 typed,
861 new contrasts rechecked, 405 overturned; relations 237,009 rows). Codex
confirmed the counts offline and put the kept tex-derived edges at 98.7%
against INSPIRE. A Codex review of the backfill
change caught two recall losses of my own (an out-of-corpus eprint no
longer fell back to its DOI; a record with an unmapped DOI was never
looked up), worth 3.1% of edges, fixed before the final run. A first 150-paper sample said
12.9%; it undercounted because its truth set skipped record numbers, and the
same flaw made tier A look 79.5% right when every inspected miss was real.
