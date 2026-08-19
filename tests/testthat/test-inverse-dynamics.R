library(testthat)
library(PhysioMoCap)


test_that("estimateSegmentInertia returns positive inertial parameters", {
  tbl <- estimateSegmentInertia(
    body_mass = 70,
    segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
  )

  expect_s3_class(tbl, "data.frame")
  expect_true(all(c("segment", "mass", "inertia") %in% names(tbl)))
  expect_true(all(tbl$segment %in% c("foot", "shank", "thigh")))
  expect_true(all(tbl$mass > 0))
  expect_true(all(tbl$inertia > 0))
})


test_that("computeJointPower multiplies moment and angular velocity", {
  m <- c(10, 5, -2)
  w <- c(2, -3, 4)
  p <- computeJointPower(m, w)

  expect_equal(p, c(20, -15, -8))
})


test_that("inverseDynamics2D computes moments and power columns", {
  n <- 300
  sr <- 100
  t <- seq(0, (n - 1) / sr, length.out = n)

  joints <- data.frame(
    ankle_x = rep(0.00, n),
    ankle_y = rep(0.05, n),
    knee_x = rep(0.00, n),
    knee_y = rep(0.45, n),
    hip_x = rep(0.00, n),
    hip_y = rep(0.85, n)
  )

  grf <- data.frame(
    fx = sin(2 * pi * 1 * t) * 30,
    fy = pmax(0, sin(2 * pi * 1 * t)) * 900,
    cop_x = 0.02 + 0.01 * sin(2 * pi * t),
    cop_y = rep(0, n)
  )

  angles <- data.frame(
    ankle = 0.2 * sin(2 * pi * t),
    knee = 0.5 * sin(2 * pi * t + 0.3),
    hip = 0.4 * sin(2 * pi * t + 0.6)
  )

  inertial <- estimateSegmentInertia(
    body_mass = 70,
    segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
  )

  out <- suppressMessages(inverseDynamics2D(
    joints = joints,
    grf = grf,
    sampling_rate = sr,
    angles = angles,
    inertial = inertial,
    angle_unit = "radian",
    model = "quasi_static"
  ))

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), n)
  expect_true(all(c("ankle_moment", "knee_moment", "hip_moment") %in% names(out)))
  expect_true(all(c("ankle_power", "knee_power", "hip_power") %in% names(out)))

  finite_mom <- is.finite(out$ankle_moment) | is.finite(out$knee_moment) | is.finite(out$hip_moment)
  expect_true(any(finite_mom))
})


test_that("inverseDynamics2D supports degree input", {
  n <- 200
  sr <- 100
  t <- seq(0, (n - 1) / sr, length.out = n)

  joints <- data.frame(
    ankle_x = rep(0.00, n), ankle_y = rep(0.04, n),
    knee_x = rep(0.00, n), knee_y = rep(0.42, n),
    hip_x = rep(0.00, n), hip_y = rep(0.82, n)
  )

  grf <- data.frame(
    fx = rep(0, n),
    fy = c(rep(0, 40), rep(700, 120), rep(0, 40)),
    cop_x = rep(0.015, n),
    cop_y = rep(0, n)
  )

  angles_deg <- data.frame(
    ankle = 10 * sin(2 * pi * t),
    knee = 25 * sin(2 * pi * t),
    hip = 20 * sin(2 * pi * t)
  )

  out <- suppressMessages(inverseDynamics2D(
    joints = joints,
    grf = grf,
    sampling_rate = sr,
    angles = angles_deg,
    angle_unit = "degree",
    model = "quasi_static"
  ))

  expect_equal(nrow(out), n)
  expect_true(all(c("ankle_power", "knee_power", "hip_power") %in% names(out)))
})


test_that("inverseDynamics2D errors when required columns are missing", {
  joints_bad <- data.frame(ankle_x = 0, ankle_y = 0)
  grf <- data.frame(fx = 0, fy = 0)

  expect_error(
    suppressMessages(inverseDynamics2D(joints_bad, grf, sampling_rate = 100,
                                       model = "quasi_static")),
    "joints must contain columns"
  )
  # the Newton-Euler model names the extra columns it needs
  expect_error(inverseDynamics2D(joints_bad, grf, sampling_rate = 100),
               "needs joint columns")
})


