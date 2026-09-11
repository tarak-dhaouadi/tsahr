test_that("RTSA beta spending formula is used", {
  t <- c(0.1, 0.25, 0.5, 0.75, 1)
  beta <- 0.20
  got <- tsahr:::.rtsa_beta_spend_OF(t, beta)$betaValuesCumulated
  expected <- 2 * stats::pnorm(
    stats::qnorm(1 - beta / 2) / sqrt(t),
    lower.tail = FALSE
  )
  expect_equal(got, expected, tolerance = 1e-14)
  expect_equal(got[length(got)], beta, tolerance = 1e-14)
})

test_that("RTSA retrospective inner-wedge engine has definitive alpha boundary", {
  t <- c(0.10, 0.25, 0.50, 0.75, 1)
  alpha <- 0.05
  beta <- 0.20
  alpha_ref <- rep(stats::qnorm(1 - alpha / 2), length(t))
  ans <- tsahr:::.rtsa_beta_boundary(t, alpha, beta, alpha_ref)

  expect_length(ans$boundary, length(t))
  expect_equal(ans$boundary[length(t)], stats::qnorm(1 - alpha / 2), tolerance = 1e-12)
  expect_equal(ans$beta_spent[length(t)], beta, tolerance = 1e-12)
})

test_that("RTSA over-powered analysis uses conventional definitive boundary", {
  t <- c(0.10, 0.25, 0.50, 0.90, 1.10, 1.50)
  alpha <- 0.05
  beta <- 0.20
  alpha_ref <- rep(stats::qnorm(1 - alpha / 2), length(t))
  ans <- tsahr:::.rtsa_beta_boundary(t, alpha, beta, alpha_ref)

  expect_true(ans$over_power)
  expect_equal(ans$fakeIFY, stats::qnorm(1 - alpha / 2), tolerance = 1e-14)
  expect_true(all(ans$boundary[t >= 1] == ans$fakeIFY))
})


test_that("RTSA beta boundary hides non-positive early futility points", {
  t <- c(0.05, 0.10, 0.20, 0.35, 0.50, 0.75, 1.0)
  alpha <- 0.05
  beta <- 0.20
  alpha_ref <- rep(qnorm(1 - alpha / 2), length(t))
  ans <- tsahr:::.rtsa_beta_boundary(t, alpha, beta, alpha_ref)

  expect_true(all(ans$boundary[!is.na(ans$boundary)] > 0))
  expect_equal(tail(ans$boundary, 1), qnorm(1 - alpha / 2), tolerance = 1e-10)
})


test_that("futility boundary is capped at the corresponding alpha boundary", {
  t <- c(0.10, 0.25, 0.50, 0.75, 1.00)
  alpha <- 0.05
  beta <- 0.20
  alpha_ref <- c(5.0, 3.5, 2.8, 2.2, qnorm(1 - alpha / 2))
  ans <- tsahr:::.rtsa_beta_boundary(t, alpha, beta, alpha_ref)

  ok <- !is.na(ans$boundary)
  expect_true(all(ans$boundary[ok] <= alpha_ref[ok] + 1e-14))
})
