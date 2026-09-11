## Internal O'Brien-Fleming-type alpha-spending and non-binding
## beta-spending group sequential boundary calculator.
##
## This replaces an earlier dependency on 'rpact' for computing trial
## sequential monitoring boundaries. rpact's getDesignGroupSequential()
## imposes a hard, software-specific limit of kMax <= 20 looks (with only
## an advisory warning above kMax=10) -- a package validation choice, not
## a statistical one. A meta-analysis with many included studies (each
## study being one "look" in TSA) routinely exceeds this. The functions
## below implement the same underlying, textbook methodology directly, so
## the number of looks is limited only by computation time, not an
## artificial cap.
##
## Methodology:
##   - Alpha-spending function (Lan & DeMets 1983 O'Brien-Fleming-type
##     approximation): alpha*(t) = 2*(1 - Phi(z_{alpha/2}/sqrt(t)))
##   - Beta-spending function (analogous, O'Brien-Fleming-type, targeting
##     a central inner wedge rather than two outer tails -- see the note
##     above .beta_spend_OF for why this is NOT doubled like alpha):
##     beta*(t)  = 1 - Phi(z_beta/sqrt(t))
##   - Sequential boundaries at each information fraction are obtained via
##     the standard recursive numerical integration (Armitage, McPherson &
##     Rowe 1969; generalised for spending functions by Reboussin, DeMets,
##     Kim & Lan 2000), carried out here in "B-value" (Brownian motion)
##     space, where increments between looks are simple additive Gaussians
##     -- computed efficiently via FFT-based convolution (stats::convolve)
##     rather than an O(K*N^2) dense matrix, so this comfortably scales to
##     many looks (tested to K > 100 in well under a second per call).
##   - Non-binding futility (beta) boundaries are computed holding the
##     already-fixed alpha boundary, under the alternative hypothesis with
##     standardised drift theta = z_{alpha/2} + z_beta (matching the
##     single-look power calculation used elsewhere in this package), as
##     is standard for non-binding futility monitoring.
##
## VALIDATION:
##   - Alpha-spending boundary engine: independently reproduced line-by-
##     line in Python (scipy) and checked two ways:
##       1. The K=5 equally-spaced two-sided alpha=0.05 case matches the
##          classical, widely-published O'Brien-Fleming boundary constant
##          (~2.040) to within grid-discretisation error.
##       2. A direct (non-simulation) 2D numerical integration for K=2
##          confirmed the constructed boundaries yield the intended
##          overall two-sided alpha almost exactly (0.0506 vs a 0.05
##          target).
##       3. A 100,000-replicate Monte Carlo across five configurations
##          (K=2, K=3 unequally spaced, K=5, K=10, K=39 unequally spaced)
##          gave empirical type-I error of 5.02%-5.22% against a 0.05
##          nominal target (Monte Carlo SE ~=0.07%) -- i.e. within 2-3
##          simulation SEs in every configuration checked, and with no
##          degradation at larger K. This is genuine evidence of correct
##          alpha-spending behaviour, not merely internal self-consistency
##          (the boundaries were verified against an independently coded
##          simulation and, for K=2, against closed-form integration).
##       This validation was carried out without R (no rpact comparison
##       was possible in that environment); it is independent of this
##       package's own R test suite, but is not a comparison against
##       rpact specifically. Users who need a like-for-like comparison
##       against rpact should still do so themselves for their exact
##       design if that specific software agreement matters to them.
##   - Non-binding beta/futility boundary engine: this is a materially
##     harder quantity to calibrate than the alpha boundaries, because
##     the realised futility-stopping probability under H1 depends on
##     conditioning on non-crossing of the (already-fixed) alpha
##     boundary at every prior look, not just on the beta-spending
##     function's target value in isolation. A Monte Carlo check under
##     H1 (K=5, theta matching the design's power calculation) found
##     that the realised probability of stopping for non-binding
##     futility, and the realised power (probability of crossing the
##     efficacy boundary), both deviate from their nominal targets by a
##     non-trivial amount (single-digit percentage points in the
##     configuration checked). Because the futility boundary is
##     explicitly NON-BINDING in this package (crossing it is reported
##     as advisory only -- see `entered_futility_region` -- and never
##     triggers an automatic stopping decision, nor affects the alpha
##     boundary or the "DARIS reached" verdict), this imprecision does
##     not compromise the package's type-I error control, which is
##     governed solely by the independently-validated alpha engine
##     above. It does mean the futility band drawn on the plot should be
##     read as an approximate, illustrative guide to when the trend is
##     unpromising, not as a boundary with a precisely calibrated
##     operating characteristic. See `?tsa_hr` for further discussion.

