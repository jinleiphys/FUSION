# COLOSS verification

Two independent checks. Run both before trusting a new COLOSS result.

## 1. Cross-code benchmark against FRESCO (physics correctness)

System: n + 40Ca at Elab = 20 MeV, central optical potential only (spin-orbit turned off), total reaction cross section.

Potential (Woods-Saxon): real volume V = 46.553, r = 1.185, a = 0.672; imaginary volume W = 1.777, same geometry; imaginary surface Ws = 7.182, r = 1.288, a = 0.538.

**Radius convention (critical):** COLOSS uses target-only R = r * A_t^(1/3), NOT the (A_p^(1/3) + A_t^(1/3)) sum some codes use. To reproduce in FRESCO, set `ap=0.0 at=40.0` so FRESCO's radius is also r * A_t^(1/3). Getting this wrong shifts sigma_R by ~30 to 50 percent.

| code | method | sigma_R (mb) |
|---|---|---|
| COLOSS | complex scaling (Lagrange-Laguerre) | 1157.53 |
| FRESCO | Numerov real-axis integration | 1157.69 |

Agreement: 4 significant figures, residual 1.4e-4. Two unrelated numerical methods on the same potential, so this validates both the build and the physics.

Input: `examples/n40Ca.in` with `vsov=0.0`. The matching FRESCO deck is in the skill's benchmark notes.

## 2. Complex-scaling angle invariance (numerical correctness, convention-free)

The defining validity check for a complex-scaling solver: the physical observable must NOT depend on the rotation angle theta over a stable window. Run `examples/alpha40Ca.in` at two angles:

| ctheta | sigma_R (mb) |
|---|---|
| 6 | 756.8206 |
| 10 | 756.8182 |

Agreement to 5 significant figures (relative difference 3e-6). If sigma_R drifts with theta by more than the last digit, the basis (nr) or Rmax is too small, or theta is outside the stable window.

## How to sum the total reaction cross section

COLOSS prints a per-partial-wave table (columns: L, S, J, Re(S), Im(S), partial-wave Reac_Xsec in mb). The total is the sum of the last column:

```bash
COLOSS < input.in | awk -F'|' '/\|.*\(.*\).*\|/ {v=$3; gsub(/[^0-9.eE+-]/,"",v); if(v!="") s+=v} END{printf "sigma_R = %.4f mb\n", s}'
```

Always confirm the partial-wave series has converged in L (last few rows should be a small fraction of a mb); if not, raise `jmax`.
