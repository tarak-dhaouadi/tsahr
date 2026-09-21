import ctypes, numpy as np, time
from scipy.optimize import brentq
import rtsa_port as rp
from scipy.stats import norm
lib = ctypes.CDLL('./librtsa_standalone.so')
dp = ctypes.POINTER(ctypes.c_double)
def arr(x): 
    a = np.ascontiguousarray(x, dtype=float); return a, a.ctypes.data_as(dp)

def c_alpha(t, side, alpha, design_R=np.nan):
    t,pt = arr(t); out = np.zeros(len(t)); 
    lib.sa_alpha.argtypes=[dp,ctypes.c_int,ctypes.c_int,ctypes.c_double,ctypes.c_double,dp]
    assert lib.sa_alpha(pt,len(t),side,alpha,design_R,out.ctypes.data_as(dp))==0
    return out
def last_error():
    lib.sa_last_error.argtypes=[ctypes.c_char_p, ctypes.c_int]
    b=ctypes.create_string_buffer(400); lib.sa_last_error(b,400); return b.value.decode()
def c_beta(t, ub, beta, side, delta, rm_bs=0, design_R=np.nan, warp=np.nan):
    t,pt = arr(t); ub,pu = arr(ub); n = len(t)+2
    za = np.zeros(n); inc = np.zeros(n)
    lib.sa_beta.argtypes=[dp,ctypes.c_int,dp,ctypes.c_int,ctypes.c_double,ctypes.c_int,ctypes.c_double,ctypes.c_int,ctypes.c_double,ctypes.c_double,dp,dp,ctypes.POINTER(ctypes.c_int)]
    unr = ctypes.c_int(0)
    k = lib.sa_beta(pt,len(t),pu,len(ub),beta,side,delta,rm_bs,design_R,warp,za.ctypes.data_as(dp),inc.ctypes.data_as(dp),ctypes.byref(unr))
    c_beta.last_unreachable = unr.value
    assert k>0, "C++ error: " + last_error()
    return za[:k], inc[:k]

t8 = np.array([0.461092,0.527034,0.610745,0.653952,0.754067,0.825699,0.903255,0.961096])
# 1. alpha, 5-look reference and the 9-look design timeline
for tt in ([0.2,0.4,0.6,0.8,1.0], np.append(t8,1.0), np.linspace(0.025,1,40)):
    a_py = rp.alpha_boundary(tt,2,0.05,0.2)["alpha_ubound"]; a_c = c_alpha(tt,2,0.05)
    print("alpha  n=%2d  max|C++ - py| = %.2e" % (len(tt), np.max(np.abs(a_py-a_c))))
# 2. beta, design mode, fixed warp
alpha,beta=0.05,0.2; delta=abs(rp.norm.ppf(alpha/2)+rp.norm.ppf(beta))
tim=np.append(t8,1.0); ub=rp.alpha_boundary(tim,2,alpha,beta)["alpha_ubound"]
for warp,rm in [(1.0,0),(1.15,0),(1.2107,0),(1.2,3)]:
    b_py = rp.beta_boundary(tim,beta,1,ub,alpha,delta=delta,warp_root=warp,rm_bs=rm)["za"]
    b_c,_ = c_beta(tim,ub,beta,1,delta,rm,np.nan,warp)
    print("beta design warp=%.4f rm=%d  max diff = %.2e" % (warp,rm,np.max(np.abs(b_py-b_c))))
# 3. beta, analysis mode
R=1.2107; t_ext=np.append(t8,R); ub2=rp.alpha_boundary(t_ext,2,alpha,beta,type_="analysis",design_R=R)["alpha_ubound"]
ub2c=c_alpha(t_ext,2,alpha,R)
print("alpha analysis max diff", np.max(np.abs(ub2-ub2c)))
for rm in (0,1):
    b_py = rp.beta_boundary(t_ext,beta,1,ub2,alpha,delta=delta,design_R=R,rm_bs=rm)["za"]
    b_c,_ = c_beta(t_ext,ub2c,beta,1,delta,rm,R,np.nan)
    print("beta analysis rm=%d max diff = %.2e" % (rm,np.max(np.abs(b_py-b_c))))
