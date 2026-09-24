#' Print a tsa_hr object
#'
#' @param x An object of class \code{"tsa_hr"}.
#' @param ... Currently unused.
#' @export
print.tsa_hr <- function(x, ...) {
  cat("Trial Sequential Analysis (Hazard Ratios)\n")
  cat("------------------------------------------\n")
  cat(sprintf("Studies: %d | Events accrued: %.0f\n",
              nrow(x$data), x$results$events_accrued))
  cat(sprintf("Pooled HR (random effects): %.3f\n", exp(x$res_re$b)))
  cat(sprintf("Anticipated HR (RIS calc): %.3f\n", x$parameters$HR_anticipated))
  cat(sprintf("Theoretical DARIS event-equivalent: %.0f\n", ceiling(x$information_size$DARIS_events)))
  analysis_route <- identical(x$settings$route_used, "analysis")
  daris_reached  <- if (is.null(x$results$daris_reached)) x$results$final_reached else x$results$daris_reached
  cat(sprintf("Crossed TSA boundary: %s | Entered futility region: %s | DARIS information reached: %s\n",
              ifelse(x$results$crossed_tsa, "YES", "NO"),
              ifelse(x$results$entered_futility_region, "YES", "NO"),
              ifelse(daris_reached, "YES", "NO")))
  if (analysis_route) {
    cat(sprintf("Boundary route: RTSA analysis | Analysis-route endpoint (%.3f x DARIS) reached: %s\n",
                x$settings$route_endpoint,
                ifelse(x$results$final_reached, "YES", "NO")))
  }
  if (isTRUE(x$results$final_reached)) {
    cat(sprintf("Definitive look crossed the efficacy boundary: %s\n",
                ifelse(isTRUE(x$results$final_crossed_efficacy), "YES", "NO")))
  }
  if (identical(x$settings$fallback_route, "design")) {
    cat("\n*** NOTE: boundary_route = \"analysis\" FAILED; the results shown are the\n")
    cat("    DESIGN-route (RTSA-derived) result -- see settings$fallback_reason. ***\n")
  }
  if (identical(x$beta_engine$engine, "legacy_r_fallback")) {
    cat("\n*** WARNING: boundaries computed with the LEGACY, APPROXIMATE fallback\n")
    cat("    engine (the RTSA-derived engine failed) -- NOT comparable with RTSA. ***\n")
  }
  cat("\nUse summary() for the full results table, or plot() for the TSA chart.\n")
  invisible(x)
}

#' Summarise a tsa_hr object
#'
#' @param object An object of class \code{"tsa_hr"}.
#' @param ... Currently unused.
#' @return The underlying summary data.frame (invisibly printed).
#' @export
summary.tsa_hr <- function(object, ...) {
  print(object$summary_table, row.names = FALSE)
  if (identical(object$settings$fallback_route, "design")) {
    cat("\n*** NOTE: boundary_route = \"analysis\" FAILED; the results shown are the\n")
    cat("    DESIGN-route (RTSA-derived) result -- see settings$fallback_reason. ***\n")
  }
  if (identical(object$beta_engine$engine, "legacy_r_fallback")) {
    cat("\n*** WARNING: boundaries computed with the LEGACY, APPROXIMATE fallback\n")
    cat("    engine (the RTSA-derived engine failed) -- NOT comparable with RTSA. ***\n")
  }
  if (isTRUE(object$information_size$circularity_warning)) {
    cat("\nNOTE: target_HR was not specified, so the observed pooled HR was used\n")
    cat("for the required information size. This is circular -- see ?tsa_hr.\n")
    if (isTRUE(object$information_size$circularity_severe)) {
      cat("Accrued events also greatly exceed the resulting DARIS, so the TSA\n")
      cat("boundary will collapse to the conventional boundary almost immediately.\n")
    }
  }
  invisible(object$summary_table)
}

