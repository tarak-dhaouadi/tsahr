## 0.2.7.13 / 0.2.7.14: boundary_route, legacy_fallback, definitive-look
## decision fields, DARIS vs route endpoint, fallback bookkeeping, and the
## numerical-diagnostics warnings.

over_info <- data.frame(   # reaches DARIS at look 2 (target_HR = 0.80)
  Study = paste0("S", 1:3),
  log_HR = rep(log(0.8), 3),
  Std_Error = rep(0.1, 3),
  Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
  Events_controls  = rep(50, 3), N_controls  = rep(1000, 3)
)
under_info <- data.frame(  # never reaches DARIS (target_HR = 0.80)
  Study = paste0("S", 1:7),
  log_HR = rep(log(0.8), 7),
  Std_Error = rep(0.4, 7),
  Events_Treatment = rep(50, 7), N_treatment = rep(1000, 7),
  Events_controls  = rep(50, 7), N_controls  = rep(1000, 7)
)

test_that("boundary_route defaults to \"design\" and matches explicit \"design\"", {
  path <- tsahr_example_data()

  res_default <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  res_design  <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                          boundary_route = "design"))

  expect_equal(res_default$settings$boundary_route, "design")
  expect_equal(res_default$settings$route_endpoint, 1)
  expect_equal(res_default$boundary_timeline, res_design$boundary_timeline)
  expect_equal(res_default$results, res_design$results)

  ## 0.2.7.14: no fallback happened, and the object says so programmatically
  expect_false(res_default$settings$fallback_used)
  expect_identical(res_default$settings$fallback_route, "none")
  expect_true(is.na(res_default$settings$fallback_reason))
  expect_identical(res_default$settings$route_used, "design")
})

test_that("boundary_route = \"analysis\" moves the endpoint to design_R and changes the timeline", {
  path <- tsahr_example_data()

  res_design   <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                           boundary_route = "design"))
  res_analysis <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                           boundary_route = "analysis"))

  expect_equal(res_analysis$settings$boundary_route, "analysis")
  expect_identical(res_analysis$settings$route_used, "analysis")
  expect_false(res_analysis$settings$fallback_used)
  expect_true(is.finite(res_analysis$settings$route_endpoint))
  expect_true(res_analysis$settings$route_endpoint > 0)
  expect_false(isTRUE(all.equal(res_analysis$settings$route_endpoint, 1)))

  synth <- res_analysis$boundary_timeline[res_analysis$boundary_timeline$synthetic, ]
  expect_equal(nrow(synth), 1L)
  expect_equal(synth$info_fraction, res_analysis$settings$route_endpoint)

  expect_false(isTRUE(all.equal(res_design$boundary_timeline,
                                res_analysis$boundary_timeline)))
})

