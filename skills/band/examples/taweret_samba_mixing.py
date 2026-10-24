"""Taweret analytic anchor: the SAMBA toy (Semposki, Furnstahl, Phillips, PRC 106, 044002 (2022),
arXiv:2206.04116), re-derived from the paper's equations, independently of Taweret's code.
  F(g)   = int exp(-x^2/2 - g^2 x^4) dx = exp(1/(32g^2)) / (2 sqrt2 g) K_{1/4}(1/(32 g^2))   (Eq. 1)
  s_2k   = sqrt2 Gamma(2k+1/2) (-4)^k / k!,  s_odd = 0                                         (Eq. 3)
  l_k    = Gamma(k/2+1/4) / (2 k!) (-1/2)^k,  F_l = sum_k l_k g^(-k-1/2)                       (Eq. 4)
  f_dag  = Z_P^-1 sum_k f_k / v_k,  Z_P = sum_k 1/v_k,  var = Z_P^-1                          (Eqs. 18-20)

Taweret's own test suite compares the same quantities with arrays produced by SAMBA, the paper's
companion code; this file re-derives them from the printed equations instead, so it does not
depend on either code being right. Usage: python taweret_samba_mixing.py      (under a second)"""
import numpy as np
from math import factorial
from scipy import special, integrate
from Taweret.models.samba_models import Loworder, Highorder, TrueModel
from Taweret.mix.gaussian import Multivariate

def rel(a, b): return np.max(np.abs(a - b) / np.abs(b))
ok = True
g = np.linspace(0.05, 1.0, 40)

# 1. exact F(g): Bessel closed form vs our own quadrature vs Taweret's TrueModel
z = 1 / (32 * g**2)
F_bessel = np.exp(z) / (2 * np.sqrt(2) * g) * special.kv(0.25, z)
F_quad = np.array([integrate.quad(lambda x: np.exp(-x**2 / 2 - gg**2 * x**4), -np.inf, np.inf, epsabs=1e-13, epsrel=1e-13)[0] for gg in g])
F_taw = np.asarray(TrueModel().evaluate(g)[0]).ravel()
r1, r2 = rel(F_quad, F_bessel), rel(F_taw, F_bessel)
print(f"F(g): quadrature vs Bessel {r1:.1e}, Taweret TrueModel vs Bessel {r2:.1e}")
ok &= r1 < 1e-8 and r2 < 1e-8

# 2. truncated series at N_s = N_l = 3 (the order Taweret's own test uses)
N = 3
s = [np.sqrt(2) * special.gamma(2 * (k // 2) + 0.5) * (-4) ** (k // 2) / factorial(k // 2) if k % 2 == 0 else 0.0 for k in range(N + 1)]
Fs = sum(s[k] * g**k for k in range(N + 1))
Fl = sum(special.gamma(k / 2 + 0.25) / (2 * factorial(k)) * (-0.5) ** k * g ** (-k - 0.5) for k in range(N + 1))
lo, hi = Loworder(order=N), Highorder(order=N)
m_lo, sd_lo = [np.asarray(a).ravel() for a in lo.evaluate(g)]
m_hi, sd_hi = [np.asarray(a).ravel() for a in hi.evaluate(g)]
r3, r4 = rel(m_lo, Fs), rel(m_hi, Fl)
print(f"series N=3: weak-coupling vs Eq.3 {r3:.1e}, strong-coupling vs Eq.4 {r4:.1e}")
ok &= r3 < 1e-10 and r4 < 1e-10

# 3. precision-weighted (bivariate Gaussian) mixing, from the two models' own means and widths
mix = Multivariate(g, {"1": lo, "2": hi}, n_models=2)
_, mean, _, std = mix.predict(ci=68)
v1, v2 = sd_lo**2, sd_hi**2
ZP = 1 / v1 + 1 / v2
f_dag, sd_dag = (m_lo / v1 + m_hi / v2) / ZP, np.sqrt(1 / ZP)
r5, r6 = rel(np.asarray(mean).ravel(), f_dag), rel(np.asarray(std).ravel(), sd_dag)
print(f"mixing: mean vs Eq.18 {r5:.1e}, width vs Z_P^-1/2 {r6:.1e}")
ok &= r5 < 1e-8 and r6 < 1e-8
# 4. the widths, independently of Taweret. Paper Sec. II.B, informative error models, N=3 (odd):
#    sigma_s = Gamma(N/2+1/2) (4g)^(N+1) cbar = 256 g^4 cbar
#    sigma_l = (1/(4g))^(N+3/2) dbar / Gamma(N/2+3/2) = (4g)^-4.5 dbar / 2
#    (a) Taweret's widths must have exactly this g-dependence with cbar, dbar "of order one";
#    (b) their size must match SAMBA, the paper's companion code (reference arrays shipped with
#        Taweret's tests: rows 2 and 3 are the variances on g = linspace(1e-6, 1, 100)).
cbar = sd_lo / (special.gamma(N / 2 + 0.5) * (4 * g) ** (N + 1))
dbar = sd_hi * (4 * g) ** (N + 1.5) * special.gamma(N / 2 + 1.5)
flat = max(np.ptp(cbar) / cbar.mean(), np.ptp(dbar) / dbar.mean())
print(f"error models: cbar = {cbar.mean():.4f}, dbar = {dbar.mean():.4f}, relative spread over g {flat:.1e}")
ok &= flat < 1e-10 and 0.1 < cbar.mean() < 10 and 0.1 < dbar.mean() < 10
from importlib.resources import files
ref = np.loadtxt(str(files("Taweret.tests") / "samba_results.txt"), delimiter=",")
gs = np.linspace(1e-6, 1.0, 100)
s_lo = np.asarray(lo.evaluate(gs)[1]).ravel(); s_hi = np.asarray(hi.evaluate(gs)[1]).ravel()
r7, r8 = rel(s_lo, np.sqrt(ref[2])), rel(s_hi, np.sqrt(ref[3]))
print(f"widths vs SAMBA reference arrays: weak {r7:.1e}, strong {r8:.1e}")
ok &= r7 < 1e-8 and r8 < 1e-8

# 5. physics: in the gap between the expansions the mixture must beat both series
gap = (g > 0.15) & (g < 0.5)
e_mix = np.max(np.abs(f_dag[gap] - F_bessel[gap])); e_lo = np.max(np.abs(Fs[gap] - F_bessel[gap])); e_hi = np.max(np.abs(Fl[gap] - F_bessel[gap]))
print(f"gap 0.15<g<0.5: max |error| mixed {e_mix:.3f}, weak series {e_lo:.3f}, strong series {e_hi:.3f}")
ok &= e_mix < 0.5 * min(e_lo, e_hi)
print("TAWERET SAMBA", "OK" if ok else "FAIL")
import sys
sys.exit(0 if ok else 1)
