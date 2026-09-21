test_that("tsa_hr runs on the frozen 10-study example data and returns a valid object", {
  path <- legacy_example_data()
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
  path <- legacy_example_data()

  res_11 <- suppressMessages(tsa_hr(path, target_HR = 0.80,
                                     allocation_source = "manual",
                                     allocation_p = 0.5, verbose = FALSE))
  res_21 <- suppressMessages(tsa_hr(path, target_HR = 0.80,
                                     allocation_source = "manual",
                                     allocation_p = 2/3, verbose = FALSE))

  expect_gt(res_21$information_size$RIS_events, res_11$information_size$RIS_events)
})

test_that("invalid inputs are rejected", {
  path <- legacy_example_data()

  expect_error(tsa_hr(path, target_HR = 1, verbose = FALSE), "cannot equal 1")
  expect_error(tsa_hr(path, target_HR = -0.5, verbose = FALSE), "must be > 0")
  expect_error(tsa_hr(path, allocation_source = "manual", allocation_p = 1.5,
                       verbose = FALSE), "strictly between 0 and 1")
  expect_error(tsa_hr(path, target_HR = 0.80, method = "not_a_method",
                       verbose = FALSE), "method must be one of")
  expect_error(tsa_hr(path, target_HR = 0.80, method = "FE",
                       verbose = FALSE), "method must be one of")
  expect_error(tsa_hr(path, target_HR = 0.80, method = c("DL", "REML"),
                       verbose = FALSE), "single character string")
  ## "CO"/"VC" are metafor's documented aliases for the Hedges ("HE")
  ## estimator, but are not accepted by every metafor version -- tsa_hr()
  ## normalises them to "HE" itself (0.2.6.7) so they work regardless of
  ## the installed metafor. They must therefore NOT error.
  ## (0.2.6.6 incorrectly rejected "CO" outright; see NEWS.)
  expect_no_error(suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = 0.80, method = "CO", verbose = FALSE)
  )))
  ## "GENQ"/"GENQM" ARE genuine metafor method strings, but require a
  ## user-supplied `weights` argument to metafor::rma() that tsa_hr()
  ## does not currently collect or pass through -- these get a specific,
  ## explanatory error rather than the generic "method must be one of"
  ## list (which would be misleading, since these two names ARE real
  ## metafor methods, just not ones usable standalone here).
  expect_error(tsa_hr(path, target_HR = 0.80, method = "GENQ",
                       verbose = FALSE), "require.*weights.*argument")
  expect_error(tsa_hr(path, target_HR = 0.80, method = "GENQM",
                       verbose = FALSE), "require.*weights.*argument")
  expect_error(tsa_hr(path, allocation_source = "manual",
                       allocation_p = NA, verbose = FALSE),
               "single finite numeric value")
  expect_error(tsa_hr(path, allocation_source = "manual",
                       allocation_p = c(0.5, 0.6), verbose = FALSE),
               "single finite numeric value")
  expect_error(tsa_hr(path, allocation_source = "manual",
                       allocation_p = "0.5", verbose = FALSE),
               "single finite numeric value")
})

