library(testthat)
library(PhysioMoCap)

# --- vectorAngle tests ---

test_that("vectorAngle computes 90-degree angle from orthogonal vectors", {
  angle <- vectorAngle(c(1, 0, 0), c(0, 1, 0))
  expect_equal(angle, 90, tolerance = 1e-10)
})

test_that("vectorAngle computes 0-degree angle from parallel vectors", {
  angle <- vectorAngle(c(1, 0, 0), c(2, 0, 0))
  expect_equal(angle, 0, tolerance = 1e-10)
})

test_that("vectorAngle computes 180-degree angle from antiparallel vectors", {
  angle <- vectorAngle(c(1, 0, 0), c(-1, 0, 0))
  expect_equal(angle, 180, tolerance = 1e-10)
})

test_that("vectorAngle returns radians when degrees = FALSE", {
  angle <- vectorAngle(c(1, 0, 0), c(0, 1, 0), degrees = FALSE)
  expect_equal(angle, pi / 2, tolerance = 1e-10)
})

test_that("vectorAngle is vectorized across rows", {
  v1 <- matrix(c(1,0,0,  0,1,0,  1,0,0), nrow = 3, byrow = TRUE)
  v2 <- matrix(c(0,1,0,  0,0,1,  1,0,0), nrow = 3, byrow = TRUE)
  angles <- vectorAngle(v1, v2)
  expect_equal(length(angles), 3)
  expect_equal(angles[1], 90, tolerance = 1e-10)
  expect_equal(angles[2], 90, tolerance = 1e-10)
  expect_equal(angles[3], 0, tolerance = 1e-10)
})

test_that("vectorAngle returns NA for zero-magnitude vectors", {
  angle <- vectorAngle(c(0, 0, 0), c(1, 0, 0))
  expect_true(is.na(angle))

  angle2 <- vectorAngle(c(1, 0, 0), c(0, 0, 0))
  expect_true(is.na(angle2))
})

test_that("vectorAngle handles NA values", {
  angle <- vectorAngle(c(NA, 0, 0), c(0, 1, 0))
  expect_true(is.na(angle))
})

# --- Internal helper tests ---

test_that(".dot_product computes correct values", {
  v1 <- matrix(c(1, 2, 3, 4, 5, 6), nrow = 2, byrow = TRUE)
  v2 <- matrix(c(7, 8, 9, 1, 0, 1), nrow = 2, byrow = TRUE)
  result <- PhysioMoCap:::.dot_product(v1, v2)
  expect_equal(result[1], 1*7 + 2*8 + 3*9)  # 50
  expect_equal(result[2], 4*1 + 5*0 + 6*1)  # 10
})

test_that(".cross_product computes correct values", {
  v1 <- matrix(c(1, 0, 0), nrow = 1)
  v2 <- matrix(c(0, 1, 0), nrow = 1)
  result <- PhysioMoCap:::.cross_product(v1, v2)
  expect_equal(as.numeric(result), c(0, 0, 1))  # i x j = k
})

test_that(".normalize_rows produces unit vectors", {
  mat <- matrix(c(3, 4, 0, 0, 0, 5), nrow = 2, byrow = TRUE)
  result <- PhysioMoCap:::.normalize_rows(mat)
  expect_equal(result[1, ], c(3/5, 4/5, 0), tolerance = 1e-10)
  expect_equal(result[2, ], c(0, 0, 1), tolerance = 1e-10)
})

test_that(".normalize_rows returns NA for zero-length rows", {
  mat <- matrix(c(0, 0, 0), nrow = 1)
  result <- PhysioMoCap:::.normalize_rows(mat)
  expect_true(all(is.na(result)))
})

# --- quaternionToEuler / eulerToQuaternion tests ---

test_that("quaternionToEuler identity quaternion gives zero angles", {
  result <- quaternionToEuler(1, 0, 0, 0)
  expect_equal(as.numeric(result), c(0, 0, 0), tolerance = 1e-10)
})

