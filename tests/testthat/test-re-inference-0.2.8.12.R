## 0.2.8.12: NA'd first-look Z on the plot, and the abbreviated summary
## table + its legend. 0.2.8.17: the HKSJ early-look caveat itself (below)
## is a warning(), not printed verbose output -- see test-tsa_hr.R for the
## style this matches (the target_HR-near-1 warning) and NEWS.md 0.2.8.17.

.fit <- function(...) {
  suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE, ...)))
}

test_that("HKSJ inference raises the early-look caveat as a warning(), like the target_HR-near-1 warning, regardless of verbose", {
  ## standard inference: no HKSJ caveat at all
  expect_warning(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE),
    NA
  )

  ## "hksj": warning fires with verbose = FALSE (not tied to printed output)
  expect_warning(
    res_h <- tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
                    re_inference = "hksj"),
    "HKSJ inference"
  )
  expect_s3_class(res_h, "tsa_hr")

  ## message content, checked the same way as the old boxed note's text
  w <- tryCatch({
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE, re_inference = "hksj")
    NULL
  }, warning = function(cond) conditionMessage(cond))
  expect_match(w, "k=1", fixed = TRUE)
  expect_match(w, "k=2", fixed = TRUE)
  expect_match(w, "not be interpreted as directly comparable", fixed = TRUE)

  ## also fires for the ad hoc variant
  expect_warning(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = FALSE,
           re_inference = "Hksj_adhoc"),
    "HKSJ inference"
  )

  ## verbose output no longer contains the old boxed note text
  out_h <- utils::capture.output(suppressWarnings(suppressMessages(
    tsa_hr(legacy_example_data(), target_HR = 0.80, verbose = TRUE, re_inference = "hksj"))))
  expect_false(any(grepl("HKSJ INFERENCE", out_h, fixed = TRUE)))
})

test_that("the first-look Z is NA'd out of the plotted Z-curve with no ggplot2 warning", {
  rh <- .fit(re_inference = "hksj")
  expect_true(is.na(rh$cumulative$Z[1]))
  expect_warning(p <- plot(rh), NA)   # no "Removed N rows" missing-value warning
  build <- ggplot2::ggplot_build(p)
  z_layer <- which(vapply(p$layers, function(l) inherits(l$geom, "GeomPoint"), logical(1)))
  expect_length(z_layer, 1L)
  pts <- build$data[[z_layer]]
  ## the point layer is built from z_curve_df, which excludes the NA row by
  ## construction (see plot.tsa_hr()), so this holds regardless of ggplot2
  ## version differences in how layers' own na.rm handling behaves
  expect_equal(nrow(pts), sum(!is.na(rh$cumulative$Z)))
  expect_equal(nrow(pts), nrow(rh$cumulative) - 1L)
  expect_true(all(!is.na(pts$y)))
})

test_that("summary_table$Parameter is abbreviated and carries an 'abbreviations' legend", {
  r <- .fit()
  st <- r$summary_table
  expect_true(all(nchar(st$Parameter) <= 55))
  abbr <- attr(st, "abbreviations")
  expect_true(is.character(abbr) && !is.null(names(abbr)) && length(abbr) > 0)
  expect_true(all(c("DARIS", "RE") %in% names(abbr)))

  out <- utils::capture.output(summary(r))
  i_legend <- grep("^Abbreviations:", out)
  expect_length(i_legend, 1L)
  expect_match(out[i_legend], "DARIS = ", fixed = TRUE)
})
