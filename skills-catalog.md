# FUSION per-code skill catalog

The core product of FUSION: **every excellent open-source nuclear-physics code gets its own expert skill**, modeled on the existing fresco skill (install/build, input authoring, run, output parsing, plus at least one benchmark reproducing a published value to stated precision). This file is the living roadmap; the fresco skill is the reference implementation.

Status legend: [ ] not started, [S] skill exists, [V] open-source status needs verification before committing (some famous codes are free-binary or licensed, not open).

## Reactions: coupled channels / DWBA / breakup

- [S] **FRESCO** (Thompson) — coupled channels, CC/CRC/CDCC/transfer/capture. The template skill; embedded in-repo at `skills/fresco/` (2026-07-14) with binary auto-install from github.com/I-Thompson/fresco (install_fresco.sh). Reference for both the skill house style and the auto-provision pattern.
- EXCLUDED **THOx** (Sevilla, Moro group) — NOT publicly released (internal code), so no FUSION skill (hard rule).
- [x] **CCFULL** (Hagino, Rowley, Kruppa; CPC 123 (1999) 143) DONE: skills/ccfull/, fetch+build from Kyoto page, 16O+144Sm fusion reproduces reference barrier + sub-barrier excitation function exactly, tail to 4-5 sig figs (2026-07-20). Interactive-stdin quirk documented.
- [V] **ECIS** (Raynal), coupled channels + optical model fits. Source located: RIPL, nds.iaea.org/RIPL/codes/ECIS/ (also OECD NEA data bank). License still to verify.
- [V] **DWUCK4/5** (Kunz), classic DWBA; public-domain-ish. Source located: Alex Brown's repository (see below).
- [V] **TWOFNR** (Igarashi/Tostevin), transfer DWBA/ADWA, one- and two-step. Source located: nucleartheory.surrey.ac.uk/NPG/code.htm (Surrey version, Tostevin). Ships the FRONT front-end; note `front21_KDUQ.f` carries the KDUQ global OMP **with uncertainty quantification**, which makes this a natural Line D companion.
- [V] **Ptolemy** (Macfarlane/Pieper, ANL) — DWBA transfer; verify license.
- [V] **NLAT** (Titus, Ross, Nunes; CPC, doi 10.1016/j.cpc.2016.06.022), **nonlocal** ADWA/DWBA single-nucleon transfer, (d,N) and (N,d), Fortran 90, CPC Library. Directly adjacent to the Lei+Ren nonlocality-in-prior-form-DWBA paper (LG18891CR); a skill here doubles as an independent cross-check of that engine.
- [ ] **pikoe** (Ogata, Yoshida, Chazono; **Comput. Phys. Commun. 297, 109058 (2024)**, DOI 10.1016/j.cpc.2023.109058, CrossRef-verified 2026-07-20), DWIA proton-induced nucleon knockout: triple/quadruple differential cross sections, vector analyzing powers, residue momentum distributions, normal and inverse kinematics. Fortran 90, Numerov + Gauss-Legendre. **ELIGIBILITY CONFIRMED: MIT license**, source on Mendeley Data DOI 10.17632/m594h58kck.1, plus a maintained page (PikoWiki, RCNP) carrying pikoe1.1.f90. NEXT UP in Wave 1b. High personal relevance: QFS-RB 2026 invited talk plus the quenching PRL, and Kazuki Yoshida (co-author) issued that invitation.
- [x] **CNOK** (Sun, Wang; **Comput. Phys. Commun. 288, 108726 (2023)**, DOI 10.1016/j.cpc.2023.108726, CrossRef-verified 2026-07-22; GPL-3.0, gitee.com/asiarabbit/cnok) DONE: skills/cnok/, C++ Glauber-model single-nucleon knockout (stripping + diffractive dissociation cross sections and parallel momentum distributions). **TIER 1**, tenth per-code skill (2026-07-22). Benchmark `./mom 1s11p` (^16C -1n, 1s1/2(x)1/2+, 239 MeV/u on ^12C) = (60.086689, 18.056073, 78.142761) mb, **bit-identical across four builds** (macOS/clang17 patched -O2 and -O0, Linux/gcc13.3 unpatched and patched); stripping matches the paper's documented 60.087 mb exactly. Two behaviour-preserving libc++ patches (fabs->std::abs, __APPLE__-guarded ulong) + a macOS-only `-undefined dynamic_lookup` link flag; the gcc-unpatched == clang-patched bit-identity is what PROVES the patch changed portability not physics. Codex adversarial pass: 8 defects, all fixed (a path-traversal rm in run_cnok.sh, a 1e-4 gate contradicting the bit-identical claim tightened to 5e-7, an Eref-absent hole in the substitution guard, a loose total-consistency tolerance, a -m doc claim contradicting the source, two doc/comment overstatements). Cross-check partner for the quenching work and the IAV-vs-Glauber line (Liu Hao PRC 108, 014617).
- [x] **SWANLOP** (Arellano, Blanchon; **Comput. Phys. Commun. 259, 107543 (2021)**, DOI 10.1016/j.cpc.2020.107543, CrossRef-verified 2026-07-22; GPL, Mendeley Data 10.17632/89gw9jdfv4.1) DONE: skills/swanlop/, scattering waves and observables (dsigma/dOmega, Ay, Q, sigma/sigma_Ruth, reaction xsec) for nucleon elastic scattering off spin-zero nuclei with local or **nonlocal** optical potentials plus Coulomb. Fortran 90. **TIER 1**, twelfth per-code skill (2026-07-22): the distribution ships zz.{main,xaq,dsdt}.REF for the quick-start (p+208Pb 30.3 MeV TPM) and this build reproduces all three line-for-line modulo the per-run timestamp, reaction xsec 1.66084 b. Install fetches only the 8 MB code tarball, not the 530 MB potential-table supplement. Codex adversarial pass: 8 defects fixed (an over-broad timestamp strip that hid appended bogus lines, a run counting non-numeric lines as observables + not requiring zz.dsdt, a docs-claim-zz.main-but-verify-skips-it gap, run not copying fort.2/fort.22 for external-potential decks, and KPOT/temp00/LMAX doc errors against the source: KPOT is 0..4 with 4=VKK, temp00 sets KPOT=2 despite its title).
- [x] **SIDES** (Blanchon, Dupuis, Arellano, Bernard, Morillon; **Comput. Phys. Commun. 254, 107340 (2020)**, DOI 10.1016/j.cpc.2020.107340, CrossRef-verified 2026-07-22; GPL, Mendeley Data 10.17632/cmpjgyrngr.1) DONE: skills/sides/, Schrodinger integro-differential solver for nucleon elastic scattering with nonlocal optical potentials in coordinate space. Fortran 90. **TIER 2** (ships no reference output), eleventh per-code skill (2026-07-22): shipped n+40Ca 20 MeV TPM gives (reaction, elastic, total) = (1115.717600, 769.200182, 1884.917782) mb, ~12 sig figs across macOS gfortran 15.2 and Linux gfortran 13.3, with the neutron optical theorem TOTAL=ELASTIC+REACTION to machine precision. Codex pass: 8 defects fixed (relative-deck-read-after-cd, unsupported/mis-documented proton runs now handled as reaction-only, a `make clean` deleting ../sides outside the package, gate tightened to 1e-9, single-row verify). Natural sibling of SWANLOP and of COLOSS's Perey-Buck nonlocal path.
- [V] **OPTMAN** (Soukhovitskii et al.), phenomenological optical model with a soft-rotator structure model for coupled channels. RIPL, nds.iaea.org/RIPL/codes/OPTMAN/.