# 4. published RTSA vignette (side = 1, alpha .025, beta .1)
tv=np.array([0.5,0.75,1.0]); ubv=c_alpha(tv,1,0.025)
f=lambda x: ubv[-1]-c_beta(tv,ubv,0.1,1,abs(rp.norm.ppf(0.025)+rp.norm.ppf(0.1)),0,np.nan,x)[0][-1]
root=brentq(f,0.9,1.5,xtol=1e-9)
za,_=c_beta(tv,ubv,0.1,1,abs(rp.norm.ppf(0.025)+rp.norm.ppf(0.1)),0,np.nan,root)
print("C++ vignette: upper",np.round(ubv,3),"SMA_timing",np.round(tv*root,3),"FutLower",np.round(za,3))
print("RTSA vignette: upper [2.963 2.359 2.014] SMA_timing [0.541 0.812 1.083] FutLower [0.332 1.292 2.014]")
# 5. timing of a 40-look design pass (worst case for runtime)
t40=np.linspace(0.02,0.98,39); t40=np.append(t40,1.0)
t0=time.time(); ub40=c_alpha(t40,2,0.05); 
d40=abs(rp.norm.ppf(0.025)+rp.norm.ppf(0.2))
z,_=c_beta(t40,ub40,0.2,1,d40,0,np.nan,1.1); print("40 looks: one beta pass %.3fs"%(time.time()-t0))

# 6. 0.2.7.14 diagnostics: reversed (za > zb) is counted separately from a
#    degenerate (za == zb) grid; an ordinary interval counts as neither.
lib.sa_znw_diag.argtypes=[ctypes.c_double,ctypes.c_double,ctypes.c_double,ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int)]
def znw_diag(za, zb, delta=0.0):
    c=ctypes.c_int(0); r=ctypes.c_int(0)
    n=lib.sa_znw_diag(za,zb,delta,ctypes.byref(c),ctypes.byref(r))
    return c.value, r.value, n
for label,(za,zb) in {"ordinary (-1, 2)":(-1.0,2.0),"degenerate (1, 1)":(1.0,1.0),"REVERSED (1, 0.5)":(1.0,0.5)}.items():
    c,r,n = znw_diag(za,zb)
    print("z_n_w %-20s collapses=%d reversed=%d nodes=%d" % (label,c,r,n))
assert znw_diag(-1.0,2.0)[:2]==(0,0)
assert znw_diag(1.0,1.0)[:2]==(1,0)
assert znw_diag(1.0,0.5)[:2]==(0,1)
print("diagnostic classification OK")

# 7. 0.2.7.15: full design-route calibration (the R orchestration, with scipy's
#    brentq standing in for uniroot) on the schedules that broke 0.2.7.13/14.
def _slide(f, start, step, nmax=50):
    up = start
    for _ in range(nmax):
        try:
            return brentq(f, up - step, up, xtol=1e-9, rtol=4 * np.finfo(float).eps)
        except Exception:
            up += step
    raise RuntimeError("no root bracket")

def design_pass_cpp(t, alpha=0.05, beta=0.2):
    t = np.asarray(t, float)
    if t.max() < 1: t = np.append(t, 1.0)
    ub = c_alpha(t, 2, alpha); nt = len(t)
    delta = abs(norm.ppf(alpha / 2) + norm.ppf(beta))
    def gap(x, rm):
        za, _ = c_beta(t, ub, beta, 1, delta, rm, np.nan, x)
        return ub[-1] - za[nt - 1]
    r1 = _slide(lambda x: gap(x, 0), 0.95, 0.02)
    za, _ = c_beta(t, ub, beta, 1, delta, 0, np.nan, r1)
    assert c_beta.last_unreachable == 0
    rm = int((za < 0).sum())
    r2 = _slide(lambda x: gap(x, rm), 0.95, 0.05)
    za, _ = c_beta(t, ub, beta, 1, delta, rm, np.nan, r2)
    assert c_beta.last_unreachable == 0, "converged pass must not be unreachable"
    assert abs(ub[-1] - za[-1]) < 1e-6, "root residual"
    return r2, rm, za, ub

