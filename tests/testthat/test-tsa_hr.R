test_that("tsa_hr runs on the bundled example data and returns a valid object", {
  path <- tsahr_example_data()
  expect_true(file.exists(path))

  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  expect_s3_class(res, "tsa_hr")
  expect_true(all(c("res_re", "res_fe", "heterogeneity", "information_size",
                     "cumulative", "results", "summary_table") %in% names(res)))
  expect_equal(nrow(res$cumulative), nrow(res$data))
  expect_true(res$information_size$DARIS_events > 0)
  expect_true(is.logical(res$results$crossed_tsa))
})

test_that("unequal allocation inflates the required information size", {
  path <- tsahr_example_data()

  res_11 <- suppressMessages(tsa_hr(path, target_HR = 0.80,
                                     allocation_source = "manual",
                                     allocation_p = 0.5, verbose = FALSE))
  res_21 <- suppressMessages(tsa_hr(path, target_HR = 0.80,
                                     allocation_source = "manual",
                                     allocation_p = 2/3, verbose = FALSE))

  expect_gt(res_21$information_size$RIS_events, res_11$information_size$RIS_events)
})

test_that("invalid inputs are rejected", {
  path <- tsahr_example_data()

  expect_error(tsa_hr(path, target_HR = 1, verbose = FALSE), "cannot equal 1")
  expect_error(tsa_hr(path, target_HR = -0.5, verbose = FALSE), "must be > 0")
  expect_error(tsa_hr(path, allocation_source = "manual", allocation_p = 1.5,
                       verbose = FALSE), "strictly between 0 and 1")
  expect_error(tsa_hr(path, target_HR = 0.80, method = "not_a_method",
                       verbose = FALSE), "method must be one of")
  expect_error(tsa_hr(path, target_HR = 0.80, method = "FE",
                       verbose = FALSE), "method must be one of")
  expect_error(tsa_hr(path, target_HR = 0.80, method = c("DL", "REML"),
                       verbose = FALSE), "method must be one of")
})

test_that("method defaults to DL and accepts other metafor random-effects estimators", {
  path <- tsahr_example_data()

  res_default <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  res_dl      <- suppressMessages(tsa_hr(path, target_HR = 0.80, method = "DL",
                                          verbose = FALSE))
  res_reml    <- suppressMessages(tsa_hr(path, target_HR = 0.80, method = "REML",
                                          verbose = FALSE))
  res_ml      <- suppressMessages(tsa_hr(path, target_HR = 0.80, method = "ML",
                                          verbose = FALSE))

  ## Default is unchanged (still DL) for backward compatibility.
  expect_identical(res_default$parameters$method, "DL")
  expect_identical(res_default$res_re$method, "DL")
  expect_equal(res_default$heterogeneity$tau2, res_dl$heterogeneity$tau2)

  ## A different method is actually passed through to metafor::rma().
  expect_identical(res_reml$res_re$method, "REML")
  expect_identical(res_reml$parameters$method, "REML")
  expect_identical(res_ml$res_re$method, "ML")

  ## The equal-effects comparator used for D2 is untouched by `method`.
  expect_identical(res_reml$res_fe$method, "FE")
  expect_identical(res_reml$res_fe$b, res_dl$res_fe$b)
})

test_that("print, summary, and plot methods work without error", {
  path <- tsahr_example_data()
  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  expect_output(print(res))
  expect_output(summary(res))

  p <- plot(res)
  expect_s3_class(p, "ggplot")
})

test_that("plot label size/position overrides work without error", {
  path <- tsahr_example_data()
  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  p <- plot(res, daris_label_size = 5, events_label_size = 5,
            daris_label_x = 1000, daris_label_y = 8,
            events_label_x = 3000, events_label_y = -8)
  expect_s3_class(p, "ggplot")
})

test_that("internal OF alpha boundary is consistent with the classical O'Brien-Fleming boundary", {
  ## Independent validation (not tied to any specific external package):
  ## the published O'Brien-Fleming boundary constant for K=5 equally-
  ## spaced two-sided looks at alpha=0.05 is ~2.040 (Lan & DeMets 1983).
  ## Note this package implements the Lan-DeMets *alpha-spending*
  ## approximation to the O'Brien-Fleming design (as does e.g. rpact's
  ## "asOF"), which is closely related to but not numerically identical
  ## to the original O'Brien-Fleming (1979) group sequential construction
  ## (rpact's "OF"); reproducing a value close to the classical constant
  ## here confirms the recursive integration engine is implemented
  ## correctly, not that the two constructions are interchangeable.
  t5 <- c(0.2, 0.4, 0.6, 0.8, 1)
  c5 <- tsahr:::.obf_alpha_boundary(t5, alpha = 0.05)
  expect_equal(c5[5], 2.04, tolerance = 0.05)
  expect_true(all(diff(c5) < 0))  # boundaries should be strictly decreasing
})

