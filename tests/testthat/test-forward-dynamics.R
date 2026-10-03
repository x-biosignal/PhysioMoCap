# Forward dynamics and predictive simulation, verified with physical invariants
# (energy conservation, torque round-trip, boundary conditions).

test_that("passive forward dynamics conserves mechanical energy", {
  m <- planarLimbModel(mass = c(7, 3), length = c(0.4, 0.4))
  fd <- forwardDynamics(m, q0 = c(pi/2 - 0.4, 0.3), qd0 = c(0, 0),
                        torque = NULL, dt = 5e-4, n_steps = 2000)
  rel_drift <- diff(range(fd$energy)) / mean(abs(fd$energy))
  expect_lt(rel_drift, 1e-3)                          # RK4 conserves energy
  expect_s3_class(fd, "fd_result")
  expect_equal(dim(fd$q), c(2001, 2))
})

test_that("gravity pulls a released limb downward (falls, gains KE)", {
  m <- planarLimbModel(c(5, 2), c(0.4, 0.3))
  q0 <- c(pi/2 - 0.3, 0.2)                            # off the unstable top equilibrium
  fd <- forwardDynamics(m, q0 = q0, qd0 = c(0, 0), dt = 1e-3, n_steps = 400)
  ke <- vapply(seq_len(nrow(fd$q)), function(i) m$energy(fd$q[i, ], fd$qd[i, ])$kinetic, numeric(1))
  pe <- vapply(seq_len(nrow(fd$q)), function(i) m$energy(fd$q[i, ], fd$qd[i, ])$potential, numeric(1))
  expect_gt(max(ke), 1)                               # released from rest -> gains KE
  expect_lt(min(pe), pe[1])                           # centre of mass falls
})

test_that("inverse and forward dynamics are consistent (round-trip)", {
  m <- planarLimbModel(c(6, 3), c(0.42, 0.4))
  q <- c(0.7, -0.4); qd <- c(0.5, -0.3); qdd <- c(1.2, 0.8)
  tau <- m$inverse_dynamics(q, qd, qdd)               # torque for this motion
  qdd_back <- m$forward_accel(q, qd, tau)             # acceleration from that torque
  expect_equal(qdd_back, qdd, tolerance = 1e-9)
})

test_that("a torque profile from inverse dynamics reproduces the motion", {
  m <- planarLimbModel(c(4, 2), c(0.35, 0.3), g = 0)  # horizontal plane
  t <- seq(0, 1, length.out = 501)
  # a known smooth trajectory
  q_ref  <- cbind(0.2 + 0.6 * (10*t^3 - 15*t^4 + 6*t^5),
                  0.1 + 0.4 * (10*t^3 - 15*t^4 + 6*t^5))
  dt <- t[2] - t[1]
  qd  <- rbind(c(0, 0), (q_ref[-1, ] - q_ref[-nrow(q_ref), ]) / dt)
  qdd <- rbind(c(0, 0), (qd[-1, ] - qd[-nrow(qd), ]) / dt)
  tau <- t(vapply(seq_along(t), function(i)
    m$inverse_dynamics(q_ref[i, ], qd[i, ], qdd[i, ]), numeric(2)))
  fd <- forwardDynamics(m, q0 = q_ref[1, ], qd0 = c(0, 0), torque = tau,
                        dt = dt, n_steps = length(t) - 1)
  expect_lt(max(abs(fd$q[nrow(fd$q), ] - q_ref[nrow(q_ref), ])), 0.02)
})

test_that("predictive simulation reaches the target and reduces effort", {
  m <- planarLimbModel(c(2.1, 1.4), c(0.3, 0.25), g = 0)
  ps <- predictiveSimulation(m, q0 = c(0.2, 0.3), qT = c(1.1, 0.6),
                             duration = 0.6, n_basis = 2, maxit = 120)
  expect_s3_class(ps, "predictive_sim")
  expect_lt(ps$boundary_error, 1e-6)                  # hits the target exactly
  expect_lte(ps$effort, ps$effort_baseline + 1e-8)    # never worse than min-jerk
  expect_equal(ps$q[1, ], c(0.2, 0.3), tolerance = 1e-9)     # start respected
  expect_output(print(ps), "Predictive simulation")
})

test_that("predictive simulation lowers effort against gravity vs min-jerk", {
  m <- planarLimbModel(c(6, 3), c(0.4, 0.4), g = 9.81)
  ps <- predictiveSimulation(m, q0 = c(0.3, 0.2), qT = c(1.2, 0.5),
                             duration = 0.8, n_basis = 3, maxit = 200)
  expect_gt(ps$effort_reduction, 0)                   # dynamics-aware saving
})
