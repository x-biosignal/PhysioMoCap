library(testthat)
library(PhysioMoCap)

# --- helpers ------------------------------------------------------------------

# A feasible redundant SO problem: torques generated from known activations.
.make_so_problem <- function(n_muscle = 6, n_dof = 2, n_frames = 15, seed = 1) {
  set.seed(seed)
  r <- matrix(stats::runif(n_dof * n_muscle, -0.05, 0.05), n_dof, n_muscle)
  fmax <- stats::runif(n_muscle, 200, 1200)
  a_true <- matrix(stats::runif(n_frames * n_muscle, 0, 0.6), n_frames, n_muscle)
  cmat <- sweep(r, 2, fmax, "*")
  tau <- t(apply(a_true, 1, function(a) as.numeric(cmat %*% a)))
  list(r = r, fmax = fmax, a_true = a_true, tau = tau)
}

# --- staticOptimizationR ------------------------------------------------------

test_that("pure-R SO recovers the joint torque within 1e-6 and keeps a in [0,1]", {
  skip_if_not_installed("quadprog")
  p <- .make_so_problem()
  so <- staticOptimizationR(p$r, p$fmax, p$tau)
  expect_s3_class(so, "static_optimization_r")
  expect_true(all(so$feasible))
  expect_lt(max(so$residual), 1e-6)
  expect_true(all(so$activations >= 0 & so$activations <= 1))
})

test_that("pure-R SO finds the minimum-effort solution", {
  skip_if_not_installed("quadprog")
  p <- .make_so_problem()
  so <- staticOptimizationR(p$r, p$fmax, p$tau)
  # the optimum's effort is <= the effort of the (feasible) generating activations
  gen_effort <- rowSums(p$a_true^2)
  expect_true(all(so$effort <= gen_effort + 1e-8))
})

test_that("a single-frame vector problem solves analytically", {
  skip_if_not_installed("quadprog")
  # two identical muscles share a moment of 30 -> a = 0.15 each (min sum a^2)
  so <- staticOptimizationR(matrix(c(1, 1), 1, 2), c(100, 100), 30)
  expect_equal(as.numeric(so$activations), c(0.15, 0.15), tolerance = 1e-7)
  expect_equal(so$moments[1, 1], 30, tolerance = 1e-7)
})

test_that("weights bias the effort distribution", {
  skip_if_not_installed("quadprog")
  # unit moment arms; weighting muscle 2 more heavily shifts load to muscle 1
  so <- staticOptimizationR(matrix(c(1, 1), 1, 2), c(100, 100), 20,
                            weights = c(1, 4))
  expect_gt(so$activations[1, 1], so$activations[1, 2])
  expect_equal(so$moments[1, 1], 20, tolerance = 1e-7)
})

test_that("passive_moments are subtracted before optimization", {
  skip_if_not_installed("quadprog")
  so_a <- staticOptimizationR(matrix(c(1, 1), 1, 2), c(100, 100), 30)
  so_b <- staticOptimizationR(matrix(c(1, 1), 1, 2), c(100, 100), 40,
                              passive_moments = 10)
  expect_equal(so_a$activations, so_b$activations, tolerance = 1e-8)
})

test_that("per-frame moment arms are honoured", {
  skip_if_not_installed("quadprog")
  arms <- list(matrix(c(1, 1), 1, 2), matrix(c(2, 1), 1, 2))
  tau <- matrix(c(30, 40), 2, 1)
  so <- staticOptimizationR(arms, c(100, 100), tau)
  expect_true(all(so$feasible))
  expect_equal(so$moments[, 1], c(30, 40), tolerance = 1e-7)
})

test_that("an infeasible frame is reported, not silently wrong", {
  skip_if_not_installed("quadprog")
  # moment far larger than muscles can produce with a in [0,1]
  so <- staticOptimizationR(matrix(c(0.01, 0.01), 1, 2), c(100, 100), 1e6)
  expect_false(so$feasible[1])
  expect_true(all(is.na(so$activations[1, ])))
  expect_true(is.na(so$residual[1]))
})

test_that("staticOptimizationR validates its inputs", {
  skip_if_not_installed("quadprog")
  r <- matrix(c(1, 1), 1, 2)
  expect_error(staticOptimizationR(r, c(0, 100), 10), "positive numeric")
  expect_error(staticOptimizationR(r, c(100, 100), 10, weights = c(1, 1, 1)),
               "length-n_muscle")
  expect_error(staticOptimizationR(r, c(100, 100), 10,
                                   activation_bounds = c(1, 0)), "lower < upper")
  expect_error(staticOptimizationR(matrix(1, 1, 3), c(100, 100), 10), "must be")
  expect_error(staticOptimizationR(list(r), c(100, 100),
                                   matrix(c(1, 2), 2, 1)), "one matrix per frame")
})

