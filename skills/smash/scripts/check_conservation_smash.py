#!/usr/bin/env python3
"""Check exact conservation laws on a SMASH OSCAR2013 particle list.

Why this and not a multiplicity comparison. SMASH is a Monte Carlo transport
code: with a pinned seed it is bit-reproducible on one build, but the individual
multiplicities are not a portable reference and comparing them across builds
proves little. Baryon number and electric charge, by contrast, are conserved
EXACTLY by the transport, whatever the seed, the platform or the statistics. A
build that is subtly broken shows up here as an integer that does not match,
which no amount of statistical spread can excuse.

Usage:
  check_conservation_smash.py <particle_lists.oscar> --baryons N --charge Z
                              [--species-min 3]
Exit 0 when the conservation laws hold, 1 otherwise.
"""
import argparse
import collections
import math
import sys


def baryon_number(pdg):
    """Baryon number from a PDG code: 4-digit codes are baryons, sign follows."""
    a = abs(pdg)
    if 1000 <= a < 10000:
        return 1 if pdg > 0 else -1
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('oscar')
    ap.add_argument('--baryons', type=int, required=True,
                    help='expected total baryon number, summed over all events '
                         '(for Au+Au that is Nevents * 2 * 197)')
    ap.add_argument('--charge', type=int, required=True,
                    help='expected total electric charge in units of e '
                         '(for Au+Au that is Nevents * 2 * 79)')
    ap.add_argument('--species-min', type=int, default=3,
                    help='minimum number of distinct species expected; a transport run that '
                         'produced only nucleons did not actually do any physics')
    args = ap.parse_args()

    for name, val in (('--baryons', args.baryons), ('--charge', args.charge)):
        if abs(val) > 10 ** 9:
            print(f"FAIL: {name}={val} is not a plausible expectation")
            return 1
    if args.species_min < 1:
        print(f"FAIL: --species-min must be at least 1, got {args.species_min}")
        return 1

    pdg_counts = collections.Counter()
    total_charge = 0
    total_baryons = 0
    n_records = 0
    events_ended = 0
    bad_lines = 0

    try:
        fh = open(args.oscar)
    except OSError as exc:
        print(f"FAIL: cannot read {args.oscar}: {exc}")
        return 1

    with fh:
        header = fh.readline()
        if not header.startswith('#!OSCAR2013'):
            print(f"FAIL: {args.oscar} does not start with an OSCAR2013 header: {header.strip()[:80]!r}")
            return 1
        for line in fh:
            if line.startswith('#'):
                if ' end' in line:
                    events_ended += 1
                continue
            fields = line.split()
            # t x y z mass p0 px py pz pdg ID charge
            if len(fields) < 12:
                bad_lines += 1
                continue
            try:
                for f in fields[:9]:
                    if not math.isfinite(float(f)):
                        print(f"FAIL: non-finite kinematic value in {args.oscar}: {line.strip()[:90]!r}")
                        return 1
                pdg = int(fields[9])
                charge = int(fields[11])
            except ValueError:
                bad_lines += 1
                continue
            pdg_counts[pdg] += 1
            total_charge += charge
            total_baryons += baryon_number(pdg)
            n_records += 1

    if bad_lines:
        print(f"FAIL: {bad_lines} malformed particle records in {args.oscar}")
        return 1
    if n_records == 0:
        print(f"FAIL: {args.oscar} contains no particle records")
        return 1
    if events_ended == 0:
        print(f"FAIL: {args.oscar} contains no event-end marker; the run was truncated")
        return 1

    ok = True
    print(f"particles: {n_records} records, {len(pdg_counts)} distinct species, {events_ended} events")

    if total_baryons != args.baryons:
        print(f"FAIL: baryon number {total_baryons} != expected {args.baryons}")
        ok = False
    else:
        print(f"  baryon number conserved EXACTLY: {total_baryons}")

    if total_charge != args.charge:
        print(f"FAIL: total charge {total_charge} != expected {args.charge}")
        ok = False
    else:
        print(f"  electric charge conserved EXACTLY: {total_charge}")

    if len(pdg_counts) < args.species_min:
        print(f"FAIL: only {len(pdg_counts)} distinct species, expected at least {args.species_min}; "
              f"no inelastic physics happened")
        ok = False

    top = ', '.join(f"{k}:{v}" for k, v in pdg_counts.most_common(6))
    print(f"  most abundant: {top}")

    if ok:
        print("CONSERVATION OK")
        return 0
    print("CONSERVATION FAILED")
    return 1


if __name__ == '__main__':
    sys.exit(main())
