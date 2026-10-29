#!/usr/bin/env python3
"""Deck preflight and run verdict for run_yahfc.sh.

    yahfc_check.py deck <deck> <seed> <staged_list>
        -> key=value lines on stdout, exit 2 on refusal
    yahfc_check.py verdict <workdir> <rc> <seed> <proj> <units> <target_dir> <fx_log> <staged_list>
        -> summary on stdout, exit 1 on failure

Every guard is a call G("tag", condition, message). selftest_yahfc.sh proves
each tag fires by editing a copy to G("tag", True or condition, ...) and
checking that the cases written for that tag then pass. The proof is per tag,
not per call site, and assumes the conditions have no side effects.

The deck reader reproduces YAHFC's own (YAHFC-Master.f90:881-905 and
parse_string, parse-command.f90:3698) on a supported subset: lines are read
into 132 characters; a line whose FIRST character is '#', '!' or a space is
skipped (so an indented command is silently ignored); words are split on
spaces only (a tab is part of a word); '#' or '!' from column 2 on ends the
line; reading stops at `end` or end of input. YAHFC then reorders the commands
by rank, and the sort is not stable, so a command given twice may execute in
either order: duplicates of the commands below are refused.
"""
import glob
import math
import os
import re
import sys

EXIT = 1
SINGLE = ("projectile", "target", "cs_units", "file", "proj_eminmax", "proj_e_file", "delta_e",
          "num_mc_samp", "event_generator", "verbose_output", "ran_seed", "cc_file", "xs_only",
          "explicit_channels")
SYMBOLS = ("H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As "
           "Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd "
           "Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am "
           "Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og").split()
NUM = re.compile(r"^[-+]?(\d+\.?\d*|\.\d+)([eEdD][-+]?\d+)?$")


def G(tag, ok, msg):
    if not ok:
        print(f"run_yahfc: {'REFUSED' if EXIT == 2 else 'FAIL'} [{tag}], {msg}", file=sys.stderr)
        sys.exit(EXIT)


def num(s):
    try:
        v = float(str(s).replace("D", "E").replace("d", "e"))
    except (TypeError, ValueError):
        return None
    return v if math.isfinite(v) else None


# ---------------------------------------------------------------- deck
def read_deck(path):
    raw = open(path, encoding="utf-8", errors="replace").read().split("\n")
    cmds, after_end, ended = [], [], False
    for ln, line in enumerate(raw, 1):
        line = line.rstrip("\r")
        if ended:
            if line.strip() and line.lstrip()[0] not in "#!":
                after_end.append(ln)
            continue
        if not line.strip():
            continue
        # A word reaching column 132 never gets its end set by parse_string, so
        # the supported subset stops at 131 characters.
        G("long", len(line.encode("utf-8")) <= 131,
          f"line {ln} is {len(line.encode('utf-8'))} bytes; YAHFC reads 132 and mishandles a word reaching column 132 (limit 131)")
        G("tab", "\t" not in line, f"line {ln} contains a tab; YAHFC splits words on spaces only, so the tab glues two words into one")
        if line[0] in "#!":
            continue
        G("indent", line[0] != " " or line.lstrip()[0] in "#!",
          f"line {ln} starts with a space; YAHFC skips such lines entirely, so '{line.strip()}' would be ignored")
        if line[0] == " ":
            continue
        cut = len(line)
        for k in range(1, len(line)):
            if line[k] in "#!":
                G("glued", line[k - 1] == " ",
                  f"line {ln}: '{line[k]}' directly after a word; YAHFC ends the line there and loses the word end")
                cut = k
                break
        words = [w for w in line[:cut].split(" ") if w]
        if not words:
            continue
        key = words[0].lower()
        cmds.append((ln, key, words[1:], line, cut < len(line)))
        if key == "end":
            ended = True
    return cmds, after_end


