# Orbital stability and recurrence-based nonlinear dynamics for movement.
#
# Completes the package's nonlinear stability toolkit (which already has the
# maximum Lyapunov exponent, local dynamic stability and sample entropy) with:
#   * Floquet multipliers -- ORBITAL stability of a cyclic movement (gait): how
#     fast small perturbations to the limit cycle decay from one stride to the
#     next (max |multiplier| < 1 = orbitally stable).
#   * Recurrence quantification analysis (RQA) -- determinism, laminarity and
#     line-length structure of the reconstructed attractor.
#   * Approximate entropy (Pincus) -- regularity of a time series (the ApEn
#     complement to the package's sample entropy).
# Dependency-free base R.

# Delay embedding of a scalar series into an m-dimensional state space.
.sr_embed <- function(x, m, tau) {
  n <- length(x) - (m - 1) * tau
  if (n < 1L) stop("series too short for this embedding.", call. = FALSE)
  vapply(seq_len(m), function(j) x[seq_len(n) + (j - 1) * tau], numeric(n))
}

#' Floquet multipliers (orbital stability of a cyclic movement)
#'
#' Quantifies how quickly perturbations to a limit-cycle movement (e.g. gait)
#' decay from one stride to the next. At each phase of the cycle a linear
#' Poincare (return) map is fitted between the SAME phase in consecutive strides
#' (`dS_{n+1} = J dS_n`); the Floquet multipliers are its eigenvalues. The
#' maximum modulus < 1 means the movement is orbitally stable (perturbations
#' shrink stride to stride).
#'
#' @param states Either a `[stride, phase, state]` array, or a list of
#'   `phase x state` matrices (one per stride). Strides must be consecutive and
#'   sampled at the same phases; the state is a vector (e.g. joint angles and
#'   velocities).
#' @return a `floquet_result`: `max_multiplier` (largest modulus over phases),
#'   `multipliers` (eigenvalues of the section return map), `per_phase_max` (the
#'   Dingwell per-phase maximum multiplier) and `orbitally_stable`.
#' @references Hurmuzlu Y, Basdogan C (1994) J Biomech Eng 116:30-36; Dingwell JB,
#'   Kang HG (2007) J Biomech Eng 129:586-593.
#' @seealso [recurrenceQuantification()], [maxLyapunovExponent()]
#' @export
#' @examples
#' set.seed(1)
#' A <- matrix(c(0.5, 0.1, 0, 0.3), 2, 2)             # stride-to-stride return map
#' P <- 4; nS <- 80; strides <- array(0, c(nS, P, 2)); d <- rnorm(2)
#' cyc <- cbind(sin(1:P), cos(1:P))
#' for (n in 1:nS) { for (k in 1:P) strides[n, k, ] <- cyc[k, ] + d
#'   d <- as.numeric(A %*% d) + rnorm(2, 0, 0.01) }
#' floquetMultipliers(strides)$max_multiplier          # ~ 0.5 (< 1, stable)
floquetMultipliers <- function(states) {
  if (is.list(states)) {
    ns <- length(states); dm <- dim(as.matrix(states[[1]]))
    A <- array(0, c(ns, dm[1], dm[2]))
    for (s in seq_len(ns)) A[s, , ] <- as.matrix(states[[s]])
  } else {
    A <- states
  }
  if (length(dim(A)) != 3L) stop("`states` must be a [stride, phase, state] array or list.", call. = FALSE)
  nS <- dim(A)[1]; P <- dim(A)[2]; d <- dim(A)[3]
  if (nS - 1L <= d) stop("need more stride pairs than state dimensions for the return map.", call. = FALSE)
  per_phase <- numeric(P); J1 <- NULL
  for (k in seq_len(P)) {
    Sk <- matrix(A[, k, ], nrow = nS)                # nS x d, one phase across strides
    mk <- colMeans(Sk)
    dX0 <- sweep(Sk[-nS, , drop = FALSE], 2L, mk)    # deviation, stride n
    dX1 <- sweep(Sk[-1, , drop = FALSE], 2L, mk)     # deviation, stride n+1
    Jt <- solve(crossprod(dX0) + diag(1e-8, d), crossprod(dX0, dX1))  # dX1 ~ dX0 %*% t(J)
    J <- t(Jt)
    if (k == 1L) J1 <- J
    per_phase[k] <- max(Mod(eigen(J, only.values = TRUE)$values))
  }
  maxmod <- max(per_phase)
  structure(list(max_multiplier = maxmod,
                 multipliers = eigen(J1, only.values = TRUE)$values,
                 per_phase_max = per_phase, orbitally_stable = maxmod < 1,
                 n_strides = nS, n_phases = P, state_dim = d),
            class = "floquet_result")
}

#' @export
print.floquet_result <- function(x, ...) {
  cat(sprintf("Floquet analysis -- %d strides, %d phases, state dim %d\n",
              x$n_strides, x$n_phases, x$state_dim))
  cat(sprintf("  max |multiplier| = %.3f (%s)\n", x$max_multiplier,
              if (x$orbitally_stable) "orbitally stable" else "NOT orbitally stable"))
  invisible(x)
}

