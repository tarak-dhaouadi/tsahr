## 0.2.8.11: re_inference = "standard" / "hksj" (= "knha") / "Hksj_adhoc".

.fit <- function(...) {
  suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE, ...)))
}

test_that("default is 'standard' and identical to asking for it explicitly", {
  r0 <- .fit()
  r1 <- .fit(re_inference = "standard")
  expect_identical(r0$parameters$re_inference, "standard")
  expect_identical(r1$parameters$re_inference, "standard")
  expect_equal(r0$cumulative, r1$cumulative)
  expect_equal(r0$cumulative$Z, r0$cumulative$estimate / r0$cumulative$se)
  ## the default output carries no extra columns/rows
  expect_false(any(c("re_scale", "re_df") %in% names(r0$cumulative)))
  expect_false(any(grepl("Random-effects inference", r0$summary_table$Parameter)))
})

test_that("re_inference is validated, case-insensitive and aliased", {
  path <- legacy_example_data()
  expect_error(tsa_hr(path, target_HR = 0.8, verbose = FALSE, re_inference = "bogus"),
               "re_inference must be one of")
  expect_error(tsa_hr(path, target_HR = 0.8, verbose = FALSE,
                      re_inference = c("standard", "hksj")),
               "re_inference must be one of")
  expect_error(tsa_hr(path, target_HR = 0.8, verbose = FALSE, re_inference = NA_character_),
               "re_inference must be one of")
  expect_identical(.fit(re_inference = "KNHA")$parameters$re_inference, "hksj")
  expect_identical(.fit(re_inference = "hksj")$parameters$re_inference, "hksj")
  r <- .fit(re_inference = "Hksj_adhoc")
  expect_identical(r$parameters$re_inference, "hksj_adhoc")
  expect_identical(r$parameters$re_inference_requested, "Hksj_adhoc")
  expect_identical(.fit(re_inference = "knha_adhoc")$parameters$re_inference, "hksj_adhoc")
})

test_that("hksj changes only the inference, not the design or boundaries", {
  rs <- .fit()
  rh <- .fit(re_inference = "hksj")
  expect_identical(rh$res_re$test, "knha")
  ## point estimate, tau2, I2, D2, DARIS and boundaries are untouched
  expect_equal(as.numeric(rh$res_re$b), as.numeric(rs$res_re$b))
  expect_equal(rh$heterogeneity, rs$heterogeneity)
  expect_equal(rh$information_size$DARIS_info, rs$information_size$DARIS_info)
  expect_equal(rh$boundary_timeline, rs$boundary_timeline)
  expect_equal(rh$cumulative$estimate, rs$cumulative$estimate)
  expect_equal(rh$cumulative$tau2, rs$cumulative$tau2)
  ## pooled p-value / CI are the t-based ones
  k <- nrow(rh$data)
  tt <- as.numeric(rh$res_re$b) / rh$res_re$se
  expect_equal(rh$res_re$pval, 2 * pt(-abs(tt), df = k - 1))
  expect_equal(rh$res_re$ci.ub,
               as.numeric(rh$res_re$b) + qt(0.975, k - 1) * rh$res_re$se)
})

test_that("cumulative HKSJ table is consistent with the fitted model", {
  rh <- .fit(re_inference = "hksj")
  cu <- rh$cumulative
  k  <- nrow(cu)
  ## last look == pooled model
  expect_equal(cu$se[k],    rh$res_re$se)
  expect_equal(cu$pval[k],  rh$res_re$pval)
  expect_equal(cu$ci.lb[k], rh$res_re$ci.lb)
  expect_equal(cu$ci.ub[k], rh$res_re$ci.ub)
  expect_equal(cu$re_df, c(Inf, seq_len(k - 1)))
  ## first look has only one study: HKSJ is undefined at k = 1, so Z is NA
  ## (0.2.8.12), even though se/pval/ci at that look keep the z-based values
  expect_true(is.na(cu$Z[1]))
  expect_false(is.na(cu$se[1]))
  expect_equal(cu$pval[1], 2 * pnorm(-abs(cu$estimate[1] / cu$se[1])))
  ## Z is the normal-equivalent of the t p-value, sign of the estimate
  expect_equal(abs(cu$Z[-1]), qnorm(cu$pval[-1] / 2, lower.tail = FALSE), tolerance = 1e-6)
  expect_equal(sign(cu$Z[-1]), sign(cu$estimate[-1]))
  ## |Z| >= z_alpha exactly when the HKSJ p-value is < alpha
  expect_identical(abs(cu$Z[-1]) >= qnorm(0.975), cu$pval[-1] <= 0.05)
})

test_that("ad hoc variant never has a smaller SE than standard, nor than HKSJ", {
  rs <- .fit()
  rh <- .fit(re_inference = "hksj")
  ra <- .fit(re_inference = "Hksj_adhoc")
  expect_true(ra$res_re$test %in% c("knha", "t"))
  expect_true(all(ra$cumulative$re_scale >= 1))
  expect_true(all(ra$cumulative$se >= rs$cumulative$se - 1e-12))
  expect_true(all(ra$cumulative$se >= rh$cumulative$se - 1e-12))
  expect_gte(ra$res_re$se, rs$res_re$se - 1e-12)
  ## where q >= 1 the ad hoc and plain HKSJ results coincide
  same <- rh$cumulative$re_scale >= 1
  expect_equal(ra$cumulative$se[same], rh$cumulative$se[same])
})

test_that("caption, print and summary name a non-standard inference option", {
  cap <- function(res) {
    p <- suppressMessages(plot(res))
    tryCatch(ggplot2::get_labs(p)$caption, error = function(e) p$labels$caption)
  }
  c_std <- cap(.fit())
  c_h   <- cap(.fit(re_inference = "hksj"))
  c_a   <- cap(.fit(re_inference = "Hksj_adhoc"))
  skip_if(is.null(c_std) || is.null(c_h), "could not read the caption in this ggplot2 build")
  expect_false(grepl("Random-effects inference", c_std, fixed = TRUE))
  expect_true(grepl("Random-effects inference: HKSJ", c_h, fixed = TRUE))
  expect_true(grepl("ad hoc", c_a, fixed = TRUE))
  ## the inference line sits directly under the first "Methods" line
  lines_h <- strsplit(c_h, "\n", fixed = TRUE)[[1]]
  expect_match(lines_h[1], "^Methods: Random-effects")
  expect_match(lines_h[2], "^Random-effects inference")

  rh <- .fit(re_inference = "hksj")
  expect_output(print(rh), "Random-effects inference: Hartung-Knapp")
  expect_true("Random-effects inference" %in% rh$summary_table$Parameter)
  expect_equal(rh$summary_table$Parameter[4], "Random-effects inference")
})

test_that("degenerate data fall back to standard inference with a warning", {
  n <- 10L   # >= 10 studies, so the few-studies warning does not fire
  d <- data.frame(
    Study = paste0("S", seq_len(n)), log_HR = rep(log(0.8), n),
    Std_Error = seq(0.20, 0.38, length.out = n),
    Events_Treatment = seq(30, 66, length.out = n), N_treatment = rep(150, n),
    Events_controls = seq(35, 71, length.out = n), N_controls = rep(150, n))
  expect_warning(
    r <- suppressMessages(tsa_hr(d, target_HR = 0.8, verbose = FALSE,
                                 re_inference = "hksj")),
    "falling back to re_inference")
  expect_identical(r$parameters$re_inference, "standard")
  expect_identical(r$parameters$re_inference_requested, "hksj")
})