test_that("boundary engine scales to many studies (no kMax limit)", {
  set.seed(1)
  n <- 40
  t40 <- sort(unique(c(seq(0.02, 1, length.out = n - 1), 1)))
  expect_no_error(c40 <- tsahr:::.obf_alpha_boundary(t40, alpha = 0.05))
  expect_no_error(b40 <- tsahr:::.obf_beta_boundary(t40, alpha = 0.05, beta = 0.2,
                                                     c_vec_alpha = c40))
  expect_equal(length(c40), length(t40))
  ## As of the RTSA-matched beta engine, the final look's futility
  ## boundary is deliberately set to the definitive two-sided alpha
  ## quantile (qnorm(1-alpha/2)) rather than NA: at a genuinely final,
  ## definitive analysis there is no distinct "non-binding early stop for
  ## futility" separate from the main efficacy decision, matching RTSA's
  ## convention (see .rtsa_beta_boundary(), the non-over-powered branch).
  ## This replaced the earlier (pre-RTSA-match) convention of leaving the
  ## final look as NA -- verified directly against the current code
  ## (obf_boundaries.R: `b[length(b)] <- stats::qnorm(1 - alpha / 2, ...)`
  ## in the branch taken here, since max(t40)==1 exactly, not >1).
  expect_equal(b40[length(b40)], stats::qnorm(1 - 0.05 / 2), tolerance = 1e-8)
})

test_that("tsa_hr runs end-to-end on a large (40-study) synthetic dataset", {
  set.seed(42)
  n <- 40
  studies <- data.frame(
    Study = sprintf("Study_%02d", 1:n),
    log_HR = rnorm(n, mean = log(0.95), sd = 0.03),
    Std_Error = runif(n, 0.05, 0.30)
  )
  studies$Events_Treatment <- sample(50:400, n, replace = TRUE)
  studies$Events_controls  <- sample(50:400, n, replace = TRUE)
  studies$N_treatment <- studies$Events_Treatment + sample(100:800, n, replace = TRUE)
  studies$N_controls  <- studies$Events_controls + sample(100:800, n, replace = TRUE)

  expect_no_error(res <- tsa_hr(studies, target_HR = 0.90, verbose = FALSE))
  expect_s3_class(res, "tsa_hr")
  expect_equal(nrow(res$cumulative), n)
  expect_no_error(p <- plot(res))
  expect_s3_class(p, "ggplot")
})

test_that("alpha-boundary engine controls type-I error at nominal level (Monte Carlo)", {
  ## Independent operating-characteristic check: simulate cumulative
  ## Z-trajectories under the null (no effect) for several look-count and
  ## information-schedule configurations, apply the computed alpha
  ## boundaries, and confirm the empirical rejection rate matches the
  ## nominal two-sided alpha (within Monte Carlo error).
  skip_on_cran()
  set.seed(2024)
  run_mc <- function(t, alpha, n_sim) {
    K <- length(t)
    c_bounds <- tsahr:::.obf_alpha_boundary(t, alpha = alpha)
    increments_sd <- sqrt(diff(c(0, t)))
    rejected <- vapply(seq_len(n_sim), function(i) {
      Bvals <- cumsum(rnorm(K, sd = increments_sd))
      Zvals <- Bvals / sqrt(t)
      any(abs(Zvals) >= c_bounds)
    }, logical(1))
    mean(rejected)
  }

  configs <- list(
    c(0.2, 0.4, 0.6, 0.8, 1),
    c(0.5, 1),
    c(0.1, 0.25, 1),
    seq(0.1, 1, by = 0.1),
    ## K=39, genuinely UNEQUALLY spaced (a power-transformed schedule, not
    ## a constant step -- seq(..., length.out=39) would be equally spaced
    ## despite the misleading comment that used to be here)
    {
      t39 <- (seq_len(39) / 39)^1.4
      t39[39] <- 1
      t39
    }
  )
  n_sim <- 4000
  for (t in configs) {
    emp_alpha <- run_mc(t, alpha = 0.05, n_sim = n_sim)
    se <- sqrt(0.05 * 0.95 / n_sim)
    ## generous +/- 4 SE tolerance to keep this fast and non-flaky while
    ## still being a meaningful check (would catch a materially broken
    ## boundary calculation, e.g. off by a large factor)
    expect_lt(abs(emp_alpha - 0.05), 4 * se)
  }
})