## Internal helper (0.2.8): the second subtitle line of the TSA plot --
## pooled random-effects HR with its 95% CI, the p-value of the pooled
## effect, tau^2 and I^2. Everything comes from the fitted random-effects
## model (x$res_re, the metafor::rma() object) and x$heterogeneity, i.e.
## the same numbers print()/summary() report; nothing is recomputed here.
## "2" is written as the Unicode superscript two (\u00b2), as already done
## for the Diversity D-squared in the first subtitle line. Missing pieces
## (e.g. an object saved by an older version) print as "NA" instead of
## erroring. Not exported.
.tsahr_pooled_subtitle <- function(x) {
  num <- function(v) if (is.null(v) || length(v) != 1L) NA_real_ else as.numeric(v)
  re   <- x$res_re
  b    <- num(re$b)
  lo   <- num(re$ci.lb)
  hi   <- num(re$ci.ub)
  pv   <- num(re$pval)
  tau2 <- num(x$heterogeneity$tau2)
  I2   <- num(x$heterogeneity$I2)
  p_txt <- if (is.na(pv)) "p = NA" else if (pv < 0.001) "p < 0.001" else sprintf("p = %.3f", pv)
  sprintf("Pooled HR = %.2f [95%% CI: %.2f, %.2f] | %s | Tau\u00b2 = %.4f | I\u00b2 = %.1f%%",
          exp(b), exp(lo), exp(hi), p_txt, tau2, I2)
}

