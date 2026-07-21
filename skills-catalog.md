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
- [V] **CNOK** (Sun, Wang; CPC, doi 10.17632/dmffpbjhsh.1), C++ Glauber-model single-nucleon knockout, parallel momentum distributions. Repo gitee.com/asiarabbit/cnok. Cross-check partner for the quenching work and for the IAV-vs-Glauber comparison line (Liu Hao PRC 108, 014617).
- [V] **SWANLOP** (Arellano, Blanchon; CPC Library doi 10.17632/89gw9jdfv4.1), scattering waves and observables for nucleon elastic scattering off spin-zero nuclei with **nonlocal** optical potentials plus Coulomb. Fortran 90.
- [V] **SIDES** (Blanchon, Dupuis, Arellano, Bernard, Morillon; CPC Library doi 10.17632/cmpjgyrngr.1), Schrodinger integro-differential solver for elastic scattering with nonlocal optical potentials in coordinate space. Fortran 90. Natural sibling of SWANLOP and of COLOSS's Perey-Buck nonlocal path.
- [V] **OPTMAN** (Soukhovitskii et al.), phenomenological optical model with a soft-rotator structure model for coupled channels. RIPL, nds.iaea.org/RIPL/codes/OPTMAN/.

## Reactions: statistical / evaporation / fission

- [x] **TALYS** (Koning, Hilaire, Goriely; Eur. Phys. J. A 59, 131 (2023), DOI 10.1140/epja/s10050-023-01034-3; github.com/arjankoning1/talys, **MIT** not GPL as previously listed here) DONE: skills/talys/, clone+build+run+verify scripts, 5 clean-room sample benchmarks reproducing 1415 of 1438 distributed reference files byte for byte and the rest to ~6 sig figs (2026-07-20). Three traps found and handled: the Makefile source glob is locale-collation dependent and silently drops 13 files unless LC_ALL=C; paths are capped at character(len=132) so the install root must be under 63 chars; and **TALYS exits 0 even on a fatal error**, so the exit status must never be trusted. Install is ~11 GB (8.6 GB structure database), the heaviest skill so far.
- [ ] **EMPIRE** (Herman, Capote, Carlson, Oblozinsky, Sin, Trkov, Wienke, Zerkin), statistical model suite, nds.iaea.org/empire/ (also a paper-mill red-flag domain; skill should embed the Boilley checklist for sanity).
- [V] **YAHFC** (Ormand, LLNL), Monte Carlo Hauser-Feshbach, event-by-event decay with n/p/d/t/3He/alpha/gamma plus fission; Fortran 90 serial and MPI, github.com/LLNL/Yet-Another-Hauser-Feshbach-Code. Verify the accompanying publication before committing (open repo alone does not satisfy the hard rule).
- [x] ~~**GEMINI++** (Charity) — statistical decay of compound nuclei.~~ **DROPPED 2026-07-21 (user):** fails the publicly-obtainable hard rule. Both known distribution URLs (chemistry.wustl.edu/~rc/gemini++/ and the SourceForge project) return HTTP 404, and no public repo was found. Recorded here rather than deleted so it is not re-proposed; revisit only if the authors publish a clonable source release.
- [ ] **GEF** (Schmidt-Jurado) — fission-fragment yields. **Openness CLEARED 2026-07-21:** GPL-3.0, anonymous direct tarball (no registration), 2025/1.4 actively maintained; Nucl. Data Sheets **131**, 107 (2016), DOI 10.1016/j.nds.2015.12.009 verified live via CrossRef. Verified running on heliumx: ²⁵²Cf(SF) nu-bar 3.8207 vs evaluated 3.7676. **Linux-only** (FreeBASIC source, no macOS binary and no `fbc` on Homebrew; use the shipped `GEF64` on heliumx). Ships 97 decks but **no reference output**, so tier 2 unless the NDS paper anchors it. Two false-success traps: `ctl/done.ctl` silently skips an already-run case at exit 0, and a stale `Fitpar.dat` silently overrides defaults.
- [V] **PACE4** — fusion-evaporation; bundled in LISE++, verify openness.
- [ ] **KEWPIE2** — evaporation for superheavy synthesis.

## R-matrix / resonances / astro

