mj_speed <- function(n = 200) {
  tau <- seq(0, 1, length.out = n)
  30 * tau^2 - 60 * tau^3 + 30 * tau^4  # minimum-jerk speed profile
}

test_that("SPARC and LDLJ match reference-toolbox values on a minimum-jerk reach", {
  s <- mj_speed(200)
  # reference values from the Balasubramanian / Melendez-Calderon smoothness
  # toolbox for this canonical minimum-jerk speed profile (fs = 200 Hz)
  expect_equal(sparc(s, fs = 200), -1.4035670075, tolerance = 1e-3)
  expect_equal(ldlj(s, fs = 200), -5.3119835599, tolerance = 1e-3)
})

test_that("SPARC and LDLJ degrade with added high-frequency roughness", {
  fs <- 200
  s <- mj_speed(fs)
  s_rough <- s + 0.15 * max(s) *
    sin(2 * pi * 8 * seq(0, 1, length.out = length(s)))
  expect_lt(sparc(s_rough, fs), sparc(s, fs))
  expect_lt(ldlj(s_rough, fs), ldlj(s, fs))
})

test_that("SPARC and LDLJ degrade monotonically with more sub-movements", {
  fs <- 200
  n <- 200
  # k overlapping minimum-jerk sub-movements: more sub-movements = less smooth
  submovement_speed <- function(k) {
    tau <- seq(0, 1, length.out = n)
    prof <- numeric(n)
    for (i in seq_len(k)) {
      shift <- (i - 1) / (2 * k)
      u <- pmin(pmax((tau - shift) / (1 / k), 0), 1)
      prof <- prof + (30 * u^2 - 60 * u^3 + 30 * u^4)
    }
    prof
  }
  sp <- vapply(1:4, function(k) sparc(submovement_speed(k), fs), numeric(1))
  lj <- vapply(1:4, function(k) ldlj(submovement_speed(k), fs), numeric(1))
  expect_true(all(diff(sp) < 0))   # SPARC strictly decreases
  expect_true(all(diff(lj) < 0))   # LDLJ strictly decreases
})

test_that("movementSmoothness returns an S3 object with both metrics", {
  m <- movementSmoothness(mj_speed(200), fs = 200)
  expect_s3_class(m, "movement_smoothness")
  expect_equal(m$sparc, -1.4035670075, tolerance = 1e-3)
  expect_equal(m$ldlj, -5.3119835599, tolerance = 1e-3)
  expect_true(is.finite(m$dimensionless_jerk))
  expect_output(print(m), "SPARC")
  # degenerate input -> NA
  expect_true(is.na(ldlj(rep(0, 100), fs = 100)))
})

test_that("movementSmoothness scores a PhysioExperiment per marker", {
  s <- mj_speed(200)
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(
      velocity_x = cbind(Wrist = s, Elbow = s * 0.5),
      velocity_y = matrix(0, 200, 2),
      velocity_z = matrix(0, 200, 2)),
    colData = S4Vectors::DataFrame(label = c("Wrist", "Elbow")),
    samplingRate = 200)
  m <- movementSmoothness(pe)
  expect_s3_class(m, "movement_smoothness")
  expect_equal(unname(m$sparc["Wrist"]), -1.4035670075, tolerance = 1e-3)
  # scaling the speed does not change smoothness (amplitude-invariant)
  expect_equal(unname(m$sparc["Elbow"]), unname(m$sparc["Wrist"]),
               tolerance = 1e-6)
  expect_equal(m$fs, 200)
})

test_that("a missing/invalid sampling frequency errors clearly", {
  s <- mj_speed(200)
  expect_error(movementSmoothness(s), "fs .* must be a single positive")
  expect_error(sparc(s, NULL), "positive number")
  expect_error(sparc(s, 0), "positive number")
  expect_error(dimensionlessJerk(s, -1), "positive number")
})