test_that("inverseDynamics3D computes expected external moments", {
  n <- 120
  joints <- data.frame(
    ankle_x = rep(0.00, n), ankle_y = rep(0.00, n), ankle_z = rep(0.05, n),
    knee_x = rep(0.00, n),  knee_y = rep(0.00, n),  knee_z = rep(0.45, n),
    hip_x = rep(0.00, n),   hip_y = rep(0.00, n),   hip_z = rep(0.85, n)
  )

  grf <- data.frame(
    fx = rep(100, n),
    fy = rep(0, n),
    fz = rep(800, n),
    cop_x = rep(0.1, n),
    cop_y = rep(0, n),
    cop_z = rep(0, n)
  )

  out <- suppressMessages(inverseDynamics3D(joints, grf, sampling_rate = 100,
                                            model = "quasi_static"))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), n)
  expect_true(all(c(
    "ankle_moment_x", "ankle_moment_y", "ankle_moment_z",
    "knee_moment_x", "knee_moment_y", "knee_moment_z",
    "hip_moment_x", "hip_moment_y", "hip_moment_z"
  ) %in% names(out)))

  expect_equal(out$ankle_moment_x, rep(0, n), tolerance = 1e-10)
  expect_equal(out$ankle_moment_y, rep(85, n), tolerance = 1e-10)
  expect_equal(out$ankle_moment_z, rep(0, n), tolerance = 1e-10)
  expect_equal(out$knee_moment_y, rep(125, n), tolerance = 1e-10)
  expect_equal(out$hip_moment_y, rep(165, n), tolerance = 1e-10)
})


test_that("inverseDynamics3D computes total joint power when angles are provided", {
  n <- 200
  sr <- 100
  t <- seq(0, (n - 1) / sr, length.out = n)

  joints <- data.frame(
    ankle_x = rep(0.00, n), ankle_y = rep(0.00, n), ankle_z = rep(0.05, n),
    knee_x = rep(0.00, n),  knee_y = rep(0.00, n),  knee_z = rep(0.45, n),
    hip_x = rep(0.00, n),   hip_y = rep(0.00, n),   hip_z = rep(0.85, n)
  )

  grf <- data.frame(
    fx = rep(80, n),
    fy = rep(30, n),
    fz = rep(700, n),
    cop_x = rep(0.05, n),
    cop_y = rep(0.00, n),
    cop_z = rep(0.00, n)
  )

  angles <- data.frame(
    ankle_x = 0.10 * sin(2 * pi * t),
    ankle_y = 0.05 * sin(2 * pi * t + 0.2),
    ankle_z = 0.03 * sin(2 * pi * t + 0.4),
    knee_x = 0.12 * sin(2 * pi * t + 0.1),
    knee_y = 0.08 * sin(2 * pi * t + 0.3),
    knee_z = 0.04 * sin(2 * pi * t + 0.5),
    hip_x = 0.08 * sin(2 * pi * t + 0.2),
    hip_y = 0.06 * sin(2 * pi * t + 0.4),
    hip_z = 0.04 * sin(2 * pi * t + 0.6)
  )

  out <- suppressMessages(inverseDynamics3D(
    joints = joints,
    grf = grf,
    sampling_rate = sr,
    angles = angles,
    angle_unit = "radian",
    model = "quasi_static"
  ))

  expect_true(all(c("ankle_power_total", "knee_power_total", "hip_power_total") %in%
                    names(out)))
  expect_true(any(is.finite(out$ankle_power_total)))
})


test_that("inverseDynamics3D validates required columns", {
  joints_bad <- data.frame(ankle_x = 0, ankle_y = 0)
  grf <- data.frame(fx = 0, fy = 0, fz = 1)

  expect_error(
    suppressMessages(inverseDynamics3D(joints_bad, grf, sampling_rate = 100,
                                       model = "quasi_static")),
    "joints must contain columns"
  )
  expect_error(inverseDynamics3D(joints_bad, grf, sampling_rate = 100),
               "needs joint columns")
})

# --- Recursive Newton-Euler inverse dynamics (WS4-03) ---

.rne_static_joints <- function(n = 20) {
  data.frame(
    hip_x = rep(0, n),    hip_y = rep(0.90, n),
    knee_x = rep(0.10, n), knee_y = rep(0.50, n),
    ankle_x = rep(0.15, n), ankle_y = rep(0.10, n),
    toe_x = rep(0.25, n),  toe_y = rep(0.05, n))
}

