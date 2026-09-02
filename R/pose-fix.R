# Pose-estimation anomaly detection and correction ------------------------
# Markerless pose estimators (OpenPose, MediaPipe, DeepLabCut) produce keypoint
# trajectories corrupted by dropouts, jitter, implausible jumps, and left/right
# swaps. poseFix() detects those anomalies from biomechanical constraints and
# corrects them, so a `readOpenPose()` recording flows cleanly into the
# downstream joint-angle / gait / kinematics analysis. Generalised, name-based,
# self-referential reimplementation of the method in PoseFixeR
# (Sugiyama, Uno & Matsui 2023).

#' @keywords internal
#' @noRd
.pose_angle <- function(X, Y, a, b, c) {
  v1x <- X[, a] - X[, b]; v1y <- Y[, a] - Y[, b]
  v2x <- X[, c] - X[, b]; v2y <- Y[, c] - Y[, b]
  dot <- v1x * v2x + v1y * v2y
  mag <- sqrt(v1x^2 + v1y^2) * sqrt(v2x^2 + v2y^2)
  acos(pmin(pmax(dot / mag, -1), 1)) * 180 / pi        # degrees at vertex b
}

#' @keywords internal
#' @noRd
.impute_smooth <- function(v, smooth, spar) {
  n <- length(v)
  idx <- which(!is.na(v))
  if (length(idx) < 2) return(v)
  vi <- stats::approx(idx, v[idx], xout = seq_len(n), rule = 2)$y  # linear + edge
  if (isTRUE(smooth) && length(unique(vi)) > 3) {
    vi <- tryCatch(stats::smooth.spline(seq_len(n), vi, spar = spar)$y,
                   error = function(e) vi)
  }
  vi
}

#' @keywords internal
#' @noRd
.default_skeleton <- function(labels) {
  s <- list(c("Neck", "RShoulder"), c("RShoulder", "RElbow"), c("RElbow", "RWrist"),
            c("Neck", "LShoulder"), c("LShoulder", "LElbow"), c("LElbow", "LWrist"),
            c("Neck", "MidHip"), c("MidHip", "RHip"), c("RHip", "RKnee"),
            c("RKnee", "RAnkle"), c("MidHip", "LHip"), c("LHip", "LKnee"),
            c("LKnee", "LAnkle"))
  Filter(function(b) all(b %in% labels), s)
}

#' @keywords internal
#' @noRd
.default_chains <- function(labels) {
  ch <- list(c("RHip", "RKnee", "RAnkle"), c("LHip", "LKnee", "LAnkle"),
             c("RShoulder", "RElbow", "RWrist"),
             c("LShoulder", "LElbow", "LWrist"))
  Filter(function(c) all(c %in% labels), ch)
}

#' @keywords internal
#' @noRd
.default_joints <- function(labels) {
  j <- list(c("RHip", "RKnee", "RAnkle"), c("LHip", "LKnee", "LAnkle"),
            c("MidHip", "RHip", "RKnee"), c("MidHip", "LHip", "LKnee"),
            c("RShoulder", "RElbow", "RWrist"), c("LShoulder", "LElbow", "LWrist"))
  Filter(function(t) all(t %in% labels), j)
}

