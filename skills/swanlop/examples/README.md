# SWANLOP examples

The benchmark deck is not copied here: it ships inside the SWANLOP archive that
`install_swanlop.sh` downloads, as `runs/fort.quick-start` (p+208Pb elastic at
30.3 MeV, Tian-Pang-Ma nonlocal potential), together with its shipped reference
outputs `runs/zz.{main,xaq,dsdt}.REF`. Reproducing a deck the distribution ships,
against the reference it ships, is the whole point of a tier-1 benchmark.

Run the benchmark:

```bash
bash ../scripts/run_swanlop.sh                  # the shipped quick-start
bash ../scripts/verify_swanlop.sh               # tier-1 check against zz.*.REF
```

Run a custom deck by passing a fort.1 file whose lines follow the order in
`../references/input-format.md`:

```bash
bash ../scripts/run_swanlop.sh /path/to/my_fort.1
```

Other cases the code supports (edit the deck): neutron projectiles, Perey-Buck
built-in (KPOT=1), local optical potentials (KPOT=0, needs a fort.22), and reading
an external microscopic nonlocal potential in coordinate (KPOT=3, VRR) or momentum
(KPOT=4, VKK) space, needing a fort.2 from `../udata/` or the CPC supplementary
tables. The shipped `runs/temp00`..`temp04` are starting templates (README_runs
says one per KPOT, but check the KPOT line: the shipped temp00 sets KPOT=2 despite
its title). Place a run's fort.2/fort.22 in the same directory as its fort.1 and
run_swanlop.sh copies them into the scratch run.