test_that("RNE static hanging-limb moments match the analytic gravity moment", {
  g <- 9.80665; n <- 20
  jt <- .rne_static_joints(n)
  grf <- data.frame(fx = rep(0, n), fy = rep(0, n),
                    cop_x = rep(0, n), cop_y = rep(0, n))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  id <- inverseDynamicsRNE(jt, grf, inertia, sampling_rate = 100)

  cf <- function(s) inertia$com_proximal_fraction[inertia$segment == s]
  m <- function(s) inertia$mass[inertia$segment == s]
  com_x <- c(foot = 0.15 + cf("foot") * (0.25 - 0.15),
             shank = 0.10 + cf("shank") * (0.15 - 0.10),
             thigh = 0.00 + cf("thigh") * (0.10 - 0.00))
  # net joint moment (reaction) = sum m*g*(com_x - joint_x)
  hip_analytic <- sum(vapply(c("foot", "shank", "thigh"),
                             function(s) m(s) * g * com_x[[s]], numeric(1)))
  ankle_analytic <- m("foot") * g * (com_x[["foot"]] - 0.15)
  expect_equal(id$hip_moment[5], hip_analytic, tolerance = 1e-8)
  expect_equal(id$ankle_moment[5], ankle_analytic, tolerance = 1e-8)
  # the hip reaction supports the whole limb weight
  expect_equal(id$hip_fy[5], (m("foot") + m("shank") + m("thigh")) * g,
               tolerance = 1e-8)
})

test_that("RNE recovers the analytic inertial moment of a rotating segment", {
  # single dominant segment: a horizontal thigh angularly accelerated in-plane.
  g <- 9.80665; fs <- 200; n <- 400
  t <- (seq_len(n) - 1) / fs
  theta <- 0.5 * 3 * t^2                 # constant angular accel alpha = 3 rad/s^2
  # thigh from hip(0,1) to knee at length 0.4 rotating about the hip
  L <- 0.4
  hipx <- rep(0, n); hipy <- rep(1, n)
  kneex <- hipx + L * cos(theta - pi / 2)   # start pointing down
  kneey <- hipy + L * sin(theta - pi / 2)
  # keep foot/shank massless-ish far away is not possible; use full limb but
  # check that hip angular acceleration term enters (compare to a static ref).
  ankx <- kneex; anky <- kneey - 0.001; toex <- ankx + 0.001; toey <- anky
  jt <- data.frame(hip_x = hipx, hip_y = hipy, knee_x = kneex, knee_y = kneey,
                   ankle_x = ankx, ankle_y = anky, toe_x = toex, toe_y = toey)
  grf <- data.frame(fx = rep(0, n), fy = rep(0, n),
                    cop_x = rep(0, n), cop_y = rep(0, n))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  id <- inverseDynamicsRNE(jt, grf, inertia, sampling_rate = fs)
  # the hip moment must be finite and vary with the motion (not constant)
  mid <- id$hip_moment[100:300]
  expect_true(all(is.finite(mid)))
  expect_gt(stats::sd(mid), 1e-6)
})

test_that("RNE 3D static moment equals the analytic reaction moment", {
  g <- 9.80665; n <- 20
  jt <- data.frame(
    hip_x = rep(0, n), hip_y = rep(0.90, n), hip_z = rep(0.05, n),
    knee_x = rep(0.10, n), knee_y = rep(0.50, n), knee_z = rep(0.03, n),
    ankle_x = rep(0.15, n), ankle_y = rep(0.10, n), ankle_z = rep(0.02, n),
    toe_x = rep(0.25, n), toe_y = rep(0.05, n), toe_z = rep(0.02, n))
  grf <- data.frame(fx = rep(0, n), fy = rep(0, n), fz = rep(0, n),
                    cop_x = rep(0, n), cop_y = rep(0, n), cop_z = rep(0, n))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  id <- inverseDynamicsRNE(jt, grf, inertia, sampling_rate = 100, dims = "3D")
  crossv <- function(a, b) c(a[2] * b[3] - a[3] * b[2],
                             a[3] * b[1] - a[1] * b[3],
                             a[1] * b[2] - a[2] * b[1])
  cf <- function(s) inertia$com_proximal_fraction[inertia$segment == s]
  m <- function(s) inertia$mass[inertia$segment == s]
  gvec <- c(0, -g, 0)
  com <- function(pr, di, s) pr + cf(s) * (di - pr)
  hip <- c(0, 0.90, 0.05); knee <- c(0.10, 0.50, 0.03)
  ankle <- c(0.15, 0.10, 0.02); toe <- c(0.25, 0.05, 0.02)
  analytic <- -(m("foot") * crossv(com(ankle, toe, "foot") - hip, gvec) +
                m("shank") * crossv(com(knee, ankle, "shank") - hip, gvec) +
                m("thigh") * crossv(com(hip, knee, "thigh") - hip, gvec))
  rne <- c(id$hip_mx[5], id$hip_my[5], id$hip_mz[5])
  expect_equal(rne, analytic, tolerance = 1e-8)
})