## Reactions: statistical / evaporation / fission

- [x] **TALYS** (Koning, Hilaire, Goriely; Eur. Phys. J. A 59, 131 (2023), DOI 10.1140/epja/s10050-023-01034-3; github.com/arjankoning1/talys, **MIT** not GPL as previously listed here) DONE: skills/talys/, clone+build+run+verify scripts, 5 clean-room sample benchmarks reproducing 1415 of 1438 distributed reference files byte for byte and the rest to ~6 sig figs (2026-07-20). Three traps found and handled: the Makefile source glob is locale-collation dependent and silently drops 13 files unless LC_ALL=C; paths are capped at character(len=132) so the install root must be under 63 chars; and **TALYS exits 0 even on a fatal error**, so the exit status must never be trusted. Install is ~11 GB (8.6 GB structure database), the heaviest skill so far.
- [ ] **EMPIRE** (Herman, Capote, Carlson, Oblozinsky, Sin, Trkov, Wienke, Zerkin), statistical model suite, nds.iaea.org/empire/ (also a paper-mill red-flag domain; skill should embed the Boilley checklist for sanity).
- [x] **CGMF** (Talou, Stetcu, Jaffke, Rising, Lovell, Kawano; LANL) SHIPPED 2026-07-22 `skills/cgmf/`, **TIER 1**. — event-by-event Monte Carlo Hauser-Feshbach de-excitation of fission fragments (prompt neutrons and gammas), spontaneous and neutron-induced. **ELIGIBILITY CONFIRMED and BUILD VERIFIED 2026-07-22**: BSD-3-Clause, public repo github.com/lanl/CGMF, C++ + CMake (39 cpp, 10 py post-processing), builds clean on Apple-Silicon macOS with no patches and produces cgmf.x, runs 252Cf(sf) end to end. Citation verified live via CrossRef: Comput. Phys. Commun. **269**, 108087 (2021), DOI 10.1016/j.cpc.2021.108087. Passes the tightened openness rule GEF failed (buildable on target platform, not FreeBASIC). data/ is 102 MB (fission-yield and structure tables), far smaller than TALYS. This is the fission/statistical row candidate. NEXT UP.
- [V] **YAHFC** (Ormand, LLNL), Monte Carlo Hauser-Feshbach, event-by-event decay with n/p/d/t/3He/alpha/gamma plus fission; Fortran 90 serial and MPI, github.com/LLNL/Yet-Another-Hauser-Feshbach-Code. Verify the accompanying publication before committing (open repo alone does not satisfy the hard rule).
- [x] ~~**GEMINI++** (Charity) — statistical decay of compound nuclei.~~ **DROPPED 2026-07-21 (user):** fails the publicly-obtainable hard rule. Both known distribution URLs (chemistry.wustl.edu/~rc/gemini++/ and the SourceForge project) return HTTP 404, and no public repo was found. Recorded here rather than deleted so it is not re-proposed; revisit only if the authors publish a clonable source release.
- [~] **GEF** (Schmidt-Jurado) — fission-fragment yields. **DROPPED 2026-07-22 as a FUSION skill** (user ruling). Passes the LITERAL openness rule (GPL-3.0, anonymous tarball, FreeBASIC source ships, NDS 131, 107 (2016) verified live) but fails the TIGHTENED rule (CLAUDE.md Key decision 2026-07-22): the source needs `fbc`, and FreeBASIC has no native Apple-Silicon toolchain, so a Mac student can only run the vendor x86/Linux binary, not rebuild it. Buildable-on-target is now required, source-exists is not enough. GEF still runs fine on heliumx for the user's own work. The fission/statistical paper row does NOT re-open: TALYS covers fission at tier 1 (`n-Th232-fis-wkb` bit-identical, plus a fission-yield model). Verified facts (nu-bar 3.8207 for 252Cf(SF); the done.ctl and Fitpar.dat traps) archived in devlog-archive.md.
- [V] **PACE4** — fusion-evaporation; bundled in LISE++, verify openness.
- [ ] **KEWPIE2** — evaporation for superheavy synthesis.

