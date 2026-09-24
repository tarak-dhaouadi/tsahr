## 0.2.8: (1) the pooled-statistics line in the plot subtitle, (2) position and
## size arguments for the "Analysis-route endpoint" label, (3) the two bundled
## example datasets that replaced HR_meta_example.xlsx.
##
## Numerical values are deliberately NOT pinned for the new example datasets
## (the older tests pin their numbers on the frozen legacy dataset, see
## helper-data.R); these tests check structure, and check the plot text against
## the numbers stored in the fitted object.

## ---------------------------------------------------------------------------
## (3) Bundled example datasets
## ---------------------------------------------------------------------------

test_that("tsahr_example_data() returns the two bundled datasets", {
  p1 <- tsahr_example_data()
  p1_explicit <- tsahr_example_data("HR_meta")
  p2 <- tsahr_example_data("HR_meta_2")

  expect_identical(p1, p1_explicit)          # HR_meta is the default
  expect_true(nzchar(p1) && file.exists(p1))
  expect_true(nzchar(p2) && file.exists(p2))
  expect_identical(basename(p1), "HR_meta.xlsx")
  expect_identical(basename(p2), "HR_meta_2.xlsx")

  expect_error(tsahr_example_data("HR_meta_example"))   # the pre-0.2.8 name
})

test_that("the bundled datasets have the expected shape and required columns", {
  required <- c("Study", "log_HR", "Std_Error", "Events_Treatment",
                "N_treatment", "Events_controls", "N_controls")

  d1 <- as.data.frame(readxl::read_excel(tsahr_example_data("HR_meta")))
  d2 <- as.data.frame(readxl::read_excel(tsahr_example_data("HR_meta_2")))

  expect_equal(nrow(d1), 20L)
  expect_equal(nrow(d2), 40L)
  ## the headers already use underscores (tsa_hr() would normalise spaces anyway)
  expect_true(all(required %in% names(d1)))
  expect_true(all(required %in% names(d2)))
  expect_false(anyDuplicated(d1$Study) > 0)
  expect_false(anyDuplicated(d2$Study) > 0)
  ## log_HR / Std_Error are consistent with the reported HR and 95% CI
  for (d in list(d1, d2)) {
    expect_equal(d$log_HR, log(d$HR), tolerance = 1e-8)
    expect_equal(d$Std_Error, (log(d$upper) - log(d$lower)) / (2 * stats::qnorm(0.975)),
                 tolerance = 1e-2)
  }
})

test_that("tsa_hr() runs on both bundled datasets and plot() works", {
  for (which_data in c("HR_meta", "HR_meta_2")) {
    path <- tsahr_example_data(which_data)
    res <- suppressWarnings(suppressMessages(
      tsa_hr(path, target_HR = 0.80, verbose = FALSE)))
    expect_s3_class(res, "tsa_hr")
    expect_equal(nrow(res$cumulative), nrow(res$data))
    expect_true(is.finite(res$information_size$DARIS_events))
    expect_no_error(suppressMessages(p <- plot(res)))
    expect_s3_class(p, "ggplot")
  }
})

## ---------------------------------------------------------------------------
## (1) Pooled-statistics line in the subtitle
## ---------------------------------------------------------------------------

test_that(".tsahr_pooled_subtitle() reports HR [95% CI], p, Tau2 and I2 from the fit", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE)))
  out <- tsahr:::.tsahr_pooled_subtitle(res)

  expect_length(out, 1L)
  ## superscript two (U+00B2) after Tau and I, not a plain "2"
  expect_match(out, "Tau\u00b2 = ", fixed = TRUE)
  expect_match(out, "I\u00b2 = ", fixed = TRUE)
  expect_false(grepl("Tau2|I2", out))

  expected <- sprintf(
    "Pooled HR = %.2f [95%% CI: %.2f, %.2f]",
    exp(as.numeric(res$res_re$b)), exp(res$res_re$ci.lb), exp(res$res_re$ci.ub))
  expect_true(startsWith(out, expected))
  expect_match(out, sprintf("Tau\u00b2 = %.4f", res$heterogeneity$tau2), fixed = TRUE)
  expect_match(out, sprintf("I\u00b2 = %.1f%%", res$heterogeneity$I2), fixed = TRUE)
  ## a p-value is always present, in one of the two formats
  expect_true(grepl("\\| p (<|=) [0-9.]+ \\|", out))
})