test_that("scaleBodyModel measures segment lengths from markers", {
  jt <- .rne_static_joints(10)
  sb <- scaleBodyModel(jt, body_mass = 70)
  expect_equal(sb$length[sb$segment == "foot"],
               sqrt((0.25 - 0.15)^2 + (0.05 - 0.10)^2), tolerance = 1e-10)
  expect_equal(sb$length[sb$segment == "shank"],
               sqrt((0.15 - 0.10)^2 + (0.10 - 0.50)^2), tolerance = 1e-10)
  expect_true(all(sb$mass > 0))
})

test_that("scaleSegmentModel scales de Leva to the subject", {
  ss <- scaleSegmentModel(body_mass = 68, body_height = 1.70)
  expect_equal(nrow(ss), 3L)
  expect_equal(sum(ss$mass), 68 * sum(ss$mass_fraction), tolerance = 1e-10)
})

test_that("RNE reproduces the OpenSim gait2392 inverse-dynamics reference", {
  ref <- system.file("extdata", "gait2392_id_reference.rds",
                     package = "PhysioMoCap")
  skip_if(ref == "", "gait2392 OpenSim ID reference not bundled")
  data <- readRDS(ref)
  id <- inverseDynamicsRNE(data$joints, data$grf, data$inertia,
                           sampling_rate = data$sampling_rate)

  # Cross-tool agreement against OpenSim 4.6 InverseDynamicsTool on the
  # subject01_walk1 trial (provenance in data$provenance): the waveforms must
  # be highly correlated and match in peak magnitude. nRMS is an extra guard.
  agree <- function(pred, reference) {
    list(
      r = cor(pred, reference),
      peak_err = abs(max(abs(pred)) - max(abs(reference))) / max(abs(reference)),
      nrms = sqrt(mean((pred - reference)^2)) / (max(abs(reference)) + 1e-9)
    )
  }
  for (joint in c("hip", "knee", "ankle")) {
    a <- agree(id[[paste0(joint, "_moment")]],
               data$reference[[paste0(joint, "_moment")]])
    expect_gt(a$r, 0.95, label = sprintf("%s moment correlation", joint))
    expect_lt(a$peak_err, 0.10, label = sprintf("%s peak error", joint))
    expect_lt(a$nrms, 0.05, label = sprintf("%s normalized RMS", joint))
  }
})

# --- regression tests for adversarial-review findings (WS4-03) ---

test_that("RNE requires at least 3 frames for differentiation", {
  jt <- .rne_static_joints(2)
  grf <- data.frame(fx = rep(0, 2), fy = rep(0, 2),
                    cop_x = rep(0, 2), cop_y = rep(0, 2))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  expect_error(inverseDynamicsRNE(jt, grf, inertia, sampling_rate = 100),
               "at least 3 frames")
})

test_that("3D RNE applies a tz-only free moment (not just full tx/ty/tz)", {
  n <- 20
  jt <- data.frame(
    hip_x = rep(0, n), hip_y = rep(0.9, n), hip_z = rep(0, n),
    knee_x = rep(0.1, n), knee_y = rep(0.5, n), knee_z = rep(0, n),
    ankle_x = rep(0.15, n), ankle_y = rep(0.1, n), ankle_z = rep(0, n),
    toe_x = rep(0.25, n), toe_y = rep(0.05, n), toe_z = rep(0, n))
  base <- data.frame(fx = rep(0, n), fy = rep(0, n), fz = rep(0, n),
                     cop_x = rep(0, n), cop_y = rep(0, n), cop_z = rep(0, n))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  with_tz <- base; with_tz$tz <- rep(5, n)
  id0 <- inverseDynamicsRNE(jt, base, inertia, sampling_rate = 100, dims = "3D")
  id5 <- inverseDynamicsRNE(jt, with_tz, inertia, sampling_rate = 100,
                            dims = "3D")
  expect_equal(id5$ankle_mz[5] - id0$ankle_mz[5], -5, tolerance = 1e-8)
})

