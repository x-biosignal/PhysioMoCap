# Movement primitives: compact, generalisable representations of a movement.
#
# Rather than storing a trajectory point by point, a primitive encodes its
# dynamics so it can be REGENERATED and generalised -- to a new goal, a new
# duration, or through a via-point. Two standard families:
#   * Dynamic Movement Primitives (DMP; Ijspeert et al. 2013) -- a stable
#     point-attractor plus a learned nonlinear forcing term; reproduces a single
#     demonstration and re-targets/‑times it while staying smooth and stable.
#   * Probabilistic Movement Primitives (ProMP; Paraschos et al. 2013) -- a
#     distribution over trajectories learned from several demonstrations, giving
#     a mean +/- variability band and Gaussian conditioning on via-points.
# Dependency-free base R.

.mp_gauss_centers <- function(K, alpha_x) {
  # basis centres equally spaced in TIME, expressed in canonical x = exp(-a t)
  ct <- seq(0, 1, length.out = K)
  c_i <- exp(-alpha_x * ct)
  h_i <- numeric(K)
  h_i[-K] <- 1 / (diff(c_i)^2) * 0.5
  h_i[K] <- h_i[K - 1]
  list(c = c_i, h = h_i)
}

#' Fit a Dynamic Movement Primitive to a demonstration
#'
#' Learns the forcing term of a DMP from one demonstrated trajectory, so it can
#' later be regenerated (and generalised to a new goal or duration) by
#' [dmpGenerate()].
#'
#' @param y Demonstration: a numeric vector (1-D) or `T x D` matrix (per-column
#'   DOF).
#' @param times Optional time stamps (length `T`); defaults to `0..1`.
#' @param n_basis Number of Gaussian basis functions (default 25).
#' @param alpha_z Attractor gain (default 25; damping `beta_z = alpha_z / 4`,
#'   critically damped).
#' @return a `dmp` object: learned weights (`n_basis x D`), goal, start,
#'   duration, and parameters.
#' @references Ijspeert AJ, et al. (2013) Neural Comput 25:328-373.
#' @seealso [dmpGenerate()], [promFit()]
#' @export
#' @examples
#' t <- seq(0, 1, length.out = 100)
#' y <- 10 * (10*t^3 - 15*t^4 + 6*t^5)               # min-jerk demo
#' d <- dmpFit(y); rg <- dmpGenerate(d)
#' max(abs(rg$y[, 1] - y))                            # reproduces the demo
dmpFit <- function(y, times = NULL, n_basis = 25L, alpha_z = 25) {
  Y <- as.matrix(y); Tn <- nrow(Y); D <- ncol(Y)
  if (Tn < 3L) stop("need >= 3 samples.", call. = FALSE)
  if (is.null(times)) times <- seq(0, 1, length.out = Tn)
  dur <- times[Tn] - times[1]; beta_z <- alpha_z / 4
  alpha_x <- -log(0.01)
  x <- exp(-alpha_x * (times - times[1]) / dur)      # canonical system
  bs <- .mp_gauss_centers(n_basis, alpha_x)
  Psi <- exp(-outer(x, bs$c, "-")^2 * rep(bs$h, each = Tn))   # Tn x K
  W <- matrix(0, n_basis, D); goal <- start <- numeric(D)
  for (j in seq_len(D)) {
    yj <- Y[, j]
    dy  <- c(0, diff(yj) / diff(times)); dy[1] <- dy[2]
    ddy <- c(0, diff(dy) / diff(times)); ddy[1] <- ddy[2]
    g <- yj[Tn]; y0 <- yj[1]; goal[j] <- g; start[j] <- y0
    f_target <- dur^2 * ddy - alpha_z * (beta_z * (g - yj) - dur * dy)
    s <- x * (g - y0)                                 # forcing scaling
    for (i in seq_len(n_basis)) {                     # locally-weighted regression
      num <- sum(Psi[, i] * s * f_target); den <- sum(Psi[, i] * s^2)
      W[i, j] <- if (abs(den) > 1e-12) num / den else 0
    }
  }
  structure(list(weights = W, goal = goal, start = start, duration = dur,
                 alpha_z = alpha_z, beta_z = beta_z, alpha_x = alpha_x,
                 centers = bs$c, widths = bs$h, n_basis = n_basis, D = D),
            class = "dmp")
}

#' Generate a trajectory from a Dynamic Movement Primitive
#'
#' Integrates a fitted [dmpFit()] DMP, optionally generalising to a new goal,
#' start or duration (temporal scaling) while preserving the movement's shape and
#' guaranteeing convergence to the goal.
#'
#' @param dmp A `dmp` from [dmpFit()].
#' @param goal,start Optional new goal / start (length `D`); default the learned
#'   ones.
#' @param tau Optional new duration (temporal scaling); default the learned
#'   duration.
#' @param n Number of output samples (default 100).
#' @return a `dmp_trajectory`: `time`, `y`, `yd` (`n x D`).
#' @seealso [dmpFit()]
#' @export
dmpGenerate <- function(dmp, goal = NULL, start = NULL, tau = NULL, n = 100L) {
  g <- if (is.null(goal)) dmp$goal else as.numeric(goal)
  y0 <- if (is.null(start)) dmp$start else as.numeric(start)
  dur <- if (is.null(tau)) dmp$duration else tau
  dt <- dur / (n - 1); D <- dmp$D
  Y <- matrix(0, n, D); YD <- matrix(0, n, D)
  for (j in seq_len(D)) {
    y <- y0[j]; z <- 0
    Y[1, j] <- y
    for (k in 2:n) {
      t <- (k - 2) * dt
      x <- exp(-dmp$alpha_x * t / dur)
      psi <- exp(-dmp$widths * (x - dmp$centers)^2)
      f <- sum(psi * dmp$weights[, j]) / max(sum(psi), 1e-10) * x * (g[j] - y0[j])
      zd <- (dmp$alpha_z * (dmp$beta_z * (g[j] - y) - z) + f) / dur
      yd <- z / dur
      z <- z + zd * dt; y <- y + yd * dt
      Y[k, j] <- y; YD[k, j] <- yd
    }
  }
  structure(list(time = seq(0, dur, length.out = n), y = Y, yd = YD),
            class = "dmp_trajectory")
}