test_that("method defaults to DL and accepts other metafor random-effects estimators", {
  path <- legacy_example_data()

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

test_that("every advertised method value runs and returns a valid object", {
  ## Regression test for a real bug found (independently of the external
  ## audit that prompted this test's addition) while writing this exact
  ## test: tsa_hr() previously advertised 13 method values, but some of
  ## them never actually worked -- "GENQ"/"GENQM" require a `weights`
  ## argument that tsa_hr() doesn't collect. This went unnoticed because
  ## only DL/REML/
  ## ML were ever tested. This test exercises every method value tsa_hr()
  ## currently advertises as supported (see `valid_methods` in
  ## R/tsa_hr.R), so a similar gap can't recur silently -- it doesn't
  ## check that all methods produce the same answer, only that each one:
  ## runs without error, returns the method it was asked for, returns a
  ## finite tau2, and produces a valid tsa_hr object.
  path <- legacy_example_data()
  supported_methods <- c("DL", "HE", "HS", "HSk", "SJ", "ML", "REML",
                          "EB", "PM", "PMM")

  for (m in supported_methods) {
    res <- suppressMessages(suppressWarnings(
      tsa_hr(path, target_HR = 0.80, method = m, verbose = FALSE)
    ))
    expect_s3_class(res, "tsa_hr")
    expect_identical(res$res_re$method, m, info = paste("method =", m))
    expect_identical(res$parameters$method, m, info = paste("method =", m))
    expect_true(is.finite(res$heterogeneity$tau2), info = paste("method =", m))
  }
})

test_that("print, summary, and plot methods work without error", {
  path <- legacy_example_data()
  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  expect_output(print(res))
  expect_output(summary(res))

  p <- plot(res)
  expect_s3_class(p, "ggplot")
})

test_that("plot label size/position overrides work without error", {
  path <- legacy_example_data()
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

test_that("LEGACY R-only boundary engine scales to many studies (no kMax limit)", {
  ## This tests the legacy pure-R engine (.obf_*), kept as tsa_hr()'s
  ## fallback. The current compiled engine's many-look behaviour is tested
  ## in test-robust-schedules.R.
  set.seed(1)
  n <- 40
  t40 <- sort(unique(c(seq(0.02, 1, length.out = n - 1), 1)))
  expect_no_error(c40 <- tsahr:::.obf_alpha_boundary(t40, alpha = 0.05))
  expect_no_error(b40 <- tsahr:::.obf_beta_boundary(t40, alpha = 0.05, beta = 0.2,
                                                     c_vec_alpha = c40))
  expect_equal(length(c40), length(t40))
  ## LEGACY engine convention: the final look's futility boundary equals
  ## the TRUE, schedule-dependent final alpha (efficacy) boundary --
  ## .rtsa_beta_boundary() recomputes this itself via .obf_alpha_boundary()
  ## on timing_beta = sort(unique(c(t[t<1], 1))) (obf_boundaries.R), which
  ## for this t40 (already sorted, unique, ending in an exact 1) is t40
  ## itself -- so the expected value is exactly c40's own last entry,
  ## already computed above, not a fixed constant.
  ##
  ## ** FIXED in 0.2.7.20. ** This used to assert the OLD, WRONG constant
  ## stats::qnorm(1 - alpha/2) = 1.96 here, on the assumption (itself fixed
  ## in 0.2.7.19) that RTSA's discretised final boundary always equals that
  ## continuous-limit value. It doesn't -- for this exact 40-look schedule
  ## the true value is materially different (~2.16) -- so this test was
  ## encoding the same bug .rtsa_beta_boundary() itself was fixed to stop
  ## making, and started failing (correctly) the moment that production fix
  ## landed. Asserting against c40's own last entry instead means this test
  ## can never re-encode a hardcoded assumption about what that value is.
  expect_equal(b40[length(b40)], c40[length(c40)], tolerance = 1e-8)
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
  ## D2_raw/D2_was_capped make the capping auditable rather than silent:
  ## D2_raw should be the (uncapped) value that triggered the cap, i.e.
  ## >= 0.999, and D2_was_capped should be TRUE and D2 itself pinned to
  ## exactly the cap.
  expect_true(res$heterogeneity$D2_was_capped)
  expect_true(res$heterogeneity$D2_raw >= 0.999)
  expect_equal(res$heterogeneity$D2, 0.999)
})

test_that("D2_was_capped is FALSE and D2_raw == D2 in the ordinary (uncapped) case", {
  path <- legacy_example_data()
  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  expect_false(res$heterogeneity$D2_was_capped)
  expect_equal(res$heterogeneity$D2_raw, res$heterogeneity$D2)
})

test_that("Study identifiers must be non-missing and non-blank", {
  bad_na <- data.frame(
    Study = c("A", NA),
    log_HR = c(0.1, 0.2), Std_Error = c(0.1, 0.1),
    Events_Treatment = c(10, 10), N_treatment = c(100, 100),
    Events_controls = c(10, 10), N_controls = c(100, 100)
  )
  bad_blank <- bad_na
  bad_blank$Study <- c("A", "   ")

  expect_error(tsa_hr(bad_na, target_HR = 0.80, verbose = FALSE),
               "non-missing, non-empty")
  expect_error(tsa_hr(bad_blank, target_HR = 0.80, verbose = FALSE),
               "non-missing, non-empty")
})

test_that("order_by warns on tied values", {
  path <- legacy_example_data()
  d <- as.data.frame(readxl::read_excel(path))
  d$Year <- rep(2010, nrow(d))  ## force every row to tie

  expect_warning(
    tsa_hr(d, target_HR = 0.80, order_by = "Year", verbose = FALSE),
    "tied values"
  )
})

test_that("order_by actually determines the cumulative order", {
  ## Complements the tied-values warning test above: that one checks the
  ## warning fires, this one checks the SORTING itself is real. Without
  ## this, order_by could silently no-op and only the warning path would
  ## be covered. TSA is order-dependent, so this is a reproducibility
  ## guarantee, not a cosmetic one.
  path <- legacy_example_data()
  d <- as.data.frame(readxl::read_excel(path))
  d$Year <- seq_len(nrow(d)) + 1990L  ## strictly increasing, no ties

  ## Shuffle deterministically, then ask tsa_hr() to restore order via
  ## order_by; result must match the already-sorted data analysed with
  ## no order_by at all.
  shuffled <- d[rev(seq_len(nrow(d))), , drop = FALSE]

  a <- suppressMessages(suppressWarnings(
    tsa_hr(shuffled, target_HR = 0.80, order_by = "Year", verbose = FALSE)
  ))
  b <- suppressMessages(suppressWarnings(
    tsa_hr(d, target_HR = 0.80, verbose = FALSE)
  ))

  expect_identical(as.character(a$cumulative$Study),
                   as.character(b$cumulative$Study))
  expect_equal(a$cumulative$Z, b$cumulative$Z)
  expect_equal(a$cumulative$info_fraction, b$cumulative$info_fraction)
})

test_that("order_by accepts the original spaced column name", {
  ## 0.2.6.7: column names have spaces replaced with underscores on
  ## load, so a user passing the header exactly as it reads in their
  ## spreadsheet would previously hit a "not found" error for a column
  ## that is visibly present. order_by is now normalised the same way.
  path <- legacy_example_data()
  d <- as.data.frame(readxl::read_excel(path))
  d$`Publication Year` <- seq_len(nrow(d)) + 1990L

  expect_no_error(suppressMessages(suppressWarnings(
    tsa_hr(d, target_HR = 0.80, order_by = "Publication Year",
           verbose = FALSE)
  )))
  ## The underscored form must keep working too.
  expect_no_error(suppressMessages(suppressWarnings(
    tsa_hr(d, target_HR = 0.80, order_by = "Publication_Year",
           verbose = FALSE)
  )))
})

test_that("column names that collide after underscore normalisation are rejected", {
  ## 0.2.6.7: "Std Error" and "Std_Error" both normalise to "Std_Error",
  ## after which data$Std_Error silently resolves to whichever came
  ## first -- a wrong-column bug producing a plausible but incorrect
  ## analysis with no error. Must be refused, not guessed at.
  path <- legacy_example_data()
  d <- as.data.frame(readxl::read_excel(path))
  d$`Std Error` <- d$Std_Error * 2  ## collides with existing Std_Error

  expect_error(tsa_hr(d, target_HR = 0.80, verbose = FALSE),
               "not unique after spaces")
})

test_that("target_HR near the null value of 1 triggers a warning, not an error", {
  path <- legacy_example_data()
  expect_warning(
    res <- tsa_hr(path, target_HR = 0.95, verbose = FALSE),
    "very close to the null value of 1"
  )
  expect_s3_class(res, "tsa_hr")
  ## Comfortably outside the near-null band: no warning expected here.
  expect_warning(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE),
    NA
  )
})

test_that("target_HR = NA triggers a circularity warning", {
  path <- legacy_example_data()
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
  path <- legacy_example_data()
  res <- suppressWarnings(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  expect_true("entered_futility_region" %in% names(res$results))
})

test_that("plot color customization works without error", {
  path <- legacy_example_data()
  res <- suppressWarnings(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  p <- plot(res, alpha_col = "purple", beta_col = "orange",
            naive_col = "grey40", z_col = "steelblue")
  expect_s3_class(p, "ggplot")
})

test_that("caption size/face are customizable and actually applied", {
  path <- legacy_example_data()
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
  path <- legacy_example_data()
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

test_that("method aliases CO and VC are normalised to HE", {
  ## 0.2.6.7. metafor documents "CO" (Cochran) and "VC" (variance
  ## component) as alternative names for the Hedges ("HE") estimator,
  ## selectable via those strings -- but that alias is not accepted by
  ## every metafor version (older releases reject a bare "CO" with
  ## "Unknown 'method' specified"). tsa_hr() therefore normalises them
  ## itself, so behaviour does not depend on which metafor is installed.
  ##
  ## This test pins the normalisation both structurally (what gets
  ## recorded and what gets passed to metafor) and NUMERICALLY (the
  ## alias must give bit-for-bit the same analysis as "HE" -- these are
  ## the same estimator, so any divergence is a bug).
  path <- legacy_example_data()

  res_he <- suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = 0.80, method = "HE", verbose = FALSE)
  ))

  for (alias in c("CO", "VC")) {
    res_alias <- suppressMessages(suppressWarnings(
      tsa_hr(path, target_HR = 0.80, method = alias, verbose = FALSE)
    ))

    ## Normalised string is what actually reaches metafor...
    expect_identical(res_alias$parameters$method, "HE",
                     info = paste("alias =", alias))
    expect_identical(res_alias$res_re$method, "HE",
                     info = paste("alias =", alias))
    ## ...but what the caller asked for is still recorded, so the
    ## normalisation is auditable rather than silent.
    expect_identical(res_alias$parameters$method_requested, alias,
                     info = paste("alias =", alias))

    ## Same estimator => identical numbers.
    expect_equal(res_alias$heterogeneity$tau2, res_he$heterogeneity$tau2,
                 info = paste("alias =", alias))
    expect_equal(res_alias$heterogeneity$D2, res_he$heterogeneity$D2,
                 info = paste("alias =", alias))
    expect_equal(res_alias$cumulative$Z, res_he$cumulative$Z,
                 info = paste("alias =", alias))
  }

  ## A non-alias method must still record method_requested == method,
  ## so downstream code can rely on the field always being present.
  expect_identical(res_he$parameters$method_requested, "HE")
})

test_that("circularity_warning reflects circularity itself, not severity", {
  ## 0.2.6.8. Before this, `circularity_warning` carried the *severe*
  ## condition (circular AND accrued events > 3x DARIS), while
  ## summary.tsa_hr() printed a message worded for the *general* case
  ## ("target_HR was not specified... This is circular"). A circular
  ## analysis that hadn't blown past 3x DARIS therefore reported no
  ## circularity at all, contradicting ?tsa_hr, which correctly states
  ## that any RIS from the observed pooled effect is circular.
  path <- legacy_example_data()

  ## target_HR = NA => circular by construction, regardless of how much
  ## information accrued.
  res_circ <- suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = NA, verbose = FALSE)
  ))
  expect_true(res_circ$information_size$circularity_warning)

  ## A pre-specified target_HR is never circular, and never severe.
  res_spec <- suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE)
  ))
  expect_false(res_spec$information_size$circularity_warning)
  expect_false(res_spec$information_size$circularity_severe)

  ## Both flags always present, and severe implies warning (never the
  ## reverse) -- the two must not drift apart again.
  expect_true(is.logical(res_circ$information_size$circularity_severe))
  expect_length(res_circ$information_size$circularity_severe, 1L)
  if (isTRUE(res_circ$information_size$circularity_severe)) {
    expect_true(res_circ$information_size$circularity_warning)
  }
})

