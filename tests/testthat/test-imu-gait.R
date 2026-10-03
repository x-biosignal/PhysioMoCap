library(testthat)
library(PhysioMoCap)

# --- ZUPT foot-IMU spatiotemporal gait (WS4-06) -------------------------------

# Synthetic foot-IMU trace with a KNOWN stride length. The foot alternates
# stance (stationary, flat) and swing (a cycloid forward step + vertical
# clearance bump, with a sagittal pitch about the world Y axis). Accelerometer
# and gyroscope are generated in the sensor frame using the package's own
# quaternion convention (stationary accel = (0, 0, -g)), so estimateOrientation
# / removeGravity round-trip cleanly.
.make_foot_imu_trial <- function(fs = 200, stride_length = 1.40, clearance = 0.10,
                                pitch_max = 0.70, stance_s = 0.30, swing_s = 0.40,
                                n_strides = 6, g = 9.81) {
  qconj <- function(q) c(q[1], -q[2], -q[3], -q[4])
  qrot <- function(q, v) {
    # rotate vector v by quaternion q (w, x, y, z)
    t <- 2 * c(q[3] * v[3] - q[4] * v[2],
               q[4] * v[1] - q[2] * v[3],
               q[2] * v[2] - q[3] * v[1])
    v + q[1] * t + c(q[3] * t[3] - q[4] * t[2],
                     q[4] * t[1] - q[2] * t[3],
                     q[2] * t[2] - q[3] * t[1])
  }
  ns <- round(stance_s * fs)
  nw <- round(swing_s * fs)
  A <- NULL; G <- NULL; st <- NULL; Q <- NULL
  push <- function(a, gy, s, q) {
    A <<- rbind(A, a); G <<- rbind(G, gy); st <<- c(st, s); Q <<- rbind(Q, q)
  }
  stance <- function() {
    push(matrix(rep(c(0, 0, -g), each = ns), ns, 3), matrix(0, ns, 3),
         rep(TRUE, ns), matrix(rep(c(1, 0, 0, 0), each = ns), ns, 4))
  }
  swing <- function() {
    s <- (0:(nw - 1)) / nw
    ax <- stride_length * 2 * pi * sin(2 * pi * s) / swing_s^2
    az <- clearance * 2 * pi^2 * cos(2 * pi * s) / swing_s^2
    th <- pitch_max * sin(pi * s)
    thd <- pitch_max * pi * cos(pi * s) / swing_s
    a <- matrix(0, nw, 3); gy <- matrix(0, nw, 3); q <- matrix(0, nw, 4)
    for (i in seq_len(nw)) {
      qi <- c(cos(th[i] / 2), 0, sin(th[i] / 2), 0)
      q[i, ] <- qi
      a[i, ] <- qrot(qconj(qi), c(ax[i], 0, az[i]) + c(0, 0, -g))
      gy[i, ] <- c(0, thd[i], 0)
    }
    push(a, gy, rep(FALSE, nw), q)
  }
  stance()
  for (k in seq_len(n_strides)) { swing(); stance() }
  list(accel = A, gyro = G, stance = st, q = Q, fs = fs,
       stride_length = stride_length, clearance = clearance)
}

test_that("detectStanceZUPT (magnitude) agrees with ground-truth stance", {
  tr <- .make_foot_imu_trial()
  det <- detectStanceZUPT(tr$accel, tr$gyro, tr$fs)
  expect_type(det, "logical")
  expect_length(det, nrow(tr$accel))
  expect_gt(mean(det == tr$stance), 0.98)
})

test_that("detectStanceZUPT (shoe) detects the stance phases", {
  tr <- .make_foot_imu_trial()
  det <- detectStanceZUPT(tr$accel, tr$gyro, tr$fs, method = "shoe")
  expect_length(det, nrow(tr$accel))
  # captures the bulk of true stance and excludes most swing (the centred
  # window naturally blurs a few samples at each stance/swing boundary)
  expect_gt(mean(det[tr$stance]), 0.8)
  expect_lt(mean(det[!tr$stance]), 0.1)
})

