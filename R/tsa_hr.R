## Internal helper: map a metafor `method` code to a human-readable label
## for use in printed/plotted output (e.g. "DL" -> "DerSimonian-Laird").
## Falls back to the bare code itself (quoted) for any method not in the
## table, so an unrecognised-but-valid metafor method code never errors
## here -- it just prints less prettily. Not exported.
.tsahr_method_label <- function(method) {
  labels <- c(
    DL    = "DerSimonian-Laird",
    HE    = "Hedges",
    HS    = "Hunter-Schmidt",
    HSk   = "Hunter-Schmidt (with k correction)",
    SJ    = "Sidik-Jonkman",
    ML    = "maximum likelihood",
    REML  = "restricted maximum likelihood",
    EB    = "empirical Bayes",
    PM    = "Paule-Mandel",
    GENQ  = "generalized Q-statistic",
    PMM   = "Paule-Mandel (median-unbiased)",
    GENQM = "generalized Q-statistic (median-unbiased)",
    ## Aliases for the Hedges estimator; tsa_hr() normalises these to
    ## "HE" before they reach here, but keep them mapped so the helper is
    ## correct if called directly with an un-normalised code.
    CO    = "Hedges (Cochran alias)",
    VC    = "Hedges (variance-component alias)"
  )
  if (method %in% names(labels)) labels[[method]] else paste0("'", method, "'")
}

