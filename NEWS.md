# tsahr 0.2.8.1

## CRAN `--as-cran` check fixes

* **DESCRIPTION: corrected the Copenhagen Trial Unit URL.** The TSA software
  reference `<https://ctu.dk/tsa/>` returned a 404; replaced with the correct
  `<https://ctu.dk/tools>` (also fixed in `README.md`).
* **DESCRIPTION: removed the redundant `Author:` field.** It duplicated (and
  had drifted from) the field R derives automatically from `Authors@R`,
  triggering a `checking DESCRIPTION meta-information ... NOTE`. `Authors@R`
  is now the sole source of truth for the `Author` field.

# tsahr 0.2.8

## Pooled-effect line in the TSA plot subtitle, configurable endpoint label, new example datasets

* **`plot()`: pooled-effect line in the subtitle.** Below the existing subtitle
  line ("Random-effects model | Diversity D² | Anticipated HR = ... | ...") the
  plot now shows a second line: `Pooled HR = 0.51 [95% CI: 0.48, 0.54] | p <
  0.001 | Tau² = 0.0136 | I² = 73.3%`. The values are the ones `print()` and
  `summary()` already report (`res$res_re`, `res$heterogeneity`); nothing is
  recomputed. HR and CI use 2 decimals, tau² 4, I² 1; p-values below 0.001 are
  shown as `p < 0.001`, others with 3 decimals. The "2" in Tau² and I² is the
  Unicode superscript two, as for Diversity D². Internal helper
  `.tsahr_pooled_subtitle()`.
* **`plot()`: `endpoint_label_x`, `endpoint_label_y`, `endpoint_label_size`.**
  Position (data coordinates: cumulative events, Z-score) and font size of the
  "Analysis-route endpoint (Design_R x DARIS) reached" label, which is drawn
  only for `boundary_route = "analysis"` when the endpoint was reached. The
  defaults reproduce the previous plot exactly: the label sits just right of
  its vertical line at 58% of the upper y limit, and `endpoint_label_size =
  NULL` still follows `info_threshold_label_size` (3.2 by default). Same
  conventions as the other `*_label_x/_y/_size` arguments.
* **New bundled example datasets (breaking for anyone relying on the old file).**
  `inst/extdata/HR_meta_example.xlsx` (10 studies) is replaced by `HR_meta.xlsx`
  (20 studies) and `HR_meta_2.xlsx` (40 studies). `tsahr_example_data()` gains
  a `dataset` argument, `"HR_meta"` (default) or `"HR_meta_2"`; calling it with
  no argument now returns the 20-study file. The new sheets already use
  underscores in their headers (`Events_Treatment`, ...). Examples in the
  documentation and README use the new data.
* **Tests keep the old dataset.** Many tests pin numbers computed on the old
  10-study data (boundaries, DARIS, D2, RTSA parity, ...), so it is kept,
  unchanged, as `tests/testthat/testdata/HR_meta_legacy_10studies.xlsx` and read
  through `legacy_example_data()` (`tests/testthat/helper-data.R`); those tests
  are otherwise untouched. New tests in `test-plot-and-example-data-0.2.8.R`
  cover the two datasets (shape, columns, `tsa_hr()` and `plot()` run), the
  subtitle line and the endpoint-label arguments. No numbers are pinned for the
  new datasets.
* Version bumped to 0.2.8. No change to the boundary engine, `tsa_hr()`'s
  results or any decision field.

# tsahr 0.2.7.22

## Fixes the `spend == beta` knife-edge (low-information designs), relicenses as GPL (>= 2) with RTSA credited, and small fixes

* **`spend == beta` knife-edge fixed.** When every interim look is suppressed
  (rm_bs = nt - 1: small information fractions, "evidence still insufficient"),
  the final look carries the whole beta spend, and RTSA's exact-float shortcut
  `else if (spend == beta) za = 0` fires or not depending on the last bit of
  `beta`. RTSA is normally called with a literal `beta = 0.2`, which differs from
  its own spend arithmetic in the last bit; tsahr computes `beta = 1 - power`
  (0.19999999999999996), which equals it. When the shortcut fired, `za` was 0
  whatever the information scale, so the calibration gap was constant and the
  root search reported "no root bracket": a design that calibrates at
  power 0.8 + 1e-12 failed at 0.8 (and at 0.95; 0.9 passed), the compiled engine
  was lost and `tsa_hr()` fell back to the legacy engine (warning, banner, 12-23
  s). The shortcut is no longer ported, at the first or later looks (a
  deliberate, documented departure from RTSA; `za = 0` has no statistical
  meaning there, and it is unreachable in everything the frozen RTSA reference
  covers, so parity is unchanged). Reproduced with the compiled core on a 30-look
  schedule up to 26% of the required information: before, `beta = 1 - 0.8` and
  `1 - 0.95` failed; after, powers 0.80-0.99 and their +/-1e-12 neighbours all
  calibrate to the same root (1.0000404 at power 0.80). Tests:
  `test-robust-schedules.R` (roots by power and last-bit perturbations; an
  end-to-end low-information `tsa_hr()` run that must use the compiled engine at
  powers 0.80/0.90/0.95); `tools/cpp_vs_py.py` section 11. The legacy R engine
  keeps RTSA's shortcuts (it did not fail on the audited design; unaudited for
  other powers) and is reached only if the compiled engine fails.
  Found by an external audit of 0.2.7.21.
* **RTSA's alpha tolerance and placeholder 20 kept, on purpose.** The audit
  showed that with RTSA's absolute search tolerance of 1e-9, looks whose
  cumulative spend is below it are reported as the placeholder 20 (true values
  6.73 and 6.22 at looks 4 and 5 of a 37-look example) and the first solved look
  after them is off by 7e-3 (5.4296 vs 5.4227 at tolerance 1e-12). This is RTSA's
  behaviour and tsahr keeps it so that its bounds match RTSA's; it is now
  documented in `?tsa_hr` and pinned by a test. Reported values are unchanged.
* **Relicensed GPL (>= 2); RTSA authors credited.** The C++ engine, its R
  orchestration and the earlier R-only reconstruction are derived from RTSA
  (GPL (>= 2)) and could not be distributed as MIT. `License: GPL (>= 2)`; the
  MIT `LICENSE` file is removed; `Authors@R` credits Anne Lyngholm Soerensen,
  Markus Harboe Olsen, Theis Lange and Christian Gluud (`ctb`, `cph`);
  `Copyright: inst/COPYRIGHTS` documents provenance file by file, including RTSA's
  origin in the Copenhagen Trial Unit's TSA software and its manual's authors;
  the derived source files carry a copyright/GPL notice; README has an
  attribution section.
* **`summary_table$Value` is a character column.** It was numeric only because
  `c()` coerced logicals, so decision rows printed as 1/0. Numbers keep their
  rounding; logicals print TRUE/FALSE/NA. (Anything that used
  `summary_table$Value` numerically must convert.)
* **`%d` overflow fixed.** Event counts derived from the required information
  can exceed the integer range (e.g. `target_HR = 0.9999`); the verbose output,
  `print()` and the DARIS lines now use `%.0f`.
* `DESCRIPTION`: `ggplot2 (>= 3.4.0)` (the `linewidth` aesthetic needs it).
* README: the legacy engine was called an "opt-in" fallback; it is ON by
  default (`legacy_fallback = TRUE`). Reworded. The `rtsa_core.h` header no
  longer claims "everything is bounds-checked" (array lengths are validated on
  entry; inner loops use unchecked indexing).
* Not done here: replacing the bundled example dataset (its numbers are pinned by
  tests), and the 0.2.7.21 audit's plot-scaling suggestion (would hide RTSA's
  placeholder).

# tsahr 0.2.7.21

## Measured accuracy of the 0.2.7.19 legacy fix; corrections to its documentation; regression test

Documentation and test release for the LEGACY fallback engine. The default
compiled paths are untouched, and no shipped code path changes.

* **Measured, in R (maintainer's session), on the reference schedule
  0.25/0.5/0.75/1 (alpha 0.05, beta 0.20).** The legacy FFT alpha engine
  (`.obf_alpha_boundary()`, default `n_grid = 16000`) gives 4.332634 2.963388
  2.358980 2.012955 against live RTSA 0.2.2's 4.332634 2.963131 2.359044
  2.014090: errors 4e-7, 2.6e-4, -6.4e-5 and -1.14e-3, largest at the final
  look (the value the futility root search targets). The legacy warp root is
  1.132483 against RTSA's 1.133242 (error 7.6e-4), where before the 0.2.7.19
  fix it was 1.0972 (error 3.6e-2) -- a ~47-fold reduction. Feeding the same
  FFT alpha vector to an independent Simpson beta implementation gives root
  1.132483339, i.e. exactly what the legacy R beta code reported: the legacy
  beta engine is exact given its alpha input, and the whole residual error comes
  from the FFT alpha. One schedule only -- not a general accuracy bound for the
  fallback, which remains labelled approximate and "NOT comparable with RTSA".
  This also answers the `n_grid = 16000` question left open in the
  `.obf_alpha_boundary()` notes for this schedule (the 5-look snippet there has
  still not been run).
* **Two claims in the 0.2.7.19 documentation were wrong and are corrected**
  (here, in the 0.2.7.19 entry, and in the code comments): (1) `.obf_alpha_boundary()`
  was called "the same validated side = 2 recursion"; it is the FFT
  approximation of RTSA's Simpson recursion (error above), not a validated
  reproduction. (2) The equality "final boundary = qnorm(1 - alpha/2)" was said to
  hold "only in a continuous-monitoring limit"; it holds only for a single look.
  With more looks the final wall is larger and keeps growing (2.014 for 4 even
  looks, 2.185 for 100), which is exactly why assuming the constant was a bug.
* **Stale comments fixed:** the header above `.tsahr_legacy_boundaries()` (it
  still said the futility route substitutes `qnorm(1 - alpha/2)`), and the
  headers of the two legacy test files (they said the `qnorm(1 - alpha/2)` final
  boundary asserted in them is the legacy engine's convention; since 0.2.7.19 it
  survives only for single-look schedules and the analysis wrapper's `design_R`
  endpoint).
* **New test** (`test-rtsa-live-reference.R`): the legacy engine on the frozen
  reference schedule stays within 3e-3 of live RTSA for the alpha bounds and
  futility bounds and within 2e-3 for the warp root, and its final wall is no
  longer `qnorm(1 - alpha/2)`. The tolerances are set from the measurements above
  and separate the fixed engine (errors <= 1.14e-3) from the unfixed one (root
  3.6e-2, futility bounds 3.4e-2 to 5.4e-2 off).

# tsahr 0.2.7.20

## Finishes the 0.2.7.19 test fixes that R CMD check caught as incomplete

0.2.7.19's production fix (`.rtsa_beta_boundary()` recomputing the true,
schedule-dependent final efficacy boundary via `.obf_alpha_boundary()`
instead of assuming `qnorm(1-alpha/2)`) was correct, but two tests that
still encoded the old assumption were not actually updated in the
uploaded package, and a real `R CMD check` run caught both:

* `test-boundaries-rtsa.R`, "0.2.7.4: the information-scale root search
  actually engages and hits its target" -- `gap_ans` was checked against
  an `alpha_ref` vector whose last entry was still the stale
  `qnorm(1-alpha/2)` constant, while `ans$warp_root` (from
  `.rtsa_beta_boundary()`) was by then solving for the CORRECT,
  recomputed final value -- two different equations, so their roots no
  longer agreed (off by 0.072). Fixed by deriving `alpha_ref` from
  `.obf_alpha_boundary()`, the same recursion `.rtsa_beta_boundary()`
  itself now uses internally, so both sides check the same equation.
* `test-tsa_hr.R`, "LEGACY R-only boundary engine scales to many studies"
  -- asserted the final futility boundary equals the fixed constant 1.96
  for a 40-look schedule; the true value there is materially different
  (~2.16). Fixed by asserting against the schedule's own true final
  alpha boundary (`c40`'s own last entry, already computed earlier in
  the same test) instead of a hardcoded constant, so this test cannot
  re-encode a wrong assumption about what that value is.

**Two more tests were fixed for correctness even though `R CMD check`
did not flag them as failing**, because they were passing for the wrong
reason: `.rtsa_beta_boundary()`'s own defensive
`pmin(boundary, c_vec_alpha)` safeguard clips its (now correct, and
therefore LARGER) recomputed final boundary back down to whatever
`c_vec_alpha`'s own last entry says, so a test that still supplied the
stale, smaller `qnorm(1-alpha/2)` as `c_vec_alpha`'s last entry got that
same stale value back out of `ans$boundary` -- appearing to confirm the
old convention while actually only exercising the safety clip, not the
recomputation the test's own comment claimed to check:

* `test-boundaries-rtsa.R`, "RTSA beta boundary returns NA only for
  negligible early spend, not for every non-positive value"
* `test-boundaries-rtsa.R`, "0.2.7.5: the two-pass root search converges
  on a realistic multi-look design"

Both now derive their expected final value from `.obf_alpha_boundary()`
directly, matching the pattern the two already-fixed 0.2.7.19 tests
("RTSA retrospective inner-wedge engine has definitive alpha boundary"
and "RTSA over-powered analysis uses the true (recursion-based)
definitive boundary") already established. One further `qnorm(1-alpha/2)`
occurrence, in "0.2.7.5: a single-look schedule (DARIS already reached at
the first study) does not error", was checked and left as-is: with a
single look, RTSA's discretised recursion collapses to the ordinary
fixed-sample critical value, so `qnorm(1-alpha/2)` genuinely is the
correct value there (verified directly against the compiled engine),
not an unfixed instance of the bug. `.rtsa_beta_boundary_analysis()`'s
own, separately-disclosed use of the same constant (its harder
design_R-endpoint case) is unaffected, as previously noted.

# tsahr 0.2.7.19

## Legacy engine bug fix: `.rtsa_beta_boundary()`'s final efficacy boundary was approximated, not computed

A live RTSA cross-check caught a real bug in the LEGACY, R-only fallback
engine (`.rtsa_beta_boundary()` in `R/obf_boundaries.R`, used only when
`legacy_fallback = TRUE` and the compiled engine fails -- the default,
compiled `boundary_route = "design"`/`"analysis"` paths are NOT affected).

* **The bug.** `.rtsa_beta_boundary()` assumed "by construction of any
  properly normalised two-sided alpha-spending function, the efficacy
  boundary at `t = 1` is exactly `qnorm(1-alpha/2)`", and substituted that
  constant for the final entry of the alpha wall it root-finds the
  information-scale factor (`warp_root`) against. That assumption is wrong
  for RTSA's actual discretised O'Brien-Fleming-type spending recursion --
  the equality holds only for a SINGLE look (no earlier spending); with more looks the final wall is larger and grows with the number of looks (2.014 for 4 even looks, 2.185 for 100) -- it depends on the schedule, not on a continuous-monitoring limit. [Corrected in 0.2.7.21; this entry originally attributed the equality to a continuous-monitoring limit.] A live RTSA reconstruction
  confirmed this concretely: for one real schedule, RTSA's own final alpha
  boundary was `2.014090377368289`, not `qnorm(1-alpha/2) =
  1.959963984540054` -- a difference large enough to materially shift the
  solved root (`1.133241903483384` vs. the wrong `1.097192717591548`) and,
  through it, every futility boundary derived from that root (e.g.
  `0.632531...`/`1.404162...` vs. the wrong `0.598718...`/`1.362718...`).
  A second line (`za_seq[length(za_seq)] <- final_alpha_bound`) then
  independently re-asserted the same wrong constant onto the reported
  final futility boundary.
* **The fix.** `.rtsa_beta_boundary()` no longer approximates the t = 1
  efficacy boundary at all. It recomputes the TRUE, schedule-dependent
  value via `.obf_alpha_boundary()` -- the same side = 2 FFT recursion used everywhere else in this legacy engine (an APPROXIMATION of RTSA's Simpson recursion, not a validated reproduction of it; see 0.2.7.21) -- run on `timing_beta`
  itself (the observed pre-1 looks plus the definitive t = 1 point),
  rather than reusing whichever `c_vec_alpha` the caller happened to
  already have. This is correct and self-contained whether or not the
  caller's `t` already contains an exact t = 1 entry, and the previously-
  separate `za_seq[...] <- final_alpha_bound` override line is now
  harmless (it re-asserts the same, now-correct value the root search
  already converges to) rather than removed, since the bug was in what
  `final_alpha_bound` held, not in tightening to it.
* **Scope.** `.rtsa_beta_boundary_analysis()` (the legacy engine's
  retrospective-analysis path) calls the now-fixed `.rtsa_beta_boundary()`
  internally for its own `design_R` calibration, so that part is fixed
  automatically. Its own, separate `qnorm(1-alpha/2)` approximation for
  the `design_R` endpoint's alpha value (a materially harder problem,
  since `design_R` essentially never coincides with an observed look, and
  a correct fix requires porting RTSA's `type = "analysis"` alpha
  recursion rather than reusing the `type = "design"` one) is UNCHANGED
  and remains a disclosed approximation -- consistent with this engine's
  existing "NOT comparable with RTSA" warning whenever it is actually
  used.
* Two tests in `test-boundaries-rtsa.R` that had encoded the old, wrong
  `qnorm(1-alpha/2)` convention as correct behaviour are corrected to
  check against a direct `.obf_alpha_boundary()` recomputation instead
  (which is what the fixed function now does internally), and to assert
  that the true value differs materially from the old approximation --
  regression protection against reintroducing this exact bug.
