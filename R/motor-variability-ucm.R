# Structure of motor variability: how trial-to-trial variability is organised
# relative to a task goal.
#
# Smoothness/coordination describe single trials; this module asks WHY the
# variability across trials looks the way it does. Three complementary
# motor-control frameworks:
#   * Uncontrolled Manifold (UCM; Scholz & Schoner 1999) -- split elemental
#     (e.g. joint-angle) variance into a component that leaves the task variable
#     unchanged (V_ucm, "good" variability along the manifold) and one that
#     perturbs it (V_ort, "bad"); their difference is a synergy index.
#   * Goal-Equivalent Manifold (GEM; Cusumano & Cesari 2006) -- the same idea for
#     a scalar goal: goal-equivalent vs non-goal-equivalent variability and the
#     motor-equivalent ratio.
#   * Tolerance-Noise-Covariation (TNC; Muller & Sternad 2004) -- decompose the
#     result error into how much is removable by relocating to a more tolerant
#     region (Tolerance), by shrinking dispersion (Noise) and how much the
#     observed inter-variable covariation already saves (Covariation).
# Dependency-free base R.

# Numerical Jacobian (d x n) of a task function f: R^n -> R^d at point p.
.ucm_jacobian <- function(f, p, eps = 1e-6) {
  f0 <- f(p); n <- length(p); d <- length(f0)
  J <- matrix(0, d, n)
  for (j in seq_len(n)) {
    pj <- p; pj[j] <- pj[j] + eps
    J[, j] <- (f(pj) - f0) / eps
  }
  J
}

# Orthonormal basis (n x (n-r)) of the null space of J (d x n) via SVD.
.ucm_null_basis <- function(J, tol = 1e-9) {
  sv <- svd(J, nu = 0, nv = ncol(J))
  r <- sum(sv$d > tol * max(sv$d, 1))
  if (r >= ncol(J)) return(matrix(0, ncol(J), 0))
  sv$v[, (r + 1):ncol(J), drop = FALSE]
}

#' Uncontrolled Manifold (UCM) analysis of motor variability
#'
#' Decomposes trial-to-trial variance of the elemental variables into the part
#' lying in the uncontrolled manifold (the null space of the task Jacobian --
#' variability that does not change the task variable, "good") and the part
#' orthogonal to it (variability that does, "bad"). A positive synergy index
#' means the elements co-vary to stabilise the task.
#'
#' @param theta An `N x n` matrix: `N` trials (repetitions), `n` elemental
#'   variables (e.g. joint angles).
#' @param jacobian The `d x n` task Jacobian at the mean configuration (`d` =
#'   dimension of the task variable). Provide this, or `task`.
#' @param task Optional task function `R^n -> R^d`; its Jacobian is computed
#'   numerically at `colMeans(theta)` when `jacobian` is not given.
#' @return a `ucm_result` list: `v_ucm`, `v_ort` (variance per DOF, parallel and
#'   orthogonal to the manifold), `v_total`, `delta_v` (synergy index,
#'   `(v_ucm - v_ort) / v_total`; > 0 = task-stabilising synergy), `n`, `d`, `N`.
#' @references Scholz JP, Schoner G (1999) Exp Brain Res 126:289-306; Latash ML,
#'   et al. (2002) Exerc Sport Sci Rev 30:26-31.
#' @seealso [goalEquivalentManifold()], [toleranceNoiseCovariation()]
#' @export
#' @examples
#' set.seed(1)
#' # redundant task: total = a1 + a2 held constant; variance mostly along the UCM
#' a1 <- rnorm(200, 30, 4); a2 <- 60 - a1 + rnorm(200, 0, 0.5)
#' uncontrolledManifold(cbind(a1, a2), jacobian = matrix(c(1, 1), nrow = 1))$delta_v
uncontrolledManifold <- function(theta, jacobian = NULL, task = NULL) {
  theta <- as.matrix(theta)
  N <- nrow(theta); n <- ncol(theta)
  if (N < 2L) stop("need >= 2 trials (rows).", call. = FALSE)
  mbar <- colMeans(theta)
  if (is.null(jacobian)) {
    if (is.null(task)) stop("provide `jacobian` or `task`.", call. = FALSE)
    jacobian <- .ucm_jacobian(task, mbar)
  }
  J <- matrix(jacobian, nrow = NROW(jacobian))
  if (ncol(J) != n) stop("`jacobian` must have n columns (one per elemental variable).", call. = FALSE)
  d <- nrow(J)
  Enull <- .ucm_null_basis(J)                       # n x (n-d)
  dim_ucm <- ncol(Enull); dim_ort <- n - dim_ucm
  dev <- sweep(theta, 2L, mbar)                     # N x n deviations
  # projection onto the UCM (null space)
  par <- dev %*% Enull %*% t(Enull)                 # component along the manifold
  perp <- dev - par
  ss_par <- sum(par^2); ss_perp <- sum(perp^2)
  v_ucm <- ss_par / (N * max(dim_ucm, 1))
  v_ort <- ss_perp / (N * max(dim_ort, 1))
  v_total <- (ss_par + ss_perp) / (N * n)
  structure(list(
    v_ucm = v_ucm, v_ort = v_ort, v_total = v_total,
    delta_v = (v_ucm - v_ort) / v_total,
    dim_ucm = dim_ucm, dim_ort = dim_ort, n = n, d = d, N = N),
    class = "ucm_result")
}