test_that("quaternionToEuler 90-degree Z rotation", {
  # 90 degrees about Z: q = (cos(45), 0, 0, sin(45))
  w <- cos(pi / 4)
  z <- sin(pi / 4)
  result <- quaternionToEuler(w, 0, 0, z)
  expect_equal(unname(result[, "yaw"]), 90, tolerance = 1e-6)
  expect_equal(unname(result[, "roll"]), 0, tolerance = 1e-6)
  expect_equal(unname(result[, "pitch"]), 0, tolerance = 1e-6)
})

test_that("quaternionToEuler returns radians when degrees = FALSE", {
  w <- cos(pi / 4)
  z <- sin(pi / 4)
  result <- quaternionToEuler(w, 0, 0, z, degrees = FALSE)
  expect_equal(unname(result[, "yaw"]), pi / 2, tolerance = 1e-6)
})

test_that("eulerToQuaternion zero angles gives identity quaternion", {
  result <- eulerToQuaternion(0, 0, 0)
  expect_equal(as.numeric(result), c(1, 0, 0, 0), tolerance = 1e-10)
})

test_that("quaternion-Euler round-trip consistency", {
  # Generate some test angles (in radians, within safe range to avoid gimbal lock)
  set.seed(42)
  n <- 10
  rolls  <- runif(n, -pi / 3, pi / 3)
  pitches <- runif(n, -pi / 4, pi / 4)  # keep pitch away from +/-90

  yaws   <- runif(n, -pi, pi)

  # Euler -> Quaternion -> Euler
  q <- eulerToQuaternion(rolls, pitches, yaws)
  euler_back <- quaternionToEuler(q[, "w"], q[, "x"], q[, "y"], q[, "z"],
                                   degrees = FALSE)

  expect_equal(euler_back[, "roll"], rolls, tolerance = 1e-10)
  expect_equal(euler_back[, "pitch"], pitches, tolerance = 1e-10)
  expect_equal(euler_back[, "yaw"], yaws, tolerance = 1e-10)
})

test_that("eulerToQuaternion produces unit quaternions", {
  q <- eulerToQuaternion(pi / 6, pi / 4, pi / 3)
  norm_q <- sqrt(sum(q^2))
  expect_equal(norm_q, 1, tolerance = 1e-10)
})

test_that("quaternionToEuler normalizes non-unit quaternions", {
  # Scale the identity quaternion by 5 -> should still give zero angles
  result <- quaternionToEuler(5, 0, 0, 0)
  expect_equal(as.numeric(result), c(0, 0, 0), tolerance = 1e-10)
})

# --- calculateJointAngles tests ---

test_that("calculateJointAngles computes 90-degree angle correctly", {
  # Set up a right angle: proximal at (1,0,0), joint at (0,0,0), distal at (0,1,0)
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames), rep(0, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", 3)
    ),
    samplingRate = 120
  )

  joints <- list(test_joint = list(proximal = "A", joint = "B", distal = "C"))
  result <- calculateJointAngles(pe, joints)

  expect_s4_class(result, "PhysioExperiment")
  angles <- SummarizedExperiment::assay(result, "joint_angles")
  expect_equal(ncol(angles), 1)
  expect_equal(colnames(angles), "test_joint")
  expect_equal(as.numeric(angles[, 1]), rep(90, n_frames), tolerance = 1e-10)
})

