# Model-based planar inverse kinematics, verified against a known chain.

test_that("scalePlanarModel recovers segment lengths from a static pose", {
  nodes <- rbind(c(0, 0), c(0.45, 0), c(0.45, -0.40))    # thigh 0.45, shank 0.40
  m <- scalePlanarModel(nodes)
  expect_s3_class(m, "planar_ik_model")
  expect_equal(m$lengths, c(0.45, 0.40), tolerance = 1e-9)
  expect_equal(m$n_segments, 2)
})

test_that("forward kinematics places nodes correctly", {
  p <- forwardKinematics2D(c(0, pi / 2), c(1, 1))
  expect_equal(p[2, ], c(1, 0), tolerance = 1e-9)
  expect_equal(p[3, ], c(1, 1), tolerance = 1e-9)        # up after the right angle
})

test_that("IK recovers known joint angles from clean markers", {
  model <- scalePlanarModel(rbind(c(0, 0), c(1, 0), c(2, 0)))
  true_ang <- rbind(c(0.3, 0.7), c(-0.2, 0.5), c(0.1, -0.4))
  M <- array(0, c(3, 3, 2))
  for (f in 1:3) M[f, , ] <- forwardKinematics2D(true_ang[f, ], model$lengths)
  ik <- inverseKinematicsMarkers(M, model)
  expect_s3_class(ik, "ik_result")
  expect_lt(max(abs(ik$angles - true_ang)), 1e-4)        # exact recovery
  expect_lt(max(ik$rmse), 1e-4)
})

test_that("IK enforces fixed segment lengths under marker noise", {
  set.seed(1)
  model <- scalePlanarModel(rbind(c(0, 0), c(0.5, 0), c(1.0, 0)))
  t <- seq(0, 1, length.out = 40)
  ang <- cbind(0.5 * sin(2 * pi * t), 0.3 * cos(2 * pi * t) - 0.2)
  M <- array(0, c(40, 3, 2))
  for (f in 1:40) {
    clean <- forwardKinematics2D(ang[f, ], model$lengths)
    M[f, , ] <- clean + matrix(rnorm(6, 0, 0.01), 3, 2)  # noisy markers
  }
  ik <- inverseKinematicsMarkers(M, model)
  # recovered angles track truth despite noise
  expect_lt(max(abs(ik$angles - ang)), 0.1)
  # the fitted chain keeps EXACT segment lengths (model-based), unlike raw markers
  fitted_len <- t(vapply(1:40, function(f) {
    p <- forwardKinematics2D(ik$angles[f, ], model$lengths, M[f, 1, ])
    sqrt(rowSums((p[-1, ] - p[-3, ])^2))
  }, numeric(2)))
  expect_lt(max(abs(sweep(fitted_len, 2, model$lengths))), 1e-8)
  # raw marker segment lengths DO wobble with the noise (motivation for model IK)
  raw_len <- t(vapply(1:40, function(f)
    sqrt(rowSums((M[f, -1, ] - M[f, -3, ])^2)), numeric(2)))
  expect_gt(max(abs(sweep(raw_len, 2, model$lengths))), 0.005)
})

test_that("IK accepts a list of per-frame node matrices", {
  model <- scalePlanarModel(rbind(c(0, 0), c(1, 0), c(2, 0)))
  frames <- lapply(list(c(0.2, 0.4), c(0.1, -0.3)), function(a)
    forwardKinematics2D(a, model$lengths))
  ik <- inverseKinematicsMarkers(frames, model)
  expect_equal(ik$n_frames, 2)
  expect_output(print(ik), "inverse kinematics")
})