#' @export
print.ucm_result <- function(x, ...) {
  cat(sprintf("Uncontrolled Manifold analysis -- %d trials, %d elements, task dim %d\n",
              x$N, x$n, x$d))
  cat(sprintf("  V_ucm = %.4g (good, along manifold)   V_ort = %.4g (bad)\n",
              x$v_ucm, x$v_ort))
  cat(sprintf("  synergy index dV = %.3f  (%s)\n", x$delta_v,
              if (x$delta_v > 0) "task-stabilising synergy" else "no stabilising synergy"))
  invisible(x)
}

#' Goal-Equivalent Manifold (GEM) decomposition for a scalar goal
#'
#' The scalar-goal special case of UCM (Cusumano & Cesari 2006): given the
#' gradient of a scalar goal function, split the execution variability into
#' goal-equivalent (along the level set -- does not change the goal) and
#' non-goal-equivalent (along the gradient -- changes it), and report the
#' motor-equivalent ratio.
#'
#' @param execution An `N x m` matrix of execution/body variables across trials.
#' @param goal_gradient Length-`m` gradient of the goal function at the mean (the
#'   direction in which the goal changes fastest). Provide this, or `goal`.
#' @param goal Optional scalar goal function `R^m -> R`; its gradient is computed
#'   numerically at the mean when `goal_gradient` is not given.
#' @return a `gem_result` list: `gev` (goal-equivalent variance, along the GEM),
#'   `ngev` (non-goal-equivalent variance, along the gradient), `me_ratio`
#'   (`gev / ngev`, > 1 = variability channelled into the goal-irrelevant
#'   direction), `log_me_ratio`.
#' @references Cusumano JP, Cesari P (2006) Biol Cybern 94:367-379.
#' @seealso [uncontrolledManifold()]
#' @export
#' @examples
#' set.seed(2)
#' x1 <- rnorm(200, 10, 3); x2 <- 20 - x1 + rnorm(200, 0, 0.4)  # x1+x2 ~ const
#' goalEquivalentManifold(cbind(x1, x2), goal_gradient = c(1, 1))$me_ratio
goalEquivalentManifold <- function(execution, goal_gradient = NULL, goal = NULL) {
  X <- as.matrix(execution); N <- nrow(X); m <- ncol(X)
  if (N < 2L) stop("need >= 2 trials.", call. = FALSE)
  mbar <- colMeans(X)
  if (is.null(goal_gradient)) {
    if (is.null(goal)) stop("provide `goal_gradient` or `goal`.", call. = FALSE)
    goal_gradient <- as.numeric(.ucm_jacobian(function(p) goal(p), mbar))
  }
  g <- as.numeric(goal_gradient)
  if (length(g) != m) stop("`goal_gradient` must have length m.", call. = FALSE)
  gn <- g / sqrt(sum(g^2))                          # unit gradient
  dev <- sweep(X, 2L, mbar)
  along <- as.numeric(dev %*% gn)                   # non-goal-equivalent component
  ngev <- sum(along^2) / N                          # 1 DOF along the gradient
  gev <- (sum(dev^2) - sum(along^2)) / (N * (m - 1))
  structure(list(gev = gev, ngev = ngev,
                 me_ratio = gev / ngev, log_me_ratio = log(gev / ngev),
                 m = m, N = N), class = "gem_result")
}