## R-matrix / resonances / astro

- [x] **AZURE2** (Notre Dame) — multichannel R-matrix for astrophysics. **SHIPPED 2026-07-22, `skills/azure2/`, TIER 2.** Built from the open channel `github.com/rdeboer1/AZURE2` (GPL-3.0, anonymously clonable); the registration-gated `azure.nd.edu` is never touched. Citation verified live via CrossRef: Azuma et al., Phys. Rev. C **81**, 045805 (2010), DOI 10.1103/physrevc.81.045805. The repo ships **neither example input nor reference output**, so the benchmark is CONSTRUCTED from PRC 81, 045805 Table V (16O(p,g)17F) and the `.azr` format reference was derived from the parser source. Verified: all 9 published parameters exact; S(90 keV) = 7.6080 vs the published 8.07 keV b (**-5.7%**, causes bounded and stated); and **chi^2/N = 1.53 against measured Rolfs (1973) data with nothing fitted**, the one check independent of the paper. Two Codex adversarial passes. Fills the **astro / R-matrix** subfield row of the fusion paper
- [V] **JITR** (Beyer), "just in time" R-matrix, a fast parametric R-matrix solver built explicitly for **calibration and uncertainty quantification**. Python, github.com/beykyle/jitr. Verify the publication. Strategically the closest external code to Line D / DREAM / the emulator work, and Python+differentiable-friendly, so worth an early look even before a skill.
- [V] **SAMMY** (ORNL) — R-matrix analysis of neutron data; license to verify (RSICC).
- [x] **SkyNet** (Lippuner + Roberts) — nucleosynthesis reaction network (r-process, rp-process, alpha, NSE). **SHIPPED 2026-07-23, `skills/skynet/`, TIER 1 with a documented macOS caveat.** BSD-3, bitbucket.org/jlippuner/skynet, ApJS 233, 18 (2017) / arXiv:1706.06198, CrossRef-verified. C++11 + Fortran, CMake, HDF5(C++)/GSL/Boost, dense LAPACK. Reproduces the shipped CTest self-comparison suite **19/19 on Linux, 17/19 on macOS** (the two macOS misses are a wall-clock timing self-test and the T9=3 full-network NSE block, libm-limited at 7e-3 vs a glibc-calibrated 3.5e-5 gate; identical source passes 19/19 on Linux). Anchors: X(ni56)=1.7794E-02 (analytic alpha net, both platforms), NSE Saha block < 1e-10. Five Apple-clang/libc++/Boost/CMake portability patches, proven behaviour-preserving by the Linux pass. Codex pass: 12 findings all fixed. Second astro code after AZURE2.
- [V] **XNet** (ORNL) — reaction network; verify.

## Structure: shell model / ab initio / DFT