#' @export
print.dmp <- function(x, ...) {
  cat(sprintf("Dynamic Movement Primitive -- %d DOF, %d basis functions\n", x$D, x$n_basis))
  cat(sprintf("  goal = (%s), duration = %.3f s\n",
              paste(sprintf("%.2f", x$goal), collapse = ", "), x$duration))
  invisible(x)
}

# Gaussian basis matrix over phase z in [0,1] (T x K).
.promp_basis <- function(z, K, width = NULL) {
  ctr <- seq(0, 1, length.out = K)
  h <- if (is.null(width)) (1 / (K - 1))^2 * 0.5 else width
  Phi <- exp(-outer(z, ctr, "-")^2 / (2 * h))
  Phi / pmax(rowSums(Phi), 1e-10)                    # normalised basis
}

#' Fit a Probabilistic Movement Primitive to demonstrations
#'
#' Learns a distribution over trajectories from several demonstrations: each is
#' projected onto a Gaussian basis, and the basis weights are modelled as
#' Gaussian, giving a mean trajectory and a variability band.
#'
#' @param demos A list of demonstrations (each a numeric vector, all resampled to
#'   the same length), or an `N x T` matrix (one demo per row).
#' @param n_basis Number of Gaussian basis functions (default 15).
#' @param ridge Ridge penalty for the per-demo weight fit (default 1e-6).
#' @return a `promp` object: `mean` and `sd` trajectories, the weight mean
#'   `w_mean` and covariance `w_cov`, the basis `Phi`, and phase `z`.
#' @references Paraschos A, et al. (2013) NIPS 26.
#' @seealso [promCondition()], [dmpFit()]
#' @export
#' @examples
#' z <- seq(0, 1, length.out = 50)
#' demos <- lapply(1:20, function(i) sin(2 * pi * z) + rnorm(50, 0, 0.1))
#' p <- promFit(demos)
#' length(p$mean)                                     # mean trajectory
promFit <- function(demos, n_basis = 15L, ridge = 1e-6) {
  M <- if (is.list(demos)) do.call(rbind, demos) else as.matrix(demos)
  N <- nrow(M); Tn <- ncol(M)
  z <- seq(0, 1, length.out = Tn)
  Phi <- .promp_basis(z, n_basis)                    # Tn x K
  A <- crossprod(Phi) + ridge * diag(n_basis)
  Wt <- t(apply(M, 1, function(y) solve(A, crossprod(Phi, y))))   # N x K weights
  w_mean <- colMeans(Wt)
  w_cov <- stats::cov(Wt)
  mean_traj <- as.numeric(Phi %*% w_mean)
  var_traj <- rowSums((Phi %*% w_cov) * Phi)         # diag(Phi w_cov Phi')
  structure(list(mean = mean_traj, sd = sqrt(pmax(var_traj, 0)),
                 w_mean = w_mean, w_cov = w_cov, Phi = Phi, z = z,
                 n_basis = n_basis, N = N, T = Tn), class = "promp")
}

#' Condition a ProMP on a via-point
#'
#' Gaussian conditioning of a fitted [promFit()] ProMP so the trajectory
#' distribution passes through a desired point at a given phase, updating the
#' mean and the variability band.
#'
#' @param promp A `promp` from [promFit()].
#' @param phase Phase in \[0, 1] of the via-point.
#' @param value Desired trajectory value at `phase`.
#' @param obs_sd Observation noise SD (smaller = tighter conditioning; default
#'   1e-3).
#' @return an updated `promp` with the conditioned `mean`, `sd`, `w_mean`,
#'   `w_cov`.
#' @seealso [promFit()]
#' @export
promCondition <- function(promp, phase, value, obs_sd = 1e-3) {
  ctr <- seq(0, 1, length.out = promp$n_basis)
  h <- (1 / (promp$n_basis - 1))^2 * 0.5
  phi <- exp(-(phase - ctr)^2 / (2 * h)); phi <- phi / sum(phi)   # 1 x K
  Sig <- promp$w_cov; mu <- promp$w_mean
  denom <- as.numeric(obs_sd^2 + t(phi) %*% Sig %*% phi)
  K <- (Sig %*% phi) / denom                          # Kalman gain (K x 1)
  mu_new <- mu + K * (value - sum(phi * mu))
  Sig_new <- Sig - (K %*% t(phi)) %*% Sig
  mean_traj <- as.numeric(promp$Phi %*% mu_new)
  var_traj <- rowSums((promp$Phi %*% Sig_new) * promp$Phi)
  out <- promp
  out$mean <- mean_traj; out$sd <- sqrt(pmax(var_traj, 0))
  out$w_mean <- as.numeric(mu_new); out$w_cov <- Sig_new
  out
}

#' @export
print.promp <- function(x, ...) {
  cat(sprintf("Probabilistic Movement Primitive -- %d demos, %d basis, length %d\n",
              x$N, x$n_basis, x$T))
  cat(sprintf("  mean-trajectory range [%.2f, %.2f], mean band SD %.3f\n",
              min(x$mean), max(x$mean), mean(x$sd)))
  invisible(x)
}