#' Trial Sequential Analysis for a meta-analysis of Hazard Ratios
#'
#' Performs a Trial Sequential Analysis (TSA) for a meta-analysis of
#' time-to-event outcomes reported as hazard ratios (HR). Adapts the
#' classical Wetterslev/Thorlund/CTU TSA framework to time-to-event data
#' using the Schoenfeld required-events formula (generalised for unequal
#' allocation), the Diversity (D-squared) heterogeneity adjustment of
#' Wetterslev et al. (2009), and O'Brien-Fleming-type alpha- and
#' beta-spending monitoring boundaries computed at the observed accrued
#' statistical information.
#'
#' @param data A data.frame, or a path to an .xlsx file, containing one row
#'   per study with (at least) the columns: \code{Study}, \code{log_HR},
#'   \code{Std_Error}, \code{Events_Treatment}, \code{N_treatment},
#'   \code{Events_controls}, \code{N_controls}. Rows are treated as being
#'   in chronological (publication) order; reorder your data before calling
#'   this function if the row order in your file is not chronological.
#' @param alpha_two_sided Overall two-sided type I error for the TSA
#'   monitoring boundaries. Default \code{0.05}.
#' @param power Desired power (1 - beta) for the required information size
#'   calculation. Default \code{0.80}.
#' @param allocation_source Either \code{"data"} (default; the allocation
#'   ratio psi is computed automatically as
#'   \code{sum(N_treatment) / sum(N_treatment + N_controls)} across the
#'   included studies) or \code{"manual"} (psi is fixed to
#'   \code{allocation_p}, e.g. for planning a future trial with a
#'   pre-specified ratio).
#' @param allocation_p Allocation proportion to use when
#'   \code{allocation_source = "manual"}. Must be strictly between 0 and 1.
#'   Ignored when \code{allocation_source = "data"}.
#' @param target_HR Anticipated hazard ratio used for the required
#'   information size calculation. Default \code{NA}, which uses the
#'   *observed* pooled HR from the random-effects meta-analysis -- see
#'   Details for an important caution about this default. Set to a
#'   pre-specified clinically-anticipated value (e.g. \code{0.80}) for a
#'   standard, non-circular, protocol-driven TSA.
#' @param method Character string specifying the heterogeneity-variance
#'   (tau^2) estimator used for the \emph{random-effects} meta-analysis and
#'   cumulative (sequential) TSA model, passed to
#'   \code{method} in \code{metafor::rma()} after validation and, for the
#'   aliases \code{"CO"}/\code{"VC"}, normalisation to \code{"HE"}. One of \code{"DL"}
#'   (DerSimonian-Laird, the default -- kept as the default here for
#'   backward compatibility with earlier tsahr versions, which always used
#'   DL; note this differs from \code{metafor::rma()}'s own default of
#'   \code{"REML"}), \code{"HE"}, \code{"HS"}, \code{"HSk"}, \code{"SJ"},
#'   \code{"ML"}, \code{"REML"}, \code{"EB"}, \code{"PM"}, or \code{"PMM"}.
#'   \code{"CO"} and \code{"VC"} are also accepted and normalised to
#'   \code{"HE"} (see below).
#'   See \code{?metafor::rma} for the definition of each estimator. This
#'   only changes the \emph{random-effects} model (\code{res_re}); the
#'   equal-effects model used internally for the Diversity (D^2)
#'   heterogeneity adjustment is always fitted with \code{method = "FE"}
#'   and is unaffected by this argument. Alpha-/beta-spending boundary
#'   calculations are unaffected by this argument.
#'
#'   \code{"CO"} and \code{"VC"} are accepted as aliases for \code{"HE"}
#'   and are normalised to \code{"HE"} before being passed to
#'   \code{metafor::rma()}. metafor's documentation notes that the Hedges
#'   estimator is also known as the Cochran (\code{"CO"}) or
#'   variance-component (\code{"VC"}) estimator, and that those strings may
#'   be used to select it -- but that alias is not accepted by every
#'   metafor version (older releases reject a bare \code{"CO"} with
#'   \dQuote{Unknown 'method' specified}). Normalising here makes
#'   \code{tsa_hr()} behave identically across metafor versions rather than
#'   inheriting that version skew, and avoids pinning a minimum metafor
#'   version purely for an alias. All three strings denote the same
#'   estimator, so this has no numerical consequence. The returned object
#'   records both \code{parameters$method} (the normalised string actually
#'   used, i.e. \code{"HE"}) and \code{parameters$method_requested} (what
#'   the caller passed).
#'
#'   Two method strings accepted by \code{metafor::rma()} are
#'   deliberately NOT supported here: \code{"GENQ"} and \code{"GENQM"}
#'   require the
#'   caller to also supply a \code{weights} argument to
#'   \code{metafor::rma()}, which \code{tsa_hr()} does not currently
#'   collect or pass through, so passing them here raises an explicit
#'   error explaining why rather than silently forwarding to
#'   \code{metafor::rma()} and surfacing its own unrelated error.
#' @param order_by Optional name of a column in \code{data} to sort by
#'   (ascending) before the cumulative analysis, e.g. a publication-year
#'   column. TSA is order-dependent, so getting the chronological order
#'   right matters. Default \code{NULL}, which uses the row order already
#'   present in \code{data} and assumes it is chronological (with no way
#'   for the package to verify this). Column names in \code{data} have
#'   spaces replaced with underscores on load (so an Excel header
#'   \dQuote{Std Error} becomes \code{Std_Error}); \code{order_by} is
#'   normalised the same way, so either \code{"Publication Year"} or
#'   \code{"Publication_Year"} will match that column. If two distinct
#'   headers would collide once spaces become underscores, \code{tsa_hr()}
#'   stops rather than silently using whichever column came first.
#' @param verbose Logical; print analysis details to the console as the
#'   function runs (mirrors the diagnostic output of the original script).
#'   Default \code{TRUE}.
#' @param boundary_route Character string, one of \code{"design"} (default)
#'   or \code{"analysis"}, selecting which of RTSA's two retrospective
#'   boundary-computation routes to use. See "Retrospective boundary
#'   timeline" under Details for what each computes and, for
#'   \code{"analysis"}, how it changes the formal endpoint, the "DARIS
#'   reached" verdict, and every decision field in \code{results} --
#'   this is more than swapping out the futility numbers.
#' @param projection_stat Character string, one of \code{"median"}
#'   (default) or \code{"mean"}, selecting the summary statistic used to
#'   turn the OBSERVED per-study contributions into "typical" values for the
#'   retrospective projection described under "Estimated additional
#'   studies/events" in Details: the information per study
#'   (\code{1/Std_Error^2}, giving the additional-studies estimate) and the
#'   information per event (\code{1/Std_Error^2} divided by the study's
#'   \code{total events}, giving the additional-events estimate).
#'   \code{"median"} is the default because it is more robust to a single
#'   unusually large or small study; \code{"mean"} is offered as an
#'   alternative when that robustness is not wanted (e.g. a deliberately
#'   evenly-sized set of studies). This has no effect on any other
#'   quantity returned by \code{tsa_hr()} -- it only feeds the
#'   \code{projection} element of the return value and the corresponding
#'   printed/plotted text.
#' @param info_per_event_basis Character string, one of \code{"per_study"} (default) or
#'   \code{"pooled"}, selecting how the "historical rate" of information per
#'   event used for the additional-EVENTS projection is obtained.
#'   \code{"per_study"}: the \code{projection_stat} (median by default, or
#'   mean) of each study's own information per event (\code{1/Std_Error^2}
#'   divided by its \code{total events}). \code{"pooled"}: the ratio of sums
#'   (total information / total events), which weights larger studies more and
#'   equals the slope of observed cumulative information against cumulative
#'   events. Studies with zero events (or another non-finite or non-positive
#'   ratio) are technically accepted but are excluded from either variant, and
#'   the number excluded is stated explicitly in the printed output. It does not
#'   affect the additional-STUDIES estimate, which always uses
#'   \code{projection_stat}. Both variants are always returned in
#'   \code{projection} as a sensitivity check.
#' @param legacy_fallback Logical, default \code{TRUE}. Governs what
#'   happens if the compiled RTSA-derived boundary engine fails to produce
#'   a result for the requested design (e.g. no root bracket exists for an
#'   unusual information-fraction schedule). When \code{TRUE} (the
#'   default), \code{tsa_hr()} falls back to the legacy, pre-0.2.7.11
#'   R-only approximate engine, with an immediate warning and a visible
#'   banner in \code{print()}/\code{summary()} output, and marks the
#'   result (\code{beta_engine$engine == "legacy_r_fallback"}) so the
#'   fallback is never silent -- but it IS a fallback: a caller who wraps
#'   the call in \code{suppressWarnings()} will not see it, and the
#'   returned boundaries are not RTSA-comparable when this happens. Set
#'   \code{legacy_fallback = FALSE} for strict fail-closed behaviour: an
#'   engine failure then stops \code{tsa_hr()} with an error instead of
#'   silently substituting the approximate engine, appropriate when the
#'   result will be reported as RTSA-equivalent and an unnoticed fallback
#'   would be worse than a hard stop.
#'
#' @details
#' **Circularity caution:** using the observed pooled effect
#' (\code{target_HR = NA}) to determine the required information size is
#' circular -- it tends to make the required information size small
#' whenever the pooled effect is large and precise, which can make the TSA
#' boundary collapse to the conventional boundary almost immediately. For
#' a publication-quality TSA, set \code{target_HR} to a value fixed
#' independently of (and ideally before looking at) the meta-analysis
#' result.
#'
#' **Random-effects caveat:** the cumulative Z-curve is estimated from a
#' random-effects model whose between-study variance is re-estimated at
#' every step. The canonical Lan-DeMets/O'Brien-Fleming theory assumes a
#' fixed, canonical information process with independent Brownian-motion
#' increments. Because tsahr obtains each cumulative Z statistic from a
#' random-effects meta-analysis with tau-squared re-estimated at each
#' look, the resulting Z process does not exactly satisfy that canonical
#' model; the displayed monitoring boundaries should therefore be
#' regarded as an approximation (as in the official Copenhagen Trial
#' Unit TSA software), not an exact result.
#'
#' **Retrospective boundary timeline:** the observed cumulative Z-curve
#' continues through every included study, but the formal alpha and beta
#' boundaries follow the RTSA retrospective convention: observed looks are
#' retained only while \code{info_fraction < 1}, followed by one synthetic
#' final-analysis point at \code{t = 1} (HARIS/DARIS). Boundaries are not
#' continued through studies occurring after DARIS. The synthetic point is
#' stored in \code{boundary_timeline}; the observed-study rows in
#' \code{cumulative} have boundary values set to \code{NA} at and after
#' DARIS.
#'
#' Formal crossing/futility decisions are evaluated only through the
#' first observed look reaching the route endpoint (DARIS for
#' \code{boundary_route = "design"}; \code{design_R * DARIS} for
#' \code{"analysis"}), using the definitive boundary at that endpoint.
#'
#' \strong{Decision fields: "at any formal look" versus "at the definitive
#' look" (0.2.7.14).} \code{results} reports two families of fields that
#' answer different questions:
#' \describe{
#'   \item{At ANY formal look}{\code{crossed_tsa} and
#'     \code{entered_futility_region} are \code{TRUE} if the cumulative
#'     Z-curve crossed the efficacy boundary (respectively lay inside the
#'     futility region) at any look up to and including the definitive one.
#'     A trial that crossed efficacy at an interim look keeps
#'     \code{crossed_tsa = TRUE} even if the definitive look then fell back
#'     below the boundary.}
#'   \item{At the DEFINITIVE look}{\code{final_crossed_efficacy},
#'     \code{final_non_efficacy} (= \code{!final_crossed_efficacy}) and
#'     \code{final_entered_futility_region} refer ONLY to the first look
#'     reaching the route endpoint (\code{results$final_tsa_look}) and are
#'     \code{NA} when that endpoint has not been reached. Version 0.2.7.13
#'     defined \code{final_non_efficacy} as \code{!crossed_tsa}, which means
#'     "never crossed at any look" rather than "the definitive look did not
#'     cross"; this was corrected in 0.2.7.14.}
#' }
#' At the definitive look the futility boundary equals the final efficacy
#' boundary (as in RTSA's design pass, where the two are calibrated to meet
#' there; e.g. about 2.1-2.2 rather than 1.959964 for a two-sided alpha of
#' 0.05 with many looks), so \code{final_entered_futility_region} is the
#' complement of \code{final_crossed_efficacy} (both are \code{TRUE} only at
#' |Z| exactly equal to the boundary). It merely says that the Z-curve did
#' not reach the final efficacy boundary; it is not a formal interim
#' futility stop, and neither family of fields is a recommendation to stop a
#' trial. (Versions 0.2.6.x-0.2.7.11 used \code{min(qnorm(1 - alpha/2),
#' <final efficacy boundary>)} as the final futility boundary.)
#'
#' \strong{Route endpoint versus DARIS (0.2.7.13/0.2.7.14).}
#' \code{boundary_route} picks between direct ports of RTSA's two
#' retrospective boundary computations:
#' \describe{
#'   \item{\code{"design"} (default)}{\code{RTSA::boundaries(type =
#'     "design")}: alpha and beta boundaries are computed directly on the
#'     observed information-fraction timeline (looks below \code{t = 1} plus
#'     one synthetic \code{t = 1} point), with NO further inflation. The
#'     formal endpoint is DARIS itself (\code{info_fraction = 1}), matching
#'     this package's stated RIS/DARIS definition and the values validated
#'     against RTSA's design pass.}
#'   \item{\code{"analysis"}}{\code{RTSA::RTSA(type = "analysis", design =
#'     NULL)}: a design pass first solves an inflation factor
#'     (\code{design_R}) so that the design's own futility and efficacy
#'     boundaries meet at its final look; the boundaries returned are then
#'     recomputed on the timeline scaled by \code{design_R}, and the efficacy
#'     boundaries change as well as the futility ones (alpha is respent on
#'     \code{t / design_R}). The formal endpoint becomes \code{design_R *
#'     DARIS}, not DARIS. This is RTSA's own inflated-sequential-design
#'     convention, not the no-inflation convention of the Copenhagen Trial
#'     Unit's TSA software.}
#' }
#' DARIS and the route endpoint are reported separately and never conflated:
#' \code{results$daris_reached} and
#' \code{information_size$DARIS_info_threshold_events} always refer to DARIS
#' itself, whereas \code{results$final_reached},
#' \code{information_size$route_endpoint_info} and
#' \code{information_size$route_endpoint_events} refer to the route endpoint
#' (identical to DARIS for \code{"design"}). For \code{"analysis"} the
#' printed output, summary table and plot call the endpoint "analysis-route
#' endpoint (x.xxx x DARIS)" and never "DARIS". Both routes share the same
#' compiled recursion (\code{src/rtsa_core.h}); only the orchestration
#' differs.
#'
#' \strong{Fallbacks (0.2.7.14).} \code{settings$route_used}
#' (\code{"design"}, \code{"analysis"} or \code{"legacy"}),
#' \code{settings$fallback_used}, \code{settings$fallback_route}
#' (\code{"none"}, \code{"design"} or \code{"legacy"}) and
#' \code{settings$fallback_reason} record programmatically what actually
#' produced the boundaries. \code{"design"}: \code{boundary_route =
#' "analysis"} failed and the RTSA-derived design-route result is returned;
#' \code{"legacy"}: the RTSA-derived engine failed and the legacy,
#' approximate R-only engine was used. Both are announced by warnings and,
#' for \code{"legacy"}, a banner in \code{print()}/\code{summary()}. For
#' confirmatory or RTSA-parity work use \code{legacy_fallback = FALSE}, which
#' makes either failure an error.
#'
#' \strong{Numerical diagnostics.} The compiled engine warns when a boundary
#' search converged only within a loose tolerance, when an integration grid
#' collapsed to a degenerate interval, and -- with a separate, more alarming
#' warning -- when an integration interval was REVERSED (lower wall above the
#' upper wall), a state RTSA's own code would have stopped on and which
#' invalidates the boundaries from that look onward. Diagnostics are
#' reported for the converged passes, not for the transient candidate
#' information scales tried inside the root searches.
#'
#' \strong{Placeholder boundaries: RTSA's tolerance, kept (0.2.7.22).} At looks
#' where the cumulative alpha spend is below RTSA's absolute search tolerance of
#' 1e-9 (very early looks, small information fractions) RTSA does not solve for a
#' boundary but reports the placeholder value 20, and tsahr reproduces this
#' deliberately (\code{TSA_boundary_upper == 20}). It is not a computed boundary:
#' the true boundary there is finite (about 6.7 and 6.2 at information fractions
#' 0.108 and 0.125 in a 37-look example), and a Z-curve above the placeholder is
#' not counted as crossing. The same tolerance also makes the first boundary that
#' IS solved after such looks slightly inaccurate (an error of about 7e-3 in that
#' example, shrinking at later looks). Both effects are RTSA's own; tsahr keeps
#' RTSA's tolerance so that its bounds match RTSA's, and the placeholder stretches
#' the vertical axis of \code{plot()}.
#'
#' \strong{Final-look-only beta spend (0.2.7.22).} When every interim look is
#' suppressed (small information fractions) the final look carries the whole beta
#' spend. RTSA has an exact-float shortcut for that case that fires or not
#' depending on the last bit of \code{beta}; tsahr computes \code{beta = 1 - power}
#' and used to hit it at power 0.80, losing the compiled engine to the legacy
#' fallback. The shortcut is no longer ported, so the result no longer depends on
#' the last bit of \code{beta}.
#'
#' \strong{Estimated additional studies/events (retrospective projection).}
#' Whenever the route's target has NOT been reached in the observed data
#' (\code{results$daris_reached == FALSE} for \code{boundary_route =
#' "design"}; \code{results$final_reached == FALSE} for \code{"analysis"}),
#' \code{tsa_hr()} additionally projects how many more studies, and
#' roughly how many more events, would be needed to reach it -- based
#' directly on the OBSERVED study-level information increments already in
#' the data, not on any new assumption about future trial size. This is
#' deliberately a retrospective, data-driven HR-specific counterpart to
#' RTSA's own prospective \code{minTrial()}/\code{ris(..., type =
#' "retrospective")} machinery, not a re-implementation of it.
#'
#' The target information \code{I_required} differs by route -- computed
#' separately, never conflated:
#' \itemize{
#'   \item{\code{"design"}: \code{I_required = DARIS} (the information
#'     target is DARIS itself, i.e. \code{information_size$DARIS_info}).}
#'   \item{\code{"analysis"}: \code{I_required = design_R x DARIS} (the
#'     analysis-route endpoint, i.e. \code{information_size$route_endpoint_info}).}
#' }
#' The shortfall \code{I_required - info_accrued_final} is translated in two
#' separate ways, which answer different questions:
#' \describe{
#'   \item{Additional events (primary)}{The shortfall divided by a "historical
#'     rate" of information per event, chosen with
#'     \code{info_per_event_basis}: \code{"per_study"} (default) uses the
#'     \code{projection_stat} (median by default, or mean) of each included
#'     study's own \code{(1/Std_Error^2) / total_events}; \code{"pooled"} uses
#'     the ratio of sums, total information / total events, which weights the
#'     larger studies more and equals the slope of observed cumulative
#'     information against cumulative events. The result is continuous and is
#'     rounded up only for display. It is returned in
#'     \code{projection$additional_events_estimated}; both variants are always
#'     returned (\code{additional_events_study_level} and
#'     \code{additional_events_pooled}) so the choice can be checked as a
#'     sensitivity analysis.}
#'   \item{Additional studies (secondary)}{The shortfall divided by a single
#'     "typical future study" information increment -- the
#'     \code{projection_stat} of each study's own \code{1/Std_Error^2} -- and
#'     rounded up to the nearest whole study, so it is always a natural
#'     number. It is not affected by \code{info_per_event_basis}.}
#' }
#' The two are deliberately not chained: the events figure is NOT the number
#' of studies times an events-per-study increment, because rounding the
#' studies up would inflate it. That chained quantity (whole typical studies x
#' typical events per study) is still returned, as
#' \code{projection$events_from_whole_studies}, but it answers "how many
#' events would the minimum whole number of typical studies bring?", not "how
#' many events are needed?".
#'
#' For both routes three separate quantities are reported when the route's
#' own target has not been reached (printed output, \code{summary()} and the
#' plot caption); for \code{boundary_route = "design"} the target is DARIS, for
#' \code{"analysis"} it is the analysis-route endpoint (design_R x DARIS):
#' \describe{
#'   \item{Theoretical additional events (Schoenfeld)}{The direct,
#'     deterministic difference between the theoretical event-equivalent of the
#'     target (\code{DARIS_events} for design, \code{DARIS_events x design_R} for
#'     analysis) and \code{events_accrued} (both already pooled-psi
#'     event-equivalents), floored at 0
#'     (\code{projection$additional_events_theoretical}; for the design route
#'     this equals \code{projection$additional_events_required_design}).}
#'   \item{Estimated additional events (historical rate)}{The events
#'     projection above, with \code{I_required} set to the route's target
#'     information (\code{projection$additional_events_estimated}).
#'     \code{plot()} draws it as a second reference line, at accrued events plus
#'     these additional events
#'     (\code{projection$target_events_historical_rate}), next to the
#'     theoretical line; see \code{show_historical_daris} in
#'     \code{\link{plot.tsa_hr}}. The printed output and \code{summary()}
#'     also give that position in cumulative events, just before the
#'     additional-events figure ("DARIS (historical rate)" for the design
#'     route; "Historical information/event-rate projection" for the
#'     analysis route).}
#'   \item{Estimated additional studies required}{The studies projection
#'     above.}
#' }
#' These two events figures rest on different assumptions and can disagree --
#' for example, when the studies supply less information per event than the
#' psi*(1-psi) assumption behind the Schoenfeld figure, the historical-rate
#' figure is larger, and it can be positive when the Schoenfeld figure is
#' already 0. Both are approximations.
#'
#' \strong{Zero-event studies.} Studies with zero events (or another
#' non-finite or non-positive information-per-event ratio) are technically
#' accepted by \code{tsa_hr()} but carry information with no events to attach
#' it to, so they are excluded from the information-per-event summaries (both
#' variants) and hence from the events projection. They remain in the
#' additional-studies projection and in every other result. The number
#' excluded is stated explicitly in the printed output, in \code{summary()},
#' and in the plot caption, and is returned as
#' \code{projection$n_zero_event_studies} and
#' \code{projection$n_excluded_events_projection}.
#'
#' \strong{Caveat: fixed-effect information scale.} All projections are
#' linear extrapolations on the fixed-effect, study-level inverse-variance
#' information scale (\code{1/Std_Error^2}) that \code{tsa_hr()} compares
#' with DARIS. They deliberately do not model how random-effects weights or
#' the between-study variance (tau^2) would change as further studies are
#' added, nor any change in the size, allocation or baseline risk of future
#' studies; the mathematics are not adjusted for random effects. Read every
#' projected number of events or studies as indicative, not as a required
#' quantity.
#'
#' This projection is deliberately NOT called "number of studies required"
#' anywhere in \code{tsa_hr()}'s output: that phrasing reads as
#' deterministic, and it is not one. Figures are labelled "Estimated ...", and
#' the printed output always carries a note that the projection assumes future
#' studies contribute information at approximately the observed historical
#' rate and is not a formal guarantee. The full detail is returned in
#' \code{projection} (see "Value"); when the endpoint HAS already been
#' reached, the projected fields (\code{n_additional_studies},
#' \code{additional_events_estimated} and their variants) are \code{NA} (there
#' is nothing left to project), and nothing is printed or plotted for it.
#'
#' @return An object of class \code{"tsa_hr"}: a list containing the fitted
#'   random-effects and fixed-effect \code{metafor::rma} model objects,
#'   heterogeneity statistics (including \code{D2}, capped at 99.9% for
#'   numerical stability in extreme-heterogeneity cases, alongside the
#'   uncapped \code{D2_raw} and a \code{D2_was_capped} logical flag so
#'   capping is auditable rather than silent), allocation and
#'   required-information-size
#'   details (\code{information_size}, which includes two distinct
#'   circularity flags: \code{circularity_warning} is \code{TRUE} whenever
#'   \code{target_HR} was left unspecified, since deriving the required
#'   information size from the observed pooled effect is circular
#'   regardless of how much information accrued; \code{circularity_severe}
#'   additionally requires accrued events to exceed three times the
#'   resulting DARIS, the runaway case in which the boundary collapses to
#'   the conventional one almost immediately),
#'   the cumulative analysis data frame (\code{cumulative}), the
#'   formal sequential boundary schedule including the synthetic \code{t=1}
#'   final-analysis point (\code{boundary_timeline}; see "Retrospective
#'   boundary timeline" above), boundary-crossing results (\code{results},
#'   including \code{crossed_conventional} -- deliberately evaluated over
#'   the FULL cumulative Z-curve, including studies added after DARIS,
#'   unlike \code{crossed_tsa}, which is restricted to the formal decision
#'   horizon -- and \code{entered_futility_region}, see the caveat under
#'   "Retrospective boundary timeline" above; a \code{TRUE} value at the
#'   DARIS-reaching look reflects a comparison against the definitive
#'   \code{t=1} futility boundary, not an interim one, and is not itself a
#'   formal stopping recommendation; the definitive-look fields
#'   \code{final_crossed_efficacy}, \code{final_non_efficacy} and
#'   \code{final_entered_futility_region}, plus \code{daris_reached} and
#'   \code{final_reached} -- see \dQuote{Decision fields} under Details), a
#'   \code{settings} list recording \code{boundary_route},
#'   \code{route_used}, \code{legacy_fallback}, \code{fallback_used},
#'   \code{fallback_route}, \code{fallback_reason}, the resolved
#'   \code{route_endpoint} (\code{1} for \code{"design"}, \code{design_R}
#'   for \code{"analysis"}), \code{route_endpoint_info} and
#'   \code{used_legacy_engine}, a \code{projection} list (see "Estimated
#'   additional studies/events" above) with \code{method}
#'   (\code{projection_stat} used), \code{I_required}, \code{info_accrued},
#'   \code{info_per_event_basis}, \code{events_accrued},
#'   \code{additional_info_required}, \code{central_info_increment},
#'   \code{central_event_increment}, \code{central_info_per_event} (the
#'   historical rate used), \code{study_level_info_per_event},
#'   \code{pooled_info_per_event}, \code{n_additional_studies},
#'   \code{additional_events_estimated} (continuous, information / info per
#'   event, on the chosen basis), \code{additional_events_study_level},
#'   \code{additional_events_pooled}, \code{events_from_whole_studies},
#'   \code{target_events_historical_rate} (accrued plus estimated additional
#'   events), \code{n_studies}, \code{n_zero_event_studies},
#'   \code{n_excluded_events_projection} and, design-route only,
#'   \code{additional_events_required_design} (design-route only, equal to
#'   \code{additional_events_theoretical} there) and
#'   \code{additional_events_theoretical} -- the projected quantities are
#'   \code{NA} once the route's endpoint has been reached, and a summary data frame (character
#'   \code{Parameter} and \code{Value} columns; \code{Value} is character so
#'   logical rows print as TRUE/FALSE/NA rather than 1/0/NA). Use
#'   \code{plot()}, \code{summary()}, or \code{print()} on the result.
#'
#' @references
#' Miladinovic B, Mhaskar R, Hozo I, Kumar A, Mahony H, Djulbegovic B.
#' "Optimal information size in trial sequential analysis of time-to-event
#' outcomes reveals potentially inconclusive results because of the risk
#' of random error." J Clin Epidemiol. 2013;66(6):654-9.
#'
#' Wetterslev J, Thorlund K, Brok J, Gluud C. "Estimating required
#' information size by quantifying diversity in random-effects model
#' meta-analyses." BMC Med Res Methodol. 2009;9:86.
#'
#' @examples
#' \donttest{
#' path <- tsahr_example_data()
#' res <- tsa_hr(path, target_HR = 0.80)
#' summary(res)
#' plot(res)
#' }
#'
#' @importFrom stats qnorm
#' @export
tsa_hr <- function(data,
                    alpha_two_sided = 0.05,
                    power = 0.80,
                    allocation_source = c("data", "manual"),
                    allocation_p = 0.5,
                    target_HR = NA_real_,
                    method = "DL",
                    order_by = NULL,
                    verbose = TRUE,
                    boundary_route = c("design", "analysis"),
                    legacy_fallback = TRUE,
                    projection_stat = c("median", "mean"),
                    info_per_event_basis = c("per_study", "pooled")) {

  allocation_source <- match.arg(allocation_source)
  boundary_route <- match.arg(boundary_route)
  projection_stat <- match.arg(projection_stat)
  info_per_event_basis <- match.arg(info_per_event_basis)
  if (!is.logical(legacy_fallback) || length(legacy_fallback) != 1L ||
      is.na(legacy_fallback))
    stop("legacy_fallback must be a single TRUE or FALSE")
  vcat <- function(...) if (verbose) cat(...)

  ## --- Random-effects (tau^2) estimator method --------------------------
  ## Validated up front, before any data handling, so an invalid method
  ## string fails fast with a clear message rather than propagating into
  ## metafor::rma() and surfacing as a less legible error from inside a
  ## dependency. "FE" is intentionally NOT offered here: the equal-effects
  ## comparator used for the Diversity (D^2) adjustment is always fitted
  ## internally with method = "FE", independent of this argument, and
  ## allowing method = "FE" for res_re itself would make D2 -- which is
  ## defined as a function of the random-effects vs. fixed-effects
  ## variance -- degenerate (D2 = 0 by construction).
  ##
  ## Two of the originally-advertised 13 method strings do not actually
  ## work standalone and have been REMOVED from valid_methods (bug found
  ## and fixed while adding a test that exercises every advertised value
  ## -- previously only DL/REML/ML were ever tested, so this went
  ## unnoticed since the method parameter was first added):
  ##   - "GENQ" / "GENQM": these require the caller to also supply a
  ##     `weights` argument to metafor::rma() (e.g.
  ##     `rma(yi, vi, weights = 1/vi, method = "GENQ")` per metafor's own
  ##     documentation and training materials) -- tsa_hr() does not
  ##     collect or pass through a weights argument, so calling rma()
  ##     with method = "GENQ"/"GENQM" and no weights errors out. Properly
  ##     supporting these would mean adding a new tsa_hr() argument for
  ##     user-supplied weights, which is a real feature addition, not a
  ##     one-line fix -- left for a future release if there's demand.
  ##
  ## "CO" (and "VC") are handled differently, as of 0.2.6.7: they are
  ## NORMALISED to "HE" rather than accepted or rejected outright.
  ## Background -- 0.2.6.6 removed "CO" on the basis of a direct test
  ## against an installed metafor (4.4.0, from Ubuntu's apt package),
  ## where `rma(..., method = "CO")` threw "Unknown 'method' specified".
  ## That observation was correct for that version, but the conclusion
  ## drawn from it ("not a recognised method string in current metafor at
  ## all") was too strong: metafor's current documentation states that
  ## the Hedges estimator is also called the variance-component or
  ## Cochran estimator, and that method = "VC" or method = "CO" can be
  ## used to select it. So the alias exists in newer metafor but not in
  ## the older installed one -- i.e. whether a bare "CO" works is
  ## metafor-version-dependent.
  ##
  ## Normalising to "HE" ourselves makes tsa_hr() behave identically on
  ## every metafor version, rather than inheriting that version skew.
  ## "HE" is the canonical string accepted by all versions, and the three
  ## names denote the SAME estimator, so this changes nothing
  ## numerically. This also avoids having to declare a minimum metafor
  ## version in DESCRIPTION purely to pin down an alias.
  method_requested <- method
  if (is.character(method) && length(method) == 1L && !is.na(method) &&
      method %in% c("CO", "VC")) {
    method <- "HE"
  }
  valid_methods <- c("DL", "HE", "HS", "HSk", "SJ", "ML", "REML",
                      "EB", "PM", "PMM")
  if (!is.character(method) || length(method) != 1L || is.na(method)) {
    stop("method must be a single character string; one of: ",
         paste(valid_methods, collapse = ", "), ".")
  }
  if (method %in% c("GENQ", "GENQM")) {
    stop("method = \"", method, "\" is not currently supported by tsa_hr(): ",
         "metafor's generalized-Q-statistic estimators require a ",
         "user-supplied `weights` argument to metafor::rma(), which ",
         "tsa_hr() does not currently collect or pass through. Supported ",
         "methods are: ", paste(valid_methods, collapse = ", "), ".")
  }
  if (!(method %in% valid_methods)) {
    stop("method must be one of: ", paste(valid_methods, collapse = ", "),
         " (the random-effects heterogeneity-variance estimators supported ",
         "by metafor::rma() that work without additional arguments this ",
         "package does not currently collect; see ?tsa_hr).")
  }

  ## --- Scalar design-parameter validation -----------------------------
  ## Checked before touching data at all: without this, e.g.
  ## alpha_two_sided = 2 would silently propagate into qnorm() (producing
  ## NaN/Inf far downstream) rather than being rejected up front with a
  ## clear message.
  if (!is.numeric(alpha_two_sided) || length(alpha_two_sided) != 1L ||
      !is.finite(alpha_two_sided) || alpha_two_sided <= 0 || alpha_two_sided >= 1) {
    stop("alpha_two_sided must be a single finite value strictly between 0 and 1.")
  }
  if (!is.numeric(power) || length(power) != 1L ||
      !is.finite(power) || power <= 0 || power >= 1) {
    stop("power must be a single finite value strictly between 0 and 1.")
  }

  ## -----------------------------------------------------------------
  ## 1. Load / validate data
  ## -----------------------------------------------------------------
  if (is.character(data)) {
    data <- as.data.frame(readxl::read_excel(data))
  } else {
    data <- as.data.frame(data)
  }
  ## Excel sheets commonly use spaces in headers ("Std Error"), so
  ## normalise them to underscores to match the required column names.
  ## This can, however, MERGE two originally-distinct headers into the
  ## same name (e.g. a sheet containing both "Std Error" and
  ## "Std_Error"), after which `data$Std_Error` silently resolves to
  ## whichever came first -- a wrong-column-used bug that would produce
  ## a plausible-looking but incorrect analysis with no error. Detect
  ## and refuse that case rather than guessing which column was meant.
  names_before <- names(data)
  names(data) <- gsub(" ", "_", names(data))
  if (anyDuplicated(names(data))) {
    clashing <- unique(names(data)[duplicated(names(data))])
    stop("Column names are not unique after spaces are replaced with ",
         "underscores: ", paste(sQuote(clashing), collapse = ", "),
         ". Original column name(s) involved: ",
         paste(sQuote(names_before[names(data) %in% clashing]),
               collapse = ", "),
         ". Rename the columns in the source data so they remain ",
         "distinct once spaces become underscores.")
  }

  ## `order_by` is matched against the POST-normalisation names, so a
  ## user passing the header exactly as it appears in their spreadsheet
  ## ("Publication Year") would otherwise get a "not found" error for a
  ## column that is plainly there. Normalise it the same way.
  if (!is.null(order_by) && is.character(order_by) &&
      length(order_by) == 1L && !is.na(order_by)) {
    order_by <- gsub(" ", "_", order_by)
  }

  required_cols <- c("Study", "log_HR", "Std_Error",
                      "Events_Treatment", "N_treatment",
                      "Events_controls", "N_controls")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required column(s): ", paste(missing_cols, collapse = ", "))
  }
  if (any(is.na(data$Study)) ||
      any(!nzchar(trimws(as.character(data$Study))))) {
    stop("Study must contain non-missing, non-empty identifiers.")
  }
  if (anyDuplicated(data$Study)) {
    stop("Study names must be unique (duplicate found in 'Study' column).")
  }
  ## --- Minimum number of studies ---------------------------------------
  if (nrow(data) < 2L) {
    stop("tsa_hr() requires at least two studies.")
  }
  if (nrow(data) < 10L) {
    warning("Only ", nrow(data), " studies were supplied. Heterogeneity/D2 ",
            "estimates (and therefore DARIS and the monitoring boundaries) can ",
            "be highly unstable with few studies; the Copenhagen TSA manual ",
            "cautions about this below roughly 10 studies.")
  }

  ## --- Event/sample-size sanity checks -------------------------------
  ## Type first, then finiteness. is.finite() on a character or factor
  ## column returns all-FALSE rather than erroring, so a column read in
  ## as text (e.g. Excel cells stored as strings, or a stray footnote
  ## marker forcing the whole column to character) would otherwise be
  ## reported as "found NA/NaN/Inf" -- technically true of the is.finite
  ## result, but a misleading diagnosis of a type problem. Name the real
  ## cause instead.
  numeric_cols <- c("log_HR", "Std_Error", "Events_Treatment",
                     "N_treatment", "Events_controls", "N_controls")
  not_numeric <- vapply(data[numeric_cols], function(col) !is.numeric(col),
                         logical(1))
  if (any(not_numeric)) {
    stop("Column(s) must be numeric, but are not: ",
         paste(sprintf("%s (%s)", numeric_cols[not_numeric],
                       vapply(data[numeric_cols[not_numeric]],
                              function(col) class(col)[1], character(1))),
               collapse = ", "),
         ". Check for text, footnote markers, or blank-but-not-empty cells ",
         "in the source data.")
  }
  if (any(!is.finite(data$log_HR))) {
    stop("log_HR must be finite for every study (found NA/NaN/Inf).")
  }
  if (any(!is.finite(data$Std_Error)) || any(data$Std_Error <= 0)) {
    stop("Std_Error must be finite and strictly positive for every study.")
  }
  ## Explicit finiteness checks on the count/size columns, rather than
  ## relying only on the comparisons below to indirectly catch NA/NaN/Inf
  ## (a comparison against NA/NaN silently returns NA, not TRUE, so a
  ## non-finite value could otherwise slip past `< 0` / `> N` checks).
  count_cols <- c("Events_Treatment", "N_treatment", "Events_controls", "N_controls")
  non_finite <- vapply(data[count_cols], function(col) any(!is.finite(col)), logical(1))
  if (any(non_finite)) {
    stop("Column(s) must contain only finite values (found NA/NaN/Inf): ",
         paste(count_cols[non_finite], collapse = ", "))
  }
  if (any(data$Events_Treatment < 0) || any(data$Events_controls < 0)) {
    stop("Events_Treatment and Events_controls must be >= 0.")
  }
  if (any(data$N_treatment <= 0) || any(data$N_controls <= 0)) {
    stop("N_treatment and N_controls must be > 0.")
  }
  if (any(data$Events_Treatment > data$N_treatment)) {
    stop("Events_Treatment cannot exceed N_treatment for any study.")
  }
  if (any(data$Events_controls > data$N_controls)) {
    stop("Events_controls cannot exceed N_controls for any study.")
  }

  if (length(target_HR) != 1L) {
    stop("target_HR must be a single finite numeric value, or NA.")
  }
  if (!is.na(target_HR) && (!is.numeric(target_HR) || !is.finite(target_HR))) {
    stop("target_HR must be a single finite numeric value, or NA.")
  }
  if (!is.na(target_HR) && target_HR <= 0) {
    stop("target_HR must be > 0.")
  }
  if (!is.na(target_HR) && isTRUE(all.equal(target_HR, 1))) {
    stop("target_HR cannot equal 1: ln(HR)=0 makes the required information infinite.")
  }
  if (!is.na(target_HR) && target_HR > 0.90 && target_HR < 1.10 &&
      !isTRUE(all.equal(target_HR, 1))) {
    ## Not an error -- values near 1 are not invalid, just increasingly
    ## information-hungry: required information is proportional to
    ## 1/[log(target_HR)]^2, which grows rapidly as log(target_HR) -> 0.
    ## E.g. target_HR=0.95 requires roughly 4x the information of
    ## target_HR=0.90 for an otherwise identical design. This is purely
    ## a heads-up to confirm the target is intentional, not a defect.
    warning("target_HR (", target_HR, ") is very close to the null value of 1; ",
            "the required information size increases rapidly as log(target_HR) ",
            "approaches zero. Confirm that this represents a clinically ",
            "meaningful target effect.", call. = FALSE)
  }
  if (allocation_source == "manual") {
    if (!is.numeric(allocation_p) ||
        length(allocation_p) != 1L ||
        !is.finite(allocation_p) ||
        allocation_p <= 0 ||
        allocation_p >= 1) {
      stop("allocation_p must be a single finite numeric value strictly ",
           "between 0 and 1.")
    }
  }

  ## --- Count columns should be whole numbers ---------------------------
  non_integer <- vapply(data[count_cols], function(col) {
    any(abs(col - round(col)) > sqrt(.Machine$double.eps))
  }, logical(1))
  if (any(non_integer)) {
    stop("Event counts and sample sizes must be whole numbers. Non-integer ",
         "value(s) found in: ", paste(count_cols[non_integer], collapse = ", "))
  }

  ## Note: TSA is inherently order-dependent (it is a CUMULATIVE analysis),
  ## so the row order matters and is assumed to represent chronological
  ## accrual (e.g. publication date/year). If order_by names a column,
  ## the data are explicitly sorted by it (ascending) before analysis --
  ## this is the recommended way to guarantee chronological order rather
  ## than relying on however the input file/data.frame happened to be
  ## sorted. If order_by is NULL (default), the SUPPLIED row order is
  ## used as-is and assumed to already be chronological; the package has
  ## no way to verify this.
  if (!is.null(order_by)) {
    if (!order_by %in% names(data)) {
      stop("order_by = '", order_by, "' is not a column in data.")
    }
    ob_col <- data[[order_by]]
    if (any(is.na(ob_col))) {
      warning("order_by column '", order_by, "' contains NA values; ",
              "those rows will sort to one end under R's default NA handling.")
    }
    if (!is.numeric(ob_col) && !inherits(ob_col, c("Date", "POSIXct", "POSIXt"))) {
      warning("order_by column '", order_by, "' is not numeric or a Date/POSIXct; ",
              "sorting will use R's default ordering for its type (e.g. lexical ",
              "for character), which may not reflect chronological order unless ",
              "e.g. formatted as 'YYYY-MM-DD'.")
    }
    if (anyDuplicated(ob_col[!is.na(ob_col)])) {
      warning("order_by column '", order_by, "' contains tied values; TSA is ",
              "order-dependent, so the relative order of tied studies (broken ",
              "by R's stable sort, i.e. their original row order among ties) ",
              "may affect the cumulative TSA. Consider a finer-grained ",
              "order_by column (e.g. publication date instead of year alone) ",
              "if the exact ordering of tied studies matters.")
    }
    data <- data[order(ob_col), , drop = FALSE]
    vcat("Studies sorted by '", order_by, "' (ascending) for the cumulative analysis.\n", sep = "")
  } else {
    vcat("Study order used for sequential analysis (assumed chronological",
         " -- pass order_by = <column name> to sort explicitly):\n")
  }
  if (verbose) print(data$Study)
  vcat("\n")

  data$total_events <- data$Events_Treatment + data$Events_controls
  data$total_n      <- data$N_treatment + data$N_controls

  vcat("Loaded", nrow(data), "studies. Total events across all studies:",
       sum(data$total_events), "/ total participants:", sum(data$total_n), "\n\n")

  ## -----------------------------------------------------------------
  ## 2. Conventional (overall) meta-analysis
  ## -----------------------------------------------------------------
  res_re <- metafor::rma(yi = log_HR, sei = Std_Error, data = data, method = method)
  res_fe <- metafor::rma(yi = log_HR, sei = Std_Error, data = data, method = "FE")

  if (verbose) {
    cat(sprintf("=== Random-effects (%s) meta-analysis ===\n",
                .tsahr_method_label(method)))
    print(res_re)
    cat(sprintf("\nPooled HR (random effects): %.3f  95%% CI: %.3f-%.3f\n\n",
                exp(res_re$b), exp(res_re$ci.lb), exp(res_re$ci.ub)))
  }

  ## -----------------------------------------------------------------
  ## 3. Heterogeneity / Diversity (D^2)
  ##    Wetterslev J, Thorlund K, Brok J, Gluud C. BMC Med Res Methodol.
  ##    2009;9:86. D^2 = (Var_random - Var_fixed) / Var_random.
  ## -----------------------------------------------------------------
  Q    <- res_re$QE
  df   <- res_re$k - 1
  I2   <- res_re$I2
  tau2 <- res_re$tau2
  var_random <- res_re$vb[1, 1]
  var_fixed  <- res_fe$vb[1, 1]

  D2_raw <- max(0, (var_random - var_fixed) / var_random)
  ## D2 is bounded in [0,1) BY DEFINITION, and in practice we expect
  ## var_random >= var_fixed for essentially all of metafor's
  ## random-effects tau^2 estimators (they should not produce a *smaller*
  ## variance than the equal-effects model). That is a statement about
  ## the definition and about typical estimator behaviour, though, not a
  ## guarantee about the computed ratio: the value here is a function of
  ## two separately estimated variances, so the usual numerical and
  ## model-behaviour caveats apply -- which is exactly why the max(0, .)
  ## above and the cap below exist rather than being redundant. With very
  ## few studies and extreme heterogeneity D2 can approach 1 closely
  ## enough that 1/(1-D2)
  ## becomes numerically unstable/explosive. Cap defensively and warn.
  ## NOTE: the 99.9% cap is a purely NUMERICAL safeguard against division
  ## by (near) zero, not a statistically justified correction to D2 or AF
  ## -- it does not represent any kind of upper bound derived from theory
  ## beyond D2's own mathematical range. Treat any AF computed near this
  ## cap as a sign that the adjustment factor itself is poorly identified
  ## given the data, not as a reliable large-but-finite value.
  ## D2_raw is retained (uncapped) alongside the capped D2 so a downstream
  ## user inspecting the result can tell the two apart -- D2 == 0.999
  ## alone doesn't distinguish "D2 genuinely computed as 0.999" from
  ## "D2 was capped here from something larger/degenerate".
  D2_was_capped <- D2_raw >= 0.999
  D2 <- if (D2_was_capped) 0.999 else D2_raw
  if (D2_was_capped) {
    warning("Diversity D2 is at or very near its theoretical upper bound (100%), ",
            "indicating extreme heterogeneity relative to the number of studies. ",
            "D2 has been capped at 99.9% to avoid a numerically unstable/explosive ",
            "heterogeneity adjustment factor; interpret the required information ",
            "size and DARIS with caution in this scenario.", call. = FALSE)
  }
  AF <- 1 / (1 - D2)

  vcat("=== Heterogeneity ===\n")
  vcat(sprintf("Q = %.2f (df = %d), p = %.4f\n", Q, df, res_re$QEp))
  vcat(sprintf("I^2 = %.1f%%   tau^2 = %.4f\n", I2, tau2))
  vcat(sprintf("Diversity D^2 = %.1f%%   Adjustment factor (1/(1-D2)) = %.3f\n\n", D2 * 100, AF))

  ## -----------------------------------------------------------------
  ## 4. Allocation ratio (psi)
  ## -----------------------------------------------------------------
  if (allocation_source == "data") {
    allocation_p_used <- sum(data$N_treatment) / sum(data$N_treatment + data$N_controls)
    allocation_note <- sprintf(
      "computed from pooled data: %.0f/%.0f treatment patients (psi = %.4f, ~%.0f:%.0f ratio)",
      sum(data$N_treatment), sum(data$total_n), allocation_p_used,
      round(allocation_p_used * 100), round((1 - allocation_p_used) * 100))
  } else {
    allocation_p_used <- allocation_p
    allocation_note <- sprintf("user-specified (manual) psi = %.4f", allocation_p_used)
  }
  if (allocation_p_used <= 0 || allocation_p_used >= 1) {
    stop("Computed/used allocation_p_used must be strictly between 0 and 1 -- ",
         "check N_treatment/N_controls in your data.")
  }
  vcat("=== Allocation ratio ===\n")
  vcat(allocation_note, "\n\n")

  ## -----------------------------------------------------------------
  ## 5. Required information size (Schoenfeld formula)
  ## -----------------------------------------------------------------
  z_alpha <- stats::qnorm(1 - alpha_two_sided / 2)
  z_beta  <- stats::qnorm(power)

  if (is.na(target_HR)) {
    HR_anticipated    <- exp(as.numeric(res_re$b))
    logHR_anticipated <- as.numeric(res_re$b)
    effect_source <- "OBSERVED pooled HR (random-effects model) -- see circularity caution in ?tsa_hr"
    warning("target_HR was not specified: the OBSERVED pooled hazard ratio from ",
            "this meta-analysis is being used to calculate the required ",
            "information size. This is circular (see ?tsa_hr, 'Details') and is ",
            "appropriate for exploratory use only -- for a publication-quality ",
            "TSA, set target_HR to a pre-specified, clinically-anticipated hazard ",
            "ratio, e.g. target_HR = 0.80.", call. = FALSE)
  } else {
    HR_anticipated    <- target_HR
    logHR_anticipated <- log(target_HR)
    effect_source <- "user-specified target_HR (pre-specified)"
  }

  info_required <- (z_alpha + z_beta)^2 / logHR_anticipated^2
  RIS_events    <- info_required / (allocation_p_used * (1 - allocation_p_used))
  DARIS_info    <- info_required * AF
  DARIS_events  <- RIS_events * AF

  if (verbose) {
    cat("=== Required Information Size (time-to-event / Schoenfeld formula) ===\n")
    cat("Effect size source:", effect_source, "\n")
    cat(sprintf("Anticipated HR (used for RIS calculation): %.3f (ln HR = %.4f)\n",
                HR_anticipated, logHR_anticipated))
    cat(sprintf("alpha (2-sided) = %.3f, power = %.0f%%, allocation psi = %.4f (%.0f:%.0f)\n",
                alpha_two_sided, power * 100, allocation_p_used,
                round(allocation_p_used * 100), round((1 - allocation_p_used) * 100)))
    cat(sprintf("Required statistical information (allocation-free): %.4f\n", info_required))
    cat(sprintf("Required number of events (RIS, no heterogeneity adj., under psi=%.3f): %.0f\n",
                allocation_p_used, ceiling(RIS_events)))
    cat(sprintf("Diversity-Adjusted Required Information (DARIS, information units): %.4f\n", DARIS_info))
    cat(sprintf("DARIS translated to an equivalent number of events (under pooled psi): %.0f\n\n",
                ceiling(DARIS_events)))
    cat(sprintf("Total events accrued across included studies: %.0f (%.1f%% of DARIS)\n\n",
                sum(data$total_events), 100 * sum(data$total_events) / DARIS_events))
  }

  ## Circularity flags. These are two DIFFERENT facts and were conflated
  ## into one field before 0.2.6.8:
  ##   - circularity_warning: the RIS was derived from the OBSERVED pooled
  ##     effect (target_HR = NA). This is circular, full stop -- it does
  ##     not depend on how much information happened to accrue.
  ##   - circularity_severe: circular AND the accrued events dwarf the
  ##     resulting DARIS, which is the tell-tale runaway case where the
  ##     boundary collapses to the conventional one almost immediately.
  ## Previously `circularity_warning` carried the *severe* condition
  ## while summary.tsa_hr() printed a message worded for the *general*
  ## one, so a circular analysis at, say, 1.5x DARIS reported no
  ## circularity note at all despite ?tsa_hr correctly documenting that
  ## any RIS from the observed pooled effect is circular.
  circularity_warning <- is.na(target_HR)
  circularity_severe  <- circularity_warning &&
    sum(data$total_events) / DARIS_events > 3
  if (verbose && circularity_severe) {
    cat("*** NOTE: accrued events greatly exceed the DARIS because the RIS was\n")
    cat("    calculated from the observed (very large, very precise) pooled effect.\n")
    cat("    This is circular and will make the TSA boundary collapse almost\n")
    cat("    immediately to the conventional boundary. Consider re-running with\n")
    cat("    a pre-specified 'target_HR' for a more standard, protocol-driven TSA. ***\n\n")
  } else if (verbose && circularity_warning) {
    ## Circular, but not the runaway case -- still worth flagging, since
    ## the circularity itself is the methodological problem.
    cat("*** NOTE: 'target_HR' was not specified, so the required information size\n")
    cat("    was calculated from the OBSERVED pooled effect. This is circular: the\n")
    cat("    required information size depends on the result it is being used to\n")
    cat("    evaluate. Set a pre-specified 'target_HR' for a standard,\n")
    cat("    protocol-driven TSA. ***\n\n")
  }

  ## -----------------------------------------------------------------
  ## 6. Cumulative (sequential) meta-analysis
  ## -----------------------------------------------------------------
  cumul_re <- metafor::cumul(res_re, order = seq_len(nrow(data)))
  cumul_df <- as.data.frame(cumul_re)

  cumul_df$Study      <- data$Study
  cumul_df$cum_events <- cumsum(data$total_events)
  cumul_df$cum_n      <- cumsum(data$total_n)
  cumul_df$Z          <- cumul_df$estimate / cumul_df$se

  ## info_accrued: cumulative STUDY-LEVEL inverse-variance information,
  ## i.e. sum(1/Std_Error^2) as reported by each individual study. This is
  ## a REPORTED-DATA surrogate for statistical information, not the exact
  ## Fisher information of the cumulative random-effects estimator: the
  ## Z-curve above (cumul_df$Z) comes from a random-effects model with
  ## weights 1/(Std_Error^2 + tau^2), and tau^2 is RE-ESTIMATED at every
  ## cumulative look, so this inverse-variance sum and the random-effects
  ## Z process are not exactly the same canonical "information" process
  ## assumed by classical group sequential theory (which was derived for
  ## a Brownian motion driven by a single, fixed information process).
  ## The package nonetheless uses this quantity as its DARIS/monitoring
  ## information scale, following common TSA practice, but this
  ## approximation should be kept in mind when interpreting the alpha/
  ## beta boundaries and "DARIS reached" verdict for a random-effects TSA
  ## -- see the package DESCRIPTION and ?tsa_hr for further discussion.
  cumul_df$info_accrued  <- cumsum(1 / data$Std_Error^2)
  cumul_df$info_fraction <- cumul_df$info_accrued / DARIS_info
  cumul_df$info_fraction_eventbased <- cumul_df$cum_events / DARIS_events

  if (verbose) {
    print(cumul_df[, c("Study", "estimate", "se", "Z", "cum_events",
                        "info_fraction", "info_fraction_eventbased")])
    cat("\n")
    cat("*** IMPORTANT CAVEAT: the cumulative Z-curve above is from a RANDOM-\n")
    cat("    EFFECTS model, whose between-study variance (tau^2) is RE-ESTIMATED\n")
    cat("    at every step. The Lan-DeMets/O'Brien-Fleming monitoring boundaries\n")
    cat("    strictly assume a fixed, CANONICAL information process with\n")
    cat("    independent Brownian-motion increments. A random-effects cumulative\n")
    cat("    Z-curve with tau^2 re-estimated at each look does not exactly satisfy\n")
    cat("    those assumptions, so applying the boundaries here is a widely-used\n")
    cat("    APPROXIMATION (as in the official Copenhagen Trial Unit TSA\n")
    cat("    software), not an exact result. ***\n\n")
  }

  ## -----------------------------------------------------------------
  ## 7. Trial sequential monitoring boundaries (alpha- and beta-spending)
  ##    Computed via this package's own O'Brien-Fleming-type recursive
  ##    integration engine (see R/obf_boundaries.R) -- no external
  ##    dependency, and no fixed software limit on the number of looks.
  ## -----------------------------------------------------------------
  info_fracs <- cumul_df$info_fraction

  ## design-pass boundary timeline on the observed information fractions:
  ##   * retain observed interim looks strictly before DARIS (t < 1);
  ##   * append one definitive final-analysis point at t = 1 (HARIS/DARIS);
  ##   * do not continue the alpha or beta boundary through studies that
  ##     occur after the required information size has been reached.
  ##
  ## This is deliberately separate from `cumul_df`, which continues to
  ## contain every observed study and its cumulative Z-score.  Thus the
  ## evidence curve can extend beyond DARIS while the formal monitoring
  ## boundaries terminate at the RTSA-style final information point.
  ##
  ## ** 0.2.7.11: RTSA-derived compiled engine. **
  ## Alpha (efficacy) and beta (non-binding futility) boundaries are now
  ## computed by src/rtsa_core.h -- a C++ port of RTSA's own
  ## alpha_boundary()/beta_boundary() recursion -- driven through RTSA's
  ## boundaries(side = 2, futility = "non-binding", type = "design")
  ## orchestration (.rtsa_design_bounds() in R/rtsa_engine.R): alpha bounds
  ## on the (t < 1, 1) timeline, then the two-pass information-scale root
  ## search for the futility bounds against THAT timeline's own final
  ## efficacy wall (the alpha recursion's value at t = 1, e.g. 2.13 -- NOT
  ## qnorm(1 - alpha/2) = 1.96, which is what 0.2.6.x-0.2.7.10 substituted
  ## and which shifted design_R and with it every futility bound).
  ## See NEWS.md (0.2.7.11) and inst/REVERSE_ENGINEERING_RTSA.md for the
  ## numerical evidence.
  ##
  ## ** 0.2.7.13: ** this design pass is now ALWAYS run first, regardless of
  ## `boundary_route`, because its root (design_R) is what the "analysis"
  ## route is calibrated against. `legacy_fallback` (default TRUE) controls
  ## what happens if the compiled engine cannot produce a result (e.g. no
  ## root bracket exists for an unusual schedule): TRUE falls back to the
  ## pre-0.2.7.11 R-only approximate engine, with an impossible-to-miss
  ## warning and console banner, and marks the result
  ## (beta_engine$engine == "legacy_r_fallback"); FALSE fails closed --
  ## tsa_hr() stops with an error instead of silently substituting a
  ## non-RTSA-comparable engine. See ?tsa_hr, "legacy_fallback".
  boundary_timing_design <- sort(unique(c(info_fracs[info_fracs < 1], 1)))

  ## ** 0.2.7.14: ** explicit, programmatic record of any fallback, returned in
  ## `settings` (fallback_used / fallback_route / fallback_reason / route_used)
  ## so calling code never has to parse warning text to tell the cases apart:
  ##   fallback_route "none"   -- the requested route ran as requested;
  ##   fallback_route "design" -- boundary_route = "analysis" failed and the
  ##                              RTSA-derived DESIGN-route result is returned;
  ##   fallback_route "legacy" -- the RTSA-derived engine failed and the
  ##                              legacy, approximate R-only engine is used.
  fallback_used   <- FALSE
  fallback_route  <- "none"
  fallback_reason <- NA_character_
  route_used      <- boundary_route

  rtsa_fit <- tryCatch(
    .rtsa_design_bounds(boundary_timing_design, alpha = alpha_two_sided,
                        beta = 1 - power),
    error = function(e) e
  )
  used_legacy <- inherits(rtsa_fit, "error")
  if (used_legacy) {
    fb_msg <- paste0(
      "*** WARNING: THE RTSA-DERIVED BOUNDARY ENGINE FAILED (",
      conditionMessage(rtsa_fit), "). The alpha and futility boundaries in ",
      "this result were computed with the LEGACY, APPROXIMATE R-only engine ",
      "(pre-0.2.7.11) and are NOT comparable with RTSA. Do not report them ",
      "as RTSA-equivalent; check the design (information fractions, alpha, ",
      "power) or report the problem. ***"
    )
    if (!isTRUE(legacy_fallback)) {
      stop(paste0(
        "The RTSA-derived boundary engine failed (",
        conditionMessage(rtsa_fit), "), and legacy_fallback = FALSE means ",
        "tsa_hr() will not silently substitute the legacy, approximate ",
        "R-only engine. Set legacy_fallback = TRUE to allow that fallback ",
        "(with a warning), or address the underlying issue (check the ",
        "design: information fractions, alpha, power)."
      ), call. = FALSE)
    }
    warning(fb_msg, call. = FALSE, immediate. = TRUE)
    if (verbose) cat("\n", fb_msg, "\n\n", sep = "")
    legacy <- .tsahr_legacy_boundaries(info_fracs, boundary_timing_design,
                                       alpha_two_sided, 1 - power)
    alpha_bounds_design <- legacy$alpha_bounds_design
    beta_pre_daris      <- legacy$beta_pre_daris
    beta_engine <- c(legacy$beta_engine,
                     list(engine = "legacy_r_fallback",
                          engine_error = conditionMessage(rtsa_fit)))
    ## The legacy engine has no analysis-route counterpart; a request for
    ## boundary_route = "analysis" is honoured as closely as possible by
    ## falling back to the (also legacy) design-route result, noted below.
    if (boundary_route == "analysis" && verbose) {
      cat("Note: boundary_route = \"analysis\" was requested, but the legacy\n",
          "  fallback engine has no analysis-route equivalent; using its\n",
          "  design-route result instead.\n", sep = "")
    }
    route_endpoint      <- 1
    beta_final          <- utils::tail(alpha_bounds_design, 1)
    beta_bounds_design  <- c(beta_pre_daris, beta_final)
    boundary_timing     <- boundary_timing_design
    fallback_used       <- TRUE
    fallback_route      <- "legacy"
    fallback_reason     <- conditionMessage(rtsa_fit)
    route_used          <- "legacy"
  } else if (boundary_route == "design") {
    alpha_bounds_design <- rtsa_fit$alpha_ubound
    beta_pre_daris      <- rtsa_fit$beta_ubound[boundary_timing_design < 1]
    beta_engine <- c(rtsa_fit, list(engine = "rtsa_design_cpp",
                                    boundary = rtsa_fit$beta_ubound,
                                    warp_root = rtsa_fit$root))
    route_endpoint <- 1
    ## Final-look futility value (changed in 0.2.7.12): equal to the final
    ## efficacy bound, exactly as in RTSA's design pass, where the root
    ## search makes the futility bound meet the efficacy bound at t = 1.
    beta_final          <- utils::tail(alpha_bounds_design, 1)
    beta_bounds_design  <- c(beta_pre_daris, beta_final)
    boundary_timing     <- boundary_timing_design
  } else {
    ## boundary_route == "analysis": RTSA::RTSA(type = "analysis",
    ## design = NULL). The design pass above already gives design_R
    ## (rtsa_fit$root); build the analysis-pass timeline (observed looks
    ## capped/extended to design_R) exactly as RTSA's own RTSA() does, and
    ## run the analysis-route recursion (.rtsa_analysis_bounds()) against
    ## it. If THIS pass fails, the same legacy_fallback contract applies,
    ## but there is no legacy analysis-route engine to fall back to, so
    ## the fallback is the already-computed design-route result (with a
    ## warning explaining the substitution) rather than the pre-0.2.7.11
    ## approximate engine.
    design_R <- rtsa_fit$root
    t_ext <- if (max(info_fracs) < design_R) {
      c(info_fracs, design_R)
    } else if (max(info_fracs) > design_R) {
      c(info_fracs[info_fracs < design_R], design_R)
    } else {
      info_fracs
    }
    ana_fit <- tryCatch(
      .rtsa_analysis_bounds(t_ext, design_R, alpha = alpha_two_sided,
                            beta = 1 - power),
      error = function(e) e
    )
    if (inherits(ana_fit, "error")) {
      fb_msg2 <- paste0(
        "*** WARNING: THE RTSA ANALYSIS-ROUTE ENGINE FAILED (",
        conditionMessage(ana_fit), "). boundary_route = \"analysis\" was ",
        "requested, but tsa_hr() is falling back to its \"design\"-route ",
        "result instead (still the RTSA-derived compiled engine, just the ",
        "other route -- NOT the legacy R-only engine). ***"
      )
      if (!isTRUE(legacy_fallback)) {
        stop(paste0(
          "The RTSA analysis-route boundary engine failed (",
          conditionMessage(ana_fit), "), and legacy_fallback = FALSE means ",
          "tsa_hr() will not silently fall back to the design-route result. ",
          "Set legacy_fallback = TRUE to allow that fallback (with a ",
          "warning), pass boundary_route = \"design\" directly, or address ",
          "the underlying issue."
        ), call. = FALSE)
      }
      warning(fb_msg2, call. = FALSE, immediate. = TRUE)
      if (verbose) cat("\n", fb_msg2, "\n\n", sep = "")
      alpha_bounds_design <- rtsa_fit$alpha_ubound
      beta_pre_daris      <- rtsa_fit$beta_ubound[boundary_timing_design < 1]
      beta_engine <- c(rtsa_fit, list(engine = "rtsa_design_cpp",
                                      boundary = rtsa_fit$beta_ubound,
                                      warp_root = rtsa_fit$root,
                                      analysis_route_error = conditionMessage(ana_fit)))
      route_endpoint      <- 1
      beta_final          <- utils::tail(alpha_bounds_design, 1)
      beta_bounds_design  <- c(beta_pre_daris, beta_final)
      boundary_timing     <- boundary_timing_design
      fallback_used       <- TRUE
      fallback_route      <- "design"
      fallback_reason     <- conditionMessage(ana_fit)
      route_used          <- "design"
    } else {
      route_endpoint      <- design_R
      boundary_timing     <- ana_fit$timing
      alpha_bounds_design <- ana_fit$alpha_ubound
      beta_bounds_design  <- ana_fit$beta_ubound
      beta_pre_daris      <- beta_bounds_design[boundary_timing < route_endpoint]
      beta_engine <- c(ana_fit, list(engine = "rtsa_analysis_cpp",
                                     boundary = beta_bounds_design,
                                     design_R = design_R))
    }
  }

  ## -----------------------------------------------------------------
  ## 7b. Reconcile the events-scale DARIS reference with the
  ##     observed-information "reached" verdict above.
  ##
  ##     DARIS_events (Section 5) is a THEORETICAL translation of the
  ##     required information into an equivalent number of events, valid
  ##     only if every study's actual information-per-event equals the
  ##     pooled psi*(1-psi) assumption used in the Schoenfeld formula. In
  ##     practice, with heterogeneous studies (unequal allocation ratios,
  ##     differing censoring), the studies' true information-per-event
  ##     deviates from that assumption -- so comparing "events accrued"
  ##     to "DARIS_events" can disagree with the observed-information
  ##     criterion (info_accrued vs DARIS_info) that final_reached is
  ##     based on. This is exactly the kind of YES-in-text /
  ##     NOT-YET-in-plot discrepancy this block prevents.
  ##
  ##     NOTE ON TERMINOLOGY: cumsum(1/SE_i^2) is the OBSERVED cumulative
  ##     inverse-variance information, not an "exact" information in any
  ##     absolute sense -- in a random-effects model tau^2 is re-estimated
  ##     at every cumulative look, so this quantity is itself an
  ##     approximation of the canonical group-sequential information.
  ##     It is nonetheless the quantity this package uses as its primary
  ##     DARIS criterion (see DESCRIPTION), and is treated as such here.
  ##
  ##     Fix: locate the cumulative-events point at which the observed
  ##     information first reaches route_endpoint (1 for the design route;
  ##     design_R for the analysis route -- see 0.2.7.13, boundary_route),
  ##     by linear interpolation between the two bracketing looks. Because
  ##     no study actually occurred exactly at that interpolated event
  ##     count, this is an ESTIMATE of where the threshold was crossed, not
  ##     an event count that was itself observed -- it is deliberately NOT
  ##     called "DARIS events": that label is reserved for the theoretical
  ##     Schoenfeld-based event-equivalent (DARIS_events) computed in
  ##     Section 5. plot.tsa_hr() shows BOTH quantities, separately
  ##     labelled, rather than substituting one for the other. If the
  ##     endpoint has NOT been reached within the observed data, there is
  ##     nothing to interpolate.
  ## -----------------------------------------------------------------
  ## ** 0.2.7.14: ** two DISTINCT thresholds are now kept apart instead of
  ## one being called "DARIS" in both routes:
  ##   * DARIS itself (info_fraction = 1, i.e. DARIS_info) --
  ##     `daris_reached` / `DARIS_info_threshold_events`, identical in both
  ##     routes;
  ##   * the ROUTE ENDPOINT (route_endpoint * DARIS_info; = DARIS for the
  ##     design route, design_R * DARIS for the analysis route) --
  ##     `final_reached` / `route_endpoint_events_est`. THIS is the formal
  ##     analysis endpoint the decision layer is evaluated at.
  ## For the design route route_endpoint == 1, so both coincide exactly and
  ## every value below is unchanged from 0.2.7.13.
  final_reached <- max(info_fracs) >= route_endpoint
  daris_reached <- max(info_fracs) >= 1
  analysis_endpoint <- identical(route_used, "analysis")
  route_endpoint_info <- route_endpoint * DARIS_info

  DARIS_info_threshold_events <- .tsahr_events_at_fraction(cumul_df, 1)
  route_endpoint_events_est <- if (route_endpoint == 1) {
    DARIS_info_threshold_events
  } else {
    .tsahr_events_at_fraction(cumul_df, route_endpoint)
  }
  endpoint_name <- if (analysis_endpoint) {
    sprintf("analysis-route endpoint (%.3f x DARIS)", route_endpoint)
  } else {
    "DARIS"
  }

  ## Map only genuine pre-DARIS observed looks back to the cumulative
  ## study table.  The synthetic t = 1 HARIS point is stored separately in
  ## `boundary_timeline`; it is not an observed study and therefore must
  ## not be inserted into `cumul_df`.
  boundary_z <- rep(NA_real_, length(info_fracs))
  futility_z <- rep(NA_real_, length(info_fracs))
  pre_daris <- info_fracs < route_endpoint
  if (any(pre_daris)) {
    boundary_z[pre_daris] <- alpha_bounds_design[match(info_fracs[pre_daris],
                                                       boundary_timing)]
    futility_z[pre_daris] <- beta_bounds_design[match(info_fracs[pre_daris],
                                                       boundary_timing)]
  }

  cumul_df$TSA_boundary_upper <- boundary_z
  cumul_df$TSA_boundary_lower <- -boundary_z
  cumul_df$TSA_futility_upper <- futility_z
  cumul_df$TSA_futility_lower <- -futility_z

  ## X-coordinate of the synthetic t = 1 boundary.  When the observed
  ## cumulative information has actually reached DARIS, the formal final
  ## boundary must terminate at that OBSERVED-information threshold, not at
  ## the theoretical Schoenfeld event-equivalent DARIS_events.  The latter
  ## remains a separate theoretical reference on the plot.
  ##
  ## DARIS_info_threshold_events is obtained by linear interpolation between
  ## the two observed looks bracketing info_fraction = 1.  It therefore marks
  ## the estimated event-coordinate at which the decision information target
  ## was reached.  If DARIS has not yet been reached, RTSA's retrospective
  ## design endpoint remains the theoretical t = 1 event-equivalent.
  ## ** 0.2.7.14: ** the endpoint is the ROUTE endpoint: for the analysis
  ## route the not-yet-reached fallback is the theoretical event-equivalent
  ## of design_R * DARIS (DARIS_events * route_endpoint), not of DARIS.
  boundary_endpoint_events <- if (final_reached &&
                                   is.finite(route_endpoint_events_est)) {
    route_endpoint_events_est
  } else {
    DARIS_events * route_endpoint
  }

  boundary_timeline <- data.frame(
    info_fraction = boundary_timing,
    cum_events = c(
      vapply(boundary_timing[boundary_timing < route_endpoint], function(tt) {
        idx <- which(info_fracs == tt)[1]
        cumul_df$cum_events[idx]
      }, numeric(1)),
      boundary_endpoint_events
    ),
    TSA_boundary_upper = alpha_bounds_design,
    TSA_boundary_lower = -alpha_bounds_design,
    TSA_futility_upper = beta_bounds_design,
    TSA_futility_lower = -beta_bounds_design,
    synthetic = boundary_timing == route_endpoint,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat("=== Trial sequential monitoring boundaries (alpha/beta spending) ===\n")
    if (analysis_endpoint) {
      cat(sprintf(paste0("Formal final boundary endpoint (%s = %.4f information ",
                         "units): %.1f cumulative events\n"),
                  endpoint_name, route_endpoint_info, boundary_endpoint_events))
    } else {
      cat(sprintf("Formal final boundary endpoint (DARIS information reached): %.1f cumulative events\n",
                  boundary_endpoint_events))
    }
    print(cumul_df[, c("Study", "info_fraction", "Z", "TSA_boundary_upper", "TSA_futility_upper")])
    cat("\n")
  }

  ## -----------------------------------------------------------------
  ## 7c. Formal decision logic: restrict to looks up to and including
  ##     DARIS being first reached.
  ##
  ##     Once DARIS is reached, the planned monitoring process is complete.
  ##     The first DARIS-reaching observed look is therefore compared with
  ##     the definitive t = 1 boundary, while later observed studies are
  ##     not treated as additional final looks.
  ##
  ##     The formal "crossed_tsa" / "entered_futility_region" verdicts are
  ##     therefore evaluated only through the FIRST look at which DARIS
  ##     was reached (or through all looks, if DARIS was never reached).
  ##     The full cumulative Z-curve, including any studies added after
  ##     DARIS, is still returned/plotted in full -- only the formal
  ##     sequential decision is restricted, not what is shown.
  final_tsa_look <- if (final_reached) which(info_fracs >= route_endpoint)[1] else length(info_fracs)
  decision_idx <- seq_len(final_tsa_look)

  ## For the formal decision, the first look reaching the route endpoint
  ## (1 for the design route; design_R for the analysis route) is compared
  ## with the definitive boundary at that endpoint, even though that
  ## boundary is displayed at the synthetic HARIS endpoint rather than on
  ## the observed post-endpoint study rows.
  decision_boundary_upper <- boundary_timeline$TSA_boundary_upper[
    match(pmin(info_fracs[decision_idx], route_endpoint), boundary_timeline$info_fraction)
  ]
  decision_futility_upper <- boundary_timeline$TSA_futility_upper[
    match(pmin(info_fracs[decision_idx], route_endpoint), boundary_timeline$info_fraction)
  ]

  crossed_tsa <- any(abs(cumul_df$Z[decision_idx]) >= decision_boundary_upper,
                     na.rm = TRUE)
  ## `crossed_conventional` is DELIBERATELY evaluated over the FULL
  ## cumulative Z-curve (unlike crossed_tsa/entered_futility_region,
  ## which are restricted to decision_idx). This is intentional: it
  ## answers "did the naive, uncorrected cumulative P-value ever drop
  ## below 0.05?", including at studies added after DARIS was reached,
  ## as a deliberate contrast against the properly-scoped crossed_tsa --
  ## illustrating exactly the repeated-testing inflation risk that TSA
  ## exists to guard against. If you instead want "did the formal
  ## sequential analysis reach conventional significance at/before the
  ## DARIS decision look" (the same horizon as crossed_tsa), use
  ## `any(abs(cumul_df$Z[decision_idx]) >= z_alpha, na.rm = TRUE)`
  ## instead. Decide explicitly before changing this -- both readings
  ## are defensible, but they answer different questions.
  crossed_conventional <- any(abs(cumul_df$Z) >= z_alpha)
  ## `entered_futility_region` uses the same decision_idx / definitive
  ## t=1-boundary comparison as crossed_tsa (see comment above
  ## decision_idx). At the first DARIS-reaching look specifically, this
  ## means comparing against the FINAL futility boundary (which, as in
  ## RTSA's design pass, equals the final efficacy boundary), not an interim futility
  ## boundary -- so entered_futility_region == TRUE at that look does
  ## NOT mean "TSA recommends stopping for futility now"; the printed
  ## summary label says "(not a formal stopping decision)" for exactly
  ## this reason. That caveat lives only in the printed/summary text,
  ## not in the boolean itself -- a caller reading
  ## `results$entered_futility_region` programmatically (bypassing the
  ## printed output) will not see it. See ?tsa_hr, "Value", for the
  ## corresponding caveat in the documented return value.
  entered_futility_region <- any(abs(cumul_df$Z[decision_idx]) <= decision_futility_upper,
                                  na.rm = TRUE)

  ## ** 0.2.7.14: DEFINITIVE-LOOK fields (fix of the 0.2.7.13 semantics). **
  ##
  ## `crossed_tsa` and `entered_futility_region` above are "at ANY formal
  ## look up to the route endpoint" quantities. 0.2.7.13 defined
  ## `final_non_efficacy <- !crossed_tsa`, which is NOT "the definitive look
  ## did not cross efficacy": a trial that crossed at an interim look and
  ## then fell back below the boundary at the definitive look would report
  ## FALSE. The fields below refer to the definitive look ONLY --
  ## `final_tsa_look`, the first look reaching the route endpoint -- and are
  ## NA when that endpoint has not been reached (there is then no
  ## definitive look to report on).
  ##
  ## Because the futility and efficacy boundaries meet at the definitive
  ## look, `final_entered_futility_region` there is the complement of
  ## `final_crossed_efficacy` (both would be TRUE only at |Z| exactly equal
  ## to the boundary). Neither is a recommendation to stop early.
  definitive <- .tsahr_definitive_look(cumul_df$Z, final_reached, final_tsa_look,
                                       decision_boundary_upper,
                                       decision_futility_upper)
  final_crossed_efficacy        <- definitive$final_crossed_efficacy
  final_entered_futility_region <- definitive$final_entered_futility_region
  final_non_efficacy            <- definitive$final_non_efficacy

  ## -----------------------------------------------------------------
  ## 7d. Retrospective HR-specific projection: estimated additional
  ##     studies/events needed to reach the route's own target
  ##     information, based directly on the OBSERVED study-level
  ##     information increments (see "Estimated additional
  ##     studies/events" under ?tsa_hr Details).
  ##
  ##     I_required is computed separately per route and never conflated:
  ##       - design route:   I_required = DARIS            (DARIS_info)
  ##       - analysis route: I_required = design_R x DARIS (route_endpoint_info)
  ##     `central_info_increment`/`central_event_increment` are the
  ##     `projection_stat` (median by default, mean if requested) of each
  ##     included study's own information (1/Std_Error^2) and event count
  ##     -- i.e. a single "typical future study" increment estimated from
  ##     the studies already in the data, not from any new assumption.
  ##     `n_additional_studies` is always rounded UP to a natural number
  ##     (>= 1 whenever there is a genuine positive shortfall).
  ## -----------------------------------------------------------------
  events_accrued     <- sum(data$total_events)
  info_accrued_final <- cumul_df$info_accrued[nrow(cumul_df)]

  per_study_info_increment  <- 1 / data$Std_Error^2
  per_study_event_increment <- data$total_events
  n_studies_total <- length(per_study_event_increment)
  central_fun <- if (identical(projection_stat, "mean")) mean else stats::median
  central_info_increment  <- central_fun(per_study_info_increment)
  central_event_increment <- central_fun(per_study_event_increment)

  ## 0.2.8.5/0.2.8.6: information per event, study by study. Additional
  ## EVENTS are the primary projected quantity and come straight from the
  ## information shortfall (continuous, not through a whole number of
  ## studies); the number of studies is a separate, secondary translation of
  ## the same shortfall. Studies with zero events (or another non-finite /
  ## non-positive ratio) are technically accepted but carry no usable
  ## information-per-event, so they are left out of the events projection
  ## ONLY (they stay in the studies projection and in every other result);
  ## the number excluded is reported explicitly.
  per_study_info_per_event <- per_study_info_increment / per_study_event_increment
  ok_ratio <- is.finite(per_study_info_per_event) & per_study_info_per_event > 0
  n_zero_event_studies         <- sum(per_study_event_increment == 0, na.rm = TRUE)
  n_excluded_events_projection <- sum(!ok_ratio)
  study_level_info_per_event <- if (any(ok_ratio)) {
    central_fun(per_study_info_per_event[ok_ratio])
  } else {
    NA_real_
  }
  ## ratio of sums (dominated by the larger studies), i.e. the slope of
  ## observed cumulative information against cumulative events
  pooled_info_per_event <- if (any(ok_ratio)) {
    sum(per_study_info_increment[ok_ratio]) / sum(per_study_event_increment[ok_ratio])
  } else {
    NA_real_
  }
  ## The historical rate actually used for the events projection; both
  ## variants are always returned so the choice can be checked.
  central_info_per_event <- if (identical(info_per_event_basis, "pooled")) {
    pooled_info_per_event
  } else {
    study_level_info_per_event
  }
  info_per_event_basis_label <- if (identical(info_per_event_basis, "pooled")) {
    "pooled ratio: total information / total events"
  } else {
    sprintf("%s of the study-level information per event", projection_stat)
  }
  exclusion_note <- if (n_excluded_events_projection == 0L) {
    NULL
  } else if (n_excluded_events_projection == n_zero_event_studies) {
    sprintf(paste0("%d of %d %s excluded from the information-per-event ",
                   "(events) projection: they carry information but no events ",
                   "to attach it to. They remain in the additional-studies ",
                   "projection and in all other results."),
            n_excluded_events_projection, n_studies_total,
            if (n_excluded_events_projection == 1L) "study with zero events was"
            else "studies with zero events were")
  } else {
    sprintf(paste0("%d of %d studies were excluded from the ",
                   "information-per-event (events) projection (%d with zero ",
                   "events, %d with another non-finite or non-positive ratio). ",
                   "They remain in the additional-studies projection and in ",
                   "all other results."),
            n_excluded_events_projection, n_studies_total, n_zero_event_studies,
            n_excluded_events_projection - n_zero_event_studies)
  }

  I_required <- route_endpoint_info
  additional_info_required_raw <- I_required - info_accrued_final

  n_additional_studies_est      <- NA_integer_
  additional_events_estimated   <- NA_real_
  additional_events_study_level <- NA_real_
  additional_events_pooled      <- NA_real_
  events_from_whole_studies     <- NA_real_
  target_events_historical_rate <- NA_real_
  if (!final_reached && is.finite(additional_info_required_raw) &&
      additional_info_required_raw > 0) {
    ## Primary: events = remaining information / information per event
    ## (continuous; rounded up only for display).
    if (is.finite(study_level_info_per_event) && study_level_info_per_event > 0) {
      additional_events_study_level <- additional_info_required_raw /
        study_level_info_per_event
    }
    if (is.finite(pooled_info_per_event) && pooled_info_per_event > 0) {
      additional_events_pooled <- additional_info_required_raw /
        pooled_info_per_event
    }
    additional_events_estimated <- if (identical(info_per_event_basis, "pooled")) {
      additional_events_pooled
    } else {
      additional_events_study_level
    }
    ## Cumulative-events position at which the route's target information
    ## would be reached at the historical rate (drawn by plot() for the
    ## design route as the "DARIS (historical rate)" reference line).
    if (is.finite(additional_events_estimated)) {
      target_events_historical_rate <- events_accrued + additional_events_estimated
    }
    ## Secondary: whole number of typical studies (rounded UP, >= 1 here
    ## because a genuine shortfall exists) and the events those whole
    ## studies would bring -- a different question from the events above.
    if (is.finite(central_info_increment) && central_info_increment > 0) {
      n_additional_studies_est <- max(1L, ceiling(additional_info_required_raw /
                                                    central_info_increment))
      if (is.finite(central_event_increment)) {
        events_from_whole_studies <- n_additional_studies_est * central_event_increment
      }
    }
  }

  ## Design-route THEORETICAL additional-events figure is NOT the projection
  ## above: it is the direct, deterministic Schoenfeld-scale difference
  ## between the two event-equivalents already computed in Section 5
  ## (DARIS_events) and Section 8 below (events_accrued) -- both under the
  ## same pooled-psi assumption, so no further projection is needed for this
  ## one figure. The design route reports it next to the historical-rate
  ## estimate above.
  additional_events_required_design <- if (!daris_reached) {
    max(ceiling(DARIS_events - events_accrued), 0)
  } else {
    NA_real_
  }

  ## 0.2.8.7: the same Schoenfeld-scale figure for the route's OWN target, so
  ## both routes report theoretical + historical-rate events side by side.
  ## Design: DARIS_events - events_accrued (== additional_events_required_design);
  ## analysis: DARIS_events * design_R - events_accrued (the theoretical
  ## event-equivalent of the analysis-route endpoint minus events accrued).
  additional_events_theoretical <- if (!final_reached) {
    max(ceiling(DARIS_events * route_endpoint - events_accrued), 0)
  } else {
    NA_real_
  }

  projection_note <- paste0(
    "Projection assumes future studies contribute information at ",
    "approximately the observed historical rate (", info_per_event_basis_label,
    "); it is not a formal guarantee of the number of future studies or ",
    "events required. It is a linear extrapolation on the fixed-effect, ",
    "study-level inverse-variance information scale that is compared with ",
    "DARIS, and it does not model how random-effects weights or the ",
    "between-study variance (\u03c4\u00b2) would change as further studies ",
    "are added; treat it as indicative only."
  )

  projection <- list(
    method = projection_stat,
    info_per_event_basis = info_per_event_basis,
    I_required = I_required,
    info_accrued = info_accrued_final,
    events_accrued = events_accrued,
    additional_info_required = if (!final_reached) max(additional_info_required_raw, 0) else NA_real_,
    central_info_increment = central_info_increment,
    central_event_increment = central_event_increment,
    central_info_per_event = central_info_per_event,
    study_level_info_per_event = study_level_info_per_event,
    pooled_info_per_event = pooled_info_per_event,
    n_additional_studies = n_additional_studies_est,
    additional_events_estimated = additional_events_estimated,
    additional_events_study_level = additional_events_study_level,
    additional_events_pooled = additional_events_pooled,
    events_from_whole_studies = events_from_whole_studies,
    target_events_historical_rate = target_events_historical_rate,
    additional_events_required_design = additional_events_required_design,
    additional_events_theoretical = additional_events_theoretical,
    n_studies = n_studies_total,
    n_zero_event_studies = n_zero_event_studies,
    n_excluded_events_projection = n_excluded_events_projection,
    note = projection_note
  )

  if (verbose) {
    if (final_reached && final_tsa_look < nrow(cumul_df)) {
      cat(sprintf(paste0("Note: %s was reached at study #%d of %d ('%s'). Formal TSA\n",
                          "  boundary-crossing/futility decisions below are evaluated only\n",
                          "  through that look (studies added afterward are still shown in\n",
                          "  the returned data and plot, but are not treated as additional\n",
                          "  formal '%s' analyses -- see ?tsa_hr).\n"),
                  endpoint_name, final_tsa_look, nrow(cumul_df),
                  cumul_df$Study[final_tsa_look],
                  if (analysis_endpoint) sprintf("t=%.3f", route_endpoint) else "t=1"))
    }
    cat(sprintf("Cumulative Z-curve crossed the conventional (P<0.05) boundary: %s\n",
                ifelse(crossed_conventional, "YES", "NO")))
    cat(sprintf("Cumulative Z-curve crossed the TSA monitoring boundary       : %s\n",
                ifelse(crossed_tsa, "YES", "NO")))
    cat(sprintf("Cumulative Z-curve entered the non-binding futility region  : %s\n",
                ifelse(entered_futility_region, "YES", "NO")))
    if (final_reached) {
      cat(sprintf("Definitive look (%s) crossed the efficacy boundary%s: %s\n",
                  if (analysis_endpoint) "route endpoint" else "DARIS",
                  if (analysis_endpoint) "" else "         ",
                  ifelse(final_crossed_efficacy, "YES", "NO")))
    }
    cat(sprintf("Required information size (DARIS) reached                    : %s\n",
                ifelse(daris_reached, "YES", "NO")))
    if (analysis_endpoint) {
      cat(sprintf("Analysis-route endpoint (%.3f x DARIS) reached               : %s\n",
                  route_endpoint, ifelse(final_reached, "YES", "NO")))
    }
    cat(sprintf("  Theoretical DARIS event-equivalent (Schoenfeld-based)        : %.0f\n",
                ceiling(DARIS_events)))
    if (analysis_endpoint) {
      cat(sprintf(paste0("  Theoretical event-equivalent of the analysis-route endpoint\n",
                          "  (%.3f x DARIS)                                            : %.0f\n"),
                  route_endpoint, ceiling(DARIS_events * route_endpoint)))
    }
    if (daris_reached) {
      cat(sprintf(paste0("  Estimated cumulative events at which DARIS information\n",
                          "  was reached (interpolated, not an observed look)          : %.0f\n"),
                  ceiling(DARIS_info_threshold_events)))
      if (abs(DARIS_info_threshold_events - DARIS_events) > 0.01 * DARIS_events) {
        cat(sprintf(paste0("  (These may differ because the observed study-level information\n",
                            "   per event differs from the pooled psi*(1-psi) approximation\n",
                            "   used for the theoretical event-equivalent -- in either\n",
                            "   direction, not necessarily because information accrued faster.)\n")))
      }
    }
    cat("\n")
    ## Estimated additional studies/events (7d) -- printed only when the
    ## route's own target has NOT been reached; design and analysis routes
    ## use different labels/figures (see 7d comment above and ?tsa_hr,
    ## "Estimated additional studies/events").
    if (!analysis_endpoint && !daris_reached) {
      cat(sprintf("Events accrued = %.0f\n\n", events_accrued))
      cat(sprintf("Theoretical additional events to DARIS (Schoenfeld): %.0f\n",
                  additional_events_required_design))
      ## 0.2.8.9: where (in cumulative events) DARIS would be reached at the
      ## historical information/event rate -- the same position plot() draws
      ## as "DARIS (historical rate)" -- shown just before the
      ## additional-events figure (mirrors the analysis route).
      if (is.finite(target_events_historical_rate)) {
        cat(sprintf(paste0("DARIS (historical rate): ~%s cumulative events\n",
                           "  (%s information units per event)\n"),
                    formatC(ceiling(target_events_historical_rate), format = "d", big.mark = ","),
                    formatC(central_info_per_event, format = "f", digits = 4)))
      }
      if (is.na(additional_events_estimated)) {
        cat("Estimated additional events to DARIS (historical rate): cannot be estimated\n")
        cat("  (no study with a usable information-per-event ratio to project from)\n")
      } else {
        cat(sprintf("Estimated additional events to DARIS (historical rate): ~%s\n",
                    formatC(ceiling(additional_events_estimated), format = "d", big.mark = ",")))
      }
      if (is.na(n_additional_studies_est)) {
        cat("Estimated additional studies required: cannot be estimated\n")
        cat("  (no usable historical per-study information increment to project from)\n")
      } else {
        cat(sprintf("Estimated additional studies required: %d\n",
                    n_additional_studies_est))
      }
      if (!is.null(exclusion_note)) {
        cat(strwrap(paste0("Note: ", exclusion_note), width = 78,
                    prefix = "", initial = ""), sep = "\n")
        cat("\n")
      }
      cat(strwrap(paste0("Note: ", projection_note), width = 78,
                  prefix = "", initial = ""), sep = "\n")
      cat("\n")
    } else if (analysis_endpoint && !final_reached) {
      cat(sprintf(
        paste0("Analysis-route endpoint (%.3f x DARIS) = %s information units): ",
               "%s cumulative events\n"),
        route_endpoint,
        formatC(route_endpoint_info, format = "f", digits = 4, big.mark = ","),
        formatC(boundary_endpoint_events, format = "f", digits = 0, big.mark = ",")))
      cat(sprintf("Additional information required: %s\n",
                  formatC(projection$additional_info_required, format = "f",
                          digits = 3, big.mark = ",")))
      cat(sprintf("Events accrued = %.0f\n", events_accrued))
      cat(sprintf("Theoretical additional events to analysis-route endpoint (Schoenfeld): %.0f\n",
                  additional_events_theoretical))
      ## 0.2.8.8: where (in cumulative events) the analysis-route endpoint
      ## would be reached at the historical information/event rate -- the
      ## same position plot() labels "Historical information/event-rate
      ## projection" -- shown just before the additional-events figure.
      if (is.finite(target_events_historical_rate)) {
        cat(sprintf(paste0("Historical information/event-rate projection = ~%s cumulative events\n",
                           "  (%s information units per event)\n"),
                    formatC(ceiling(target_events_historical_rate), format = "d", big.mark = ","),
                    formatC(central_info_per_event, format = "f", digits = 4)))
      }
      if (is.na(additional_events_estimated)) {
        cat("Estimated additional events to analysis-route endpoint (historical rate): cannot be estimated\n")
        cat("  (no study with a usable information-per-event ratio to project from)\n")
      } else {
        cat(sprintf("Estimated additional events to analysis-route endpoint (historical rate): ~%s\n",
                    formatC(ceiling(additional_events_estimated), format = "d", big.mark = ",")))
      }
      if (is.na(n_additional_studies_est)) {
        cat("Estimated additional studies required: cannot be estimated\n")
        cat("  (no usable historical per-study information increment to project from)\n")
      } else {
        cat(sprintf("Estimated additional studies required: %d\n",
                    n_additional_studies_est))
      }
      if (!is.null(exclusion_note)) {
        cat(strwrap(paste0("Note: ", exclusion_note), width = 78,
                    prefix = "", initial = ""), sep = "\n")
        cat("\n")
      }
      cat(strwrap(paste0("Note: ", projection_note), width = 78,
                  prefix = "", initial = ""), sep = "\n")
      cat("\n")
    }
    cat(strwrap(paste0(
      "Note: The \u03c4\u00b2 estimator may have limited influence on the pooled ",
      "average effect-size when the evidence base is substantial, but it can ",
      "materially influence heterogeneity-dependent quantities, prediction ",
      "intervals, DARIS, and the timing of TSA conclusions\u2014particularly ",
      "when cumulative information is near the DARIS threshold."
    ), width = 78, prefix = "", initial = ""), sep = "\n")
    cat("\n")
  }

  ## -----------------------------------------------------------------
  ## 8. Summary table
  ## -----------------------------------------------------------------
  ## events_accrued / info_accrued_final are already computed in 7d above.

  ## ** 0.2.7.14: ** decision rows distinguish "at ANY formal look" from "at
  ## the DEFINITIVE look" (see the decision-fields comment above); the
  ## analysis-route endpoint row is added only when that route actually ran.
  sum_par <- c("Pooled HR (random effects, observed)", "95% CI lower", "95% CI upper",
               "Anticipated HR (used for RIS calculation)",
               "I2 (%)", "tau2", "Diversity D2 (%)", "Adjustment factor",
               "Allocation psi (proportion in treatment arm)",
               "Required statistical information (allocation-free)",
               "Required Information Size in events (RIS, under pooled psi)",
               "Diversity-Adjusted Required Information (DARIS, information units)",
               "Theoretical DARIS event-equivalent (Schoenfeld-based, under pooled psi)",
               "Events accrued (reporting scale)",
               "Statistical information accrued (observed inverse-variance)",
               "% of DARIS (information) reached",
               "Estimated cumulative events at which DARIS information was reached")
  sum_val <- c(round(exp(res_re$b), 3), round(exp(res_re$ci.lb), 3), round(exp(res_re$ci.ub), 3),
               round(HR_anticipated, 3),
               round(I2, 1), round(tau2, 4), round(D2 * 100, 1), round(AF, 3),
               round(allocation_p_used, 4),
               round(info_required, 4),
               ceiling(RIS_events),
               round(DARIS_info, 4),
               ceiling(DARIS_events),
               events_accrued,
               round(info_accrued_final, 4),
               round(100 * info_accrued_final / DARIS_info, 1),
               ifelse(is.na(DARIS_info_threshold_events), NA_real_,
                      ceiling(DARIS_info_threshold_events)))
  if (analysis_endpoint) {
    sum_par <- c(sum_par, sprintf(
      "Estimated cumulative events at which the analysis-route endpoint (%.3f x DARIS) was reached",
      route_endpoint))
    sum_val <- c(sum_val, ifelse(is.na(route_endpoint_events_est), NA_real_,
                                 ceiling(route_endpoint_events_est)))
  }
  ## Estimated additional studies/events rows (7d) -- appended only when
  ## the route's own target has NOT been reached, matching the printed
  ## verbose output; design and analysis routes report different figures
  ## (see 7d comment and ?tsa_hr, "Estimated additional studies/events").
  if (!analysis_endpoint && !daris_reached) {
    sum_par <- c(sum_par,
                 "Theoretical additional events to DARIS (Schoenfeld)",
                 "DARIS (historical rate): cumulative events at which DARIS would be reached",
                 sprintf("Estimated additional events to DARIS (historical rate; %s)",
                         info_per_event_basis_label),
                 sprintf("Estimated additional studies to reach DARIS (%s-based projection)",
                        projection_stat),
                 "Studies excluded from the events projection (zero events / unusable ratio)")
    sum_val <- c(sum_val,
                 additional_events_required_design,
                 ifelse(is.finite(target_events_historical_rate),
                        ceiling(target_events_historical_rate), NA_real_),
                 ifelse(is.na(additional_events_estimated), NA_real_,
                        ceiling(additional_events_estimated)),
                 ifelse(is.na(n_additional_studies_est), NA_real_, n_additional_studies_est),
                 n_excluded_events_projection)
  } else if (analysis_endpoint && !final_reached) {
    sum_par <- c(sum_par,
                 sprintf("Additional information required to reach the analysis-route endpoint (%.3f x DARIS)",
                        route_endpoint),
                 "Theoretical additional events to analysis-route endpoint (Schoenfeld)",
                 "Historical information/event-rate projection (cumulative events at the analysis-route endpoint)",
                 sprintf("Estimated additional events to analysis-route endpoint (historical rate; %s)",
                         info_per_event_basis_label),
                 sprintf("Estimated additional studies to reach the analysis-route endpoint (%s-based projection)",
                        projection_stat),
                 "Studies excluded from the events projection (zero events / unusable ratio)")
    sum_val <- c(sum_val,
                 round(projection$additional_info_required, 4),
                 additional_events_theoretical,
                 ifelse(is.finite(target_events_historical_rate),
                        ceiling(target_events_historical_rate), NA_real_),
                 ifelse(is.na(additional_events_estimated), NA_real_,
                        ceiling(additional_events_estimated)),
                 ifelse(is.na(n_additional_studies_est), NA_real_, n_additional_studies_est),
                 n_excluded_events_projection)
  }
  sum_par <- c(sum_par,
               "Crossed conventional boundary",
               "Crossed TSA monitoring boundary (at any formal look)",
               "Entered non-binding futility region (at any formal look; not a formal stopping decision)",
               "Definitive look crossed efficacy boundary (NA if the endpoint was not reached)",
               "Definitive look did not cross efficacy (final_non_efficacy; NA if the endpoint was not reached)")
  ## ** 0.2.7.22: ** `Value` is a CHARACTER column. Building it with c() of
  ## numbers and logicals silently coerced everything to numeric, so the
  ## TRUE/FALSE decision rows printed as 1/0. Numbers keep their rounding;
  ## logicals print as TRUE/FALSE/NA; NA stays NA.
  sum_val <- c(.tsahr_format_numeric(sum_val),
               .tsahr_format_logical(c(crossed_conventional, crossed_tsa,
                                       entered_futility_region,
                                       final_crossed_efficacy, final_non_efficacy)))
  summary_df <- data.frame(Parameter = sum_par, Value = sum_val,
                           stringsAsFactors = FALSE)

  out <- list(
    data = data,
    call = match.call(),
    parameters = list(alpha_two_sided = alpha_two_sided, power = power,
                       allocation_source = allocation_source,
                       allocation_p_used = allocation_p_used,
                       target_HR = target_HR, HR_anticipated = HR_anticipated,
                       method = method,
                       method_requested = method_requested),
    res_re = res_re,
    res_fe = res_fe,
    heterogeneity = list(Q = Q, df = df, I2 = I2, tau2 = tau2, D2 = D2,
                          D2_raw = D2_raw, D2_was_capped = D2_was_capped, AF = AF),
    beta_engine = beta_engine,
    information_size = list(z_alpha = z_alpha, z_beta = z_beta,
                             info_required = info_required, RIS_events = RIS_events,
                             DARIS_info = DARIS_info, DARIS_events = DARIS_events,
                             DARIS_info_threshold_events = DARIS_info_threshold_events,
                             route_endpoint_info = route_endpoint_info,
                             route_endpoint_events = route_endpoint_events_est,
                             circularity_warning = circularity_warning,
                             circularity_severe = circularity_severe),
    cumulative = cumul_df,
    boundary_timeline = boundary_timeline,
    results = list(crossed_conventional = crossed_conventional,
                   crossed_tsa = crossed_tsa,
                   entered_futility_region = entered_futility_region,
                   final_crossed_efficacy = final_crossed_efficacy,
                   final_non_efficacy = final_non_efficacy,
                   final_entered_futility_region = final_entered_futility_region,
                   final_reached = final_reached,
                   daris_reached = daris_reached,
                   final_tsa_look = final_tsa_look,
                   events_accrued = events_accrued,
                   info_accrued_final = info_accrued_final),
    settings = list(boundary_route = boundary_route,
                    legacy_fallback = legacy_fallback,
                    route_endpoint = route_endpoint,
                    route_endpoint_info = route_endpoint_info,
                    route_used = route_used,
                    fallback_used = fallback_used,
                    fallback_route = fallback_route,
                    fallback_reason = fallback_reason,
                    used_legacy_engine = used_legacy),
    projection = projection,
    summary_table = summary_df
  )
  class(out) <- "tsa_hr"
  out
}