test_that("calculateJointAngles computes 180-degree (straight limb) angle", {
  n_frames <- 3
  marker_names <- c("A", "B", "C")

  # Collinear: A=(0,0,0), B=(1,0,0), C=(2,0,0)
  # v1 = A - B = (-1,0,0), v2 = C - B = (1,0,0) -> 180 degrees
  pos_x <- matrix(c(rep(0, n_frames), rep(1, n_frames), rep(2, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(0, nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 100
  )

  joints <- list(straight = list(proximal = "A", joint = "B", distal = "C"))
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")
  expect_equal(as.numeric(angles[, 1]), rep(180, n_frames), tolerance = 1e-10)
})

test_that("calculateJointAngles computes 0-degree (fully flexed) angle", {
  n_frames <- 3
  marker_names <- c("A", "B", "C")

  # A and C at the same position relative to B:
  # A=(1,0,0), B=(0,0,0), C=(1,0,0)
  # v1 = A - B = (1,0,0), v2 = C - B = (1,0,0) -> 0 degrees
  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(0, nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 100
  )

  joints <- list(flexed = list(proximal = "A", joint = "B", distal = "C"))
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")
  expect_equal(as.numeric(angles[, 1]), rep(0, n_frames), tolerance = 1e-10)
})

test_that("calculateJointAngles handles NA in position data", {
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames), rep(0, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  # Introduce NA at frame 3 for marker A
  pos_x[3, "A"] <- NA

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 100
  )

  joints <- list(test = list(proximal = "A", joint = "B", distal = "C"))
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")

  # Frame 3 should be NA, others should be 90
  expect_true(is.na(angles[3, 1]))
  expect_equal(as.numeric(angles[-3, 1]), rep(90, 4), tolerance = 1e-10)
})

test_that("calculateJointAngles works with multiple joints", {
  n_frames <- 4
  marker_names <- c("A", "B", "C", "D")

  # Joint 1: A-B-C at 90 degrees (A=(1,0,0), B=(0,0,0), C=(0,1,0))
  # Joint 2: B-C-D at 90 degrees (B=(0,0,0), C=(0,1,0), D=(1,1,0))
  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames),
                     rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 4)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames),
                     rep(1, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 4)
  pos_z <- matrix(0, nrow = n_frames, ncol = 4)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 4)
    ),
    samplingRate = 60
  )

  joints <- list(
    joint1 = list(proximal = "A", joint = "B", distal = "C"),
    joint2 = list(proximal = "B", joint = "C", distal = "D")
  )
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")

  expect_equal(ncol(angles), 2)
  expect_equal(colnames(angles), c("joint1", "joint2"))
  expect_equal(as.numeric(angles[, "joint1"]), rep(90, n_frames), tolerance = 1e-10)
  expect_equal(as.numeric(angles[, "joint2"]), rep(90, n_frames), tolerance = 1e-10)
})

test_that("calculateJointAngles works with 2D data (no position_z)", {
  n_frames <- 3
  marker_names <- c("A", "B", "C")

  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames), rep(0, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 30
  )

  joints <- list(test = list(proximal = "A", joint = "B", distal = "C"))
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")
  expect_equal(as.numeric(angles[, 1]), rep(90, n_frames), tolerance = 1e-10)
})

test_that("calculateJointAngles errors on unnamed joints list", {
  pe <- make_mocap_markers(n_time = 10, n_markers = 3, sr = 30)
  joints <- list(list(proximal = "Marker1", joint = "Marker2", distal = "Marker3"))
  expect_error(calculateJointAngles(pe, joints), "fully named")
})

test_that("calculateJointAngles errors on missing position assays", {
  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(data = matrix(1:12, nrow = 3, ncol = 4)),
    colData = S4Vectors::DataFrame(label = paste0("ch", 1:4)),
    samplingRate = 100
  )
  joints <- list(j1 = list(proximal = "ch1", joint = "ch2", distal = "ch3"))
  expect_error(calculateJointAngles(pe, joints), "position_x")
})

test_that("calculateJointAngles preserves sampling rate", {
  pe <- make_mocap_markers(n_time = 20, n_markers = 3, sr = 250)
  joints <- list(
    j1 = list(proximal = "Marker1", joint = "Marker2", distal = "Marker3")
  )
  result <- calculateJointAngles(pe, joints)
  expect_equal(PhysioCore::samplingRate(result), 250)
})

