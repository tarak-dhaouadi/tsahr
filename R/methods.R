#' Print a tsa_hr object
#'
#' @param x An object of class \code{"tsa_hr"}.
#' @param ... Currently unused.
#' @export
print.tsa_hr <- function(x, ...) {
  cat("Trial Sequential Analysis (Hazard Ratios)\n")
  cat("------------------------------------------\n")
  cat(sprintf("Studies: %d | Events accrued: %d\n",
              nrow(x$data), x$results$events_accrued))
  cat(sprintf("Pooled HR (random effects): %.3f\n", exp(x$res_re$b)))
  cat(sprintf("Anticipated HR (RIS calc): %.3f\n", x$parameters$HR_anticipated))
  cat(sprintf("Theoretical DARIS event-equivalent: %d\n", ceiling(x$information_size$DARIS_events)))
  cat(sprintf("Crossed TSA boundary: %s | Entered futility region: %s | DARIS information reached: %s\n",
              ifelse(x$results$crossed_tsa, "YES", "NO"),
              ifelse(x$results$entered_futility_region, "YES", "NO"),
              ifelse(x$results$final_reached, "YES", "NO")))
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
                         alpha_col = "firebrick", beta_col = "blue",
                         naive_col = "darkgreen", z_col = "black",
                         ...) {

  cumul_df <- x$cumulative
  DARIS_events <- x$information_size$DARIS_events
  DARIS_info_threshold_events <- x$information_size$DARIS_info_threshold_events
  final_reached <- x$results$final_reached

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
  show_info_threshold_marker <- final_reached && !is.na(DARIS_info_threshold_events)

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
                  if (show_info_threshold_marker) DARIS_info_threshold_events else NA),
               na.rm = TRUE) * 1.15

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
      subtitle = sprintf(
        "Random-effects model | Diversity D\u00b2 = %.0f%% | Anticipated HR = %.2f | psi = %.3f | alpha=%.0f%%, power=%.0f%%",
        D2 * 100, HR_anticipated, allocation_p_used, alpha_two_sided * 100, power * 100),
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

  if (caption) {
    methods_caption <- sprintf(
      paste0("Methods: Random-effects (%s) model, allocation psi = %.3f\n",
             "Alpha spending: O'Brien-Fleming-type (asOF); ",
             "Non-binding futility: RTSA retrospective inner-wedge algorithm, ",
             "O'Brien-Fleming-type beta-spending (bsOF)\n",
             "alpha = %.0f%% (two-sided), power = %.0f%% | Diversity D\u00b2 = %.0f%%, Adjustment factor = %.2f"),
      .tsahr_method_label(if (is.null(x$parameters$method)) "DL" else x$parameters$method),
      allocation_p_used, alpha_two_sided * 100, power * 100, D2 * 100, AF)
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
