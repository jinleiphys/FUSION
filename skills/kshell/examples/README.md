# KSHELL examples

The benchmark is not a copied deck: it is built from the interaction files that
ship in the cloned repo's `snt/` directory (`usda.snt`) plus a partition generated
on the fly by `gen_partition.py`. Reproducing a case from the distribution's own
interactions is more faithful than a hand-copied input.

Run the benchmark (^20Ne, USDA, 5 lowest M=0 states):

```bash
bash ../scripts/run_kshell.sh                       # defaults to usda.snt 2 2 1 0 5
bash ../scripts/verify_kshell.sh                    # tier-2 check (cross-build spectrum + band physics)
```

Run other cases by passing `<snt> <valence_p> <valence_n> <parity> <mtot> <n_eigen>`
(valence numbers are relative to the interaction's core):

```bash
bash ../scripts/run_kshell.sh usdb.snt 2 2 1 0 5    # 20Ne with USDB instead of USDA
bash ../scripts/run_kshell.sh usda.snt 4 4 1 0 5    # 24Mg (4 valence p + 4 valence n above 16O)
bash ../scripts/run_kshell.sh kb3g.snt 4 4 1 0 3    # 48Cr in the fp shell (40Ca core), KB3G
```

The shipped `test/Ne20_usda/` and `test/v2_to_v4/` directories in the cloned repo
hold the upstream test scripts (including a version-regression comparison); they
are driven by the interactive `kshell_ui.py` and are not used by the skill, which
calls `gen_partition.py` and `kshell.exe` directly for reproducibility.

The 25 shipped interactions (`ls snt/` in the clone) span the sd shell (usda,
usdb, w), the fp shell (gxpf1a, kb3g, fpd6), the upper fp-g region (jun45, jj44*),
the Sn region (sn100*), and others. Pick the interaction whose model space
contains the nucleus.
