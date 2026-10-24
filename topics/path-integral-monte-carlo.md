# Path-integral Monte Carlo

**PhySH lineage:** [Monte Carlo methods](monte-carlo-methods.md) > Path-integral Monte Carlo

**Broader:** [Monte Carlo methods](monte-carlo-methods.md)

## Landscape

Path integral Monte Carlo (PIMC) is a nonperturbative, finite temperature quantum simulation method that extends classical statistical mechanics into the quantum regime by representing the thermal density matrix as a path integral. This topic is crucial because it enables first principles calculations of thermodynamic and transport properties in strongly correlated systems ranging from dense astrophysical plasmas to the quark gluon plasma, where mean field or semiclassical approximations fail. For example, PIMC calculations of Coulomb tunneling in dense matter show excellent agreement with WKB methods above one fifth of the ion plasma temperature, while in neutron star crusts PIMC reveals electron scattering rates enhanced by a factor of 2 to 4 compared to simpler impurity scattering models.

The main methodological threads include simulations of nuclear matter and quark gluon plasma. For nuclear systems, PIMC has been applied to bosons and fermions interacting via Lennard Jones potentials to construct phase diagrams, and to dilute neutron matter where the critical temperature for the superfluid normal phase transition is extracted from finite size scaling of the condensate fraction. For quark gluon plasma, color path integral Monte Carlo methods with a relativistic measure instead of the Gaussian Feynman Wiener measure reproduce the lattice QCD equation of state and reveal liquid like properties with bound quark antiquark states surviving just above the critical temperature.

Open questions visible in recent papers include the extraction of scattering phase shifts from integrated correlation functions in trapped systems, particularly for coupled channels where a new relation retains explicit dependence on phase shifts but not inelasticity. Additionally, dissipative effects on quarkonium spectral functions are studied using PIMC with a nonlocal term to determine the Euclidean Green function, though challenges in deconvolution via the maximum entropy method remain significant. The thermal behavior of the Tan contact in one dimensional Bose gases also presents an active direction, where the \(1/k^4\) tail of the momentum distribution is screened by a \(1/|k|^3\) term above the hole anomaly temperature.

**Papers:** 16

- [2511.19209](../papers/2511.19209.md) (2025) [2] Projected Density Matrix Sampling for Lattice Hamiltonians
- [2412.00812](../papers/2412.00812.md) (2024) [2] Toward extracting scattering phase shift from integrated correlation functions III: coupled-channels
- [2302.03509](../papers/2302.03509.md) (2023) [2] Thermal fading of the $1/k^4$-tail of the momentum distribution induced by the hole anomaly
- [2007.04863](../papers/2007.04863.md) (2020) [1] Nucleon clustering at kinetic freezeout of heavy-ion collisions via path-integral Monte Carlo
- [1707.01113](../papers/1707.01113.md) (2017) [1] Path Integral Monte Carlo study of particles obeying quantum mechanics and classical statistics
- [1608.05459](../papers/1608.05459.md) (2016) [2] Quantum Chromodynamics: Computational Aspects
- [1602.01831](../papers/1602.01831.md) (2016) [2] Thermal conductivity and impurity scattering in the accreting neutron star crust
- [1504.00343](../papers/1504.00343.md) (2015) [2] Dissipative effects on quarkonium spectral functions
- [1210.2664](../papers/1210.2664.md) (2012) [1] Color path-integral Monte-Carlo simulations of quark-gluon plasma: Thermodynamic and transport properties
- [1203.2191](../papers/1203.2191.md) (2012) [1] Color path-integral Monte Carlo simulations of quark-gluon plasma
- [1101.2089](../papers/1101.2089.md) (2011) [2] Quantum simulations of thermodynamic properties of strongly coupled quark-gluon plasma
- [1008.3720](../papers/1008.3720.md) (2010) [2] Quantum effects on the phase diagram of nuclear-like systems
- [1006.3390](../papers/1006.3390.md) (2010) [2] Quantum simulations of strongly coupled quark-gluon plasma
- [0912.0373](../papers/0912.0373.md) (2009) [2] Quantum Monte Carlo study of dilute neutron matter at finite temperatures
- [0905.0324](../papers/0905.0324.md) (2009) [1] Equation of state of strongly coupled quark--gluon plasma -- Path integral Monte Carlo results
- [0707.3500](../papers/0707.3500.md) (2007) [1] Coulomb tunneling for fusion reactions in dense matter: Path integral Monte Carlo versus mean field
