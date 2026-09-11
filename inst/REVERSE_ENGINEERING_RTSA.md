# RTSA beta/futility boundary engine in tsahr 0.2.4

`tsahr` 0.2.4 uses the retrospective/analysis-mode `tsa_beta_bound`
algorithm from RTSA rather than the previous RPact-inspired beta engine.

The implementation is based on RTSA's `getInnerWedge()` and the helper
functions it calls (`betas_Obf`, `sdfunc`, `first_old`, `other_old`,
`searchfunc_old`, `qpos_old`, `fcab_old`, `trap_old`, and `gfunc`).
RTSA labels these routines as "old TSA functions (translated from java)".
For two-sided retrospective analysis, RTSA's `boundaries()` code calls
`getInnerWedge()` when `tsa_beta_bound = TRUE`.

The algorithm:

1. Compute cumulative O'Brien-Fleming beta spending:
   `2 * upper_tail(qnorm(1-beta/2) / sqrt(t))`.
2. Convert it to incremental beta spending.
3. Build a symmetric null-referenced inner wedge recursively.
4. Propagate the surviving density through successive information
   increments using the original trapezoidal numerical integration.
5. Iteratively solve each new wedge edge so its incremental probability
   equals the incremental beta spend.
6. Calculate `testDrift = fakeIFY + abs(ya[last])`.
7. Return `za + sqrt(t) * testDrift` as the futility boundary.
8. In the RTSA retrospective `tsa_beta_bound` branch, if observed
   information exceeds 1, use `qnorm(1-alpha/2)` as `fakeIFY`, compute
   the wedge only for `t < 1`, and append the definitive conventional
   boundary. Otherwise `fakeIFY` is the final efficacy boundary and RTSA
   replaces the final inner-wedge value by `qnorm(1-alpha/2)`.

The package deliberately retains its existing alpha/effect-size/DARIS
machinery; only the beta/futility engine has been replaced.

Source reference:
https://raw.githubusercontent.com/AnneLyng/RTSA/master/R/RTSA_helperfunctions.R
https://raw.githubusercontent.com/AnneLyng/RTSA/master/R/boundaries.R
