# Forward dynamics and predictive simulation for a planar limb.
#
# Inverse dynamics (already in the package) computes the joint torques that
# produced a MEASURED motion. Forward dynamics is the other direction: given the
# torques, what motion results -- the basis of predictive simulation, where we
# ask what movement the model WOULD produce under a control objective (e.g.
# minimal effort), rather than fitting recorded data.
#
# Provides: a validated planar two-segment limb model (thigh-shank, upper arm-
# forearm; analytic mass matrix / Coriolis / gravity), a model-agnostic RK4
# integrator, and a direct-collocation minimal-effort predictive simulation.
# Dependency-free base R (+ stats::optim for the optimal control).

#' Planar two-segment limb model (equations of motion)
#'
#' Builds the analytic dynamics of a planar two-link limb with distributed
#' segment mass: the mass matrix `M(q)`, the Coriolis/centrifugal matrix, the
#' gravity vector, and forward/inverse dynamics. Angles are joint angles
#' (proximal, then distal relative to the proximal segment), measured so gravity
#' acts in `-y`.
#'
#' @param mass Length-2 segment masses (kg).
#' @param length Length-2 segment lengths (m).
#' @param com Length-2 distances of each segment centre of mass from its proximal
#'   joint (m); default `length / 2`.
#' @param inertia Length-2 segment moments of inertia about the CoM (kg m^2);
#'   default the thin-rod `mass * length^2 / 12`.
#' @param g Gravitational acceleration (m/s^2, default 9.81; use 0 for a
#'   horizontal-plane / no-gravity model).
#' @return a `planar_limb_model`: functions `M(q)`, `coriolis(q, qd)` (matrix),
#'   `gravity(q)`, `forward_accel(q, qd, tau)`, `inverse_dynamics(q, qd, qdd)`,
#'   `energy(q, qd)` (kinetic, potential, total), and `ndof = 2`.
#' @references Spong MW, et al. (2006) Robot Modeling and Control.
#' @seealso [forwardDynamics()], [predictiveSimulation()]
#' @export
#' @examples
#' m <- planarLimbModel(mass = c(7, 3), length = c(0.4, 0.4))
#' m$energy(c(0, 0), c(1, 0))$total
planarLimbModel <- function(mass, length, com = length / 2,
                            inertia = mass * length^2 / 12, g = 9.81) {
  stopifnot(length(mass) == 2, length(length) == 2)
  m1 <- mass[1]; m2 <- mass[2]; l1 <- length[1]
  r1 <- com[1]; r2 <- com[2]; I1 <- inertia[1]; I2 <- inertia[2]
  a  <- I1 + I2 + m1 * r1^2 + m2 * (l1^2 + r2^2)
  b  <- m2 * l1 * r2
  d  <- I2 + m2 * r2^2
  Mf <- function(q) {
    c2 <- cos(q[2])
    matrix(c(a + 2 * b * c2, d + b * c2,
             d + b * c2,     d), 2, 2, byrow = TRUE)
  }
  Cf <- function(q, qd) {
    s2 <- sin(q[2])
    matrix(c(-b * s2 * qd[2], -b * s2 * (qd[1] + qd[2]),
              b * s2 * qd[1],  0), 2, 2, byrow = TRUE)
  }
  Gf <- function(q) {
    c(( m1 * r1 + m2 * l1) * g * cos(q[1]) + m2 * r2 * g * cos(q[1] + q[2]),
        m2 * r2 * g * cos(q[1] + q[2]))
  }
  fa <- function(q, qd, tau) as.numeric(solve(Mf(q), tau - Cf(q, qd) %*% qd - Gf(q)))
  idyn <- function(q, qd, qdd) as.numeric(Mf(q) %*% qdd + Cf(q, qd) %*% qd + Gf(q))
  en <- function(q, qd) {
    ke <- 0.5 * as.numeric(t(qd) %*% Mf(q) %*% qd)
    yc1 <- r1 * sin(q[1]); yc2 <- l1 * sin(q[1]) + r2 * sin(q[1] + q[2])
    pe <- g * (m1 * yc1 + m2 * yc2)
    list(kinetic = ke, potential = pe, total = ke + pe)
  }
  structure(list(M = Mf, coriolis = Cf, gravity = Gf, forward_accel = fa,
                 inverse_dynamics = idyn, energy = en, ndof = 2L,
                 params = list(mass = mass, length = length, com = com,
                               inertia = inertia, g = g)),
            class = "planar_limb_model")
}

#' @export
print.planar_limb_model <- function(x, ...) {
  cat(sprintf("Planar 2-segment limb model (g = %.2f)\n", x$params$g))
  cat(sprintf("  masses = (%.2f, %.2f) kg   lengths = (%.2f, %.2f) m\n",
              x$params$mass[1], x$params$mass[2], x$params$length[1], x$params$length[2]))
  invisible(x)
}

