# UCM / GEM / TNC decomposition of motor variability, verified on synthetic
# redundant tasks with a known variability structure.

test_that("UCM finds a task-stabilising synergy for redundant covariation", {
  set.seed(1)
  # task variable = a1 + a2; if a1, a2 anti-covary the total is stable ->
  # variance lies along the UCM (good) -> positive synergy index.
  a1 <- rnorm(300, 30, 5); a2 <- 60 - a1 + rnorm(300, 0, 0.4)
  syn <- uncontrolledManifold(cbind(a1, a2), jacobian = matrix(c(1, 1), nrow = 1))
  expect_s3_class(syn, "ucm_result")
  expect_gt(syn$delta_v, 0)                          # stabilising synergy
  expect_gt(syn$v_ucm, syn$v_ort)
  # no covariation (independent) -> variance shared, weak/no synergy
  b1 <- rnorm(300, 30, 5); b2 <- rnorm(300, 30, 5)
  nosyn <- uncontrolledManifold(cbind(b1, b2), jacobian = matrix(c(1, 1), nrow = 1))
  expect_lt(nosyn$delta_v, syn$delta_v)
  expect_lt(abs(nosyn$delta_v), 0.5)                 # ~ 0 for independent elements
})

test_that("UCM dimensions and per-DOF normalisation are correct", {
  set.seed(2)
  th <- matrix(rnorm(100 * 4), ncol = 4)
  J <- matrix(c(1, 1, 1, 1), nrow = 1)               # 1D task, 4 elements
  u <- uncontrolledManifold(th, jacobian = J)
  expect_equal(u$dim_ucm, 3)                         # n - d = 4 - 1
  expect_equal(u$dim_ort, 1)
  expect_equal(u$n, 4); expect_equal(u$d, 1)
})

test_that("UCM accepts a task function (numerical Jacobian)", {
  set.seed(3)
  a1 <- rnorm(200, 10, 3); a2 <- 20 - a1 + rnorm(200, 0, 0.3)
  u <- uncontrolledManifold(cbind(a1, a2), task = function(p) sum(p))
  expect_gt(u$delta_v, 0)
})

test_that("GEM separates goal-equivalent from non-goal-equivalent variability", {
  set.seed(4)
  x1 <- rnorm(300, 10, 3); x2 <- 20 - x1 + rnorm(300, 0, 0.3)   # x1+x2 ~ const
  g <- goalEquivalentManifold(cbind(x1, x2), goal_gradient = c(1, 1))
  expect_s3_class(g, "gem_result")
  expect_gt(g$me_ratio, 1)                           # variability channelled off-goal
  expect_gt(g$log_me_ratio, 0)
  expect_gt(g$gev, g$ngev)
})

test_that("TNC recovers a positive covariation benefit on a redundant task", {
  set.seed(5)
  # covary to keep x1 + x2 = 20 -> observed covariation reduces error
  x1 <- rnorm(400, 12, 3); x2 <- 20 - x1 + rnorm(400, 0, 0.5)
  err <- function(M) (M[, 1] + M[, 2] - 20)^2
  tnc <- toleranceNoiseCovariation(cbind(x1, x2), err, optimum = c(10, 10),
                                   n_surrogate = 100)
  expect_s3_class(tnc, "tnc_result")
  expect_gt(tnc$covariation, 0)                      # covariation helps
  # destroying covariation on an INDEPENDENT cloud gives ~ no covariation benefit
  y1 <- rnorm(400, 10, 3); y2 <- rnorm(400, 10, 3)
  tnc0 <- toleranceNoiseCovariation(cbind(y1, y2), err, optimum = c(10, 10),
                                    n_surrogate = 100)
  expect_lt(tnc0$covariation, tnc$covariation)
  expect_output(print(tnc), "Tolerance-Noise-Covariation")
})

test_that("TNC tolerance component reflects an off-target mean", {
  set.seed(6)
  # cloud mean far from the tolerant optimum -> large tolerance component
  x1 <- rnorm(300, 20, 2); x2 <- rnorm(300, 20, 2)   # mean sum 40, target 20
  err <- function(M) (M[, 1] + M[, 2] - 20)^2
  tnc <- toleranceNoiseCovariation(cbind(x1, x2), err, optimum = c(10, 10),
                                   n_surrogate = 60)
  expect_gt(tnc$tolerance, 0)                        # relocating the mean helps a lot
})
