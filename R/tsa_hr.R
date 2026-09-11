## Internal helper: map a metafor `method` code to a human-readable label
## for use in printed/plotted output (e.g. "DL" -> "DerSimonian-Laird").
## Falls back to the bare code itself (quoted) for any method not in the
## table, so an unrecognised-but-valid metafor method code never errors
## here -- it just prints less prettily. Not exported.
.tsahr_method_label <- function(method) {
  labels <- c(
    DL    = "DerSimonian-Laird",
    HE    = "Hedges",
    CO    = "Hedges",
    HS    = "Hunter-Schmidt",
    HSk   = "Hunter-Schmidt (with k correction)",
    SJ    = "Sidik-Jonkman",
    ML    = "maximum likelihood",
    REML  = "restricted maximum likelihood",
    EB    = "empirical Bayes",
    PM    = "Paule-Mandel",
    GENQ  = "generalized Q-statistic",
    PMM   = "Paule-Mandel (median-unbiased)",
    GENQM = "generalized Q-statistic (median-unbiased)"
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
#'   cumulative (sequential) TSA model, passed straight through to
#'   \code{method} in \code{metafor::rma()}. One of \code{"DL"}
#'   (DerSimonian-Laird, the default -- kept as the default here for
#'   backward compatibility with earlier tsahr versions, which always used
#'   DL; note this differs from \code{metafor::rma()}'s own default of
#'   \code{"REML"}), \code{"HE"} (or its alias \code{"CO"}), \code{"HS"},
#'   \code{"HSk"}, \code{"SJ"}, \code{"ML"}, \code{"REML"}, \code{"EB"},
#'   \code{"PM"}, \code{"GENQ"}, \code{"PMM"}, or \code{"GENQM"}. See
#'   \code{?metafor::rma} for the definition of each estimator. This only
#'   changes the \emph{random-effects} model (\code{res_re}); the
#'   equal-effects model used internally for the Diversity (D^2)
#'   heterogeneity adjustment is always fitted with \code{method = "FE"}
#'   and is unaffected by this argument. Alpha-/beta-spending boundary
#'   calculations are unaffected by this argument.
#' @param order_by Optional name of a column in \code{data} to sort by
#'   (ascending) before the cumulative analysis, e.g. a publication-year
#'   column. TSA is order-dependent, so getting the chronological order
#'   right matters. Default \code{NULL}, which uses the row order already
#'   present in \code{data} and assumes it is chronological (with no way
#'   for the package to verify this).
#' @param verbose Logical; print analysis details to the console as the
#'   function runs (mirrors the diagnostic output of the original script).
#'   Default \code{TRUE}.
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
#' every step. The Lan-DeMets/O'Brien-Fleming monitoring boundaries
#' strictly assume the canonical joint (independent Brownian-motion
#' increments) distribution, which holds exactly only for a fixed-effect
#' cumulative process. With random effects this is a widely-used
#' approximation (as in the official Copenhagen Trial Unit TSA software),
#' not an exact result.
#'
#' **Retrospective boundary timeline:** the observed cumulative Z-curve
#' continues through every included study, but the formal alpha and beta
#' boundaries follow the RTSA retrospective convention: observed looks are
#' retained only while \code{info_fraction < 1}, followed by one synthetic
#' final-analysis point at \code{t = 1} (HARIS/DARIS). Boundaries are not
#' continued through studies occurring after DARIS. The synthetic point is
#' stored in \code{boundary_timeline}; the observed-study rows in
#' \code{cumulative} have boundary values set to \code{NA} at and after
#' DARIS. Formal crossing/futility decisions are evaluated only through the
#' first observed look reaching DARIS, using the definitive \code{t = 1}
#' boundary.
#'
#' @return An object of class \code{"tsa_hr"}: a list containing the fitted
#'   random-effects and fixed-effect \code{metafor::rma} model objects,
#'   heterogeneity statistics, allocation and required-information-size
#'   details, the cumulative analysis data frame, boundary-crossing
#'   results, and a summary data frame. Use \code{plot()},
#'   \code{summary()}, or \code{print()} on the result.
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
                    verbose = TRUE) {

  allocation_source <- match.arg(allocation_source)
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
  valid_methods <- c("DL", "HE", "CO", "HS", "HSk", "SJ", "ML", "REML",
                      "EB", "PM", "GENQ", "PMM", "GENQM")
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !(method %in% valid_methods)) {
    stop("method must be one of: ", paste(valid_methods, collapse = ", "),
         " (the random-effects heterogeneity-variance estimators supported ",
         "by metafor::rma(); see ?tsa_hr).")
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
  names(data) <- gsub(" ", "_", names(data))

  required_cols <- c("Study", "log_HR", "Std_Error",
                      "Events_Treatment", "N_treatment",
                      "Events_controls", "N_controls")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required column(s): ", paste(missing_cols, collapse = ", "))
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
  if (allocation_source == "manual" && (allocation_p <= 0 || allocation_p >= 1)) {
    stop("allocation_p must be strictly between 0 and 1.")
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

  D2 <- max(0, (var_random - var_fixed) / var_random)
  ## D2 is mathematically bounded in [0,1) since var_random >= var_fixed
  ## for essentially all of metafor's random-effects tau^2 estimators
  ## (they cannot produce a *smaller* variance than the equal-effects
  ## model), but with very few studies and extreme heterogeneity it can
  ## approach 1 closely enough that 1/(1-D2)
  ## becomes numerically unstable/explosive. Cap defensively and warn.
  ## NOTE: the 99.9% cap is a purely NUMERICAL safeguard against division
  ## by (near) zero, not a statistically justified correction to D2 or AF
  ## -- it does not represent any kind of upper bound derived from theory
  ## beyond D2's own mathematical range. Treat any AF computed near this
  ## cap as a sign that the adjustment factor itself is poorly identified
  ## given the data, not as a reliable large-but-finite value.
  if (D2 >= 0.999) {
    warning("Diversity D2 is at or very near its theoretical upper bound (100%), ",
            "indicating extreme heterogeneity relative to the number of studies. ",
            "D2 has been capped at 99.9% to avoid a numerically unstable/explosive ",
            "heterogeneity adjustment factor; interpret the required information ",
            "size and DARIS with caution in this scenario.", call. = FALSE)
    D2 <- 0.999
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
      "computed from pooled data: %d/%d treatment patients (psi = %.4f, ~%.0f:%.0f ratio)",
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
    cat(sprintf("Required number of events (RIS, no heterogeneity adj., under psi=%.3f): %d\n",
                allocation_p_used, ceiling(RIS_events)))
    cat(sprintf("Diversity-Adjusted Required Information (DARIS, information units): %.4f\n", DARIS_info))
    cat(sprintf("DARIS translated to an equivalent number of events (under pooled psi): %d\n\n",
                ceiling(DARIS_events)))
    cat(sprintf("Total events accrued across included studies: %d (%.1f%% of DARIS)\n\n",
                sum(data$total_events), 100 * sum(data$total_events) / DARIS_events))
  }

  circularity_warning <- is.na(target_HR) && sum(data$total_events) / DARIS_events > 3
  if (verbose && circularity_warning) {
    cat("*** NOTE: accrued events greatly exceed the DARIS because the RIS was\n")
    cat("    calculated from the observed (very large, very precise) pooled effect.\n")
    cat("    This is circular and will make the TSA boundary collapse almost\n")
    cat("    immediately to the conventional boundary. Consider re-running with\n")
    cat("    a pre-specified 'target_HR' for a more standard, protocol-driven TSA. ***\n\n")
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
    cat("    strictly assume the canonical joint distribution (independent\n")
    cat("    Brownian-motion increments), which holds exactly only for a\n")
    cat("    FIXED-EFFECT cumulative process. With random effects this is a\n")
    cat("    widely-used APPROXIMATION (as in the official Copenhagen Trial Unit\n")
    cat("    TSA software), not an exact result. ***\n\n")
  }

  ## -----------------------------------------------------------------
  ## 7. Trial sequential monitoring boundaries (alpha- and beta-spending)
  ##    Computed via this package's own O'Brien-Fleming-type recursive
  ##    integration engine (see R/obf_boundaries.R) -- no external
  ##    dependency, and no artificial limit on the number of looks.
  ## -----------------------------------------------------------------
  info_fracs    <- cumul_df$info_fraction
  final_reached <- max(info_fracs) >= 1

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
  ##     information first reaches DARIS_info, by linear interpolation
  ##     between the two bracketing looks. Because no study actually
  ##     occurred exactly at that interpolated event count, this is an
  ##     ESTIMATE of where the threshold was crossed, not an event count
  ##     that was itself observed -- it is deliberately NOT called
  ##     "DARIS events": that label is reserved for the theoretical
  ##     Schoenfeld-based event-equivalent (DARIS_events) computed in
  ##     Section 5. plot.tsa_hr() shows BOTH quantities, separately
  ##     labelled, rather than substituting one for the other. If DARIS
  ##     has NOT been reached within the observed data, there is nothing
  ##     to interpolate.
  ## -----------------------------------------------------------------
  if (final_reached) {
    reach_idx <- which(cumul_df$info_fraction >= 1)[1]
    if (reach_idx == 1) {
      DARIS_info_threshold_events <- cumul_df$cum_events[1]
    } else {
      f0 <- cumul_df$info_fraction[reach_idx - 1]
      f1 <- cumul_df$info_fraction[reach_idx]
      e0 <- cumul_df$cum_events[reach_idx - 1]
      e1 <- cumul_df$cum_events[reach_idx]
      w  <- if (f1 > f0) (1 - f0) / (f1 - f0) else 0
      DARIS_info_threshold_events <- e0 + w * (e1 - e0)
    }
  } else {
    DARIS_info_threshold_events <- NA_real_
  }

  ## RTSA retrospective boundary timeline:
  ##   * retain observed interim looks strictly before DARIS (t < 1);
  ##   * append one definitive final-analysis point at t = 1 (HARIS/DARIS);
  ##   * do not continue the alpha or beta boundary through studies that
  ##     occur after the required information size has been reached.
  ##
  ## This is deliberately separate from `cumul_df`, which continues to
  ## contain every observed study and its cumulative Z-score.  Thus the
  ## evidence curve can extend beyond DARIS while the formal monitoring
  ## boundaries terminate at the RTSA-style final information point.
  boundary_timing <- sort(unique(c(info_fracs[info_fracs < 1], 1)))
  alpha_bounds_design <- .obf_alpha_boundary(boundary_timing, alpha = alpha_two_sided)

  ## Keep the beta engine on the original observed timeline as well, so
  ## `beta_engine` continues to expose the RTSA retrospective calculation
  ## including its over-powered (>1) branch.  For the plotted/design
  ## boundary timeline, use a second calculation on the RTSA-style
  ## t < 1 + final t = 1 timeline.
  beta_unique_fracs <- sort(unique(info_fracs))
  beta_alpha_ref_observed <- alpha_bounds_design[
    match(pmin(beta_unique_fracs, 1), boundary_timing)
  ]
  beta_engine <- .rtsa_beta_boundary(beta_unique_fracs,
                                      alpha = alpha_two_sided,
                                      beta = 1 - power,
                                      c_vec_alpha = beta_alpha_ref_observed)

  ## IMPORTANT: do not recompute the RTSA beta engine on `boundary_timing`.
  ## The retrospective inner-wedge recursion is sequential: adding the
  ## synthetic t = 1 endpoint changes the earlier wedge recursion and hence
  ## changes the early futility boundaries.  Version 0.2.4.3 computed the
  ## early beta boundaries from the observed information fractions (with
  ## post-DARIS observations handled by RTSA's over-powered branch).  The
  ## requested correction is ONLY to relocate/add the final formal endpoint;
  ## therefore preserve those 0.2.4.3 beta values exactly and append the
  ## definitive final boundary separately.
  beta_pre_daris <- beta_engine$boundary[
    match(boundary_timing[boundary_timing < 1], beta_unique_fracs)
  ]
  beta_final <- min(
    stats::qnorm(1 - alpha_two_sided / 2),
    utils::tail(alpha_bounds_design, 1)
  )
  beta_bounds_design <- c(beta_pre_daris, beta_final)

  ## Map only genuine pre-DARIS observed looks back to the cumulative
  ## study table.  The synthetic t = 1 HARIS point is stored separately in
  ## `boundary_timeline`; it is not an observed study and therefore must
  ## not be inserted into `cumul_df`.
  boundary_z <- rep(NA_real_, length(info_fracs))
  futility_z <- rep(NA_real_, length(info_fracs))
  pre_daris <- info_fracs < 1
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
  boundary_endpoint_events <- if (final_reached &&
                                   is.finite(DARIS_info_threshold_events)) {
    DARIS_info_threshold_events
  } else {
    DARIS_events
  }

  boundary_timeline <- data.frame(
    info_fraction = boundary_timing,
    cum_events = c(
      vapply(boundary_timing[boundary_timing < 1], function(tt) {
        idx <- which(info_fracs == tt)[1]
        cumul_df$cum_events[idx]
      }, numeric(1)),
      boundary_endpoint_events
    ),
    TSA_boundary_upper = alpha_bounds_design,
    TSA_boundary_lower = -alpha_bounds_design,
    TSA_futility_upper = beta_bounds_design,
    TSA_futility_lower = -beta_bounds_design,
    synthetic = boundary_timing == 1,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cat("=== Trial sequential monitoring boundaries (alpha/beta spending) ===\n")
    cat(sprintf("Formal final boundary endpoint (DARIS information reached): %.1f cumulative events\n",
                boundary_endpoint_events))
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
  final_tsa_look <- if (final_reached) which(info_fracs >= 1)[1] else length(info_fracs)
  decision_idx <- seq_len(final_tsa_look)

  ## For the formal decision, the first look reaching DARIS is compared
  ## with the definitive t = 1 boundary, even though that boundary is
  ## displayed at the synthetic HARIS endpoint rather than on the observed
  ## post-DARIS study rows.
  decision_boundary_upper <- boundary_timeline$TSA_boundary_upper[
    match(pmin(info_fracs[decision_idx], 1), boundary_timeline$info_fraction)
  ]
  decision_futility_upper <- boundary_timeline$TSA_futility_upper[
    match(pmin(info_fracs[decision_idx], 1), boundary_timeline$info_fraction)
  ]

  crossed_tsa <- any(abs(cumul_df$Z[decision_idx]) >= decision_boundary_upper,
                     na.rm = TRUE)
  crossed_conventional <- any(abs(cumul_df$Z) >= z_alpha)
  entered_futility_region <- any(abs(cumul_df$Z[decision_idx]) <= decision_futility_upper,
                                  na.rm = TRUE)

  if (verbose) {
    if (final_reached && final_tsa_look < nrow(cumul_df)) {
      cat(sprintf(paste0("Note: DARIS was reached at study #%d of %d ('%s'). Formal TSA\n",
                          "  boundary-crossing/futility decisions below are evaluated only\n",
                          "  through that look (studies added afterward are still shown in\n",
                          "  the returned data and plot, but are not treated as additional\n",
                          "  formal 't=1' analyses -- see ?tsa_hr).\n"),
                  final_tsa_look, nrow(cumul_df), cumul_df$Study[final_tsa_look]))
    }
    cat(sprintf("Cumulative Z-curve crossed the conventional (P<0.05) boundary: %s\n",
                ifelse(crossed_conventional, "YES", "NO")))
    cat(sprintf("Cumulative Z-curve crossed the TSA monitoring boundary       : %s\n",
                ifelse(crossed_tsa, "YES", "NO")))
    cat(sprintf("Cumulative Z-curve entered the non-binding futility region  : %s\n",
                ifelse(entered_futility_region, "YES", "NO")))
    cat(sprintf("Required information size (DARIS) reached                    : %s\n",
                ifelse(final_reached, "YES", "NO")))
    cat(sprintf("  Theoretical DARIS event-equivalent (Schoenfeld-based)        : %d\n",
                ceiling(DARIS_events)))
    if (final_reached) {
      cat(sprintf(paste0("  Estimated cumulative events at which DARIS information\n",
                          "  was reached (interpolated, not an observed look)          : %d\n"),
                  ceiling(DARIS_info_threshold_events)))
      if (abs(DARIS_info_threshold_events - DARIS_events) > 0.01 * DARIS_events) {
        cat(sprintf(paste0("  (These may differ because the observed study-level information\n",
                            "   per event differs from the pooled psi*(1-psi) approximation\n",
                            "   used for the theoretical event-equivalent -- in either\n",
                            "   direction, not necessarily because information accrued faster.)\n")))
      }
    }
    cat("\n")
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
  events_accrued <- sum(data$total_events)
  info_accrued_final <- cumul_df$info_accrued[nrow(cumul_df)]

  summary_df <- data.frame(
    Parameter = c("Pooled HR (random effects, observed)", "95% CI lower", "95% CI upper",
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
                  "Estimated cumulative events at which DARIS information was reached",
                  "Crossed conventional boundary", "Crossed TSA monitoring boundary",
                  "Entered non-binding futility region (not a formal stopping decision)"),
    Value = c(round(exp(res_re$b), 3), round(exp(res_re$ci.lb), 3), round(exp(res_re$ci.ub), 3),
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
                     ceiling(DARIS_info_threshold_events)),
              crossed_conventional, crossed_tsa, entered_futility_region),
    stringsAsFactors = FALSE
  )

  out <- list(
    data = data,
    call = match.call(),
    parameters = list(alpha_two_sided = alpha_two_sided, power = power,
                       allocation_source = allocation_source,
                       allocation_p_used = allocation_p_used,
                       target_HR = target_HR, HR_anticipated = HR_anticipated,
                       method = method),
    res_re = res_re,
    res_fe = res_fe,
    heterogeneity = list(Q = Q, df = df, I2 = I2, tau2 = tau2, D2 = D2, AF = AF),
    beta_engine = beta_engine,
    information_size = list(z_alpha = z_alpha, z_beta = z_beta,
                             info_required = info_required, RIS_events = RIS_events,
                             DARIS_info = DARIS_info, DARIS_events = DARIS_events,
                             DARIS_info_threshold_events = DARIS_info_threshold_events,
                             circularity_warning = circularity_warning),
    cumulative = cumul_df,
    boundary_timeline = boundary_timeline,
    results = list(crossed_conventional = crossed_conventional,
                   crossed_tsa = crossed_tsa,
                   entered_futility_region = entered_futility_region,
                   final_reached = final_reached,
                   final_tsa_look = final_tsa_look,
                   events_accrued = events_accrued,
                   info_accrued_final = info_accrued_final),
    summary_table = summary_df
  )
  class(out) <- "tsa_hr"
  out
}