* **Validation status.** The `2.014090377368289`/`1.133241903483384`
  figures above are taken directly from the live RTSA reconstruction that
  reported this bug; they were not independently re-run in the environment
  that made this fix (no R interpreter available here). The corrected
  formula is a direct, minimal port of the same `.obf_alpha_boundary()`
  call already used and validated elsewhere in this file.

# tsahr 0.2.7.18

## Wording and provenance corrections (no numerical change)

Documentation/diagnostic-text release following the 0.2.7.17 assessment. No
boundary value, root, test reference or code path changes.

* **"Exact" reachability was too strong.** The beta-search reachability test is
  `qmax < target - tol` (`tol = 1e-15`, plus floating-point summation error): the
  classification is decided directly from the analytic limit `qmax = sum(last)`,
  up to the numerical tolerance, not mathematically exactly. Reworded in
  `src/rtsa_core.h`, `R/rtsa_engine.R`, `inst/REVERSE_ENGINEERING_RTSA.md` and
  the 0.2.7.15/16 NEWS entries.
* **Grid-collapse wording made accurate.** The reversed-interval warning said the
  interval was "replaced by a degenerate window"; the C++ widens an interval with
  no positive width to the minimal NON-ZERO window `[lo, lo + 1e-8]`, and the
  warning now says so. While checking this I found the collapse warning's "each
  was widened automatically" was also inaccurate: only intervals with no positive
  width are widened; a zero-width two-node grid is merely counted (arithmetic
  unchanged) and a collapsed grid whose interval already has positive width is
  used as is. The warning and the `z_n_w()` header comment now describe exactly
  that.
* **Look-spacing evidence claims softened.** "Silently wrong" is replaced by
  "numerically unreliable" in the warning text, code comments, NEWS and notes,
  with the caveat that the 0.25% threshold rests on measurements on even
  schedules and one close-pair family (r = 18 vs r = 72), not on a systematic
  benchmark of the failure region.
* **Fixture provenance.** `inst/extdata/rtsa_0.2.2_reference.R` now records the
  maintainer's R version and platform (R 4.6.1 (2026-06-24 ucrt),
  x86_64-w64-mingw32), flagged for correction if the RTSA run was made in a
  different session.
* **Stale heading.** `inst/REVERSE_ENGINEERING_RTSA.md` "Current implementation"
  heading now spans 0.2.7.11 - 0.2.7.18.

# tsahr 0.2.7.17

## Frozen live-RTSA reference: the compiled engine is compared with RTSA 0.2.2's own output

The open item from 0.2.7.12 onward is closed for the case supplied. Numbers
printed by RTSA 0.2.2 itself (`RTSA::boundaries()`, timing 0.25/0.50/0.75/1.00,
alpha 0.05, beta 0.20, side 2, non-binding, esOF) are frozen in
`inst/extdata/rtsa_0.2.2_reference.R` (provenance and call shapes documented in
the file) and tested in `tests/testthat/test-rtsa-live-reference.R`, which does
not need RTSA to be installed.

* **Design route.** Root 1.133241903483384 reproduced to 2e-16; alpha bounds to
  2e-15; beta bounds `NA, 0.63253131244591, 1.40416178814087, 2.01409037736827`
  to 2e-16 (including the two-pass root search and the suppressed first look);
  beta spend vectors (`bs_cum`, `bs_incr`) to 1e-9.
* **Analysis route (RTSA's own call).** Alpha bounds to 2e-15 (they differ from
  the design-route alpha at the 5e-8 level, and RTSA reports that); beta bounds
  reproduced EXACTLY (difference 0.0), including the appended fifth look.
* **Call-shape support.** RTSA's `boundaries(type = "analysis")`, given a timing
  that stops short of `design_R`, appends `design_R` to the information scale, so
  the beta timeline has one more look than the alpha bounds it is handed (RTSA
  silently recycles them; the harmless "zb * info$sd_proc" warning in the
  reference run). The C++ `beta_boundary()` now accepts exactly that shape
  (design-R mode, alpha bound one element short, padded with NaN at the appended
  look, never read); every other length mismatch is still an error.
  `.rtsa_analysis_bounds()` accepts the unextended timing, and its interior
  "reaches the efficacy wall" check now counts looks from the beta timeline
  rather than from the input timing.
  `RTSA()`'s own internal call (timing already extended with `design_R`) is what
  `tsa_hr(boundary_route = "analysis")` uses; it is covered by the design-R
  parity tests and by the Python port, but is not frozen live.
* **What this does and does not establish.** It is the first comparison of the
  package with RTSA's own output rather than with a reconstruction of RTSA, and
  it agrees to machine precision on a small schedule for both routes. It does not
  cover many-look schedules, `rm_bs` > 1, or the extended-timing analysis call.
  `tools/cpp_vs_py.py` section 10 repeats the comparison without R.
* `inst/REVERSE_ENGINEERING_RTSA.md`: "Validation status" rewritten around
  this.

# tsahr 0.2.7.16

## Exact reachability test for beta searches; finite-input checks; sentinel and threshold documentation; the random-schedule check is now shipped

Hardening release. The alpha/beta mathematics and every pinned reference value
are unchanged (the compiled core still agrees with the Python port to ~1e-14 and
all schedules in `tools/cpp_vs_py.py` give the same roots).

* **"Unreachable beta target" is now decided directly from the analytic limit
  (up to the numerical tolerance).** 0.2.7.15 inferred it
  from `qout < as` where an unconverged search happened to stop, which is not a
  proof: a reachable target the search merely failed to find would also end
  below the target. As the boundary goes to +Inf every `Phi(...)` in `prob()`
  tends to 1, so the largest spend any boundary can produce at a look is
  `qmax = sum(last)`, the probability mass still alive. `searchfunc()` now
  compares the target with `qmax` BEFORE iterating: target > `qmax` ->
  `SearchUnreachable` (`qmax < target - tol`, tol = 1e-15; immediate instead of
  400 rounds);
  otherwise a search that fails to converge beyond the loose tolerance is a hard
  error, never "beyond the wall". (An instrumented run over 303 schedules found
  the old inference never misclassified -- 171 unreachable declarations, none
  with `qmax >= target` -- so this makes the claim provable rather than
  fixing an observed fault.)
* **Sentinel documented.** From `unreachable_look` onward the raw `za` is the
  deliberately non-physical `zb + 1`, an encoding of "beyond the efficacy wall"
  for the sign of the root-search gap -- never a boundary. Stated in
  `BetaOut`, `.rtsa_beta_cpp()` and on `.rtsa_analysis_bounds()`'s raw `za`
  (only `beta_ubound` is meaningful), and asserted by a test.
* **Finite checks.** `.rtsa_alpha_cpp()`, `.rtsa_design_bounds()`,
  `.rtsa_analysis_bounds()` and `.rtsa_beta_cpp()` now reject `Inf`, `-Inf`
  and `NaN` (`!is.finite()`), not only `NA`; `anyNA()` let `Inf` reach the
  compiled recursion, which then returns garbage.
* **Look-spacing threshold wording.** The 0.25% level is described everywhere
  as an empirical warning threshold for this implementation's default grid
  (r = 18 vs r = 72), not as an RTSA rule (RTSA refuses design timings adding
  < 1% and drops such looks in `RTSA()`).
* **The 300-random-schedule check is now in the archive.** 0.2.7.15's NEWS cited
  it, but it only existed in a development sandbox. `tools/cpp_vs_py.py`
  section 9 (fixed seed, 3-45 looks) now reproduces "300 of 300 calibrate";
  section 8 checks the reachability classification (converged / unreachable /
  hard error). Both are standalone (no R) -- they are not part of the R test
  suite, and the "186 of 300 under the 0.2.7.13/14 behaviour" figure in the
  0.2.7.15 entry was measured on that older build, which is not shipped.
* Tests: finite-input rejection, sentinel layout, and the threshold wording.
* Not changed / still open: a frozen reference generated by the live RTSA
  package (design and analysis routes; needs `packageVersion("RTSA")`).

# tsahr 0.2.7.15

## Fixes a regression in 0.2.7.13/14 (design-route calibration failing on many schedules), adds regression tests and a look-spacing diagnostic, and separates current from historical documentation