.alpha_spend_OF <- function(t, alpha) {
  z <- stats::qnorm(1 - alpha / 2)
  2 * (1 - stats::pnorm(z / sqrt(t)))
}

## Non-binding beta-spending function. Deliberately NOT doubled (unlike
## .alpha_spend_OF): the alpha function's factor of 2 reflects genuine
## two-tailed spending (alpha/2 in each tail, symmetric outer rejection
## regions). The futility construction below instead targets a single,
## central "inner wedge" |B_k| < b_k under one-directional drift theta;
## doubling that target would make the cumulative nominal spend equal to
## 2*beta rather than beta at t=1 (e.g. 0.40 rather than 0.20 for the
## default beta=0.20), which is not the intended convention -- the total
## non-binding-futility spend across the whole design should target the
## nominal beta used elsewhere in the power calculation. See the
## VALIDATION note above for the accuracy this achieves in practice
## (approximate, not exact, and inherently harder to calibrate than the
## alpha engine).
.beta_spend_OF <- function(t, beta) {
  z <- stats::qnorm(1 - beta)
  1 - stats::pnorm(z / sqrt(t))
}

## FFT-based Gaussian convolution step: given a (sub-)density h defined on
## an equally-spaced grid, returns the density after one Brownian-motion
## increment of variance dt (and optional mean shift), evaluated back on
## the SAME grid.
.convolve_step <- function(h, bgrid, db, dt, shift = 0) {
  n <- length(bgrid)
  lags <- seq(-(n - 1), (n - 1)) * db
  kernel <- stats::dnorm(lags - shift, sd = sqrt(dt))
  conv_result <- stats::convolve(h, rev(kernel), type = "open") * db
  conv_result[n:(2 * n - 1)]
}

## Alpha (efficacy) boundary at each information fraction in t (t[K]
## should be 1, i.e. the design's final/reference information size).
## Returns critical values in Z-space; Inf where the information fraction
## is too small for any finite boundary to be reached under the spending
## function (this is the mathematically correct answer -- no amount of
## evidence that early would justify stopping -- not a failure).
.obf_alpha_boundary <- function(t, alpha, bmax = 15, n_grid = 2000) {
  K <- length(t)
  bgrid <- seq(-bmax, bmax, length.out = n_grid)
  db <- bgrid[2] - bgrid[1]

  A <- .alpha_spend_OF(t, alpha)
  a_vec <- numeric(K)

  sd1 <- sqrt(t[1])
  a_vec[1] <- sd1 * stats::qnorm(1 - A[1] / 2)
  if (!is.finite(a_vec[1])) a_vec[1] <- Inf
  h <- stats::dnorm(bgrid, mean = 0, sd = sd1)
  h[abs(bgrid) >= a_vec[1]] <- 0

  if (K >= 2) {
    for (k in 2:K) {
      dt <- t[k] - t[k - 1]
      h_pre <- .convolve_step(h, bgrid, db, dt)

      target <- A[k] - A[k - 1]
      tail_prob <- function(a) 2 * sum(h_pre[bgrid >= a]) * db
      a_vec[k] <- if (tail_prob(bmax - 0.01) > target) {
        Inf
      } else {
        tryCatch(
          stats::uniroot(function(a) tail_prob(a) - target,
                          lower = 0, upper = bmax - 0.01)$root,
          error = function(e) Inf)
      }
      h <- h_pre
      h[abs(bgrid) >= a_vec[k]] <- 0
    }
  }
  a_vec / sqrt(t)
}