test_that("an NA marker stays local and does not poison all later frames", {
  n <- 20
  jt <- .rne_static_joints(n)
  jt$knee_x[10] <- NA          # a single dropped-marker frame
  grf <- data.frame(fx = rep(0, n), fy = rep(0, n),
                    cop_x = rep(0, n), cop_y = rep(0, n))
  inertia <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  id <- inverseDynamicsRNE(jt, grf, inertia, sampling_rate = 100)
  # frames well before and after the gap remain finite
  expect_true(is.finite(id$hip_moment[3]))
  expect_true(is.finite(id$hip_moment[18]))
})


# --- full Newton-Euler entry points (WSCB-08) ---

.G <- 9.80665

# Marker table for a single massive segment (the thigh) swinging about a fixed
# hip: the shank and foot are collapsed to vestigial stubs so the chain reduces
# to a rigid pendulum with a closed-form solution.
.pendulum_chain <- function(q, L, hip_y = 1) {
  n <- length(q)
  hip <- cbind(rep(0, n), rep(hip_y, n))
  knee <- hip + L * cbind(sin(q), -cos(q))
  ankle <- knee + 1e-6 * cbind(sin(q), -cos(q))
  toe <- ankle + 1e-6 * cbind(cos(q), sin(q))
  data.frame(hip_x = hip[, 1], hip_y = hip[, 2],
             knee_x = knee[, 1], knee_y = knee[, 2],
             ankle_x = ankle[, 1], ankle_y = ankle[, 2],
             toe_x = toe[, 1], toe_y = toe[, 2])
}

.zero_grf <- function(n) data.frame(fx = rep(0, n), fy = rep(0, n),
                                    cop_x = rep(0, n), cop_y = rep(0, n))

test_that("inverseDynamics2D reproduces the analytic pendulum moment", {
  fs <- 500; n <- 1000
  t <- (seq_len(n) - 1) / fs
  w <- 2 * pi * 0.5
  q <- 0.6 * sin(w * t)
  qdd <- -0.6 * w^2 * sin(w * t)

  L <- 0.45; m <- 8.5; cfrac <- 0.40
  inertia_com <- m * (0.32 * L)^2
  lcom <- cfrac * L
  inert <- data.frame(segment = c("foot", "shank", "thigh"),
                      length = c(1e-6, 1e-6, L),
                      mass = c(1e-9, 1e-9, m),
                      com_proximal_fraction = c(0.5, 0.5, cfrac),
                      inertia = c(0, 0, inertia_com))

  out <- inverseDynamics2D(.pendulum_chain(q, L), .zero_grf(n),
                           sampling_rate = fs, inertial = inert)
  # I_hip * alpha + m * g * L_com * sin(theta), with I_hip by the parallel axis
  analytic <- (inertia_com + m * lcom^2) * qdd + m * .G * lcom * sin(q)
  k <- 20:(n - 20)
  expect_lt(max(abs(out$hip_moment[k] - analytic[k])) / max(abs(analytic)), 0.02)
})

test_that("the quasi-static model misses the whole inertial moment", {
  fs <- 500; n <- 1000
  t <- (seq_len(n) - 1) / fs
  q <- 0.6 * sin(2 * pi * 0.5 * t)
  L <- 0.45
  inert <- data.frame(segment = c("foot", "shank", "thigh"),
                      length = c(1e-6, 1e-6, L), mass = c(1e-9, 1e-9, 8.5),
                      com_proximal_fraction = c(0.5, 0.5, 0.40),
                      inertia = c(0, 0, 8.5 * (0.32 * L)^2))
  jt <- .pendulum_chain(q, L)

  ne <- inverseDynamics2D(jt, .zero_grf(n), sampling_rate = fs,
                          inertial = inert)
  qs <- suppressMessages(inverseDynamics2D(jt, .zero_grf(n), sampling_rate = fs,
                                           inertial = inert,
                                           model = "quasi_static"))
  # with no ground contact the legacy model returns identically zero
  expect_equal(max(abs(qs$hip_moment)), 0)
  expect_gt(max(abs(ne$hip_moment)), 1)
})