- [x] **GSM** (Michel, Ploszajczak; LNP 983, Springer 2021; github.com/GSMUTNSR/book_codes, AFL v3.0) DONE: skills/gsm/, clone+unzip+patch+build from public repo, 3 clean-room benchmarks against the book's own exercise outputs (Ch2 Ex XV resonance 11 sig figs; Ch3 Ex XIII Berggren diagonalization 9 sig figs; Ch5 Ex II 18O many-body 8 sig figs on 2539 observables) (2026-07-20). Found and patched an upstream `finite()` infinite recursion that segfaults on any platform without the legacy BSD `finite(double)`; needs real GNU g++ (Apple clang cannot compile it).
- [x] **KSHELL** (Shimizu, Mizusaki, Utsuno, Tsunoda; **Comput. Phys. Commun. 244, 372 (2019)**, DOI 10.1016/j.cpc.2019.06.011, CrossRef-verified 2026-07-22; original arXiv:1310.5431; GPL-3.0 declared in the README) DONE: skills/kshell/, M-scheme large-scale shell model (thick-restart block Lanczos), Fortran 90 + OpenMP. **TIER 2** (ships no reference eigenvalue), thirteenth per-code skill (2026-07-22), first structure/shell-model code after GSM. 20Ne USDA (2 valence p + 2 valence n above 16O) gives the sd-shell spectrum g.s. -40.46689 MeV (0+), 2+ at Ex 1.696, 4+ at 4.091, **identical to 5 printed decimals across macOS gfortran 15.2 and Linux gfortran 13.3 (heliumx)**. Built from the maintained GaffaSnobb fork (Python 3.10+ tooling; the jorgenem mirror is Python 2, unusable on Mac); needs `-fallow-argument-mismatch` (gfortran 10+) and Accelerate (not -llapack) on macOS. Ships 25 interactions. Codex adversarial pass: 9 findings, 8 acted on (Lanczos non-convergence ignored if a summary exists, now caught; state indices not required to be 1..n; empty .ptn unchecked in verify; install rm -rf clobber before clone, now temp-clone-then-move; and the license/count/Python-version/table doc fixes, notably the README's "Licensing provisions: GPLv3" that GitHub's detector missed). selftest 16 cases.
- [ ] **BIGSTICK** (Johnson) — CI shell model, open.
- [V] **NuShellX** (Brown/Rae) — free binaries, NOT open source; decide skill-with-binary policy.
- [ ] **imsrg++** (Stroberg) — VS-IMSRG, open.
- [ ] **NuHamil** (Miyagi) — chiral-EFT matrix elements, open; already in daily use here.
- [x] **NuclearToolkit.jl** (Yoshida) — Julia chiral EFT + IMSRG + shell model. **SHIPPED 2026-07-23, `skills/nucleartoolkit/`, TIER 1.** MIT, JOSS 7(79), 4694 (2022), DOI 10.21105/joss.04694, CrossRef-verified. **First Julia-package skill and first ab-initio code.** Installed via a pinned `Pkg.add` (v0.5.2) into an ISOLATED depot + project (never touches the user's global Julia env); no source patches (Julia is cross-platform). Reproduces the shipped `@test` references: CKpot Be-8 shell-model spectrum (10 eigenvalues to |dE|<1e-3, g.s. -31.1194) and the full `Pkg.test` 30/30 (chiral EFT -> HFMBPT -> IMSRG He-4 g.s. -4.05225276 to 1e-6 -> shell model). Codex pass: 6 findings all fixed (exit-status-over-content in run/verify, L2 accepting <30 tests, unpinned version check, NTK_PIN injection, selftest isolation); isolation + ARGS-safety + L1-tolerance confirmed clean. Complements KSHELL (phenomenological); adds the IMSRG/chiral-EFT capability for Line D.
- [ ] **HFBTHO / HFODD** — Skyrme HFB, published open versions.
- [x] **Sky3D** (Maruhn, Reinhard, Stevenson, Umar; **Comput. Phys. Commun. 185, 2195 (2014)**, DOI 10.1016/j.cpc.2014.04.008, and v1.1 **CPC 229, 211 (2018)**, DOI 10.1016/j.cpc.2018.03.012, both CrossRef-verified 2026-07-23; **CPC non-profit use licence, NOT open source**, github.com/manybody/sky3d) DONE 2026-07-23: skills/sky3d/, time-dependent Skyrme Hartree-Fock on a symmetry-unrestricted 3D cartesian grid, static (ground states) and dynamic (heavy-ion collisions, giant-resonance strength functions). Fortran 90, FFTW3 + LAPACK/BLAS, **zero source patches** (upstream ships `apple` make targets). **TIER 1 on the static case with a measured macOS stability caveat**, sixteenth per-code skill and the first of the heavy-ion row. Benchmark: shipped `Test/Static` 16O SV-bas reproduced EXACTLY at printed precision, 266 energy-functional + 2432 single-particle + 570 moment values, same 370 iterations, on macOS gfortran 15.2 and Linux gfortran 13.3. `diff` is the wrong comparator here (about 1870 lines differ on a physically identical run: degenerate-multiplet orientation and symmetry zeros), hence `compare_sky3d.py`, which treats q20 adaptively so a deformed case is not excused. **The shipped collision reference is NOT a benchmark**: its real input is a binary O16 wavefunction the distribution does not ship, so E(sum) differs by 7.8e-4 MeV at t=0; both platforms agree with each other (byte-identical energies.res, 943 steps, 18.702 degree scattering angle) while both differ from it, which localizes the difference to the un-shipped input. Caveat: an unexplained SIGBUS at startup on macOS, 1 in 25 runs, 0 in 25 on Linux, stack exhaustion refuted; loud, so the harness rejects it. TWO Codex passes, 29 defects total, all fixed; selftest 69 cases.
- [ ] **DIRHB** — relativistic Hartree-Bogoliubov, CPC-published.

## Transport / nuclear data (lower tier: big ecosystems, decide scope later)

- [ ] **OpenMC** — Monte Carlo neutron/photon transport, fully open.
- [ ] **NJOY21** (LANL) — nuclear data processing, open.
- [V] **Geant4** — huge; a skill is feasible but scope must be narrowed (physics-list selection + common nuclear setups).
- [x] excluded: MCNP (export-controlled), FLUKA/PHITS (restrictive licenses).

## Heavy-ion collisions and the equation of state (opened 2026-07-23)

Scope opened by the user ruling of 2026-07-23 (CLAUDE.md Key decisions): FUSION serves the whole
nuclear-physics community, so a row does not need an interface to Lines A/E/F to be built. Every
fact in this section was verified live on 2026-07-23, by the GitHub API for the repo and license
and by CrossRef for the paper; nothing here is from memory. None of these is built yet.

The asymmetry worth stating up front: the codes NEAREST the user's own field are the ones that
fail the rules. Low-energy heavy-ion transport (ImQMD, AMD, CoMD, IBUU) and the NRV web platform
are request-based or registration-gated, so they fail "publicly clonable" exactly as Theo4Exp does.
The cleanly open codes cluster at relativistic energies, a different community.

**Build notes found while starting SMASH on 2026-07-23** (they apply to anyone in
this row, not only to SMASH): its `INSTALL.md` tells you to fetch Pythia from
`pythia.org/download/pythia83/...`, which now **404s**, since Pythia moved the
path to `/releases/`. The 404 arrives as a 3.7 KB HTML page named `.tgz`, so the
first real symptom is `tar: Unrecognized archive format`, which points nowhere
near the cause. Separately, `brew --prefix eigen` prints a path even when Eigen
is NOT installed, and once installed Homebrew now gives **Eigen 5.0.1**, which
renamed `EIGEN_WORLD_VERSION`, so SMASH 3.3's bundled `FindEigen3.cmake` cannot
parse it and reports "version .. found ... but at least 3.0 is required", a
message that reads like the opposite of the truth. The fix is Eigen 3.4.0
headers (2.7 MB, header-only), not a patch to SMASH.

**Verified eligible (repo + license + paper all confirmed live):**

| code | repo | license (GitHub API) | language | paper (CrossRef-verified) |
|---|---|---|---|---|
| ~~**SMASH**~~ **DONE 2026-07-23, see below** | smash-transport/smash | GPLv3, confirmed twice | C++17 / CMake | PRC **94**, 054905 (2016) |
| **GiBUU** | gibuu/GiBUU_2017 | GPL-2.0 | Fortran | Buss et al., Phys. Rept. **512**, 1-124 (2012), `10.1016/j.physrep.2011.12.001` |
| **Thermal-FIST** | vlvovch/Thermal-FIST | GPL-3.0 | C++ | Vovchenko, Stoecker, Comput. Phys. Commun. **244**, 295-310 (2019), `10.1016/j.cpc.2019.06.024` |
| **vHLLE** | yukarpenko/vhlle | GPL-2.0 | C++ | Karpenko et al., Comput. Phys. Commun. **185**, 3016-3027 (2014), `10.1016/j.cpc.2014.07.010` |
| **MUSIC** | MUSIC-fluid/MUSIC | GPL-2.0 | C++ | (paper not yet CrossRef-verified) |
| **TRENTO** | Duke-QCD/trento | MIT | C++ | (paper not yet CrossRef-verified) |
| **iEBE / iEBE-MUSIC** | chunshen1987/iEBE, chunshen1987/iEBE-MUSIC | GPL-3.0 both | Fortran / Python | (papers not yet CrossRef-verified) |

**Cleared 2026-07-23, and the next thing to build: Sky3D.** `manybody/sky3d` (nuclear
time-dependent Hartree-Fock, symmetry-unrestricted 3D cartesian box, static and time-dependent
modes; Fortran 90 with OpenMP, FFTW and LAPACK). The most research-relevant code in this section,
since TDHF fusion and dissipation touch the superheavy white paper and the Line A CF-suppression
work. Published twice, Maruhn et al., Comput. Phys. Commun. **185**, 2195-2216 (2014),
`10.1016/j.cpc.2014.04.008`, and version 1.1, Comput. Phys. Commun. **229**, 211-213 (2018),
`10.1016/j.cpc.2018.03.012`, both CrossRef-verified. **It carries no open-source license.**
Following the KSHELL lesson the check was run in all three places: no LICENSE file, nothing in the
README, no copyright header in the Fortran sources, and the CPC paper's program summary states
`Licensing provisions: none`, whose template comment reads "enter 'none' if CPC non-profit use
license is sufficient". So Sky3D is under the CPC non-profit use license. This is the opposite of
KSHELL, where the same grep found a GPLv3 declaration. It ships anyway under the boundary
amendment of 2026-07-23 (CLAUDE.md Key decisions): the rule tests whether a student can obtain and
build the source, not what the license permits commercially, and the skill clones from upstream and
redistributes nothing, so each user receives the code from the authors under the authors' own terms.
**Hard requirement on the skill: SKILL.md must state that Sky3D is CPC non-profit and not open
source, and send a commercial user to the authors.**

**IN PROGRESS 2026-07-23: SMASH**, `skills/smash/`, intended as the seventeenth
per-code skill and the first of this row. **NOT yet shipped**: round 1 of the
adversarial audit passed, round 2 found 2 new blockers caused by the round-1
fixes themselves, and **both blockers plus all 10 remaining round-2 items are
now fixed** (identity check no longer rejects the relink that SMASH's own
library test performs; the OSCAR grammar now covers all three `Only_Final`
shapes from a single transcribed parser). Selftest 49 to 83 cases, every new
guard shown to flip. What remains before it ships is a round-3 Codex pass and a
Linux re-run, since the round-2 fixes were measured on macOS/ARM only. Details
in TODO.md and `skills/smash/references/verification.md`. SMASH-3.3 (pinned commit `d1a1c6cf`), C++17 + CMake, needs
GSL, Eigen 3.x and Pythia exactly 8.316. **Zero source patches** on macOS/ARM and
Linux/x86-64. **TIER 1**: reproduces SMASH's own 104-case ctest suite, 104/104
first attempt on Linux.

Two design decisions here are measurements, not preferences, and both generalize
to any Monte Carlo code in this row:

1. **Two of the 104 tests are non-deterministic BY UPSTREAM CONSTRUCTION.**
   `src/tests/potentials.cc` and `random.cc` open with
   `std::random_device rd; random::set_seed(rd())` and then assert statistical
   quantities to fixed tolerances; only 2 of 82 test files do this. Measured:
   `potentials` passed 4 of 5 standalone runs. verify therefore retries exactly
   those two BY NAME, once, requires the total to be exactly 104, and treats
   every other failure as fatal. Do not generalize this to "allow one failure".
2. **The physics anchor is a conservation law, not a multiplicity**, and the
   cross-build data is why: same seed, same config, same source, and macOS vs
   Linux multiplicities differ by up to 25 per cent (n 450 vs 442, pi+ 57 vs 43)
   while baryon number 788 and charge 316 are identical integers on both.
   Anchoring on multiplicities would have produced a skill that only works on
   the machine that built it.

Three dependency traps, each with a message pointing away from its cause, are in
`references/failure-modes.md`: the dead Pythia URL whose 404 page gets saved as a
`.tgz` (symptom: `tar: Unrecognized archive format`); Eigen 5 making SMASH report
"at least version 3.0 is required" when the problem is that Eigen is too NEW; and
the library-example test spawning a fresh cmake that inherits no cache variables,
so it needs `EIGEN3_ROOT`, the GSL hints AND `LD_LIBRARY_PATH`, each discovered
only after the previous fix moved the error rather than removing it.

Defect worth recording, because it was wrong TWICE: the baryon-number rule
`1000 <= |code| < 10000` silently gives light NUCLEI a baryon number of 0. SMASH's particle table
carries the deuteron (1000010020), triton, He3 and hypertriton, and ships a
`light_nuclei` configuration that produces them. Adding the nuclear branch did
NOT fix it: "four digits" is not what makes a baryon, and every resonance SMASH
propagates breaks it (N(1440) is 12112, Lambda(1405) is 13122). It now
transcribes `PdgCode::baryon_number()` from the source. The Au+Au anchor is taken
at 20 fm/c, after the resonances decay, which is why the first fix looked
sufficient: the test case could not see the error.

**Adversarial round 1: 19 defects, 7 blockers, all fixed** (commit 842cbabd5). **Round 2: 11 fixed, 7 partial, 1 not fixed, 2 NEW blockers**, both regressions from the round-1 fixes: the new build-identity check rejects a legitimate build (the library test relinks the binary after the installer stamps it) while remaining spoofable, and real `Only_Final: No` output (one event with an `in` block and multiple `out` blocks) is rejected outright. Lesson for the next Monte Carlo skill: a guard validated against ONE configuration will reject legitimate output from the others.
Besides the above: `--seed -2` pinned nothing because SMASH randomizes ANY
negative seed while `config_used.yaml` still read `-2`; verify discarded ctest's
exit status; a mixed `(Failed)` + `(Timeout)` slipped past a regex matching only
the first; a retry that selected NO tests exited 0 and counted as a pass;
pre-set environment variables bypassed every identity check; `run_smash.sh`
accepted a forged OSCAR file; and shipped examples ran against the DEFAULT
particle tables because `-p/-d` were never passed, succeeding while computing
something other than the example. Conservation is now checked PER EVENT, since
equal and opposite violations cancel in a total. selftest 29 -> 49.

**Equation of state, surveyed but not yet verified:** CompOSE (compose.obspm.fr, database plus
its own tools, not on GitHub), SROEOS (Schneider-Roberts-Ott finite-temperature EOS), HFBTHO and
HFODD (Skyrme DFT, distributed through the CPC library). None located on GitHub in the 2026-07-23
pass, so each needs its channel, license and paper found before it can enter the table above.
Thermal-FIST already covers the hadron-resonance-gas branch of "EOS" and is verified.

## Lei code family (ONLY published + publicly-open ones; hard rule, see CLAUDE.md)

Eligible (published paper + public repo, skills double as student onboarding docs):
- [x] COLOSS (CPC 311, 109568 (2025)) DONE: skills/coloss/, install+run scripts, FRESCO cross-check 4 sig figs + theta-invariance 5 sig figs (2026-07-20)
- [ ] SLAM.jl (PRC 113, 024614 (2026); github.com/jinleiphys/SLAM.jl)
- [ ] PINN-ECS (PRC 113, 064618 (2026); github.com/jinleiphys/PINN-ECS)
- [ ] inhomoR (PRC 102 (2020); github.com/jinleiphys/inhomoR)

Per-code judgment call (public repo, but journal paper still in review, ask user):
- [ ] HPRMAT (CPC in revision; arXiv 2512.11590; github.com/jinleiphys/HPRMAT)
- [ ] swift.jl (public repo; no journal paper yet)
- [ ] DREAM (public repo; PLB in submission; note: bundles internal pstars)

EXCLUDED (not publicly released, never get a FUSION skill):
- STARS / pstars (internal repo only)
- smoothie (not public)
- transfer (not public)

## Research skills (not per-code)

These drive no single code, so the per-code bar (install, build, benchmark against a published value) does not apply. Their integrity check is that what they report can be traced back to a primary source.

- [x] **exfor-data** DONE 2026-07-23: `skills/exfor-data/`, retrieval and parsing of measured nuclear reaction data from the IAEA EXFOR database. Partner to every reaction skill, because comparing a calculation with experiment needs real data and inventing a data point is worse than having none. Two things it encodes that cost real time to discover: the interactive search servlet **cannot be scripted** (it answers `Define Search Criteria!` to every GET and POST, since the form is JavaScript-built and session-bound), so the workflow is to find the accession number by other means and then pull the entry through `X4sGetEntry`; and the data blocks are **fixed width** (6 fields of 11 characters, wrapping past 6 columns) where a blank field means "not measured", so whitespace splitting silently shifts every later column. Also handles the trap that `DATA-ERR` is sometimes `PER-CENT` and sometimes absolute, and that `COMMON` and `DATA` count their header line differently. Designed to answer "there is no measurement at that energy" as a first-class result: verified live on n+90Zr, where nothing exists at 50 MeV and the nearest sets are 24 MeV (enriched, full angular range) and 55 MeV (natural Zr, forward angles).

## Where the community keeps these codes (source registry)

Added 2026-07-20 from the community list at
`sites.google.com/view/opticalpotentials/reaction-codes` (the optical-potential
community page). Useful mainly as a **distribution map**: it resolves several of
the "verify canonical source" flags above.

- **CPC Program Library / Mendeley Data**: the single richest source. SWANLOP, SIDES, NLAT, CNOK, pikoe all live here, each tied to a CPC paper, so they clear the published-and-public rule by construction. This is the highest-yield place to mine for future skills.
- **RIPL (IAEA)**: `nds.iaea.org/RIPL/codes/`. ECIS, OPTMAN. Also the standard reference-input-parameter source generally.
- **Alex Brown's repository**: `people.nscl.msu.edu/~brown/reaction-codes/`. A large bundle of classics in one place: Fr2in, faCE, STURMXX, EFADDY, TWOFNR variants, wspot, RADCAP, Dweiko, MOMDIS, EMPIRE-II, DW81, DW91, DWBA91, DWBA98, ECIS, CHUCK3, DWUCK4, DWUCK5, CCFULL. Licensing per code is unstated, so treat as "source located, license unverified" rather than automatically eligible.
- **Surrey NPG**: `nucleartheory.surrey.ac.uk/NPG/code.htm`. TWOFNR + FRONT.
- **LLNL GitHub**: YAHFC, and **Frescox** (`github.com/LLNL/Frescox`), the actively maintained FRESCO fork. Worth noting in the fresco skill: the skill currently builds I-Thompson/fresco, and whether to track Frescox instead is an open question.
- EXCLUDED, reason clarified 2026-07-23: **Theo4Exp** (`institucional.us.es/theo4exp`, IFJ PAN Krakow + Seville + Milano; MeanField4Exp / Reaction4Exp / Structure4Exp). The reason was never licensing, and it is not the registration gate either: **there is no source distribution at all.** It is a server-side web platform where the calculation runs on their machine and the user fills in a browser form, so there is nothing to clone, nothing to build, nothing to benchmark to N digits, and no cross-build check. A "skill" could only be a guide to someone else's web form: unverifiable, and liable to break silently on their next redesign. This is why the 2026-07-23 obtainability rule excludes it while admitting Sky3D, whose license is far more restrictive but whose source is right there. Contrast also the AZURE2 precedent (2026-07-21): a gate on a SECONDARY channel does not make a code unobtainable when an open channel exists; Theo4Exp has no such channel. Confirmed by the user 2026-07-23: it is deliberately a browser-based service, used directly on the web page, and the project is **led by A.M. Moro** (the user's PhD advisor). So this is settled, not pending verification; do not re-open it as a candidate in a later session. It is complementary to FUSION rather than competing: Theo4Exp lowers the barrier for people who should not have to install anything, while FUSION ships what can be built locally and benchmarked to N digits. If a pointer is ever wanted, the right form is a line in the student-facing docs (Phase 4), never a per-code skill.

