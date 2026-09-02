# Pure-R static optimization: resolve net joint moments into muscle activations
# by minimising muscle effort, used as a fallback when OpenSim is not available.

#' Pure-R static optimization of muscle activations
#'
#' Distributes the net joint moment at each time frame across muscles by
#' minimising the sum of squared activations (a quadratic muscle-effort
#' criterion), subject to the moments being reproduced exactly and each
#' activation staying within its bounds:
#' \deqn{\min_a \sum_i w_i a_i^2 \quad \text{s.t.} \quad
#'       \tau_j = \sum_i a_i F^{max}_i r_{ji}, \; 0 \le a_i \le 1.}
#' Each frame is an independent convex quadratic program (solved with
#' \pkg{quadprog}), giving the unique minimum-effort activations. This mirrors
#' the OpenSim Static Optimization tool (Anderson & Pandy 2001) and is used by
#' [runStaticOptimization()] when OpenSim is unavailable.
#'
#' @param moment_arms Muscle moment arms: either a single `n_dof x n_muscle`
#'   matrix `r` (moment arm of muscle *i* about degree-of-freedom *j*, reused for
#'   every frame) or a list of such matrices, one per frame.
#' @param max_force Numeric vector of muscle maximum isometric forces
#'   (`F_max`, length `n_muscle`).
#' @param joint_moments Net joint moments to reproduce: a length-`n_dof` vector
#'   (single frame) or an `n_frames x n_dof` matrix (one row per frame).
#' @param activation_bounds Length-2 numeric `c(lower, upper)` activation bounds
#'   (default `c(0, 1)`).
#' @param weights Optional length-`n_muscle` positive weights `w_i` for the
#'   effort criterion (default all 1).
#' @param passive_moments Optional passive/gravity joint moments subtracted from
#'   `joint_moments` before optimization (same shape as `joint_moments`).
#'
#' @return A `static_optimization_r` object: a list with `activations`
#'   (`n_frames x n_muscle`), `moments` (the reproduced net joint moments,
#'   `n_frames x n_dof`), `residual` (max absolute moment error per frame),
#'   `effort` (sum of squared activations per frame), `feasible` (logical per
#'   frame), and the muscle / DOF counts.
#'
#' @references
#' Anderson FC, Pandy MG (2001). "Static and dynamic optimization solutions for
#' gait are practically equivalent." J Biomech 34(2):153-161.
#'
#' @seealso [runStaticOptimization()]
#' @export
#' @examples
#' if (requireNamespace("quadprog", quietly = TRUE)) {
#'   # Two muscles with unit moment arm and F_max reproduce a moment of 30.
#'   r <- matrix(c(1, 1), nrow = 1)
#'   so <- staticOptimizationR(r, max_force = c(100, 100), joint_moments = 30)
#'   so$activations
#' }
staticOptimizationR <- function(moment_arms, max_force, joint_moments,
                                activation_bounds = c(0, 1),
                                weights = NULL,
                                passive_moments = NULL) {
  if (!requireNamespace("quadprog", quietly = TRUE)) {
    stop("staticOptimizationR() requires the 'quadprog' package.",
         call. = FALSE)
  }
  if (!is.numeric(max_force) || length(max_force) < 1L ||
      any(!is.finite(max_force)) || any(max_force <= 0)) {
    stop("max_force must be a non-empty positive numeric vector.", call. = FALSE)
  }
  n_muscle <- length(max_force)

  # Normalise joint_moments to an n_frames x n_dof matrix
  tau <- if (is.matrix(joint_moments)) joint_moments else {
    matrix(joint_moments, nrow = 1)
  }
  if (!is.numeric(tau) || any(!is.finite(tau))) {
    stop("joint_moments must be finite numeric.", call. = FALSE)
  }
  n_frames <- nrow(tau)
  n_dof <- ncol(tau)
  if (n_dof < 1L) {
    stop("joint_moments must have at least one degree of freedom.",
         call. = FALSE)
  }

  if (!is.null(passive_moments)) {
    pm <- if (is.matrix(passive_moments)) passive_moments else {
      matrix(passive_moments, nrow = 1)
    }
    if (!all(dim(pm) == dim(tau))) {
      stop("passive_moments must match joint_moments in shape.", call. = FALSE)
    }
    tau <- tau - pm
  }

  # Per-frame moment-arm matrices
  arms <- if (is.list(moment_arms)) {
    if (length(moment_arms) != n_frames) {
      stop("a list of moment_arms must have one matrix per frame.",
           call. = FALSE)
    }
    moment_arms
  } else {
    rep(list(moment_arms), n_frames)
  }

  if (is.null(weights)) weights <- rep(1, n_muscle)
  if (!is.numeric(weights) || length(weights) != n_muscle ||
      any(weights <= 0)) {
    stop("weights must be a positive length-n_muscle vector.", call. = FALSE)
  }
  if (length(activation_bounds) != 2L || activation_bounds[1] >=
      activation_bounds[2]) {
    stop("activation_bounds must be c(lower, upper) with lower < upper.",
         call. = FALSE)
  }
  lb <- activation_bounds[1]
  ub <- activation_bounds[2]

  Dmat <- 2 * diag(weights, n_muscle, n_muscle)
  dvec <- rep(0, n_muscle)
  box <- cbind(diag(n_muscle), -diag(n_muscle))          # a >= lb, -a >= -ub
  box_b <- c(rep(lb, n_muscle), rep(-ub, n_muscle))

  activations <- matrix(NA_real_, n_frames, n_muscle)
  moments <- matrix(NA_real_, n_frames, n_dof)
  feasible <- logical(n_frames)

  for (f in seq_len(n_frames)) {
    r <- as.matrix(arms[[f]])
    if (nrow(r) != n_dof || ncol(r) != n_muscle) {
      stop(sprintf("moment_arms for frame %d must be %d x %d.",
                   f, n_dof, n_muscle), call. = FALSE)
    }
    C <- sweep(r, 2, max_force, "*")                     # C[j,i] = Fmax_i * r_ji

    # quadprog's dual method needs linearly independent equality rows; reduce
    # over-determined / rank-deficient moment constraints to an independent
    # basis (and detect a genuinely inconsistent set) before solving.
    red <- .so_reduce_equalities(C, tau[f, ])
    if (!red$consistent) {
      feasible[f] <- FALSE                               # moments not achievable
      next
    }
    Amat <- cbind(t(red$C), box)                         # equalities then bounds
    bvec <- c(red$tau, box_b)
    sol <- tryCatch(
      quadprog::solve.QP(Dmat, dvec, Amat, bvec, meq = red$meq),
      error = function(e) NULL
    )
    if (is.null(sol)) {
      feasible[f] <- FALSE                               # bounds make it infeasible
      next
    }
    a <- pmin(pmax(sol$solution, lb), ub)                # clamp tiny overshoots
    activations[f, ] <- a
    moments[f, ] <- as.numeric(C %*% a)                  # over the full DOF set
    feasible[f] <- TRUE
  }

  residual <- vapply(seq_len(n_frames), function(f) {
    if (feasible[f]) max(abs(moments[f, ] - tau[f, ])) else NA_real_
  }, numeric(1))
  effort <- vapply(seq_len(n_frames), function(f) {
    if (feasible[f]) sum(weights * activations[f, ]^2) else NA_real_
  }, numeric(1))

  out <- list(
    activations = activations,
    moments = moments,
    residual = residual,
    effort = effort,
    feasible = feasible,
    n_muscles = n_muscle,
    n_dof = n_dof
  )
  class(out) <- "static_optimization_r"
  out
}

