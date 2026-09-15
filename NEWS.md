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