Note on the whole list: openness is *asserted by the page*, not verified by us. Every entry above stays [V] until someone actually fetches the code and reads its license.

## Skill quality bar (every entry, no exceptions)

1. Install/build recipe tested on macOS + Linux; where the code is open-source and buildable, ship an auto-install script (check bin/PATH, else clone+compile from upstream, verify against a published anchor). fresco's install_fresco.sh is the pattern.
2. Input-deck authoring guidance with verified examples (anti-hallucination: never write decks from memory).
3. Run + output parsing (which file, which line, what units).
4. At least one benchmark against a published value, agreement stated to N digits.
5. Failure-modes section (the arcane traps each code is famous for).

## Strategy (user 2026-07-20)

- **Community codes first**, not the Lei family. The community codes are the point of FUSION.
- **Self-consistent benchmarks**, not cross-code matching. Each code ships a test suite / manual with documented reference values; reproduce THOSE. Avoid the convention archaeology that made the COLOSS cross-check slow (radius/spin-orbit conventions differ per code). Cross-code checks only when a code has no documented reference.
- **One at a time, sequential.** Per-code build+benchmark cannot be parallelized or delegated (each needs real compilation + a verified number). Each skill is fully done (builds from source, runs, reproduces a documented value to N digits) before the next starts.

## Build order

