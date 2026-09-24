\name{tsa_hr}
\alias{tsa_hr}
\title{Trial Sequential Analysis for a meta-analysis of Hazard Ratios}
\usage{
tsa_hr(data, alpha_two_sided = 0.05, power = 0.80,
  allocation_source = c("data", "manual"), allocation_p = 0.5,
  target_HR = NA_real_, method = "DL", order_by = NULL, verbose = TRUE,
  boundary_route = c("design", "analysis"), legacy_fallback = TRUE,
  projection_stat = c("median", "mean"),
  info_per_event_basis = c("per_study", "pooled"))
}
\arguments{
\item{data}{A data.frame, or a path to an .xlsx file, containing one row
per study with (at least) the columns: \code{Study}, \code{log_HR},
\code{Std_Error}, \code{Events_Treatment}, \code{N_treatment},
\code{Events_controls}, \code{N_controls}. Rows are treated as being in
chronological (publication) order; reorder your data before calling this
function if the row order in your file is not chronological.}

\item{alpha_two_sided}{Overall two-sided type I error for the TSA
monitoring boundaries. Default \code{0.05}.}

\item{power}{Desired power (1 - beta) for the required information size
calculation. Default \code{0.80}.}

\item{allocation_source}{Either \code{"data"} (default; the allocation
ratio psi is computed automatically as
\code{sum(N_treatment) / sum(N_treatment + N_controls)} across the
included studies) or \code{"manual"} (psi is fixed to
\code{allocation_p}, e.g. for planning a future trial with a
pre-specified ratio).}

\item{allocation_p}{Allocation proportion to use when
\code{allocation_source = "manual"}. Must be strictly between 0 and 1.
Ignored when \code{allocation_source = "data"}.}

\item{target_HR}{Anticipated hazard ratio used for the required
information size calculation. Default \code{NA}, which uses the
\emph{observed} pooled HR from the random-effects meta-analysis -- see
Details for an important caution about this default. Set to a
pre-specified clinically-anticipated value (e.g. \code{0.80}) for a
standard, non-circular, protocol-driven TSA.}

\item{method}{Character string specifying the heterogeneity-variance
(tau^2) estimator used for the \emph{random-effects} meta-analysis and
cumulative (sequential) TSA model, passed to
\code{method} in \code{metafor::rma()} after validation and, for the
aliases \code{"CO"}/\code{"VC"}, normalisation to \code{"HE"}. One of \code{"DL"}
(DerSimonian-Laird, the default -- kept as the default here for backward
compatibility with earlier tsahr versions, which always used DL; note
this differs from \code{metafor::rma()}'s own default of \code{"REML"}),
\code{"HE"}, \code{"HS"}, \code{"HSk"}, \code{"SJ"}, \code{"ML"},
\code{"REML"}, \code{"EB"}, \code{"PM"}, or \code{"PMM"}. \code{"CO"} and
\code{"VC"} are also accepted and normalised to \code{"HE"} (see below).
See
\code{?metafor::rma} for the definition of each estimator. This only
changes the \emph{random-effects} model (\code{res_re}); the equal-effects
model used internally for the Diversity (D^2) heterogeneity adjustment is
always fitted with \code{method = "FE"} and is unaffected by this
argument. Alpha-/beta-spending boundary calculations are unaffected by
this argument.

\code{"CO"} and \code{"VC"} are accepted as aliases for \code{"HE"} and
are normalised to \code{"HE"} before being passed to
\code{metafor::rma()}. metafor's documentation notes that the Hedges
estimator is also known as the Cochran (\code{"CO"}) or variance-component
(\code{"VC"}) estimator, and that those strings may be used to select it
-- but that alias is not accepted by every metafor version (older releases
reject a bare \code{"CO"} with \dQuote{Unknown 'method' specified}).
Normalising here makes \code{tsa_hr()} behave identically across metafor
versions rather than inheriting that version skew, and avoids pinning a
minimum metafor version purely for an alias. All three strings denote the
same estimator, so this has no numerical consequence. The returned object
records both \code{parameters$method} (the normalised string actually
used, i.e. \code{"HE"}) and \code{parameters$method_requested} (what the
caller passed).

Two method strings accepted by \code{metafor::rma()} are deliberately
NOT supported here:
\code{"GENQ"} and \code{"GENQM"} require the caller to also supply a
\code{weights} argument to \code{metafor::rma()}, which \code{tsa_hr()}
does not currently collect or pass through, so passing them here raises
an explicit error explaining why rather than silently forwarding to
\code{metafor::rma()} and surfacing its own unrelated error.}

\item{order_by}{Optional name of a column in \code{data} to sort by
(ascending) before the cumulative analysis, e.g. a publication-year
column. TSA is order-dependent, so getting the chronological order right
matters. Default \code{NULL}, which uses the row order already present
in \code{data} and assumes it is chronological (with no way for the
package to verify this). Column names in \code{data} have spaces replaced
with underscores on load (so an Excel header \dQuote{Std Error} becomes
\code{Std_Error}); \code{order_by} is normalised the same way, so either
\code{"Publication Year"} or \code{"Publication_Year"} will match that
column. If two distinct headers would collide once spaces become
underscores, \code{tsa_hr()} stops rather than silently using whichever
column came first.}

\item{verbose}{Logical; print analysis details to the console as the
function runs. Default \code{TRUE}.}

\item{boundary_route}{Character string, one of \code{"design"} (default)
or \code{"analysis"}, selecting which of RTSA's two retrospective
boundary-computation routes to use. \code{"design"} computes alpha and
beta boundaries directly on the observed information-fraction timeline
with no inflation (DARIS reached at \code{info_fraction = 1}).
\code{"analysis"} first solves an inflation factor \code{design_R} (RTSA's
own \code{RTSA(type = "analysis", design = NULL)} route) and moves the
formal endpoint to \code{design_R * DARIS} instead -- this changes the
"DARIS reached" verdict, the plotted endpoint, and every field in
\code{results}, not just the futility numbers. See Details, "Retrospective
boundary timeline".}

\item{legacy_fallback}{Logical, default \code{TRUE}. If the compiled
RTSA-derived boundary engine fails, \code{TRUE} falls back to the legacy,
pre-0.2.7.11 R-only approximate engine with an immediate warning (not
RTSA-comparable); \code{FALSE} instead stops \code{tsa_hr()} with an error
(strict fail-closed behaviour, appropriate when the result will be
reported as RTSA-equivalent).}

\item{projection_stat}{Character string, one of \code{"median"}
(default) or \code{"mean"}, selecting the summary statistic used to turn
the OBSERVED per-study contributions into "typical" values for the
retrospective projection described under "Estimated additional
studies/events" in Details: the information per study
(\code{1/Std_Error^2}, giving the additional-studies estimate) and the
information per event (\code{1/Std_Error^2} divided by the study's
\code{total events}, giving the additional-events estimate).
\code{"median"} is the default because it is more robust to a single
unusually large or small study; \code{"mean"} is offered as an
alternative when that robustness is not wanted (e.g. a deliberately
evenly-sized set of studies). This has no effect on any other quantity
returned by \code{tsa_hr()} -- it only feeds the \code{projection}
element of the return value and the corresponding printed/plotted text.}

\item{info_per_event_basis}{Character string, one of \code{"per_study"} (default) or
\code{"pooled"}, selecting how the "historical rate" of information per
event used for the additional-EVENTS projection is obtained.
\code{"per_study"}: the \code{projection_stat} (median by default, or
mean) of each study's own information per event (\code{1/Std_Error^2}
divided by its \code{total events}). \code{"pooled"}: the ratio of sums
(total information / total events), which weights larger studies more and
equals the slope of observed cumulative information against cumulative
events. Studies with zero events (or another non-finite or non-positive
ratio) are technically accepted but are excluded from either variant, and
the number excluded is stated explicitly in the printed output. It does not
affect the additional-STUDIES estimate, which always uses
\code{projection_stat}. Both variants are always returned in
\code{projection} as a sensitivity check.}

}
\value{
An object of class \code{"tsa_hr"}: a list containing the fitted
random-effects and fixed-effect \code{metafor::rma} model objects,
heterogeneity statistics (including \code{D2}, capped at 99.9% for
numerical stability in extreme-heterogeneity cases, alongside the
uncapped \code{D2_raw} and a \code{D2_was_capped} logical flag so
capping is auditable rather than silent), allocation and
required-information-size
details (\code{information_size}, which includes two distinct circularity
flags: \code{circularity_warning} is \code{TRUE} whenever \code{target_HR}
was left unspecified, since deriving the required information size from
the observed pooled effect is circular regardless of how much information
accrued; \code{circularity_severe} additionally requires accrued events to
exceed three times the resulting DARIS, the runaway case in which the
boundary collapses to the conventional one almost immediately),
the cumulative analysis data frame (\code{cumulative}), the
formal sequential boundary schedule including the synthetic \code{t=1}
final-analysis point (\code{boundary_timeline}; see "Retrospective
boundary timeline" below), boundary-crossing results (\code{results},
including \code{crossed_conventional} -- deliberately evaluated over
the FULL cumulative Z-curve, including studies added after DARIS,
unlike \code{crossed_tsa}, which is restricted to the formal decision
horizon -- and \code{entered_futility_region}, see the caveat under
"Retrospective boundary timeline" below; a \code{TRUE} value at the
DARIS-reaching look reflects a comparison against the definitive
\code{t=1} futility boundary, not an interim one, and is not itself a
formal stopping recommendation; the definitive-look fields
\code{final_crossed_efficacy}, \code{final_non_efficacy} and
\code{final_entered_futility_region}, plus \code{daris_reached} and
\code{final_reached} -- see "Decision fields" under Details), a
\code{settings} list recording \code{boundary_route}, \code{route_used},
\code{legacy_fallback}, \code{fallback_used}, \code{fallback_route},
\code{fallback_reason}, the resolved \code{route_endpoint} (\code{1} for
\code{"design"}, \code{design_R} for \code{"analysis"}),
\code{route_endpoint_info} and \code{used_legacy_engine}, a
\code{projection} list (see "Estimated additional studies/events" under
Details) with \code{method} (the \code{projection_stat} used),
\code{info_per_event_basis}, \code{I_required}, \code{info_accrued},
\code{events_accrued}, \code{additional_info_required},
\code{central_info_increment}, \code{central_event_increment},
\code{central_info_per_event} (the historical rate used),
\code{study_level_info_per_event}, \code{pooled_info_per_event},
\code{n_additional_studies}, \code{additional_events_estimated}
(continuous, information / info per event, on the chosen basis),
\code{additional_events_study_level}, \code{additional_events_pooled},
\code{events_from_whole_studies}, \code{target_events_historical_rate}
(accrued plus estimated additional events), \code{n_studies},
\code{n_zero_event_studies}, \code{n_excluded_events_projection} and,
\code{additional_events_required_design} (design-route only, equal to
\code{additional_events_theoretical} there) and
\code{additional_events_theoretical} -- the projected quantities are
\code{NA} once the route's endpoint has been reached, and a summary data
frame (character \code{Parameter} and \code{Value} columns; \code{Value} is
character so logical rows print as TRUE/FALSE/NA rather than 1/0/NA). Use \code{plot()}, \code{summary()}, or \code{print()} on the
result.
}
\description{
Performs a Trial Sequential Analysis (TSA) for a meta-analysis of
time-to-event outcomes reported as hazard ratios (HR). Adapts the
classical Wetterslev/Thorlund/CTU TSA framework to time-to-event data
using the Schoenfeld required-events formula (generalised for unequal
allocation), the Diversity (D-squared) heterogeneity adjustment of
Wetterslev et al. (2009), and O'Brien-Fleming-type alpha- and
beta-spending monitoring boundaries computed at the observed accrued
statistical information.
}
\details{
\strong{Circularity caution:} using the observed pooled effect
(\code{target_HR = NA}) to determine the required information size is
circular -- it tends to make the required information size small
whenever the pooled effect is large and precise, which can make the TSA
boundary collapse to the conventional boundary almost immediately. For a
publication-quality TSA, set \code{target_HR} to a value fixed
independently of (and ideally before looking at) the meta-analysis
result.

\strong{Random-effects caveat:} the cumulative Z-curve is estimated from
a random-effects model whose between-study variance is re-estimated at
every step. The canonical Lan-DeMets/O'Brien-Fleming theory assumes a
fixed, canonical information process with independent Brownian-motion
increments. Because tsahr obtains each cumulative Z statistic from a
random-effects meta-analysis with tau-squared re-estimated at each look,
the resulting Z process does not exactly satisfy that canonical model;
the displayed monitoring boundaries should therefore be regarded as an
approximation (as in the official Copenhagen Trial Unit TSA software),
not an exact result.

\strong{Boundary engine:} since 0.2.7.11 the alpha (efficacy) and
non-binding beta (futility) boundaries are computed by compiled C++ code
ported from RTSA's own recursive-integration engine and driven through
RTSA's \code{boundaries(side = 2, futility = "non-binding", type =
"design")} steps: alpha bounds on the (\code{t < 1}, \code{1}) timeline,
then the two-pass information-scale root search whose target is the
alpha recursion's own final efficacy bound at \code{t = 1} (not
\code{qnorm(1 - alpha/2)}). Early looks whose futility spend is suppressed
by that search are returned as \code{NA}. A C++ compiler is therefore
required to install the package from source.