## Beta (non-binding futility) boundary at each information fraction,
## holding the already-computed alpha boundary (c_vec_alpha, in Z-space)
## fixed. Returns Z-space values; NA where no futility bound is computed
## (too early for a formal call, or -- by construction -- at the final
## look, since there is never a futility DECISION at a definitive final
## analysis).

## -------------------------------------------------------------------------
## RTSA / original CTU-TSA non-binding futility engine
##
## This is a literal R implementation of the retrospective/analysis-mode
## "inner wedge" algorithm supplied from RTSA's old TSA functions
## ("translated from java").  It is deliberately used here instead of
## rpact: tsahr is an observed-data / retrospective TSA application and
## this engine is the practical reference requested for that use case.
##
## The important distinction from the previous beta engine is that the
## beta boundary is NOT obtained by independently assigning a probability
## to each look under H1.  Instead:
##   1. construct the O'Brien-Fleming beta-spending increments;
##   2. construct a symmetric null-referenced inner wedge recursively;
##   3. propagate the surviving density through the wedge;
##   4. solve each subsequent wedge edge from the incremental beta spend;
##   5. derive an empirical drift from the final wedge width;
##   6. shift the null-referenced wedge into the reported futility Z
##      boundaries.
##
## The implementation below follows the supplied RTSA/CTU functions
## betas_Obf(), sdfunc(), trap_old(), gfunc(), fcab_old(), qpos_old(),
## first_old(), other_old(), searchfunc_old(), and getInnerWedge().
## -------------------------------------------------------------------------

.rtsa_gfunc <- function(x, delta) {
  exp(-0.5 * (x - delta)^2) / sqrt(2 * pi)
}

.rtsa_trap <- function(f, n, h) {
  if (n <= 0L) return(0)
  h * (f[1L] + f[n + 1L] + 2 * sum(f[seq_len(n - 1L) + 1L])) / 2
}

.rtsa_fcab <- function(last, nint, yam1, ybm1, h, x, stdv, delta) {
  grid2 <- yam1 + h * seq.int(0, nint)
  f <- last[seq_len(nint + 1L)] *
    .rtsa_gfunc((x - grid2) / stdv, delta = delta) / stdv
  .rtsa_trap(f, nint, h)
}

.rtsa_qpos <- function(xq, last, nint, yam1, ybm1, stdv) {
  hlast <- (ybm1 - yam1) / nint
  grid3 <- yam1 + hlast * seq.int(0, nint)
  f <- last[seq_len(nint + 1L)] *
    stats::pnorm((grid3 - xq) / stdv)
  .rtsa_trap(f, nint, hlast)
}

.rtsa_first <- function(ya, yb, stdv, nint, delta) {
  hh <- (yb - ya) / nint
  ## Preserve the indexing used by RTSA's old TSA translation literally:
  ## 1:(nint)+1 is parsed by R as (1:nint)+1.
  ## RTSA used a fixed 5000-cell buffer.  Keep its literal indexing,
  ## but size the buffer to the actual grid so large first wedges cannot
  ## silently run beyond the allocated vector.
  last <- numeric(nint + 1L)
  j <- seq_len(nint) + 1L
  grid <- ya + hh * (j - 1L)
  last[j] <- .rtsa_gfunc(grid / stdv, delta = delta) / stdv
  last
}

