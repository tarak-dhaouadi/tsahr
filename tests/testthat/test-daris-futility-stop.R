## These replace an earlier version of this file that used
## readLines(file.path("R", "tsa_hr.R")) and regex-matched the literal
## source text -- that only worked when tests were run from the package's
## source root, and broke under a normal R CMD check (which runs tests
## against the INSTALLED package, where "R/tsa_hr.R" is not a valid
## relative path). A later revision replaced that with genuine behavioral
## tests, but used a dataset (3 studies of 1/sqrt(30) = 30 information
## units each) that does NOT actually reach DARIS under the default
## target_HR=0.80/power=0.80/alpha=0.05 (DARIS_info is ~157.6 there, but
## 3*30=90 information units never gets there) -- contradicting the
## tests' own "DARIS reached at look 2" premise. It also checked the
## final boundary value against tsahr:::.obf_alpha_boundary(1, ...), a
## SINGLE-look calculation (trivially qnorm(1-alpha/2)=1.960) rather than
## the actual multi-look recursive sequence the package computes
## (verified numerically to differ by ~0.03, far outside the test's
## stated 1e-8 tolerance). Both are fixed below: the dataset now
## genuinely reaches DARIS at the intended look (verified by direct
## computation before writing this file, not assumed), and the reference
## boundary is computed by calling the actual internal function on the
## SAME information-fraction vector the real code path constructs,
## rather than a shortcut that happens to be a different calculation.

test_that("retrospective boundary timeline terminates at the observed DARIS information point", {
  ## 3 studies, each contributing 100 inverse-variance information units
  ## (Std_Error = 0.1). With target_HR=0.80 (alpha=0.05, power=0.80
  ## defaults), DARIS_info ~= 157.6, so: look 1 (info=100) is below
  ## DARIS, look 2 (info=200) exceeds it, and look 3 is post-DARIS.
  over_info <- data.frame(
    Study = paste0("S", 1:3),
    log_HR = rep(log(0.8), 3),
    Std_Error = rep(0.1, 3),
    Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
    Events_controls = rep(50, 3), N_controls = rep(1000, 3)
  )

  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))

  expect_true(res$results$final_reached)
  expect_true("boundary_timeline" %in% names(res))
  expect_true(any(res$boundary_timeline$synthetic))
  expect_equal(tail(res$boundary_timeline$info_fraction, 1), 1)

  ## (0.2.7.11+: the reference is the compiled RTSA-derived alpha recursion,
  ## .rtsa_alpha_cpp(); the mention of .obf_alpha_boundary() in the header
  ## above is history.)
  ## Reference: call the ACTUAL boundary engine on the SAME
  ## information-fraction schedule the real code path uses for this
  ## dataset (every pre-DARIS look, plus the synthetic t=1 endpoint) --
  ## not a shortcut single-look calculation, which is a different,
  ## smaller quantity (a single look spends its entire alpha budget
  ## immediately, giving the trivial qnorm(1-alpha/2), not the true
  ## multi-look recursive boundary).
  pre_daris_fracs <- res$cumulative$info_fraction[res$cumulative$info_fraction < 1]
  expected_timing <- sort(unique(c(pre_daris_fracs, 1)))
  expected_bound <- tsahr:::.rtsa_alpha_cpp(expected_timing, side = 2L,
                                            alpha = 0.05)$alpha_ubound
  expect_equal(
    tail(res$boundary_timeline$TSA_boundary_upper, 1),
    tail(expected_bound, 1),
    tolerance = 1e-8
  )

  expect_equal(
    tail(res$boundary_timeline$cum_events, 1),
    res$information_size$DARIS_info_threshold_events,
    tolerance = 1e-8
  )
})

test_that("final futility boundary equals the final efficacy boundary (RTSA design pass)", {
  ## 0.2.7.12: reverses the 0.2.6.x-0.2.7.11 convention
  ## min(qnorm(1 - alpha/2), final efficacy).  As in RTSA's design pass, the
  ## futility and efficacy boundaries meet at t = 1.
  over_info <- data.frame(
    Study = paste0("S", 1:3),
    log_HR = rep(log(0.8), 3),
    Std_Error = rep(0.1, 3),
    Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
    Events_controls = rep(50, 3), N_controls = rep(1000, 3)
  )

  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))

  final_futility  <- tail(res$boundary_timeline$TSA_futility_upper, 1)
  final_efficacy  <- tail(res$boundary_timeline$TSA_boundary_upper, 1)

  expect_equal(final_futility, final_efficacy, tolerance = 1e-12)
  expect_equal(tail(res$boundary_timeline$TSA_futility_lower, 1),
               -final_efficacy, tolerance = 1e-12)
})

test_that("post-DARIS observed rows do not carry formal boundaries", {
  over_info <- data.frame(
    Study = paste0("S", 1:3),
    log_HR = rep(log(0.8), 3),
    Std_Error = rep(0.1, 3),
    Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
    Events_controls = rep(50, 3), N_controls = rep(1000, 3)
  )

  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))
  first_daris <- which(res$cumulative$info_fraction >= 1)[1]

  expect_equal(first_daris, 2)
  expect_lt(first_daris, nrow(res$cumulative))
  expect_true(all(is.na(
    res$cumulative$TSA_boundary_upper[first_daris:nrow(res$cumulative)]
  )))
  expect_true(all(is.na(
    res$cumulative$TSA_futility_upper[first_daris:nrow(res$cumulative)]
  )))
})

test_that("formal boundary endpoint uses observed DARIS information rather than theoretical DARIS events", {
  over_info <- data.frame(
    Study = paste0("S", 1:3),
    log_HR = rep(log(0.8), 3),
    Std_Error = rep(0.1, 3),
    Events_Treatment = rep(50, 3), N_treatment = rep(1000, 3),
    Events_controls = rep(50, 3), N_controls = rep(1000, 3)
  )

  res <- suppressWarnings(tsa_hr(over_info, target_HR = 0.80, verbose = FALSE))

  expect_true(res$results$final_reached)
  expect_true(is.finite(res$information_size$DARIS_info_threshold_events))
  expect_false(isTRUE(all.equal(
    res$information_size$DARIS_info_threshold_events,
    res$information_size$DARIS_events
  )))
  expect_equal(
    tail(res$boundary_timeline$cum_events, 1),
    res$information_size$DARIS_info_threshold_events,
    tolerance = 1e-8
  )
})
