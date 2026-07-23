---
name: exfor-data
description: >-
  Retrieve real measured nuclear reaction data (cross sections, angular distributions, spectra, resonance data) from the IAEA EXFOR database and parse it into clean columns for comparison with a calculation. Use whenever experiment enters the picture: 实验数据, 有没有实验数据, 找实验点, EXFOR, 对比实验, compare with experiment, measured cross section, angular distribution data, add the data to this plot, is there data at this energy. Also use before claiming that a measurement does or does not exist.
---

# EXFOR: experimental nuclear reaction data

EXFOR is the IAEA's compilation of essentially all measured nuclear reaction data: cross sections, angular distributions, energy spectra, polarizations, resonance parameters. It is the authority for "what has actually been measured" and the natural partner to any optical-model, CDCC, or reaction calculation that needs a comparison.

This skill covers getting real numbers out of it and not getting them wrong.

## Prime directive

**Every data point you report must come from an actual retrieval performed in this task.** Never reconstruct an experimental dataset from memory, and never fill a gap with plausible-looking numbers. Fabricated data in a figure is worse than no figure, because it looks like evidence and will survive into a manuscript.

The corollary matters just as much: **"there is no measurement at that energy" is a real, valuable, publishable answer.** Users often ask to "add the experimental data" assuming it exists. Frequently it does not exist at their exact energy, or exists only on a natural-isotope target, or only over a restricted angular range. Say so plainly and offer the nearest real alternatives. Do not stretch a nearby dataset and quietly relabel it.

## Access: what works and what does not

Two things will waste your time if you discover them the hard way:

- **The interactive search servlet cannot be scripted.** `X4sSearch5` answers `Define Search Criteria!` to every GET and POST, whatever parameter names you use, because the real form is JavaScript-built and session-bound. Do not spend calls trying to reverse-engineer it.
- **WebFetch may return HTTP 402** on `www-nds.iaea.org`. That is a proxy artifact, not a paywall (EXFOR is free). Plain `curl` and Python `urllib` reach the site fine.

What does work is per-entry retrieval, which is what `scripts/exfor.py` uses:

```
https://www-nds.iaea.org/exfor//servlet/X4sGetEntry?acc=<5-digit accession>&reqx=1
```

So the workflow is inverted from what you would expect: you find the accession number first, then pull the entry.

## Workflow

### 1. Find the accession number

This is the only genuinely hard step, since you cannot query by reaction. In rough order of reliability:

- **Web search naming the measurement**: authors, target, projectile, energy, plus the word EXFOR. Search results frequently expose `X4sGetEntry?acc=NNNNN` or `X4sGetSubent?subID=NNNNNNNN` URLs directly.
- **Work backwards from the literature.** Papers that use the data cite the original measurement. Get author and year from the paper (a literature search skill is good for this), then search EXFOR for that author.
- **Guess neighbours.** Entry numbering is by compilation centre, so related measurements from one group often sit close together.

Accession numbers are 5 digits; subentries append 3 more (`13160` -> `13160004`).

### 2. List what the entry contains

```bash
python scripts/exfor.py list 13160
```

One accession usually holds an entire experimental campaign, not a single curve. Entry 13160 is one paper covering four Zr isotopes at three energies, elastic and inelastic: 20+ subentries. Listing first tells you every target, energy, and reaction available, which often answers the user's question immediately.

### 3. Pull the table

```bash
python scripts/exfor.py data 13160004 --header
python scripts/exfor.py data 22480005 --energy 55 --columns ANG-CM DATA DATA-ERR
```

Output is tab-separated columns with `#` comment lines carrying the reaction, sample composition, incident energy, and **units for every column**. Read those comment lines; they are where the traps live.

### 4. Use it, checking frames and units

Match the calculation to the data, not the other way round. If the data are centre-of-mass, compare in centre-of-mass. If the target is natural, either compute for the natural isotopic mix or say explicitly that you are approximating it.

## Traps that silently corrupt results

These are why the bundled parser exists and why you should read the header lines.

**Fixed-width columns.** EXFOR data are 6 fields of exactly 11 characters per line. A blank field means "not measured" and must stay blank. Splitting on whitespace collapses it and shifts every later column into the wrong slot, producing numbers that look reasonable and are wrong. `scripts/exfor.py` parses by column position. If you ever parse by hand with awk, verify the row count and a few values against the raw text.

**Errors are sometimes percentages.** `DATA-ERR` carries whatever unit the compiler used. In EXFOR 22480.007 it is `PER-CENT`, while in 13160.004 it is `MB/SR`. Treating a percentage as absolute silently destroys every error bar. Always read the units line.

**Lab versus centre of mass.** `ANG` and `DATA` are laboratory frame; `ANG-CM` and `DATA-CM` are centre of mass. Both conventions appear, sometimes in the same entry. For light projectiles on heavy targets the difference is small enough to look plausible and large enough to be wrong.

**Natural versus isotopic targets.** `40-ZR-0` is natural zirconium, a mix; `40-ZR-90` is the separated isotope. Even "enriched" samples are not pure, and the `SAMPLE` field records the composition (97.7% in 13160). This matters whenever the physics depends on N or on a shell closure.

**Where the energy lives.** Single-energy subentries put `EN` in the `COMMON` block; multi-energy ones make `EN` a data column; and an entry that used one energy throughout hoists it into subentry `xxx001`, so it appears nowhere in the subentry you actually want. The script merges all three, so `list` and `data` report the energy wherever it was filed. If you ever read an entry by eye and the energy seems missing, look at `001`.

**Restricted angular coverage.** Forward-angle-only datasets are common in high-energy neutron work. Check the angular range before promising a full comparison.

## Worked example

The question "add the EXFOR data to my n + 90Zr elastic calculation at 50 MeV" resolves like this:

1. Search identifies two relevant measurements: Wang and Rapaport (entry 13160) and an Ibaraki TIARA campaign (entry 22480).
2. `list 13160` shows 90Zr elastic at 8.0, 10.0 and 24.0 MeV only.
3. `list 22480` shows natural Zr at 55, 65 and 75 MeV, forward angles.
4. Conclusion: **there is no 50 MeV measurement.** The honest deliverable is the calculation at 50 MeV plus validation against 24 MeV (isotopically clean, full angular range) and 55 MeV (nearest energy, natural target, forward angles), each computed at its own measured energy rather than one curve stretched across the gap.

That negative result is the most useful part of the answer, and reporting it is the skill working correctly.

## Reference

`references/exfor-format.md` covers the REACTION string syntax, process and quantity codes, standard column names and units, entry-number ranges by compilation centre, and verified example entries. Read it when a reaction code or column name is unfamiliar.
