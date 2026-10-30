# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

**Keep this file under 100 lines.** CLAUDE.md imports it with `@devlog.md`, so
every line is loaded into every session in this project. When it grows past
that, move the oldest entries to `devlog-archive.md` in full, cutting at an
entry boundary, and consolidate what stays. `scripts/hooks/pre-commit` enforces
this; install it with `ln -sf ../../scripts/hooks/pre-commit .git/hooks/`.

## 2026-10-29: the Studio's working tree was two months stale under a current HEAD

HEAD had been mixed-reset to origin/main, but Nextcloud never delivered the
files: 22 tracked files matched old committed blobs, 32 were missing, and the
YAHFC session read the OLD CLAUDE.md unnoticed. Four files held real local
work. Fix: `git hash-object` each modified file against `git rev-list --all
--objects` (found = stale, restore from HEAD; not found = local, merge by hand).
**After `reset origin/main`, check that the files moved too.**

## 2026-10-28: YAHFC feasibility; why -Ofast and -O0 disagree; a patch tested and declined

**Eligible, builds, no shipped reference output (tier 2 unless an anchor is found).**
User ruling: technical report LLNL-TR-824700 (DOE CODE DOI 10.11578/dc.20211209.1)
counts as the paper; MIT in README prose. YAHFC and Frescox (LLNL fork, GPL-2.0,
run as bare `frescox` from PATH, no version or exit check) build unpatched on
Apple Silicon. `ran_seed N` makes runs bit-reproducible (default: clock). Existing
`.tcoef` in the run dir are silently reused. `Data/Trans-coeff/CC-DWBA/` ships 25
FRESCO `.tcoef` usable to check Frescox.

**-Ofast vs -O0 (45 of 87 files) has three causes, none physics.** (i)
`Exit_Channel%num_particles` is never zeroed (`decay-chain.f90:503`, heap from
`allocate` at :287); it toggles one header line in 6 (n,g) files at -O2, and
`-finit-integer` cannot see an allocated component. (ii) Fast-math, up to 15
printed units, enters via `KE_com = sqrt(M**2+2*mT*E) - M` (`YAHFC-Master.f90:5947`),
which cancels catastrophically (M ~ 85 GeV; rel error 7e-7 on the grid, stable
form 3e-16); forcing the O0 grid removes it. (iii) FMA: object-swap bisection
puts all 21 numeric O2 files in `print_channels.o`, `print_elastic.o` (exact
zeros become 2^-54 ~ 1e-17) and `eig_eis.o` (Gauss nodes one ulp, 6e-12 abs).
An `fmadd` in KE_com moves the grid but does not reach the library.

**Patch tested, then NOT adopted** (user: 1e-7 is invisible in nuclear physics;
see Key decisions 2026-10-28). Zeroing `num_particles`, stable KE_com/KE_lab
and `cc_file` 132 to 256 made -O2 = -Ofast byte for byte and lifted the path
limit, moving 31 files by <= 2e-7 with events and sigma unchanged. The skill
ships upstream source; an install guard handles the path limit instead.
**Physics anchor found:** LLNL's tuned `YAHFC-Examples/U235` deck gives
235U(n,f) within 4% of EXFOR 10950/14016 at 0.46, 0.97, 4.95, 14.0 MeV
(numbers in `skills/yahfc/references/verification.md`). **Trap:** stdout
carries NUL bytes, so a plain grep treats it as binary; always `grep -a`.

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
