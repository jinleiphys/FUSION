#!/usr/bin/env python3
"""
Assert that the 14N(p,gamma)15O 6.79 deck still carries its PUBLISHED inputs.

WHY THIS IS SEPARATE FROM THE S-FACTOR CHECK. The 0.259 MeV resonance term is
worth 0.6% of S(0), so its published widths can be edited substantially without
moving the observable outside any honest tolerance. An adversarial pass changed
Gp from the paper's 1.0 keV to 900 eV and the verifier still printed VERIFY OK
while claiming "inputs exact". Checking an output number is not checking an
input.

The 16O case gets this property free from its calibration loop, which refuses a
deck that does not already reproduce Table V. The 14N case has no such loop, so
the fields are asserted directly here.

Every value below is quoted from Azuma et al., Phys. Rev. C 81, 045805 (2010).
Exit 0 if the deck matches, 1 otherwise.
"""
import sys

# (level excitation energy in MeV, pair key) -> list of
#   (field index, expected value, what it is and where it comes from)
# Field indices are 0-BASED into the 31-field level line of include/NucLine.h,
# so the documented 1-based field N is index N-1: s is field 7 -> index 6,
# l is field 8 -> index 7, gamma is field 12 -> index 11, sepE field 23 ->
# index 22, chRad field 28 -> index 27. Getting this wrong is easy and the
# first version of this file did, on three of the eight entries.
WANT = {
    (6.793, 1): [
        (11, 4.86,   "ANC C_s3/2 = 4.86 fm^(-1/2)  [Table III]"),
        (6,  3,      "2 x channel spin, I = 3/2    [Table III, (s,3/2)]"),
        (7,  0,      "2 x l, s-wave                [Table III, (s,3/2)]"),
        (27, 5.5,    "channel radius 5.5 fm        [Sec. IV B]"),
        (22, 7.2971, "Sp(15O) = 7.2971 MeV         [TUNL, external]"),
    ],
    (7.5561, 1): [
        (11, 1000.0, "Gp = 1.0 keV entered in eV   [Table II]"),
        (7,  0,      "2 x l, s-wave (1/2+ from l=0)"),
    ],
    (7.5561, 2): [
        (11, 0.0096, "Ggamma_6.79 = 9.6 meV in eV  [Table II]"),
        (7,  2,      "2 x L, M1 to the 3/2+ state"),
    ],
}


def main(path):
    problems, seen = [], set()
    inside = False
    try:
        lines = open(path).read().splitlines()
    except OSError as e:
        print(f"check_14N_inputs: cannot read {path}: {e}", file=sys.stderr)
        return 1
    for line in lines:
        if line == "<levels>":
            inside = True
            continue
        if line == "</levels>":
            inside = False
            continue
        if not inside or not line.strip():
            continue
        tok = line.split()
        if len(tok) < 31:
            problems.append(f"level line has {len(tok)} fields, not 31: {line[:60]}")
            continue
        key = (round(float(tok[2]), 4), int(tok[5]))
        if key not in WANT:
            continue
        seen.add(key)
        for idx, expected, what in WANT[key]:
            got = float(tok[idx])
            if abs(got - expected) > 1e-9 * max(1.0, abs(expected)):
                problems.append(f"level {key[0]} MeV pair {key[1]}: {what}: "
                                f"deck has {got}, published {expected}")

    for key in sorted(set(WANT) - seen):
        problems.append(f"required channel absent from the deck: "
                        f"level {key[0]} MeV, pair {key[1]}")

    if problems:
        for p in problems:
            print(f"check_14N_inputs: {p}", file=sys.stderr)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: check_14N_inputs.py <deck.azr>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
