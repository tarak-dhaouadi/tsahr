\name{tsa_hr}
\alias{tsa_hr}
\title{Trial Sequential Analysis for a meta-analysis of Hazard Ratios}
\usage{
tsa_hr(data, alpha_two_sided = 0.05, power = 0.80,
  allocation_source = c("data", "manual"), allocation_p = 0.5,
  target_HR = NA_real_, method = "DL", order_by = NULL, verbose = TRUE)
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
cumulative (sequential) TSA model, passed straight through to
\code{method} in \code{metafor::rma()}. One of \code{"DL"}
(DerSimonian-Laird, the default -- kept as the default here for backward
compatibility with earlier tsahr versions, which always used DL; note
this differs from \code{metafor::rma()}'s own default of \code{"REML"}),
\code{"HE"} (or its alias \code{"CO"}), \code{"HS"}, \code{"HSk"},
\code{"SJ"}, \code{"ML"}, \code{"REML"}, \code{"EB"}, \code{"PM"},
\code{"GENQ"}, \code{"PMM"}, or \code{"GENQM"}. See \code{?metafor::rma}
for the definition of each estimator. This only changes the
\emph{random-effects} model (\code{res_re}); the equal-effects model used
internally for the Diversity (D^2) heterogeneity adjustment is always
fitted with \code{method = "FE"} and is unaffected by this argument.
Alpha-/beta-spending boundary calculations are unaffected by this
argument.}

\item{order_by}{Optional name of a column in \code{data} to sort by
(ascending) before the cumulative analysis, e.g. a publication-year
column. TSA is order-dependent, so getting the chronological order right
matters. Default \code{NULL}, which uses the row order already present
in \code{data} and assumes it is chronological (with no way for the
package to verify this).}

\item{verbose}{Logical; print analysis details to the console as the
function runs. Default \code{TRUE}.}
}
\value{
An object of class \code{"tsa_hr"}: a list containing the fitted
random-effects and fixed-effect \code{metafor::rma} model objects,
heterogeneity statistics, allocation and required-information-size
details, the cumulative analysis data frame, boundary-crossing results,
and a summary data frame. Use \code{plot()}, \code{summary()}, or
\code{print()} on the result.
}
\description{
Performs a Trial Sequential Analysis (TSA) for a meta-analysis of
time-to-event outcomes reported as hazard ratios (HR). Adapts the
classical Wetterslev/Thorlund/CTU TSA framework to time-to-event data
using the Schoenfeld required-events formula (generalised for unequal
allocation), the Diversity (D-squared) heterogeneity adjustment of
Wetterslev et al. (2009), and O'Brien-Fleming-type alpha- and
beta-spending monitoring boundaries computed at the exact accrued
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
every step. The Lan-DeMets/O'Brien-Fleming monitoring boundaries strictly
assume the canonical joint (independent Brownian-motion increments)
distribution, which holds exactly only for a fixed-effect cumulative
process. With random effects this is a widely-used approximation (as in
the official Copenhagen Trial Unit TSA software), not an exact result.

\strong{Looks after DARIS is reached:} once the observed accrued
information first reaches DARIS at some look k, \code{info_fraction} is
capped at 1 for every subsequent look, so they all map to the same
(final, \code{t=1}) boundary value. Testing every one of those looks
against that boundary would amount to several additional, uncounted
tests against what the alpha-spending calculation treats as a single
final analysis. The formal \code{crossed_tsa} and
\code{entered_futility_region} verdicts are therefore evaluated only
through the FIRST look at which DARIS was reached (recorded as
\code{results$final_tsa_look}; equal to the total number of looks if
DARIS was never reached). Any studies added after that look are still
included in full in the returned cumulative data frame and in
\code{plot()} -- only the formal sequential decision is restricted, not
what is shown.
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
