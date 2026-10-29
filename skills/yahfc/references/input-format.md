# YAHFC input reference

Source: the manual's Appendix "Input Commands" (`Documentation/YAHFC-Manual.tex`,
line 1136 on), checked against the code at the pinned commit 18af2fe: command
names against the dispatch strings in `parse-command.f90`, defaults against the
code that sets them (global ones in `YAHFC-Master.f90` lines 500-835, model and
particle dependent ones where cited). Where they disagree the code wins and the
row says so. Defaults without a citation are as the manual states and were
spot-checked, not traced individually.

## Syntax

How YAHFC reads a deck (`YAHFC-Master.f90:881-905`, `parse_string` at
`parse-command.f90:3698`); `run_yahfc.sh` reproduces this reader and refuses the
cases marked *refused*, because YAHFC would ignore or misread them silently:

- One command per line from stdin, each read into **132 characters**; the rest
  of a longer line is dropped (*refused*).
- A line whose **first character is `#`, `!` or a space is skipped entirely**.
  So an indented command is ignored without a message (*refused*); an indented
  comment is fine.
- Words are split on **spaces only**. A tab is part of a word, so
  `target<TAB>Zr90` is one unknown word (*refused*).
- `#` or `!` from column 2 on ends the line. Put a space before it: glued to a
  word (`xs_only y#note`) it leaves that word's end unset (*refused*).
- `proj_e_file` is special: YAHFC takes the **last word up to column 100 of the
  raw line**, comment text included (`parse-command.f90:590-607`), so
  `proj_e_file elist.txt # grid` opens a file called `grid` (*refused*).
- Reading stops at `end` or at end of input; anything after `end` is never read
  (*refused*). The commands are then ranked and executed in YAHFC's own order,
  written to `YAHFC-commands.txt` (first line `#YAHFC commands in order of
  execution`, then the default seed information, then the commands; an explicit
  `ran_seed` appears among them).
- Any case; command words are lower-cased. They must be spelled exactly: an
  unknown command prints `COMMAND NOT RECOGNIZED` and exits 101.
- Nuclei: `Z A` or a label, all equivalent: `92 238`, `U238`, `238U`, `U-238`,
  `238-U`.
- Particles: index or label: 0 `g`, 1 `n`, 2 `p`, 3 `d`, 4 `t`, 5 `h` (3He),
  6 `a`.
- Yes/no answers: `y`, `1`, `t` for yes; `n`, `0`, `f` for no.

## Environment

| variable | meaning |
|---|---|
| `YAHFC_DATA` | data directory (`$YAHFC_DIR/Data/`). The manual calls it `$YAHFC_DAT`; the code reads `YAHFC_DATA` (`YAHFC-Master.f90:799`). Unset, the code does not stop with its own message: it looks for `/mass-frdm95.dat` and dies with a Fortran runtime error (exit 2). |
| `YAHFC_DIR` | top of the source tree. |
| PATH | must find `frescox` (LLNL Frescox, not FRESCO). |

`run_yahfc.sh` sets all three from the installer.

## General commands

