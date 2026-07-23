# NuclearToolkit.jl examples

The benchmark is not a copied deck. NuclearToolkit.jl is a Julia library, and its
inputs are function calls plus the interaction files that ship inside the package
(`test/interaction_file/ckpot.snt`, `usdb.snt`). `run_nucleartoolkit.sh` resolves
those from the installed package, which is more faithful than a hand-copied input.

Run a shell-model calculation (default: Be-8 with the Cohen-Kurath p-shell
interaction, 10 states):

```bash
bash ../scripts/run_nucleartoolkit.sh                 # Be8 ckpot 10 -> g.s. -31.1194 MeV
bash ../scripts/verify_nucleartoolkit.sh              # tier-1 benchmark (CKpot anchor + full Pkg.test)
NTK_FAST=1 bash ../scripts/verify_nucleartoolkit.sh   # L1 only (fast)
```

Other shell-model cases (nucleus, interaction, n_eigen):

```bash
bash ../scripts/run_nucleartoolkit.sh Li6 ckpot 3     # p-shell
bash ../scripts/run_nucleartoolkit.sh O18 usdb 5      # sd-shell, USDB (g.s. -11.93 MeV)
bash ../scripts/run_nucleartoolkit.sh Ne20 usdb 5     # sd-shell
```

`ckpot` covers the p-shell (He/Li/Be/B/C isotopes); `usdb` covers the sd-shell
(O/F/Ne/Na/Mg/... isotopes). Pick the interaction whose model space contains the
nucleus.

## The ab initio pipeline

The package's signature workflow is chiral EFT -> HFMBPT/IMSRG -> shell model.
It is exercised end to end by `verify_nucleartoolkit.sh` (the full `Pkg.test`,
which reproduces the He-4 IMSRG ground state -4.05225276 MeV to 1e-6). To author
your own, follow `../references/input-format.md` (Workflow B): `make_chiEFT()`
builds the interaction, `hf_main(...; doIMSRG=true)` runs HFMBPT and the IMSRG
(with `valencespace=...` to emit a VS effective interaction), and `main_sm(...)`
diagonalizes the shell model with it. The distribution's `example/sample_script.jl`
(under `$NTK_PKGDIR/example/`) is the reference template; it does O-16 -> Mg-24 at
emax=4 and is a few-minute calculation.

## Cost

The shell-model examples are seconds. The ab initio pipeline scales sharply with
`emax`: emax=2 (He-4) is seconds, emax=4 is minutes, larger emax needs a remote
box with many threads (`julia -t N`) and substantial memory.