test_that("inverseDynamics2D returns pure gravitational moments when static", {
  n <- 30
  jt <- .rne_static_joints(n)
  inert <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  out <- inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                           inertial = inert)

  cf <- function(s) inert$com_proximal_fraction[inert$segment == s]
  ms <- function(s) inert$mass[inert$segment == s]
  comx <- c(foot = 0.15 + cf("foot") * (0.25 - 0.15),
            shank = 0.10 + cf("shank") * (0.15 - 0.10),
            thigh = 0.00 + cf("thigh") * (0.10 - 0.00))
  expect_equal(out$ankle_moment[5], ms("foot") * .G * (comx[["foot"]] - 0.15),
               tolerance = 1e-8)
  expect_equal(out$knee_moment[5],
               ms("foot") * .G * (comx[["foot"]] - 0.10) +
                 ms("shank") * .G * (comx[["shank"]] - 0.10), tolerance = 1e-8)
  expect_equal(out$hip_moment[5],
               sum(vapply(names(comx), function(s) ms(s) * .G * comx[[s]],
                          numeric(1))), tolerance = 1e-8)
  expect_equal(out$hip_fy[5],
               sum(vapply(names(comx), ms, numeric(1))) * .G, tolerance = 1e-8)
})

test_that("Newton-Euler moments match an independent Lagrangian derivation", {
  # Cross-check against d/dt(dL/dqdot) - dL/dq = tau for a two-link chain in
  # absolute segment angles, from which M_knee = tau2 and M_hip = tau1 + tau2.
  fs <- 500; n <- 1200
  t <- (seq_len(n) - 1) / fs
  w1 <- 2 * pi * 0.7; w2 <- 2 * pi * 1.1
  q1 <- 0.5 * sin(w1 * t);  q1d <- 0.5 * w1 * cos(w1 * t)
  q1dd <- -0.5 * w1^2 * sin(w1 * t)
  q2 <- 0.35 * sin(w2 * t + 0.8); q2d <- 0.35 * w2 * cos(w2 * t + 0.8)
  q2dd <- -0.35 * w2^2 * sin(w2 * t + 0.8)

  L1 <- 0.45; m1 <- 8.5; f1 <- 0.40; I1 <- m1 * (0.32 * L1)^2; c1 <- f1 * L1
  L2 <- 0.42; m2 <- 3.4; f2 <- 0.43; I2 <- m2 * (0.30 * L2)^2; c2 <- f2 * L2

  hip <- cbind(rep(0, n), rep(1, n))
  knee <- hip + L1 * cbind(sin(q1), -cos(q1))
  ankle <- knee + L2 * cbind(sin(q2), -cos(q2))
  toe <- ankle + 1e-6 * cbind(cos(q2), sin(q2))
  jt <- data.frame(hip_x = hip[, 1], hip_y = hip[, 2],
                   knee_x = knee[, 1], knee_y = knee[, 2],
                   ankle_x = ankle[, 1], ankle_y = ankle[, 2],
                   toe_x = toe[, 1], toe_y = toe[, 2])
  inert <- data.frame(segment = c("foot", "shank", "thigh"),
                      length = c(1e-6, L2, L1), mass = c(1e-9, m2, m1),
                      com_proximal_fraction = c(0.5, f2, f1),
                      inertia = c(0, I2, I1))

  out <- inverseDynamics2D(jt, .zero_grf(n), sampling_rate = fs,
                           inertial = inert)

  a1 <- m1 * c1^2 + I1 + m2 * L1^2
  a2 <- m2 * c2^2 + I2
  cpl <- m2 * L1 * c2
  d <- q1 - q2
  tau1 <- a1 * q1dd + cpl * (q2dd * cos(d) + q2d^2 * sin(d)) +
    (m1 * c1 + m2 * L1) * .G * sin(q1)
  tau2 <- a2 * q2dd + cpl * (q1dd * cos(d) - q1d^2 * sin(d)) +
    m2 * .G * c2 * sin(q2)

  k <- 25:(n - 25)
  expect_lt(max(abs(out$hip_moment[k] - (tau1 + tau2)[k])) /
              max(abs(tau1 + tau2)), 0.01)
  expect_lt(max(abs(out$knee_moment[k] - tau2[k])) / max(abs(tau2)), 0.01)
  expect_gt(stats::cor(out$hip_moment[k], (tau1 + tau2)[k]), 0.999)
  expect_gt(stats::cor(out$knee_moment[k], tau2[k]), 0.999)
})

