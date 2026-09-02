# Golden regression tests: movement-quality smoothness kernels vs
# INDEPENDENT references captured in _golden/ by data-raw/golden.R.
#
#   sparc_minjerk / sparc_midband -> published Balasubramanian (2015) algorithm
#   dlj_quadratic / ldlj_minjerk  -> analytic closed-form dimensionless jerk
#
# Inputs here MUST match the builders in data-raw/golden.R exactly.

# --- deterministic input builders (mirror data-raw/golden.R) ---------------
.g_mj_speed <- function(n) {
  tau <- seq(0, 1, length.out = n)
  30 * tau^2 - 60 * tau^3 + 30 * tau^4
}
.g_midband_speed <- function(n) {
  tau <- seq(0, 1, length.out = n)
  sin(2 * pi * 4 * tau) * exp(-((tau - 0.5)^2) / 0.02)
}
.g_quad_speed <- function(n, fs, a = 3.0) {
  t <- seq(0, (n - 1) / fs, length.out = n)
  a * t^2
}

test_that("SPARC matches the published Balasubramanian algorithm (min-jerk)", {
  actual <- sparc(.g_mj_speed(200L), fs = 200)
  expect_equal_golden(actual, "sparc_minjerk", tol = 1e-8)
})

test_that("SPARC matches the published algorithm on a mid-band profile", {
  actual <- sparc(.g_midband_speed(200L), fs = 200)
  expect_equal_golden(actual, "sparc_midband", tol = 1e-8)
})

test_that("dimensionlessJerk matches the analytic value (4) for a quadratic profile", {
  # n large enough that the O(1/n) finite-difference error is within tol=1e-3.
  n <- 20001L; fs <- 100
  actual <- dimensionlessJerk(.g_quad_speed(n, fs), fs = fs)
  expect_equal_golden(actual, "dlj_quadratic", tol = 1e-3)
})

test_that("LDLJ matches the analytic value (-log(204.8)) for the min-jerk profile", {
  # High-n grid so the finite-difference LDLJ converges within tol=1e-3.
  n <- 20001L; fs <- 20000
  actual <- ldlj(.g_mj_speed(n), fs = fs)
  expect_equal_golden(actual, "ldlj_minjerk", tol = 1e-3)
})