def particle(args):
    """Return the particle label n p d t h a, 'photon', 'population' or None."""
    if not args:
        return None
    if len(args) == 1:
        a = args[0].lower()
        return {"g": "photon", "0": "photon", "n": "n", "1": "n", "p": "p", "2": "p", "d": "d", "3": "d",
                "t": "t", "4": "t", "h": "h", "5": "h", "a": "a", "6": "a"}.get(a)
    z, a = args[0], args[1]
    if z == "-1":
        return "population"
    return {("0", "0"): "photon", ("0", "1"): "n", ("1", "1"): "p", ("1", "2"): "d", ("1", "3"): "t",
            ("2", "3"): "h", ("2", "4"): "a"}.get((z, a))


def target_dir(args):
    """Library directory YAHFC names after the target, e.g. 90Zr; None if not derivable."""
    if not args:
        return None
    if len(args) >= 2 and args[0].isdigit() and args[1].isdigit():
        z = int(args[0])
        return f"{int(args[1])}{SYMBOLS[z - 1]}" if 1 <= z <= len(SYMBOLS) else None
    m = re.fullmatch(r"([A-Za-z]+)-?(\d+)|(\d+)-?([A-Za-z]+)", args[0])
    if not m:
        return None
    sym, a = (m.group(1), m.group(2)) if m.group(1) else (m.group(4), m.group(3))
    sym = sym.capitalize()
    return f"{int(a)}{sym}" if sym in SYMBOLS else None


def deck(path, seed, staged_list):
    global EXIT
    EXIT = 2
    staged = set(x for x in open(staged_list).read().split("\n") if x)
    G("seedenv", re.fullmatch(r"[1-9][0-9]*", seed) is not None,
      f"YAHFC_SEED must be a positive integer without leading zeros (got '{seed}')")
    rawtext = open(path, encoding="utf-8", errors="replace").read()
    first = next((l for l in rawtext.split("\n") if l.strip() and l.lstrip()[0] not in "#!"), "")
    G("wrapper", not (re.match(r"\s*(time\s+)?\S*YAHFC\S*\.x", first) or "<<" in rawtext),
      "this looks like a shell wrapper (.com), not a deck; extract the lines between '<< input' and 'input'")
    cmds, after_end = read_deck(path)
    G("afterend", not after_end, f"commands after 'end' (line {after_end[:1]}) are never read by YAHFC; remove them")
    by = {}
    for c in cmds:
        by.setdefault(c[1], []).append(c)
    seeds = by.get("ran_seed", [])
    G("dupseed", len(seeds) <= 1, "more than one ran_seed; keep one")
    dups = [k for k in SINGLE if k != "ran_seed" and len(by.get(k, [])) > 1]
    G("dupcmd", not dups, f"{dups} given more than once; YAHFC's rank sort is not stable, so which one runs is undefined")
    if seeds:
        G("seedval", len(seeds[0][2]) >= 1 and re.fullmatch(r"[1-9][0-9]*", seeds[0][2][0]) is not None,
          f"ran_seed must be a positive integer (line {seeds[0][0]})")
    ns = by.get("num_mc_samp", [])
    G("nsamp", all(len(c[2]) >= 1 and re.fullmatch(r"[1-9][0-9]*", c[2][0]) for c in ns),
      "num_mc_samp must be a positive integer; YAHFC prints 'using default' and then runs with the bad value, writing NaN")
    vb = by.get("verbose_output", [])
    G("quiet", not any(c[2] and c[2][0].lower()[:1] in "nf0" for c in vb),
      "'verbose_output n' suppresses the stdout this script verifies the run from; remove it")
    proj = particle(by["projectile"][0][2]) if by.get("projectile") else None
    G("mode", proj in ("n", "p", "d", "t", "h", "a"),
      "this wrapper certifies particle-induced (n, p, d, t, h, a) library runs only; photon and population runs "
      "print a different stdout layout and are not supported here" if by.get("projectile") else "the deck sets no projectile")
    G("evgen", not any(c[2] and c[2][0].lower()[:1] in "yt1" for c in by.get("event_generator", [])),
      "event_generator y writes events and no libraries; not supported by this wrapper")
    tdir = target_dir(by["target"][0][2]) if by.get("target") else None
    G("target", tdir is not None, "the deck sets no target this wrapper can name (use Z A or a label such as Zr90)")
    units = (by["cs_units"][0][2][0].lower() if by.get("cs_units") and by["cs_units"][0][2] else "b")
    G("units", units in ("b", "mb"), f"cs_units must be b or mb (got '{units}')")
    files = []
    for c in by.get("proj_e_file", []):
        G("pecomment", not c[4] and len(c[3]) <= 100,
          f"line {c[0]}: YAHFC takes the LAST word up to column 100 of a proj_e_file line, comments included; "
          "put the comment on its own line")
        f = c[2][-1] if c[2] else ""
        G("pename", 0 < len(f.encode("utf-8")) <= 50, f"proj_e_file name '{f}' must be 1 to 50 characters (YAHFC's buffer)")
        files.append(f)
    for c in by.get("cc_file", []):
        files.append(c[2][0] if c[2] else "")
    for f in files:
        G("unstaged", f in staged and "/" not in f,
          f"the deck names input file '{f}' but no file of that name was staged; pass it to run_yahfc.sh (a plain name, no path)")
    out = (by["file"][0][2][0] if by.get("file") and by["file"][0][2] else "YAHFC-Output") + ".out"
    G("reserved", out not in staged and tdir not in staged, f"staged '{out if out in staged else tdir}' would be overwritten by this run")
    print(f"SEED_ACTION={'deck' if seeds else 'inject'}")
    print(f"SEED={seeds[0][2][0] if seeds else seed}")
    print(f"PROJ={proj}")
    print(f"UNITS={units}")
    print(f"TARGET_DIR={tdir}")