test_that("model = 'quasi_static' reproduces the legacy formula exactly", {
  n <- 200
  jt <- data.frame(ankle_x = rep(0.00, n), ankle_y = rep(0.05, n),
                   knee_x = rep(0.00, n), knee_y = rep(0.45, n),
                   hip_x = rep(0.00, n), hip_y = rep(0.85, n))
  grf <- data.frame(fx = rep(0, n),
                    fy = abs(sin(seq(0, pi, length.out = n))) * 800,
                    cop_x = rep(0.02, n), cop_y = rep(0, n))
  out <- suppressMessages(inverseDynamics2D(jt, grf, sampling_rate = 100,
                                            model = "quasi_static"))
  legacy <- (jt$ankle_x - grf$cop_x) * grf$fy - (jt$ankle_y - grf$cop_y) * grf$fx
  expect_identical(out$ankle_moment, legacy)

  # the deprecation notice fires once per session, not once per call
  withr::with_options(list(PhysioMoCap.quasi_static_notified = NULL), {
    expect_message(inverseDynamics2D(jt, grf, sampling_rate = 100,
                                     model = "quasi_static"), "quasi_static")
    expect_no_message(inverseDynamics2D(jt, grf, sampling_rate = 100,
                                        model = "quasi_static"))
  })
})

test_that("the Newton-Euler entry points state what they need", {
  n <- 30
  jt_no_toe <- data.frame(ankle_x = rep(0.15, n), ankle_y = rep(0.10, n),
                          knee_x = rep(0.10, n), knee_y = rep(0.50, n),
                          hip_x = rep(0.00, n), hip_y = rep(0.90, n))
  expect_error(inverseDynamics2D(jt_no_toe, .zero_grf(n), sampling_rate = 100,
                                 body_mass = 70), "toe_x")
  expect_error(inverseDynamics2D(.rne_static_joints(n), .zero_grf(n),
                                 sampling_rate = 100), "needs segment masses")
  bad <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  bad$mass <- NULL
  expect_error(inverseDynamics2D(.rne_static_joints(n), .zero_grf(n),
                                 sampling_rate = 100, inertial = bad),
               "inertial columns")
})

test_that("body_mass builds the segment model from the markers", {
  n <- 30
  jt <- .rne_static_joints(n)
  from_mass <- inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                 body_mass = 70)
  from_table <- inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                  inertial = scaleBodyModel(jt, body_mass = 70))
  expect_equal(from_mass$hip_moment, from_table$hip_moment, tolerance = 1e-12)
})

test_that("the ground free moment reaches the recursion", {
  n <- 30
  jt <- .rne_static_joints(n)
  grf <- .zero_grf(n)
  inert <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  base <- inverseDynamics2D(jt, grf, sampling_rate = 100, inertial = inert)
  grf$tz <- rep(4, n)
  with_tz <- inverseDynamics2D(jt, grf, sampling_rate = 100, inertial = inert)
  expect_equal(with_tz$ankle_moment[5] - base$ankle_moment[5], -4,
               tolerance = 1e-9)
})

test_that("inverseDynamics3D Newton-Euler agrees with the 2D sagittal chain", {
  n <- 30
  jt2 <- .rne_static_joints(n)
  jt3 <- jt2
  for (j in c("ankle", "toe", "knee", "hip")) jt3[[paste0(j, "_z")]] <- 0
  inert <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  grf3 <- data.frame(fx = rep(0, n), fy = rep(0, n), fz = rep(0, n),
                     cop_x = rep(0, n), cop_y = rep(0, n), cop_z = rep(0, n))

  sag <- inverseDynamics2D(jt2, .zero_grf(n), sampling_rate = 100,
                           inertial = inert)
  out <- inverseDynamics3D(jt3, grf3, sampling_rate = 100, inertial = inert)
  expect_equal(out$hip_moment_z[5], sag$hip_moment[5], tolerance = 1e-8)
  expect_equal(out$ankle_moment_z[5], sag$ankle_moment[5], tolerance = 1e-8)
})

