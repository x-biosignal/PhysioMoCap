# Movement primitives: DMP (reproduce + generalise) and ProMP (distribution +
# conditioning), verified on synthetic trajectories.

test_that("DMP reproduces the demonstrated trajectory", {
  t <- seq(0, 1, length.out = 120)
  y <- 8 * (10*t^3 - 15*t^4 + 6*t^5)                 # min-jerk demo, 0 -> 8
  d <- dmpFit(y, n_basis = 30)
  rg <- dmpGenerate(d, n = 120)
  expect_s3_class(d, "dmp")
  expect_lt(max(abs(rg$y[, 1] - y)), 0.2)            # close reproduction
  expect_equal(rg$y[nrow(rg$y), 1], 8, tolerance = 0.05)   # converges to goal
})

test_that("DMP generalises to a new goal (converges to it)", {
  t <- seq(0, 1, length.out = 100)
  y <- 5 * (10*t^3 - 15*t^4 + 6*t^5)
  d <- dmpFit(y)
  rg <- dmpGenerate(d, goal = 12, n = 100)
  expect_equal(rg$y[nrow(rg$y), 1], 12, tolerance = 0.1)   # new goal reached
})

test_that("DMP temporal scaling changes duration but keeps the endpoint", {
  t <- seq(0, 1, length.out = 100)
  y <- 5 * (10*t^3 - 15*t^4 + 6*t^5)
  d <- dmpFit(y)
  slow <- dmpGenerate(d, tau = 2, n = 100)
  expect_equal(max(slow$time), 2, tolerance = 1e-8)
  expect_equal(slow$y[nrow(slow$y), 1], 5, tolerance = 0.1)
})

test_that("DMP handles multi-DOF demonstrations", {
  t <- seq(0, 1, length.out = 80); s <- 10*t^3 - 15*t^4 + 6*t^5
  Y <- cbind(3 * s, -2 * s + 1)
  d <- dmpFit(Y); expect_equal(d$D, 2)
  rg <- dmpGenerate(d, n = 80)
  expect_lt(max(abs(rg$y - Y)), 0.2)
})

test_that("ProMP recovers the mean shape and a positive variability band", {
  set.seed(1)
  z <- seq(0, 1, length.out = 60); shape <- sin(2 * pi * z)
  demos <- lapply(1:30, function(i) shape + rnorm(60, 0, 0.15))
  p <- promFit(demos, n_basis = 20)
  expect_s3_class(p, "promp")
  expect_gt(cor(p$mean, shape), 0.98)                # mean recovers the shape
  expect_true(all(p$sd >= 0) && mean(p$sd) > 0)      # non-degenerate band
})

test_that("ProMP conditioning pulls the trajectory through a via-point", {
  set.seed(2)
  z <- seq(0, 1, length.out = 60); shape <- sin(2 * pi * z)
  demos <- lapply(1:30, function(i) shape + rnorm(60, 0, 0.2))
  p <- promFit(demos, n_basis = 20)
  via_phase <- 0.5; via_val <- 1.5                    # off the mean (~0 at z=0.5)
  pc <- promCondition(p, via_phase, via_val, obs_sd = 1e-3)
  idx <- which.min(abs(z - via_phase))
  expect_lt(abs(pc$mean[idx] - via_val), 0.15)       # passes near the via-point
  expect_gt(pc$mean[idx], p$mean[idx] + 1)           # pulled strongly toward it
  expect_lt(pc$sd[idx], p$sd[idx])                   # uncertainty shrinks there
  expect_output(print(pc), "Probabilistic Movement Primitive")
})
