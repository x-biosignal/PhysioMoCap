# Native (pure-R) model-based inverse kinematics for a planar chain.
#
# calculateJointAngles() reads joint angles straight off marker vectors, so the
# implied segment lengths wobble frame to frame with marker noise. Model-based
# inverse kinematics instead fits a SCALED model with FIXED segment lengths to
# the markers, solving the joint angles that best explain the observed marker
# positions -- the OpenSim IK idea, without the OpenSim dependency (planar).
# Scale the model once from a static pose, then solve per frame by least squares.
# Dependency-free base R (+ stats::optim).

#' Scale a planar chain model from a static pose
#'
#' Estimates the fixed segment lengths of a serial planar chain from the marker
#' positions of its nodes (joint centres and the end point) in a static/reference
#' pose.
#'
#' @param nodes A `(n_segments + 1) x 2` matrix of node positions (root, joint 1,
#'   ..., end point) in the static pose.
#' @return a `planar_ik_model`: `lengths` (per segment) and `n_segments`.
#' @seealso [inverseKinematicsMarkers()], [forwardKinematics2D()]
#' @export
#' @examples
#' nodes <- rbind(c(0, 0), c(0.4, 0), c(0.8, 0))      # two 0.4 m segments
#' scalePlanarModel(nodes)$lengths
scalePlanarModel <- function(nodes) {
  nodes <- as.matrix(nodes)
  if (nrow(nodes) < 2L || ncol(nodes) != 2L)
    stop("`nodes` must be a (n_segments + 1) x 2 matrix.", call. = FALSE)
  seg <- nodes[-1, , drop = FALSE] - nodes[-nrow(nodes), , drop = FALSE]
  structure(list(lengths = sqrt(rowSums(seg^2)), n_segments = nrow(nodes) - 1L),
            class = "planar_ik_model")
}

#' @export
print.planar_ik_model <- function(x, ...) {
  cat(sprintf("Planar IK model -- %d segments, lengths (%s)\n",
              x$n_segments, paste(sprintf("%.3f", x$lengths), collapse = ", ")))
  invisible(x)
}

#' Forward kinematics of a planar chain
#'
#' Node positions of a serial planar chain from a base, the fixed segment lengths
#' and the ABSOLUTE segment angles (radians, from the x-axis).
#'
#' @param angles Absolute segment angles (length `n_segments`).
#' @param lengths Segment lengths (length `n_segments`).
#' @param base Root position (length 2; default origin).
#' @return a `(n_segments + 1) x 2` matrix of node positions.
#' @seealso [inverseKinematicsMarkers()]
#' @export
#' @examples
#' forwardKinematics2D(c(0, pi/2), c(1, 1))           # right angle
forwardKinematics2D <- function(angles, lengths, base = c(0, 0)) {
  n <- length(lengths)
  pos <- matrix(0, n + 1L, 2); pos[1, ] <- base
  for (i in seq_len(n))
    pos[i + 1, ] <- pos[i, ] + lengths[i] * c(cos(angles[i]), sin(angles[i]))
  pos
}

#' Model-based inverse kinematics from markers (planar)
#'
#' Solves the segment angles of a scaled planar chain that best fit observed
#' marker positions, frame by frame, by least squares. Because the segment
#' lengths are fixed by the model, the solution is consistent (unlike reading
#' angles directly off noisy markers, which lets the limb stretch).
#'
#' @param markers A `[frame, node, 2]` array of observed node positions (root and
#'   each joint/end), or a list of `(n_segments + 1) x 2` matrices.
#' @param model A `planar_ik_model` from [scalePlanarModel()].
#' @param anchor_root If `TRUE` (default) the root is fixed to the observed root
#'   marker each frame; otherwise the root is also fitted.
#' @return an `ik_result`: `angles` (`frame x n_segments`, absolute radians),
#'   `rmse` (per-frame marker RMS error, in position units), and `n_frames`.
#' @references Lu TW, O'Connor JJ (1999) global optimisation IK, J Biomech
#'   32:129-134.
#' @seealso [scalePlanarModel()], [forwardKinematics2D()]
#' @export
#' @examples
#' model <- scalePlanarModel(rbind(c(0, 0), c(1, 0), c(2, 0)))
#' truth <- forwardKinematics2D(c(0.3, 0.7), model$lengths)
#' arr <- array(0, c(1, 3, 2)); arr[1, , ] <- truth
#' inverseKinematicsMarkers(arr, model)$angles         # ~ c(0.3, 0.7)
inverseKinematicsMarkers <- function(markers, model, anchor_root = TRUE) {
  if (is.list(markers)) {
    fr <- length(markers); nn <- nrow(markers[[1]])
    M <- array(0, c(fr, nn, 2)); for (f in seq_len(fr)) M[f, , ] <- as.matrix(markers[[f]])
  } else M <- markers
  nf <- dim(M)[1]; ns <- model$n_segments; L <- model$lengths
  angles <- matrix(0, nf, ns); rmse <- numeric(nf)
  warm <- NULL
  for (f in seq_len(nf)) {
    obs <- matrix(M[f, , ], ncol = 2)
    base <- if (anchor_root) obs[1, ] else colMeans(obs)
    # initial guess: angles of the observed segment vectors
    init <- if (is.null(warm)) {
      seg <- obs[-1, , drop = FALSE] - obs[-nrow(obs), , drop = FALSE]
      atan2(seg[, 2], seg[, 1])
    } else warm
    obj <- function(a) {
      fk <- forwardKinematics2D(a, L, base)
      sum((fk[-1, , drop = FALSE] - obs[-1, , drop = FALSE])^2)
    }
    opt <- stats::optim(init, obj, method = "BFGS", control = list(maxit = 200))
    angles[f, ] <- opt$par; warm <- opt$par
    rmse[f] <- sqrt(opt$value / ns)
  }
  structure(list(angles = angles, rmse = rmse, n_frames = nf, n_segments = ns),
            class = "ik_result")
}

#' @export
print.ik_result <- function(x, ...) {
  cat(sprintf("Planar inverse kinematics -- %d frames, %d segments\n",
              x$n_frames, x$n_segments))
  cat(sprintf("  marker RMSE: mean %.4g, max %.4g\n", mean(x$rmse), max(x$rmse)))
  invisible(x)
}