test_that("summary() reports circularity whenever target_HR is unspecified", {
  ## Companion to the test above, at the user-visible layer: the note
  ## must appear for ANY circular analysis, not only severe ones.
  path <- legacy_example_data()
  res <- suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = NA, verbose = FALSE)
  ))
  expect_output(summary(res), "circular")

  res_spec <- suppressMessages(suppressWarnings(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE)
  ))
  out <- capture.output(summary(res_spec))
  expect_false(any(grepl("circular", out, fixed = TRUE)))
})

test_that("non-numeric input columns are diagnosed as a type problem", {
  ## 0.2.6.8: is.finite() on a character column returns all-FALSE rather
  ## than erroring, so a column read in as text previously surfaced as
  ## "found NA/NaN/Inf" -- a misleading diagnosis of a type problem.
  path <- legacy_example_data()
  d <- as.data.frame(readxl::read_excel(path))
  ## The example sheet stores several headers with spaces ("Events
  ## Treatment"), which tsa_hr() normalises on load. Do the same here so
  ## these tests address columns by their post-normalisation names and
  ## don't silently target a NULL column.
  names(d) <- gsub(" ", "_", names(d))

  d_chr <- d
  d_chr$Events_Treatment <- as.character(d_chr$Events_Treatment)
  expect_error(tsa_hr(d_chr, target_HR = 0.80, verbose = FALSE),
               "must be numeric")

  d_se <- d
  d_se$Std_Error <- as.character(d_se$Std_Error)
  expect_error(tsa_hr(d_se, target_HR = 0.80, verbose = FALSE),
               "must be numeric")

  ## Genuinely numeric data must still pass this gate.
  expect_no_error(suppressMessages(suppressWarnings(
    tsa_hr(d, target_HR = 0.80, verbose = FALSE)
  )))
})
