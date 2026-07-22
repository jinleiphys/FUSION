# FUSION devlog

Append-only, reverse-chronological. Log direction changes and dead-ends, not every failed run.
Full-length versions of consolidated entries live in `devlog-archive.md` (not auto-imported).

## 2026-07-23: SkyNet macOS NSE block-3 is libm-limited, not a flag fix

**Why we tried it:** the full-network NSE (Saha) block at T9=3 reproduced the
shipped reference to 7.0e-3 on macOS against a 3.5e-5 gate. FMA contraction is a
common cause of such cross-platform deltas, so `-ffp-contract=off` was the first
suspect, cheap to test.

**What failed:** `-ffp-contract=off` gave the byte-identical 0.00701498, and -O3
and -O0 also agree. So it is neither FMA contraction nor optimization-sensitive UB.

**Root cause:** Apple libm vs glibc `exp`/`log` differences, amplified through a
Newton iteration over abundances spanning ~200 decades (ni56 ~ 5e-201 at T9=3).
The reference tolerance was calibrated on the authors' glibc platform; the
identical patched source passes 19/19 on Linux, so it is a platform numerical
property, not a build or patch defect.

**Lesson:** a stiff nonlinear solve's tightest reference may not survive a libm
change. Do not chase it with flags or by loosening the passing platform's gate:
reproduce cross-platform, document the delta, and encode the exception narrowly
(other blocks pass on both platforms; the excepted case bounded to a window).
Full reasoning in the 2026-07-23 CLAUDE.md key decision.

**Status:** Parked (documented macOS caveat; SkyNet ships tier-1-with-caveat).

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