test_that("static_optimization_r prints a summary", {
  skip_if_not_installed("quadprog")
  so <- staticOptimizationR(matrix(c(1, 1), 1, 2), c(100, 100), 30)
  expect_output(print(so), "static_optimization_r")
})

# --- runStaticOptimization orchestrator --------------------------------------

test_that("runStaticOptimization falls back to pure-R when OpenSim is absent", {
  skip_if_not_installed("quadprog")
  skip_if(PhysioMoCap:::.opensim_backend_available(),
          "OpenSim backend present; this test targets the R fallback")
  p <- .make_so_problem()
  res <- runStaticOptimization(moment_arms = p$r, max_force = p$fmax,
                               joint_moments = p$tau)
  expect_s3_class(res, "opensim_so_result")
  expect_identical(res$backend, "r")
  expect_lt(max(res$static_optimization$residual), 1e-6)
})

test_that("runStaticOptimization execution='r' forces the pure-R backend", {
  skip_if_not_installed("quadprog")
  p <- .make_so_problem()
  res <- runStaticOptimization(moment_arms = p$r, max_force = p$fmax,
                               joint_moments = p$tau, execution = "r")
  expect_identical(res$backend, "r")
  expect_output(print(res), "backend: r")
})

test_that("runStaticOptimization errors without a backend or inputs", {
  expect_error(
    runStaticOptimization(execution = "r"),
    "moment_arms")
  skip_if(PhysioMoCap:::.opensim_backend_available(), "OpenSim backend present")
  expect_error(
    runStaticOptimization(so_setup = "so.xml", execution = "opensim"),
    "OpenSim backend")
})

# --- runRRA / runCMC (OpenSim-only) ------------------------------------------

test_that("runRRA / runCMC require a working OpenSim backend", {
  expect_error(runRRA(NULL), "non-empty character")
  expect_error(runCMC(NULL), "non-empty character")
  skip_if(PhysioMoCap:::.opensim_backend_available(), "OpenSim backend present")
  expect_error(runRRA("rra_setup.xml"), "OpenSim backend")
  expect_error(runCMC("cmc_setup.xml"), "OpenSim backend")
})

# --- regression tests for adversarial-review findings (WS4-10) ----------------

test_that("an over-determined but consistent moment system is solved, not flagged", {
  skip_if_not_installed("quadprog")
  # 2 DOFs, 1 muscle: C = (100, 200)^T, tau = (20, 40) is satisfied by a = 0.2
  so <- staticOptimizationR(matrix(c(1, 2), 2, 1), 100, matrix(c(20, 40), 1, 2))
  expect_true(so$feasible[1])
  expect_equal(so$activations[1, 1], 0.2, tolerance = 1e-7)
  expect_equal(so$moments[1, ], c(20, 40), tolerance = 1e-7)
  expect_lt(so$residual[1], 1e-6)
})

test_that("a genuinely inconsistent over-determined system is infeasible", {
  skip_if_not_installed("quadprog")
  # tau = (20, 50) is NOT reproducible with one muscle (needs 40 for DOF 2)
  so <- staticOptimizationR(matrix(c(1, 2), 2, 1), 100, matrix(c(20, 50), 1, 2))
  expect_false(so$feasible[1])
})

test_that("rank-deficient (coupled) DOF rows still solve when consistent", {
  skip_if_not_installed("quadprog")
  # two identical DOF rows with identical rhs -> rank 1, consistent
  so <- staticOptimizationR(matrix(c(1, 1, 1, 1), 2, 2), c(100, 100),
                            matrix(c(30, 30), 1, 2))
  expect_true(so$feasible[1])
  expect_equal(so$activations[1, ], c(0.15, 0.15), tolerance = 1e-7)
})

test_that("empty joint_moments / max_force are rejected with a clear error", {
  skip_if_not_installed("quadprog")
  expect_error(
    staticOptimizationR(matrix(numeric(0), 0, 2), c(100, 100), numeric(0)),
    "degree of freedom")
  expect_error(
    staticOptimizationR(matrix(numeric(0), 1, 0), numeric(0), 5),
    "non-empty positive")
})

test_that("runRRA/runCMC thread the cli argument through the backend check", {
  # cli is accepted (no unused-arg error); still requires a backend locally
  skip_if(PhysioMoCap:::.opensim_backend_available(), "OpenSim backend present")
  expect_error(runRRA("rra.xml", cli = "/usr/bin/opensim-cmd"), "OpenSim backend")
  expect_error(runCMC("cmc.xml", cli = "/usr/bin/opensim-cmd"), "OpenSim backend")
})