Wave 1 (small, classic, self-benchmarking, community): CCFULL done, GSM done, TALYS done. (THOx dropped: not public.)
Wave 1b (added 2026-07-20, CPC-Library codes: small, published, distributed with the paper, so the openness question is already settled and each ships author test cases): **pikoe, NLAT, CNOK, SWANLOP/SIDES**. These jumped the queue over Wave 2 because they are cheap to verify and every one of them sits directly on an active research line (knockout/QFS, nonlocality, Glauber-vs-IAV). Suggested order: pikoe, NLAT, CNOK, SIDES+SWANLOP as a pair. **Status: Wave 1b COMPLETE (2026-07-22). All five shipped: pikoe, NLAT (07-21), CNOK, SIDES, SWANLOP (07-22).**
Wave 2 (community heavyweights): KSHELL done 2026-07-22; SkyNet done 2026-07-23 (AZURE2 done 2026-07-22; GEF dropped 2026-07-22, not buildable on target platform). NuclearToolkit.jl done 2026-07-23 (first Julia-package + first ab-initio skill). Remaining clean-license Wave-2 option: imsrg (GPL-2.0, C++, ab-initio).
Wave 3 (verify-then-build): ECIS, TWOFNR (+FRONT/KDUQ), OPTMAN, JITR, YAHFC, DWUCK, SAMMY, NuShellX-policy, OpenMC, NJOY.
Wave 4 (ecosystem monsters, scoped): Geant4.
Lei family (eligible only): COLOSS done; SLAM.jl, PINN-ECS, inhomoR when convenient.