* **Regression fixed: strict search convergence broke the design-route root
  search.** 0.2.7.13 made `searchfunc()` throw when a search could not converge.
  During the information-scale root search that routinely happens at the upper
  edge of a bracketing window: the futility spend asked for at a look exceeds
  the probability mass still alive, i.e. the futility bound would lie BEYOND the
  efficacy wall. The candidate aborted, the bracket window slid on, no sign
  change was ever found ("no root bracket"), and `tsa_hr()` fell back to the
  legacy engine (or errored with `legacy_fallback = FALSE`). Measured with the
  compiled core through the design-route orchestration: 114 of 300 random
  3-45-look schedules failed, and so did a real 37-look (40-study, target HR
  0.94) schedule and 100 evenly spaced looks; 0.2.7.12's silent cap-and-accept
  succeeded on them only because the returned junk value happened to have the
  right sign, and returns junk elsewhere.
  Now an unreachable beta target is reported as such
  (`BetaOut::unreachable_look`, exception `SearchUnreachable`): from that look on
  the futility bounds are set to `zb + 1` ("beyond the wall"), so the final gap
  the root search works on is NEGATIVE -- the right sign -- and the search
  continues. All 300 random schedules and the schedules above now calibrate, with
  the same roots as before where 0.2.7.12 succeeded (e.g. 37-look schedule: root
  1.2278, 14 suppressed early looks, matching the printed 0.2.7.12 results to
  every digit). (The random-schedule figures come from a standalone harness, not
  from the R tests; `tools/cpp_vs_py.py` section 9 reproduces the 300-schedule
  calibration for the current build -- added in 0.2.7.16.)
  Safeguards: a CONVERGED calibration pass must never be unreachable and its
  residual final gap (futility vs efficacy at t = 1) is re-verified
  (`.rtsa_check_converged_pass()`); in the analysis route an unreachable FINAL
  look is handled by RTSA's own final clamp (`beta_ubound[last] >
  alpha_ubound[last]`) and flagged (`final_beyond_wall`), while an interior one is
  an error. Genuine non-convergence (target reachable but not found) still throws.
  Root-search failures now report the last real engine error instead of only
  "no sign change".
* **New look-spacing diagnostic.** RTSA refuses `type = "design"` timings that
  add < 1% of the required information and drops such looks in `RTSA()`; tsahr
  keeps every study. Measuring the default grid (r = 18 vs r = 72) shows the
  recursion is accurate for even schedules down to increments of ~0.5% (error
  <= 6e-4), for a single close pair down to ~0.25%, and numerically unreliable
  below that (500 even looks: final wall 11.7 vs 2.216; one extra look 0.0005
  after another: error 6e-3 -- measurements on even schedules and one close-pair
  family, not a systematic benchmark of the failure region). `tsa_hr()` now WARNS (does not alter the schedule; the 0.25%
  level is an empirical threshold for this implementation's grid, not an RTSA
  rule) when the
  increment between looks is < 0.25% of the required information
  (`.rtsa_check_look_spacing()`). Merging near-simultaneous studies, as RTSA()
  does below 1%, is left as a decision for the user.
* **Tests.** New `test-robust-schedules.R`: real 37-look schedule (values checked
  against a real 0.2.7.12 printout), 50/100 even looks, dense-at-start,
  dense-at-end, tiny first fraction, many early looks (pinned root / `rm_bs` /
  final wall); unreachable candidates (final and interior) give a negative gap
  and are flagged; converged-pass checks; root-search error message; the
  analysis-route final clamp vs interior error (mocked); the spacing diagnostic.
  `tools/cpp_vs_py.py` (section 7) reproduces the design-route calibration on
  these schedules without R.
* **Documentation.** `inst/REVERSE_ENGINEERING_RTSA.md` is split into
  "Current implementation (0.2.7.11-0.2.7.15)" and a clearly marked
  "HISTORICAL" part; the three statements that had become false (final boundary
  set directly to `qnorm(1 - alpha/2)`, "tsahr has no compiled-code
  dependency", "no compiled code was needed") are marked superseded. Test files
  that exercise the legacy R-only engine (`.obf_*`, `.rtsa_beta_boundary*`) now say
  so at the top and where they assert `qnorm(1 - alpha/2)`.
* Not changed / still open: a frozen reference generated by the live RTSA
  package (design and analysis routes; needs `packageVersion("RTSA")`);
  schedules with looks closer than ~0.25% of the required information are only
  warned about, not repaired.

# tsahr 0.2.7.14

## Definitive-look decision fields, DARIS vs analysis-route endpoint, fallback bookkeeping, and a separate reversed-grid diagnostic

Implements four items from the 0.2.7.13 audit. The alpha/beta mathematics is
untouched: the compiled engine still agrees with the Python port
(`tools/cpp_vs_py.py`) to ~1e-14 and reproduces the same reference vectors.

* **`final_non_efficacy` fixed (was a semantic bug).** 0.2.7.13 defined it as
  `!crossed_tsa`, but `crossed_tsa` means "crossed at ANY formal look", so a
  trial that crossed efficacy at an interim look and then fell back below the
  boundary at the definitive look reported `final_non_efficacy = FALSE`.
  New definitive-look fields refer to `results$final_tsa_look` only:
  `final_crossed_efficacy`, `final_non_efficacy` (= `!final_crossed_efficacy`)
  and `final_entered_futility_region`. All three are `NA` when the route
  endpoint has not been reached (there is no definitive look then).
  `crossed_tsa` and `entered_futility_region` are unchanged and remain the
  "at any formal look" versions. Logic lives in the tested helper
  `.tsahr_definitive_look()`; `summary_table` gained the matching rows and
  relabelled the "at any formal look" ones; `?tsa_hr` documents both families.
* **Analysis-route endpoint no longer labelled "DARIS".** With
  `boundary_route = "analysis"` the formal endpoint is `design_R * DARIS`.
  DARIS itself and the route endpoint are now kept apart:
  `results$daris_reached` and `information_size$DARIS_info_threshold_events`
  always refer to DARIS (t = 1); `results$final_reached`,
  `information_size$route_endpoint_info` and `route_endpoint_events` refer to
  the route endpoint (identical to DARIS for `"design"`, so the default route
  is unchanged). The verbose output, `print()`, `summary_table` and `plot()`
  call it "analysis-route endpoint (x.xxx x DARIS)" and draw it as its own
  marker; the not-yet-reached fallback endpoint is the event-equivalent of
  `design_R * DARIS`, not of DARIS. The interpolation moved to
  `.tsahr_events_at_fraction()` (identical arithmetic for t = 1).
* **`settings$fallback_used`, `fallback_route`, `fallback_reason`,
  `route_used`.** `fallback_route` is `"none"`, `"design"` (analysis route
  failed; the RTSA-derived design-route result is returned) or `"legacy"`
  (RTSA-derived engine failed; approximate legacy engine). `route_used` is
  `"design"`, `"analysis"` or `"legacy"`; `boundary_route` still records what
  was requested. `print()`/`summary()` also flag the design-route fallback.
  The fallback paths are now covered by mocked-failure tests.
* **Reversed integration interval is diagnosed separately, not thrown.** In
  `z_n_w()`, a REVERSED interval (lower wall above the upper wall, za > zb)
  is now counted in its own `Diagnostics::grid_reversed` -- no longer folded
  into `grid_collapses` -- and surfaced by its own, louder warning ("NOT a
  valid RTSA computation ... must not be trusted or reported as
  RTSA-equivalent"). It deliberately does NOT throw: `z_n_w()` also runs at
  every candidate information scale tried by the root searches, where an
  interior look can be transiently reversed at a bad candidate without the
  search (which targets the final look) being unable to continue and
  converge; erroring there would turn recoverable searches into failures.
  Also counted now: an exactly zero-width two-node grid (za == zb), as a
  degenerate `grid_collapses` (arithmetic unchanged).
  Because of the same transient-candidate argument, the root searches'
  candidate evaluations no longer emit diagnostics warnings (`warn = FALSE`
  in `.rtsa_beta_cpp()`); the converged passes always do, so a persistent
  problem at the accepted root is still reported.
* Wording: `DESCRIPTION`/`README.md` now say "no fixed software-imposed limit
  on the number of looks, subject to available computational resources"; the
  README bullet describing the engine now describes the compiled RTSA-derived
  engine (the R-only engine is the opt-in fallback).
* Not changed / still open: a frozen live-RTSA reference file in
  `inst/extdata` (needs one run of the real RTSA 0.2.2 calls -- design and
  analysis -- with `packageVersion("RTSA")`), and the information-scale
  convention (unchanged, as argued in 0.2.7.12/13).

# tsahr 0.2.7.13

## Acted on the 0.2.7.12 audit: strict search convergence, a grid-collapse diagnostic, clearer final-look wording, an opt-in strict-fail mode, and an opt-in RTSA analysis-route

This release implements the five actioned points of the 0.2.7.12 audit, plus
an opt-in `boundary_route` argument the audit recommended over changing the
default. Two audit points were declined, with reasons (see below).

* **`searchfunc()` now errors on genuine non-convergence
  (`src/rtsa_core.h`).** Previously, hitting the (disclosed, RTSA-diverging)
  400-round iteration cap silently returned whatever value the search had
  reached. It now checks the residual against a loose tolerance
  (`kLooseSearchTol = 1e-6` -- far coarser than the 1e-9/1e-15 convergence
  tolerances the recursion itself runs at, so it does not reject harmless
  floating-point noise on an otherwise-converged search): within it, the
  value is accepted and counted as having taken the "slow path"
  (`Diagnostics::slow_searches`); beyond it, `searchfunc()` throws
  `std::runtime_error`, which surfaces as a real R error. RTSA's own
  `while(cond)` loop has no cap and would simply never terminate in this
  situation, so erroring here is stricter than RTSA, not a departure from
  it -- unlike returning a value RTSA's own algorithm would never have
  produced.
* **Grid-collapse counter, surfaced as a warning (`z_n_w()`).** The
  degenerate-interval widening (a disclosed departure from RTSA, which
  errors here) is now counted (`Diagnostics::grid_collapses`) rather than
  passed through silently.
  Both diagnostics are threaded through `alpha_boundary()`/`beta_boundary()`
  into `AlphaOut`/`BetaOut`, returned from the compiled entry points
  (`rtsa_alpha_boundary_cpp()`/`rtsa_beta_boundary_cpp()`), and turned into
  immediate R warnings by every call site in `R/rtsa_engine.R`
  (`.rtsa_warn_diagnostics()`), each naming which boundary/pass triggered
  it (e.g. "the analysis-route beta (futility) boundary (pass 2)").
* **`results$final_non_efficacy`.** Because the futility and efficacy
  boundaries are calibrated to meet exactly at the definitive final look,
  `entered_futility_region` restricted to that look is, in practice, the
  complement of `crossed_tsa`. `final_non_efficacy <- !crossed_tsa` names
  that explicitly, and the "entered_futility_region is not a stopping rule"
  documentation under `?tsa_hr` is strengthened accordingly. Added to
  `results` and to `summary_table`.
* **Wording.** "No limit on the number of included studies" (`DESCRIPTION`,
  `README.md`) and "no artificial limit on the number of looks" (a comment
  in `R/tsa_hr.R`) are now uniformly "no fixed software limit on the number
  of looks" -- the previously-stated claim was stronger than the package
  actually guarantees.
* **`legacy_fallback` argument, default `TRUE`.** Governs what happens when
  the compiled RTSA-derived engine fails to produce a result. `TRUE`
  (unchanged default) falls back to the legacy, pre-0.2.7.11 R-only
  approximate engine, with an immediate warning and a console/print/summary
  banner -- a caller wrapping the call in `suppressWarnings()` will still
  see the banner in `print()`/`summary()` output and the
  `beta_engine$engine == "legacy_r_fallback"` flag, but not the warning
  itself. `legacy_fallback = FALSE` instead makes `tsa_hr()` `stop()` with
  an error, appropriate when a silently-substituted, non-RTSA-comparable
  result would be worse than a hard failure. Applied both to the (always-run)
  design pass and, separately, to the analysis pass when
  `boundary_route = "analysis"` (whose fallback target is the already-
  computed design-route result, not the legacy R engine, since the legacy
  engine has no analysis-route equivalent).
* **`boundary_route = c("design", "analysis")` argument, default
  `"design"` (unchanged default, per the audit's recommendation not to
  switch it).** `"analysis"` runs RTSA's real
  `RTSA(type = "analysis", design = NULL)` route
  (`.rtsa_analysis_bounds()`/`.rtsa_retrospective()`, already implemented
  in 0.2.7.11 but not previously wired into `tsa_hr()`): a design pass
  first solves an inflation factor `design_R`, and the alpha/beta
  boundaries actually reported are recomputed on the timeline scaled by
  it. This is more than swapping the futility numbers -- the formal
  endpoint moves from `DARIS` to `design_R * DARIS`, so `final_reached`,
  the interpolated DARIS-threshold event count, `boundary_timeline`'s
  synthetic endpoint, and every decision-layer field in `results` are now
  computed relative to a new `route_endpoint` variable (`1` for
  `"design"`, `design_R` for `"analysis"`) rather than the previously
  hard-coded `1`. `settings$boundary_route`/`settings$route_endpoint` in
  the returned object record which was used. Both routes share the same
  compiled recursion; only the orchestration differs, matching RTSA's own
  two code paths.

## Declined audit points (with reasons)

* **Making the legacy-fallback default `FALSE`.** The audit's
  `suppressWarnings()` scenario is real, but the visible `print()`/
  `summary()` banner and the `beta_engine$engine` flag remain even then.
  Per direction, the compromise is the new `legacy_fallback` argument
  above (default `TRUE`, i.e. the existing behaviour kept) rather than a
  default change.
* **Random-effects information scale (option C, `sum(1/(SE^2 + tau^2))`).**
  Not changed: DARIS already inflates the required information by the
  diversity factor `1/(1-D^2)`, so accruing information on the *same*
  (heterogeneity-inflated) scale it is compared against is the standard
  TSA convention, not an inconsistency; option C would likely double-count
  heterogeneity. The limitation remains documented, not fixed, per this
  release's direction.

# tsahr 0.2.7.12

## Final futility bound now equals the final efficacy bound (as in RTSA); louder legacy fallback; cleanup

* **Final-look futility boundary.** `beta_final` is now the final efficacy
  bound (RTSA's design pass makes the futility bound meet the efficacy bound at
  t = 1). Versions 0.2.6.x-0.2.7.11 used `min(qnorm(1 - alpha/2), final
  efficacy)` (1.96 at alpha = 0.05). Consequence: at the definitive look,
  `results$entered_futility_region` is TRUE exactly when the cumulative Z-curve
  did not reach the final efficacy boundary. Pre-DARIS bounds are unchanged.
  Docs (`?tsa_hr`) and `test-daris-futility-stop.R` updated.
* **Legacy fallback kept, made impossible to miss.** If the RTSA-derived
  engine errors, `tsa_hr()` still falls back to the pre-0.2.7.11 R-only engine,
  but now emits an immediate warning and (if `verbose`) a console banner;
  `print()`/`summary()` repeat it; the result is flagged
  (`res$beta_engine$engine == "legacy_r_fallback"`, `engine_error`).
* **Wording.** "RTSA-exact" is no longer used: `tsa_hr()` runs RTSA's
  `type = "design"` route on the observed information fractions (DARIS =
  t = 1). RTSA's retrospective chain (design pass -> design_R -> analysis pass)
  exists internally (`.rtsa_retrospective()`) but is not used by `tsa_hr()`;
  the analysis route also changes the efficacy bounds (alpha recomputed on
  t / design_R).
* Cleanup: `.Rbuildignore` now excludes all of `tools/`; internal helper
  `.rtsa_na_to_null()` renamed `.rtsa_null_to_na()` (it converts NULL to NA);
  `importFrom(Rcpp, sourceCpp)` is deliberately kept (it is what keeps
  `R CMD check` from flagging `Rcpp` in `Imports` as unused).
* New tests: final futility == final efficacy == RTSA design-pass final bound;
  fallback is loud and flagged.

# tsahr 0.2.7.11

## Compiled RTSA-derived boundary engine; the final efficacy wall gap closed

**The package now needs a C++ compiler** (`NeedsCompilation: yes`, `Rcpp`).

### What was wrong

Numerical comparison against a Python port of RTSA 0.2.2's R sources (which
reproduces RTSA's published futility-vignette output: SMA timing
0.541/0.812/1.083, futility 0.332/1.292/2.014) traced the reported "beta
bounds far from RTSA" symptom to orchestration, not to the C++ kernels
(`init_int`/`recur_int`/`prob` were already term-for-term equal; `first`,
`other`, `fcab`, `qpos`, `trap` are never called from any RTSA R file and are
not needed):

1. **Final efficacy wall.** RTSA root-finds the information-scale factor
   (`root`) so the futility bound meets the efficacy bound at t = 1, where
   that efficacy bound is the value of RTSA's alpha recursion at t = 1
   (2.127 for the 9-look schedule 0.461 ... 0.961, 1). tsahr <= 0.2.7.10
   used `qnorm(1 - alpha/2)` = 1.96 instead: root 1.1517 instead of
   1.2107, first-look bound 0.479 instead of 0.531, and so on.
2. **Alpha engine.** tsahr's FFT alpha engine is an approximation of
   RTSA's Simpson recursion (its own notes quote errors up to ~0.006), which
   also enters the futility recursion as the fixed upper wall.
3. **Route mix-up in 0.2.7.7-0.2.7.10.** The RTSA `type = "analysis"` route
   was run against alpha bounds computed for the *design* timeline; RTSA
   recomputes them on `t / design_R` for that route. More importantly, the
   RTSA futility numbers used as the reference for these fractions are the
   `type = "design"` route's (reproduced to 4 decimals), not the analysis
   route's (which gives ~0.13 ... 1.46 for the same fractions).

### What changed

* New `src/rtsa_core.h`, `src/rtsa_engine.cpp`, `src/RcppExports.cpp`,
  `R/RcppExports.R`: end-to-end C++ port of RTSA's `alpha_boundary()`,
  `beta_boundary()`, `z_n_w()`, `searchfunc()`, `esOF()`, `sd_inf()` and
  the three used `first.cpp` functions. Calls `R::dnorm/pnorm/qnorm`.
  Disclosed differences from RTSA: `searchfunc()` has an iteration cap
  (RTSA converges in <= 9 rounds), and a collapsed integration grid is
  widened instead of erroring.
* New `R/rtsa_engine.R`: `.rtsa_design_bounds()` (RTSA
  `boundaries(side = 2, futility = "non-binding", type = "design")`),
  `.rtsa_analysis_bounds()` (`type = "analysis"`) and `.rtsa_retrospective()`
  (`RTSA(type = "analysis", design = NULL)` chain), all using `stats::uniroot`
  as RTSA does.
* `tsa_hr()` now takes alpha bounds and pre-DARIS futility bounds from
  `.rtsa_design_bounds()` on the (t < 1, 1) timeline. If that engine errors
  it falls back, with a warning, to the pre-0.2.7.11 R-only engine
  (`.tsahr_legacy_boundaries()`).
* `res$beta_engine` now carries `engine = "rtsa_design_cpp"`, `root`,
  `warp_root`, `rm_bs`, `beta_ubound`, `boundary`.
* Tests: `test-rtsa-engine-parity.R` (reference values from a Python port of
  RTSA's R sources, `tools/rtsa_port.py`; optional live comparisons against
  RTSA when it is installed); `test-daris-futility-stop.R` and the 0.2.7.7
  `beta_engine` test updated.
* `RTSA` added to `Suggests` (used only by the `skip_if_not_installed("RTSA")`
  parity tests).

# tsahr 0.2.7.10

## Reverts the 0.2.7.9 regression: `design_R` calibration was switched to the wrong RTSA branch

0.2.7.9 changed `.rtsa_beta_boundary_analysis()`'s `design_R`/`delta`/
`rm_bs` calibration from a `side = 2`, `futility = "non-binding"` basis
to a `side = 1`, `futility = "none"`, `right_power()`-based one, on the
strength of an external "live RTSA 0.2.2 reconstruction" that reported
different numbers (`delta = 2.486475`, `design_R = 1.057434`,
`rm_bs = 0`) than 0.2.7.7/0.2.7.8 produced
(`delta = 2.801585`, `design_R = 1.151571`, `rm_bs = 5`).

**That reconstruction queried the wrong branch of RTSA's source.**
Re-reading RTSA's own top-level `RTSA()` wrapper (`R/RTSA.R`), not just
`boundaries()` in isolation, shows the internal call that manufactures
`design_R` when no design object is supplied uses `side = side,
futility = futility` -- `RTSA()`'s *own* top-level arguments (`side =
2`, `futility = "non-binding"` for this package's design), not
hardcoded `side = 1`/`futility = "none"`. The correct calibration is
therefore exactly `.rtsa_beta_boundary()`'s existing two-pass
`warp_root` search (`side = 2`, `futility = "non-binding"`,
`type = "design"`) -- what 0.2.7.7 already used.

* **`design_R`, `delta`, and `rm_bs` reverted to the 0.2.7.7/0.2.7.8
  calculation**, now with the source of that calculation directly
  cited against `R/RTSA.R`'s exact lines rather than an unverifiable
  external reconstruction. `.rtsa_beta_boundary_analysis()` again
  calls `.rtsa_beta_boundary()` for `design_R`, uses
  `delta = abs(qnorm(alpha/2) + qnorm(beta))` (side = 2, matching this
  package's own alpha engine), and runs the 3-pass `rm_bs`
  fixed-point iteration RTSA's own `side == 2` analysis branch uses.
* The `side = 1`/`futility = "none"`/`right_power()` functions 0.2.7.9
  added (`.rtsa_design_R()`, `.rtsa2_alpha_boundary_design_side1()`,
  `.rtsa2_esOF()`, `.rtsa2_ma_power_upper()`, `.rtsa2_right_power()`)
  are removed rather than left in as dead code.
* **This also fixes the "early negative futility bounds shown instead
  of `NA`" symptom**, without any separate display-layer change.
  RTSA's own `boundaries()` converts every look pinned at the `+/-20`
  sentinel (suppressed by `rm_bs`) to `NA`; with 0.2.7.9's `rm_bs`
  fixed at `0`, that sentinel was essentially never hit, so early
  looks surfaced as small genuine finite negative numbers instead.
  `tsa_hr()` has no NA-hiding logic beyond what
  `.rtsa_beta_boundary_analysis()` returns, so restoring the correct
  `rm_bs` iteration restores the correct `NA`s.
* **No compiled C++/Rcpp code was added, and none is needed.** A
  line-by-line comparison of tsahr's R port
  (`.rtsa2_init_int()`/`.rtsa2_recur_int()`/`.rtsa2_prob()`) against
  RTSA's actual `src/first.cpp` shows they already match exactly, term
  for term. RTSA's own R code only calls three of `first.cpp`'s eight
  exported functions (`init_int`, `recur_int`, `prob`) -- the rest
  (`first`, `trap`, `fcab`, `other`, `qpos`) are unused/orphaned. All
  three functions that are used call `R::dnorm()`/`R::pnorm()`
  internally, which is the identical Rmath C library `stats::dnorm()`/
  `stats::pnorm()` call from R -- there is no floating-point gap
  between the two, compiled or not. The "beta bounds too small"
  symptom was fully explained by the `design_R`/`delta`/`rm_bs`
  regression above.
* Test file `test-boundaries-analysis-rtsa.R` updated to assert the
  reverted (correct) behaviour instead of 0.2.7.9's; a new test
  confirms sentinel-suppressed looks come back as `NA`.
* `inst/REVERSE_ENGINEERING_RTSA.md` rewritten to document this
  regression-and-revert plainly, including the exact `R/RTSA.R` lines
  that settle the side/futility question, so this mistake is not
  repeated from an unverifiable external claim again without checking
  the top-level wrapper first.

# tsahr 0.2.7.9

## Post-`R CMD check` patch: `design_R` root search now filters out-of-range info fractions before searching, matching RTSA exactly

A live `R CMD check`/`devtools::test()` run against this fix (on real
data, including the package's own bundled example dataset, which
reaches an `info_fraction` of 1.50 at its last study) surfaced two
further problems in the brand-new `.rtsa_design_R()`, both now fixed:

* **`uniroot()` bracket failure on any real, over-powered dataset**
  (`"f() values at end points not of opposite sign"`, raised from
  every non-trivial call to `tsa_hr()`, including the package's own
  example and every affected test). Root cause: `.rtsa_design_R()` was
  extending the *raw* observed information fractions with a final `1`
  when needed, but never removed fractions that already **exceed** 1.
  Retrospective meta-analyses routinely overshoot the required
  information size at their last look or two -- but RTSA's own source
  does not merely cap that overshoot; it **drops** every such look
  outright before the design_R search (`R/RTSA.R`:
  `if (max(timing) > 1) { timing <- timing[timing <= 1] }`). Passing
  fractions greater than 1 into the `side = 1` alpha-spending recursion
  broke its monotonicity in the info-scale factor badly enough that
  the search bracket `[0.9, 1.2]` no longer contained a sign change.
  Fixed by filtering to `t[t <= 1]` before extending with the final `1`,
  exactly mirroring RTSA's own line.
* **All-over-informed edge case.** When *every* observed look already
  exceeds the required information size (extreme over-powering from
  the very first study -- exercised by this package's own
  `test-boundaries-analysis-rtsa.R` "over-powered single early look"
  test), the filtered set above is empty and there is no sub-design_R
  data left to calibrate a power root from at all. RTSA's own source
  has a sanctioned value for exactly this situation --
  `if (power_adj == FALSE) design_R <- 1` -- and `.rtsa_design_R()` now
  falls back to it, letting the existing `t > design_R` "over-power"
  routing in `.rtsa_beta_boundary_analysis()` correctly send every one
  of those looks straight to the definitive final boundary (as it did
  before this release), rather than raising an error.
* No change to the `delta`/`design_R`-derivation *method* itself, the
  single-pass `rm_bs = 0` beta calculation, or the alpha engine -- only
  to what timing values are allowed into the design_R search.
* All 31 previously-failing `testthat` cases (surfaced by the
  `devtools::test()` run that caught this) exercise a path through
  `.rtsa_design_R()`; this patch is expected to resolve them. No
  further test files were changed for this patch beyond the fixes
  already made for the original three bugs described below.

## Beta/futility engine now matches RTSA's real `type = "analysis"` design_R and drift calibration

* **Three confirmed bugs in the 0.2.7.7/0.2.7.8 `.rtsa_beta_boundary_analysis()`
  beta-futility engine, found by a direct numerical comparison against a
  live RTSA 0.2.2 `type = "analysis"` reconstruction on real data, are
  fixed:**
    1. **`delta` used the wrong side.** RTSA's `type = "analysis"`
       branch is reached from inside `boundaries()`'s `side == 1`
       code path, where the fixed theoretical drift is
       `abs(qnorm(alpha/side) + qnorm(beta))` evaluated at `side = 1`
       (i.e. plain `alpha`) -- `0.2.486475` for `alpha = 0.05, beta =
       0.20`. The previous code hard-coded `abs(qnorm(alpha/2) +
       qnorm(beta))` (the *design engine's* `side = 2` drift), giving
       `2.801585` instead -- about 13% too high, and the root cause of
       every downstream discrepancy below.
    2. **`design_R` was calibrated from the wrong branch.** When no
       `design_R` is supplied, RTSA's own `RTSA()` wrapper
       manufactures one via a *separate*
       `boundaries(timing = <observed, extended to 1>, side = 1,
       futility = "none", type = "design")` call -- a single
       power-only `uniroot(right_power, ...)` search against a dummy
       lower bound. The previous code instead called
       `.rtsa_beta_boundary()`, which implements a *different* branch
       (`futility = "non-binding"`, a two-pass `warp_root`/inner-wedge
       search) -- the right engine for prospective *design* work, but
       the wrong one for calibrating `design_R` for a retrospective
       analysis. This alone produced a `design_R` about 8-9% too high
       in the case checked (`1.151571` vs. the correct `~1.057434`),
       which shifted every futility boundary derived from it. Fixed by
       adding `.rtsa_design_R()` (and its supporting port of RTSA's
       `alpha_boundary(..., side = 1, type = "design")` and
       `right_power()`/`ma_power()`, reusing the same
       Simpson's-rule integration primitives already ported for the
       futility engine) and calling it instead.
    3. **A spurious `rm_bs` early-look-suppression loop.** The
       previous code ran RTSA's *side = 2* non-binding-futility
       `type = "analysis"` pattern (three passes of `beta_boundary()`,
       re-deriving `rm_bs` -- the count of early looks whose beta
       spend gets manually zeroed -- from the previous pass's
       negative-boundary count each time). RTSA's actual *side = 1*
       `type = "analysis"` branch (the one this package's `side = 1`
       design reaches) calls `beta_boundary()` exactly once, with
       `rm_bs` left at its default of `0` -- there is no early-look
       suppression mechanism in that branch at all. The previous code
       was accordingly producing `rm_bs = 5` (five looks with their
       beta spend forced to exactly zero) where the correct value is
       `rm_bs = 0` (a smoothly increasing beta-spend curve from the
       first look onward).
* **Net effect:** `beta_engine$boundary`, `beta_engine$design_R`,
  `beta_engine$delta`, `beta_engine$rm_bs`, and
  `beta_engine$beta_spent`/`beta_spent_delta` (and, downstream,
  `TSA_futility_upper`/`TSA_futility_lower` on the returned
  `cumul_df`) all change for any retrospective analysis. The alpha
  (efficacy) engine (`.obf_alpha_boundary()`) is **unchanged** -- it
  was independently validated against live RTSA output previously and
  is not implicated in this bug.
* `tests/testthat/test-boundaries-analysis-rtsa.R` updated: the two
  tests that previously asserted the old (buggy) behaviour
  (`design_R` equal to `.rtsa_beta_boundary()`'s `warp_root`; `rm_bs`
  re-derived by iteration) now assert the corrected behaviour
  (`design_R` equal to `.rtsa_design_R()`'s root and measurably
  different from the design-mode `warp_root`; `rm_bs` fixed at `0`
  with no exactly-zero early-look run). All other tests in that file,
  and `.rtsa_beta_boundary()` (design mode) itself, are unchanged.
* **Validation status:** the corrected `delta` formula is an exact,
  closed-form match to the RTSA 0.2.2 reconstruction that prompted
  this fix (`2.486475`). The recursive integration primitives
  reused for the new `design_R` search
  (`.rtsa2_z_n_w`/`.rtsa2_init_int`/`.rtsa2_recur_int`/`.rtsa2_searchfunc`/`.rtsa2_prob`)
  are the same ones already used by, and validated for, the futility
  engine, and were additionally spot-checked in an independent Python
  re-implementation against RTSA's own published `side = 2`
  `esOF`/`alpha_boundary()` reference values
  (`RTSA::boundaries(timing = c(0.2,0.4,0.6,0.8,1), alpha = 0.05,
  side = 2, es_alpha = "esOF")` -> `4.877, 3.357, 2.680, 2.290,
  2.031`), which that re-implementation reproduces exactly, and,
  separately, against the actual `info_fraction` values of this
  package's own bundled example data (design_R root of ~1.045 with
  power exactly matching the 0.80 target at that root, in the same
  Python re-implementation). No R interpreter was available in the
  environment that made this fix, so it could not be run inside the
  package itself directly -- a live `R CMD check`/`devtools::test()`
  run against it (see the post-check patch above) did catch two
  further bugs in `.rtsa_design_R()`'s timing handling, now fixed.
  Before relying on this for a real analysis, run the direct
  comparison snippet in the block comment above
  `.rtsa_beta_boundary_analysis()` in `R/obf_boundaries.R` against a
  live RTSA installation on your own data, and please report anything
  else `R CMD check`/`testthat` still catches.

# tsahr 0.2.7.8

## Test-only fix: R CMD check on 0.2.7.7 found a bug in a test's assumption, not in the package

* **R CMD check on 0.2.7.7 came back with 260 passing tests and exactly
  one failure**, in the new `.rtsa_beta_boundary_analysis()` test suite
  added that same release. The failure was in the test, not the
  production code it was testing -- the `.rtsa_beta_boundary_analysis()`
  code itself ran correctly end-to-end (including through a full
  `tsa_hr()` call) in every other test, and all pre-existing tests
  continued to pass unchanged.
* The test ("rm_bs is derived (iterated fixed point), never
  hard-coded") asserted `ans$rm_bs != 5L || length(t) == 5L` -- i.e.
  that `rm_bs` landing on exactly `5` should only be possible when the
  input schedule also happened to have exactly 5 looks. That was never
  a valid invariant: `rm_bs` is a *count* of early looks suppressed by
  the fixed-point iteration, which can legitimately equal 5 for a
  schedule of any length (the test's own 6-look example genuinely
  suppressed 5 of them). The test conflated "happens to equal the old
  hard-coded constant" with "is therefore still hard-coded", which
  does not follow.
* Fixed by replacing that check with the actual invariants that
  matter: `rm_bs` stays within `[0, length(t_ext)]`, and two
  differently-shaped schedules (tightly-spaced early looks vs.
  well-separated looks) are confirmed to produce independently-derived
  `rm_bs` values rather than both landing on a shared magic number.
* No production code in `R/obf_boundaries.R` or `R/tsa_hr.R` changed in
  this release -- only the test file.

# tsahr 0.2.7.7

## Beta/futility engine now reproduces RTSA's `type = "analysis"` (retrospective) branch, not `type = "design"`

* **Disclosed compromise, now fixed.** Every previous 0.2.7.x release's
  beta engine (`.rtsa_beta_boundary()`) is a faithful port of RTSA's
  `boundaries(..., type = "design")` branch: given only a timing
  vector, it root-finds its own information-scale inflation
  (`warp_root`) from scratch on every call. That is RTSA's
  *prospective-design* math (solve everything given only `alpha`,
  `beta`, and a planned schedule). `tsa_hr()` uses it *retrospectively*
  -- on whatever information fractions the included studies actually
  produced -- which is conceptually RTSA's `type = "analysis"` use
  case, but `type = "analysis"` has a hard prerequisite (`design_R`, a
  sample-size-inflation root from an earlier, separate design call)
  that `tsa_hr()`'s architecture never had anywhere to get from, so it
  ran the design-mode math on observed data instead. This was already
  disclosed as an open item in the previous release's development
  notes; it is a real, mechanical mismatch with RTSA's own
  `type = "analysis"` code path, not just semantics.
* **`.rtsa_beta_boundary()` (design mode, `warp_root`) is unchanged**
  and still used internally, but only as step 1 of a new two-step
  pipeline: a new `.rtsa_beta_boundary_analysis()` first calibrates a
  `design_R` internally -- by running that same design-mode root
  search once on the observed timing, exactly as RTSA's own `RTSA()`
  wrapper does when no prior design object is supplied
  (`R/RTSA.R`'s `type == "analysis"`/`design = NULL` branch: it calls
  `boundaries(type = "design")` once to get `design_R <- bounds$root`)
  -- then runs RTSA's actual `type = "analysis"` beta_boundary() branch
  against that fixed `design_R`:
    - the observed information fractions drive the recursion's
      info/standard-deviation scale directly and *unwarped* (no
      `warp_root`/`inf_warp()` re-scaling at this stage);
    - the design's completion point (`design_R`) is appended as an
      explicit endpoint whenever the observed data has not yet reached
      it, exactly as RTSA's `beta_boundary()` does for its own
      `design_R` branch;
    - the beta-spending budget consumed at each look is looked up
      against `inf_frac / design_R` (how much of the eventually-
      planned total information has actually accrued), not the raw
      observed fraction;
    - the early-look suppression count (`rm_bs`) is iterated to a
      fixed point (three passes, matching RTSA's own three
      `beta_boundary()` calls for this branch) rather than hard-coded
      or re-derived via another root search -- `design_R` itself stays
      fixed throughout, unlike the design-mode pipeline.
* `tsa_hr()`'s `beta_engine` now comes from
  `.rtsa_beta_boundary_analysis()` instead of `.rtsa_beta_boundary()`;
  its `$boundary` output shape (aligned to the unique observed
  information fractions) is unchanged, so no other code in the package
  needed to change.
* **Honesty note, carried over from the design-mode engine's own
  VALIDATION section:** this is a careful, line-by-line reading of
  RTSA's published `beta_boundary()`/`boundaries()` `design_R` branch
  (RTSA 0.2.2 source), not a numerically confirmed match against a
  live two-step `RTSA::boundaries(type = "design")` +
  `RTSA::boundaries(type = "analysis", design_R = ...)` call -- no R
  interpreter was available in the environment that wrote this port.
  See the block comment on `.rtsa_beta_boundary_analysis()` in
  `R/obf_boundaries.R` for a runnable comparison snippet.

# tsahr 0.2.7.6

## Test-only fix: R CMD check on 0.2.7.5 found a bug in a test's assumption, not in the package

* **`R CMD check` on 0.2.7.5 came back with 242 passing tests and
  exactly one failure**, a substantial jump in confidence over the
  three previous 0.2.7.x releases (each of which had shipped with a
  real package bug). The failure itself was in the test, not the code
  it was testing.
* The test ("the information-scale root search actually engages and
  hits its target") asserted that `ans$warp_root` (the root found by
  the FULL two-pass `.rtsa_beta_boundary()` pipeline, which may apply
  `rm_bs > 0` on its second pass) should nearly equal an isolated
  `root` computed with `rm_bs` fixed at `0`. For the specific design
  this test uses, the pipeline's first pass suppressed one early look
  (`rm_bs = 1`), which genuinely changes the root-search objective
  function -- so the two roots are, correctly, solutions to two
  *different* equations, and were never guaranteed to coincide. They
  differed by about 4.6e-4, just past this test's (too tight,
  wrongly-reasoned) 1e-4 tolerance.
* Fixed by replacing that comparison with the actual invariant that
  matters: `ans$warp_root` should be a root of the pipeline's own
  `rm_bs`-adjusted objective function (`.rtsa2_inf_warp(ans$warp_root,
  ..., rm_bs = ans$rm_bs)` should be numerically zero), which is what
  the fixed test now checks, rather than requiring it to match a
  different, unadjusted equation's root.
* No production code in `R/obf_boundaries.R` changed in this release --
  only the test file.

# tsahr 0.2.7.5

## Root search from 0.2.7.4 failed almost universally -- found and fixed by actually running the algorithm

* **0.2.7.4's root-finding fix was itself badly broken**: `R CMD
  check` on 0.2.7.4 showed PASS 2 of the two-pass root search (any
  design where at least one look came back negative on PASS 1, i.e.
  most realistic designs) failing with "Non-binding futility
  boundaries could not be computed" -- not an edge case, essentially
  every test that called `tsa_hr()` on real-shaped data.
* **Root cause, found by actually executing the algorithm** (a
  from-scratch Python port of the exact same code, run in this
  environment, since no R interpreter is available here): PASS 2's
  `rm_bs` suppression deliberately zeroes the first `rm_bs` entries of
  its timing vector before calling `.rtsa_beta_spend_OF()` -- that is
  the whole mechanism. `.rtsa_beta_spend_OF()` had an input-validation
  guard, `if (any(t <= 0)) stop(...)`, added well before the `rm_bs`
  mechanism existed, that rejected exactly the `t = 0` values `rm_bs`
  produces. Every PASS-2 call with `rm_bs > 0` therefore failed with
  this function's own error on every evaluation, exhausted all 50
  widening attempts, and surfaced one level up as a root-search
  non-convergence -- a misleading symptom for what was actually an
  unconditional, immediate failure. The underlying spending-function
  formula was never the problem: `qnorm(1-beta/2)/sqrt(0)` is `+Inf`
  in IEEE 754 (no error, no NaN), and `pnorm(Inf, lower.tail = FALSE)
  = 0`, so `t = 0` already gave exactly the correct "no spend yet"
  answer -- only the guard rejecting it was wrong. Fixed by relaxing
  the guard to `t < 0` (negative fractions are still, correctly,
  rejected).
* **A second, independent degeneracy found during the same
  investigation**: a schedule where every observed information
  fraction is already >= 1 (DARIS reached at or before the very first
  study) collapses to a single-point `timing_beta = 1`. At that single
  point the incremental beta-spend is exactly `beta` by construction
  of any complete spending function, which hits the `d1 == beta`
  special case (`za = 0`) regardless of the warp factor -- so the root
  search's own objective function is constant and can never bracket a
  sign change. This is a genuine mathematical degeneracy, not a
  search-tuning problem. `.rtsa_beta_boundary()` now detects the
  single-point case up front and skips the root search entirely,
  going straight to the same definitive-look convention used in every
  other case.
* **Both fixes were verified by actually running the algorithm**
  end-to-end in a faithful Python re-implementation (numpy/scipy,
  executed in this environment) across several realistic schedules --
  a 7-look retrospective design matching the shape of the package's
  own bundled example data, a 40-look near-equal-spacing design, a
  15-look randomly-spaced design, varying alpha/beta, an
  early-clustered design that suppresses most of its looks, and the
  single-look degeneracy above -- all converge cleanly post-fix, none
  did pre-fix. This is a materially stronger check than the previous
  three 0.2.7.x releases had (each of which was reasoned through from
  source alone, with no execution at all, and each of which turned out
  to have a real bug); it is still not a run of the actual R package
  or a comparison against a live `RTSA::boundaries()` call, which
  remains outstanding -- see `inst/REVERSE_ENGINEERING_RTSA.md`.
* Three new regression tests: `.rtsa_beta_spend_OF()` accepts `t = 0`
  and still rejects `t < 0`; a full two-pass root search on a
  design constructed to produce `rm_bs > 0` converges rather than
  erroring; a single-look (`nn = 1`) schedule resolves via the new
  special case rather than exhausting the root search.

# tsahr 0.2.7.4

## Beta/futility engine: RTSA's information-scale root search was missing (numbers far from RTSA, final look didn't meet efficacy boundary, negative early values not hidden)

* **Root cause of all three reported discrepancies, found in one place.**
  0.2.7-0.2.7.3 ported RTSA's per-look recursion (`beta_boundary()`,
  `z_n_w()`, `searchfunc()`, `init_int()`, `recur_int()`, `prob()`)
  faithfully, but silently assumed an implicit `warp_root = 1`: it used
  the SAME information fractions both to look up how much beta had been
  spent at each look and as the standard-deviation scale the recursion
  runs on. RTSA's own `boundaries()` never does this. It always finds a
  scalar inflation of the information SCALE alone (`org_inf_frac =
  inf_frac * root`; the beta-spending fractions themselves are never
  warped) via root-finding (`uniroot(inf_warp, ...)`), chosen so the
  resulting futility boundary lands exactly on the fixed efficacy
  boundary at the definitive final look -- and then repeats that root
  search a second time with any look that came back with a negative
  futility boundary on the first pass suppressed (`rm_bs = sum(lb$za <
  0)`, its beta-spend fraction zeroed, which routes it through the
  "negligible spend" sentinel instead).
  - **Beta-bounds far from RTSA/rpact across the whole schedule**: this
    is exactly what running the recursion at the wrong (unwarped)
    information scale produces -- systematically low, with the error
    shrinking toward the final look purely because the final-look
    convention below pins that one point regardless.
  - **Final beta-bound not meeting the final alpha-bound**: meeting
    exactly at the final look is *what the root search's objective
    function solves for*; without it, there is no reason for the two
    to coincide anywhere except at the single point this package
    already forces directly (see below).
  - **Early negative futility bounds shown instead of hidden as NA**:
    RTSA does not detect and hide negative values after the fact --
    it *prevents* them from surviving in the first place, via exactly
    the second (`rm_bs`) root-search pass above. Without that pass,
    values that real RTSA would have suppressed by construction were
    left visible.
* **0.2.7.4 ports this root-search/suppression pipeline**, in
  `.rtsa2_inf_warp()` and `.rtsa2_find_warp_root()` (new), and extends
  `.rtsa2_beta_boundary_core()` with `warp_root` and `rm_bs`
  parameters. `.rtsa_beta_boundary()` now runs the full two-pass
  sequence RTSA's own `boundaries()` does: find a root with `rm_bs =
  0`; run the recursion once to see which early looks came back
  negative; re-find the root with those looks' beta-spend zeroed; run
  the recursion once more for the final result. RTSA's own narrow,
  incrementally-widening `uniroot()` bracket search (`[start - step,
  start]`, `start` stepped by `step` on failure, up to 50 attempts) is
  ported as-is rather than substituted with a generic wide-bracket
  search, since a wide bracket risks landing on a spurious root far
  from the physically sensible region RTSA's own narrow search is
  specifically designed to stay within.
* **The 0.2.7.1 preventive za/zb clamp (added to stop a grid-collapse
  crash) is no longer applied to the final look.** With the root
  search now needing `za[last]` to be able to reach -- and, for
  `uniroot()` to bracket a sign change at all, briefly cross -- the
  fixed efficacy boundary as the candidate warp factor is varied, a
  fixed-margin ceiling on that one value would make the root search's
  objective function unable to ever change sign. The clamp is kept, as
  before, for every look *before* the final one, where the original
  crash was actually triggered; that case is unaffected by this
  change. `.rtsa2_z_n_w()`'s own degenerate-grid fallback (0.2.7.1/
  0.2.7.2) remains as a second line of defense regardless.
* **A specific proposed fix to `.rtsa_beta_spend_OF()` -- replacing
  `qnorm(1 - beta / 2)` with `qnorm(1 - beta)`, on the claim that
  RTSA's `esOF()` itself omits the `/2` -- was checked directly against
  the actual RTSA 0.2.2 source and found to be incorrect.**
  `R/RTSA_helperfunctions.R`'s `esOF()` is
  `as_cum[i] <- 2*(1 - pnorm(qnorm(1-alpha/2)/sqrt(timing[i])))` -- the
  `/2` is present. This formula was already correct in 0.2.7-0.2.7.3
  and is unchanged here; applying the proposed fix would have halved
  the effective beta-spend rate and reintroduced a real error,
  understating early-look futility boundaries even further than the
  bug this release actually fixes. A comment directly above
  `.rtsa_beta_spend_OF()` now documents this check so the claim isn't
  reintroduced without a fresh, direct read of the real source.
* **Validation status (still honest, still unverified numerically):**
  this release was written and reasoned through entirely from RTSA's
  published source and the specific numeric discrepancy report that
  motivated it; no R interpreter was available to actually run any of
  it, including the new root-search code, against a live
  `RTSA::boundaries()` call or the reported reference table. The root
  search's failure mode (`stop("Non-binding futility boundaries could
  not be computed...")` when no bracket is found within 50 widening
  attempts) is itself ported from RTSA's own code -- it is RTSA's
  defined behaviour for a sufficiently unusual design, not necessarily
  a tsahr defect, if it is ever hit. Please re-run the comparison in
  `inst/REVERSE_ENGINEERING_RTSA.md` against a live RTSA/rpact call
  before relying on this for anything beyond an approximate futility
  band.
