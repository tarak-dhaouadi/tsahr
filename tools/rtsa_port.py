"""
Copyright (C) the RTSA authors (Soerensen, Olsen, Lange, Gluud) for the algorithms and
code this file is derived from (RTSA 0.2.2, GPL >= 2); copyright (C) Tarak Dhaouadi for
the adaptation. Free software under GPL (>= 2): see ../DESCRIPTION and ../inst/COPYRIGHTS.

Faithful Python port of the numerical engine of RTSA 0.2.2
(R/RTSA_helperfunctions.R, R/boundaries.R, src/first.cpp -- init_int,
recur_int, prob only; the other first.cpp exports are never called from R).
Used only to cross-check the C++/R code written for tsahr (no R interpreter
is available in this sandbox).
"""
import numpy as np
from scipy.stats import norm
from scipy.optimize import brentq

ZNINF = -20.0

# ---------------------------------------------------------------- spending
def esOF(alpha, timing):
    timing = np.asarray(timing, float)
    with np.errstate(divide="ignore"):
        as_cum = 2 * (1 - norm.cdf(norm.ppf(1 - alpha / 2) / np.sqrt(timing)))
    as_incr = np.concatenate(([as_cum[0]], np.diff(as_cum)))
    return as_cum, as_incr

def sd_inf(timing):
    timing = np.asarray(timing, float)
    prev = np.concatenate(([0.0], timing[:-1]))
    return np.sqrt(timing - prev), np.sqrt(timing)

# ---------------------------------------------------------------- C++ ports
def init_int(wj, zj, delta, sd1):
    return wj * norm.pdf(zj, loc=delta * sd1, scale=1.0)

def recur_int(k, sd_incr, sd_proc, zj, last, zj_up, wj_up, delta, bs):
    # k is the 1-based look index used in the R/C++ code
    y_prev = zj * sd_proc[k - 2]
    y_cur = zj_up * sd_proc[k - 1]
    sdk = sd_incr[k - 1]
    ratio = sd_proc[k - 1] / sdk
    if bs:
        arg = (y_prev[None, :] - y_cur[:, None]) / sdk
    else:
        arg = (y_cur[:, None] - y_prev[None, :]) / sdk
    dens = norm.pdf(arg, loc=delta * sdk, scale=1.0)
    return (dens * (last * ratio)[None, :]).sum(axis=1) * wj_up

def prob(xq, last, zj, k, sd_incr, sd_proc, bs, delta):
    y_prev = zj * sd_proc[k - 2]
    sdk = sd_incr[k - 1]
    if (not bs) and delta != 0:
        p = norm.cdf((y_prev - xq) / sdk, loc=-delta * sdk)
    elif bs:
        p = norm.cdf((xq - y_prev) / sdk, loc=delta * sdk)
    else:
        p = norm.cdf((y_prev - xq) / sdk, loc=delta * sdk)
    return float((last * p).sum())

# ---------------------------------------------------------------- helpers
def z_n_w(r, sd_incr, za, zb, i, delta):
    """i is 1-based as in R."""
    j = np.arange(1, 6 * r)
    xi = (delta * sd_incr[i - 1]
          + (j < r) * (-3 - 4 * np.log(r / j))
          + ((r <= j) & (j <= 5 * r)) * (-3 + 3 * (j - r) / (2 * r))
          + (5 * r < j) * (3 + 4 * np.log(r / (6 * r - j))))
    xi = xi.astype(float)
    if np.any(xi < za[i - 1]):
        indi = np.max(np.where(xi < za[i - 1])[0])
        xi = xi[indi:].copy()
        xi[0] = za[i - 1]
    if np.any(xi > zb[i - 1]):
        indi = np.min(np.where(xi > zb[i - 1])[0])
        xi = xi[: indi + 1].copy()
        xi[indi] = zb[i - 1]
    n = len(xi)
    m = 2 * n - 1
    zj = np.zeros(m)
    zj[0::2] = xi
    zj[1:m - 1:2] = (xi[:-1] + xi[1:]) / 2
    wj = np.zeros(m)
    for k in range(1, m + 1):          # 1-based k as in R
        if k == 1:
            wj[k - 1] = (1 / 6) * (zj[2] - zj[0])
        elif k in range(3, m - 1, 2):
            wj[k - 1] = (1 / 6) * (zj[k + 1] - zj[k - 3])
        elif k in range(2, m, 2):
            wj[k - 1] = (4 / 6) * (zj[k] - zj[k - 2])
        else:
            wj[k - 1] = (1 / 6) * (zj[m - 1] - zj[m - 3])
    return zj, wj