# Left/right leg-swap correction by trajectory continuity. Pose estimators
# routinely swap the leg labels as the legs cross during gait; here each frame's
# leg keypoints are (un)swapped to minimise displacement from the previous
# corrected frame, restoring continuous left/right trajectories. This is a
# generalised, model-agnostic form of the leg-reversal correction in PoseFixeR.
#' @keywords internal
#' @noRd
.pose_deswap_legs <- function(X, Y, labels) {
  legs <- Filter(function(p) all(p %in% labels),
                 list(c("RHip", "LHip"), c("RKnee", "LKnee"),
                      c("RAnkle", "LAnkle")))
  if (!length(legs)) return(list(X = X, Y = Y, n = 0L))
  Xc <- X; Yc <- Y; nsw <- 0L
  for (t in 2:nrow(X)) {
    cost_no <- 0; cost_sw <- 0
    for (p in legs) {
      r <- p[1]; l <- p[2]
      cost_no <- cost_no + (Xc[t, r] - Xc[t - 1, r])^2 + (Yc[t, r] - Yc[t - 1, r])^2 +
                           (Xc[t, l] - Xc[t - 1, l])^2 + (Yc[t, l] - Yc[t - 1, l])^2
      cost_sw <- cost_sw + (Xc[t, l] - Xc[t - 1, r])^2 + (Yc[t, l] - Yc[t - 1, r])^2 +
                           (Xc[t, r] - Xc[t - 1, l])^2 + (Yc[t, r] - Yc[t - 1, l])^2
    }
    if (is.finite(cost_sw) && is.finite(cost_no) && cost_sw < cost_no) {
      for (p in legs) {
        r <- p[1]; l <- p[2]
        tx <- Xc[t, r]; Xc[t, r] <- Xc[t, l]; Xc[t, l] <- tx
        ty <- Yc[t, r]; Yc[t, r] <- Yc[t, l]; Yc[t, l] <- ty
      }
      nsw <- nsw + 1L
    }
  }
  list(X = Xc, Y = Yc, n = nsw)
}

