# FUSION per-code skill catalog

The core product of FUSION: **every excellent open-source nuclear-physics code gets its own expert skill**, modeled on the existing fresco skill (install/build, input authoring, run, output parsing, plus at least one benchmark reproducing a published value to stated precision). This file is the living roadmap; the fresco skill is the reference implementation.

Status legend: [ ] not started, [S] skill exists, [V] open-source status needs verification before committing (some famous codes are free-binary or licensed, not open).

## Reactions: coupled channels / DWBA / breakup

- [S] **FRESCO** (Thompson) — coupled channels, CC/CRC/CDCC/transfer/capture. The template skill.
- [ ] **THOx** (Sevilla) — CDCC with core excitation (XCDCC); Moro group, on GitHub.
- [ ] **CCFULL** (Hagino) — fusion coupled channels near barrier.
- [V] **ECIS** (Raynal) — coupled channels + optical model fits; distribution status to verify.
- [V] **DWUCK4/5** (Kunz) — classic DWBA; public-domain-ish, verify canonical source.
- [V] **TWOFNR** (Igarashi/Tostevin) — transfer DWBA/ADWA; verify distribution.
- [V] **Ptolemy** (Macfarlane/Pieper, ANL) — DWBA transfer; verify license.

## Reactions: statistical / evaporation / fission

- [ ] **TALYS** — Hauser-Feshbach + preequilibrium + nuclear data evaluation; GPL.
- [ ] **EMPIRE** — statistical model suite (also a paper-mill red-flag domain; skill should embed the Boilley checklist for sanity).
- [ ] **GEMINI++** (Charity) — statistical decay of compound nuclei.
- [ ] **GEF** (Schmidt-Jurado) — fission-fragment yields.
- [V] **PACE4** — fusion-evaporation; bundled in LISE++, verify openness.
- [ ] **KEWPIE2** — evaporation for superheavy synthesis.

## R-matrix / resonances / astro

- [ ] **AZURE2** (Notre Dame) — multichannel R-matrix for astrophysics; open.
- [V] **SAMMY** (ORNL) — R-matrix analysis of neutron data; license to verify (RSICC).
- [ ] **SkyNet** (Lippuner) — nucleosynthesis reaction network; open.
- [V] **XNet** (ORNL) — reaction network; verify.

## Structure: shell model / ab initio / DFT

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

## Lei code family (group-owned, skills also serve as onboarding docs for students)

- [ ] smoothie, transfer, inhomoR (Line A engines)
- [ ] COLOSS, SLAM.jl, swift.jl (scattering/few-body)
- [ ] HPRMAT, STARS-public-parts (HPC)
- [ ] PINN-ECS, DREAM (ML/UQ)

## Skill quality bar (every entry, no exceptions)

1. Install/build recipe tested on macOS + Linux.
2. Input-deck authoring guidance with verified examples (anti-hallucination: never write decks from memory).
3. Run + output parsing (which file, which line, what units).
4. At least one benchmark against a published value, agreement stated to N digits.
5. Failure-modes section (the arcane traps each code is famous for).

## Build order proposal (user to confirm)

Wave 1 (user is expert, benchmarks at hand): THOx, CCFULL, TALYS, smoothie, COLOSS.
Wave 2 (community heavyweights): KSHELL, GEMINI++, GEF, AZURE2, SkyNet.
Wave 3 (verify-then-build): ECIS, TWOFNR, DWUCK, SAMMY, NuShellX-policy, OpenMC, NJOY.
Wave 4 (ecosystem monsters, scoped): Geant4.
