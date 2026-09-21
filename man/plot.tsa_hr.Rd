\name{plot.tsa_hr}
\alias{plot.tsa_hr}
\title{Plot a tsa_hr object}
\usage{
\method{plot}{tsa_hr}(x, legend = TRUE, caption = TRUE,
  caption_size = 8, caption_face = "italic",
  show_theoretical_daris = TRUE,
  daris_label_size = 3.2, daris_label_x = NULL, daris_label_y = NULL,
  info_threshold_label_size = 3.2, info_threshold_label_x = NULL,
  info_threshold_label_y = NULL,
  events_label_size = 3.2, events_label_x = NULL, events_label_y = NULL,
  endpoint_label_size = NULL, endpoint_label_x = NULL,
  endpoint_label_y = NULL,
  alpha_col = "firebrick", beta_col = "blue", naive_col = "darkgreen",
  z_col = "black", ...)
}
\arguments{
\item{x}{An object of class \code{"tsa_hr"}.}

\item{legend}{Logical; show the boundary-type legend at the bottom of the
plot. Default \code{TRUE}.}

\item{caption}{Logical; show the methods caption below the plot. Default
\code{TRUE}.}

\item{caption_size}{Font size for the methods caption text. Default
\code{8}.}

\item{caption_face}{Font face for the methods caption text: one of
\code{"italic"} (default, matching the previous fixed styling) or
\code{"plain"}. Also accepts any other value \code{ggplot2::element_text()}
understands for \code{face} (e.g. \code{"bold"}, \code{"bold.italic"}).}

\item{show_theoretical_daris}{Logical; show the theoretical DARIS
event-equivalent reference line and its label (see Details). Default
\code{TRUE}. Set to \code{FALSE} to hide it -- e.g. when it would clutter
the plot, or when only the observed-information "DARIS information
reached" marker is of interest. Has no effect on the underlying DARIS
calculation or on the "DARIS reached" verdict, only on what is drawn.}

\item{daris_label_size}{Font size for the theoretical "DARIS
event-equivalent" label. Default \code{3.2}.}

\item{daris_label_x, daris_label_y}{Position (in data coordinates: x =
cumulative events, y = Z-score) for the theoretical DARIS event-
equivalent label. Default \code{NULL} uses the built-in position (just
right of its vertical line, near the top of the plot).}

\item{info_threshold_label_size}{Font size for the "DARIS information
reached" label (only shown when DARIS has actually been reached).
Default \code{3.2}.}

\item{info_threshold_label_x, info_threshold_label_y}{Position (in data
coordinates) for the "DARIS information reached" label. Default
\code{NULL} uses the built-in position.}

\item{events_label_size}{Font size for the "Events accrued" label.
Default \code{3.2}.}

\item{events_label_x, events_label_y}{Position (in data coordinates) for
the "Events accrued" label. Default \code{NULL} uses the built-in
position (bottom right, above the last data point).}

\item{endpoint_label_size}{Font size for the "Analysis-route endpoint
(Design_R x DARIS) reached" label (only shown when
\code{boundary_route = "analysis"} and the analysis-route endpoint was
reached). Default \code{NULL} uses the same size as
\code{info_threshold_label_size} (\code{3.2} unless changed), which is
what this label followed before 0.2.8.}

\item{endpoint_label_x, endpoint_label_y}{Position (in data coordinates: x
= cumulative events, y = Z-score) for the "Analysis-route endpoint
(Design_R x DARIS) reached" label. Default \code{NULL} uses the built-in
position (just right of its vertical line, below the "DARIS information
reached" label).}

\item{alpha_col}{Color for the alpha (efficacy) boundary line. Default
\code{"firebrick"}.}

\item{beta_col}{Color for the beta (futility) boundary line. Default
\code{"blue"}.}

\item{naive_col}{Color for the naive/conventional significance boundary
line. Default \code{"darkgreen"}.}

\item{z_col}{Color for the cumulative Z-score line/points. Default
\code{"black"}.}

\item{...}{Currently unused.}
}
\value{
A \code{ggplot} object (invisibly), also drawn on the current graphics
device / returned for further customisation, e.g. \code{ggplot2::ggsave()}.
}
\description{
Produces the standard Trial Sequential Analysis chart: cumulative
Z-curve, O'Brien-Fleming-type alpha (efficacy) and beta (futility)
spending boundaries, the conventional (naive) significance boundary, the
theoretical Diversity-Adjusted Required Information Size (DARIS)
event-equivalent reference line, and -- whenever DARIS has actually been
reached -- a second reference line marking the estimated cumulative-
events point at which the observed accrued statistical information
reached DARIS. The two lines are shown and labelled separately, since
they are different quantities that need not coincide (see \code{?tsa_hr}).

The subtitle has two lines: the model and design summary (random-effects
model, Diversity D^2, anticipated HR, allocation psi, alpha and power), and,
from 0.2.8, the pooled random-effects HR with its 95\% CI, the p-value of
the pooled effect, tau^2 and I^2 (the same values \code{print()} and
\code{summary()} report).
}
\examples{
\donttest{
path <- tsahr_example_data()
res <- tsa_hr(path, target_HR = 0.80)
plot(res, daris_label_size = 5, events_label_size = 5,
     daris_label_y = 10, events_label_x = res$results$events_accrued)
plot(res, alpha_col = "purple", beta_col = "orange")
plot(res, show_theoretical_daris = FALSE)
plot(res, caption_size = 10, caption_face = "plain")

## boundary_route = "analysis": move / resize the "Analysis-route endpoint
## (Design_R x DARIS) reached" label
res_a <- tsa_hr(path, target_HR = 0.80, boundary_route = "analysis")
plot(res_a, endpoint_label_size = 4,
     endpoint_label_x = res_a$results$events_accrued / 2,
     endpoint_label_y = 5)
}
}