test_that(".tsahr_pooled_subtitle() formats the p-value and tolerates missing pieces", {
  fake <- function(p) list(
    res_re = list(b = matrix(log(0.5)), ci.lb = log(0.4), ci.ub = log(0.6), pval = p),
    heterogeneity = list(tau2 = 0.0123, I2 = 45.67))

  expect_match(tsahr:::.tsahr_pooled_subtitle(fake(0.0004)), "| p < 0.001 |", fixed = TRUE)
  expect_match(tsahr:::.tsahr_pooled_subtitle(fake(0.0234)), "| p = 0.023 |", fixed = TRUE)
  expect_match(tsahr:::.tsahr_pooled_subtitle(fake(0.0234)),
               "Pooled HR = 0.50 [95% CI: 0.40, 0.60]", fixed = TRUE)
  expect_match(tsahr:::.tsahr_pooled_subtitle(fake(0.0234)), "Tau\u00b2 = 0.0123", fixed = TRUE)
  expect_match(tsahr:::.tsahr_pooled_subtitle(fake(0.0234)), "I\u00b2 = 45.7%", fixed = TRUE)

  ## an object lacking the fields must not error
  out <- tsahr:::.tsahr_pooled_subtitle(list())
  expect_match(out, "Pooled HR = NA [95% CI: NA, NA] | p = NA", fixed = TRUE)
})

test_that("plot() puts the pooled line directly under the first subtitle line", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE)))
  p <- suppressMessages(plot(res))
  sub <- p$labels$subtitle
  skip_if(is.null(sub), "this ggplot2 build does not expose $labels$subtitle")

  lines <- strsplit(sub, "\n", fixed = TRUE)[[1]]
  expect_length(lines, 2L)
  expect_true(startsWith(lines[1], "Random-effects model | Diversity D\u00b2 = "))
  expect_identical(lines[2], tsahr:::.tsahr_pooled_subtitle(res))
})

## ---------------------------------------------------------------------------
## (2) Position / size of the "Analysis-route endpoint ... reached" label
## ---------------------------------------------------------------------------

## The layer drawing the endpoint label (an annotate("text") layer), or NULL.
.endpoint_layer <- function(p) {
  for (l in p$layers) {
    lab <- l$aes_params$label
    if (is.character(lab) && length(lab) == 1L &&
        grepl("^Analysis-route endpoint", lab)) return(l)
  }
  NULL
}

test_that("endpoint_label_x / _y / _size position and size the endpoint label", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
           boundary_route = "analysis")))
  skip_if_not(identical(res$settings$route_used, "analysis"),
              "analysis route fell back to the design route")

  ## The label is only drawn when the analysis-route endpoint was reached.
  ## Force that state (drawing only; no analysis is re-run) so the label
  ## exists whatever this dataset does.
  res$results$final_reached <- TRUE
  res$information_size$route_endpoint_events <- 0.9 * max(res$cumulative$cum_events)

  ## defaults: unchanged from before 0.2.8
  p0 <- suppressMessages(plot(res))
  l0 <- .endpoint_layer(p0)
  skip_if(is.null(l0), "could not locate the endpoint label layer in this ggplot2 build")
  expect_equal(l0$data$x, res$information_size$route_endpoint_events)
  expect_true(is.finite(l0$data$y))
  expect_equal(l0$aes_params$size, 3.2)            # follows info_threshold_label_size

  ## the old coupling is kept: endpoint size follows info_threshold_label_size
  p1 <- suppressMessages(plot(res, info_threshold_label_size = 5))
  expect_equal(.endpoint_layer(p1)$aes_params$size, 5)

  ## the new arguments override position and size
  p2 <- suppressMessages(plot(res, endpoint_label_x = 1234, endpoint_label_y = -7,
                              endpoint_label_size = 6, info_threshold_label_size = 5))
  l2 <- .endpoint_layer(p2)
  expect_equal(l2$data$x, 1234)
  expect_equal(l2$data$y, -7)
  expect_equal(l2$aes_params$size, 6)

  ## x and y can be set independently
  p3 <- suppressMessages(plot(res, endpoint_label_y = 3))
  l3 <- .endpoint_layer(p3)
  expect_equal(l3$data$x, l0$data$x)
  expect_equal(l3$data$y, 3)
})

## ---------------------------------------------------------------------------
## (3) 0.2.8.3: analysis-route endpoint marker when the endpoint is NOT reached
## ---------------------------------------------------------------------------

