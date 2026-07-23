#!/usr/bin/env python3
"""Check exact conservation laws on a SMASH OSCAR2013 particle list.

Why this and not a multiplicity comparison. SMASH is a Monte Carlo transport
code: with a pinned seed it is bit-reproducible on one build, but the individual
multiplicities are not a portable reference and comparing them across builds
proves little. Baryon number and electric charge, by contrast, are conserved
EXACTLY by the transport, whatever the seed, the platform or the statistics. A
build that is subtly broken shows up here as an integer that does not match,
which no amount of statistical spread can excuse.

Conservation is checked PER BLOCK, not only on the total and not only per event.
Two events with equal and opposite violations sum to the right answer, so a
total-only check can be satisfied by output that is wrong twice over. And with
`Only_Final: No` each event contains SEVERAL full particle lists, one per output
interval, each of which must balance on its own; checking only the last one
would miss a transport that loses baryon number mid-evolution and recovers it.

This module is also the single authority on the OSCAR2013 particle_lists
grammar: run_smash.sh calls it with --structure-only instead of re-implementing
the same parsing in shell, so there is one place where the grammar can be wrong.

Usage:
  check_conservation_smash.py <particle_lists.oscar> --baryons N --charge Z
                              [--events N] [--species-min 3]
  check_conservation_smash.py <particle_lists.oscar> --structure-only [--events N]
--baryons and --charge are TOTALS over all events; they must divide evenly by
the number of events found, because every event starts from the same nuclei.
Exit 0 when the conservation laws hold, 1 otherwise.
"""
import argparse
import collections
import math
import re
import sys