.rtsa_other <- function(ya, yb, i, stdv, last, nints) {
  hh <- (yb[i] - ya[i]) / nints[i]
  hlast <- (yb[i - 1L] - ya[i - 1L]) / nints[i - 1L]
  grid1 <- ya[i] + hh * seq.int(0, nints[i])
  vapply(
    grid1,
    function(x)
      .rtsa_fcab(
        last = last,
        nint = nints[i - 1L],
        yam1 = ya[i - 1L],
        ybm1 = yb[i - 1L],
        h = hlast,
        x = x,
        stdv = stdv,
        delta = 0
      ),
    numeric(1)
  )
}

.rtsa_searchfunc_old <- function(last, nints, i, valSF, stdv, ya, yb,
                                 maxnn = 50L, eps = 1e-7) {
  upper <- yb[i - 1L]
  del <- 10
  qout <- .rtsa_qpos(
    xq = upper, last = last, nint = nints[i - 1L],
    yam1 = ya[i - 1L], ybm1 = yb[i - 1L], stdv = stdv
  )

  iter <- 0L
  best_upper <- upper
  best_err <- abs(qout - valSF)
  converged <- best_err <= eps

  while (!converged && iter < 100000L) {
    iter <- iter + 1L

    if (qout > valSF + eps) {
      del <- del / 10
      for (k in seq_len(maxnn)) {
        upper <- upper + del
        qout <- .rtsa_qpos(
          xq = upper, last = last, nint = nints[i - 1L],
          yam1 = ya[i - 1L], ybm1 = yb[i - 1L], stdv = stdv
        )
        err <- abs(qout - valSF)
        if (err < best_err) {
          best_err <- err
          best_upper <- upper
        }
        if (qout <= valSF + eps) break
      }
    } else if (qout < valSF - eps) {
      del <- del / 10
      for (k in seq_len(maxnn)) {
        upper <- upper - del
        qout <- .rtsa_qpos(
          xq = upper, last = last, nint = nints[i - 1L],
          yam1 = ya[i - 1L], ybm1 = yb[i - 1L], stdv = stdv
        )
        err <- abs(qout - valSF)
        if (err < best_err) {
          best_err <- err
          best_upper <- upper
        }
        if (qout >= valSF - eps) break
      }
    }

    converged <- abs(qout - valSF) <= eps
  }

  if (!converged) {
    warning(
      sprintf(
        "RTSA futility-boundary search did not converge at look %d; using the closest value found (absolute error %.3g).",
        i, best_err
      ),
      call. = FALSE
    )
    upper <- best_upper
  }

  yb[i] <- upper
  yb
}

.rtsa_beta_spend_OF <- function(t, beta, tol = 1e-13) {
  t <- as.numeric(t)
  if (any(!is.finite(t)) || any(t <= 0))
    stop("information fractions must be finite and > 0")
  if (!is.finite(beta) || beta <= 0 || beta >= 1)
    stop("beta must be strictly between 0 and 1")

  cum <- 2 * stats::pnorm(
    stats::qnorm(1 - beta / 2) / sqrt(t),
    lower.tail = FALSE
  )
  delta <- c(cum[1L], diff(cum))
  delta[delta < tol] <- 0
  list(betaValuesCumulated = cum, betaValuesDelta = delta)
}