def searchfunc(last, zj, i, as_, sd_incr, sd_proc, za, zb, tol, bs, delta,
               max_outer=400):
    maxnn = 50
    upper = zb[i - 2] * sd_proc[i - 1]
    if bs:
        upper = za[i - 2] * sd_proc[i - 1]
    dl = 10.0
    qout = prob(upper, last, zj, i, sd_incr, sd_proc, bs, delta)
    it = 0
    while True:
        it += 1
        if abs(qout - as_) <= tol:
            break
        if qout > as_ + tol:
            dl /= 10
            for _ in range(maxnn):
                if bs:
                    upper -= 2 * dl
                upper += dl
                qout = prob(upper, last, zj, i, sd_incr, sd_proc, bs, delta)
                if qout <= as_ + tol:
                    break
        if qout < as_ - tol:
            dl /= 10
            for _ in range(maxnn):
                if bs:
                    upper += 2 * dl
                upper -= dl
                qout = prob(upper, last, zj, i, sd_incr, sd_proc, bs, delta)
                if qout >= as_ - tol:
                    break
        if it > max_outer:          # RTSA has no cap; float-granularity guard
            break
    return upper / sd_proc[i - 1]

# ---------------------------------------------------------------- alpha
def alpha_boundary(inf_frac, side, alpha, beta, es_alpha="esOF", tol=1e-9,
                   r=18, type_="design", design_R=None):
    inf_frac = np.asarray(inf_frac, float)
    delta_unused = abs(norm.ppf(alpha / side) + norm.ppf(beta))
    nn = len(inf_frac)
    alpha_timing = inf_frac / inf_frac.max() if np.any(inf_frac > 1) else inf_frac
    as_cum, as_incr = esOF(alpha / side, alpha_timing)
    if type_ == "analysis":
        sd_incr, sd_proc = sd_inf(inf_frac * design_R)
    else:
        sd_incr, sd_proc = sd_inf(inf_frac)
    as_incr = as_incr.copy()
    as_incr[0] = max(0.0, min(alpha, as_incr[0]))
    za = np.zeros(nn); zb = np.zeros(nn)
    zb[0] = -ZNINF if as_incr[0] < tol else norm.isf(as_incr[0])
    za[0] = -zb[0]
    zj, wj = z_n_w(r, sd_incr, za, zb, 1, 0.0)
    last = None
    for i in range(2, nn + 1):
        if i == 2:
            last = init_int(wj, zj, 0.0, sd_incr[0])
        a = as_incr[i - 1]
        if a <= 0 or a >= 1:
            a = max(0.0, min(1.0, a)); as_incr[i - 1] = a
        if a < tol:
            zb[i - 1] = -ZNINF
        elif a == 1:
            zb[i - 1] = 0.0
        else:
            zb[i - 1] = searchfunc(last, zj, i, a, sd_incr, sd_proc, za, zb,
                                   tol, False, 0.0)
        za[i - 1] = -zb[i - 1]
        if i != nn:
            zj_up, wj_up = z_n_w(r, sd_incr, za, zb, i, 0.0)
            last = recur_int(i, sd_incr, sd_proc, zj, last, zj_up, wj_up, 0.0, False)
            zj, wj = zj_up, wj_up
    return dict(inf_frac=inf_frac, alpha_ubound=zb, alpha=alpha,
                as_incr=as_incr, delta=delta_unused)

# ---------------------------------------------------------------- beta
def beta_boundary(inf_frac, beta, side, alpha_ubound, alpha, zninf=ZNINF,
                  tol=1e-15, rm_bs=0, delta=None, r=18, design_R=None,
                  warp_root=None):
    inf_frac = np.asarray(inf_frac, float)
    if delta is None:
        delta = abs(norm.ppf(alpha / side) + norm.ppf(beta))
    nn = len(inf_frac)
    org = inf_frac.copy()
    if warp_root is not None:
        org = inf_frac * warp_root
    beta_timing = inf_frac.copy()
    if design_R is not None:
        beta_timing = inf_frac / design_R
        org = inf_frac.copy()
        if org.max() < design_R:
            org = np.append(org, design_R)
        beta_timing = np.append(beta_timing[beta_timing < 1], 1.0)
        nn = len(beta_timing)
    if np.any(beta_timing > 1):
        beta_timing = np.append(beta_timing[beta_timing < 1], 1.0)
        nn = len(beta_timing)
    if rm_bs != 0:
        beta_timing = np.concatenate((np.zeros(rm_bs), beta_timing[rm_bs:]))
    as_cum, as_incr = esOF(beta / side, beta_timing)
    as_incr = as_incr.copy()
    sd_incr, sd_proc = sd_inf(org)
    if as_incr[0] <= 0 or as_incr[0] >= beta:
        as_incr[0] = max(0.0, min(beta, as_incr[0]))
    za = np.zeros(nn)
    zb = np.asarray(alpha_ubound, float).copy()
    if as_incr[0] == 0:
        za[0] = zninf
    elif as_incr[0] == beta:
        za[0] = 0.0
    else:
        za[0] = norm.ppf(as_incr[0], loc=sd_proc[0] * delta, scale=1.0)
    zj, wj = z_n_w(r, sd_incr, za, zb, 1, delta)
    last = None
    for i in range(2, nn + 1):
        if i == 2:
            last = init_int(wj, zj, delta, sd_incr[0])
        a = as_incr[i - 1]
        if a <= 0 or a >= 1:
            a = max(0.0, min(1.0, a)); as_incr[i - 1] = a
        if a < tol:
            za[i - 1] = zninf
        elif a == beta:
            za[i - 1] = 0.0
        else:
            za[i - 1] = searchfunc(last, zj, i, a, sd_incr, sd_proc, za, zb,
                                   tol, True, delta)
        if i != nn:
            zj_up, wj_up = z_n_w(r, sd_incr, za, zb, i, delta)
            last = recur_int(i, sd_incr, sd_proc, zj, last, zj_up, wj_up, delta, False)
            zj, wj = zj_up, wj_up
    return dict(za=za, zb=zb, as_incr=as_incr, as_cum=as_cum, delta=delta,
                sd_incr=sd_incr, sd_proc=sd_proc, beta_timing=beta_timing, org=org)