def baryon_number(pdg):
    """Baryon number from a PDG code, transcribed from SMASH's own rule.

    `src/include/smash/pdgcode.h`, `PdgCode::baryon_number()`:

        if (is_nucleus())                       return A * antiparticle_sign();
        if (!is_hadron() || digits_.n_q1_ == 0) return 0;
        return antiparticle_sign();

    with `is_hadron() = (n_q3 != 0 && n_q2 != 0 && !is_nucleus())`.

    So a baryon is NOT "a four-digit code". It is any non-nuclear hadron whose
    first quark digit n_q1 is nonzero, which includes every excited state SMASH
    propagates: N(1440) is 12112, Lambda(1405) is 13122, and higher resonances
    run to six and seven digits. Judging by digit count silently gives all of
    them baryon number zero, and resonances are the bulk of a transport run's
    intermediate state, so that error turns an "exact" conservation check into a
    wrong one on any output taken before they have decayed.

    Digit layout for a non-nucleus, from the right:
        n_J (1) n_q3 (10) n_q2 (100) n_q1 (1000) n_L (1e4) n_R (1e5) n (1e6)
    Nuclei use +-10LZZZAAAI, ten digits, and their baryon number is A.
    """
    a = abs(pdg)
    sign = 1 if pdg > 0 else -1
    # Nucleus: +-10LZZZAAAI
    if a >= 1000000000:
        A = (a // 10) % 1000
        return sign * A
    n_q3 = (a // 10) % 10
    n_q2 = (a // 100) % 10
    n_q1 = (a // 1000) % 10
    if n_q3 == 0 or n_q2 == 0:      # not a hadron (lepton, photon, ...)
        return 0
    if n_q1 == 0:                   # meson
        return 0
    return sign



# Real SMASH-3.3 grammar, transcribed from src/oscaroutput.cc rather than
# inferred from one sample run. OscarOutput writes exactly three shapes for
# particle_lists (at_eventstart, at_intermediate_time, at_eventend):
#
#   # event N ensemble E in  COUNT      once, at event start
#   # event N ensemble E out COUNT      at every output interval, and at the end
#   # event N ensemble E end 0 impact X scattering_projectile_target yes|no
#
# and each in/out line is followed by COUNT particle records: a COMPLETE list of
# the particles present at that time, not an interaction. Which of them appear
# is set by Output.Particles.Only_Final:
#
#   Yes         one 'out' block per event                  (the shipped default)
#   IfNotEmpty  one 'out' block, or NONE for an empty event
#   No          one 'in', then one 'out' per output interval, then one at the end
#
# The earlier version of this parser knew only the Only_Final: Yes shape, so a
# real Box or collider run with Only_Final: No failed with "event 0/0 starts
# while 0/0 is still open" on its second block. Counting any comment that
# contains " end" was a separate, earlier bug: it accepted a file with no event
# blocks at all as long as some comment happened to contain that substring.
#
# Both patterns are ANCHORED to the full line and the COUNT is mandatory,
# because SMASH always writes one. Leaving the count optional and letting the
# end marker carry any tail accepted `# event 0 ensemble 0 out` with no count
# and `# event 0 ensemble 0 end nonsense tokens` as valid, and a truncated or
# corrupted marker is exactly the damage this parser exists to catch. The end
# line's tail is fixed by at_eventend: `end 0 impact %7.3f
# scattering_projectile_target yes|no`.
BLOCK = re.compile(r'^#\s+event\s+(\d+)\s+ensemble\s+(\d+)\s+(in|out)\s+(\d+)\s*$')
EVENT_END = re.compile(
    r'^#\s+event\s+(\d+)\s+ensemble\s+(\d+)\s+end\s+0\s+impact\s+\S+'
    r'\s+scattering_projectile_target\s+(?:yes|no)\s*$')
# A line that looks like a marker but does not match the grammar above is a
# corrupted marker, not a comment to skip past. Matched separately so it can be
# reported rather than silently ignored.
MARKER_ISH = re.compile(r'^#\s+event\s+\d+\s+ensemble\s+\d+\s+(?:in|out|end)\b')

# A block is one full particle list. Conservation is asserted on each.
Block = collections.namedtuple('Block', 'event kind baryons charge n declared')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('oscar')
    ap.add_argument('--baryons', type=int,
                    help='expected TOTAL baryon number over all events (Au+Au: Nevents * 2 * 197)')
    ap.add_argument('--charge', type=int,
                    help='expected TOTAL electric charge in units of e (Au+Au: Nevents * 2 * 79)')
    ap.add_argument('--events', type=int,
                    help='number of (event, ensemble) pairs the configuration asked for, i.e. '
                         'Nevents * Ensembles. Every one of them must be closed by an end marker.')
    ap.add_argument('--structure-only', action='store_true',
                    help='validate the OSCAR grammar and stop; do not require --baryons/--charge. '
                         'This is the mode run_smash.sh uses, so that the grammar lives in one place.')
    ap.add_argument('--species-min', type=int, default=0,
                    help='minimum number of distinct species. Off by default: a species count is '
                         'weak evidence and was overstated as proof that inelastic physics happened.')
    args = ap.parse_args()

    if not args.structure_only and (args.baryons is None or args.charge is None):
        print("FAIL: --baryons and --charge are required unless --structure-only is given")
        return 1
    for name, val in (('--baryons', args.baryons), ('--charge', args.charge)):
        if val is not None and abs(val) > 10 ** 9:
            print(f"FAIL: {name}={val} is not a plausible expectation")
            return 1
    if args.species_min < 0:
        print(f"FAIL: --species-min cannot be negative, got {args.species_min}")
        return 1
    if args.events is not None and args.events < 1:
        print(f"FAIL: --events must be at least 1, got {args.events}")
        return 1

    try:
        fh = open(args.oscar)
    except OSError as exc:
        print(f"FAIL: cannot read {args.oscar}: {exc}")
        return 1

    pdg_counts = collections.Counter()
    blocks = []          # one entry per in/out block, each a full particle list
    ended = set()        # (event, ensemble) pairs closed by an 'end' marker
    cur = None           # [label, kind, baryons, charge, n, declared]
    bad_lines = 0
    stray = 0

    def close_current():
        if cur is not None:
            blocks.append(Block(cur[0], cur[1], cur[2], cur[3], cur[4], cur[5]))

    with fh:
        header = fh.readline()
        tokens = header.split()
        if not tokens or not tokens[0].startswith('#!OSCAR2013'):
            print(f"FAIL: {args.oscar} does not start with an OSCAR2013 header: {header.strip()[:80]!r}")
            return 1
        # The content name decides what the blocks MEAN. In full_event_history
        # an 'in'/'out' pair is one interaction's incoming and outgoing
        # particles, not a particle list, so summing it would report a
        # conservation result that is meaningless rather than wrong-looking.
        if len(tokens) < 2 or tokens[1] != 'particle_lists':
            print(f"FAIL: {args.oscar} is OSCAR content {tokens[1] if len(tokens) > 1 else '(none)'!r}, "
                  f"not 'particle_lists'; this checker reads full particle lists only")
            return 1
        # The header NAMES its columns and the set changes with the requested
        # content, so read the positions rather than assuming 9 and 11.
        cols = tokens[2:]
        try:
            i_pdg = cols.index('pdg')
            i_chg = cols.index('charge')
        except ValueError:
            print(f"FAIL: the OSCAR header does not declare both 'pdg' and 'charge' columns: {cols}")
            return 1
        ncols = len(cols)
        int_cols = {i_pdg, i_chg}

        for line in fh:
            if line.startswith('#'):
                m = BLOCK.match(line)
                if m:
                    label = f"{m.group(1)}/{m.group(2)}"
                    kind = m.group(3)
                    # A new block header implicitly ends the previous BLOCK;
                    # only an 'end' marker ends the EVENT. So several blocks of
                    # the same event in a row are legal, and a block of a
                    # DIFFERENT event before the current one ended is not.
                    if cur is not None and cur[0] != label:
                        print(f"FAIL: block for event {label} starts while event {cur[0]} "
                              f"has not been closed by an 'end' marker")
                        return 1
                    if label in ended:
                        print(f"FAIL: a block for event {label} appears after that event already ended")
                        return 1
                    if kind == 'in' and cur is not None and cur[0] == label:
                        print(f"FAIL: event {label} has an 'in' block that is not its first block")
                        return 1
                    close_current()
                    declared = int(m.group(4))
                    cur = [label, kind, 0, 0, 0, declared]
                    continue
                m = EVENT_END.match(line)
                if m:
                    label = f"{m.group(1)}/{m.group(2)}"
                    if cur is not None and cur[0] != label:
                        print(f"FAIL: event {label} ends while a block of event {cur[0]} is open")
                        return 1
                    if label in ended:
                        print(f"FAIL: event {label} ends twice")
                        return 1
                    # An event with no block at all is legitimate: Only_Final:
                    # IfNotEmpty writes only the 'end' marker for an empty event.
                    close_current()
                    cur = None
                    ended.add(label)
                    continue
                if MARKER_ISH.match(line):
                    print(f"FAIL: malformed event marker: {line.strip()[:100]!r}")
                    return 1
                continue

            fields = line.split()
            if len(fields) != ncols:
                bad_lines += 1
                continue
            try:
                for i, f in enumerate(fields):
                    if i in int_cols:
                        continue
                    if not math.isfinite(float(f)):
                        print(f"FAIL: non-finite value in {args.oscar}: {line.strip()[:90]!r}")
                        return 1
                pdg = int(fields[i_pdg])
                charge = int(fields[i_chg])
            except ValueError:
                bad_lines += 1
                continue
            if cur is None:
                stray += 1
                continue
            pdg_counts[pdg] += 1
            cur[2] += baryon_number(pdg)
            cur[3] += charge
            cur[4] += 1

    if bad_lines:
        print(f"FAIL: {bad_lines} malformed particle records in {args.oscar}")
        return 1
    if stray:
        print(f"FAIL: {stray} particle records lie outside any event block")
        return 1
    if cur is not None:
        print(f"FAIL: event {cur[0]} was never closed by an 'end' marker; the run was truncated")
        return 1
    if not ended:
        print(f"FAIL: {args.oscar} contains no complete event block")
        return 1

    n_ev = len(ended)
    n_records = sum(b.n for b in blocks)

    print(f"particles: {n_records} records in {len(blocks)} particle-list blocks, "
          f"{len(pdg_counts)} distinct species, {n_ev} events")

    ok = True
    # The declared count on each in/out line must match what followed it.
    for b in blocks:
        if b.declared is not None and b.declared != b.n:
            print(f"FAIL: the '{b.kind}' block of event {b.event} declares {b.declared} "
                  f"particles but {b.n} records follow")
            ok = False

    if args.events is not None and n_ev != args.events:
        print(f"FAIL: the configuration asks for {args.events} (event, ensemble) pairs "
              f"but {n_ev} were completed; the run stopped early")
        ok = False

    if args.structure_only:
        if ok:
            print("STRUCTURE OK")
            return 0
        print("STRUCTURE FAILED")
        return 1

    if n_records == 0:
        print(f"FAIL: {args.oscar} contains no particle records")
        return 1

    # Per BLOCK, not just on the total and not just at the end of an event:
    # equal and opposite violations in two events would otherwise cancel into a
    # clean-looking sum, and with Only_Final: No a violation that appears and
    # heals between output intervals would never be seen at all.
    if args.baryons % n_ev or args.charge % n_ev:
        print(f"FAIL: expectations {args.baryons}/{args.charge} do not divide evenly by {n_ev} events; "
              f"every event starts from the same nuclei, so they must")
        return 1
    b_per, q_per = args.baryons // n_ev, args.charge // n_ev
    for b in blocks:
        if b.baryons != b_per:
            print(f"FAIL: the '{b.kind}' block of event {b.event} has baryon number "
                  f"{b.baryons}, expected {b_per}")
            ok = False
        if b.charge != q_per:
            print(f"FAIL: the '{b.kind}' block of event {b.event} has charge "
                  f"{b.charge}, expected {q_per}")
            ok = False
    if ok:
        print(f"  baryon number conserved EXACTLY in all {len(blocks)} blocks: {b_per} each, {args.baryons} total")
        print(f"  electric charge conserved EXACTLY in all {len(blocks)} blocks: {q_per} each, {args.charge} total")

    if args.species_min and len(pdg_counts) < args.species_min:
        print(f"FAIL: only {len(pdg_counts)} distinct species, expected at least {args.species_min}")
        ok = False

    print("  most abundant: " + ', '.join(f"{k}:{v}" for k, v in pdg_counts.most_common(6)))

    if ok:
        print("CONSERVATION OK")
        return 0
    print("CONSERVATION FAILED")
    return 1


if __name__ == '__main__':
    sys.exit(main())