| command | arguments | meaning, default |
|---|---|---|
| `file` | name | output name; writes `name.out`. Default `YAHFC-Output` (`YAHFC-Master.f90:1294`; the manual says `YAHFC-Calc`). |
| `target` | Z A [k] or label | target; optional k = RIPL-3 state number (1 = ground). |
| `target_state` | k | preferred way to set the target state. Default 1. |
| `projectile` | Zp Ap, or index/label | incident particle. Population calculation instead: `-1 -1 Ex dEx` (single Ex, Gaussian width, J-pi bins weighted by level density) or `-1 0 file.pop` (populations from a file). A population run switches off width fluctuations and pre-equilibrium and switches on `track_gammas` (`YAHFC-Master.f90:1332-1335`). Not supported by `run_yahfc.sh`, which certifies particle-induced runs only. |
| `proj_eminmax` | Emin Emax Estep | incident energy grid (MeV). Energies are moved to the centre of the continuum bins of width `delta_e`; the lowest allowed is delta_e/2. |
| `proj_e_file` | file | incident energies, one per line. Energies above delta_e/2 are moved onto bin centres, lower ones kept. The file must be in the run directory (stage it with `run_yahfc.sh`). |
| (neither) | | default grid of 216 energies (`parse-command.f90:5042-5064`): 15 points from 1e-4 to 0.09 MeV, then 0.1 to 20.1 MeV in steps of 0.1, before the mapping onto bin centres (which can merge points). The manual's "0.2 MeV steps to 20 MeV" is not what the code builds. |
| `delta_e` | dE | continuum bin width. Default 0.1 MeV. |
| `num_mc_samp` | N | Monte Carlo events per energy. Default 1000000. **N < 1 prints "Invalid value using default" and then runs with N anyway** (`parse-command.f90:2262`), writing NaN; `run_yahfc.sh` refuses it. |
| `ran_seed` | integer | seed. **Without it the seed comes from the system clock** and runs are not reproducible. |
| `max_j_allowed` | NJ | maximum J. Default 20 (+1/2 for odd A). |
| `all_discrete_states` | y/n | n (default): discrete levels only up to Ecut. y: all discrete states with full decay paths. |
| `max_particle` | k N | cap on emitted particles of type k (1..6). Defaults: n, p unlimited (-1); d, t, h, a 0. Do not cap neutrons. |
| `biased_sampling` | y/n | **The manual's y/n labels are inverted.** Default (code `.false.`): the decay branch is chosen with equal probability among the enabled emitted-particle types and the tally carries the compensating Hauser-Feshbach weight, which the manual calls "unbiased (Default)"; final states within a branch are then sampled from their own distribution. `y` chooses the branch in proportion to the Hauser-Feshbach probabilities (analog). `HF-decay-MC.f90:158-184`, branches built in `HF_denominator.f90:640-644`. |
| `wf_model` | 0/1 | width fluctuations: 0 none, 1 Moldauer (default). |
| `moldauer_cutoff` | X | no width fluctuations above this sum of transmission coefficients. Default 50. |
| `prob_cut` | P | skip decays below this probability. Default 1e-7; lower it when delta_e is reduced. |
| `trans_p_cut`, `trans_e_cut` | T | particle / EM transmission-coefficient cut in the HF denominators. Defaults 1e-7 / 1e-14. |
| `beta_2` | Z A b2 | deformation of a nucleus. |
| `t12_isomer` | t (s) | half-life above which a RIPL-3 level is an isomer. Default 1 s. |
| `num_theta_angles` | N | angles sampled per event. Default 10. |
| `xs_only` | y/n | y: cross sections only, no spectra or angular distributions (much faster). Default n. |
| `explicit_channels` | y/n | y: nnp, npn, pnn are distinct channels. **Default n in the code** (`YAHFC-Master.f90:550`) and in the manual's library chapter; the manual's appendix says y. |
| `primary_decay` | y/n | write first-step cross sections to `Primary-decay/`. Default n. |
| `dump_events` | y/n [a/b] | write every event (ascii or binary). Default n. |
| `event_generator` | y/n [y/n] | events only, no libraries; second answer labels event files by energy index. Default n. |
| `initial_ke` | T dT | initial kinetic energy of the decaying nucleus (population runs only; fission fragments). |
| `cs_units` | b / mb | units of every cross section, on stdout and in the libraries. Default b. `run_yahfc.sh` reports the units it found and checks them against the deck. |
| `use_eval_levels` | y/n | read evaluated discrete levels from `levels-eval`. Default y. |
| `use_saved_parameters` | y/n | read `saved-parameters.txt` from `my-saved-parameters/` then `saved-parameters/` under the data directory. Default n. |
| `use_unequal_bins` | y/n | bins widen with excitation energy. Default n. |
| `clean_library` | y/n | delete the library directories at the start of the run (`rm -r`). Default y. |
| `write_outfile` | y/n | write `name.out`. Default y. |
| `verbose_output` | y/n | **Inverted in the manual**, which says y suppresses stdout: the code sets `verbose` to the answer (`parse-command.f90:3370`) and the default is `.true.` (full stdout), so `n` is the one that quiets it. |
| `end` | | ends the command list. The manual calls it terminating; at end of input YAHFC also stops. |

## Gamma decay

