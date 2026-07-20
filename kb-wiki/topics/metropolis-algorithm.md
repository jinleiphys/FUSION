# Metropolis algorithm

**PhySH lineage:** [Monte Carlo methods](monte-carlo-methods.md) > Metropolis algorithm

**Broader:** [Monte Carlo methods](monte-carlo-methods.md)

## Landscape

The Metropolis algorithm provides a robust framework for simulating stochastic relativistic and non-relativistic hydrodynamics, particularly in contexts where fluctuations and dissipation are essential. This matters because such simulations are critical for understanding dynamic phenomena in heavy-ion collisions, including the evolution near a possible QCD critical point, as well as phase transitions in superfluids and ordinary fluids. The algorithm systematically incorporates fluctuations by proposing random transfers of charge or momentum between fluid cells, accepting or rejecting these proposals based on the change in entropy, thereby reproducing dissipative hydrodynamics in specific frames such as the Density Frame.

The main approaches center on applying the Metropolis algorithm to different stochastic hydrodynamic models. Several papers implement the algorithm for relativistic viscous hydrodynamics, using ideal hydrodynamic steps interspersed with random spatial momentum transfers. Other works focus on non-relativistic stochastic fluids in two dimensions, replacing dissipative terms with random forces. Specific applications include model B for critical dynamics near a QCD critical point, model H for heat conduction and momentum transport, and model F for the superfluid phase transition. A distinct thread applies the Metropolis algorithm to the pairing-force problem for stochastic number projection in nuclear physics.

Open questions and active directions are visible in recent papers, particularly regarding the precise determination of dynamical critical exponents. For model B, simulations yield a dynamical critical exponent \(z \simeq 3.972(2)\), which agrees with theoretical predictions. Studies of model H observe the expected logarithmic divergence of shear viscosity in two-dimensional non-critical fluids, while investigations of model F aim to describe dynamic scaling near the lambda transition in liquid \(^4\)He and superfluid transitions in ultracold atomic gases. The extension of these Metropolis-based algorithms to other hydrodynamic theories and to three-dimensional systems remains an active area of development.

**Papers:** 7

- [2603.21479](../papers/2603.21479.md) (2026) [2] Critical dynamics of the superfluid phase transition in Model F
- [2602.00207](../papers/2602.00207.md) (2026) [1] Numerical simulations of non-relativistic stochastic fluids via the Metropolis algorithm
- [2510.12557](../papers/2510.12557.md) (2025) [2] Transport properties of stochastic fluids
- [2412.10306](../papers/2412.10306.md) (2024) [1] Stochastic relativistic viscous hydrodynamics from the Metropolis algorithm
- [2403.04185](../papers/2403.04185.md) (2024) [1] The stochastic relativistic advection diffusion equation from the Metropolis algorithm
- [2304.07279](../papers/2304.07279.md) (2023) [2] Dynamic scaling of order parameter fluctuations in model B
- [nucl-th/9811001](../papers/nucl-th/9811001.md) (0000) [2] nucl-th/9811001