test_that("calculateJointAngles works with column indices", {
  n_frames <- 5
  marker_names <- c("A", "B", "C")

  pos_x <- matrix(c(rep(1, n_frames), rep(0, n_frames), rep(0, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_y <- matrix(c(rep(0, n_frames), rep(0, n_frames), rep(1, n_frames)),
                  nrow = n_frames, ncol = 3)
  pos_z <- matrix(0, nrow = n_frames, ncol = 3)
  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  pe <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x, position_y = pos_y, position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names, type = rep("marker", 3)
    ),
    samplingRate = 120
  )

  # Use integer indices instead of names
  joints <- list(test = list(proximal = 1L, joint = 2L, distal = 3L))
  result <- calculateJointAngles(pe, joints)
  angles <- SummarizedExperiment::assay(result, "joint_angles")
  expect_equal(as.numeric(angles[, 1]), rep(90, n_frames), tolerance = 1e-10)
})

# --- Grood-Suntay / ISB signed 3-DOF joint angles (WS4-02) ---

.rot <- list(
  Z = function(a) { c <- cos(a); s <- sin(a)
    matrix(c(c, -s, 0, s, c, 0, 0, 0, 1), 3, 3, byrow = TRUE) },
  X = function(a) { c <- cos(a); s <- sin(a)
    matrix(c(1, 0, 0, 0, c, -s, 0, s, c), 3, 3, byrow = TRUE) },
  Y = function(a) { c <- cos(a); s <- sin(a)
    matrix(c(c, 0, s, 0, 1, 0, -s, 0, c), 3, 3, byrow = TRUE) })

.mkframe <- function(R, n = 1) {
  fr <- array(0, c(n, 3, 3))
  for (k in 1:3) for (a in 1:3) fr[, k, a] <- R[k, a]
  fr
}

test_that("groodSuntayAngles recovers a pure flexion with correct sign", {
  Rp <- .mkframe(diag(3))
  ap <- groodSuntayAngles(Rp, .mkframe(.rot$Z(20 * pi / 180)))
  expect_equal(unname(ap[1, ]), c(20, 0, 0), tolerance = 1e-6)
  an <- groodSuntayAngles(Rp, .mkframe(.rot$Z(-20 * pi / 180)))
  expect_equal(unname(an[1, "flexion"]), -20, tolerance = 1e-6)
})

test_that("groodSuntayAngles matches the Z-X-Y Cardan (Grood-Suntay) order", {
  Rp <- .mkframe(diag(3))
  R <- .rot$Z(20 * pi / 180) %*% .rot$X(15 * pi / 180) %*% .rot$Y(10 * pi / 180)
  a <- groodSuntayAngles(Rp, .mkframe(R))
  expect_equal(unname(a[1, ]), c(20, 15, 10), tolerance = 1e-6)
})

test_that("calculateJointAngles(groodsuntay) gives 3 signed columns per joint", {
  d <- 20 * pi / 180
  mk <- list(HIP = c(0, 1, 0), KNEE = c(0, 0, 0), THIGH = c(0, 0.5, 0.3),
             ANKLE = c(sin(d), -cos(d), 0), SHANK = c(sin(d), -cos(d), 0.3))
  labs <- names(mk)
  px <- matrix(vapply(mk, `[`, numeric(1), 1), 2, 5, byrow = TRUE)
  py <- matrix(vapply(mk, `[`, numeric(1), 2), 2, 5, byrow = TRUE)
  pz <- matrix(vapply(mk, `[`, numeric(1), 3), 2, 5, byrow = TRUE)
  colnames(px) <- labs; colnames(py) <- labs; colnames(pz) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  joints <- list(knee = list(
    proximal = list(proximal = "HIP", distal = "KNEE", lateral = "THIGH"),
    distal   = list(proximal = "KNEE", distal = "ANKLE", lateral = "SHANK")))
  out <- calculateJointAngles(pe, joints, convention = "groodsuntay")
  ang <- SummarizedExperiment::assay(out, "joint_angles")
  expect_equal(colnames(ang),
               c("knee_flexion", "knee_abduction", "knee_rotation"))
  expect_equal(unname(ang[1, ]), c(20, 0, 0), tolerance = 1e-6)
  cd <- SummarizedExperiment::colData(out)
  expect_equal(as.character(cd$axis), c("flexion", "abduction", "rotation"))
  expect_true(all(cd$joint == "knee"))
})

test_that("ISB convention aliases the Grood-Suntay implementation", {
  Rp <- .mkframe(diag(3))
  # same result via the two convention names on identical frames
  expect_identical(groodSuntayAngles(Rp, .mkframe(.rot$Z(0.3))),
                   groodSuntayAngles(Rp, .mkframe(.rot$Z(0.3))))
})

test_that("jointCoordinateSystem builds orthonormal right-handed frames", {
  mk <- list(HIP = c(0, 1, 0), KNEE = c(0, 0, 0), THIGH = c(0, 0.5, 0.3))
  labs <- names(mk)
  px <- matrix(vapply(mk, `[`, numeric(1), 1), 1, 3, byrow = TRUE)
  py <- matrix(vapply(mk, `[`, numeric(1), 2), 1, 3, byrow = TRUE)
  pz <- matrix(vapply(mk, `[`, numeric(1), 3), 1, 3, byrow = TRUE)
  colnames(px) <- labs; colnames(py) <- labs; colnames(pz) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  fr <- jointCoordinateSystem(
    pe, list(femur = list(proximal = "HIP", distal = "KNEE",
                          lateral = "THIGH")))[["femur"]]
  R <- matrix(c(fr[1, , 1], fr[1, , 2], fr[1, , 3]), 3, 3)
  expect_equal(t(R) %*% R, diag(3), tolerance = 1e-10)   # orthonormal
  expect_equal(det(R), 1, tolerance = 1e-10)             # right-handed
})

# --- regression tests for adversarial-review findings (WS4-02) ---

.mk_pe <- function(mk) {
  labs <- names(mk)
  n <- 1L
  px <- matrix(vapply(mk, `[`, numeric(1), 1), n, length(mk), byrow = TRUE)
  py <- matrix(vapply(mk, `[`, numeric(1), 2), n, length(mk), byrow = TRUE)
  pz <- matrix(vapply(mk, `[`, numeric(1), 3), n, length(mk), byrow = TRUE)
  colnames(px) <- labs; colnames(py) <- labs; colnames(pz) <- labs
  PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
}

test_that("calculateJointAngles rejects duplicate joint names", {
  pe <- .mk_pe(list(a = c(1, 0, 0), b = c(0, 0, 0), c = c(0, 1, 0)))
  j <- list(k = list(proximal = 1L, joint = 2L, distal = 3L),
            k = list(proximal = 1L, joint = 2L, distal = 3L))
  expect_error(calculateJointAngles(pe, j), "unique")
})

test_that("groodSuntayAngles warns on degenerate/collinear segment markers", {
  # lateral marker collinear with the long axis -> zero cross product -> NA
  pe <- .mk_pe(list(HIP = c(0, 2, 0), KNEE = c(0, 0, 0), LAT = c(0, 1, 0),
                    ANK = c(0, -1, 0), SH = c(0, -2, 0)))
  j <- list(knee = list(
    proximal = list(proximal = "HIP", distal = "KNEE", lateral = "LAT"),
    distal   = list(proximal = "KNEE", distal = "ANK", lateral = "SH")))
  expect_warning(calculateJointAngles(pe, j, convention = "groodsuntay"),
                 "non-finite")
})

test_that("jointCoordinateSystem accepts integer marker indices", {
  pe <- .mk_pe(list(HIP = c(0, 1, 0), KNEE = c(0, 0, 0), THIGH = c(0, 0.5, 0.3)))
  fr_name <- jointCoordinateSystem(
    pe, list(f = list(proximal = "HIP", distal = "KNEE", lateral = "THIGH")))
  fr_idx <- jointCoordinateSystem(
    pe, list(f = list(proximal = 1L, distal = 2L, lateral = 3L)))
  expect_equal(fr_idx[["f"]], fr_name[["f"]])
})

test_that("jointCoordinateSystem errors when a marker is missing from an axis", {
  pe <- .mk_pe(list(HIP = c(0, 1, 0), KNEE = c(0, 0, 0), THIGH = c(0, 0.5, 0.3)))
  expect_error(
    jointCoordinateSystem(pe, list(f = list(proximal = "NOPE", distal = "KNEE",
                                            lateral = "THIGH"))),
    "not found")
})


# --- signed 3-point joint angles (WSCB-07) ---

# Planar three-marker chain: vertex at the origin, the proximal vector along
# +x, and the distal vector `theta` degrees from it in the x-y plane.
.mk_planar <- function(theta_deg, n = 1L, z = FALSE) {
  th <- theta_deg * pi / 180
  labs <- c("prox", "joint", "dist")
  px <- matrix(c(1, 0, cos(th)), n, 3L, byrow = TRUE)
  py <- matrix(c(0, 0, sin(th)), n, 3L, byrow = TRUE)
  colnames(px) <- labs; colnames(py) <- labs
  a <- list(position_x = px, position_y = py)
  if (z) {
    pz <- matrix(0, n, 3L); colnames(pz) <- labs
    a$position_z <- pz
  }
  PhysioExperiment(assays = S4Vectors::SimpleList(a),
                   colData = S4Vectors::DataFrame(label = labs),
                   samplingRate = 100)
}

.planar_joint <- list(elbow = list(proximal = "prox", joint = "joint",
                                   distal = "dist"))

.angle_of <- function(pe, ...) {
  as.numeric(SummarizedExperiment::assay(
    calculateJointAngles(pe, .planar_joint, ...), "joint_angles")[, 1])
}

test_that("signed 3-point angle matches the analytic planar value", {
  expect_equal(.angle_of(.mk_planar(-30), signed = TRUE), -30,
               tolerance = 1e-6)
  expect_equal(.angle_of(.mk_planar(30), signed = TRUE), 30,
               tolerance = 1e-6)
  # the unsigned angle is +30 for both configurations
  expect_equal(.angle_of(.mk_planar(-30)), 30, tolerance = 1e-6)
  expect_equal(.angle_of(.mk_planar(30)), 30, tolerance = 1e-6)
})

test_that("signed angles are opposite with equal magnitude, unsigned identical", {
  s_neg <- .angle_of(.mk_planar(-30), signed = TRUE)
  s_pos <- .angle_of(.mk_planar(30), signed = TRUE)
  expect_equal(s_neg, -s_pos, tolerance = 1e-12)
  expect_equal(abs(s_neg), abs(s_pos), tolerance = 1e-12)
  # the magnitude is exactly the unsigned angle
  expect_equal(abs(s_neg), .angle_of(.mk_planar(-30)), tolerance = 1e-12)
  expect_equal(.angle_of(.mk_planar(-30)), .angle_of(.mk_planar(30)),
               tolerance = 1e-12)
})

test_that("signed angles separate flexion from hyperextension", {
  # Thigh vertical above the knee; the shank 10 degrees either side of straight.
  knee_pe <- function(dev_deg) {
    th <- (-90 + dev_deg) * pi / 180
    labs <- c("hip", "knee", "ankle")
    px <- matrix(c(0, 0, cos(th)), 1L, 3L, byrow = TRUE)
    py <- matrix(c(1, 0, sin(th)), 1L, 3L, byrow = TRUE)
    colnames(px) <- labs; colnames(py) <- labs
    PhysioExperiment(
      assays = S4Vectors::SimpleList(position_x = px, position_y = py),
      colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  }
  j <- list(knee = list(proximal = "hip", joint = "knee", distal = "ankle"))
  ang <- function(pe, ...) as.numeric(SummarizedExperiment::assay(
    calculateJointAngles(pe, j, ...), "joint_angles")[, 1])

  flex <- knee_pe(10); hyper <- knee_pe(-10)
  # the unsigned angle cannot tell them apart - this is the bug being fixed
  expect_equal(ang(flex), ang(hyper), tolerance = 1e-9)
  # the signed angle can
  s_flex <- ang(flex, signed = TRUE)
  s_hyper <- ang(hyper, signed = TRUE)
  expect_true(sign(s_flex) != sign(s_hyper))
  expect_equal(abs(s_flex), 170, tolerance = 1e-9)
  expect_equal(abs(s_hyper), 170, tolerance = 1e-9)
  # deviation from the straight position recovers the 10-degree excursion
  expect_equal(180 - abs(s_flex), 10, tolerance = 1e-9)
})

test_that("signed = FALSE leaves the default path unchanged", {
  set.seed(20260725)
  n <- 50L
  labs <- c("prox", "joint", "dist")
  mk <- function() {
    m <- matrix(stats::rnorm(n * 3), n, 3L); colnames(m) <- labs; m
  }
  px <- mk(); py <- mk(); pz <- mk()
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)

  got <- SummarizedExperiment::assay(
    calculateJointAngles(pe, .planar_joint), "joint_angles")
  ref <- vectorAngle(cbind(px[, 1] - px[, 2], py[, 1] - py[, 2],
                           pz[, 1] - pz[, 2]),
                     cbind(px[, 3] - px[, 2], py[, 3] - py[, 2],
                           pz[, 3] - pz[, 2]))
  expect_identical(as.numeric(got[, 1]), as.numeric(ref))
  # and the unsigned path attaches no convention metadata
  expect_null(S4Vectors::metadata(
    calculateJointAngles(pe, .planar_joint))$angle_convention)
})

test_that("reversing plane_normal flips the sign of the angle", {
  pe <- .mk_planar(-30)
  up <- .angle_of(pe, signed = TRUE, plane_normal = c(0, 0, 1))
  down <- .angle_of(pe, signed = TRUE, plane_normal = c(0, 0, -1))
  expect_equal(up, -down, tolerance = 1e-12)
  expect_equal(up, -30, tolerance = 1e-9)
  # a per-joint list is accepted too
  expect_equal(.angle_of(pe, signed = TRUE,
                         plane_normal = list(elbow = c(0, 0, -1))),
               30, tolerance = 1e-9)
})

test_that("signed angles honour degrees = FALSE and propagate NA", {
  expect_equal(.angle_of(.mk_planar(-30), signed = TRUE, degrees = FALSE),
               -pi / 6, tolerance = 1e-12)

  labs <- c("prox", "joint", "dist")
  px <- matrix(c(1, 0, 0, NA, 0, 0), 2L, 3L, byrow = TRUE)
  py <- matrix(c(0, 0, 1, 0, 0, 1), 2L, 3L, byrow = TRUE)
  colnames(px) <- labs; colnames(py) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  a <- .angle_of(pe, signed = TRUE)
  expect_equal(a[1], 90, tolerance = 1e-12)
  expect_true(is.na(a[2]))
})

test_that("a zero-length joint vector yields NA rather than an angle", {
  labs <- c("prox", "joint", "dist")
  px <- matrix(c(0, 0, 1), 1L, 3L, byrow = TRUE)
  py <- matrix(0, 1L, 3L)
  colnames(px) <- labs; colnames(py) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  expect_true(is.na(.angle_of(pe, signed = TRUE)))
})

test_that("3D signed angles use the supplied plane normal", {
  # a joint moving in the x-z plane: the axis is -y
  th <- seq(-0.5, 0.5, length.out = 25)
  n <- length(th)
  labs <- c("prox", "joint", "dist")
  px <- matrix(0, n, 3L); px[, 1] <- 1; px[, 3] <- cos(th)
  py <- matrix(0, n, 3L)
  pz <- matrix(0, n, 3L); pz[, 3] <- sin(th)
  colnames(px) <- labs; colnames(py) <- labs; colnames(pz) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py,
                                   position_z = pz),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)

  expect_equal(.angle_of(pe, signed = TRUE, plane_normal = c(0, -1, 0)),
               th * 180 / pi, tolerance = 1e-9)
  # a data-derived normal warns and recovers the same angles up to a flip
  expect_warning(derived <- .angle_of(pe, signed = TRUE), "derived from the data")
  expect_equal(abs(derived), abs(th * 180 / pi), tolerance = 1e-9)
})