test_that("0.2.7.14: DARIS and the analysis-route endpoint are reported separately", {
  path <- tsahr_example_data()
  res_d <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))
  res_a <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                    boundary_route = "analysis"))

  ## DARIS itself (t = 1) does not depend on the route ...
  expect_equal(res_a$information_size$DARIS_info_threshold_events,
               res_d$information_size$DARIS_info_threshold_events)
  expect_identical(res_a$results$daris_reached, res_d$results$daris_reached)
  ## ... whereas the route endpoint is design_R x DARIS
  R <- res_a$settings$route_endpoint
  expect_equal(res_a$information_size$route_endpoint_info,
               R * res_a$information_size$DARIS_info)
  expect_equal(res_a$settings$route_endpoint_info,
               res_a$information_size$route_endpoint_info)
  ## design route: the two coincide
  expect_equal(res_d$information_size$route_endpoint_events,
               res_d$information_size$DARIS_info_threshold_events)
  expect_equal(res_d$information_size$route_endpoint_info,
               res_d$information_size$DARIS_info)

  ## reaching the (larger) analysis endpoint implies having reached DARIS
  if (isTRUE(res_a$results$final_reached) && R > 1) {
    expect_true(res_a$results$daris_reached)
    expect_gte(res_a$information_size$route_endpoint_events,
               res_a$information_size$DARIS_info_threshold_events)
  }

  ## labelling: the summary table names the endpoint only for the analysis
  ## route; the design route keeps the DARIS-only table
  expect_true(any(grepl("analysis-route endpoint", res_a$summary_table$Parameter,
                        fixed = TRUE)))
  expect_false(any(grepl("analysis-route endpoint", res_d$summary_table$Parameter,
                         fixed = TRUE)))

  ## printed output: the analysis route never calls its endpoint "DARIS"
  out_a <- capture.output(suppressMessages(
    tsa_hr(path, target_HR = 0.80, verbose = TRUE, boundary_route = "analysis")))
  expect_true(any(grepl("analysis-route endpoint", out_a, fixed = TRUE)))
  expect_false(any(grepl("Formal final boundary endpoint (DARIS information reached)",
                         out_a, fixed = TRUE)))
  out_d <- capture.output(suppressMessages(
    tsa_hr(path, target_HR = 0.80, verbose = TRUE)))
  expect_true(any(grepl("Formal final boundary endpoint (DARIS information reached)",
                        out_d, fixed = TRUE)))
  expect_false(any(grepl("analysis-route endpoint", out_d, fixed = TRUE)))

  expect_output(print(res_a), "Analysis-route endpoint")
  expect_no_error(suppressMessages(plot(res_a)))
  expect_no_error(suppressMessages(plot(res_d)))
})

test_that(".tsahr_definitive_look() reports the DEFINITIVE look only, not \"any look\"", {
  ## The audit example: efficacy crossed at an interim look, then the
  ## definitive look falls back below its boundary.
  z <- c(2.0, 3.5, 1.5)
  b <- c(2.5, 3.0, 2.0)          # efficacy boundary at each look
  f <- c(0.5, 1.0, 2.0)          # futility boundary (= efficacy at the last look)
  expect_true(any(abs(z) >= b))  # crossed_tsa-style "any look" is TRUE ...
  d <- tsahr:::.tsahr_definitive_look(z, TRUE, 3L, b, f)
  expect_false(d$final_crossed_efficacy)   # ... but the definitive look did not cross
  expect_true(d$final_non_efficacy)        # (0.2.7.13's !crossed_tsa said FALSE here)
  expect_true(d$final_entered_futility_region)

  ## crossing AT the definitive look
  d2 <- tsahr:::.tsahr_definitive_look(c(1, 2, 2.4), TRUE, 3L, b, f)
  expect_true(d2$final_crossed_efficacy)
  expect_false(d2$final_non_efficacy)
  expect_false(d2$final_entered_futility_region)

  ## negative Z is handled through |Z|
  d3 <- tsahr:::.tsahr_definitive_look(c(-1, -2, -2.4), TRUE, 3L, b, f)
  expect_true(d3$final_crossed_efficacy)

  ## endpoint not reached -> there is no definitive look: all NA
  d4 <- tsahr:::.tsahr_definitive_look(z, FALSE, 3L, b, f)
  expect_true(is.na(d4$final_crossed_efficacy))
  expect_true(is.na(d4$final_non_efficacy))
  expect_true(is.na(d4$final_entered_futility_region))

  ## a missing boundary at the definitive look -> NA, never a silent FALSE
  d5 <- tsahr:::.tsahr_definitive_look(z, TRUE, 3L, c(2.5, 3.0, NA), f)
  expect_true(is.na(d5$final_crossed_efficacy))
  expect_true(is.na(d5$final_non_efficacy))
})