#' Reduce a moment-constraint system to an independent, consistent basis
#'
#' Returns the linearly-independent rows of the equality system `C a = tau` (so
#' quadprog receives full-row-rank equalities), or `consistent = FALSE` when the
#' system has no solution (the moments cannot be reproduced).
#' @keywords internal
#' @noRd
.so_reduce_equalities <- function(C, tau) {
  n_dof <- nrow(C)
  if (n_dof == 0L) {
    return(list(C = C, tau = tau, meq = 0L, consistent = TRUE))
  }
  qr_ct <- qr(t(C))                                    # cols of t(C) = rows of C
  rk <- qr_ct$rank
  # Consistent iff rank([C | tau]) == rank(C).
  if (qr(cbind(C, tau))$rank > rk) {
    return(list(consistent = FALSE))
  }
  if (rk == n_dof) {
    return(list(C = C, tau = tau, meq = n_dof, consistent = TRUE))
  }
  keep <- sort(qr_ct$pivot[seq_len(rk)])                # independent DOF rows
  list(C = C[keep, , drop = FALSE], tau = tau[keep], meq = rk, consistent = TRUE)
}

#' @export
print.static_optimization_r <- function(x, ...) {
  nf <- length(x$feasible)
  cat("<static_optimization_r>\n")
  cat(sprintf("  frames        : %d (%d feasible)\n", nf, sum(x$feasible)))
  cat(sprintf("  muscles / DOFs: %d / %d\n", x$n_muscles, x$n_dof))
  if (any(x$feasible)) {
    cat(sprintf("  max residual  : %.3g\n", max(x$residual, na.rm = TRUE)))
    cat(sprintf("  mean effort   : %.4g\n", mean(x$effort, na.rm = TRUE)))
  }
  invisible(x)
}