- [ ] **AZURE2** (Notre Dame) — multichannel R-matrix for astrophysics. **Openness CLEARED 2026-07-21 (user decision: use the open-source channel).** Two distribution channels exist and only one is usable: **`github.com/rdeboer1/AZURE2` is GPL-3.0, public, anonymously clonable and actively pushed**, while **`azure.nd.edu` redirects to `login.php`** and is registration-gated. The skill builds from GitHub and never touches the gated site, so it satisfies the hard rule. This is materially unlike GEMINI++, which has no public repo at all. Citation verified live via CrossRef: Azuma et al., Phys. Rev. C **81**, 045805 (2010), DOI 10.1103/physrevc.81.045805. Build works headless; **remaining blocker is L2, not licensing**: no `.azr` test case ships anywhere.
- [V] **JITR** (Beyer), "just in time" R-matrix, a fast parametric R-matrix solver built explicitly for **calibration and uncertainty quantification**. Python, github.com/beykyle/jitr. Verify the publication. Strategically the closest external code to Line D / DREAM / the emulator work, and Python+differentiable-friendly, so worth an early look even before a skill.
- [V] **SAMMY** (ORNL) — R-matrix analysis of neutron data; license to verify (RSICC).
- [ ] **SkyNet** (Lippuner) — nucleosynthesis reaction network; open.
- [V] **XNet** (ORNL) — reaction network; verify.

## Structure: shell model / ab initio / DFT

- [x] **GSM** (Michel, Ploszajczak; LNP 983, Springer 2021; github.com/GSMUTNSR/book_codes, AFL v3.0) DONE: skills/gsm/, clone+unzip+patch+build from public repo, 3 clean-room benchmarks against the book's own exercise outputs (Ch2 Ex XV resonance 11 sig figs; Ch3 Ex XIII Berggren diagonalization 9 sig figs; Ch5 Ex II 18O many-body 8 sig figs on 2539 observables) (2026-07-20). Found and patched an upstream `finite()` infinite recursion that segfaults on any platform without the legacy BSD `finite(double)`; needs real GNU g++ (Apple clang cannot compile it).
- [ ] **KSHELL** (Shimizu) — large-scale shell model, open.
- [ ] **BIGSTICK** (Johnson) — CI shell model, open.
- [V] **NuShellX** (Brown/Rae) — free binaries, NOT open source; decide skill-with-binary policy.
- [ ] **imsrg++** (Stroberg) — VS-IMSRG, open.
- [ ] **NuHamil** (Miyagi) — chiral-EFT matrix elements, open; already in daily use here.
- [ ] **NuclearToolkit.jl** (Yoshida) — Julia chiral EFT + IMSRG + shell model, open.
- [ ] **HFBTHO / HFODD** — Skyrme HFB, published open versions.
- [ ] **Sky3D** — time-dependent Skyrme HF, open.
- [ ] **DIRHB** — relativistic Hartree-Bogoliubov, CPC-published.

## Transport / nuclear data (lower tier: big ecosystems, decide scope later)

- [ ] **OpenMC** — Monte Carlo neutron/photon transport, fully open.
- [ ] **NJOY21** (LANL) — nuclear data processing, open.
- [V] **Geant4** — huge; a skill is feasible but scope must be narrowed (physics-list selection + common nuclear setups).
- [x] excluded: MCNP (export-controlled), FLUKA/PHITS (restrictive licenses).

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
- EXCLUDED for now: **Theo4Exp** (`institucional.us.es/theo4exp`, IFJ PAN Krakow + Seville + Milano; MeanField4Exp / Reaction4Exp / Structure4Exp). It is a **registration-gated web platform**, not a repository anyone can clone, so it fails the "publicly obtainable" half of the hard rule. Flagged rather than deleted because it is a Moro-adjacent Seville product and the user may know its terms; ask before acting.

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
Wave 1b (added 2026-07-20, CPC-Library codes: small, published, distributed with the paper, so the openness question is already settled and each ships author test cases): **pikoe, NLAT, CNOK, SWANLOP/SIDES**. These jumped the queue over Wave 2 because they are cheap to verify and every one of them sits directly on an active research line (knockout/QFS, nonlocality, Glauber-vs-IAV). Suggested order: pikoe, NLAT, CNOK, SIDES+SWANLOP as a pair.
Wave 2 (community heavyweights): KSHELL, GEF, AZURE2, SkyNet.
Wave 3 (verify-then-build): ECIS, TWOFNR (+FRONT/KDUQ), OPTMAN, JITR, YAHFC, DWUCK, SAMMY, NuShellX-policy, OpenMC, NJOY.
Wave 4 (ecosystem monsters, scoped): Geant4.
Lei family (eligible only): COLOSS done; SLAM.jl, PINN-ECS, inhomoR when convenient.