test_that("tsa_hr() definitive-look fields: reached, crossing, non-crossing, not reached", {
  ## reached, efficacy crossed at the definitive look
  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))
  r <- res$results
  expect_true(r$final_reached)
  expect_true(r$daris_reached)
  expect_true(is.logical(r$final_crossed_efficacy))
  expect_identical(r$final_non_efficacy, !r$final_crossed_efficacy)
  expect_identical(r$final_entered_futility_region, !r$final_crossed_efficacy)
  expect_equal(r$final_crossed_efficacy,
               abs(res$cumulative$Z[r$final_tsa_look]) >=
                 utils::tail(res$boundary_timeline$TSA_boundary_upper, 1))
  expect_true(r$final_crossed_efficacy)     # |Z| ~ 3.2 at look 2
  expect_false(r$final_non_efficacy)

  ## reached, NOT crossed at the definitive look (weak effect)
  weak <- over_info
  weak$log_HR <- rep(log(0.9), 3)
  res_w <- suppressWarnings(tsa_hr(weak, target_HR = 0.80, verbose = FALSE))
  expect_true(res_w$results$final_reached)
  expect_false(res_w$results$final_crossed_efficacy)
  expect_true(res_w$results$final_non_efficacy)
  expect_true(res_w$results$final_entered_futility_region)

  ## DARIS not reached -> no definitive look -> NA
  res_u <- suppressWarnings(tsa_hr(under_info, target_HR = 0.80, verbose = FALSE))
  expect_false(res_u$results$final_reached)
  expect_true(is.na(res_u$results$final_crossed_efficacy))
  expect_true(is.na(res_u$results$final_non_efficacy))
  expect_true(is.na(res_u$results$final_entered_futility_region))

  expect_true(any(grepl("did not cross efficacy", res$summary_table$Parameter,
                        fixed = TRUE)))
  expect_true(any(grepl("Definitive look crossed efficacy", res$summary_table$Parameter,
                        fixed = TRUE)))
})

test_that("legacy_fallback is validated and the default path returns a normal result", {
  path <- tsahr_example_data()
  expect_error(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                       legacy_fallback = NA),
               "legacy_fallback must be a single TRUE or FALSE")
  expect_error(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                       legacy_fallback = c(TRUE, FALSE)),
               "legacy_fallback must be a single TRUE or FALSE")

  res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                  legacy_fallback = FALSE))
  expect_s3_class(res, "tsa_hr")
  expect_false(res$settings$used_legacy_engine)
  expect_equal(res$settings$legacy_fallback, FALSE)
})

test_that("design-route failure: legacy fallback is flagged; legacy_fallback = FALSE errors", {
  skip_if_not_installed("testthat", "3.2.0")
  testthat::local_mocked_bindings(
    .rtsa_design_bounds = function(...) stop("simulated design failure"),
    .package = "tsahr"
  )
  path <- tsahr_example_data()

  expect_warning(
    res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE)),
    "LEGACY, APPROXIMATE"
  )
  expect_true(res$settings$fallback_used)
  expect_identical(res$settings$fallback_route, "legacy")
  expect_identical(res$settings$route_used, "legacy")
  expect_match(res$settings$fallback_reason, "simulated design failure")
  expect_true(res$settings$used_legacy_engine)
  expect_identical(res$beta_engine$engine, "legacy_r_fallback")
  expect_output(print(res), "LEGACY, APPROXIMATE")

  ## a request for the analysis route cannot be honoured either -> legacy
  expect_warning(
    res_a <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                      boundary_route = "analysis")),
    "LEGACY, APPROXIMATE"
  )
  expect_identical(res_a$settings$boundary_route, "analysis")
  expect_identical(res_a$settings$fallback_route, "legacy")
  expect_identical(res_a$settings$route_used, "legacy")
  expect_equal(res_a$settings$route_endpoint, 1)

  expect_error(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE, legacy_fallback = FALSE),
    "legacy_fallback = FALSE"
  )
})

