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
details, the cumulative analysis data frame (\code{cumulative}), the
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
formal stopping recommendation), and a summary data frame. Use
\code{plot()}, \code{summary()}, or \code{print()} on the result.
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
every step. The Lan-DeMets/O'Brien-Fleming monitoring boundaries strictly
assume the canonical joint (independent Brownian-motion increments)
distribution, which holds exactly only for a fixed-effect cumulative
process. With random effects this is a widely-used approximation (as in
the official Copenhagen Trial Unit TSA software), not an exact result.

\strong{Retrospective boundary timeline:} the observed cumulative
Z-curve continues through every included study, but the formal alpha
and beta boundaries follow the RTSA retrospective convention: observed
looks are retained only while \code{info_fraction < 1}, followed by one
synthetic final-analysis point at \code{t = 1} (HARIS/DARIS). Boundaries
are not continued through studies occurring after DARIS. The synthetic
point is stored in \code{boundary_timeline}; the observed-study rows in
\code{cumulative} have boundary values set to \code{NA} at and after
DARIS. Formal crossing/futility decisions are evaluated only through the
first observed look reaching DARIS, using the definitive \code{t = 1}
boundary. In particular, \code{results$entered_futility_region} at that
look reflects a comparison against the FINAL futility boundary (which by
the RTSA convention equals the same value as the final efficacy
boundary), not an interim one -- a \code{TRUE} value there means the
definitive analysis did not reach conventional significance, not that a
formal interim futility stop was triggered.
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