| command | arguments | meaning, default |
|---|---|---|
| `global_e1_model` / `e1_model` | j / Z A j | E1 strength: 1 Lorentzian, 2 Kopecky-Uhl (default), 3 modified Kopecky-Uhl. |
| `el_param` / `ml_param` | Z A L j E Gamma S | j-th resonance of EL / ML strength; j <= 3 overrides `gdr-parameters-exp.dat`. j = 3 is the extra resonance used to fit Gamma_gamma; entering parameters by hand suspends that fit. |
| `read_el_gsf` / `read_ml_gsf` | Z A L c file [norm] | strength from a file; c = f strength function, s photoabsorption cross section. |
| `max_num_gsf` | N | maximum number of strength functions. Default 4. |
| `global_fit_gamma_gamma` / `fit_gamma_gamma` | y/n / Z A y/n | fit an added E1 resonance (5 MeV, 5 MeV wide) to Gamma_gamma. Default y. The fitted strength can be negative. |
| `set_gamma_gamma` | Z A Gg | set the s-wave radiative width. |
| `track_gammas` | y/n | track discrete gammas. Default n (y for population runs). |
| `e_l_max`, `m_l_max` | L | maximum EL / ML multipolarity. Default 3. |

## Level density

| command | arguments | meaning, default |
|---|---|---|
| `global_lev_option` / `lev_option` | i / Z A i | 0 Gilbert-Cameron; 1 TALYS defaults; 2 collective enhancement. **Default by mass** (`YAHFC-Master.f90:1043-1048`): 0 for A <= 20, 1 for 20 < A <= 130, 2 above 130 (the manual omits the A <= 20 case). Ignatyuk a(U) for 1 and 2. |
| `global_lev_fit_d0` | y/n | fit to D0 by adjusting the shell correction. Default y. |
| `global_lev_fit_aparam` | y/n | manual: when fitting D0, adjust a-tilde instead. **Probably has no effect**: it sets a global flag (`modules.f90:50`), while `fit_D0` receives a per-nucleus flag (`level-density.f90:755`) that `decay-chain.f90:419-431` sets from the level-density option (true for option 0, false for the heavy-nucleus options), and nothing copies the global into it. Read from the source, not tested in a run. |
| `global_lev_fit_ematch` | y/n | fit Ematch to the cumulative discrete levels. Default y. |
| `lev_aparam`, `lev_delta`, `lev_shell`, `lev_gamma`, `lev_ematch`, `lev_ecut` | Z A value | a-tilde, pairing Delta, shell correction dW, damping gamma (default depends on the level-density option: 0.43309/A^(1/3) in one branch, 0.473625/A^(1/3) in another, `level-density.f90:444` and `:536`), matching energy, level cut-off (must be below the default Ecut). |
| `lev_d0` | Z A D0 dD0 | override the RIPL-3 D0. |
| `lev_parity_fac` | Z A PAR E0 B | parity factor 0.5 tanh(B(Ex-E0)). Default 0.5. |
| `lev_sig_model`, `lev_spin_cut` | Z A k / Z A X | spin cut-off model and factor (default X = 0.01389). |
| `lev_rot_enhance`, `lev_vib_enhance` | Z A k X1 X2 X3 | collective enhancement and its damping X1/(1+exp((Ex-X2)/X3)). |
| `lev_vib_enhance_mode` | k | global vibrational-enhancement model. |
| `lev_den_read` | Z A P file | level density from a file (P = +, -, or b for both). |

## Fission

All per barrier j of nucleus Z A; they override
`$YAHFC_DATA/Fission/empirical-barrier.dat`.

| command | arguments | meaning, default |
|---|---|---|
| `f_num_barrier` | Z A N | number of barriers. Give it before the per-barrier commands. |
| `f_barrier` | Z A j EB hw | height and curvature. |
| `f_barrier_damp` | Z A j X2 X3 | Gaussian damping of the barrier with Ex. Default none. |
| `f_lev_aparam`, `f_lev_spin`, `f_lev_delta`, `f_lev_shell`, `f_lev_gamma`, `f_lev_ematch`, `f_lev_ecut` | Z A j value | level density above barrier j. **The manual's `f_ecut` is not a command; the code parses `f_lev_ecut`** (`parse-command.f90:1761`). Defaults are not all "as the compound nucleus": the shell correction is set to 1.5 MeV (barrier 1) and 0.6 MeV (barrier 2) (`fission-model.f90:816-817`). |
| `f_beta2` | Z A j b2 | barrier deformation (absolute value). **The manual's `f_beta_2` and `f_scale_beta_2` are not commands.** Default 2 b2 (inner) and 4 b2 (outer) (`fission-model.f90:792-795`, and the manual's main text; its appendix says 2.5 and 4.5). |
| `f_barrier_symmetry` | Z A j k | 1 axial, 2 left-right asymmetric, 3 and 4 triaxial variants. **The manual spells it `f_lev_barrier_symmetry`, which the code does not parse** (only `f_barrier_symmetry`, `parse-command.f90:1705`), so the manual's spelling stops the run with exit 101. |
| `f_lev_rot_enhance`, `f_lev_vib_enhance` | Z A j X1 X2 X3 | collective enhancement above the barrier. |
| `fiss_max_j` | Jmax | barriers vanish at Jmax. Default 0 (off). **The manual's `f_max_J` is not a command**; the code parses `fiss_max_j` (`parse-command.f90:3211`), and that branch writes `F_Barrier(i)` with the nucleus index where the barrier index is expected (line 3222), so check its effect before relying on it. |
| `global_use_tran_states`, `f_use_tran_states` | (Z A) y/n | discrete transition states. Default y. |
| `f_barr_states`, `f_spect_scale` | Z A j file / X | read transition states; scale their spectrum. |