#' Recurrence quantification analysis (RQA)
#'
#' Reconstructs the attractor by delay embedding and quantifies its recurrence
#' structure: recurrence rate, determinism, laminarity and diagonal/vertical
#' line statistics. High determinism indicates deterministic (periodic/chaotic)
#' rather than stochastic dynamics.
#'
#' @param x Numeric time series.
#' @param m Embedding dimension (default 3).
#' @param tau Embedding delay (default 1).
#' @param radius Recurrence threshold; if `NULL`, chosen to reach `target_rr`.
#' @param target_rr Target recurrence rate when `radius` is `NULL` (default 0.1).
#' @param lmin,vmin Minimum diagonal / vertical line lengths (default 2).
#' @param max_n Cap on embedded points (subsampled if longer; default 1500).
#' @return an `rqa_result`: `RR`, `DET`, `LAM`, `Lmax`, `Lmean`, `TT` (trapping
#'   time), `ENTR` (diagonal line entropy), `radius`.
#' @references Marwan N, et al. (2007) Phys Rep 438:237-329.
#' @seealso [floquetMultipliers()], [approximateEntropy()]
#' @export
#' @examples
#' t <- seq(0, 20 * pi, length.out = 800)
#' recurrenceQuantification(sin(t))$DET               # ~1 (deterministic)
recurrenceQuantification <- function(x, m = 3L, tau = 1L, radius = NULL,
                                     target_rr = 0.1, lmin = 2L, vmin = 2L,
                                     max_n = 1500L) {
  X <- .sr_embed(as.numeric(x), m, tau)
  if (nrow(X) > max_n) X <- X[round(seq(1, nrow(X), length.out = max_n)), , drop = FALSE]
  D <- as.matrix(stats::dist(X))
  if (is.null(radius)) radius <- stats::quantile(D[upper.tri(D)], target_rr, names = FALSE)
  R <- D <= radius
  N <- nrow(R)
  RR <- (sum(R) - N) / (N^2 - N)                     # exclude the main diagonal
  # diagonal line lengths off the line of identity (R symmetric -> upper only;
  # the DET/ENTR ratios are invariant to the mirror). O(N^2) via direct indexing.
  diag_lines <- vector("list", N - 1L)
  for (k in seq_len(N - 1L)) {
    idx <- seq_len(N - k)
    diag_lines[[k]] <- .sr_runs(R[cbind(idx, idx + k)])
  }
  diag_lines <- unlist(diag_lines)
  vert_lines <- unlist(lapply(seq_len(N), function(j) .sr_runs(R[, j])))
  det <- .sr_line_ratio(diag_lines, lmin)
  lam <- .sr_line_ratio(vert_lines, vmin)
  dl <- diag_lines[diag_lines >= lmin]; vl <- vert_lines[vert_lines >= vmin]
  p <- table(dl) / length(dl)
  structure(list(
    RR = RR, DET = det, LAM = lam,
    Lmax = if (length(dl)) max(dl) else 0L,
    Lmean = if (length(dl)) mean(dl) else 0,
    TT = if (length(vl)) mean(vl) else 0,
    ENTR = if (length(p)) -sum(p * log(p)) else 0,
    radius = radius, m = m, tau = tau, N = N), class = "rqa_result")
}

# run lengths of TRUEs in a logical vector
.sr_runs <- function(v) {
  r <- rle(as.logical(v)); r$lengths[r$values]
}
# fraction of recurrent points forming lines of length >= lmin
.sr_line_ratio <- function(lines, lmin) {
  tot <- sum(lines)
  if (tot == 0) return(0)
  sum(lines[lines >= lmin]) / tot
}

#' @export
print.rqa_result <- function(x, ...) {
  cat(sprintf("RQA -- %d embedded points (m=%d, tau=%d), radius=%.3g\n",
              x$N, x$m, x$tau, x$radius))
  cat(sprintf("  RR=%.3f  DET=%.3f  LAM=%.3f  Lmax=%d  ENTR=%.2f\n",
              x$RR, x$DET, x$LAM, x$Lmax, x$ENTR))
  invisible(x)
}

#' Approximate entropy (Pincus)
#'
#' The regularity of a time series: the (negative) log-likelihood that patterns
#' close for `m` samples stay close for `m + 1`. Lower = more regular/predictable,
#' higher = more irregular. The ApEn complement to the package's sample entropy
#' (ApEn includes self-matches and is more biased for short series, but is the
#' classical measure).
#'
#' @param x Numeric time series.
#' @param m Pattern length (default 2).
#' @param r Tolerance; if `NULL`, `0.2 * sd(x)`.
#' @return the approximate entropy (scalar).
#' @references Pincus SM (1991) PNAS 88:2297-2301.
#' @seealso [recurrenceQuantification()], [sampleEntropy()]
#' @export
#' @examples
#' t <- seq(0, 20 * pi, length.out = 500)
#' approximateEntropy(sin(t))                          # low (regular)
#' set.seed(1); approximateEntropy(rnorm(500))         # high (irregular)
approximateEntropy <- function(x, m = 2L, r = NULL) {
  x <- as.numeric(x); N <- length(x)
  if (is.null(r)) r <- 0.2 * stats::sd(x)
  phi <- function(mm) {
    n <- N - mm + 1L
    templ <- vapply(seq_len(mm), function(j) x[seq_len(n) + (j - 1)], numeric(n))
    if (is.null(dim(templ))) templ <- matrix(templ, ncol = 1)
    cnt <- vapply(seq_len(n), function(i) {
      dmax <- apply(abs(sweep(templ, 2L, templ[i, ])), 1, max)
      sum(dmax <= r) / n
    }, numeric(1))
    mean(log(cnt))
  }
  phi(m) - phi(m + 1L)
}
