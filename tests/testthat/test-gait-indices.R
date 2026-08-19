library(testthat)
library(PhysioMoCap)

# --- helpers ------------------------------------------------------------------

# A tiny synthetic norm (mean = 0) for unit tests independent of PhysioGaitNorm.
.tiny_norm <- function(vars = letters[1:9], n_points = 51) {
  m <- matrix(0, length(vars), n_points,
              dimnames = list(vars, NULL))
  list(variables = vars, mean = m, sd = m + 1, cycle_length = n_points)
}

# --- GVS / GPS (Baker MAP) ----------------------------------------------------

test_that("GPS and GVS are zero for the normative mean", {
  norm <- .tiny_norm()
  kin <- norm$mean            # exactly the mean
  expect_equal(unname(gaitVariableScore(kin, norm)), rep(0, 9))
  expect_equal(gaitProfileScore(kin, norm), 0)
})

test_that("a constant offset gives the analytic GVS and GPS", {
  norm <- .tiny_norm(vars = letters[1:9], n_points = 51)
  kin <- norm$mean
  kin["c", ] <- 15           # constant +15 deg on one variable
  gvs <- gaitVariableScore(kin, norm)
  expect_equal(unname(gvs["c"]), 15)
  expect_equal(unname(gvs[setdiff(names(gvs), "c")]), rep(0, 8))
  # GPS = RMS across variables = sqrt(15^2 / 9) = 5
  expect_equal(gaitProfileScore(kin, norm), 5)
})

test_that("GPS is non-negative and sign-independent", {
  norm <- .tiny_norm(vars = c("a", "b"), n_points = 51)
  kin_pos <- norm$mean; kin_pos["a", ] <- 3
  kin_neg <- norm$mean; kin_neg["a", ] <- -3
  expect_gt(gaitProfileScore(kin_pos, norm), 0)
  expect_equal(gaitProfileScore(kin_pos, norm), gaitProfileScore(kin_neg, norm))
})

test_that("GPS increases monotonically with deviation magnitude", {
  norm <- .tiny_norm(vars = c("a", "b"), n_points = 51)
  gps <- vapply(c(1, 2, 4), function(d) {
    kin <- norm$mean; kin["a", ] <- d
    gaitProfileScore(kin, norm)
  }, numeric(1))
  expect_true(all(diff(gps) > 0))
})

test_that("movementAnalysisProfile bundles GVS + GPS and prints", {
  norm <- .tiny_norm(vars = c("a", "b"), n_points = 51)
  kin <- norm$mean; kin["b", ] <- 4
  map <- movementAnalysisProfile(kin, norm)
  expect_s3_class(map, "movement_analysis_profile")
  expect_equal(map$gps, gaitProfileScore(kin, norm))
  expect_equal(unname(map$gvs["b"]), 4)
  expect_output(print(map), "movement_analysis_profile")
})

# --- input handling -----------------------------------------------------------

test_that("kinematics accept a named list and reorder by variable", {
  norm <- .tiny_norm(vars = c("a", "b", "c"), n_points = 51)
  kin_list <- list(c = rep(6, 51), a = rep(0, 51), b = rep(0, 51))
  gvs <- gaitVariableScore(kin_list, norm)
  expect_equal(unname(gvs["c"]), 6)
  expect_identical(names(gvs), norm$variables)
})

test_that("kinematics are time-normalised to the norm cycle length", {
  norm <- .tiny_norm(vars = c("a", "b"), n_points = 51)
  # subject sampled at 101 points, constant offset on 'a'
  kin <- matrix(0, 2, 101, dimnames = list(c("a", "b"), NULL))
  kin["a", ] <- 2
  expect_equal(gaitProfileScore(kin, norm), gaitProfileScore(
    matrix(c(rep(2, 51), rep(0, 51)), 2, 51, byrow = TRUE,
           dimnames = list(c("a", "b"), NULL)), norm), tolerance = 1e-8)
})

test_that("gaitVariableScore errors on a missing variable", {
  norm <- .tiny_norm(vars = c("a", "b", "c"))
  kin <- matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL))
  expect_error(gaitVariableScore(kin, norm), "missing required variables")
})

# --- GDI (Schwartz-Rozumalski) ------------------------------------------------

