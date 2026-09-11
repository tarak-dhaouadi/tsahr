# tsahr 0.2.5.1

## Minor

* `tsa_hr()`'s verbose console output now ends with a final note on the
  practical impact of the `method` (\u03c4\u00b2 estimator) choice: it may have
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