test_that("beta-spending function targets total spend = beta (not 2*beta) at t=1", {
  ## .beta_spend_OF is deliberately NOT doubled like .alpha_spend_OF (see
  ## comment in R/obf_boundaries.R): the non-binding futility construction
  ## targets a single central "inner wedge", not two symmetric outer
  ## tails, so the cumulative nominal spend at t=1 should equal beta
  ## itself, matching the nominal type-II-error/power budget used
  ## elsewhere in the package's calculations.
  for (beta in c(0.1, 0.2, 0.3)) {
    expect_equal(tsahr:::.beta_spend_OF(1, beta), beta, tolerance = 1e-8)
  }
})

test_that("alpha boundaries behave sensibly across K and information schedules", {
  configs <- list(
    K2  = c(0.5, 1),
    K3  = c(0.2, 0.5, 1),
    K5  = c(0.1, 0.25, 0.5, 0.75, 1),
    K10 = seq(0.1, 1, by = 0.1)
  )
  for (t in configs) {
    c_vec <- tsahr:::.obf_alpha_boundary(t, alpha = 0.05)
    finite_c <- c_vec[is.finite(c_vec)]
    ## boundaries should generally decrease as information accumulates
    expect_true(all(diff(finite_c) <= 1e-8))
    ## final boundary should be in a sensible range around the
    ## conventional fixed-sample critical value (1.96), not wildly off
    expect_true(c_vec[length(c_vec)] >= 1.9 && c_vec[length(c_vec)] <= 2.5)
  }
})

test_that("D2/AF are safely capped under extreme heterogeneity", {
  ## Construct a pathological, highly heterogeneous 2-study dataset and
  ## confirm D2 stays < 1 and AF stays finite, with a warning issued.
  extreme_data <- data.frame(
    Study = c("A", "B"),
    log_HR = c(-2, 2),
    Std_Error = c(0.05, 0.05),
    Events_Treatment = c(100, 100), N_treatment = c(200, 200),
    Events_controls  = c(100, 100), N_controls  = c(200, 200)
  )
  expect_warning(
    res <- tsa_hr(extreme_data, target_HR = 0.80, verbose = FALSE),
    "Diversity D2"
  )
  expect_true(res$heterogeneity$D2 < 1)
  expect_true(is.finite(res$heterogeneity$AF))
})

test_that("target_HR = NA triggers a circularity warning", {
  path <- tsahr_example_data()
  expect_warning(tsa_hr(path, verbose = FALSE), "circular")
})

test_that("invalid event/sample-size data are rejected", {
  base <- data.frame(
    Study = c("A", "B"), log_HR = c(-0.2, -0.3), Std_Error = c(0.1, 0.1),
    Events_Treatment = c(50, 50), N_treatment = c(100, 100),
    Events_controls = c(50, 50), N_controls = c(100, 100)
  )

  bad_events <- base; bad_events$Events_Treatment[1] <- 150  # exceeds N
  expect_error(tsa_hr(bad_events, target_HR = 0.8, verbose = FALSE),
               "cannot exceed N_treatment")

  bad_n <- base; bad_n$N_controls[1] <- 0
  expect_error(tsa_hr(bad_n, target_HR = 0.8, verbose = FALSE),
               "must be > 0")

  bad_se <- base; bad_se$Std_Error[1] <- 0
  expect_error(tsa_hr(bad_se, target_HR = 0.8, verbose = FALSE),
               "strictly positive")

  bad_hr <- base; bad_hr$log_HR[1] <- NA
  expect_error(tsa_hr(bad_hr, target_HR = 0.8, verbose = FALSE),
               "must be finite")
})