test_that("GDI of the normative control set is 100 +/- 10", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  basis <- gdiBasis(norm, n_features = 15)
  G <- norm$features
  np <- basis$n_points
  vars <- norm$variables
  gdi <- vapply(seq_len(nrow(G)), function(i) {
    kin <- t(matrix(G[i, ], nrow = np, ncol = length(vars)))
    rownames(kin) <- vars
    gaitDeviationIndex(kin, basis = basis)$gdi
  }, numeric(1))
  expect_equal(mean(gdi), 100, tolerance = 1e-6)
  expect_equal(stats::sd(gdi), 10, tolerance = 1e-6)
})

test_that("GDI drops below 100 as a gait deviates, monotonically", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  basis <- gdiBasis(norm)
  base_kin <- norm$mean[norm$variables, , drop = FALSE]
  gdi <- vapply(c(0, 5, 15, 30), function(d) {
    kin <- base_kin
    kin["knee_flexion", ] <- kin["knee_flexion", ] + d
    gaitDeviationIndex(kin, basis = basis)$gdi
  }, numeric(1))
  expect_true(all(diff(gdi) < 0))      # more deviation -> lower GDI
  expect_lt(gdi[4], 100)
})

test_that("a precomputed gdiBasis reproduces the direct GDI", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  kin <- norm$mean[norm$variables, , drop = FALSE]
  kin["ankle_dorsiflexion", ] <- kin["ankle_dorsiflexion", ] + 8
  basis <- gdiBasis(norm, n_features = 15)
  expect_equal(gaitDeviationIndex(kin, basis = basis)$gdi,
               gaitDeviationIndex(kin, norm = norm, n_features = 15)$gdi)
})

test_that("gaitDeviationIndex prints and validates the basis", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  gdi <- gaitDeviationIndex(norm$mean[norm$variables, , drop = FALSE] + 3,
                            norm = norm)
  expect_s3_class(gdi, "gait_deviation_index")
  expect_output(print(gdi), "gait_deviation_index")
  expect_error(gaitDeviationIndex(matrix(0, 9, 51), basis = list()),
               "gdi_basis")
})

test_that("gdiBasis validates n_features and a features matrix", {
  norm_no_feat <- .tiny_norm()
  expect_error(gdiBasis(norm_no_feat), "no `features`")
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  expect_error(gdiBasis(norm, n_features = 0), "n_features must be")
  expect_error(gdiBasis(norm, n_features = 500), "n_features must be")
})

# --- plot ---------------------------------------------------------------------

test_that("plotMAP returns a ggplot for a MAP", {
  norm <- .tiny_norm(vars = c("a", "b", "c"))
  kin <- norm$mean; kin["b", ] <- 5
  p <- plotMAP(movementAnalysisProfile(kin, norm))
  expect_s3_class(p, "ggplot")
  expect_error(plotMAP(list()), "movement_analysis_profile")
})

# --- regression tests for adversarial-review findings (WS4-09) ----------------

test_that("duplicated variable rows in kinematics are rejected, not mis-mapped", {
  norm <- .tiny_norm(vars = c("a", "b", "c"))
  bad <- rbind(
    matrix(999, 1, 51, dimnames = list("a", NULL)),   # garbage first 'a'
    matrix(0, 1, 51, dimnames = list("a", NULL)),      # correct 'a'
    matrix(0, 1, 51, dimnames = list("b", NULL)),
    matrix(0, 1, 51, dimnames = list("c", NULL))
  )
  expect_error(gaitVariableScore(bad, norm), "duplicated variable rows")
})

test_that("a norm with an unlabelled mean matrix errors clearly", {
  norm <- list(variables = c("a", "b"),
               mean = matrix(0, 2, 51),   # no row names
               cycle_length = 51)
  expect_error(gaitProfileScore(matrix(0, 2, 51,
               dimnames = list(c("a", "b"), NULL)), norm),
               "row names")
  norm2 <- list(variables = c("a", "z"),
                mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
                cycle_length = 51)
  expect_error(gaitVariableScore(matrix(0, 2, 51,
               dimnames = list(c("a", "z"), NULL)), norm2),
               "not found in")
})

test_that("a subject equal to the feature mean warns (GDI unbounded)", {
  skip_if_not_installed("PhysioGaitNorm")
  norm <- PhysioGaitNorm::loadGaitNorm("adult_reference", cycle = 51)
  basis <- gdiBasis(norm, n_features = 15)
  mean_kin <- t(matrix(basis$mean, nrow = basis$n_points,
                       ncol = length(basis$variables)))
  rownames(mean_kin) <- basis$variables
  expect_warning(res <- gaitDeviationIndex(mean_kin, basis = basis),
                 "coincides with the normative mean")
  expect_true(is.infinite(res$gdi))
})