#' Forward dynamics: integrate the equations of motion
#'
#' Given a limb model, initial state and joint torques, integrates the motion
#' with a fixed-step 4th-order Runge-Kutta scheme.
#'
#' @param model A `planar_limb_model` (or any list with a `forward_accel(q, qd,
#'   tau)` and `ndof`).
#' @param q0,qd0 Initial joint angles and velocities (length `ndof`).
#' @param torque Joint torques: `NULL` (free/passive), a length-`ndof` constant,
#'   an `n_steps x ndof` matrix, or a function `(t, q, qd) -> torque`.
#' @param dt Time step (s).
#' @param n_steps Number of integration steps.
#' @return an `fd_result`: `time`, `q`, `qd` (`(n_steps+1) x ndof`), `tau`, and
#'   `energy` (total mechanical energy per step).
#' @seealso [planarLimbModel()], [predictiveSimulation()]
#' @export
#' @examples
#' m <- planarLimbModel(c(7, 3), c(0.4, 0.4))
#' fd <- forwardDynamics(m, q0 = c(pi/2 - 0.3, 0.2), qd0 = c(0, 0),
#'                       torque = NULL, dt = 0.001, n_steps = 500)
#' diff(range(fd$energy)) / mean(abs(fd$energy))     # ~ 0: energy conserved
forwardDynamics <- function(model, q0, qd0, torque = NULL, dt = 0.001,
                            n_steps = 1000L) {
  nd <- model$ndof; q0 <- as.numeric(q0); qd0 <- as.numeric(qd0)
  tau_at <- function(step, t, q, qd) {
    if (is.null(torque)) rep(0, nd)
    else if (is.function(torque)) as.numeric(torque(t, q, qd))
    else if (is.matrix(torque)) torque[min(step, nrow(torque)), ]
    else as.numeric(torque)
  }
  Q <- matrix(0, n_steps + 1L, nd); QD <- matrix(0, n_steps + 1L, nd)
  E <- numeric(n_steps + 1L); TAU <- matrix(0, n_steps + 1L, nd)
  Q[1, ] <- q0; QD[1, ] <- qd0
  E[1] <- if (!is.null(model$energy)) model$energy(q0, qd0)$total else NA_real_
  q <- q0; qd <- qd0
  deriv <- function(step, t, q, qd) {
    tau <- tau_at(step, t, q, qd)
    list(qd = qd, qdd = model$forward_accel(q, qd, tau), tau = tau)
  }
  for (s in seq_len(n_steps)) {
    t <- (s - 1) * dt
    k1 <- deriv(s, t, q, qd)
    k2 <- deriv(s, t + dt/2, q + dt/2 * k1$qd, qd + dt/2 * k1$qdd)
    k3 <- deriv(s, t + dt/2, q + dt/2 * k2$qd, qd + dt/2 * k2$qdd)
    k4 <- deriv(s, t + dt,   q + dt   * k3$qd, qd + dt   * k3$qdd)
    q  <- q  + dt/6 * (k1$qd  + 2*k2$qd  + 2*k3$qd  + k4$qd)
    qd <- qd + dt/6 * (k1$qdd + 2*k2$qdd + 2*k3$qdd + k4$qdd)
    Q[s + 1, ] <- q; QD[s + 1, ] <- qd; TAU[s + 1, ] <- k1$tau
    E[s + 1] <- if (!is.null(model$energy)) model$energy(q, qd)$total else NA_real_
  }
  structure(list(time = seq(0, n_steps) * dt, q = Q, qd = QD, tau = TAU,
                 energy = E, dt = dt), class = "fd_result")
}

#' @export
print.fd_result <- function(x, ...) {
  cat(sprintf("Forward-dynamics trajectory -- %d steps, dt = %g s\n",
              nrow(x$q) - 1L, x$dt))
  if (!all(is.na(x$energy)))
    cat(sprintf("  energy drift = %.2e (relative)\n",
                diff(range(x$energy)) / max(mean(abs(x$energy)), .Machine$double.eps)))
  invisible(x)
}

# Boundary quintic (pos, zero vel & acc at both ends) and its derivatives.
.ps_quintic <- function(tau) {
  s   <- 10*tau^3 - 15*tau^4 + 6*tau^5
  s1  <- 30*tau^2 - 60*tau^3 + 30*tau^4
  s2  <- 60*tau   - 180*tau^2 + 120*tau^3
  list(s = s, s1 = s1, s2 = s2)
}
# Interior bump basis phi_k = tau^(k+1)(1-tau)^2 (value & 1st deriv vanish at ends).
.ps_basis <- function(tau, K) {
  phi <- d1 <- d2 <- matrix(0, length(tau), K)
  for (k in seq_len(K)) {
    p <- k + 1
    phi[, k] <- tau^p * (1 - tau)^2
    d1[, k]  <- p*tau^(p-1)*(1-tau)^2 - 2*tau^p*(1-tau)
    d2[, k]  <- p*(p-1)*tau^(p-2)*(1-tau)^2 - 4*p*tau^(p-1)*(1-tau) + 2*tau^p
  }
  list(phi = phi, d1 = d1, d2 = d2)
}

