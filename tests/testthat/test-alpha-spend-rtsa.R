## Regression test for the alpha-spending formula correction: verifies
## the two-sided (side = 2) O'Brien-Fleming-type spending function
## against a concrete, exact, approximation-free comparison point.
##
## The FIRST look of any group-sequential design has no prior boundary
## to condition on, so its boundary is an exact closed-form function of
## the spending function value at that look -- c_1 = qnorm(1 - A(t_1)/2)
## -- with no recursive-integration approximation involved. This makes
## it a clean, engine-independent check of the spending FORMULA itself
## (as opposed to the recursive engine's numerics), which is exactly
## what needed checking here.
##
## Reference value is live output from RTSA::boundaries() (Copenhagen
## Trial Unit's R package -- the reference TSA implementation this
## package models itself on):
##   RTSA::boundaries(timing = c(0.2,0.4,0.6,0.8,1), alpha = 0.05,
##                     side = 2, es_alpha = "esOF")
## reported a first-look upper boundary of 4.877 at an (internally
## event-count-rounded) timing of t = 0.205.

test_that("alpha-spending formula matches RTSA::boundaries() at the first look", {
  t1 <- 0.205
  alpha <- 0.05

  A1 <- tsahr:::.alpha_spend_OF(t1, alpha)
  c1 <- stats::qnorm(1 - A1 / 2)

  rtsa_reported <- 4.877

  ## Loose-ish tolerance: RTSA's reported timing (0.205) is itself
  ## rounded from an underlying integer event count, so an exact bit-for-
  ## bit match isn't expected -- but the corrected formula should land
  ## within a few hundredths, not the ~0.5 discrepancy the pre-correction
  ## formula had.
  expect_equal(c1, rtsa_reported, tolerance = 0.1)
})

test_that("alpha-spending formula reaches exactly alpha at t = 1", {
  alpha <- 0.05
  expect_equal(tsahr:::.alpha_spend_OF(1, alpha), alpha, tolerance = 1e-12)
})

test_that("alpha-spending formula is the side=2 (two-sided) OF-type form", {
  t <- c(0.1, 0.3, 0.5, 0.7, 1)
  alpha <- 0.05
  got <- tsahr:::.alpha_spend_OF(t, alpha)
  expected <- 4 * stats::pnorm(
    stats::qnorm(1 - alpha / 4) / sqrt(t),
    lower.tail = FALSE
  )
  expect_equal(got, expected, tolerance = 1e-14)
})