def inf_warp(x, alpha_ubound, alpha, beta, timing, rm_bs=0, side=1, delta=None):
    a = beta_boundary(timing, beta, side, alpha_ubound, alpha, rm_bs=rm_bs,
                      delta=delta, warp_root=x)["za"][len(timing) - 1]
    return alpha_ubound[len(timing) - 1] - a

def slide_uniroot(f, start, step, nmax=50):
    upper = start
    for _ in range(nmax):
        try:
            return brentq(f, upper - step, upper, xtol=1e-9, rtol=4 * np.finfo(float).eps)
        except ValueError:
            upper += step
    raise RuntimeError("no root")

# ---------------------------------------------------------------- boundaries
def boundaries_design_s2_nb(timing, alpha=0.05, beta=0.2):
    """side = 2, futility = 'non-binding', type = 'design' (RTSA boundaries())."""
    timing = np.asarray(timing, float)
    if timing.max() < 1:
        timing = np.append(timing, 1.0)
    ab = alpha_boundary(timing, 2, alpha, beta)
    ub = ab["alpha_ubound"]
    delta = abs(norm.ppf(alpha / 2) + norm.ppf(beta))
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta)
    f1 = lambda x: inf_warp(x, ub, alpha, beta, timing, 0, 1, delta)
    root = slide_uniroot(f1, 0.95, 0.02)
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta, warp_root=root)
    rm = int(np.sum(lb["za"] < 0))
    f2 = lambda x: inf_warp(x, ub, alpha, beta, timing, rm, 1, delta)
    root = slide_uniroot(f2, 0.95, 0.05)
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta, rm_bs=rm, warp_root=root)
    return dict(timing=timing, alpha_ubound=ub, za=lb["za"], root=root, rm_bs=rm,
                delta=delta, root_pass1_rm=rm)

def boundaries_analysis_s2_nb(timing, design_R, alpha=0.05, beta=0.2):
    """side = 2, 'non-binding', type = 'analysis'."""
    timing = np.asarray(timing, float)
    ab = alpha_boundary(timing, 2, alpha, beta, type_="analysis", design_R=design_R)
    ub = ab["alpha_ubound"]
    delta = ab["delta"]
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta, design_R=design_R)
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta, design_R=design_R,
                       rm_bs=int(np.sum(lb["za"] < 0)))
    rm = int(np.sum(lb["za"] < 0))
    lb = beta_boundary(timing, beta, 1, ub, alpha, delta=delta, design_R=design_R,
                       rm_bs=rm)
    za = lb["za"].copy()
    rm_final = int(np.sum(np.abs(za) == 20))
    beta_ubound = np.concatenate((np.full(rm_final, np.nan), za[np.abs(za) < 20]))
    if beta_ubound[-1] > ub[-1]:
        beta_ubound[-1] = ub[-1]
    return dict(timing=timing, alpha_ubound=ub, beta_ubound=beta_ubound,
                za=za, delta=delta, root=design_R, rm_bs=rm)

def rtsa_retrospective(t_obs, alpha=0.05, beta=0.2):
    """RTSA::RTSA(type='analysis', design = NULL, power_adj = TRUE) route
    for a two-sided, non-binding-futility design; t_obs = subjects / RIS."""
    t_obs = np.asarray(t_obs, float)
    t_design = t_obs[t_obs <= 1]
    des = boundaries_design_s2_nb(t_design, alpha, beta)
    R = des["root"]
    if t_obs.max() < R:
        tim = np.append(t_obs, R)
    elif t_obs.max() > R:
        tim = np.append(t_obs[t_obs < R], R)
    else:
        tim = t_obs
    ana = boundaries_analysis_s2_nb(tim, R, alpha, beta)
    return des, ana
