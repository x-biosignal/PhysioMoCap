# Orbital stability (Floquet), RQA and approximate entropy, verified on systems
# with known dynamics.

# build strides from a stride-to-stride perturbation map: the same perturbation
# d_n is added at every phase and evolves d_{n+1} = A d_n + noise.
mk_strides <- function(A, P, nS, cyc_sd = 1, noise = 0.01, seed = 1) {
  set.seed(seed)
  cyc <- matrix(rnorm(P * nrow(A), 0, cyc_sd), P, nrow(A))
  strides <- array(0, c(nS, P, nrow(A))); d <- rnorm(nrow(A))
  for (n in seq_len(nS)) {
    for (k in seq_len(P)) strides[n, k, ] <- cyc[k, ] + d
    d <- as.numeric(A %*% d) + rnorm(nrow(A), 0, noise)
  }
  strides
}

test_that("Floquet multipliers recover a known stable return map", {
  A <- matrix(c(0.5, 0.1, 0.0, 0.3), 2, 2)           # eigenvalues 0.5, 0.3
  fl <- floquetMultipliers(mk_strides(A, P = 4, nS = 150, noise = 0.02, seed = 1))
  expect_s3_class(fl, "floquet_result")
  expect_true(fl$orbitally_stable)                   # max |mult| < 1
  expect_equal(fl$max_multiplier, 0.5, tolerance = 0.1)   # dominant eigenvalue
})

test_that("Floquet flags an unstable (expanding) map", {
  A <- matrix(c(1.15, 0, 0, 0.4), 2, 2)              # eigenvalue 1.15 > 1
  fl <- floquetMultipliers(mk_strides(A, P = 3, nS = 60, noise = 0.02, seed = 2))
  expect_false(fl$orbitally_stable)
  expect_gt(fl$max_multiplier, 1)
})

test_that("Floquet accepts a list of stride matrices", {
  A <- matrix(c(0.6, 0, 0, 0.2), 2, 2)
  arr <- mk_strides(A, P = 3, nS = 90, seed = 3)
  strides <- lapply(seq_len(dim(arr)[1]), function(s) matrix(arr[s, , ], 3, 2))
  expect_true(floquetMultipliers(strides)$orbitally_stable)
})

test_that("RQA: determinism is high for a sine, low for white noise", {
  t <- seq(0, 30 * pi, length.out = 900)
  det_sine <- recurrenceQuantification(sin(t), m = 3, tau = 5)$DET
  set.seed(4)
  det_noise <- recurrenceQuantification(rnorm(900), m = 3, tau = 5)$DET
  expect_gt(det_sine, 0.9)
  expect_lt(det_noise, det_sine)
  expect_lt(det_noise, 0.6)
})

test_that("RQA returns a valid recurrence rate near the target", {
  set.seed(5)
  r <- recurrenceQuantification(cumsum(rnorm(500)), target_rr = 0.1)
  expect_gt(r$RR, 0.03); expect_lt(r$RR, 0.25)
  expect_s3_class(r, "rqa_result")
  expect_output(print(r), "RQA")
})

test_that("approximate entropy is low for regular, high for irregular signals", {
  t <- seq(0, 20 * pi, length.out = 500)
  ap_sine <- approximateEntropy(sin(t))
  set.seed(6)
  ap_noise <- approximateEntropy(rnorm(500))
  expect_lt(ap_sine, 0.3)
  expect_gt(ap_noise, ap_sine)
  expect_gt(ap_noise, 0.8)
})