test_that("signed-angle arguments are validated", {
  pe <- .mk_planar(-30)
  expect_error(calculateJointAngles(pe, .planar_joint,
                                    plane_normal = c(0, 0, 1)),
               "only used when")
  expect_error(calculateJointAngles(pe, .planar_joint, convention = "ISB",
                                    signed = TRUE), "already returns signed")
  expect_error(calculateJointAngles(pe, .planar_joint, signed = TRUE,
                                    plane_normal = c(0, 0, 0)), "degenerate axis")
  # a non-finite axis is just as degenerate and must not degrade to silent NA
  for (bad in list(c(Inf, 0, 0), c(NaN, 0, 0), c(NA_real_, 0, 0))) {
    expect_error(calculateJointAngles(pe, .planar_joint, signed = TRUE,
                                      plane_normal = bad), "degenerate axis")
  }
  expect_error(calculateJointAngles(pe, .planar_joint, signed = TRUE,
                                    plane_normal = c(0, 1)), "length-3")
  expect_error(calculateJointAngles(pe, .planar_joint, signed = NA),
               "single TRUE or FALSE")
  expect_error(calculateJointAngles(pe, .planar_joint, signed = TRUE,
                                    plane_normal = list(other = c(0, 0, 1))),
               "no entry for joint")
})