\strong{Retrospective boundary timeline:} the observed cumulative
Z-curve continues through every included study, but the formal alpha
and beta boundaries follow a design pass applied to the observed
information fractions (in the manner of RTSA): observed
looks are retained only while \code{info_fraction < 1}, followed by one
synthetic final-analysis point at \code{t = 1} (HARIS/DARIS). Boundaries
are not continued through studies occurring after DARIS. The synthetic
point is stored in \code{boundary_timeline}; the observed-study rows in
\code{cumulative} have boundary values set to \code{NA} at and after
DARIS. Formal crossing/futility decisions are evaluated only through the
first observed look reaching the route endpoint (DARIS for
\code{boundary_route = "design"}; \code{design_R * DARIS} for
\code{"analysis"}), using the definitive boundary at that endpoint.

\strong{Decision fields: "at any formal look" versus "at the definitive
look" (0.2.7.14).} \code{results} reports two families of fields that
answer different questions:
\describe{
  \item{At ANY formal look}{\code{crossed_tsa} and
    \code{entered_futility_region} are \code{TRUE} if the cumulative
    Z-curve crossed the efficacy boundary (respectively lay inside the
    futility region) at any look up to and including the definitive one.
    A trial that crossed efficacy at an interim look keeps
    \code{crossed_tsa = TRUE} even if the definitive look then fell back
    below the boundary.}
  \item{At the DEFINITIVE look}{\code{final_crossed_efficacy},
    \code{final_non_efficacy} (= \code{!final_crossed_efficacy}) and
    \code{final_entered_futility_region} refer ONLY to the first look
    reaching the route endpoint (\code{results$final_tsa_look}) and are
    \code{NA} when that endpoint has not been reached. Version 0.2.7.13
    defined \code{final_non_efficacy} as \code{!crossed_tsa}, which means
    "never crossed at any look" rather than "the definitive look did not
    cross"; this was corrected in 0.2.7.14.}
}
At the definitive look the futility boundary equals the final efficacy
boundary (as in RTSA's design pass, where the two are calibrated to meet
there; e.g. about 2.1-2.2 rather than 1.959964 for a two-sided alpha of
0.05 with many looks), so \code{final_entered_futility_region} is the
complement of \code{final_crossed_efficacy} (both are \code{TRUE} only at
|Z| exactly equal to the boundary). It merely says that the Z-curve did
not reach the final efficacy boundary; it is not a formal interim
futility stop, and neither family of fields is a recommendation to stop a
trial. (Versions 0.2.6.x-0.2.7.11 used \code{min(qnorm(1 - alpha/2),
<final efficacy boundary>)} as the final futility boundary.)

\strong{Route endpoint versus DARIS (0.2.7.13/0.2.7.14).}
\code{boundary_route} picks between direct ports of RTSA's two
retrospective boundary computations:
\describe{
  \item{\code{"design"} (default)}{\code{RTSA::boundaries(type =
    "design")}: alpha and beta boundaries are computed directly on the
    observed information-fraction timeline (looks below \code{t = 1} plus
    one synthetic \code{t = 1} point), with NO further inflation. The
    formal endpoint is DARIS itself (\code{info_fraction = 1}), matching
    this package's stated RIS/DARIS definition and the values validated
    against RTSA's design pass.}
  \item{\code{"analysis"}}{\code{RTSA::RTSA(type = "analysis", design =
    NULL)}: a design pass first solves an inflation factor
    (\code{design_R}) so that the design's own futility and efficacy
    boundaries meet at its final look; the boundaries returned are then
    recomputed on the timeline scaled by \code{design_R}, and the efficacy
    boundaries change as well as the futility ones (alpha is respent on
    \code{t / design_R}). The formal endpoint becomes \code{design_R *
    DARIS}, not DARIS. This is RTSA's own inflated-sequential-design
    convention, not the no-inflation convention of the Copenhagen Trial
    Unit's TSA software.}
}
DARIS and the route endpoint are reported separately and never conflated:
\code{results$daris_reached} and
\code{information_size$DARIS_info_threshold_events} always refer to DARIS
itself, whereas \code{results$final_reached},
\code{information_size$route_endpoint_info} and
\code{information_size$route_endpoint_events} refer to the route endpoint
(identical to DARIS for \code{"design"}). For \code{"analysis"} the
printed output, summary table and plot call the endpoint "analysis-route
endpoint (x.xxx x DARIS)" and never "DARIS". Both routes share the same
compiled recursion (\code{src/rtsa_core.h}); only the orchestration
differs.

\strong{Fallbacks (0.2.7.14).} \code{settings$route_used}
(\code{"design"}, \code{"analysis"} or \code{"legacy"}),
\code{settings$fallback_used}, \code{settings$fallback_route}
(\code{"none"}, \code{"design"} or \code{"legacy"}) and
\code{settings$fallback_reason} record programmatically what actually
produced the boundaries. \code{"design"}: \code{boundary_route =
"analysis"} failed and the RTSA-derived design-route result is returned;
\code{"legacy"}: the RTSA-derived engine failed and the legacy,
approximate R-only engine was used. Both are announced by warnings and,
for \code{"legacy"}, a banner in \code{print()}/\code{summary()}. For
confirmatory or RTSA-parity work use \code{legacy_fallback = FALSE}, which
makes either failure an error.

\strong{Numerical diagnostics.} The compiled engine warns when a boundary
search converged only within a loose tolerance, when an integration grid
collapsed to a degenerate interval, and -- with a separate, more alarming
warning -- when an integration interval was REVERSED (lower wall above the
upper wall), a state RTSA's own code would have stopped on and which
invalidates the boundaries from that look onward. Diagnostics are
reported for the converged passes, not for the transient candidate
information scales tried inside the root searches.

\strong{Placeholder boundaries: RTSA's tolerance, kept (0.2.7.22).} At looks
where the cumulative alpha spend is below RTSA's absolute search tolerance of
1e-9 (very early looks, small information fractions) RTSA does not solve for a
boundary but reports the placeholder value 20, and tsahr reproduces this
deliberately (\code{TSA_boundary_upper == 20}). It is not a computed boundary:
the true boundary there is finite (about 6.7 and 6.2 at information fractions
0.108 and 0.125 in a 37-look example), and a Z-curve above the placeholder is
not counted as crossing. The same tolerance also makes the first boundary that
IS solved after such looks slightly inaccurate (an error of about 7e-3 in that
example, shrinking at later looks). Both effects are RTSA's own; tsahr keeps
RTSA's tolerance so that its bounds match RTSA's, and the placeholder stretches
the vertical axis of \code{plot()}.

\strong{Final-look-only beta spend (0.2.7.22).} When every interim look is
suppressed (small information fractions) the final look carries the whole beta
spend. RTSA has an exact-float shortcut for that case that fires or not
depending on the last bit of \code{beta}; tsahr computes \code{beta = 1 - power}
and used to hit it at power 0.80, losing the compiled engine to the legacy
fallback. The shortcut is no longer ported, so the result no longer depends on
the last bit of \code{beta}.

\strong{Estimated additional studies/events (retrospective projection,
0.2.8.4; events/studies split 0.2.8.5).} Whenever the route's target has NOT been reached in the
observed data (\code{results$daris_reached == FALSE} for
\code{boundary_route = "design"}; \code{results$final_reached == FALSE}
for \code{"analysis"}), \code{tsa_hr()} additionally projects how many
more studies, and roughly how many more events, would be needed to reach
it -- based directly on the OBSERVED study-level information increments
already in the data, not on any new assumption about future trial size.
This is deliberately a retrospective, data-driven HR-specific counterpart
to RTSA's own prospective \code{minTrial()}/\code{ris(..., type =
"retrospective")} machinery, not a re-implementation of it.

The target information \code{I_required} differs by route -- computed
separately, never conflated:
\describe{
  \item{\code{"design"}}{\code{I_required = DARIS} (the information
    target is DARIS itself, i.e. \code{information_size$DARIS_info}).}
  \item{\code{"analysis"}}{\code{I_required = design_R x DARIS} (the
    analysis-route endpoint, i.e.
    \code{information_size$route_endpoint_info}).}
}
The shortfall \code{I_required - info_accrued_final} is translated in two
separate ways, which answer different questions:
\describe{
  \item{Additional events (primary)}{The shortfall divided by a "historical
    rate" of information per event, chosen with
    \code{info_per_event_basis}: \code{"per_study"} (default) uses the
    \code{projection_stat} (median by default, or mean) of each included
    study's own \code{(1/Std_Error^2) / total_events}; \code{"pooled"} uses
    the ratio of sums, total information / total events, which weights the
    larger studies more and equals the slope of observed cumulative
    information against cumulative events. The result is continuous and is
    rounded up only for display. It is returned in
    \code{projection$additional_events_estimated}; both variants are always
    returned (\code{additional_events_study_level} and
    \code{additional_events_pooled}) so the choice can be checked as a
    sensitivity analysis.}
  \item{Additional studies (secondary)}{The shortfall divided by a single
    "typical future study" information increment -- the
    \code{projection_stat} of each study's own \code{1/Std_Error^2} -- and
    rounded up to the nearest whole study, so it is always a natural
    number. It is not affected by \code{info_per_event_basis}.}
}
The two are deliberately not chained: the events figure is NOT the number
of studies times an events-per-study increment, because rounding the
studies up would inflate it. That chained quantity (whole typical studies x
typical events per study) is still returned, as
\code{projection$events_from_whole_studies}, but it answers "how many
events would the minimum whole number of typical studies bring?", not "how
many events are needed?".

For both routes three separate quantities are reported when the route's
own target has not been reached (printed output, \code{summary()} and the
plot caption); for \code{boundary_route = "design"} the target is DARIS, for
\code{"analysis"} it is the analysis-route endpoint (design_R x DARIS):
\describe{
  \item{Theoretical additional events (Schoenfeld)}{The direct,
    deterministic difference between the theoretical event-equivalent of the
    target (\code{DARIS_events} for design, \code{DARIS_events x design_R} for
    analysis) and \code{events_accrued} (both already pooled-psi
    event-equivalents), floored at 0
    (\code{projection$additional_events_theoretical}; for the design route
    this equals \code{projection$additional_events_required_design}).}
  \item{Estimated additional events (historical rate)}{The events
    projection above, with \code{I_required} set to the route's target
    information (\code{projection$additional_events_estimated}).
    \code{plot()} draws it as a second reference line, at accrued events plus
    these additional events
    (\code{projection$target_events_historical_rate}), next to the
    theoretical line; see \code{show_historical_daris} in
    \code{\link{plot.tsa_hr}}. The printed output and \code{summary()}
    also give that position in cumulative events, just before the
    additional-events figure ("DARIS (historical rate)" for the design
    route; "Historical information/event-rate projection" for the
    analysis route).}
  \item{Estimated additional studies required}{The studies projection
    above.}
}
These two events figures rest on different assumptions and can disagree --
for example, when the studies supply less information per event than the
psi*(1-psi) assumption behind the Schoenfeld figure, the historical-rate
figure is larger, and it can be positive when the Schoenfeld figure is
already 0. Both are approximations.

\strong{Zero-event studies.} Studies with zero events (or another
non-finite or non-positive information-per-event ratio) are technically
accepted by \code{tsa_hr()} but carry information with no events to attach
it to, so they are excluded from the information-per-event summaries (both
variants) and hence from the events projection. They remain in the
additional-studies projection and in every other result. The number
excluded is stated explicitly in the printed output, in \code{summary()},
and in the plot caption, and is returned as
\code{projection$n_zero_event_studies} and
\code{projection$n_excluded_events_projection}.

\strong{Caveat: fixed-effect information scale.} All projections are
linear extrapolations on the fixed-effect, study-level inverse-variance
information scale (\code{1/Std_Error^2}) that \code{tsa_hr()} compares
with DARIS. They deliberately do not model how random-effects weights or
the between-study variance (tau^2) would change as further studies are
added, nor any change in the size, allocation or baseline risk of future
studies; the mathematics are not adjusted for random effects. Read every
projected number of events or studies as indicative, not as a required
quantity.

This projection is deliberately NOT called "number of studies required"
anywhere in \code{tsa_hr()}'s output: that phrasing reads as
deterministic, and it is not one. Figures are labelled "Estimated ...", and
the printed output always carries a note that the projection assumes future
studies contribute information at approximately the observed historical
rate and is not a formal guarantee. The full detail is returned in
\code{projection} (see "Value"); when the endpoint HAS already been
reached, the projected fields (\code{n_additional_studies},
\code{additional_events_estimated} and their variants) are \code{NA} (there
is nothing left to project), and nothing is printed or plotted for it.
}
\examples{
\donttest{
path <- tsahr_example_data()
res <- tsa_hr(path, target_HR = 0.80)
summary(res)
plot(res)
}
}
\references{
Miladinovic B, Mhaskar R, Hozo I, Kumar A, Mahony H, Djulbegovic B.
"Optimal information size in trial sequential analysis of time-to-event
outcomes reveals potentially inconclusive results because of the risk of
random error." J Clin Epidemiol. 2013;66(6):654-9.

Wetterslev J, Thorlund K, Brok J, Gluud C. "Estimating required
information size by quantifying diversity in random-effects model
meta-analyses." BMC Med Res Methodol. 2009;9:86.
}