#' Plot a tsa_hr object
#'
#' Produces the standard Trial Sequential Analysis chart: cumulative
#' Z-curve, O'Brien-Fleming-type alpha (efficacy) and beta (futility)
#' spending boundaries, the conventional (naive) significance boundary,
#' the theoretical Diversity-Adjusted Required Information Size (DARIS)
#' event-equivalent reference line, and -- whenever DARIS has actually
#' been reached (see \code{?tsa_hr}, "DARIS reached" criterion) -- a
#' second reference line marking the estimated cumulative-events point at
#' which the observed accrued statistical information reached DARIS. The
#' two lines are shown and labelled separately, since they are different
#' quantities that need not coincide (see \code{?tsa_hr}, Section 7b).
#'
#' The subtitle has two lines: the model and design summary (random-effects
#' model, Diversity D^2, anticipated HR, allocation psi, alpha and power),
#' and, from 0.2.8, the pooled random-effects HR with its 95\% CI, the
#' p-value of the pooled effect, tau^2 and I^2 (the same values
#' \code{print()} and \code{summary()} report).
#'
#' @param x An object of class \code{"tsa_hr"}.
#' @param legend Logical; show the boundary-type legend at the bottom of
#'   the plot. Default \code{TRUE}.
#' @param caption Logical; show the methods caption below the plot.
#'   Default \code{TRUE}.
#' @param caption_size Font size for the methods caption text. Default
#'   \code{8}.
#' @param caption_face Font face for the methods caption text: one of
#'   \code{"italic"} (default, matching the previous fixed styling) or
#'   \code{"plain"}. Also accepts any other value \code{ggplot2::element_text()}
#'   understands for \code{face} (e.g. \code{"bold"}, \code{"bold.italic"}).
#' @param show_theoretical_daris Logical; show the theoretical DARIS
#'   event-equivalent reference line and its label (see Details). Default
#'   \code{TRUE}. Set to \code{FALSE} to hide it -- e.g. when it would
#'   clutter the plot, or when only the observed-information "DARIS
#'   information reached" marker is of interest. Has no effect on the
#'   underlying DARIS calculation or on the "DARIS reached" verdict,
#'   only on what is drawn.
#' @param daris_label_size Font size for the theoretical "DARIS
#'   event-equivalent" label. Default \code{3.2}.
#' @param daris_label_x,daris_label_y Position (in data coordinates: x =
#'   cumulative events, y = Z-score) for the theoretical DARIS
#'   event-equivalent label. Default \code{NULL} uses the built-in
#'   position (just right of its vertical line, near the top of the plot).
#' @param info_threshold_label_size Font size for the "DARIS information
#'   reached" label (only shown when DARIS has actually been reached).
#'   Default \code{3.2}.
#' @param info_threshold_label_x,info_threshold_label_y Position (in data
#'   coordinates) for the "DARIS information reached" label. Default
#'   \code{NULL} uses the built-in position.
#' @param events_label_size Font size for the "Events accrued" label.
#'   Default \code{3.2}.
#' @param events_label_x,events_label_y Position (in data coordinates) for
#'   the "Events accrued" label. Default \code{NULL} uses the built-in
#'   position (bottom right, above the last data point).
#' @param endpoint_label_size Font size for the "Analysis-route endpoint
#'   (Design_R x DARIS) reached" label (only shown when
#'   \code{boundary_route = "analysis"}; from 0.2.8.3 it is also drawn, worded
#'   "not yet reached; theoretical ~ N events", at the theoretical position
#'   when the endpoint has not been reached). Default \code{NULL} uses the same size as
#'   \code{info_threshold_label_size} (\code{3.2} unless changed), which is
#'   what this label followed before 0.2.8.
#' @param endpoint_label_x,endpoint_label_y Position (in data coordinates: x
#'   = cumulative events, y = Z-score) for the "Analysis-route endpoint
#'   (Design_R x DARIS) reached" label. Default \code{NULL} uses the
#'   built-in position (just right of its vertical line, below the "DARIS
#'   information reached" label).
#' @param xmax_mult Positive number; multiplier applied to the largest x
#'   value that must fit in the plot (accrued events, theoretical DARIS,
#'   DARIS information marker, analysis-route endpoint, and the last x of the
#'   formal boundaries) to obtain the upper limit of the x-axis. Default
#'   \code{1.15}, i.e. 15\% of free space to the right. Use a larger value
#'   (e.g. \code{1.4}) to leave more room for labels, or \code{1} to end the
#'   axis exactly at the largest element. Values below \code{1} crop the
#'   right-hand part of the plot.
#' @param alpha_col Color for the alpha (efficacy) boundary line. Default
#'   \code{"firebrick"}.
#' @param beta_col Color for the beta (futility) boundary line. Default
#'   \code{"blue"}.
#' @param naive_col Color for the naive/conventional significance boundary
#'   line. Default \code{"darkgreen"}.
#' @param z_col Color for the cumulative Z-score line/points. Default
#'   \code{"black"}.
#' @param ... Currently unused.
#' @return A \code{ggplot} object (invisibly), also drawn on the current
#'   graphics device / returned for further customisation, e.g.
#'   \code{ggplot2::ggsave()}.
#' @export
plot.tsa_hr <- function(x, legend = TRUE, caption = TRUE,
                         caption_size = 8, caption_face = "italic",
                         show_theoretical_daris = TRUE,
                         daris_label_size = 3.2,
                         daris_label_x = NULL, daris_label_y = NULL,
                         info_threshold_label_size = 3.2,
                         info_threshold_label_x = NULL, info_threshold_label_y = NULL,
                         events_label_size = 3.2,
                         events_label_x = NULL, events_label_y = NULL,
                         endpoint_label_size = NULL,
                         endpoint_label_x = NULL, endpoint_label_y = NULL,
                         xmax_mult = 1.15,
                         alpha_col = "firebrick", beta_col = "blue",
                         naive_col = "darkgreen", z_col = "black",
                         ...) {

  cumul_df <- x$cumulative

  if (!is.numeric(xmax_mult) || length(xmax_mult) != 1L ||
      !is.finite(xmax_mult) || xmax_mult <= 0) {
    stop("`xmax_mult` must be a single positive number (default 1.15).",
         call. = FALSE)
  }
  DARIS_events <- x$information_size$DARIS_events
  DARIS_info_threshold_events <- x$information_size$DARIS_info_threshold_events
  final_reached <- x$results$final_reached
  ## 0.2.7.14: DARIS (t = 1) and the route endpoint are separate quantities.
  ## For boundary_route = "design" they coincide (route endpoint == DARIS)
  ## and the plot is unchanged; for "analysis" the formal endpoint is
  ## design_R * DARIS and gets its own, separately labelled marker.
  daris_reached <- if (is.null(x$results$daris_reached)) final_reached else x$results$daris_reached
  analysis_route <- identical(x$settings$route_used, "analysis")
  route_endpoint <- if (is.null(x$settings$route_endpoint)) 1 else x$settings$route_endpoint
  route_endpoint_events <- x$information_size$route_endpoint_events
  show_endpoint_marker <- analysis_route && isTRUE(final_reached) &&
    !is.null(route_endpoint_events) && !is.na(route_endpoint_events)
  ## 0.2.8.3: the formal boundaries always terminate at the route endpoint
  ## (observed-information estimate if reached, otherwise the theoretical
  ## event-equivalent DARIS_events * route_endpoint). When design_R > 1 the
  ## endpoint typically lies beyond the observed information, so it is NOT
  ## reached; before 0.2.8.3 nothing marked where the boundaries ended in
  ## that case (vertical line and caption were only drawn once reached).
  ## The theoretical position is now drawn and labelled "not yet reached".
  endpoint_theoretical_events <- DARIS_events * route_endpoint
  show_endpoint_theoretical <- analysis_route && !show_endpoint_marker &&
    is.finite(endpoint_theoretical_events) &&
    !(isTRUE(all.equal(route_endpoint, 1)) && isTRUE(show_theoretical_daris))

  ## Two distinct quantities are shown on the plot, deliberately NOT
  ## conflated into a single "DARIS events" figure:
  ##
  ##  1. DARIS_events: the THEORETICAL event-equivalent of the required
  ##     information (Schoenfeld-based, assuming each event carries
  ##     psi*(1-psi) units of information). Always drawn.
  ##  2. DARIS_info_threshold_events: an ESTIMATE (interpolated between
  ##     looks) of the cumulative-events point at which the OBSERVED
  ##     accrued inverse-variance information actually reached DARIS_info
  ##     -- only meaningful, and only drawn, when DARIS has been reached
  ##     (see tsa_hr(), Section 7b). This is why the printed "DARIS
  ##     reached" verdict can never contradict what is plotted: whenever
  ##     it says YES, this second marker is shown at (or before) the
  ##     accrued-events point; whenever it says NO, only the theoretical
  ##     line (1) is shown, clearly labelled as not yet reached.
  show_info_threshold_marker <- daris_reached && !is.na(DARIS_info_threshold_events)

  z_alpha <- x$information_size$z_alpha
  D2 <- x$heterogeneity$D2
  AF <- x$heterogeneity$AF
  allocation_p_used <- x$parameters$allocation_p_used
  alpha_two_sided <- x$parameters$alpha_two_sided
  power <- x$parameters$power
  HR_anticipated <- x$parameters$HR_anticipated

  ## Boundary plotting uses the dedicated RTSA-style timeline.  The
  ## observed cumulative table continues through all studies, whereas the
  ## formal boundaries terminate at the t = 1 information target.  If DARIS
  ## was reached in the observed data, that endpoint is plotted at the
  ## interpolated observed-information event coordinate (DARIS_info_threshold_events);
  ## the theoretical Schoenfeld DARIS_events line remains separate.
  boundary_line <- x$boundary_timeline[, c("cum_events", "TSA_boundary_upper",
                                           "TSA_boundary_lower",
                                           "TSA_futility_upper",
                                           "TSA_futility_lower")]

  finite_bounds <- c(boundary_line$TSA_boundary_upper[is.finite(boundary_line$TSA_boundary_upper)],
                      abs(boundary_line$TSA_boundary_lower[is.finite(boundary_line$TSA_boundary_lower)]))
  y_abs_max <- max(abs(cumul_df$Z), finite_bounds, na.rm = TRUE)
  y_limit <- y_abs_max * 1.15

  boundary_line$TSA_boundary_upper <- pmin(boundary_line$TSA_boundary_upper, y_limit)
  boundary_line$TSA_boundary_lower <- pmax(boundary_line$TSA_boundary_lower, -y_limit)

  events_accrued <- x$results$events_accrued
  x_max <- max(c(cumul_df$cum_events,
                  if (show_theoretical_daris) DARIS_events else NA,
                  if (show_info_threshold_marker) DARIS_info_threshold_events else NA,
                  if (show_endpoint_marker) route_endpoint_events else NA,
                  if (show_endpoint_theoretical) endpoint_theoretical_events else NA,
                  ## 0.2.8.3: the boundaries' own last x (the route endpoint)
                  ## must always fit inside the axis range
                  boundary_line$cum_events[is.finite(boundary_line$cum_events)]),
               na.rm = TRUE) * xmax_mult

  alpha_lines <- data.frame(
    cum_events = rep(boundary_line$cum_events, 2),
    y = c(boundary_line$TSA_boundary_upper, boundary_line$TSA_boundary_lower),
    side = rep(c("upper", "lower"), each = nrow(boundary_line)),
    type = "Alpha boundaries"
  )
  beta_lines <- data.frame(
    cum_events = rep(boundary_line$cum_events, 2),
    y = c(boundary_line$TSA_futility_upper, boundary_line$TSA_futility_lower),
    side = rep(c("upper", "lower"), each = nrow(boundary_line)),
    type = "Non-binding futility boundaries"
  )
  naive_lines <- data.frame(
    cum_events = rep(c(0, x_max), 2),
    y = rep(c(z_alpha, -z_alpha), each = 2),
    side = rep(c("upper", "lower"), each = 2),
    type = "Naive boundaries"
  )
  z_line <- data.frame(
    cum_events = cumul_df$cum_events,
    y = cumul_df$Z,
    side = "z",
    type = "Z scores"
  )

  plot_lines <- rbind(alpha_lines, beta_lines, naive_lines, z_line)
  line_types  <- c("Alpha boundaries" = "solid", "Non-binding futility boundaries" = "dashed",
                    "Naive boundaries" = "dashed", "Z scores" = "solid")
  line_colors <- c("Alpha boundaries" = alpha_col, "Non-binding futility boundaries" = beta_col,
                    "Naive boundaries" = naive_col, "Z scores" = z_col)
  line_widths <- c("Alpha boundaries" = 0.8, "Non-binding futility boundaries" = 0.8,
                    "Naive boundaries" = 0.5, "Z scores" = 0.8)

  cum_events <- y <- type <- side <- Z <- NULL  # avoid R CMD check NOTE for NSE

  p <- ggplot2::ggplot() +
    ggplot2::geom_line(
      data = plot_lines,
      ggplot2::aes(x = cum_events, y = y, color = type, linetype = type,
                   linewidth = type, group = interaction(type, side)),
      na.rm = TRUE
    ) +
    ggplot2::geom_point(data = cumul_df, ggplot2::aes(x = cum_events, y = Z, color = "Z scores"),
                         size = 2) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = x_max, y = 0, yend = 0),
                           color = "grey60", linewidth = 0.3) +
    ggplot2::annotate("text",
                       x = if (is.null(events_label_x)) max(cumul_df$cum_events) else events_label_x,
                       y = if (is.null(events_label_y)) -y_limit * 0.92 else events_label_y,
                       label = paste0("Events accrued = ", events_accrued),
                       hjust = 1, vjust = 0, size = events_label_size, color = "steelblue4") +
    ggplot2::scale_color_manual(name = NULL, values = line_colors) +
    ggplot2::scale_linetype_manual(name = NULL, values = line_types) +
    ggplot2::scale_linewidth_manual(values = line_widths, guide = "none") +
    ggplot2::labs(
      title = "Trial Sequential Analysis of Hazard Ratios",
      subtitle = paste0(
        sprintf(
          "Random-effects model | Diversity D\u00b2 = %.0f%% | Anticipated HR = %.2f | psi = %.3f | alpha=%.0f%%, power=%.0f%%",
          D2 * 100, HR_anticipated, allocation_p_used, alpha_two_sided * 100, power * 100),
        "\n", .tsahr_pooled_subtitle(x)),
      x = "Cumulative number of events",
      y = "Cumulative Z-score"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::coord_cartesian(xlim = c(0, x_max), ylim = c(-y_limit, y_limit), clip = "off")

  ## Theoretical DARIS event-equivalent reference line (Section 5 of
  ## tsa_hr()). Optional -- toggled off via show_theoretical_daris = FALSE
  ## -- since some users only want the observed-information marker below,
  ## or find two reference lines cluttered. Hiding it only affects the
  ## plot; the underlying DARIS calculation and "DARIS reached" verdict
  ## are unchanged either way.
  if (show_theoretical_daris) {
    p <- p +
      ggplot2::geom_vline(xintercept = DARIS_events, color = "black",
                           linetype = "dotted", linewidth = 0.6) +
      ggplot2::annotate("text",
                         x = if (is.null(daris_label_x)) DARIS_events else daris_label_x,
                         y = if (is.null(daris_label_y)) y_limit * 0.92 else daris_label_y,
                         label = paste0("Theoretical DARIS event-equivalent ~ ", ceiling(DARIS_events)),
                         hjust = -0.05, vjust = 0, size = daris_label_size)
  }

  ## Second reference marker: the ESTIMATED cumulative-events point at
  ## which the observed accrued statistical information reached DARIS_info
  ## (see tsa_hr(), Section 7b). Added separately, and only when DARIS has
  ## actually been reached, so it is never confused with the theoretical
  ## event-equivalent line above -- both are shown, distinctly labelled,
  ## per the package's documented "observed inverse-variance information"
  ## criterion.
  if (show_info_threshold_marker) {
    p <- p +
      ggplot2::geom_vline(xintercept = DARIS_info_threshold_events, color = "grey35",
                           linetype = "dashed", linewidth = 0.6) +
      ggplot2::annotate("text",
                         x = if (is.null(info_threshold_label_x)) DARIS_info_threshold_events
                             else info_threshold_label_x,
                         y = if (is.null(info_threshold_label_y)) y_limit * 0.75
                             else info_threshold_label_y,
                         label = paste0("DARIS information reached ~ ",
                                        ceiling(DARIS_info_threshold_events), " events (est.)"),
                         hjust = -0.05, vjust = 0, size = info_threshold_label_size,
                         color = "grey35")
  }

  ## Analysis route only: the formal analysis endpoint (design_R x DARIS
  ## information), estimated by interpolation between looks. Drawn
  ## separately from the DARIS marker above so the two are never conflated.
  if (show_endpoint_marker) {
    p <- p +
      ggplot2::geom_vline(xintercept = route_endpoint_events, color = "purple4",
                           linetype = "longdash", linewidth = 0.6) +
      ggplot2::annotate("text",
                         x = if (is.null(endpoint_label_x)) route_endpoint_events
                             else endpoint_label_x,
                         y = if (is.null(endpoint_label_y)) y_limit * 0.58
                             else endpoint_label_y,
                         label = paste0("Analysis-route endpoint (",
                                        sprintf("%.3f", route_endpoint),
                                        " x DARIS) reached ~ ",
                                        ceiling(route_endpoint_events), " events (est.)"),
                         hjust = -0.05, vjust = 0,
                         size = if (is.null(endpoint_label_size)) info_threshold_label_size
                                else endpoint_label_size,
                         color = "purple4")
  }

  ## Analysis route, endpoint NOT yet reached in the observed data (typically
  ## design_R > 1): mark where the formal boundaries terminate, i.e. the
  ## theoretical event-equivalent of design_R x DARIS. Analogous to the
  ## theoretical DARIS line; the label says explicitly that it is not reached.
  if (show_endpoint_theoretical) {
    p <- p +
      ggplot2::geom_vline(xintercept = endpoint_theoretical_events, color = "purple4",
                           linetype = "longdash", linewidth = 0.6) +
      ggplot2::annotate("text",
                         x = if (is.null(endpoint_label_x)) endpoint_theoretical_events
                             else endpoint_label_x,
                         y = if (is.null(endpoint_label_y)) y_limit * 0.58
                             else endpoint_label_y,
                         label = paste0("Analysis-route endpoint (",
                                        sprintf("%.3f", route_endpoint),
                                        " x DARIS) not yet reached; theoretical ~ ",
                                        ceiling(endpoint_theoretical_events), " events"),
                         hjust = -0.05, vjust = 0,
                         size = if (is.null(endpoint_label_size)) info_threshold_label_size
                                else endpoint_label_size,
                         color = "purple4")
  }

  if (caption) {
    methods_caption <- sprintf(
      paste0("Methods: Random-effects (%s) model, allocation psi = %.3f\n",
             "Alpha spending: O'Brien-Fleming-type (asOF); ",
             "Non-binding futility: RTSA-reconstructed recursive-integration ",
             "engine, O'Brien-Fleming-type beta-spending (bsOF)\n",
             "alpha = %.0f%% (two-sided), power = %.0f%% | Diversity D\u00b2 = %.0f%%, Adjustment factor = %.2f"),
      .tsahr_method_label(if (is.null(x$parameters$method)) "DL" else x$parameters$method),
      allocation_p_used, alpha_two_sided * 100, power * 100, D2 * 100, AF)
    if (analysis_route) {
      methods_caption <- paste0(methods_caption, sprintf(
        "\nBoundary route: RTSA analysis (formal endpoint = %.3f x DARIS information)",
        route_endpoint))
    }
    ## Estimated additional events/studies (7d in tsa_hr()) -- appended as
    ## its own caption line, below everything else, only when the route's
    ## own target has not been reached (design: DARIS; analysis: the
    ## analysis-route endpoint). Uses the deterministic Schoenfeld-scale
    ## events figure for the design route and the projected (approximate)
    ## figure for the analysis route, matching tsa_hr()'s printed output.
    projection <- x$projection
    if (!is.null(projection) && !is.na(projection$n_additional_studies)) {
      show_projection_caption <- if (analysis_route) !isTRUE(final_reached) else !isTRUE(daris_reached)
      if (show_projection_caption) {
        additional_events_caption <- if (analysis_route) {
          projection$additional_events_estimated
        } else {
          projection$additional_events_required_design
        }
        methods_caption <- paste0(methods_caption, sprintf(
          "\nEstimated additional events required: %s, Estimated additional studies required: %d",
          formatC(ceiling(additional_events_caption), format = "d", big.mark = ","),
          projection$n_additional_studies))
      }
    }
    p <- p + ggplot2::labs(caption = methods_caption) +
      ggplot2::theme(plot.caption = ggplot2::element_text(
        hjust = 0, size = caption_size, face = caption_face))
  }

  if (legend) {
    p <- p + ggplot2::theme(legend.position = "bottom")
  } else {
    p <- p + ggplot2::theme(legend.position = "none")
  }

  print(p)
  invisible(p)
}