test_that("analysis route: endpoint vertical + label are drawn even when not reached (design_R > 1)", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
           boundary_route = "analysis")))
  skip_if_not(identical(res$settings$route_used, "analysis"),
              "analysis route fell back to the design route")

  ## Force the "beyond DARIS, not reached" state (drawing only).
  res$results$final_reached <- FALSE
  res$settings$route_endpoint <- 1.25
  expected_x <- res$information_size$DARIS_events * 1.25

  p <- suppressMessages(plot(res))
  l <- .endpoint_layer(p)
  skip_if(is.null(l), "could not locate the endpoint label layer in this ggplot2 build")
  expect_equal(l$data$x, expected_x)
  expect_match(l$aes_params$label, "not yet reached; theoretical", fixed = TRUE)

  ## a vertical line at the same x exists
  vx <- vapply(p$layers, function(ly) {
    v <- ly$data$xintercept; if (is.null(v)) NA_real_ else as.numeric(v)[1]
  }, numeric(1))
  ## (geom_vline stores xintercept in aes_params)
  vx2 <- vapply(p$layers, function(ly) {
    v <- ly$geom_params$xintercept; if (is.null(v)) NA_real_ else as.numeric(v)[1]
  }, numeric(1))
  expect_true(any(abs(c(vx, vx2) - expected_x) < 1e-8, na.rm = TRUE))

  ## design route: unchanged, no endpoint label
  res_d <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
           boundary_route = "design")))
  expect_null(.endpoint_layer(suppressMessages(plot(res_d))))
})

test_that("plot(): xmax_mult scales the x-axis upper limit and is validated", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE)))
  xl <- function(m) suppressMessages(plot(res, xmax_mult = m))$coordinates$limits$x[2]
  p_def <- suppressMessages(plot(res))$coordinates$limits$x[2]
  expect_equal(xl(1.15), p_def)
  expect_equal(xl(2) / xl(1.15), 2 / 1.15)
  expect_error(plot(res, xmax_mult = 0), "xmax_mult")
  expect_error(plot(res, xmax_mult = c(1, 2)), "xmax_mult")
  expect_error(plot(res, xmax_mult = "a"), "xmax_mult")
})

test_that("analysis route: historical-rate line and caption lines (forced not-reached state)", {
  res <- suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
           boundary_route = "analysis")))
  skip_if_not(identical(res$settings$route_used, "analysis"),
              "analysis route fell back to the design route")

  ## Force the "endpoint not reached, projection available" state (drawing only).
  res$results$final_reached <- FALSE
  res$projection$additional_events_theoretical <- 500
  res$projection$additional_events_estimated   <- 2500
  res$projection$n_additional_studies          <- 4L
  res$projection$target_events_historical_rate <- res$results$events_accrued + 2500
  res$projection$n_excluded_events_projection  <- 0L
  res$projection$n_zero_event_studies          <- 0L

  p <- suppressMessages(plot(res))
  labs <- vapply(p$layers, function(ly) {
    l <- ly$aes_params$label
    if (is.null(l)) NA_character_ else as.character(l)[1]
  }, character(1))
  skip_if(all(is.na(labs)), "could not read annotation labels in this ggplot2 build")
  i <- grep("^Historical information/event-rate projection", labs)
  expect_length(i, 1L)
  expect_equal(p$layers[[i]]$data$x, res$results$events_accrued + 2500)

  labs_off <- vapply(suppressMessages(plot(res, show_historical_daris = FALSE))$layers,
                     function(ly) { l <- ly$aes_params$label
                       if (is.null(l)) NA_character_ else as.character(l)[1] },
                     character(1))
  expect_length(grep("Historical information/event-rate projection", labs_off, fixed = TRUE), 0L)
  ## the theoretical endpoint keeps the "Analysis-route endpoint" name; the
  ## projection line is not called an endpoint
  expect_false(any(grepl("^Analysis-route endpoint.*historical", labs)))

  cap <- tryCatch(ggplot2::get_labs(p)$caption, error = function(e) p$labels$caption)
  skip_if(is.null(cap), "could not read the caption in this ggplot2 build")
  expect_match(cap, "Theoretical additional events to analysis-route endpoint (Schoenfeld): 500",
               fixed = TRUE)
  expect_match(cap, "Estimated additional events to analysis-route endpoint (historical rate): ~2,500",
               fixed = TRUE)
  expect_match(cap, "Estimated additional studies required: 4", fixed = TRUE)
})
