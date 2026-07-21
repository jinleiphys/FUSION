# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-22: a results table is not an anchor, and 14N(p,g)15O cannot be built

**Why we tried it:** After the 16O(p,g)17F benchmark worked, 14N(p,g)15O was the
obvious next case and TODO called its Table IV "a better check than pikoe ever
had", because it tabulates S(0) per transition plus a total of 1.81 keV b.

**What failed:** the reconstruction, before a single run. Auditing the INPUT
side against the paper: Table II covers gamma widths for "the three strongest
transitions" only; the 5.18 MeV final state has neither an ANC in Table III nor
a gamma width anywhere, so it is 100% unspecified; and decisively, **the signs of
the reduced-width amplitudes are never published**, while the ground-state S(0)
is set by destructive interference among four 3/2+ components. Table III adds
its own warning that "there is a sign ambiguity in the conversion". Four
components give eight sign combinations spanning orders of magnitude in S(0).

**Root cause:** the attractiveness of a benchmark was judged from its OUTPUT
side. A table of results says nothing about whether the inputs that generated it
were all printed. 16O(p,g)17F happened to publish a complete parameter set;
14N(p,g)15O publishes a better-looking answer and an incomplete question.

**Lesson:** before promising a constructed benchmark, audit the input table for
completeness including signs and phases. Picking a sign to match a published
number is fitting to the answer, which is the exact failure the clean-room rule
exists to prevent. Tractable subsets can still be worth building: here the
6.79 MeV transition is 72% of the total, external-capture dominated with a single
ANC, and explicitly "added incoherently", so it carries no sign ambiguity.

**Status:** Full Table IV case abandoned. 6.79 MeV subset parked, in TODO.

**Also this session, two smaller dead-ends:**

- **`--no-transform` for entering published reduced-width amplitudes: rejected on
  physics.** It agrees with transform mode at the one radius where the
  amplitudes were converted and diverges by a **factor of 4** across
  ac = 4.0 to 6.0 fm, because it bypasses the ANC-to-amplitude conversion.
  Transform mode is flat to 0.4%, which is what ANC-normalised external capture
  must be. A single-radius check rates the two equally good. **Lesson: when a
  quantity is supposed to be invariant, test the invariance, not one point.**
- **The `codex:codex-rescue` plugin path was silently dead** for an hour: broker
  never started (0-byte log, no pid file), no live process, and the task kept
  reporting "still running". The Codex CLI itself was fine. This is a sixth
  false-success costume and the first at the ORCHESTRATION layer rather than in
  a physics code: silence was indistinguishable from work. **Lesson: a
  long-running delegated job needs a liveness check, not just a status string.**
  Workaround: drive `codex exec` directly.

## 2026-07-21: four skills, one failure shape, consolidated

Full text of all four entries in `devlog-archive.md`. Consolidated here because
they repeat one theme; every distinct mechanism is preserved below.

**The shape: a failed run that looks successful.** Six distinct mechanisms found
so far, each in a new costume:

| code | how a failure looked like success |
|---|---|
| CCFULL | leaves a stale reference file behind |
| GSM | exits 139 with empty stderr |
| TALYS | exits 0 on a fatal error |
| pikoe | opens every output file at zero bytes before computing |
| GEF | memoizes completed cases in `ctl/done.ctl`, silently skips, exits 0 |
| codex plugin (2026-07-22) | orchestration broker dies, task still reports "running" |

**Rule: verify content, never presence, and never status.** Corollary from GEF: a
scientific code may carry state between runs, so a clean room means clearing that
state (`ctl/`, a stale `Fitpar.dat`), not just the output directory.

**The second shape: destructive-command guards written against the wrong path.**
pikoe's `rm -rf` guard tested `$WORK/case` while deleting `$WORK`. NLAT's tested
whether the install contained the workdir when the danger was the reverse, in a
function whose comment cited the pikoe incident. AZURE2's (2026-07-22) escaped
through a symlinked path component. Three times, the third while quoting the
lesson from the first. **Writing a lesson down, and even citing it at the point
of use, does not transfer it. What caught all three was an adversarial agent
running the script with a hostile argument.** The guard must name the same
operand as the command, and the repro must be written before the guard.

**Verification philosophy, settled 2026-07-21:** the author's reference output is
produced by the SAME source as your run, so it certifies build integrity only,
never physics; a genuine physics bug sits in their reference too. Cross-build
reproduction certifies that same property over more configurations. Measured on
pikoe: bit-identical across macOS ARM64 gfortran 15.2 and Linux x86_64 gfortran
13.3, at `-O2`, `-O0` and `-finit-real=snan`, 5642 numbers. Consequence: do not
email authors for missing reference output. Physics correctness must be carried
separately, by published figures or tables.

**Other findings that must survive:** GEF is FreeBASIC and Linux-only, the first
platform-pinned row. `pkill -f GEF64` on a remote one-liner matches the ssh
session's own command line and self-kills silently. gfortran writes `.mod` files
into the caller's cwd unless given `-J`, which poisons a rebuild after any
compiler upgrade with an error naming neither cause nor fix. NLAT carries three
genuine upstream defects (a `(8,3)`/`(9,3)` index error at `front_end.f90:476`,
swapped print flags 16/17, a tolerance labelled "percent" that is dimensionless)
plus a paper recommendation that cannot be followed in the released code; worth
an email to Nunes. When a benchmark disagrees, find out whose fault it is before
deciding what to do about it, and encode any upstream exception narrowly enough
that a real regression still fails.