#' Detect and correct pose-estimation anomalies
#'
#' Cleans a markerless-pose recording (e.g. from [readOpenPose()]) by detecting
#' biomechanically implausible keypoints and correcting them, connecting pose
#' estimation to the downstream joint-angle / gait / kinematics analysis.
#' Anomalies are flagged from four criteria (after Sugiyama, Uno & Matsui 2023):
#' low detector confidence; segment (bone) lengths that deviate from the
#' subject's own median; frame-to-frame jumps larger than a fraction of body
#' scale; and joint angles outside their empirical range. Flagged coordinates are
#' set to `NA`, linearly interpolated, and optionally smoothed. References are
#' derived from the recording itself, so the method is model-agnostic.
#'
#' @param pe A `PhysioExperiment` of pose keypoints with assays `keypoint_x`,
#'   `keypoint_y` and (optionally) `confidence`, and `colData$label` naming the
#'   keypoints — the output of [readOpenPose()] / [readMediaPipe()].
#' @param conf_threshold Keypoints with confidence below this are flagged
#'   (default 0.2).
#' @param length_tol A bone is flagged when its length deviates from its own
#'   median by more than this fraction (default 0.4).
#' @param jump_tol A keypoint is flagged when its frame-to-frame displacement
#'   exceeds this fraction of body scale (default 0.5).
#' @param angle_range Lower/upper quantiles bounding plausible joint angles
#'   (default `c(0.01, 0.99)`).
#' @param deswap If `TRUE` (default), first correct left/right leg-label swaps by
#'   restoring trajectory continuity (a common pose-estimation error during gait).
#' @param length_correct If `TRUE`, additionally standardise segment lengths with
#'   [poseLengthCorrect()] after cleaning (camera-distance correction; default
#'   `FALSE`).
#' @param skeleton Optional list of `c(from, to)` keypoint-name bone pairs
#'   (default: a standard body skeleton restricted to the present keypoints).
#' @param joints Optional list of `c(a, b, c)` angle triplets (angle at `b`).
#' @param smooth If `TRUE` (default) smooth each coordinate with a spline after
#'   interpolation.
#' @param smooth_spar Smoothing parameter passed to [stats::smooth.spline()].
#'
#' @return A cleaned `PhysioExperiment` (corrected `keypoint_x`/`keypoint_y`
#'   assays); `metadata()$poseFix` holds the per-criterion anomaly counts, the
#'   number of leg-swap corrections (`leg_swaps`), the `flagged` frame-by-keypoint
#'   logical matrix, and the flagged fraction.
#'
#' @references Sugiyama S, Uno K, Matsui Y (2023). Types of anomalies in
#'   two-dimensional video-based gait analysis in uncontrolled environments.
#'   \emph{PLOS Computational Biology} 19:e1009989.
#'   \doi{10.1371/journal.pcbi.1009989}
#'
#' @seealso [readOpenPose()], [calculateJointAngles()]
#' @export
poseFix <- function(pe, conf_threshold = 0.2, length_tol = 0.4, jump_tol = 0.5,
                    angle_range = c(0.01, 0.99), skeleton = NULL, joints = NULL,
                    deswap = TRUE, length_correct = FALSE,
                    smooth = TRUE, smooth_spar = 0.4) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  an <- SummarizedExperiment::assayNames(pe)
  if (!all(c("keypoint_x", "keypoint_y") %in% an))
    stop("`pe` must have 'keypoint_x' and 'keypoint_y' assays (see readOpenPose()).",
         call. = FALSE)
  X <- as.matrix(SummarizedExperiment::assay(pe, "keypoint_x"))
  Y <- as.matrix(SummarizedExperiment::assay(pe, "keypoint_y"))
  conf <- if ("confidence" %in% an)
    as.matrix(SummarizedExperiment::assay(pe, "confidence"))
  else matrix(1, nrow(X), ncol(X))
  labels <- as.character(SummarizedExperiment::colData(pe)$label)
  if (length(labels) != ncol(X)) labels <- colnames(X)
  colnames(X) <- colnames(Y) <- labels
  nf <- nrow(X); nk <- ncol(X)
  if (is.null(skeleton)) skeleton <- .default_skeleton(labels)
  if (is.null(joints)) joints <- .default_joints(labels)

  # 0. correct left/right leg-label swaps first (per the paper's ordering)
  n_swaps <- 0L
  if (isTRUE(deswap)) {
    dw <- .pose_deswap_legs(X, Y, labels)
    X <- dw$X; Y <- dw$Y; n_swaps <- dw$n
  }

  flag <- matrix(FALSE, nf, nk, dimnames = list(NULL, labels))
  counts <- c(low_confidence = 0L, segment_length = 0L,
              temporal_jump = 0L, joint_angle = 0L)

  # 1. low confidence
  lc <- conf < conf_threshold
  flag <- flag | lc
  counts["low_confidence"] <- sum(lc)

  bone <- function(i, j) sqrt((X[, i] - X[, j])^2 + (Y[, i] - Y[, j])^2)
  ref_len <- vapply(skeleton, function(b) stats::median(bone(b[1], b[2]),
                    na.rm = TRUE), numeric(1))
  scale <- stats::median(ref_len[is.finite(ref_len)], na.rm = TRUE)
  if (!is.finite(scale) || scale <= 0) scale <- 1

  # 2. segment-length anomaly (flag the distal keypoint)
  for (bi in seq_along(skeleton)) {
    b <- skeleton[[bi]]; L <- bone(b[1], b[2]); rl <- ref_len[bi]
    if (!is.finite(rl) || rl <= 0) next
    bad <- is.finite(L) & abs(L - rl) > length_tol * rl
    flag[bad, b[2]] <- TRUE
    counts["segment_length"] <- counts["segment_length"] + sum(bad)
  }

  # 3. temporal jump
  for (k in seq_len(nk)) {
    d <- sqrt(c(NA, diff(X[, k]))^2 + c(NA, diff(Y[, k]))^2)
    bad <- is.finite(d) & d > jump_tol * scale
    flag[bad, k] <- TRUE
    counts["temporal_jump"] <- counts["temporal_jump"] + sum(bad)
  }

  # 4. joint-angle range
  for (jt in joints) {
    ang <- .pose_angle(X, Y, jt[1], jt[2], jt[3])
    rng <- stats::quantile(ang, angle_range, na.rm = TRUE, names = FALSE)
    bad <- is.finite(ang) & (ang < rng[1] | ang > rng[2])
    flag[bad, jt[3]] <- TRUE
    counts["joint_angle"] <- counts["joint_angle"] + sum(bad)
  }

  # correct: NA out flagged, interpolate + smooth per coordinate
  Xc <- X; Yc <- Y; Xc[flag] <- NA; Yc[flag] <- NA
  for (k in seq_len(nk)) {
    Xc[, k] <- .impute_smooth(Xc[, k], smooth, smooth_spar)
    Yc[, k] <- .impute_smooth(Yc[, k], smooth, smooth_spar)
  }

  out <- pe
  SummarizedExperiment::assay(out, "keypoint_x") <- Xc
  SummarizedExperiment::assay(out, "keypoint_y") <- Yc
  S4Vectors::metadata(out)$poseFix <- list(
    counts = counts, leg_swaps = n_swaps, flagged = flag,
    total_flagged = sum(flag), fraction = sum(flag) / (nf * nk))
  if (isTRUE(length_correct)) out <- poseLengthCorrect(out)
  out
}