# ---------------------------------------------------------------- verdict
def rows(path):
    return [l.split() for l in open(path, errors="replace") if l.strip() and not l.lstrip().startswith("#")]


def verdict(work, rc, seed, proj, units, tdir, fx_log, staged_list):
    os.chdir(work)
    G("rc", rc == "0", f"YAHFC.x exited {rc}")
    out = open("yahfc.stdout", "rb").read().replace(b"\0", b"").decode("utf-8", "replace").split("\n")

    libs = glob.glob(f"*/{proj}/Reaction_cs.dat")
    G("library", len(libs) == 1 and libs[0].split("/")[0].lower() == tdir.lower(),
      f"expected one generated {tdir}/{proj}/Reaction_cs.dat, found {libs}")
    lib = libs[0] if libs else None
    libtop = lib.split("/")[0] if lib else None

    noise = [r"mkdir: Fresco-files: File exists",
             r"mkdir: cannot create directory ['‘\"]?Fresco-files['’\"]?: File exists",
             r"rm: fort\.\*: No such file or directory",
             r"rm: cannot remove ['‘\"]?fort\.\*['’\"]?: No such file or directory",
             rf"rm: {re.escape(libtop or '/')}: No such file or directory",
             rf"rm: cannot remove ['‘\"]?{re.escape(libtop or '/')}['’\"]?: No such file or directory"]
    bad = [l for l in open("yahfc.stderr", errors="replace").read().split("\n")
           if l and not any(re.fullmatch(p, l) for p in noise)]
    G("stderr", not bad, f"unexpected output on stderr: {bad[:3]}")
    G("banner", any("That's all Folks" in l for l in out), "no closing banner (\"That's all Folks\"); the run did not finish")

    ann = [int(m.group(1)) for l in out for m in [re.search(r"Starting energy loop with\s+(\d+)", l)] if m]
    starts = [i for i, l in enumerate(out) if l.startswith("Incident energy =")]
    G("loop", len(ann) == 1 and ann[0] > 0 and len(starts) == ann[0],
      f"{len(starts)} incident-energy blocks for {ann[0] if ann else 'no'} announced energies")

    labels = ["Total cross section", "Total Reaction cross section", "Shape Elastic cross section"]
    need = labels if proj == "n" else ["Total Reaction cross section"]
    table = []
    for b, s in enumerate(starts):
        blk = out[s:(starts[b + 1] if b + 1 < len(starts) else len(out))]
        e = num(blk[0].split("=")[1].split()[0]) if "=" in blk[0] and blk[0].split("=")[1].split() else None
        nchk = sum("Check that all events are accounted for" in l for l in blk)
        nacc = sum("All events are accounted for" in l for l in blk)
        cs = [num(l.split("=")[1]) for l in blk if l.strip().startswith("Check_sum =")]
        G("account", nchk == 1 and nacc == 1 and len(cs) == 1 and cs[0] is not None and abs(cs[0] - 1) <= 1e-8,
          f"energy block {b + 1}: events not accounted for (checks {nchk}, successes {nacc}, Check_sum {cs})")
        found = {}
        for l in blk:
            for k in labels:
                if re.match(rf"{k}\s*=", l):
                    m = re.fullmatch(rf"{k} =\s+(\S+)\s+(b|mb)\s*", l)
                    found.setdefault(k, []).append((m.group(1), m.group(2)) if m else None)
        G("xsfields", all(len(found.get(k, [])) == 1 and found[k][0] is not None for k in need)
          and all(None not in v for v in found.values()),
          f"energy block {b + 1}: expected one well-formed line each for {need}, found "
          f"{ {k: len(v) for k, v in found.items()} } (malformed lines count)")
        G("units", all(found[k][0][1] == units for k in need), f"energy block {b + 1}: cross sections not in '{units}'")
        vals = {k: num(found[k][0][0]) for k in need}
        G("xsvalues", e is not None and e > 0 and all(v is not None and v >= 0 for v in vals.values()),
          f"energy block {b + 1}: energy {e} or cross sections {vals} not finite and non-negative")
        if proj == "n":
            t, r, se = (vals[k] for k in need)
            G("identity", abs(t - (r + se)) <= 2e-7 * max(t, 1e-30) + 1e-12,
              f"E={e}: sigma_tot {t} != sigma_R + sigma_SE = {r + se}")
        table.append((e, vals))
    es = [t[0] for t in table]
    G("xsvalues", len(set(es)) == len(es), f"repeated incident energies {es}")
    G("econs", any("There were no events that violated energy conservation" in l for l in out),
      "events violated energy conservation (or the conservation line is missing)")

    cmdlog = open("YAHFC-commands.txt", errors="replace").read().split("\n") if os.path.exists("YAHFC-commands.txt") else []
    executed = [re.split(r" [#!]", l, maxsplit=1)[0].split() for l in cmdlog if l and l[0] not in "#! "]
    G("seedrun", any(w[:2] == ["ran_seed", seed] for w in executed),
      f"no evidence in YAHFC-commands.txt that 'ran_seed {seed}' executed")

    ins = sorted(glob.glob("Fresco-files/*-ie_*.in"))
    rcs = [l.strip() for l in open(fx_log).read().split("\n") if l.strip()] if os.path.exists(fx_log) else []
    calls = sum(1 for l in out if re.match(r"\s*frescox\s*<", l))
    G("fxexit", len(rcs) == len(ins) == calls and all(x == "0" for x in rcs),
      f"Frescox: {len(ins)} decks, {calls} calls on stdout, {len(rcs)} recorded exits, nonzero: {[x for x in rcs if x != '0'][:3]}")
    pairs = sorted(set(os.path.basename(p).rsplit("-ie_", 1)[0] for p in ins))
    errf = [f"Fresco-files/{q}_fresco_err.out" for q in pairs]
    # gfortran's exit note listing raised IEEE flags is tolerated for the harmless
    # flags only (Linux x86-64 Frescox prints IEEE_DENORMAL on proton runs);
    # INVALID, DIVIDE_BY_ZERO or OVERFLOW can mean a NaN or Inf was made.
    note = re.compile(r"Note: The following floating-point exceptions are signalling:"
                      r"( (IEEE_DENORMAL|IEEE_UNDERFLOW_FLAG|IEEE_INEXACT_FLAG))+")
    errs = [p for p in errf if not os.path.exists(p)
            or any(l.strip() and not note.fullmatch(l.strip()) for l in open(p, errors="replace"))]
    empty = [p for p in ins if not os.path.exists(p[:-3] + ".out") or os.path.getsize(p[:-3] + ".out") == 0]
    G("fxfiles", not errs and not empty, f"Frescox error files missing or non-empty {errs[:2]}, or missing/empty outputs {empty[:2]}")

    r = rows(lib) if lib else []
    G("library", len(r) == len(table) and all(len(x) >= 2 for x in r), f"{lib} has {len(r)} rows for {len(table)} energies")
    for (e, vals), x in zip(table, r):
        le, lv = num(x[0]), num(x[1])
        key = "Total Reaction cross section"
        ok = le is not None and abs(le - e) <= 1e-7 * e and lv is not None \
            and abs(lv - vals[key]) <= 2e-7 * max(vals[key], 1e-30) + 1e-12
        G("library", ok, f"{lib} row ({x[0]}, {x[1]}) does not match stdout E={e}, sigma_R={vals[key]}")

    libdat = glob.glob(f"{libtop}/**/*.dat", recursive=True) if libtop else []
    badu = []
    for p in libdat:
        for m in re.finditer(r"xs\(\s*(\w+)\)", open(p, errors="replace").read()):
            if m.group(1) != units:
                badu.append(p); break
    G("units", not badu, f"library files declare units other than '{units}': {badu[:3]}")
    neg = []
    for p in (q for q in libdat if re.search(r"_cs(_|\.)", os.path.basename(q))):
        for x in rows(p):
            if any(NUM.match(t) and float(t.replace("D", "E")) < 0 for t in x):
                neg.append(p); break
    G("libvalues", not neg, f"negative numbers in cross-section files {neg[:3]}")

    bad = []
    for p in libdat + glob.glob("*.tcoef") + glob.glob("*-CC.data"):
        for l in open(p, errors="replace"):
            s = l.strip()
            if not s:
                continue
            if s.startswith("#"):
                if re.search(r"=\s*\*{3,}", s) or re.search(r"(?i)(?<![a-z])(nan|inf|infinity)(?![a-z])", s):
                    bad.append(p); break
            elif "*" in s or re.search(r"(?i)(?<![a-z])(nan|inf|infinity)(?![a-z])", s) \
                    or any(NUM.match(t) and num(t) is None for t in s.split()):
                bad.append(p); break
    for p in [q for q in glob.glob("Fresco-files/*") if not q.endswith(".in")] + ["yahfc.stdout"]:
        for l in open(p, errors="replace"):
            if re.search(r"(?i)(?<![a-z])(nan|inf|infinity)(?![a-z])", l) \
                    or (re.search(r"[0-9.]\*{3,}", l) and not re.fullmatch(r"\s*\d?\*+\s*", l)):
                bad.append(p); break
    G("finite", not bad, f"non-finite or overflowed numbers in {sorted(set(bad))[:4]}")

    staged = set(x for x in open(staged_list).read().split("\n") if x)
    with open("provenance.txt", "a") as f:
        for t in sorted(glob.glob("*.tcoef")):
            computed = bool(glob.glob(f"Fresco-files/{t[:-6]}-ie_*.in"))
            if t in staged:
                f.write(f"tcoef {t} staged; {'RECOMPUTED by frescox (its -CC.data was not staged with it)' if computed else 'used, not recomputed'}\n")
            else:
                f.write(f"tcoef {t} computed by frescox in this run\n")
        f.write(f"energies {len(table)}\nunits {units}\nlibrary {lib.rsplit('/', 1)[0] if lib else 'none'}\n")
        f.write("frescox_exits " + " ".join(rcs) + "\n")

    print(f"run_yahfc: OK, {len(table)} energies, every event accounted for, no energy-conservation violations, "
          f"{len(ins)} Frescox runs all exit 0")
    hdr = "sigma_tot  sigma_R  sigma_SE" if proj == "n" else "sigma_R"
    print(f"#  E_inc(MeV)  {hdr}   (units: {units})")
    for e, vals in table:
        print("   " + "  ".join(f"{v:.7E}" for v in [e] + [vals[k] for k in need]))
    for p in (sorted(glob.glob(f"{libtop}/*/f/fission_cs.dat")) if libtop else []):
        print(f"#  fission, {p}:  E_inc(MeV)  sigma_f (units: {units})")
        for x in rows(p):
            print(f"   {x[0]}  {x[1]}")


if __name__ == "__main__":
    if sys.argv[1:2] == ["deck"]:
        deck(*sys.argv[2:5])
    elif sys.argv[1:2] == ["verdict"]:
        verdict(*sys.argv[2:10])
    else:
        sys.exit("usage: yahfc_check.py deck|verdict ...")