* Tests updated: the two tests that fed a constant (unrealistically
  flat) alpha wall into the beta engine now use a realistic
  decreasing-then-flattening wall (matching the live RTSA reference
  boundaries already used elsewhere in this suite), since a flat wall
  is a harder case for the new root search to bracket and was never
  the property those tests were actually checking. Two new tests
  confirm the root search converges to (numerically) zero at the
  target design and that the naive `warp_root = 1` case is measurably
  different from it, i.e. that the fix is not a no-op.

# tsahr 0.2.7.3

## Test fix only: `R CMD check` failure was in a 0.2.7.2 regression test itself, not in the package code

Re-running `R CMD check` after 0.2.7.2 reported 4 failures, all in the
one new test added in 0.2.7.2
(`"0.2.7.2: a 3-node (m = 3) Simpson grid produces correct weights, not
an error"`) -- **not** in `.rtsa2_z_n_w()`, `.rtsa2_seq_by2()`, or any
other package code, and not a crash: `expect_length()`/`expect_equal()`
mismatches. The underlying 0.2.7.2 fix itself was already correct and is
unchanged in this release.

**Cause:** that test picked `lo = 1.5` as a stand-in for a near-collapsed
`[za[i], zb[i]]` window. For the specific `r = 18`, `delta = 0`,
`sd_incr = 1` inputs used in the test, `1.5` happens to land EXACTLY on
one of `.rtsa2_z_n_w()`'s own log-spaced grid nodes (node `j = 72`
evaluates to precisely `-3 + (72 - 18)/12 = 1.5`), so one extra original
node coincided with `lo` and survived trimming, correctly producing a
5-node grid (`m = 5`) instead of the 2-node/3-node (`m = 3`) case the
test's hard-coded expected values assumed. The code was doing the right
thing with the input it was given; the test's prediction of what that
input would produce was wrong.