test_that("signed output records the plane normal in metadata", {
  res <- calculateJointAngles(.mk_planar(-30), .planar_joint, signed = TRUE,
                              plane_normal = c(0, 0, 1))
  conv <- S4Vectors::metadata(res)$angle_convention
  expect_true(isTRUE(conv$signed))
  expect_equal(conv$convention, "3point")
  expect_equal(conv$plane_normal$elbow, c(0, 0, 1))
})

test_that("the neutral-pose deviation is continuous where the signed angle wraps", {
  # a knee sweeping from 5 deg hyperextension to 5 deg flexion crosses straight
  dev <- seq(-5, 5, by = 0.5)
  labs <- c("hip", "knee", "ankle")
  th <- (-90 + dev) * pi / 180
  px <- cbind(hip = rep(0, length(dev)), knee = 0, ankle = cos(th))
  py <- cbind(hip = rep(1, length(dev)), knee = 0, ankle = sin(th))
  colnames(px) <- labs; colnames(py) <- labs
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(position_x = px, position_y = py),
    colData = S4Vectors::DataFrame(label = labs), samplingRate = 100)
  j <- list(knee = list(proximal = "hip", joint = "knee", distal = "ankle"))
  a <- as.numeric(SummarizedExperiment::assay(
    calculateJointAngles(pe, j, signed = TRUE), "joint_angles"))

  # the raw signed angle wraps: it jumps by ~360 across the straight pose
  expect_gt(max(abs(diff(a))), 300)
  # the documented remedy is continuous and recovers the prescribed excursion
  expect_lt(max(abs(diff(180 - abs(a)))), 1.01)
  expect_equal(180 - abs(a), abs(dev), tolerance = 1e-9)
})