#' Standardise segment lengths (camera-distance correction)
#'
#' In 2D video, apparent bone lengths shrink and grow as the subject moves toward
#' or away from the camera, biasing kinematics. This rescales each limb segment so
#' its length matches a stable reference (the recording's median or mean of that
#' segment), repositioning the distal keypoint along the bone direction and
#' chaining proximal to distal. Generalised form of the length correction in
#' PoseFixeR (Sugiyama, Uno & Matsui 2023).
#'
#' @param pe A pose `PhysioExperiment` (assays `keypoint_x`, `keypoint_y`;
#'   `colData$label`), e.g. from [readOpenPose()] or after [poseFix()].
#' @param chains Optional list of kinematic chains, each a proximal-to-distal
#'   vector of keypoint names (default: both legs and both arms, restricted to
#'   the present keypoints).
#' @param reference `"median"` (default, robust) or `"mean"` reference length.
#' @return A `PhysioExperiment` with length-standardised `keypoint_x`/`y`;
#'   `metadata()$poseLengthCorrect` holds the reference length per segment.
#' @references Sugiyama S, Uno K, Matsui Y (2023). \emph{PLOS Comput Biol}
#'   19:e1009989. \doi{10.1371/journal.pcbi.1009989}
#' @seealso [poseFix()]
#' @export
poseLengthCorrect <- function(pe, chains = NULL, reference = c("median", "mean")) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  reference <- match.arg(reference)
  X <- as.matrix(SummarizedExperiment::assay(pe, "keypoint_x"))
  Y <- as.matrix(SummarizedExperiment::assay(pe, "keypoint_y"))
  labels <- as.character(SummarizedExperiment::colData(pe)$label)
  if (length(labels) == ncol(X)) { colnames(X) <- colnames(Y) <- labels }
  if (is.null(chains)) chains <- .default_chains(colnames(X))
  ref_fun <- if (reference == "median") stats::median else mean

  refs <- list()
  for (chain in chains) {
    for (s in seq_len(length(chain) - 1L)) {
      prox <- chain[s]; dist <- chain[s + 1L]
      L <- sqrt((X[, dist] - X[, prox])^2 + (Y[, dist] - Y[, prox])^2)
      refL <- ref_fun(L, na.rm = TRUE)
      if (!is.finite(refL) || refL <= 0) next
      sc <- refL / L; sc[!is.finite(sc)] <- 1
      X[, dist] <- X[, prox] + (X[, dist] - X[, prox]) * sc   # uses corrected prox
      Y[, dist] <- Y[, prox] + (Y[, dist] - Y[, prox]) * sc
      refs[[paste(prox, dist, sep = "-")]] <- refL
    }
  }
  out <- pe
  SummarizedExperiment::assay(out, "keypoint_x") <- X
  SummarizedExperiment::assay(out, "keypoint_y") <- Y
  S4Vectors::metadata(out)$poseLengthCorrect <- list(reference_length = refs,
                                                     reference = reference)
  out
}