**Fix:** rewrote the test (`tests/testthat/test-boundaries-rtsa.R`) to
(a) use `lo = 1.234567`, deliberately off the `r = 18` grid's node
spacing, and, more importantly, (b) stop hard-coding an exact node count
or exact `zj`/`wj` values altogether, in favor of checking the
invariants that must hold for ANY valid Simpson grid built on
`[lo, hi]` regardless of how many interior nodes happen to survive
trimming: no error, an odd node count `>= 3`, endpoints exactly at
`lo`/`hi`, a non-decreasing sequence, and total Simpson weight equal to
the window width (the property Simpson's rule actually guarantees, and
what the downstream recursion actually relies on). This is more robust
against similar grid-alignment coincidences with any future choice of
`r`/`lo`, not just a fix for this one value.

No change to `R/obf_boundaries.R` in this release.

# tsahr 0.2.7.2

## Bug fix: `R CMD check` still failing after 0.2.7.1 -- a second, related `seq()` crash in the same grid, now with a different index

0.2.7.1 fixed the `length(xi) <= 1` grid-collapse crash, but re-running
`R CMD check` surfaced a second, closely related crash in the exact same
function, `.rtsa2_z_n_w()`, now at `seq(3, m - 2, 2): wrong sign in 'by'
argument` -- hit by the same `target_HR = NA` example-data scenario as
before (and by two of the new 0.2.7.1 regression tests themselves, which
is how it was caught).

**Root cause:** the 0.2.7.1 clamp keeps `za[i]` only `1e-6` below `zb[i]`
when the two would otherwise converge -- deliberately tiny, so as not to
perturb any well-separated boundary. But a `1e-6`-wide interval is far
narrower than the spacing between `.rtsa2_z_n_w()`'s log-spaced grid
nodes, so trimming to `[za[i], zb[i]]` in that situation legitimately
leaves exactly 2 points (the two endpoints, no interior node survives) --
which is precisely what the 0.2.7.1 safety net widens degenerate cases
to as well. Both routes land on the same `m = length(xi) * 2 - 1 = 3`
grid. That case turns out to have been separately broken already, for
any `m = 3` grid regardless of cause: the Simpson-weight loop's
`k %in% seq(3, m - 2, 2)` membership check evaluates `seq(3, m - 2, 2)`
eagerly, and for `m = 3` that's `seq(3, 1, 2)` -- an empty index range,
but, as with 0.2.7.1's `seq(1, length(xi) - 1, 1)`, R's `seq()` with an
explicit `by` throws rather than returning `integer(0)` when `to < from`.
So `m = 3` (i.e. a 2-node grid) was never actually safe to reach, even
after 0.2.7.1 -- it was just newly *reachable* by 0.2.7.1's own fix,
where previously (pre-0.2.7.1) the crash at `length(xi) <= 1` happened
first and masked it.

**Fix:** new internal `.rtsa2_seq_by2(from, to)` helper -- `seq(from, to,
2)`, but returns `integer(0)` instead of erroring when `to < from` -- used
in place of the two raw `seq(3, m - 2, 2)` / `seq(2, m - 1, 2)` calls in
`.rtsa2_z_n_w()`'s Simpson-weight loop. For any `m` where those ranges
are non-empty (`m >= 5`), this is byte-for-byte the same `seq()` call as
before -- **no change to any boundary value outside the previously-
crashing case.** Hand-traced the `m = 3` case through the full weight
loop to confirm it now produces the correct composite-Simpson weights
(`1/6, 4/6, 1/6` of the interval width, summing to the full width) rather
than just failing to crash.

Also fixed the two 0.2.7.1 regression tests that this same bug broke
(`test-boundaries-rtsa.R`): both exercised exactly the `m = 3` path (the
real `tsa_hr(path, verbose = FALSE)` call, and the direct
`.rtsa2_z_n_w()` unit test with equal/reversed `za`/`zb`) and so were
themselves failing under `R CMD check`, for the same underlying reason
they were written to catch the *previous* bug -- no test changes were
needed once the underlying `.rtsa2_seq_by2()` fix was in place; they
pass as originally written.

# tsahr 0.2.7.1

## Bug fix: `R CMD check` failure -- grid collapse in the new RTSA-ported beta/futility engine

`R CMD check` on 0.2.7 failed 3 tests with `Error in seq.default(1, length(xi) - 1, 1): wrong sign in 'by' argument`,
raised from `.rtsa2_z_n_w()` via `.rtsa2_beta_boundary_core()` /
`.rtsa_beta_boundary()`, triggered by the package's own bundled example
data under `target_HR = NA` (the circular-target scenario exercised by
`tsa_hr(path, verbose = FALSE)` with no `target_HR`).

**Root cause:** `.rtsa2_z_n_w()` builds a Simpson's-rule integration grid
on `[za[i], zb[i]]` (the futility and efficacy boundaries at look `i`) by
trimming a fixed log-spaced node vector down to that interval. The
non-binding futility boundary `za[i]`, returned unconstrained by
`.rtsa2_searchfunc()`'s root search, is expected to approach the fixed
efficacy wall `zb[i]` closely near the final look by design (the two are
constructed to meet at `t = 1`) -- but nothing kept it from landing at or
past `zb[i]`, which collapses the trimmed grid to a single point (or
fewer). The two-argument form `seq(1, length(xi) - 1, 1)` then throws
"wrong sign in 'by' argument" once `length(xi) <= 1`, instead of quietly
returning an empty sequence -- this is a real edge case surfaced by this
specific port (RTSA's own equivalent R source has the identical
unguarded pattern), not a mistranslation.

**Fix, two parts:**

* **Prevention** (`.rtsa2_beta_boundary_core()`): new internal
  `.rtsa2_clamp_za_below_zb()` helper clamps `za[i]` to stay at least a
  small margin (`1e-6` on the Z scale) below `zb[i]`, applied right after
  every branch that sets `za[i]` (the `zninf` sentinel and `0` branches
  included, for uniformity, though the observed failure was in the
  `.rtsa2_searchfunc()` branch). This keeps the grid-collapse condition
  from arising during normal operation in the first place; the margin is
  small enough that it does not perturb any well-separated boundary
  value.
* **Safety net** (`.rtsa2_z_n_w()`): if the trimmed grid still collapses
  to fewer than 2 points (e.g. from a future direct call with unclamped
  `za`/`zb`), it is now widened back out to the two-point interval
  `[za[i], zb[i]]` (with a minimal positive width inserted if the two are
  equal or reversed) instead of proceeding to the vectorized Simpson's-
  rule construction that assumed at least 2 points. The specific
  `seq(1, length(xi) - 1, 1)` call is also replaced with
  `seq_len(length(xi) - 1)`, which returns an empty sequence rather than
  erroring when `length(xi) == 1` (note: `1:0` is not such an idiom -- it
  evaluates to the length-2 sequence `c(1, 0)`, not an empty one;
  `seq_len(0)` is the correct empty-sequence idiom).

No change to any boundary value for the normal (well-separated `za`/`zb`)
case tested elsewhere in the suite -- the clamp is a no-op unless `za[i]`
would otherwise land within `1e-6` of `zb[i]`, and the safety net is only
reached if the clamp somehow didn't fire first.

# tsahr 0.2.7

## Beta/futility boundary engine reconstructed to match RTSA (correctness/provenance)

