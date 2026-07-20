# Langevin algorithm

**PhySH lineage:** [Monte Carlo methods](monte-carlo-methods.md) > Langevin algorithm

**Broader:** [Monte Carlo methods](monte-carlo-methods.md)

## Landscape

The Langevin algorithm is a stochastic method used to simulate systems where conventional Monte Carlo techniques fail due to the sign problem, a severe numerical challenge that arises in finite-density quantum chromodynamics (QCD) and other many-body systems. This topic matters because the sign problem prohibits direct lattice simulations of cold and dense nuclear matter, which is essential for understanding the phase diagram of QCD and the properties of neutron stars. By enabling calculations in regimes otherwise inaccessible, the Langevin algorithm provides a pathway to non-perturbative results for heavy quark dynamics and mass-imbalanced fermion systems.

The main approaches within this topic include the complex Langevin algorithm, which is applied to evade the sign problem in lattice QCD with heavy quarks, as demonstrated by a study showing agreement between standard Metropolis and complex Langevin results for a first order phase transition at finite baryon chemical potential. Another sub-thread involves coupling the Langevin equation to hydrodynamic models to study heavy quark energy loss in a quark-gluon plasma, where gluon radiation is incorporated as an extra force term. Additionally, methods such as gauge cooling, shifted representation, deformation techniques, and reweighted complex Langevin are tested to address convergence issues, as seen in random matrix model simulations of QCD.

Active open questions visible in recent papers include the need to resolve convergence failures of the naive complex Langevin algorithm, which can produce phase quenched results that are analytically incorrect. The development of reliable fixes, such as reweighted complex Langevin, remains an active direction. Furthermore, extending these stochastic methods to zero energy quantum scattering and to fully non-perturbative studies of mass-imbalanced Fermi systems highlights ongoing efforts to broaden the algorithm’s applicability beyond nuclear matter.

**Papers:** 5

- [1712.07514](../papers/1712.07514.md) (2017) [2] Complex Langevin Simulation of a Random Matrix Model at Nonzero Chemical Potential
- [1708.03149](../papers/1708.03149.md) (2017) [2] Surmounting the sign problem in non-relativistic calculations: a case study with mass-imbalanced fermions
- [1209.5410](../papers/1209.5410.md) (2012) [2] Collisional vs. Radiative Energy Loss of Heavy Quark in a Hot and Dense Nuclear Matter
- [1207.3005](../papers/1207.3005.md) (2012) [2] Onset Transition to Cold Nuclear Matter from Lattice QCD with Heavy Quarks
- [nucl-th/9703019](../papers/nucl-th/9703019.md) (0000) [2] nucl-th/9703019
