#!/usr/bin/env python3
"""
Calibrate the .azr partial widths so that AZURE2's OWN parameter transformation
reproduces the reduced-width amplitudes published in Table V of
Azuma et al., Phys. Rev. C 81, 045805 (2010).

WHY THIS EXISTS. Table V quotes gamma (a reduced-width amplitude) for the
unbound levels and an ANC for the two bound levels. AZURE2's default input
convention is the other way round for the unbound case: field 12 of a level
line is a PARTIAL WIDTH IN eV, which it converts internally to gamma. The two
bound-state ANCs go in verbatim, so only the seven unbound entries need work.

Rather than do that conversion by hand (which would put my own penetrability
calculation between the paper and the benchmark, and so could hide a format
error behind a compensating arithmetic error), this script inverts AZURE2's own
transform numerically: run, read back what AZURE2 reports, rescale, repeat.

TWO SUBTLETIES, both found the hard way.

1. The target is `g_int` in parameters.out, matching Table V's "gamma(int)"
   column heading. For a plain particle channel that equals the formal rwa in
   param.par, but for a capture channel with external capture switched on it
   does not, so param.par is the wrong file to read.

2. For a capture channel the reported g_int is offset by the RESONANT external
   capture amplitude g_ext, and g_ext is itself proportional to the proton
   reduced width of the same level. Iterating on gamma alone therefore chases a
   moving target: a first version of this script rescaled on g_int assuming
   gamma ~ sqrt(width), drove three capture widths to ~1e-16 eV, and cycled
   forever instead of converging. A second version subtracted g_ext and rescaled;
   that model is also wrong, and it fails loudly by dividing by zero.

   So no closed-form model is assumed here at all. AZURE2 is treated as a black
   box and each channel is driven to its target by a secant iteration on the
   width. That converges regardless of what the true relation is, and it cannot
   quietly return a wrong answer built on a wrong model.

The bound levels are deliberately NOT touched: their field 12 already is the
published ANC in AZURE2's own units.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
AZR = HERE / "16O_pg_17F.azr"
PARAM = HERE / "output" / "param.par"
PHYS = HERE / "output" / "parameters.out"

# Table V of PRC 81, 045805 (2010). Key = (level energy in MeV, pair key),
# value = published gamma. Pair 1 = p + 16O, pair 2 = gamma + 17F(g.s.),
# pair 3 = gamma + 17F(0.495).
TARGETS = {
    (3.103, 1): 0.1415,    # gamma_p,   J = 1/2-
    (3.103, 3): 0.04359,   # gamma_g1,  E1 to the 495 keV state
    (3.859, 1): 0.2456,    # gamma_p,   J = 5/2-
    (3.859, 2): 0.05344,   # gamma_g0,  E1 to the ground state
    (4.711, 1): 0.7519,    # gamma_p,   J = 3/2- background pole
    (4.711, 2): -0.09586,  # gamma_g0,  note the sign
    (4.711, 3): 0.00404,   # gamma_g1
}

TOL = 1e-8
MAX_ITER = 60

LEVEL_RE = re.compile(r"J = \S+\s+E_level =\s+(\S+) MeV")
CHAN_RE = re.compile(
    r"R =\s*(\d+).*?g_int =\s*(\S+) MeV\^\(1/2\)\s+g_ext =\s*\(([^,]+),([^)]+)\)"
)


def level_lines(text):
    """Yield (line index, token list) for every channel line inside <levels>."""
    inside = False
    for i, line in enumerate(text.splitlines()):
        if line == "<levels>":
            inside = True
            continue
        if line == "</levels>":
            inside = False
            continue
        if inside and line.strip():
            yield i, line.split()


def run_azure2(binary):
    """One calculation pass. Returns {(E_level, pair key): (g_int, Re g_ext)}."""
    # AZURE2 reads param.par back if it exists, instead of regenerating it.
    if PARAM.exists():
        PARAM.unlink()
    proc = subprocess.run(
        [binary, "--no-gui", AZR.name],
        cwd=HERE, input="3\n\n\n6\n", capture_output=True, text=True,
    )
    if not PHYS.exists():
        sys.exit("calibrate: AZURE2 produced no parameters.out\n" + proc.stdout[-2000:])
    reported, energy = {}, None
    for line in PHYS.read_text().splitlines():
        m = LEVEL_RE.search(line)
        if m:
            energy = round(float(m.group(1)), 6)
            continue
        m = CHAN_RE.search(line)
        if m and energy is not None:
            reported[(energy, int(m.group(1)))] = (float(m.group(2)), float(m.group(3)))
    if not reported:
        sys.exit("calibrate: parsed no channels out of parameters.out")
    return reported


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else None
    if not binary:
        out = subprocess.run(
            ["bash", str(HERE.parent.parent / "scripts" / "install_azure2.sh")],
            capture_output=True, text=True,
        )
        m = re.search(r"^AZURE2=(.+)$", out.stdout, re.M)
        if not m:
            sys.exit("calibrate: could not locate the AZURE2 binary\n" + out.stderr)
        binary = m.group(1)

    history = {}  # key -> [(width, gamma), (width, gamma)], most recent last
    for iteration in range(1, MAX_ITER + 1):
        reported = run_azure2(binary)
        text = AZR.read_text()
        lines = text.splitlines()

        worst, changed = 0.0, False
        for idx, tok in level_lines(text):
            key = (round(float(tok[2]), 6), int(tok[5]))
            if key not in TARGETS:
                continue  # bound level: field 12 is already the published ANC
            if key not in reported:
                sys.exit(f"calibrate: AZURE2 never reported channel {key}")
            target = TARGETS[key]
            gamma = reported[key][0]
            width = float(tok[11])
            worst = max(worst, abs(gamma - target) / abs(target))

            # The width is searched SIGNED, over the whole real line. It is
            # tempting to fix the input sign from the sign of the published
            # gamma, and two earlier versions of this script did; it is wrong.
            # For a capture channel the reported g_int carries a large negative
            # offset (-Re g_ext, set by the proton width of the same level), so
            # the 4.711 MeV E1-to-ground-state channel reaches its NEGATIVE
            # published gamma from a POSITIVE partial width. Forcing the sign
            # put the root outside the search space and the iteration stalled
            # at 1e-16 eV forever.
            past = history.setdefault(key, [])
            past.append((width, gamma))
            del past[:-2]
            if abs(gamma - target) / abs(target) < TOL:
                continue

            if len(past) < 2 or past[0][1] == past[1][1] or past[0][0] == past[1][0]:
                # No usable secant yet: perturb to create one. gamma ~ sqrt(w)
                # is only a step heuristic, never trusted as the answer.
                new = width * 1.5 + (0.1 if width == 0.0 else 0.0)
            else:
                (w0, g0), (w1, g1) = past
                new = w1 + (target - g1) * (w1 - w0) / (g1 - g0)
            # Bound the MAGNITUDE only. The sign is a free search direction.
            if not (1e-30 < abs(new) < 1e12):
                sys.exit(f"calibrate: width for {key} left physical range ({new:g} eV)")
            tok[11] = f"{new:.10e}"
            lines[idx] = " ".join(tok)
            changed = True

        print(f"iteration {iteration}: worst relative deviation {worst:.3e}")
        if not changed:
            print(f"converged: every channel within {TOL:g} of Table V")
            return 0
        AZR.write_text("\n".join(lines) + "\n")

    sys.exit(f"calibrate: no fixed point after {MAX_ITER} iterations")


if __name__ == "__main__":
    raise SystemExit(main())