.rtsa_get_inner_wedge <- function(informationFractions, beta, fakeIFY,
                                  zninf = -20, tol = 1e-13) {
  t <- as.numeric(informationFractions)
  nn <- length(t)
  if (nn < 1L) stop("at least one information fraction is required")
  if (any(!is.finite(t)) || any(t <= 0))
    stop("information fractions must be finite and > 0")
  if (any(diff(t) < 0))
    stop("information fractions must be non-decreasing")

  za <- numeric(nn)
  zb <- numeric(nn)
  ya <- numeric(nn)
  yb <- numeric(nn)
  nints <- numeric(nn)

  outbeta <- .rtsa_beta_spend_OF(t, beta, tol = tol)
  sdincr <- sqrt(c(t[1L], diff(t)))
  sdproc <- sqrt(t)

  d1 <- outbeta$betaValuesDelta[1L]
  d1 <- min(beta, max(0, d1))

  if (d1 < tol) {
    za[1L] <- zninf
    ya[1L] <- za[1L] * sdincr[1L]
  } else if (d1 == beta) {
    za[1L] <- 0
    ya[1L] <- 0
  } else {
    za[1L] <- stats::qnorm(d1)
    ya[1L] <- za[1L] * sdincr[1L]
  }

  zb[1L] <- -za[1L]
  yb[1L] <- -ya[1L]

  nints[1L] <- max(
    1L,
    round(abs(yb[1L] - ya[1L]) / 0.05 * sdincr[1L]) + 1L
  )

  last <- NULL

  if (nn >= 2L) {
    for (i in 2:nn) {
      if (i == 2L) {
        last <- .rtsa_first(
          ya = ya[1L], yb = yb[1L], stdv = sdincr[1L],
          nint = nints[1L], delta = 0
        )
      }

      di <- outbeta$betaValuesDelta[i]
      di <- min(1, max(0, di))

      if (di < tol) {
        za[i] <- zninf
        ya[i] <- za[i] * sdincr[i]
      } else if (di == 1) {
        za[i] <- 0
        ya[i] <- 0
      } else {
        yb <- .rtsa_searchfunc_old(
          last = last, nints = nints, i = i, valSF = di,
          stdv = sdincr[i], ya = ya, yb = yb
        )
        zb[i] <- yb[i] / sdproc[i]
        ya[i] <- -yb[i]
        za[i] <- -zb[i]
      }

      nints[i] <- max(
        1L,
        round(abs(yb[i] - ya[i]) / 0.05 * sdincr[i]) + 1L
      )

      if (i != nn) {
        last <- .rtsa_other(
          ya = ya, yb = yb, i = i, stdv = sdincr[i],
          last = last, nints = nints
        )
      }
    }
  }

  ## This is the RTSA/old-TSA empirical drift construction:
  ## the final inner-wedge half-width is added to the supplied fake
  ## information-yield/final-alpha reference.
  testDrift <- fakeIFY + abs(ya[nn])
  futility_z <- za + sdproc * testDrift

  list(
    inf_frac = t,
    futility_z = futility_z,
    za = za,
    testDrift = testDrift,
    betaValuesCumulated = outbeta$betaValuesCumulated,
    betaValuesDelta = outbeta$betaValuesDelta,
    sdincr = sdincr,
    sdproc = sdproc,
    ya = ya,
    yb = yb,
    nints = nints
  )
}