test_that("analysis-route failure: falls back to the DESIGN route (flagged); FALSE errors", {
  skip_if_not_installed("testthat", "3.2.0")
  path <- tsahr_example_data()
  res_design <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE))

  testthat::local_mocked_bindings(
    .rtsa_analysis_bounds = function(...) stop("simulated analysis failure"),
    .package = "tsahr"
  )
  expect_warning(
    res <- suppressMessages(tsa_hr(path, target_HR = 0.80, verbose = FALSE,
                                    boundary_route = "analysis")),
    "ANALYSIS-ROUTE ENGINE FAILED"
  )
  expect_identical(res$settings$boundary_route, "analysis")     # what was asked
  expect_identical(res$settings$route_used, "design")           # what was delivered
  expect_true(res$settings$fallback_used)
  expect_identical(res$settings$fallback_route, "design")
  expect_match(res$settings$fallback_reason, "simulated analysis failure")
  expect_false(res$settings$used_legacy_engine)                 # still RTSA-derived
  expect_equal(res$settings$route_endpoint, 1)
  expect_equal(res$boundary_timeline, res_design$boundary_timeline)
  ## the endpoint is labelled DARIS again, since that is what it now is
  expect_false(any(grepl("analysis-route endpoint", res$summary_table$Parameter,
                         fixed = TRUE)))
  expect_output(print(res), "DESIGN-route")

  expect_error(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE, boundary_route = "analysis",
           legacy_fallback = FALSE),
    "legacy_fallback = FALSE"
  )
})

test_that("boundary_route rejects invalid values", {
  path <- tsahr_example_data()
  expect_error(
    tsa_hr(path, target_HR = 0.80, verbose = FALSE, boundary_route = "bogus"),
    "should be one of"
  )
})

test_that("0.2.7.14: reversed-grid warning is separate from, and louder than, the collapse warning", {
  expect_no_warning(tsahr:::.rtsa_warn_diagnostics(
    list(grid_collapses = 0L, grid_reversed = 0L, slow_searches = 0L), "x"))

  msg_rev <- tryCatch(
    tsahr:::.rtsa_warn_diagnostics(list(grid_reversed = 2L), "the test boundary"),
    warning = function(w) conditionMessage(w))
  expect_match(msg_rev, "REVERSED")
  ## the reversed interval is widened to a minimal NON-ZERO window (not a
  ## "degenerate window"): the wording must match what the C++ does
  expect_match(msg_rev, "minimal non-zero window", fixed = TRUE)
  expect_false(grepl("degenerate window", msg_rev, fixed = TRUE))
  expect_match(msg_rev, "NOT a valid RTSA computation", fixed = TRUE)
  expect_match(msg_rev, "the test boundary", fixed = TRUE)

  msg_col <- tryCatch(
    tsahr:::.rtsa_warn_diagnostics(list(grid_collapses = 1L), "the test boundary"),
    warning = function(w) conditionMessage(w))
  expect_match(msg_col, "degenerate")
  expect_match(msg_col, "positive width", fixed = TRUE)
  expect_false(grepl("REVERSED", msg_col, fixed = TRUE))

  ## an ordinary compiled run reports none of the three counters
  ab <- suppressWarnings(tsahr:::.rtsa_alpha_cpp(c(0.2, 0.4, 0.6, 0.8, 1),
                                                 side = 2L, alpha = 0.05))
  expect_identical(ab$grid_reversed, 0L)
  expect_identical(ab$grid_collapses, 0L)
  expect_identical(ab$slow_searches, 0L)
})

test_that("0.2.7.14: warn = FALSE silences root-search candidates only", {
  skip_if_not_installed("testthat", "3.2.0")
  testthat::local_mocked_bindings(
    rtsa_beta_boundary_cpp = function(...) {
      list(za = c(0, 1), grid_reversed = 3L, grid_collapses = 0L,
           slow_searches = 0L)
    },
    .package = "tsahr"
  )
  expect_warning(
    tsahr:::.rtsa_beta_cpp(c(0.5, 1), c(2, 2), 0.2, 2.8),
    "REVERSED"
  )
  expect_no_warning(
    tsahr:::.rtsa_beta_cpp(c(0.5, 1), c(2, 2), 0.2, 2.8, warn = FALSE)
  )
})