* **The non-binding futility engine used in 0.2.4-0.2.6.9 was not built
  from actual RTSA source, despite claiming to be.** That engine's
  file-level comment cited RTSA functions `getInnerWedge()`,
  `betas_Obf`, `sdfunc`, `first_old`, `other_old`, `searchfunc_old`,
  `qpos_old`, `fcab_old`, `gfunc`, and `tsa_beta_bound` as its source.
  Having now obtained and read the actual RTSA package (RTSA 0.2.2,
  https://github.com/AnneLyng/RTSA) directly, **none of those names
  exist anywhere in it.** 0.2.6.6-0.2.6.9 softened the surrounding
  comment from "literal R implementation" to "adapted from" on an
  external audit's advice, but the algorithm itself was never
  re-examined or rebuilt until now.
* **0.2.7 replaces the entire engine with a line-by-line port of RTSA's
  real non-binding-futility machinery**: `beta_boundary()`, `z_n_w()`,
  and `searchfunc()` (R/RTSA_helperfunctions.R, ported near-verbatim,
  since they are already pure R), and `init_int()`, `recur_int()`, and
  `prob()` (src/first.cpp, ported from C++ to pure R, since tsahr has
  no compiled-code dependency) -- specialised to `es_beta = "esOF"`,
  the only spending family this package exposes. See
  `inst/REVERSE_ENGINEERING_RTSA.md` for the full algorithmic write-up,
  including a side-by-side of the old and new algorithms.
* **Three concrete corrections**, in order of consequence:
  1. **Fixed, not empirical, drift.** The old engine derived its
     alternative-hypothesis drift ("testDrift") empirically from the
     shape of a symmetric, null-referenced futility wedge, computed
     *after* constructing that wedge. RTSA's real engine uses a FIXED,
     closed-form drift, `delta = |qnorm(alpha/side) + qnorm(beta)|`,
     computed directly from alpha/beta/side before any recursion runs
     -- independent of the data or of the futility construction's own
     shape.
  2. **The true efficacy boundary as the wall throughout.** The old
     engine built a symmetric (`+-za`) null-referenced wedge and only
     reconciled it with the real (generally asymmetric,
     decreasing-then-flattening) efficacy boundary after the fact.
     RTSA's real engine uses the actual efficacy boundary as the upper
     wall of the recursive integration at every step from the start.
  3. **NA now means "negligible spend," not "non-positive."** The old
     engine suppressed (set to NA) every non-positive futility value
     (`b[b <= 0] <- NA_real_`). RTSA returns NA only where the
     incremental beta spend at a look is negligible enough to hit an
     internal sentinel (`zninf = -20`); a finite, possibly negative,
     non-binding futility boundary is a legitimate result (it says the
     trial would only be flagged for advisory futility if the
     cumulative Z-statistic had already crossed to the "wrong" side of
     the null by that point) and is no longer hidden.
* **Two departures from a literal port are kept, disclosed, and
  unchanged from previous versions**: (a) the single definitive final
  look (t = 1) still has its futility boundary set directly to the
  closed-form `qnorm(1-alpha/2)`, rather than porting RTSA's own
  root-finding (`uniroot(inf_warp,...)`) machinery, which solves a
  prospective *design* problem tsahr's retrospective architecture has
  no counterpart for; (b) a defensive `pmin(boundary, c_vec_alpha)`
  safeguard is still applied on top of the reconstructed recursion,
  since RTSA's own algorithm does not hard-enforce that a futility
  value can never exceed the efficacy wall at every intermediate step.
* **Validation status (honest): this reconstruction has NOT been
  checked against a live `RTSA::boundaries()` call.** Unlike the alpha
  engine (0.2.6, checked against a live 5-look call and matching
  essentially exactly), no R interpreter was available while writing
  this port, so none of the new code has actually been executed. It is
  a careful, line-by-line reading of RTSA's published source, not a
  numerically confirmed match. `inst/REVERSE_ENGINEERING_RTSA.md`
  gives the exact comparison to run before relying on this for
  anything beyond an approximate, illustrative futility band (which is
  how this package has always described its futility output).
* **Dead code removed**: `.rtsa_gfunc`, `.rtsa_trap`, `.rtsa_fcab`,
  `.rtsa_qpos`, `.rtsa_first`, `.rtsa_other`, `.rtsa_searchfunc_old`,
  and `.rtsa_get_inner_wedge` are deleted; a new test
  ("legacy (non-RTSA-matching) beta engine internals have been
  removed") checks they stay gone. `.rtsa_beta_spend_OF()` is
  unchanged -- its formula already matched RTSA's real `esOF()`; only
  the recursion built around it was wrong.
* Test suite updated: the old "hides non-positive early futility
  points" test encoded the incorrect NA rule and is replaced with a
  test of the corrected rule (NA only for the negligible-spend
  sentinel case, checked via a closed-form early-look argument, not
  the recursion's own numerics); a new test pins `delta` to the fixed
  theoretical formula; a new test confirms the dead functions are
  gone. The pre-existing "definitive alpha boundary,"
  "over-powered analysis," and "capped at the corresponding alpha
  boundary" tests are unchanged and still pass under the reconstructed
  engine. No downstream test (DARIS/futility-stop end-to-end tests,
  the 40-study integration test) required changes: the only
  beta-engine-derived quantity that reaches `tsa_hr()`'s formal output
  for those scenarios is the single pre-DARIS interim boundary and the
  independently-computed definitive final value, neither of which
  depends on the specific numeric internals changed here.
* Only the beta/futility engine changed. Alpha-spending, DARIS,
  effect-size, and all other package machinery are untouched.

# tsahr 0.2.6.9

## Fixes a broken test introduced in 0.2.6.8 (`R CMD check` failure)

* **`test-tsa_hr.R` "non-numeric input columns are diagnosed as a type
  problem" failed under `R CMD check`** with
  `replacement has 0 rows, data has 10`. The bug was in the test, not in
  the package: it read the bundled example workbook directly with
  `readxl::read_excel()` and then addressed `d$Events_Treatment`, but
  several headers in that sheet are stored **with spaces** (`Events
  Treatment`, `N treatment`, `Events controls`, `N controls`; only
  `Study`, `log_HR`, and `Std_Error` are already underscored). Space-to-
  underscore normalisation happens *inside* `tsa_hr()`, so at that point
  in the test `d$Events_Treatment` was `NULL`, and
  `as.character(NULL)` is `character(0)` -- which cannot be assigned
  into a 10-row data frame.
* The test now applies the same `gsub(" ", "_", names(d))` normalisation
  that `tsa_hr()` performs before addressing columns, so it targets real
  columns and stays correct if the example sheet's headers change.
* **No package code changed.** The 0.2.6.8 type-validation feature itself
  was never exercised by the failing line -- the test errored before
  reaching `tsa_hr()`. The other four tests that read the workbook
  directly were checked for the same latent flaw and are unaffected:
  they either add new columns or use `Std_Error`, which is genuinely
  underscored in the source file.

Note on the `RoxygenNote` mismatch reported by `devtools::check()`
(installed roxygen2 8.1.0 vs declared 7.3.1): this is informational, not
an error. `RoxygenNote` is deliberately left at 7.3.1 so `check()` does
not re-document the package, because the `.Rd` files have been edited by
hand in recent releases; regenerating them with roxygen2 would discard
those edits. If you switch back to a roxygen-driven workflow, run
`devtools::document()` once and let it update both the `.Rd` files and
this field together.

# tsahr 0.2.6.8

## Fixes a semantic bug in `circularity_warning`, plus three documentation/validation refinements

Prompted by an external (ChatGPT) audit of 0.2.6.7, which rated the
release otherwise ready and identified `circularity_warning` as the one
item to fix before finalising. Each item was checked against the code
before acting on it.

* **`circularity_warning` now means what its name and message say.** It
  was defined as
  `is.na(target_HR) && sum(total_events) / DARIS_events > 3` -- i.e. it
  carried a *severity* condition on top of the circularity condition.
  But `summary.tsa_hr()` gates a message worded purely for the general
  case on that flag ("target_HR was not specified, so the observed
  pooled HR was used... This is circular"). The consequence was a real
  user-visible gap, not just a misnomer: a circular analysis sitting at,
  say, 1.5x DARIS reported **no circularity note at all**, directly
  contradicting `?tsa_hr`, which correctly documents that any RIS
  derived from the observed pooled effect is circular. Now split into
  two fields:
  - `circularity_warning <- is.na(target_HR)` -- circular, full stop.
  - `circularity_severe` -- circular **and** accrued events exceed three
    times DARIS (the runaway case where the boundary collapses to the
    conventional one almost immediately).
  Both are returned in `information_size` and documented in `?tsa_hr`.
  The statistical calculation is unchanged; only the reporting is.
* **Verbose output now covers the non-severe circular case too.** The
  detailed "accrued events greatly exceed DARIS" block is unchanged and
  still fires only when `circularity_severe`, but a shorter note now
  fires for any circular analysis, so the console and `summary()` agree
  with each other and with the documentation. `summary()` prints the
  general note whenever circular, and adds the collapse warning on top
  when severe.
* **Verbose random-effects caveat resynchronised with the Rd wording.**
  The console still used the older "holds exactly only for a
  FIXED-EFFECT cumulative process" formulation that was deliberately
  replaced in the source/Rd documentation in an earlier release, leaving
  two subtly different descriptions of the same caveat. The console now
  uses the more precise canonical-information-process framing.
* **The `method` documentation no longer says "passed straight through"**
  to `metafor::rma()`, which stopped being exactly true in 0.2.6.7 when
  `"CO"`/`"VC"` began being normalised to `"HE"` first. Now states that
  it is passed after validation and, for those aliases, normalisation.
* **Non-numeric input columns are diagnosed as a type problem.**
  `is.finite()` returns all-`FALSE` (rather than erroring) on a
  character or factor column, so a column read in as text -- Excel cells
  stored as strings, a stray footnote marker forcing the column to
  character -- surfaced as "Column(s) must contain only finite values
  (found NA/NaN/Inf)". True of the `is.finite` result, but a misleading
  diagnosis. `log_HR`, `Std_Error`, and the four count columns are now
  type-checked first, and the error names each offending column and its
  actual class.
* **New regression tests** for the circularity split (including that
  `circularity_severe` never holds without `circularity_warning`), for
  `summary()` reporting circularity in the non-severe case, and for the
  numeric-type diagnosis.

Not changed, deliberately: the beta engine remains frozen and
RTSA-derived/adapted, as in 0.2.6.7. The audit's suggestion to escalate
`order_by` NA handling from warning to error was not adopted -- the
current behaviour is transparent and reproducible, and the audit itself
scoped that as a possible future major release, not a fix for this one.

# tsahr 0.2.6.7

## Reverses an incorrect 0.2.6.6 decision: `method = "CO"` is a real metafor alias and is now supported

Prompted by an external (ChatGPT) review of 0.2.6.6, which flagged the
`"CO"` removal as a release blocker. The flag was correct; this release
reverses that removal and picks up several smaller items from the same
review. Each was checked against primary sources or the actual code
before acting on it.

* **`method = "CO"` (and `"VC"`) are now accepted, and normalised to
  `"HE"`.** 0.2.6.6 removed `"CO"` from the supported methods on the
  basis of a direct test against an installed metafor, which threw
  `Unknown 'method' specified`. That observation was real, but the
  conclusion drawn from it -- that `"CO"` is "not a recognised method
  string in current metafor at all" -- was **wrong**, and the
  0.2.6.6 source comment and documentation asserting that have been
  corrected. metafor's current documentation states that the Hedges
  estimator is also called the variance-component or Cochran estimator
  and that `method = "VC"` or `method = "CO"` may be used to select it.
  The two observations are reconciled by version skew: the alias is
  present in current metafor but absent from the older release the
  0.2.6.6 test ran against (the CRAN 4.6-0 reference manual carries the
  same sentence *without* the alias parenthetical, which is exactly the
  boundary in question).
* **Normalised rather than merely passed through**, which is the point
  of the fix: forwarding a bare `"CO"` to `metafor::rma()` would make
  `tsa_hr()` work or fail depending on which metafor the user happens to
  have installed. Mapping `"CO"`/`"VC"` to `"HE"` inside `tsa_hr()`
  makes behaviour identical on every metafor version, and avoids
  declaring a minimum metafor version in `DESCRIPTION` purely to pin
  down an alias. All three strings denote the same estimator, so there
  is no numerical consequence.
* **The normalisation is auditable, not silent:** the returned object
  now carries `parameters$method_requested` (what the caller passed)
  alongside `parameters$method` (the normalised string actually used).
  `method_requested` is always populated, including when no aliasing
  occurred, so downstream code can rely on the field existing.
* **New regression test** pins both the structural behaviour (what is
  recorded, what reaches metafor) and the numerical one: `"CO"` and
  `"VC"` must produce identical `tau2`, `D2`, and cumulative `Z` to
  `"HE"`. The 0.2.6.6 test asserting `"CO"` errors has been removed and
  replaced with one asserting it does *not*.
* `"GENQ"`/`"GENQM"` remain unsupported, unchanged and for the unchanged
  reason: they require a user-supplied `weights` argument that
  `tsa_hr()` does not collect. That part of the 0.2.6.6 finding was
  correct and is not affected by the `"CO"` reversal.

## Input-validation gaps closed

* **Colliding column names after underscore normalisation are now
  rejected.** Column headers have spaces replaced with underscores on
  load, so a sheet containing both `Std Error` and `Std_Error` produced
  two identically-named columns, after which `data$Std_Error` silently
  resolved to whichever came first -- a wrong-column-used bug yielding a
  plausible-looking but incorrect analysis with no error anywhere.
  `tsa_hr()` now stops and names the offending columns instead of
  guessing which was meant.
* **`order_by` is normalised the same way as the column names.**
  Previously, passing a header exactly as it reads in the user's
  spreadsheet (`order_by = "Publication Year"`) failed with "not a
  column in data" for a column that is plainly there, because matching
  happened after normalisation. Both spaced and underscored forms now
  work; documented in `?tsa_hr`.

## Test coverage

* **`order_by` sorting is now tested, not just its tied-value warning.**
  The previous test only confirmed the warning fires; `order_by` could
  have silently no-opped and only the warning path was covered. The new
  test reverses a strictly-ordered dataset, sorts it back via
  `order_by`, and requires identical `Study` order, `Z`, and
  `info_fraction` to the already-sorted data. TSA is order-dependent, so
  this is a reproducibility guarantee.

## Wording corrections (no behaviour change)

* The beta/futility engine is no longer described as a **"literal R
  implementation"** of RTSA's inner-wedge algorithm. It follows RTSA's
  algorithmic structure and indexing conventions, but adds
  package-specific numerical safeguards RTSA has no need for
  (`pmin(boundary, c_vec_alpha)`, dynamic grid sizing, a convergence
  fallback, defensive `NA` handling, post-DARIS mapping onto the
  definitive `t=1` boundary). It is now described as RTSA-derived and
  adapted, with the open point stated plainly: no live multi-look RTSA
  beta reference has yet been obtained, so numerical identity with RTSA
  is not claimed. The engine itself is unchanged and remains frozen for
  this release, as intended.
* The `D2` comment's claim that D2 is **"mathematically bounded"** in
  [0,1) is softened. D2 is bounded by definition, and
  `var_random >= var_fixed` holds for essentially all of metafor's
  estimators, but the computed value is a ratio of two separately
  estimated variances -- which is precisely why the `max(0, .)` and the
  0.999 cap exist rather than being redundant.

# tsahr 0.2.6.6

## Bug fix: 3 of 13 advertised `method` values never worked, plus a documentation correction and several audit-driven improvements

Prompted by a second external (ChatGPT) audit of 0.2.6.5, verified against
the actual code and against current metafor documentation before acting
on any of it (see below for what was independently corroborated and how).

### Bug fix (correctness): `method = "CO"`, `"GENQ"`, `"GENQM"` never worked

* **`tsa_hr(method = ...)` has advertised 13 metafor method strings as
  supported since the `method` parameter was first added, but 3 of them
  never actually worked** -- this went unnoticed because only `"DL"`,
  `"REML"`, and `"ML"` were ever exercised by the test suite. Found while
  adding a test that runs every advertised method (itself prompted by
  the audit's suggestion to test the full advertised set) -- independent
  of anything the audit itself flagged.
  - `"CO"` is not a recognised method string in current metafor at all
    (verified directly against an installed metafor: it throws
    `"Unknown 'method' specified"`, not a Hedges-estimator result).
    It appears as a documented alias for `"HE"` in some older/secondary
    sources, but is not accepted by `rma()` as currently shipped.
    Independently corroborated: a search of metafor's own current
    documentation and training materials turned up no mention of `"CO"`
    in any enumerated method list.
  - `"GENQ"` / `"GENQM"` require the caller to also supply a `weights`
    argument to `metafor::rma()` (per metafor's own documentation, e.g.
    `rma(yi, vi, weights = 1/vi, method = "GENQ")`), which `tsa_hr()`
    does not currently collect or pass through, so calling it with
    these methods and no weights errors out inside `rma()`.
    Independently corroborated against metafor's own documentation and
    Cochrane training materials.
* **`valid_methods` corrected to the 10 that actually work standalone**:
  `DL, HE, HS, HSk, SJ, ML, REML, EB, PM, PMM`. Passing `"GENQ"` or
  `"GENQM"` now raises a specific, explanatory error (these ARE real
  metafor method names, just not usable here without a feature this
  package doesn't yet have, so the generic "method must be one of"
  list would be misleading); passing `"CO"` or any other unsupported
  string still gets the generic list.
* Cleaned up the internal method-to-label helper (`.tsahr_method_label`)
  to drop the now-invalid `"CO"` entry.
* Updated `@param method` in `R/tsa_hr.R` and `man/tsa_hr.Rd` to list the
  correct 10 methods and explain why the other 3 aren't supported.
* **New test** (`"every advertised method value runs and returns a valid
  object"`) exercises all 10 currently-supported methods on the bundled
  example data, plus explicit tests that `"CO"`/`"GENQ"`/`"GENQM"` each
  fail with the right error message -- so a similar gap can't recur
  silently.
* This is a genuine behavior change for anyone who was passing
  `method = "CO"`, `"GENQ"`, or `"GENQM"`: those calls were already
  failing before this release (with a less legible error from inside
  `metafor::rma()`), so no one could have been relying on them
  succeeding -- this release only makes the failure explicit and
  immediate, with a clearer message.

### Documentation fix: final futility boundary wording

* **`R/tsa_hr.R` and `man/tsa_hr.Rd` incorrectly stated that the final
  futility boundary "equals the same value as the final efficacy
  boundary."** It doesn't, and the actual code never implied it should:
  ```r
  beta_final <- min(qnorm(1 - alpha_two_sided / 2), tail(alpha_bounds_design, 1))
  ```
  Since the sequentially-adjusted final efficacy boundary is virtually
  always at or above the conventional `qnorm(1-alpha/2)` value, `min()`
  almost always selects the conventional value instead -- confirmed
  numerically on the bundled example data (2.0786 for the final
  efficacy boundary vs. 1.959964 for the final futility boundary).
  Practical consequence: for `1.96 < |Z| < 2.08` (using that example),
  conventional p<.05 is YES, the TSA efficacy boundary is NO, and the
  futility region is also NO -- a legitimate intermediate state the old
  wording obscured. Wording corrected in both files to describe the
  final futility boundary as "the conventional two-sided alpha critical
  value at the definitive analysis," not as equal to the efficacy
  boundary. New regression test
  (`"final futility boundary is the conventional critical value, not
  the final efficacy boundary"`, `test-daris-futility-stop.R`) pins
  this numerically so it can't silently drift back.

### Other fixes and improvements from the audit

* **`D2_raw` and `D2_was_capped`** added to the returned `heterogeneity`
  list, alongside the existing (possibly-capped) `D2` -- so a downstream
  user can tell "D2 genuinely computed as 0.999" apart from "D2 was
  capped here from something larger/degenerate" instead of the capping
  being silent. Documented in `@return`/`\value{}`.
* **`Study` identifiers are now validated** as non-missing and
  non-empty (previously only checked for duplicates).
* **`order_by` now warns on tied values** (previously only warned on
  `NA`s and non-numeric/non-Date types) -- TSA is order-dependent, so
  the relative order of tied studies can matter.
* **`target_HR` very close to 1 (0.90-1.10, excluding exactly 1, which
  is still a hard error) now triggers a warning, not silence** --
  required information size grows rapidly as `log(target_HR)` -> 0
  (e.g. `target_HR=0.95` needs roughly 4x the information of
  `target_HR=0.90` for an otherwise identical design), so this is a
  nudge to confirm the target is intentional, not a defect.
* **Random-effects caveat reworded** in `R/tsa_hr.R` and `man/tsa_hr.Rd`
  to the more precise framing: the canonical Lan-DeMets/O'Brien-Fleming
  theory assumes a fixed, canonical information process with independent
  Brownian-motion increments, and tsahr's random-effects (tau^2
  re-estimated at every look) Z-process doesn't exactly satisfy that --
  rather than the previous, slightly imprecise "holds exactly only for
  a fixed-effect cumulative process."
* **Plot methods caption reworded**: "Non-binding futility: RTSA
  retrospective inner-wedge algorithm, O'Brien-Fleming-type
  beta-spending (bsOF)" instead of "approximate O'Brien-Fleming-type
  beta-spending (bsOF)" -- the engine is a specific, documented,
  reverse-engineered RTSA algorithm (see
  `inst/REVERSE_ENGINEERING_RTSA.md`), not a generic approximation.
* **README's `method` section reworded** to the more precise framing:
  `method` does not change the mathematical alpha-spending function or
  boundary-calculation algorithm, but it DOES change `tau^2`, the
  cumulative information schedule, and therefore which study lands on
  which information fraction -- so it can still change the practical
  timing of a boundary crossing indirectly, which the previous wording
  understated.

# tsahr 0.2.6.5

## Input-validation fix, three real documentation bugs, and two judgment calls left as-is (documented, not silently resolved)

Prompted by an external (ChatGPT) review; each item below was checked
against the actual code before acting on it, not applied at face value
-- see the per-item notes.

* **`allocation_p` validation hardened.** `allocation_source = "manual"`
  with `allocation_p = NA`, a length>1 vector, or a non-numeric value
  previously could reach a generic/uninformative R error (e.g. "missing
  value where TRUE/FALSE needed" for `NA`) instead of the package's own
  informative message. Confirmed by direct testing before fixing, not
  just taken on faith. Now validates `is.numeric()`, `length() == 1L`,
  and `is.finite()` before the range check, with three new regression
  tests (`NA`, `c(0.5, 0.6)`, `"0.5"`) added to `test-tsa_hr.R`.
* **Fixed: stale `man/tsa_hr.Rd`, out of sync with `R/tsa_hr.R` in three
  compounding ways.** The source's roxygen documentation had already
  been updated in previous releases, but `man/tsa_hr.Rd` was never
  regenerated to match, so it still said `info_fraction` "is capped at
  1 for every subsequent look" (false -- only the boundary/decision
  *mapping* is capped via `pmin(info_fracs, 1)`; the stored
  `cumulative$info_fraction` itself is not, and can exceed 1, e.g.
  1.0126, after DARIS) and "...computed at the **exact** accrued
  statistical information" (the source had already been corrected to
  "observed"). The Rd was also entirely missing the source's current
  "Retrospective boundary timeline" paragraph (about `boundary_timeline`
  and the synthetic `t=1` point), still showing an older, superseded
  "Looks after DARIS is reached" paragraph instead. `man/tsa_hr.Rd` is
  resynced to the current source. If you use roxygen2/devtools to
  regenerate docs going forward, this class of drift won't recur; for
  now the fix was done by hand since no R was available in this
  session.
* **`boundary_timeline` and the caveated components of `results` are
  now documented in `@return`/`\value{}`** (both the roxygen source and
  the Rd), including that `results$entered_futility_region == TRUE` at
  the DARIS-reaching look reflects a comparison against the *definitive*
  `t=1` futility boundary, not an interim one, and is not itself a
  formal stopping recommendation -- that caveat previously existed only
  in the printed/verbose console output, not in the object a caller
  gets back programmatically.
* **`crossed_conventional`'s full-cumulative-curve scope (as opposed to
  `crossed_tsa`'s decision-horizon-restricted scope) is now an explicit,
  documented design choice, not left ambiguous.** Checked directly:
  yes, `crossed_conventional` uses the unrestricted `cumul_df$Z`
  (including studies added after DARIS) while `crossed_tsa` is
  restricted to `decision_idx` -- these do answer genuinely different
  questions. Concluded this is intentional (the printed label already
  says "Cumulative Z-curve crossed...", and contrasting it with the
  properly-scoped `crossed_tsa` line illustrates exactly the
  repeated-testing inflation risk TSA exists to guard against), so
  **behaviour is unchanged** -- but this was a judgment call, not a
  certainty, so it's now spelled out in both a code comment and
  `?tsa_hr` rather than left for a future reader to guess at. If you
  intended the decision-horizon-restricted reading instead, that's a
  one-line change (see the code comment above `crossed_conventional`
  for the exact replacement) -- flag it and it'll be made explicitly
  rather than silently.
* **`README.md`** now states explicitly that `method` (the
  heterogeneity-variance estimator) affects `tau^2`, the random-effects
  cumulative Z-curve, and D-squared/DARIS-related quantities, but does
  **not** change the alpha-spending function or TSA monitoring
  boundaries themselves.
* **Not done, needs your input:** a concrete multi-look RTSA beta-
  boundary regression test (paralleling the existing
  `rtsa_reported <- c(4.877, 3.357, 2.680, 2.290, 2.031)` alpha test).
  This needs an actual reference vector from a live
  `RTSA::boundaries()` call with a beta-spending function, the same way
  the alpha reference came from your own live RTSA session in 0.2.5.2 --
  no R is available in this environment to run it, and I won't fabricate
  reference numbers. Send the output of a call like
  `RTSA::boundaries(timing=c(...), alpha=0.05, beta=0.20, side=2,
  es_alpha="esOF", es_beta="esOF")` and this test gets added properly.

# tsahr 0.2.6.4

## Cosmetic: superscript "2" in "Diversity D2" on the TSA plot

* `plot.tsa_hr()`'s subtitle and methods caption now render "Diversity
  D²" using the Unicode superscript-two character (U+00B2), matching
  the existing convention elsewhere in the package (e.g. the tau²
  console note added in 0.2.5.1), instead of adding a new dependency
  (e.g. `ggtext`) just for this. Purely cosmetic -- no change to any
  computed value, and `x$heterogeneity$D2` (the underlying R variable
  and list element name) is unchanged, since it must stay valid R
  syntax. Not changed in this release: the "Diversity D2" wording in
  `summary.tsa_hr()`'s printed table and in the near-boundary warning
  message from `tsa_hr()` -- only the plot was in scope for this fix.

# tsahr 0.2.6.3

## Cleanup: removed dead `.beta_spend_OF()` and fixed the stale doc pointing at it

* **Removed `.beta_spend_OF()`** (`R/obf_boundaries.R`), the un-doubled
  candidate beta-spending formula `beta*(t) = 1 - Phi(z_beta/sqrt(t))`.
  It was flagged as dead code when the RTSA-matched beta/futility engine
  was added in 0.2.4: the actual boundary-solving path has used
  `.rtsa_beta_spend_OF()` (`beta*(t) = 2*(1 - Phi(z_{beta/2}/sqrt(t)))`,
  reverse-engineered directly from RTSA's `getInnerWedge()` -- see
  `inst/REVERSE_ENGINEERING_RTSA.md`) ever since, and `.beta_spend_OF()`
  was never called from anywhere in that path. Not a behaviour change --
  `tsa_hr()`'s output is identical before and after this release.
* **Fixed the top-of-file "Methodology" comment for beta-spending**,
  which described `.beta_spend_OF()`'s (dead, un-doubled) formula as
  though it were what the package actually computes. It now describes
  `.rtsa_beta_spend_OF()`'s real (doubled) formula instead, with a
  pointer to `inst/REVERSE_ENGINEERING_RTSA.md`.
* **Removed the now-orphaned test** ("beta-spending function targets
  total spend = beta (not 2*beta) at t=1", `test-tsa_hr.R`), which
  exercised only the deleted dead function. The equivalent property for
  the function actually in use is already covered by "RTSA beta
  spending formula is used" in `test-boundaries-rtsa.R`.

# tsahr 0.2.6.2

## Doc fix: `R/obf_boundaries.R`'s VALIDATION section contradicted itself — and one of the two contradicting claims turned out to be based on a units mix-up, not a real gap

(Supersedes an interim 0.2.6.1 that introduced this fix but also
introduced a second, separate documentation problem -- see below.)


* **The `VALIDATION` comment block in `R/obf_boundaries.R` said two
  incompatible things about the same question.** One passage stated
  the full 5-look boundary schedule had been checked end-to-end
  against live `RTSA::boundaries()` output and matched "essentially
  exactly"; a later passage in the same block said only the first look
  had ever been checked (in closed form) and explicitly warned readers
  that the rest was unverified. These cannot both be true, and
  `inst/REVERSE_ENGINEERING_RTSA.md` disagreed with the second passage
  too (it also claimed the full comparison was done) -- so the two
  files disagreed with each other on top of the R file disagreeing
  with itself.
* **The full 5-look comparison against RTSA turns out to have been done
  correctly, and the "essentially exactly" claim holds up** — once
  compared against the right numbers. RTSA::boundaries() was called
  with `timing = c(0.2, 0.4, 0.6, 0.8, 1.0)`; it reports back a rounded
  `SMA_Timing` column (0.205, 0.409, 0.614, 0.818, 1.023) reflecting its
  internal event-count discretisation, and at one point during this
  package's development that reported (rounded) column got used as the
  comparison input instead of the nominal schedule that was actually
  requested. Since the first-look boundary is an exact, closed-form
  function of the timing value fed in, that mismatch alone produces a
  spurious ~0.06 "discrepancy" that has nothing to do with the formula
  or the recursive engine. Using the correct nominal timing, an
  independent from-scratch Python port of `.obf_alpha_boundary()`
  reproduces all 5 of RTSA's reported boundaries to within
  ~0.003-0.006 -- even at this engine's long-standing default of
  `n_grid=2000` -- consistent with "essentially exactly".
* **A previous draft of this note (and of this release) additionally
  claimed a specific, more severe grid-coarseness problem at
  n_grid=2000** -- boundaries of 4.877, 3.358, 2.703, 2.307, 2.064
  (~0.03 error at the final look), improving to ~0.0044 only once
  n_grid was raised to 16000, with a cited progression of
  0.0325/0.0133/0.0074/0.0044/0.0020 as n_grid rose from 2000 to
  32000. **That specific set of numbers could not be reproduced** by
  the independent Python port described above (which found ~0.003-0.006
  error already at n_grid=2000, not ~0.03) and was never confirmed by
  an actual run of this package's R code in an environment with R
  available. It is being retracted from this release's documentation
  as unverified, rather than repeated as an established finding.
* **`.obf_alpha_boundary()`'s default `n_grid` is still raised from
  2000 to 16000** in this release, but the justification is narrower
  than previously stated: not "fixes a confirmed ~0.03 error", but "a
  conservative, essentially-free accuracy margin" -- FFT-based
  convolution makes the extra grid resolution cheap for this package's
  actual usage pattern (a handful of interim looks per `tsa_hr()` call),
  so there's no real cost to preferring the larger grid even without a
  confirmed problem at 2000. `bmax` is unchanged. Anyone who can run
  the real R implementation is encouraged to confirm (or correct) the
  Python-based numbers above -- see the VALIDATION note in
  `R/obf_boundaries.R` for the exact snippet to run.
* **Regression test** (`test-alpha-spend-rtsa.R`) pins the full
  recursive-engine output against all 5 RTSA reference boundaries
  (using the correct nominal timing) at a 0.01 tolerance. Based on the
  Python check above this is expected to pass at both n_grid=2000 and
  n_grid=16000, not only at the new default -- unlike what an earlier
  draft of this test's own comment claimed.
* No change to `.alpha_spend_OF()` itself, the beta/futility engine, or
  anything else; this release is scoped entirely to documentation
  accuracy and the default grid resolution.

# tsahr 0.2.6

## Bug fix: alpha-spending formula did not match this package's own reference methodology (correctness — please upgrade)



* **`.alpha_spend_OF()`'s two-sided alpha-spending formula was wrong for
  the methodology this package documents itself as implementing**, and
  is corrected in this release. `tsa_hr()`'s O'Brien-Fleming-type
  efficacy boundaries were computed with
  `alpha*(t) = 2*(1-Phi(z_{alpha/2}/sqrt(t)))` in every prior tsahr
  release (0.2.0-0.2.5.1). That form is a textbook Lan-DeMets
  two-sided spending function — it's internally valid as *a* spending
  function (it does reach exactly `alpha` at t=1) and is quoted as-is
  in some general group-sequential-design references (e.g. gsDesign's
  documentation) — but it does **not** match the specific TSA
  methodology (Copenhagen Trial Unit / RTSA, Thorlund et al.) that this
  package documents itself as following (Miladinovic et al. 2013,
  Wetterslev et al. 2009). The corrected formula is
  `alpha*(t) = 4*(1-Phi(z_{alpha/4}/sqrt(t)))` -- RTSA's own
  `side`-parameterised spending function evaluated at `side=2`.
* **Confirmed directly against a live `RTSA::boundaries()` call**
  (`timing=c(0.2,0.4,0.6,0.8,1), alpha=0.05, side=2, es_alpha="esOF"`),
  which returns boundaries 4.877, 3.357, 2.680, 2.290, 2.031 -- matching
  the corrected formula (run through tsahr's existing recursive
  integration engine) essentially exactly, across all 5 boundaries of
  that schedule, and clearly distinguishable from the pre-correction
  formula's 4.383, 3.099, 2.554, 2.254, 2.063 for the same schedule. A
  first-look regression test (`test-alpha-spend-rtsa.R`) locks in the
  corrected value against this RTSA reference in closed form.
* **Practical impact:** the old formula spent alpha noticeably faster
  at early looks than the corrected version -- roughly 9-11x more
  budget at the first look of the K=5 reference schedule above --
  i.e. it was less conservative than intended early in monitoring,
  which works directly against the reason people choose an
  O'Brien-Fleming design in the first place (strong protection against
  declaring "significance" from sparse early evidence). The corrected
  formula is more conservative early and correspondingly less
  conservative at the final look (2.031 vs the old 2.063 for the same
  K=5 example), while, like the old formula, still reaching exactly the
  nominal alpha at t=1 by construction. Anyone who used `tsa_hr()` from
  a version between 0.2.0 and 0.2.5.1 for TSA boundaries at an interim
  look (not just a completed, fully-informed meta-analysis) should
  re-run their analysis with this version.
* **Why this was not caught by prior validation:** both the old and
  corrected formulas independently satisfy alpha*(1) = alpha (any
  correctly normalised spending function does), which is exactly what
  the pre-existing Monte Carlo and closed-form checks in
  `R/obf_boundaries.R` confirm -- they check the *total* spend, not the
  *shape* across interim looks. This bug is a genuinely separate
  property from what those checks were ever positioned to catch, not a
  contradiction of them.
* **Re-validated under the corrected formula**, not just assumed
  correct by construction: a 20,000-replicate Monte Carlo (K=2, K=3
  unequally spaced, K=5, K=10) against the corrected spending function
  gave empirical type-I error of 4.35%-4.93% against a 5% nominal
  target (Monte Carlo SE ~=0.15%) -- consistent with correct behaviour.
  See the updated `VALIDATION` note at the top of `R/obf_boundaries.R`
  for the full numeric account, and `inst/REVERSE_ENGINEERING_RTSA.md`
  for the alpha-engine analogue of the beta-engine writeup added in
  0.2.4.
* Only `.alpha_spend_OF()` and its documentation changed. The recursive
  integration engine that solves for the actual sequential boundaries
  given a spending function (the FFT-based convolution machinery) is
  untouched, as is the beta/futility engine (which is non-binding,
  advisory-only, and doesn't affect type I error control), DARIS
  calculation, and everything else in the package. No existing test
  asserted a specific numeric alpha-boundary value tied to the old
  formula (the one test that checks a specific constant, "internal OF
  alpha boundary is consistent with the classical O'Brien-Fleming
  boundary", uses a tolerance of 0.05 around the published ~2.040
  reference and still passes under the corrected formula's ~2.031
  final-look value); no existing test changes were needed.

# tsahr 0.2.5.1

## Minor

* `tsa_hr()`'s verbose console output now ends with a final note on the
  practical impact of the `method` (τ² estimator) choice: it may have
  limited influence on the pooled effect-size when the evidence base is
  substantial, but can materially influence heterogeneity-dependent
  quantities, prediction intervals, DARIS, and the timing of TSA
  conclusions -- particularly when cumulative information is near the
  DARIS threshold.

# tsahr 0.2.5

## New feature

* **`tsa_hr()` gains a `method` argument** to choose the heterogeneity-variance
  (tau^2) estimator used for the random-effects meta-analysis and the
  cumulative (sequential) TSA model, passed straight through to
  \code{metafor::rma(method = ...)}. Accepts any of metafor's random-effects
  estimators: \code{"DL"} (DerSimonian-Laird), \code{"HE"} (or its alias
  \code{"CO"}), \code{"HS"}, \code{"HSk"}, \code{"SJ"}, \code{"ML"},
  \code{"REML"}, \code{"EB"}, \code{"PM"}, \code{"GENQ"}, \code{"PMM"}, or
  \code{"GENQM"}. **Default remains \code{"DL"}** for full backward
  compatibility with all earlier tsahr versions (which always used
  DerSimonian-Laird internally and offered no choice) -- this is a
  deliberate difference from \code{metafor::rma()}'s own default of
  \code{"REML"}. An invalid `method` value now fails fast with a clear
  error listing the accepted values, rather than propagating into
  `metafor::rma()`.
* The console header (`"=== Random-effects (...) meta-analysis ==="`) and
  the plot caption (`"Methods: Random-effects (...) model, ..."`) now
  reflect whichever `method` was actually used, instead of always saying
  "DerSimonian-Laird".
* The equal-effects model used internally for the Diversity (D^2)
  heterogeneity adjustment is unaffected by this change -- it is still
  always fitted with `method = "FE"`, regardless of the new `method`
  argument, so D^2 retains its original definition. Alpha-/beta-spending
  boundary calculations (the O'Brien-Fleming-type spending functions) are
  also unaffected -- this release does not touch, and does not validate
  against `rpact`, any of that machinery.
* `tsa_hr()`'s returned `parameters` list now includes the `method` that
  was used, for downstream inspection/reporting.

# tsahr 0.2.4.8

## Bug fix (from a real `R CMD check --run-donttest` run, Windows)

* **ERROR fixed:** the `plot.tsa_hr()` example crashed with `conversion
  failure ... in 'mbcsToSbcs': for \u2248 (U+2248)`. The DARIS-information
  marker label used the Unicode "almost equal to" character (`\u2248`) in
  text handed to `ggplot2::annotate()`; on Windows, grid's text-drawing
  routine tries to convert the string to the graphics device's native
  single-byte codepage, and that conversion hard-fails for a codepage
  that can't represent U+2248 (this is a real, environment-dependent
  crash for affected users generally, not just a check artifact -- R CMD
  check's "non-ASCII characters" step doesn't catch it because it checks
  source-file encoding declarations, not runtime grid-rendering behavior
  on a given codepage). Replaced with a plain ASCII `~`, matching the
  sibling "Theoretical DARIS event-equivalent ~ ..." label two lines
  above, which already used `~` for the identical "approximately"
  meaning. Confirmed no other non-ASCII characters (literal or `\u`
  escapes) remain anywhere in `R/`.

# tsahr 0.2.4.7

## Bug fixes (from a real `R CMD check` run)

* **NOTE fixed:** `tail()` was called bare (no namespace qualification) in
  `.rtsa_beta_boundary()` (`R/obf_boundaries.R`, 2 call sites) and in
  `tsa_hr()` (`R/tsa_hr.R`). Changed to `utils::tail()` at all three sites,
  consistent with this package's existing convention of explicit
  `pkg::fn()` calls rather than blanket `importFrom` — no NAMESPACE change
  needed.
* **Test failure fixed:** `"caption size/face are customizable and
  actually applied"` asserted `expect_null(p_none$theme$plot.caption)`
  for `plot(res, caption = FALSE)`. `plot.tsa_hr()`'s actual behavior here
  was already correct (the whole `labs(caption = ...)` +
  `theme(plot.caption = ...)` block is skipped when `caption = FALSE`) --
  the test itself was the problem: newer, S7-based ggplot2 theme objects
  resolve an *unset* `plot.caption` slot to an inherited `element_text`
  object when accessed via `$`, rather than the literal `NULL` older
  ggplot2's plain-list themes returned, so the assertion broke purely from
  a ggplot2 version upgrade, not from any change in tsahr. Replaced the
  check with `expect_null(p_none$labels$caption)`, which tests the actual
  intent (`labs(caption = ...)` was never called) and is stable across
  ggplot2's internal theme representation.

# tsahr 0.2.4.6

## New feature

* `plot.tsa_hr()` gains two new arguments for the methods caption at the
  bottom of the plot (previously fixed at size 8, italic):
    - `caption_size`: font size (default `8`, unchanged from before).
    - `caption_face`: font face, e.g. `"italic"` (default, unchanged from
      before) or `"plain"`; also accepts anything
      `ggplot2::element_text()` understands for `face` (e.g. `"bold"`,
      `"bold.italic"`).
  Example: `plot(res, caption_size = 10, caption_face = "plain")`.

# tsahr 0.2.4.5

## Test-suite fixes, following a self-reported regression review of 0.2.4.4

This release does **not** change any file under `R/` -- `tsa_hr.R`,
`methods.R`, and `obf_boundaries.R` are byte-identical to 0.2.4.4 (this
was verified directly, not assumed). Both the alpha-boundary recursive
engine and the RTSA-matched beta-boundary engine are unchanged, per
explicit instruction that both are deliberate design choices, not bugs
to be second-guessed here.

A review of 0.2.4.4 claimed three things: (1) the alpha-spending formula
had "regressed" to a one-sided-parameterized bug, with a specific claim
that the correct first-look boundary was 4.88 rather than 4.38; (2) the
package fails `R CMD check` with real errors, not just warnings, due to
a test file that used `readLines(file.path("R", "tsa_hr.R"))` (a
relative path that does not exist when tests run against an installed
package) and a second test asserting stale (pre-RTSA-match) behavior at
the final look; (3) none of this had ever actually been run.

Each claim was checked independently before acting on it (this
environment also has no R, so "checked" here means independent
recomputation in Python, not running the package itself):

* **Claim 1 (alpha regression): not substantiated, and not changed.**
  `.alpha_spend_OF()` -- `2*(1-Phi(z_alpha/2/sqrt(t)))` -- was
  independently re-verified via a closed-form (non-simulation) 2D
  integration at a schedule matching the disputed case (t1=0.0716): the
  resulting first-look boundary was 7.3247, which (a) exactly matches
  the elementary closed-form O'Brien-Fleming approximation
  z_alpha/sqrt(t1) at that t1, (b) reproduces an overall two-sided alpha
  of 0.0498 against a 0.05 target via the same independent integration,
  and (c) matches the 7.32 tsahr originally reported for this same
  scenario several revisions ago. No evidence for "4.38 vs the correct
  4.88" could be reproduced. If a genuine discrepancy against a specific
  rpact/RTSA run persists, the most likely explanation remains a
  difference in the information-fraction SCHEDULE the two tools were
  given (see "Information-fraction convention" in `?tsa_hr`), not this
  formula. See the VALIDATION note in `R/obf_boundaries.R` for the full
  account, including this specific re-check.

* **Claim 2 (test failures): confirmed, and fixed.** Both specific
  problems were independently reproduced by inspection/computation:
    - `test-daris-futility-stop.R` did use a working-directory-dependent
      `readLines()` call that regex-matched literal source text rather
      than testing behavior. This has been REPLACED (not merely patched)
      with genuine behavioral tests that call `tsa_hr()` and check
      properties of its actual return value. Note: an intermediate
      "clean" revision had already replaced this file with a
      behavioral-style test, but with a dataset that does not actually
      reach DARIS under the stated design (3 studies of 30 information
      units each, needing ~157.6 to reach DARIS at target_HR=0.80) --
      this was caught by direct recomputation before being trusted, and
      the dataset was corrected (100 information units/study) so the
      test's own stated premise ("DARIS reached at look 2") is actually
      true. That revision's alpha-boundary reference check was also
      wrong in a different way: it compared against
      `.obf_alpha_boundary(1, alpha=0.05)` -- a trivial SINGLE-look
      calculation (numerically just `qnorm(1-alpha/2)`=1.960) -- against
      the real MULTI-look recursive final boundary, which is a
      different, larger quantity (verified numerically: ~1.992 for the
      schedule in question, a difference far outside the test's stated
      tolerance). Fixed to compute the reference via the actual
      multi-look sequence the code path constructs.
    - `test-tsa_hr.R` asserted `is.na(b40[length(b40)])` ("no futility
      decision at final look"), contradicting the RTSA-matched engine's
      deliberate behavior (confirmed present in the actual code:
      `b[length(b)] <- stats::qnorm(1 - alpha / 2, ...)` in the relevant
      branch) of assigning a definitive final-look futility value rather
      than leaving it undefined. Updated to assert the actual (correct,
      deliberate) value.

* **Claim 3 (nothing was ever run): accurate as a description of the
  limits of this environment, which also has no R.** Every check in this
  release was performed by independent recomputation (Python/scipy for
  the numerical claims, direct source inspection and manual data-value
  computation for the test-correctness claims) rather than by running
  the actual package, and that limitation is stated here rather than
  implied away. `devtools::check()`/the test suite should still be run
  in a real R environment before relying on this release.



* Corrected the retrospective boundary endpoint when DARIS is reached: the
  formal alpha/futility curves now terminate at the interpolated cumulative
  event coordinate corresponding to the observed DARIS information threshold,
  rather than at the theoretical Schoenfeld event-equivalent DARIS.
* The theoretical DARIS event-equivalent remains displayed as a separate
  reference line.
* The cumulative Z curve and observed-study data remain unchanged.
* Preserved the 0.2.4.3 early futility-boundary values. The final-endpoint
  correction does not recompute the RTSA beta recursion with a synthetic
  t = 1 endpoint, because doing so would alter the earlier futility looks.

# tsahr 0.2.4.2

* Added an additional guard so the displayed non-binding beta/futility boundary is capped at the corresponding alpha/efficacy boundary.
* Retained the RTSA retrospective beta engine and the post-DARIS suppression introduced in 0.2.4.1.

## tsahr 0.2.4.1

- Stop displaying/reporting non-binding beta/futility boundaries at and after the first look that reaches DARIS.
- Retain the RTSA retrospective beta engine internally; post-DARIS observations are treated as definitive/final rather than additional futility looks.

# tsahr 0.2.4 corrected RTSA futility output

- Corrected RTSA/CTU retrospective futility output so non-positive early
  futility values are returned as `NA`, matching RTSA's `beta_ubound`
  post-processing rather than plotting them as negative boundaries.

# tsahr 0.2.4

## Beta/futility boundary engine

* Replaced the previous approximate non-binding futility engine with a
  literal R port of the retrospective `tsa_beta_bound` / `getInnerWedge()`
  algorithm in RTSA, which itself documents the old TSA functions as
  translated from the original Copenhagen Trial Unit Java TSA software.
* The beta O'Brien-Fleming spending function is
  `2 * (1 - Phi(qnorm(1-beta/2) / sqrt(t)))`.
* The engine recursively constructs the null-referenced symmetric inner
  wedge using the original trapezoidal numerical integration and iterative
  boundary search, then applies RTSA's empirical drift construction.
* For observed information exceeding 1, the RTSA analysis-mode convention
  is followed: the wedge is computed only for `t < 1` and the definitive
  futility boundary is the conventional two-sided alpha quantile.
* `TSA$beta_engine` exposes the RTSA-derived diagnostics.

# tsahr 0.2.3

Built from the 0.2.2 release (not from an interim 0.2.3 that had
unrelated problems and was withdrawn), applying fixes from a further
external statistical review of the 0.2.2 source.

## High priority

* **Fixed repeated formal testing after DARIS is reached.** Once the
  observed accrued information first reaches DARIS at some look k,
  `info_fraction` was already capped at 1 for every subsequent look --
  but `crossed_tsa` and `entered_futility_region` were previously
  computed with `any()` across ALL looks, meaning every look after DARIS
  was reached got tested against the same final (t=1) boundary as if
  each were an independent additional "final analysis". This is not
  accounted for by the alpha-spending calculation, which treats t=1 as a
  single final look. Fixed: both verdicts are now evaluated only through
  the FIRST look at which DARIS was reached, exposed as the new
  `results$final_tsa_look` (equal to the total number of looks if DARIS
  was never reached). The full cumulative Z-curve, including any studies
  added after DARIS, is still returned and plotted in full -- only the
  formal sequential decision is restricted, not what is shown. `verbose`
  output now prints a note identifying which look this was, when
  relevant.

## Important

* **Fixed an incorrect DOI.** DESCRIPTION and `inst/CITATION` cited
  Miladinovic et al. (2013) with DOI `10.1016/j.jclinepi.2013.01.007`,
  which belongs to an unrelated article ("How to write a research
  paper"). Corrected to the actual DOI, `10.1016/j.jclinepi.2012.11.007`
  (verified against PubMed/ScienceDirect/Wikidata, not just taken on
  trust).
* Plot legend label renamed from "Beta boundaries" to "Non-binding
  futility boundaries", and the caption now reads "approximate
  O'Brien-Fleming-type beta-spending futility boundaries", so the label
  doesn't imply the same validation status as the efficacy boundaries.

## Moderate

* Added scalar validation for `alpha_two_sided` and `power` (must be
  finite, length-1, strictly between 0 and 1) and for `target_HR` (must
  be a single finite value, or `NA`) -- previously e.g.
  `alpha_two_sided = 2` would silently propagate into `qnorm()` rather
  than being rejected with a clear message.
* `tsa_hr()` now requires at least two studies (`stop`), and warns (not
  errors) below 10 studies, since heterogeneity/D2 -- and therefore
  DARIS and the monitoring boundaries -- can be unstable with few
  studies (per the Copenhagen TSA manual's own caution on this point).
* Event counts and sample sizes (`Events_Treatment`, `N_treatment`,
  `Events_controls`, `N_controls`) must now be whole numbers.
* Added explicit tests reproducing both directions of the DARIS
  event-equivalent vs. information-threshold disagreement (constructed
  with homogeneous, D2=0 synthetic data so the direction is
  deterministic rather than incidental), plus tests for all the new
  validation and for `final_tsa_look`.
* Fixed a mislabeled test: `seq(0.02, 1, length.out = 39)` was commented
  as "K=39, unequally spaced" but is in fact equally spaced (constant
  step). Replaced with a genuinely unequal schedule,
  `(seq_len(39)/39)^1.4` with the last point fixed at 1.

## Minor

* Neutralized wording in the verbose output that explained a difference
  between the theoretical DARIS event-equivalent and the observed
  information threshold as always being because studies were "more
  informative" -- this can go either direction (see the two new tests
  above), so the message no longer implies a single direction.
* Removed the accidental `tests/testthat/Rplots.pdf` build artifact from
  the package source, and added a `.Rbuildignore` to keep future stray
  plot output from being shipped.

## Explicitly not addressed in this release

Per the same reviewer's own priority ranking, and consistent with prior
NEWS entries: the two-sided beta/futility betaAdjustment geometry and
independent numerical comparison against another group sequential
package (e.g. rpact) both remain open. The next step recommended in the
0.2.2 review -- and still the recommendation here -- is external
numerical validation against an established group-sequential
implementation.

# tsahr 0.2.2

## Methodological fixes, prompted by external statistical review

* **Beta/futility spending fixed.** `.beta_spend_OF()` was reusing the
  same "doubled" form as the alpha-spending function, which made its
  cumulative target at t=1 equal `2*beta` (e.g. 0.40 for the default
  `beta=0.20`) rather than `beta`. The alpha function's doubling reflects
  genuine two-tailed spending (symmetric outer rejection regions); the
  futility construction instead targets a single central "inner wedge"
  and should not be doubled. Fixed to `beta*(t) = 1 - Phi(z_beta/sqrt(t))`,
  which reaches exactly `beta` at t=1. This only affects the non-binding,
  advisory futility band -- it has no effect on type-I error control
  (governed entirely by the independently-validated alpha engine).

* **Independent verification performed** (this environment has no R, so
  this was done via a faithful line-by-line Python/scipy reimplementation
  of `R/obf_boundaries.R`, cross-checked three independent ways):
    - A direct (non-simulation) closed-form 2D numerical integration for
      K=2 confirmed the alpha boundaries deliver almost exactly the
      intended overall two-sided alpha (0.0506 vs a 0.05 target).
    - A 100,000-replicate Monte Carlo across five look-schedules (K=2 to
      K=39, equal and unequal spacing) gave empirical type-I error of
      5.02%-5.22% against nominal 0.05 in every configuration, with no
      degradation at larger K.
    - The non-binding futility engine was checked the same way and found
      to be a harder quantity to calibrate precisely (the realised
      futility-stopping and power probabilities under H1 deviate from
      their nominal targets by single-digit percentage points, even
      after the fix above); this is now documented explicitly in
      `R/obf_boundaries.R` rather than left as an implicit assumption.
  See the `VALIDATION` comment block at the top of `R/obf_boundaries.R`
  for the full write-up. No comparison against `rpact` specifically was
  possible (no R available in this environment); this validation is
  independent of, and in addition to, the package's own R test suite.

* **Terminology tightened.** `info_accrued`/`info_fraction` are now
  documented explicitly as *reported, study-level* inverse-variance
  information (`sum(1/SE^2)` from each study's reported standard error),
  not the exact Fisher information of the cumulative random-effects
  estimator -- since `tau^2` is re-estimated at every cumulative look
  under the random-effects model, these are not exactly the same
  process. "Exact" language was removed from code comments, roxygen
  docs, and the alpha-boundary test description; replaced with
  "observed"/"reported" and a note that the Lan-DeMets alpha-spending
  approximation to O'Brien-Fleming (used here) is closely related to,
  but not numerically identical to, the original O'Brien-Fleming (1979)
  construction.

* **D2 cap wording clarified**: the 99.9% cap on Diversity D2 is
  documented as a purely numerical safeguard against division by
  (near-)zero, not a statistically justified correction.

* **Stronger input validation**: `tsa_hr()` now explicitly checks
  `Events_Treatment`, `N_treatment`, `Events_controls`, and `N_controls`
  for finite values (previously NA/NaN/Inf could silently pass some of
  the range checks, since comparisons against non-finite values return
  `NA` rather than `TRUE`/`FALSE`).

* **New `order_by` argument** for `tsa_hr()`: optionally names a column
  to explicitly sort by (ascending, e.g. a publication-year column)
  before the cumulative analysis, rather than relying solely on however
  the input data happened to be ordered. Default `NULL` preserves the
  previous behaviour (row order assumed chronological), with a printed
  reminder that `order_by` is available.

* Expanded the alpha-boundary Monte Carlo test to include a K=39
  unequally-spaced configuration, and added a unit test asserting the
  corrected beta-spending function reaches exactly `beta` (not `2*beta`)
  at t=1.

## Not addressed in this release

Two items from the external review are explicitly **not** resolved here,
and are flagged for a future release rather than attempted without
adequate tooling:

* A rigorous, betaAdjustment-style geometric reconciliation of the
  two-sided efficacy/futility decision regions (the current
  implementation already bounds the futility search within the fixed
  efficacy boundary and skips infeasible targets, which prevents the
  boundaries from crossing, but this is not the same as a fully
  validated joint two-sided beta-spending construction).
* A like-for-like numerical comparison against `rpact` (or another
  independently validated group-sequential package) for a range of K
  and information schedules -- not possible in an environment without R.

# tsahr 0.2.1

## New feature

* `plot.tsa_hr()` gains a `show_theoretical_daris` argument (default
  `TRUE`). Set `show_theoretical_daris = FALSE` to hide the theoretical
  DARIS event-equivalent reference line/label (e.g. when only the
  observed-information "DARIS information reached" marker is of
  interest, or to reduce clutter). This only affects what is drawn --
  the underlying DARIS calculation and the printed "DARIS reached"
  verdict are unchanged.

## Bug fix

* Fixed a discrepancy where `verbose`/`print()` output could report
  `Required information size (DARIS) reached: YES` while `plot()` still
  showed the cumulative Z-curve short of the DARIS reference line (or vice
  versa).

  Cause: `plot.tsa_hr()` placed its DARIS vertical line at the
  **theoretical** event-equivalent of the required information
  (`DARIS_events`, derived from the Schoenfeld formula assuming a constant
  `psi*(1-psi)` amount of information per event), while the "DARIS
  information reached" verdict was based on the **observed** accrued
  inverse-variance statistical information (`sum(1/SE^2)` across studies
  vs. `DARIS_info`). These two quantities only agree when every included
  study's actual information-per-event matches the pooled `psi*(1-psi)`
  assumption; with heterogeneous studies (differing allocation ratios,
  censoring patterns), they can diverge.

  Fix: `tsa_hr()` now also computes `DARIS_info_threshold_events`, an
  *estimated* cumulative-events position (via linear interpolation between
  looks) at which the observed information first meets `DARIS_info`,
  whenever DARIS has been reached. `plot.tsa_hr()` now shows **both**
  reference lines, separately labelled, rather than substituting one for
  the other:

  - a dotted black line at the theoretical DARIS event-equivalent
    (`"Theoretical DARIS event-equivalent ~ N"`, always shown), and
  - when DARIS has actually been reached, a dashed grey line at the
    interpolated crossing point (`"DARIS information reached \u2248 M
    events (est.)"`).

  This means the plot can no longer contradict the printed verdict, while
  keeping the two quantities visually and terminologically distinct: the
  interpolated crossing point is deliberately never called "DARIS events"
  (no study was actually observed at that exact event count), and the
  observed accrued information is no longer referred to as "exact" in
  code comments/docs, since `tau^2` is re-estimated at every cumulative
  look under the random-effects model.

  `verbose = TRUE` output and the summary table now report both the
  theoretical DARIS event-equivalent and (when applicable) the estimated
  event count at which the DARIS information threshold was reached, so
  both figures are visible together rather than one replacing the other.
  New `plot()` arguments `info_threshold_label_size`,
  `info_threshold_label_x`, `info_threshold_label_y` control the position
  of the new label.

# tsahr 0.2.0

* Initial version reviewed.