#' @export
print.gem_result <- function(x, ...) {
  cat(sprintf("Goal-Equivalent Manifold -- %d trials, %d execution variables\n", x$N, x$m))
  cat(sprintf("  GEV = %.4g (goal-equivalent)   NGEV = %.4g (non-goal-equivalent)\n",
              x$gev, x$ngev))
  cat(sprintf("  motor-equivalent ratio = %.2f (log %.2f)\n", x$me_ratio, x$log_me_ratio))
  invisible(x)
}

#' Tolerance-Noise-Covariation (TNC) decomposition of result error
#'
#' Decomposes the mean result error of a set of executions (Muller & Sternad
#' 2004): how much error is removable by moving the mean to a more **tolerant**
#' region, how much is due to dispersion (**noise**) around that region, and how
#' much the observed inter-variable **covariation** already saves relative to a
#' de-covaried (column-permuted) surrogate.
#'
#' @param execution An `N x m` matrix of execution variables.
#' @param error_fn A vectorised error function: given an `N x m` matrix it
#'   returns the length-`N` per-trial error (>= 0, 0 = perfect).
#' @param optimum Length-`m` execution vector achieving (near-)zero error, used
#'   as the most tolerant target. When `NULL`, the dispersion (noise) reference
#'   is the cloud centroid.
#' @param n_surrogate Number of column-permutation surrogates for the covariation
#'   estimate (default 200).
#' @return a `tnc_result` list: `tolerance`, `noise`, `covariation` (error
#'   components; covariation > 0 = the observed covariation reduces error),
#'   `e_data` (mean data error), `e_optimum`.
#' @references Muller H, Sternad D (2004) J Exp Psychol Hum Percept Perform
#'   30:212-233; Cohen RG, Sternad D (2009) Exp Brain Res 193:69-83.
#' @seealso [uncontrolledManifold()]
#' @export
#' @examples
#' set.seed(3)
#' # redundant reaching task: result = x1 + x2, target 20, error squared
#' x1 <- rnorm(300, 12, 3); x2 <- 20 - x1 + rnorm(300, 0, 0.6)   # covary to hit 20
#' err <- function(M) (M[, 1] + M[, 2] - 20)^2
#' toleranceNoiseCovariation(cbind(x1, x2), err, optimum = c(10, 10))$covariation
toleranceNoiseCovariation <- function(execution, error_fn, optimum = NULL,
                                       n_surrogate = 200L) {
  X <- as.matrix(execution); N <- nrow(X); m <- ncol(X)
  if (N < 2L) stop("need >= 2 trials.", call. = FALSE)
  e_data <- mean(error_fn(X))
  cen <- colMeans(X)
  target <- if (is.null(optimum)) cen else as.numeric(optimum)
  # tolerance: shift the whole cloud so its centroid sits at the optimum
  Xt <- sweep(sweep(X, 2L, cen), 2L, target, "+")
  e_tol <- mean(error_fn(Xt))
  tolerance <- e_data - e_tol
  # noise: dispersion error of the tolerance-optimised cloud above the optimum
  e_opt <- if (is.null(optimum)) e_tol else mean(error_fn(matrix(target, 1L, m)))
  noise <- e_tol - e_opt
  # covariation: extra error when the observed covariation is destroyed
  perm_err <- vapply(seq_len(n_surrogate), function(s) {
    Xs <- Xt
    for (j in seq_len(m)) Xs[, j] <- Xt[sample.int(N), j]   # independent column shuffles
    mean(error_fn(Xs))
  }, numeric(1))
  covariation <- mean(perm_err) - e_tol
  structure(list(tolerance = tolerance, noise = noise, covariation = covariation,
                 e_data = e_data, e_optimum = e_opt, N = N, m = m),
            class = "tnc_result")
}

#' @export
print.tnc_result <- function(x, ...) {
  cat(sprintf("Tolerance-Noise-Covariation -- %d trials, %d execution variables\n", x$N, x$m))
  cat(sprintf("  mean data error = %.4g\n", x$e_data))
  cat(sprintf("  Tolerance = %.4g   Noise = %.4g   Covariation = %.4g\n",
              x$tolerance, x$noise, x$covariation))
  invisible(x)
}