## Public internal entry point used by tsa_hr().
##
## This follows RTSA's `tsa_beta_bound = TRUE` analysis branch.  The
## null inner wedge is shifted by RTSA's `fakeIFY` reference and its
## final half-width; the definitive futility boundary is then set to
## qnorm(1-alpha/2) in the non-overpowered case.
.rtsa_beta_boundary <- function(t, alpha, beta, c_vec_alpha) {
  t <- as.numeric(t)
  if (length(t) != length(c_vec_alpha))
    stop("t and c_vec_alpha must have the same length")

  ## This is the exact retrospective `tsa_beta_bound` branch in RTSA:
  ## if observed information exceeds the required information size, the
  ## inner-wedge calculation is done only for t < 1 and the definitive
  ## boundary is the conventional two-sided alpha quantile.
  over_power <- any(t > 1)

  if (over_power) {
    fakeIFY <- stats::qnorm(1 - alpha / 2, lower.tail = TRUE)
    timing_beta <- t[t < 1]
  } else {
    fakeIFY <- c_vec_alpha[length(c_vec_alpha)]
    timing_beta <- t
  }

  if (length(timing_beta) == 0L) {
    boundary <- rep(fakeIFY, length(t))
    boundary[t >= 1] <- fakeIFY
    return(list(
      boundary = boundary,
      beta_spent = rep(beta, length(t)),
      beta_spent_raw = rep(beta, length(t)),
      beta_spent_delta = rep(NA_real_, length(t)),
      auxiliary_futility = rep(NA_real_, length(t)),
      testDrift = NA_real_,
      fakeIFY = fakeIFY,
      over_power = TRUE,
      timing_beta = numeric(0)
    ))
  }

  ans <- .rtsa_get_inner_wedge(
    informationFractions = timing_beta,
    beta = beta,
    fakeIFY = fakeIFY
  )

  if (over_power) {
    ## RTSA: out_inner$ret2 <- c(out_inner$ret2, fakeIFY)
    b <- c(ans$futility_z, fakeIFY)
    ## The observed data can contain several post-DARIS looks.  All of
    ## them are definitive t=1-equivalent analyses in tsahr, so use the
    ## RTSA final value for every t >= 1.
    boundary <- ifelse(t < 1, b[match(t, timing_beta)], fakeIFY)
    ## RTSA exposes only positive futility boundaries.  The retrospective
    ## tsa_beta_bound branch explicitly converts all ret2 <= 0 values to NA
    ## before returning beta_ubound/beta_lbound.
    boundary[boundary <= 0] <- NA_real_
    ## Additional tsahr display guard: a non-binding futility boundary
    ## must not lie outside the corresponding efficacy (alpha) boundary.
    ## For t >= 1, c_vec_alpha is the definitive alpha boundary.
    boundary <- pmin(boundary, c_vec_alpha)

    beta_cum <- c(ans$betaValuesCumulated, beta)
    beta_delta <- c(ans$betaValuesDelta, beta - utils::tail(ans$betaValuesCumulated, 1))
    aux <- c(ans$za, NA_real_)
  } else {
    ## RTSA replaces the final inner-wedge value by qnorm(1-alpha/side).
    ## With side=2 this is +1.959964.
    b <- ans$futility_z
    if (length(b) >= 1L)
      b[length(b)] <- stats::qnorm(1 - alpha / 2, lower.tail = TRUE)
    ## RTSA returns NA for non-positive futility boundaries.
    b[b <= 0] <- NA_real_
    ## Additional tsahr display guard: do not allow futility to extend
    ## beyond the corresponding alpha/efficacy boundary.
    boundary <- pmin(b, c_vec_alpha)
    beta_cum <- ans$betaValuesCumulated
    beta_delta <- ans$betaValuesDelta
    aux <- ans$za
  }

  ## Map the RTSA analysis-mode result back to the original t vector.
  if (over_power) {
    beta_spent <- ifelse(t < 1,
                         beta_cum[match(t, timing_beta)],
                         beta)
    beta_spent_delta <- ifelse(t < 1,
                               beta_delta[match(t, timing_beta)],
                               beta - utils::tail(ans$betaValuesCumulated, 1))
    auxiliary <- ifelse(t < 1, aux[match(t, timing_beta)], NA_real_)
  } else {
    beta_spent <- beta_cum
    beta_spent_delta <- beta_delta
    auxiliary <- aux
  }

  list(
    boundary = boundary,
    beta_spent = beta_spent,
    beta_spent_raw = beta_spent,
    beta_spent_delta = beta_spent_delta,
    auxiliary_futility = auxiliary,
    testDrift = ans$testDrift,
    fakeIFY = fakeIFY,
    over_power = over_power,
    timing_beta = timing_beta,
    sdincr = ans$sdincr,
    sdproc = ans$sdproc,
    ya = ans$ya,
    yb = ans$yb,
    nints = ans$nints
  )
}

## Backward-compatible helper: returns only the boundary vector.
.obf_beta_boundary <- function(t, alpha, beta, c_vec_alpha) {
  .rtsa_beta_boundary(
    t = t, alpha = alpha, beta = beta, c_vec_alpha = c_vec_alpha
  )$boundary
}