test_that("strapdownIntegrate resets velocity to zero at every stance (ZUPT)", {
  tr <- .make_foot_imu_trial()
  # feed the clean world-frame acceleration via the true orientation
  res <- footImuGait(tr$accel, tr$gyro, tr$fs, orientation = tr$q,
                     stance = tr$stance)
  vmag <- sqrt(rowSums(res$velocity^2))
  expect_lt(max(vmag[tr$stance]), 1e-6)   # velocity ~ 0 through stance
})

test_that("strapdownIntegrate errors when there are no stance samples", {
  expect_error(
    strapdownIntegrate(matrix(0, 10, 3), 100, rep(FALSE, 10)),
    "No stance samples")
})

test_that("footImuGait reconstructs stride length within 5% (after ZUPT)", {
  tr <- .make_foot_imu_trial()
  # ZUPT / integration accuracy with a reliable orientation
  res <- footImuGait(tr$accel, tr$gyro, tr$fs, orientation = tr$q)
  expect_s3_class(res, "imu_gait")
  expect_gte(nrow(res$strides), 5)
  err <- abs(res$strides$stride_length - tr$stride_length) / tr$stride_length
  expect_true(all(err < 0.05))
  # clearance recovered to within a couple of cm
  expect_true(all(abs(res$strides$foot_clearance - tr$clearance) < 0.02))
})

test_that("footImuGait end-to-end (internal orientation) is within 5%", {
  tr <- .make_foot_imu_trial()
  res <- footImuGait(tr$accel, tr$gyro, tr$fs)   # default gyro-dominant beta
  err <- abs(res$strides$stride_length - tr$stride_length) / tr$stride_length
  expect_true(all(err < 0.05))
  # per-stride drift bounded: velocity returns to ~0 at each detected stance
  vmag <- sqrt(rowSums(res$velocity^2))
  expect_lt(max(vmag[res$stance]), 1e-6)
})

test_that("footImuGait returns sensible spatiotemporal parameters", {
  tr <- .make_foot_imu_trial()
  res <- footImuGait(tr$accel, tr$gyro, tr$fs, orientation = tr$q)
  s <- res$strides
  expect_true(all(c("stride", "stride_length", "foot_clearance", "stance_time",
                    "swing_time", "stride_time", "gait_velocity") %in% names(s)))
  # gait velocity == stride length / stride time
  expect_equal(s$gait_velocity, s$stride_length / s$stride_time, tolerance = 1e-8)
  # stride time ~ stance + swing durations (~0.7 s)
  expect_true(median(s$stride_time) > 0.6 && median(s$stride_time) < 0.8)
})

test_that("print.imu_gait summarises the result", {
  tr <- .make_foot_imu_trial()
  res <- footImuGait(tr$accel, tr$gyro, tr$fs, orientation = tr$q)
  expect_output(print(res), "imu_gait")
  expect_output(print(res), "strides")
})

test_that("footImuGait validates its inputs", {
  tr <- .make_foot_imu_trial()
  expect_error(footImuGait(tr$accel[, 1:2], tr$gyro, tr$fs), "n x 3")
  expect_error(footImuGait(tr$accel, tr$gyro, -1), "positive")
  expect_error(footImuGait(tr$accel, tr$gyro, tr$fs, vertical_axis = 4),
               "vertical_axis")
  expect_error(
    footImuGait(tr$accel, tr$gyro, tr$fs, stance = rep(TRUE, 3)),
    "length")
})

# --- regression test for adversarial-review finding (WS4-06) ------------------

test_that("a single stance sample de-drifts without crashing (one approx knot)", {
  set.seed(1)
  n <- 10
  a <- matrix(stats::rnorm(n * 3), n, 3)
  stance <- rep(FALSE, n)
  stance[5] <- TRUE
  si <- strapdownIntegrate(a, 100, stance)
  expect_false(any(is.na(si$velocity)))
  # velocity is forced to zero at the single stance sample
  expect_lt(max(abs(si$velocity[5, ])), 1e-12)

  # end-to-end footImuGait with a single-stance vector also survives
  q <- matrix(rep(c(1, 0, 0, 0), each = n), n, 4)
  expect_silent(footImuGait(a, matrix(0, n, 3), 100, orientation = q,
                            stance = stance))
})
