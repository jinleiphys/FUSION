# SIDES examples

The benchmark deck is not copied here: it ships inside the SIDES archive that
`install_sides.sh` downloads from Mendeley Data, as `INPUT` in the source
directory (n + 40Ca at 20 MeV, Tian-Pang-Ma nonlocal potential). Reproducing a
deck the distribution ships is more faithful than a hand-copied one.

Run the benchmark:

```bash
bash ../scripts/run_sides.sh                 # the shipped INPUT (n+40Ca 20 MeV TPM)
bash ../scripts/verify_sides.sh              # tier-2 check (cross-build pin + optical theorem)
```

Run a custom deck by passing a stdin file whose lines follow the order in
`../references/input-format.md`:

```bash
bash ../scripts/run_sides.sh /path/to/my_deck
```

Other cases the code supports out of the box (change the deck): proton
projectiles (line 1 = 1, Coulomb included), Perey-Buck nonlocal (neutron only),
Koning-Delaroche local, multi-energy runs via an `ENERGIES` file, and reading an
external microscopic potential (potential choice 1).