test_that("results object uses the renamed entered_futility_region field", {
  path <- tsahr_example_data()
  res <- suppressWarnings(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  expect_true("entered_futility_region" %in% names(res$results))
})

test_that("plot color customization works without error", {
  path <- tsahr_example_data()
  res <- suppressWarnings(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  p <- plot(res, alpha_col = "purple", beta_col = "orange",
            naive_col = "grey40", z_col = "steelblue")
  expect_s3_class(p, "ggplot")
})

test_that("caption size/face are customizable and actually applied", {
  path <- tsahr_example_data()
  res <- suppressWarnings(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  p_default <- plot(res)
  expect_equal(p_default$theme$plot.caption$size, 8)
  expect_equal(p_default$theme$plot.caption$face, "italic")

  p_custom <- plot(res, caption_size = 12, caption_face = "plain")
  expect_s3_class(p_custom, "ggplot")
  expect_equal(p_custom$theme$plot.caption$size, 12)
  expect_equal(p_custom$theme$plot.caption$face, "plain")

  ## caption = FALSE should skip the caption entirely. Check via $labels
  ## rather than $theme$plot.caption: modern ggplot2's (S7-based) theme
  ## objects resolve an unset element to an inherited element_text, not a
  ## literal NULL, when accessed this way -- labs()$caption is the stable
  ## signal that ggplot2::labs(caption = ...) was never called, matching
  ## what this test is actually meant to check.
  p_none <- plot(res, caption = FALSE)
  expect_null(p_none$labels$caption)
})

## --- Tests for the two DARIS-vs-events disagreement directions --------
## Both directions are constructed with homogeneous studies (identical
## log_HR => D2=0, AF=1 exactly) and psi=0.5 (equal N per arm), so
## DARIS_info and DARIS_events are simple, predictable multiples of each
## other (DARIS_events = DARIS_info / (psi*(1-psi)) = 4 * DARIS_info when
## psi=0.5), and the only thing varied is each study's information PER
## EVENT (via Std_Error) relative to the psi*(1-psi)=0.25 Schoenfeld
## assumption -- this is exactly the mechanism that makes the theoretical
## DARIS event-equivalent and the observed-information threshold disagree
## (see ?tsa_hr, "Information-fraction convention").
test_that("DARIS info-threshold can be reached BEFORE the theoretical event-equivalent", {
  ## Each study supplies far more information per event (1/SE^2=100 for
  ## 100 events, i.e. 1.0 info/event) than the psi*(1-psi)=0.25 assumed
  ## by the theoretical event-equivalent -- so the exact information
  ## criterion is met using fewer events than DARIS_events predicts.
  over_info <- data.frame(
    Study = paste0("S", 1:3),
    log_HR = rep(log(0.8), 3),
    Std_Error = rep(0.1, 3),
    Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
    Events_controls  = rep(50, 3), N_controls  = rep(1000, 3)
  )
  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))

  expect_equal(res$heterogeneity$D2, 0)
  expect_true(res$results$final_reached)
  expect_lt(res$results$events_accrued, res$information_size$DARIS_events)
  expect_true(is.finite(res$information_size$DARIS_info_threshold_events))
  ## the formal decision should be based on the look where DARIS was
  ## FIRST reached, not every look afterward
  expect_equal(res$results$final_tsa_look, which(res$cumulative$info_fraction >= 1)[1])
  expect_lt(res$results$final_tsa_look, nrow(res$cumulative))
})

test_that("DARIS info-threshold can remain unreached AFTER the theoretical event-equivalent", {
  ## Each study supplies far less information per event (1/SE^2=6.25 for
  ## 100 events, i.e. 0.0625 info/event) than the psi*(1-psi)=0.25
  ## assumption -- so cumulative EVENTS can pass the theoretical
  ## event-equivalent while the exact information criterion still has not
  ## been met.
  under_info <- data.frame(
    Study = paste0("S", 1:7),
    log_HR = rep(log(0.8), 7),
    Std_Error = rep(0.4, 7),
    Events_Treatment = rep(50, 7), N_treatment = rep(1000, 7),
    Events_controls  = rep(50, 7), N_controls  = rep(1000, 7)
  )
  res <- suppressWarnings(tsa_hr(under_info, target_HR = 0.80, verbose = FALSE))

  expect_equal(res$heterogeneity$D2, 0)
  expect_false(res$results$final_reached)
  expect_gt(res$results$events_accrued, res$information_size$DARIS_events)
  expect_true(is.na(res$information_size$DARIS_info_threshold_events))
  ## with DARIS never reached, the formal decision uses every look
  expect_equal(res$results$final_tsa_look, nrow(res$cumulative))
})

test_that("scalar parameter validation rejects out-of-range alpha/power/target_HR", {
  path <- tsahr_example_data()
  expect_error(tsa_hr(path, alpha_two_sided = 2, target_HR = 0.8, verbose = FALSE),
               "alpha_two_sided")
  expect_error(tsa_hr(path, power = 1.5, target_HR = 0.8, verbose = FALSE),
               "power")
  expect_error(tsa_hr(path, target_HR = c(0.8, 0.9), verbose = FALSE),
               "target_HR")
})

test_that("at least two studies are required", {
  one_study <- data.frame(
    Study = "A", log_HR = -0.2, Std_Error = 0.1,
    Events_Treatment = 50, N_treatment = 100,
    Events_controls = 50, N_controls = 100
  )
  expect_error(tsa_hr(one_study, target_HR = 0.8, verbose = FALSE),
               "at least two studies")
})

test_that("non-integer event/sample-size counts are rejected", {
  base <- data.frame(
    Study = c("A", "B"), log_HR = c(-0.2, -0.3), Std_Error = c(0.1, 0.1),
    Events_Treatment = c(50, 50), N_treatment = c(100, 100),
    Events_controls = c(50, 50), N_controls = c(100, 100)
  )
  bad <- base; bad$Events_Treatment[1] <- 50.5
  expect_error(tsa_hr(bad, target_HR = 0.8, verbose = FALSE),
               "whole numbers")
})