#' Predictive simulation: minimal-effort optimal control
#'
#' Predicts the movement a limb model would produce to go from one posture to
#' another while minimising control effort (integral of squared joint torque) --
#' a direct-collocation optimal-control problem. Each joint trajectory is a
#' boundary-satisfying quintic plus interior basis functions whose amplitudes are
#' optimised; the required torque at each node is obtained by inverse dynamics.
#'
#' @param model A `planar_limb_model`.
#' @param q0,qT Start and target joint configurations (length `ndof`); velocity
#'   is zero at both ends.
#' @param duration Movement time (s).
#' @param n_nodes Collocation nodes for the effort integral (default 60).
#' @param n_basis Interior basis functions per joint (default 3).
#' @param maxit Optimiser iterations (default 200).
#' @return a `predictive_sim`: `time`, `q`, `qd`, `qdd`, `tau` (node x ndof),
#'   `effort` (optimised) and `effort_baseline` (the minimum-jerk quintic), the
#'   effort reduction, and boundary error.
#' @references Todorov & Jordan (2002); Ackermann & van den Bogert (2010)
#'   predictive simulation.
#' @seealso [forwardDynamics()]
#' @export
#' @examples
#' m <- planarLimbModel(c(2.1, 1.4), c(0.3, 0.25), g = 0)   # horizontal reach
#' ps <- predictiveSimulation(m, q0 = c(0.2, 0.3), qT = c(1.1, 0.6),
#'                            duration = 0.6, n_basis = 2, maxit = 80)
#' ps$effort <= ps$effort_baseline                          # optimisation helps
predictiveSimulation <- function(model, q0, qT, duration, n_nodes = 60L,
                                 n_basis = 3L, maxit = 200L) {
  nd <- model$ndof; q0 <- as.numeric(q0); qT <- as.numeric(qT)
  Tt <- duration; tau_grid <- seq(0, 1, length.out = n_nodes); dt <- Tt / (n_nodes - 1)
  quin <- .ps_quintic(tau_grid); bas <- .ps_basis(tau_grid, n_basis)
  dq <- qT - q0
  # trajectory (and derivatives) for a matrix of amplitudes A (nd x K)
  traj <- function(A) {
    q <- qd <- qdd <- matrix(0, n_nodes, nd)
    for (j in seq_len(nd)) {
      q[, j]   <- q0[j] + dq[j]*quin$s      + bas$phi %*% A[j, ]
      qd[, j]  <- (dq[j]*quin$s1            + bas$d1 %*% A[j, ]) / Tt
      qdd[, j] <- (dq[j]*quin$s2            + bas$d2 %*% A[j, ]) / Tt^2
    }
    list(q = q, qd = qd, qdd = qdd)
  }
  effort_of <- function(tr) {
    tau <- t(vapply(seq_len(n_nodes), function(i)
      model$inverse_dynamics(tr$q[i, ], tr$qd[i, ], tr$qdd[i, ]), numeric(nd)))
    list(tau = tau, effort = sum(rowSums(tau^2)) * dt)
  }
  obj <- function(par) {
    A <- matrix(par, nd, n_basis)
    effort_of(traj(A))$effort
  }
  A0 <- matrix(0, nd, n_basis)
  base <- effort_of(traj(A0))
  opt <- stats::optim(as.numeric(A0), obj, method = "BFGS",
                      control = list(maxit = maxit))
  A <- matrix(opt$par, nd, n_basis)
  tr <- traj(A); ef <- effort_of(tr)
  structure(list(
    time = tau_grid * Tt, q = tr$q, qd = tr$qd, qdd = tr$qdd, tau = ef$tau,
    effort = ef$effort, effort_baseline = base$effort,
    effort_reduction = 1 - ef$effort / base$effort,
    boundary_error = max(abs(tr$q[n_nodes, ] - qT)),
    converged = opt$convergence == 0, ndof = nd, duration = Tt),
    class = "predictive_sim")
}

#' @export
print.predictive_sim <- function(x, ...) {
  cat(sprintf("Predictive simulation (minimal effort) -- %d dof, %.2f s\n",
              x$ndof, x$duration))
  cat(sprintf("  effort %.4g (baseline %.4g, %.1f%% reduction)\n",
              x$effort, x$effort_baseline, 100 * x$effort_reduction))
  cat(sprintf("  target reached to %.2e rad\n", x$boundary_error))
  invisible(x)
}