if __name__ == "__main__":
    user37 = [0.02538682,0.05287274,0.07337192,0.10764900,0.12546251,0.16341297,0.18678300,0.21645033,0.23176335,0.26724431,0.29263113,0.32011705,0.34061623,0.37489331,0.39270682,0.43065727,0.45402731,0.48369464,0.49900766,0.53448862,0.55987544,0.58736136,0.60786054,0.64213762,0.65995113,0.69790158,0.72127162,0.75093894,0.76625197,0.80173292,0.82711975,0.85460567,0.87510485,0.90938192,0.92719543,0.96514589,0.98851592]
    cases = {
      "user 37-look (40 studies, target HR 0.94)": user37,
      "50 even looks": np.linspace(0.02, 1, 50),
      "100 even looks": np.linspace(0.01, 1, 100),
      "dense at start": np.concatenate((np.linspace(0.001, 0.1, 30), np.linspace(0.15, 0.95, 10))),
      "dense at end": np.concatenate((np.linspace(0.05, 0.8, 10), np.linspace(0.9, 0.999, 30))),
      "tiny first fraction": [1e-4, 0.05, 0.2, 0.4, 0.7, 0.95],
      "many early looks": np.concatenate((np.linspace(0.01, 0.3, 20), [0.5, 0.7, 0.9])),
    }
    for name, t in cases.items():
        r, rm, za, ub = design_pass_cpp(t)
        print("design pass %-42s root=%.6f rm_bs=%d final wall=%.6f" % (name, r, rm, ub[-1]))
    # candidate beyond the wall: gap negative, flagged, no exception
    t100 = np.append(np.linspace(0.01, 1, 100)[:-1], 1.0)
    ub = c_alpha(t100, 2, 0.05)
    za, _ = c_beta(t100, ub, 0.2, 1, abs(norm.ppf(0.025) + norm.ppf(0.2)), 0, np.nan, 1.25)
    print("100 looks, candidate x=1.25: unreachable_look=%d, gap=%.3f" % (c_beta.last_unreachable, ub[-1] - za[-1]))
    assert c_beta.last_unreachable > 0 and ub[-1] - za[-1] < 0
    print("robust-schedule design passes OK")

    # 8. 0.2.7.16: exact reachability classification of a beta search
    #    (0 converged / 1 unreachable: target > qmax = sum(last) / 2 hard error:
    #    target reachable but the search failed within max_outer rounds).
    lib.sa_search_classify.argtypes = [ctypes.c_double, ctypes.c_int, ctypes.POINTER(ctypes.c_double)]
    def classify(target, max_outer=400):
        q = ctypes.c_double(0.0)
        code = lib.sa_search_classify(target, max_outer, ctypes.byref(q))
        return code, q.value
    code, qmax = classify(0.5);            print("search target 0.5 (qmax=%.6f): code %d" % (qmax, code)); assert code == 0
    code, qmax = classify(qmax + 0.05);    print("search target qmax+0.05      : code %d (unreachable)" % code); assert code == 1
    code, qmax = classify(0.3, max_outer=1); print("search target 0.3, max_outer=1: code %d (reachable, not found -> hard error)" % code); assert code == 2
    print("reachability classification OK")

    # 9. 300 random schedules (3-45 looks), fixed seed: every one must calibrate.
    #    (0.2.7.14's strict throw failed 114 of a comparable 300; this is what
    #    NEWS.md 0.2.7.15/16 refer to. Standalone only -- not an R test.)
    rng = np.random.default_rng(2024)
    n_ok, failures = 0, []
    for _ in range(300):
        n = int(rng.integers(3, 45))
        t = np.unique(np.round(np.sort(rng.uniform(0.003, 0.995, n)), 6))
        try:
            design_pass_cpp(t); n_ok += 1
        except Exception as e:
            failures.append((len(t), str(e)[:60]))
    print("300 random schedules: %d calibrated, %d failed %s" % (n_ok, len(failures), failures[:3]))
    assert n_ok == 300, "random-schedule calibration regression"
    print("random-schedule calibration OK")

    # 10. 0.2.7.17: the compiled core against numbers printed by the LIVE RTSA
    #     0.2.2 package (inst/extdata/rtsa_0.2.2_reference.R): design route and
    #     RTSA's own (unextended-timing) analysis call.
    ref_root = 1.133241903483384
    ref_a  = np.array([4.332633646049564, 2.963130728293607, 2.359044407368292, 2.014090377368289])
    ref_b  = np.array([np.nan, 0.6325313124459123, 1.4041617881408750, 2.0140903773682739])
    ref_aa = np.array([4.332633646049564, 2.963130674316038, 2.359044357300598, 2.014090359906189])
    ref_ab = np.array([np.nan, 0.3709071738839083, 1.1440542785920043, 1.7200465809397056, 2.1228442649443582])
    t4 = np.array([0.25, 0.5, 0.75, 1.0])
    r, rm, za, ub = design_pass_cpp(t4)
    bu = np.where(np.abs(za) == 20, np.nan, za)
    e_root, e_a, e_b = abs(r - ref_root), np.max(np.abs(ub - ref_a)), np.nanmax(np.abs(bu - ref_b))
    ub2 = c_alpha(t4, 2, 0.05, ref_root)            # analysis alpha: spent on t
    d = abs(norm.ppf(0.025) + norm.ppf(0.2)); rmm = 0
    for _ in range(3):                              # RTSA: three beta passes
        za2, _inc = c_beta(t4, ub2, 0.2, 1, d, rmm, ref_root, np.nan)   # 4 alpha bounds, 5 looks
        rmm = int((za2 < 0).sum())
    bu2 = np.where(np.abs(za2) == 20, np.nan, za2)
    e_aa, e_ab = np.max(np.abs(ub2 - ref_aa)), np.nanmax(np.abs(bu2 - ref_ab))
    print("live RTSA 0.2.2: design root %.1e alpha %.1e beta %.1e | analysis alpha %.1e beta %.1e"
          % (e_root, e_a, e_b, e_aa, e_ab))
    assert max(e_root, e_a, e_b, e_aa, e_ab) < 1e-12
    print("live RTSA 0.2.2 reference reproduced")

    # 11. 0.2.7.22: the `spend == beta` knife-edge. tsahr computes beta = 1 - power
    #     (0.19999999999999996 for power 0.8); on a low-information schedule every
    #     interim look is suppressed, the final look carries all the beta spend, and
    #     RTSA's exact-float shortcut `spend == beta -> za = 0` fired for some betas
    #     only, making the calibration gap constant ("no root bracket"). The
    #     shortcut is no longer ported: every power now calibrates identically.
    sched = np.linspace(0.009, 0.26, 30)
    roots = {}
    for pw in (0.80, 0.85, 0.90, 0.95, 0.99):
        for b in (1 - pw, round(1 - pw, 12), (1 - pw) + 1e-12, (1 - pw) - 1e-12):
            r, rm, za, ub = design_pass_cpp(sched, beta=b)
            assert rm == 30, "all 30 interim looks must be suppressed"
            roots.setdefault(pw, []).append(r)
        assert max(roots[pw]) - min(roots[pw]) < 1e-6, "root must not depend on the last bit of beta"
    print("knife-edge: roots by power", {k: round(v[0], 7) for k, v in roots.items()})
    print("knife-edge fix OK")