## Pre-equilibrium

| command | arguments | meaning, default |
|---|---|---|
| `preeq_model` | 0/1 | 0 off, 1 two-component exciton (default). |
| `preeq_pair_model` | i [Delta] | -1 none, 0 Eq. 10 of NPA 744, 15 (2004), 1 Fu (default), 2 the given Delta. |
| `preeq_m2_c1`, `preeq_m2_c2`, `preeq_m2_c3` | C | matrix-element constants. Default 1. |
| `preeq_well_v`, `preeq_well_v1` | V | well depth V and minimum depth V1 of the excitation-dependent well. **The manual's `preeq_v`, `preeq_v_n`, `preeq_v_p` are not commands** (`parse-command.f90:2380`, `:2406`). Defaults set by the incident particle (`parse-command.f90:338-346`): V = 38 MeV; V1 = 12 MeV for neutrons (the manual's appendix says 32; its main text says 12) and 22 MeV for protons. One V1 applies to the run, not one per species. |
| `preeq_g_div`, `preeq_g_a` | g / i | single-particle density g = A/g_div (default 15), or from the level-density a (i = 1). |
| `preeq_analytic` | y/n | analytic transition rates. Default n. |

## Optical model and direct reactions

| command | arguments | meaning, default |
|---|---|---|
| `optical_potential` | k j | for n and p: 1 Koning-Delaroche (default outside 90 <= Z <= 96), 2 Soukhovitskii (default for 90 <= Z <= 96), 3 Maslov 03, 4 Soukhovitskii-Capote 20. d, t: Perey. 3He: Becchetti. alpha: Avrigeanu. |
| `fresco_shape` | i | shape in the Frescox calculation. Default 13. |
| `cc_file` | file | coupled-channels / DWBA states; default `$YAHFC_DATA/Coupled-Channels.txt`. Name is case sensitive; stage it into the run directory. |
| `do_dwba` | y/n | DWBA for direct inelastic to the states in the cc file. Default n. DWBA states are mapped onto the delta_e grid, so results cannot be reused with another delta_e. |
| `scale_elastic` | S A B | scale shape elastic by S(1+A(1-exp(-B E))); transmission coefficients rescaled to conserve elastic plus absorption. |
| `trans_avg_l` | y/n | average the j = l +- 1/2 transmission coefficients. Default n. |
| `trans_norm` | T | global rescale of transmission coefficients. Default 1. Use with care. |
| `cc_scale` | X | scale the DWBA couplings. Default 1. |

## Transmission-coefficient files

At each run YAHFC looks in the run directory for `<proj><target>.tcoef`
(`nZr90.tcoef`, `pY90.tcoef`, ...). For the incident particle it reuses the file
**only if the matching `<proj><target>-CC.data` is there too**
(`optical_setup.f90:184-199`); with either missing it calls Frescox, which
rewrites both, with the decks in `Fresco-files/`. Stage a pair, never one half.
`run_yahfc.sh` records afterwards whether each staged `.tcoef` was used or
recomputed, judged from the Frescox decks the run wrote. `$YAHFC_DATA/Trans-coeff/CC-DWBA/` ships 25 FRESCO-computed
coupled-channels `.tcoef` and `-CC.data` files (actinides and others); stage
them deliberately when a deck relies on them, as the LLNL actinide examples do.
