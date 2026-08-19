# Build a synthetic OpenPose-style PhysioExperiment (a simple standing skeleton
# with gait sway), then inject anomalies and check poseFix detects + corrects.
make_pose <- function(n = 200, seed = 1) {
  set.seed(seed)
  labels <- c("Neck", "RShoulder", "LShoulder", "MidHip",
              "RHip", "RKnee", "RAnkle", "LHip", "LKnee", "LAnkle")
  base_x <- c(Neck = 0, RShoulder = -18, LShoulder = 18, MidHip = 0,
              RHip = -10, RKnee = -10, RAnkle = -10,
              LHip = 10, LKnee = 10, LAnkle = 10)
  base_y <- c(Neck = 0, RShoulder = 15, LShoulder = 15, MidHip = 60,
              RHip = 60, RKnee = 105, RAnkle = 150,
              LHip = 60, LKnee = 105, LAnkle = 150)
  t <- seq_len(n)
  sway <- 4 * sin(2 * pi * t / 40)
  X <- outer(rep(1, n), base_x); Y <- outer(rep(1, n), base_y)
  colnames(X) <- colnames(Y) <- labels
  # gait: knees/ankles sway in x, small vertical bob
  for (kp in c("RKnee", "RAnkle", "LKnee", "LAnkle"))
    X[, kp] <- X[, kp] + sway * ifelse(grepl("^R", kp), 1, -1)
  X <- X + matrix(rnorm(n * ncol(X), 0, 0.4), n)
  Y <- Y + matrix(rnorm(n * ncol(Y), 0, 0.4), n)
  conf <- matrix(0.9, n, ncol(X), dimnames = list(NULL, labels))
  list(X = X, Y = Y, conf = conf, labels = labels)
}

as_pose_pe <- function(p) {
  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(keypoint_x = p$X, keypoint_y = p$Y,
                                   confidence = p$conf),
    colData = S4Vectors::DataFrame(label = p$labels,
                                   type = "keypoint", model = "BODY_25"),
    samplingRate = 30)
}

test_that("poseFix detects and corrects injected anomalies", {
  skip_if_not_installed("PhysioCore")
  p <- make_pose()
  truth_x <- p$X[, "RAnkle"]
  # inject: a confidence dropout, a temporal jump, a segment-length blow-up
  p$conf[50, "RKnee"] <- 0.02                     # low confidence
  p$X[100, "RAnkle"] <- p$X[100, "RAnkle"] + 120  # jump + segment length
  p$Y[150, "LKnee"] <- p$Y[150, "LKnee"] - 90     # segment length / angle
  pe <- as_pose_pe(p)

  fx <- poseFix(pe, deswap = FALSE)   # isolate anomaly detection from leg-deswap
  rep <- S4Vectors::metadata(fx)$poseFix

  expect_s4_class(fx, "PhysioExperiment")
  expect_gt(rep$total_flagged, 0)
  expect_gt(rep$counts["low_confidence"], 0)
  expect_true(rep$flagged[50, "RKnee"])           # dropout caught
  expect_true(rep$flagged[100, "RAnkle"])         # jump caught

  # the corrected RAnkle at the jump frame is back near the true trajectory
  cx <- as.matrix(SummarizedExperiment::assay(fx, "keypoint_x"))
  expect_lt(abs(cx[100, "RAnkle"] - truth_x[100]), 30)
})

test_that("a clean recording is left essentially unchanged", {
  skip_if_not_installed("PhysioCore")
  pe <- as_pose_pe(make_pose())
  fx <- poseFix(pe, smooth = FALSE)
  # low flagged fraction on clean data
  expect_lt(S4Vectors::metadata(fx)$poseFix$fraction, 0.05)
})

test_that("pipeline connects: readOpenPose-style PE -> poseFix -> valid PE", {
  skip_if_not_installed("PhysioCore")
  pe <- as_pose_pe(make_pose())
  fx <- poseFix(pe)
  # cleaned object retains structure for downstream analysis
  expect_equal(dim(SummarizedExperiment::assay(fx, "keypoint_x")),
               dim(SummarizedExperiment::assay(pe, "keypoint_x")))
  expect_false(anyNA(SummarizedExperiment::assay(fx, "keypoint_x")))
  expect_equal(as.character(SummarizedExperiment::colData(fx)$label),
               make_pose()$labels)
})

test_that("poseFix corrects a left/right leg swap by continuity", {
  skip_if_not_installed("PhysioCore")
  p <- make_pose(n = 200)
  true_RAnkle_x <- p$X[, "RAnkle"]
  # swap R/L legs from frame 100 to the end (a common pose-estimation error)
  for (pr in list(c("RHip", "LHip"), c("RKnee", "LKnee"), c("RAnkle", "LAnkle"))) {
    rng <- 100:200
    tx <- p$X[rng, pr[1]]; p$X[rng, pr[1]] <- p$X[rng, pr[2]]; p$X[rng, pr[2]] <- tx
    ty <- p$Y[rng, pr[1]]; p$Y[rng, pr[1]] <- p$Y[rng, pr[2]]; p$Y[rng, pr[2]] <- ty
  }
  pe <- as_pose_pe(p)
  fx <- poseFix(pe, deswap = TRUE, smooth = FALSE)
  rep <- S4Vectors::metadata(fx)$poseFix

  expect_gt(rep$leg_swaps, 0)
  cx <- as.matrix(SummarizedExperiment::assay(fx, "keypoint_x"))
  expect_lt(mean(abs(cx[, "RAnkle"] - true_RAnkle_x)), 3)   # restored trajectory
})

test_that("deswap leaves an unswapped recording alone", {
  skip_if_not_installed("PhysioCore")
  pe <- as_pose_pe(make_pose())
  fx <- poseFix(pe, deswap = TRUE, smooth = FALSE)
  expect_equal(S4Vectors::metadata(fx)$poseFix$leg_swaps, 0)
})

test_that("poseLengthCorrect standardises segment lengths (camera distance)", {
  skip_if_not_installed("PhysioCore")
  p <- make_pose(n = 200)
  # simulate camera-distance change: a time-varying zoom on all coordinates
  zoom <- 1 + 0.4 * sin(2 * pi * seq_len(200) / 200)
  p$X <- p$X * zoom; p$Y <- p$Y * zoom
  pe <- as_pose_pe(p)

  bone <- function(pe, a, b) {
    X <- SummarizedExperiment::assay(pe, "keypoint_x")
    Y <- SummarizedExperiment::assay(pe, "keypoint_y")
    sqrt((X[, a] - X[, b])^2 + (Y[, a] - Y[, b])^2)
  }
  before <- sd(bone(pe, "RHip", "RKnee"))
  lc <- poseLengthCorrect(pe)
  after <- sd(bone(lc, "RHip", "RKnee"))

  expect_s4_class(lc, "PhysioExperiment")
  expect_lt(after, before / 5)                    # thigh length made ~constant
  expect_true(after < 1e-6 || after / before < 0.05)
  expect_true(!is.null(S4Vectors::metadata(lc)$poseLengthCorrect))
})

test_that("poseFix length_correct option runs end to end", {
  skip_if_not_installed("PhysioCore")
  pe <- as_pose_pe(make_pose())
  fx <- poseFix(pe, length_correct = TRUE)
  expect_s4_class(fx, "PhysioExperiment")
  expect_false(anyNA(SummarizedExperiment::assay(fx, "keypoint_x")[, "RAnkle"]))
})

test_that("input validation", {
  skip_if_not_installed("PhysioCore")
  bad <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = matrix(1, 10, 3)), samplingRate = 30)
  expect_error(poseFix(bad), "keypoint_x")
})