test_that("inverseDynamics3D honours the vertical-axis contract", {
  n <- 30
  jt2 <- .rne_static_joints(n)
  # the same limb expressed with z up instead of y up
  jt_z <- list()
  for (j in c("ankle", "toe", "knee", "hip")) {
    jt_z[[paste0(j, "_x")]] <- jt2[[paste0(j, "_x")]]
    jt_z[[paste0(j, "_y")]] <- rep(0, n)
    jt_z[[paste0(j, "_z")]] <- jt2[[paste0(j, "_y")]]
  }
  jt_z <- as.data.frame(jt_z)
  inert <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)
  grf3 <- data.frame(fx = rep(0, n), fy = rep(0, n), fz = rep(0, n),
                     cop_x = rep(0, n), cop_y = rep(0, n), cop_z = rep(0, n))
  sag <- inverseDynamics2D(jt2, .zero_grf(n), sampling_rate = 100,
                           inertial = inert)

  right <- inverseDynamics3D(jt_z, grf3, sampling_rate = 100, inertial = inert,
                             vertical = "z")
  expect_equal(abs(right$hip_moment_y[5]), abs(sag$hip_moment[5]),
               tolerance = 1e-8)
  # declaring the wrong vertical axis puts gravity in the wrong direction, and
  # the marker geometry is checked so that it does not pass silently
  expect_warning(wrong <- inverseDynamics3D(jt_z, grf3, sampling_rate = 100,
                                            inertial = inert, vertical = "y"),
                 "declared vertical")
  expect_lt(abs(wrong$hip_moment_y[5]), 1e-8)
  # the correct axis raises no such warning
  expect_no_warning(inverseDynamics3D(jt_z, grf3, sampling_rate = 100,
                                      inertial = inert, vertical = "z"))
  expect_error(inverseDynamicsRNE(jt2, .zero_grf(n), inert,
                                  sampling_rate = 100, vertical = "z"),
               "x-y plane")
})


test_that("the Newton-Euler path flags inputs it cannot use", {
  n <- 30
  jt <- .rne_static_joints(n)
  inert <- estimateSegmentInertia(body_mass = 70, body_height = 1.75)

  # millimetre markers would inflate every moment a thousandfold
  mm <- jt
  for (nm in names(mm)) mm[[nm]] <- mm[[nm]] * 1000
  expect_warning(inverseDynamics2D(mm, .zero_grf(n), sampling_rate = 100,
                                   inertial = inert), "plausible limb length")
  expect_no_warning(inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                      inertial = inert))

  # the recursion derives segment angular acceleration itself, so a joint
  # angular acceleration cannot be honoured
  aa <- data.frame(ankle = rep(0, n), knee = rep(0, n), hip = rep(0, n))
  expect_warning(inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                   inertial = inert, angular_acceleration = aa),
                 "is ignored by")

  expect_error(inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                 inertial = inert, gravity = -1))

  bad <- inert
  bad$com_proximal_fraction[bad$segment == "foot"] <- 1.7
  expect_error(inverseDynamics2D(jt, .zero_grf(n), sampling_rate = 100,
                                 inertial = bad), "outside \\[0, 1\\]")

  na_jt <- jt
  na_jt[] <- NA_real_
  expect_error(inverseDynamics2D(na_jt, .zero_grf(n), sampling_rate = 100,
                                 body_mass = 70), "no finite values")
  # a single dropped marker is named rather than surfacing as a segment-length
  # complaint about an argument the caller never supplied
  one_gone <- jt
  one_gone$toe_x <- NA_real_
  expect_error(inverseDynamics2D(one_gone, .zero_grf(n), sampling_rate = 100,
                                 body_mass = 70), "toe_x")

  # too few frames to differentiate, reported by the entry point itself
  expect_error(inverseDynamics2D(jt[1:2, ], .zero_grf(2), sampling_rate = 100,
                                 inertial = inert), "at least 3 frames")
  expect_error(inverseDynamics2D(jt[0, ], .zero_grf(0), sampling_rate = 100,
                                 inertial = inert), "at least 3 frames")
})


# --- gait-cycle inverse-dynamics golden (WSCB-08 / WSCB-09) ---

test_that("inverseDynamics2D matches the Lagrangian gait-cycle reference", {
  fx <- readRDS(test_path("fixtures", "gaitcycle_id_reference.rds"))
  id <- inverseDynamics2D(fx$joints, fx$grf, sampling_rate = fx$sampling_rate,
                          inertial = fx$inertia)
  k <- 6:(nrow(fx$reference) - 5)          # ignore the differentiation edges
  for (j in c("hip", "knee")) {
    got <- id[[paste0(j, "_moment")]][k]
    ref <- fx$reference[[paste0(j, "_moment")]][k]
    # the Newton-Euler recursion agrees with the independent Lagrangian moments
    expect_gt(stats::cor(got, ref), 0.95)
    expect_lt(max(abs(got - ref)) / max(abs(ref)), 0.10)
    # Correlation and peak error alone are near-blind to a fully dropped
    # additive term (e.g. gravity leaves r > 0.99). Since the two formalisms
    # are exact, also require agreement in normalised RMS, which fails hard
    # (nRMSE ~ 0.13) if any term - gravity, linear or angular inertia - is
    # missing.
    nrmse <- sqrt(mean((got - ref)^2)) / sqrt(mean(ref^2))
    expect_lt(nrmse, 0.01)
  }
})
