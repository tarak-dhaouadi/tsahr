# RTSA-matched boundary engines in tsahr

## Alpha-spending fix (0.2.6)

`tsahr` versions 0.2.0-0.2.5.1 computed the two-sided alpha-spending
boundaries with the more commonly-seen textbook two-argument Lan-DeMets
O'Brien-Fleming form, `2*(1-pnorm(qnorm(1-alpha/2)/sqrt(t)))`. That form
is internally valid as *an* alpha-spending function (it does reach
exactly `alpha` at t=1), and is the form quoted directly in some
general group-sequential-design references (e.g. gsDesign's
documentation) -- but it does not match the specific TSA methodology
(Copenhagen Trial Unit / RTSA, Thorlund et al.) that this package
documents itself as following (Miladinovic et al. 2013, Wetterslev
et al. 2009), and does not match RTSA's own `side`-parameterised form
evaluated at `side=2`: `2*(1-pnorm(qnorm(1-alpha/side/2)/sqrt(t)))*side`,
which at `side=2` reduces to `4*(1-pnorm(qnorm(1-alpha/4)/sqrt(t)))`.
0.2.6 corrects `.alpha_spend_OF()` to use this RTSA-matched form. This
was confirmed directly against a live call, across the full 5-look
schedule:

```
> RTSA::boundaries(timing=c(0.2,0.4,0.6,0.8,1), alpha=0.05, side=2,
                    es_alpha="esOF")
Upper: 4.877  3.357  2.680  2.290  2.031
```

All 5 boundaries match the corrected formula (run through tsahr's
existing recursive integration engine) essentially exactly, and are
clearly distinguishable from the old formula's 4.383, 3.099, 2.554,
2.254, 2.063 for the same schedule. A first-look regression test
(`test-alpha-spend-rtsa.R`) additionally pins the corrected formula
against this RTSA reference in closed form, since the first look has
no prior boundary to condition on and so needs no recursive-engine
approximation.

Both forms independently reach exactly `alpha` at t=1; they differ in
how alpha is allocated across interim looks -- the old form spent
roughly 9-11x more alpha at the first look of that schedule than RTSA's
boundaries call for, which works directly against the reason people
choose an O'Brien-Fleming design (strong protection against declaring
"significance" from sparse early evidence). Because both forms
satisfy `alpha*(1) = alpha` by construction, this discrepancy was not
caught by the existing total-alpha Monte Carlo/closed-form checks in
`R/obf_boundaries.R`, which check the *total* spend rather than the
*shape* across interim looks. This is a genuine correctness bug
relative to this package's own documented reference methodology, not a
stylistic or reference-preference choice -- anyone who used `tsa_hr()`
from a version between 0.2.0 and 0.2.5.1 for TSA boundaries at an
interim look should re-run their analysis with 0.2.6 or later. Only
`.alpha_spend_OF()` changed; the surrounding recursive integration
engine (the actual boundary-solving machinery) is untouched, as is the
beta/futility engine described below.

## Default grid resolution (0.2.6.1)

The "all 5 boundaries match essentially exactly" claim above was
re-checked with an independent from-scratch Python port of
`.obf_alpha_boundary()`, run against the nominal timing actually passed
to `RTSA::boundaries()` (0.2, 0.4, 0.6, 0.8, 1.0) rather than the
rounded `SMA_Timing` column it reports back (0.205, 0.409, ...) --
mixing those two up produces a spurious ~0.06 discrepancy at the first
look that has nothing to do with the formula or engine, since the
first look is an exact closed-form quantity determined entirely by the
timing value fed in. Using the correct nominal timing, the Python port
matched RTSA's boundaries to within ~0.003-0.006 across all 5 looks
even at this engine's long-standing default of `n_grid=2000` -- i.e.
"essentially exactly" holds up, and does not require the larger grid
introduced below to be true.

A previous draft of this note additionally claimed a specific,
more severe problem at n_grid=2000 -- boundaries of 4.877, 3.358,
2.703, 2.307, 2.064 against RTSA's 4.877, 3.357, 2.680, 2.290, 2.031
(~0.03 error at the final look), with a cited progression of
0.0325/0.0133/0.0074/0.0044/0.0020 as n_grid rose from 2000 to 32000.
That specific set of numbers could not be reproduced by the Python
port above and was never confirmed by an actual run of this package's
R code -- it is retracted here as unverified rather than repeated.
`.obf_alpha_boundary()`'s default `n_grid` is nonetheless still raised
from 2000 to 16000 in this release, on narrower grounds: FFT-based
convolution makes the extra grid resolution essentially free for this
package's actual usage pattern (a handful of interim looks per
`tsa_hr()` call), so there's no real cost to the more conservative
choice even without a confirmed problem at 2000. Anyone with a working
R installation is encouraged to run the snippet in the VALIDATION note
of `R/obf_boundaries.R` and confirm (or correct) the numbers above.

A 20,000-replicate Monte Carlo re-check (K=2, K=3 unequally spaced,
K=5, K=10) run directly against the corrected formula gave empirical
type-I error of 4.35%-4.93% against the 5% nominal target (Monte Carlo
SE ~=0.15%), consistent with correct behaviour. See the `VALIDATION`
note at the top of `R/obf_boundaries.R` for the fuller numeric account.
The full 5-look, engine-level comparison against live RTSA output has
been checked against the corrected formula specifically (see "Default
grid resolution" above); the one comparison that has only been run
under the pre-0.2.6 formula and not repeated for the corrected one is
the classical published ~2.040 O'Brien-Fleming constant check, which is
a different, narrower reference point (a single textbook number, not
RTSA's own multi-look output) -- that narrower gap does not need to
hold anyone up, since the direct RTSA comparison above is the stronger
and more relevant check for this package's specific goal of matching
RTSA rather than the general OF literature.

## Beta/futility boundary engine (added 0.2.4)

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
