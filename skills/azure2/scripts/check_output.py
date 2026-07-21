#!/usr/bin/env python3
"""
Validate the NUMERIC STRUCTURE of an AZURE2 result file.

Greping for nan and inf is not enough, which an adversarial pass demonstrated
with three separate files that all passed a nan/inf check and were all garbage:
a truncated final line with no newline, a column reading 1e9999 (which parses to
inf without containing the letters "inf"), and a line of non-numeric words.

A .extrap line is 5 columns, a .out line is 9, and an .acoeff line varies, so
the column count is taken from the file's own first data line and every
subsequent line must match it. What is enforced:

  - at least one data line
  - every line has the same number of fields as the first
  - every field parses as a float and is finite
  - the file ends with a newline (a truncated write does not)

Exit 0 if the file is sound, 1 otherwise, with the reason on stderr.
"""
import math
import sys


def check(path):
    try:
        raw = open(path, "rb").read()
    except OSError as e:
        return f"cannot read: {e}"
    if not raw:
        return "file is empty"
    if not raw.endswith(b"\n"):
        return "file does not end with a newline (truncated write?)"
    try:
        text = raw.decode()
    except UnicodeDecodeError as e:
        return f"not text: {e}"

    ncol, nrow = None, 0
    for lineno, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        fields = line.split()
        if ncol is None:
            ncol = len(fields)
            if ncol < 2:
                return f"line {lineno}: only {ncol} column(s), not a data table"
        elif len(fields) != ncol:
            return (f"line {lineno}: {len(fields)} columns, but the first data "
                    f"line has {ncol}")
        for i, tok in enumerate(fields, 1):
            try:
                v = float(tok)
            except ValueError:
                return f"line {lineno} column {i}: {tok!r} is not a number"
            if not math.isfinite(v):
                return f"line {lineno} column {i}: {tok!r} is not finite"
        nrow += 1
    if nrow == 0:
        return "no data lines"
    return None


def main(argv):
    if len(argv) < 2:
        print("usage: check_output.py <file> [file ...]", file=sys.stderr)
        return 2
    bad = 0
    for path in argv[1:]:
        why = check(path)
        if why:
            print(f"check_output: {path}: {why}", file=sys.stderr)
            bad = 1
    return bad


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
