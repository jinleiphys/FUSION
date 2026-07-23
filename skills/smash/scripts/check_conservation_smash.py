#!/usr/bin/env python3
"""Check exact conservation laws on a SMASH OSCAR2013 particle list.

Why this and not a multiplicity comparison. SMASH is a Monte Carlo transport
code: with a pinned seed it is bit-reproducible on one build, but the individual
multiplicities are not a portable reference and comparing them across builds
proves little. Baryon number and electric charge, by contrast, are conserved
EXACTLY by the transport, whatever the seed, the platform or the statistics. A
build that is subtly broken shows up here as an integer that does not match,
which no amount of statistical spread can excuse.

Conservation is checked PER EVENT, not only on the total. Two events with equal
and opposite violations sum to the right answer, so a total-only check can be
satisfied by output that is wrong twice over.

Usage:
  check_conservation_smash.py <particle_lists.oscar> --baryons N --charge Z
                              [--species-min 3]
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



# Real SMASH-3.3 grammar, from src/oscaroutput.cc:
#   # event N ensemble E out COUNT
#   # event N ensemble E end 0 impact X scattering_projectile_target yes|no
# Counting any comment that contains " end" accepted a file with no event blocks
# at all, as long as some comment happened to contain that substring.
EVENT_OUT = re.compile(r'^#\s+event\s+(\d+)\s+ensemble\s+(\d+)\s+out\b(?:\s+(\d+))?')
EVENT_END = re.compile(r'^#\s+event\s+(\d+)\s+ensemble\s+(\d+)\s+end\b')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('oscar')
    ap.add_argument('--baryons', type=int, required=True,
                    help='expected TOTAL baryon number over all events (Au+Au: Nevents * 2 * 197)')
    ap.add_argument('--charge', type=int, required=True,
                    help='expected TOTAL electric charge in units of e (Au+Au: Nevents * 2 * 79)')
    ap.add_argument('--species-min', type=int, default=0,
                    help='minimum number of distinct species. Off by default: a species count is '
                         'weak evidence and was overstated as proof that inelastic physics happened.')
    args = ap.parse_args()

    for name, val in (('--baryons', args.baryons), ('--charge', args.charge)):
        if abs(val) > 10 ** 9:
            print(f"FAIL: {name}={val} is not a plausible expectation")
            return 1
    if args.species_min < 0:
        print(f"FAIL: --species-min cannot be negative, got {args.species_min}")
        return 1

    try:
        fh = open(args.oscar)
    except OSError as exc:
        print(f"FAIL: cannot read {args.oscar}: {exc}")
        return 1

    pdg_counts = collections.Counter()
    events = []          # (label, baryons, charge, n_records, declared)
    open_ev = None       # (label, baryons, charge, n_records, declared)
    bad_lines = 0
    stray = 0

    with fh:
        header = fh.readline()
        if not header.startswith('#!OSCAR2013'):
            print(f"FAIL: {args.oscar} does not start with an OSCAR2013 header: {header.strip()[:80]!r}")
            return 1
        # The header NAMES its columns and the set changes with the requested
        # content, so read the positions rather than assuming 9 and 11.
        cols = header.split()[2:]
        try:
            i_pdg = cols.index('pdg')
            i_chg = cols.index('charge')
        except ValueError:
            print(f"FAIL: the OSCAR header does not declare both 'pdg' and 'charge' columns: {cols}")
            return 1
        ncols = len(cols)

        for line in fh:
            if line.startswith('#'):
                m = EVENT_OUT.match(line)
                if m:
                    if open_ev is not None:
                        print(f"FAIL: event {m.group(1)}/{m.group(2)} starts while "
                              f"{open_ev[0]} is still open")
                        return 1
                    declared = int(m.group(3)) if m.group(3) else None
                    open_ev = [f"{m.group(1)}/{m.group(2)}", 0, 0, 0, declared]
                    continue
                m = EVENT_END.match(line)
                if m:
                    label = f"{m.group(1)}/{m.group(2)}"
                    if open_ev is None:
                        print(f"FAIL: event {label} ends without a matching 'out' line")
                        return 1
                    if open_ev[0] != label:
                        print(f"FAIL: event {label} ends while {open_ev[0]} is open")
                        return 1
                    events.append(tuple(open_ev))
                    open_ev = None
                continue

            fields = line.split()
            if len(fields) != ncols:
                bad_lines += 1
                continue
            try:
                for f in fields[:i_pdg]:
                    if not math.isfinite(float(f)):
                        print(f"FAIL: non-finite value in {args.oscar}: {line.strip()[:90]!r}")
                        return 1
                pdg = int(fields[i_pdg])
                charge = int(fields[i_chg])
            except ValueError:
                bad_lines += 1
                continue
            if open_ev is None:
                stray += 1
                continue
            pdg_counts[pdg] += 1
            open_ev[1] += baryon_number(pdg)
            open_ev[2] += charge
            open_ev[3] += 1

    if bad_lines:
        print(f"FAIL: {bad_lines} malformed particle records in {args.oscar}")
        return 1
    if stray:
        print(f"FAIL: {stray} particle records lie outside any event block")
        return 1
    if open_ev is not None:
        print(f"FAIL: event {open_ev[0]} was never closed; the run was truncated")
        return 1
    if not events:
        print(f"FAIL: {args.oscar} contains no complete event block")
        return 1

    n_ev = len(events)
    n_records = sum(e[3] for e in events)
    if n_records == 0:
        print(f"FAIL: {args.oscar} contains no particle records")
        return 1

    print(f"particles: {n_records} records, {len(pdg_counts)} distinct species, {n_ev} events")

    ok = True
    # The declared count on each 'out' line must match what followed it.
    for label, _, _, got, declared in events:
        if declared is not None and declared != got:
            print(f"FAIL: event {label} declares {declared} particles but {got} records follow")
            ok = False

    # Per event, not just on the total: equal and opposite violations in two
    # events would otherwise cancel into a clean-looking sum.
    if args.baryons % n_ev or args.charge % n_ev:
        print(f"FAIL: expectations {args.baryons}/{args.charge} do not divide evenly by {n_ev} events; "
              f"every event starts from the same nuclei, so they must")
        return 1
    b_per, q_per = args.baryons // n_ev, args.charge // n_ev
    for label, b, q, _, _ in events:
        if b != b_per:
            print(f"FAIL: event {label} has baryon number {b}, expected {b_per}")
            ok = False
        if q != q_per:
            print(f"FAIL: event {label} has charge {q}, expected {q_per}")
            ok = False
    if ok:
        print(f"  baryon number conserved EXACTLY in every event: {b_per} each, {args.baryons} total")
        print(f"  electric charge conserved EXACTLY in every event: {q_per} each, {args.charge} total")

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
