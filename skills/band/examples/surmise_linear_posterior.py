"""surmise analytic anchor: a linear model with Gaussian noise and a Gaussian prior has an exact
Gaussian posterior. Calibrate it through surmise's own pipeline (PCGP emulator, directbayes,
Metropolis-Hastings) and compare with the closed form.

Pass (a regression bar, not a proof): batch-means effective sample size > 500 per parameter,
posterior means within 3 batch-means Monte Carlo standard errors, widths within 10%, and the
posterior correlation (about -0.85 here) within 0.05 of the exact one.

Two things this case taught, both general:
- surmise 1.0 refuses to run until set_RNG() is called, and directbayes requires every
  Metropolis-Hastings field (theta0, stepType, stepParam, nSamples, nBurnSamples, verbose).
- stepParam=None sets the proposal width to the PRIOR's spread. For a well-constrained parameter
  that is 10x the posterior width: 40,000 samples gave an effective sample size of 44-115 and a
  0.3-sigma error in the mean. Use ~2.4/sqrt(d) times the posterior width (from a pilot run),
  and always report the effective sample size.

Usage: python surmise_linear_posterior.py [seed]      (about 10 s)
"""
import numpy as np, scipy.stats as sps, sys
from surmise.emulation import emulator
from surmise.calibration import calibrator
from surmise import set_RNG

rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
set_RNG(rng)  # surmise 1.0 refuses to run without this
x = np.linspace(0, 1, 15).reshape(-1, 1)
X = np.hstack([np.ones_like(x), x])               # design: f = th0 + th1 x
th_true, sigma = np.array([0.3, 0.8]), 0.05
y = X @ th_true + rng.normal(0, sigma, len(x))
mu0, s0 = np.array([0.5, 0.5]), 0.5

class prior:
    def lpdf(theta):
        return (sps.norm.logpdf(theta[:, 0], mu0[0], s0) + sps.norm.logpdf(theta[:, 1], mu0[1], s0)).reshape(-1, 1)
    def rnd(n):
        return np.vstack([rng.normal(mu0[0], s0, n), rng.normal(mu0[1], s0, n)]).T

# exact posterior
S_post = np.linalg.inv(np.eye(2) / s0**2 + X.T @ X / sigma**2)
m_post = S_post @ (mu0 / s0**2 + X.T @ y / sigma**2)
sd_post = np.sqrt(np.diag(S_post))

theta_train = prior.rnd(80)
f = (X @ theta_train.T)                            # shape (n_x, n_theta), surmise convention
emu = emulator(x=x, theta=theta_train, f=f, method='PCGP')
cal = calibrator(emu=emu, y=y, x=x, thetaprior=prior, method='directbayes',
                 yvar=np.full(len(y), sigma**2),
                 args={'sampler': 'metropolis_hastings', 'nSamples': 40000, 'nBurnSamples': 5000, 'theta0': None, 'stepType': 'Normal', 'stepParam': 2.4 / np.sqrt(2) * sd_post,
                       'verbose': False})
print("exact  mean", np.round(m_post, 5), " sd", np.round(sd_post, 5))
chain = cal.info['thetarnd']
print("surmise mean", np.round(chain.mean(0), 5), " sd", np.round(chain.std(0), 5))
# Monte Carlo error by batch means (sqrt(n) batches): unlike a truncated autocorrelation sum it
# does not miss a slow-mixing component that sits below the truncation threshold.
n = len(chain); nb = int(np.sqrt(n)); bs = n // nb
bm = chain[: nb * bs].reshape(nb, bs, -1).mean(1)
mcse = bm.std(0, ddof=1) / np.sqrt(nb)
E = chain.var(0) / mcse**2
dm = np.abs(chain.mean(0) - m_post) / mcse
rs = chain.std(0) / sd_post
rho_exact = S_post[0, 1] / np.sqrt(S_post[0, 0] * S_post[1, 1])
rho_mc = np.corrcoef(chain.T)[0, 1]
print("ESS (batch means)", np.round(E), " mean offset / MC std error:", np.round(dm, 2), "  sd ratio:", np.round(rs, 3))
print(f"posterior correlation: exact {rho_exact:.3f}, surmise {rho_mc:.3f}")
# A regression bar, not a proof: an exact posterior should pass it with high probability.
ok = np.all(E > 500) and np.all(dm < 3) and np.all(np.abs(rs - 1) < 0.1) and abs(rho_mc - rho_exact) < 0.05
print("SURMISE POSTERIOR", "OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
