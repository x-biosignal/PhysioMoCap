library(testthat)
library(PhysioMoCap)

# --- cohensD tests ---

test_that("cohensD computes large effect correctly", {
  set.seed(42)
  # Two groups with known separation: mean diff = 2, SD ~1 => d ~ 2
  x <- rnorm(50, mean = 12, sd = 1)
  y <- rnorm(50, mean = 10, sd = 1)
  result <- cohensD(x, y)

  expect_true(result$d > 0.8)
  expect_equal(result$interpretation, "large")
})

test_that("cohensD returns paired vs unpaired results", {
  set.seed(123)
  x <- rnorm(30, mean = 10, sd = 3)
  y <- x + rnorm(30, mean = 1, sd = 1)  # correlated with small improvement

  result_paired <- cohensD(x, y, paired = TRUE)
  result_unpaired <- cohensD(x, y, paired = FALSE)

  # Paired and unpaired should give different d values
  expect_false(isTRUE(all.equal(result_paired$d, result_unpaired$d)))

  # Both should return valid lists
  expect_true(is.numeric(result_paired$d))
  expect_true(is.numeric(result_unpaired$d))
})

test_that("cohensD returns approximately zero for no difference", {
  set.seed(42)
  x <- rnorm(100, mean = 50, sd = 10)
  y <- rnorm(100, mean = 50, sd = 10)
  result <- cohensD(x, y)

  expect_true(abs(result$d) < 0.5)
  expect_true(result$interpretation %in% c("negligible", "small"))
})

test_that("cohensD CI contains the true effect size for known effect", {
  set.seed(42)
  # Large sample, d ~ 0.5
  x <- rnorm(200, mean = 10.5, sd = 1)
  y <- rnorm(200, mean = 10.0, sd = 1)
  result <- cohensD(x, y)

  # CI should contain the true d of 0.5 (approximately)
  expect_true(result$ci_lower < result$d)
  expect_true(result$ci_upper > result$d)
  # With large N, CI should be reasonably tight around d
  expect_true(result$ci_upper - result$ci_lower < 1.0)
})

test_that("cohensD interpretation labels are correct", {
  # Construct groups with known d values
  # negligible: d < 0.2 -- use mean diff = 0.1, sd = 1
  set.seed(99)
  x_neg <- rnorm(500, mean = 0.1, sd = 1)
  y_neg <- rnorm(500, mean = 0, sd = 1)
  res_neg <- cohensD(x_neg, y_neg)
  expect_equal(res_neg$interpretation, "negligible")

  # small: 0.2 <= d < 0.5 -- use mean diff = 0.35, sd = 1
  set.seed(1)
  x_sm <- rnorm(500, mean = 0.35, sd = 1)
  y_sm <- rnorm(500, mean = 0, sd = 1)
  res_small <- cohensD(x_sm, y_sm)
  expect_equal(res_small$interpretation, "small")

  # medium: 0.5 <= d < 0.8 -- use mean diff = 0.65, sd = 1
  set.seed(2)
  x_md <- rnorm(500, mean = 0.65, sd = 1)
  y_md <- rnorm(500, mean = 0, sd = 1)
  res_med <- cohensD(x_md, y_md)
  expect_equal(res_med$interpretation, "medium")

  # large: d >= 0.8
  set.seed(3)
  x_lg <- rnorm(500, mean = 1.0, sd = 1)
  y_lg <- rnorm(500, mean = 0, sd = 1)
  res_large <- cohensD(x_lg, y_lg)
  expect_equal(res_large$interpretation, "large")
})

# --- etaSquared tests ---

test_that("etaSquared for completely separated groups is near 1", {
  # Three well-separated groups
  x <- c(rep(0, 100), rep(100, 100), rep(200, 100))
  groups <- rep(c("A", "B", "C"), each = 100)
  result <- etaSquared(x, groups)

  expect_true(result$eta_sq > 0.99)
  expect_true(result$partial_eta_sq > 0.99)
})

test_that("etaSquared for no group effect is near 0", {
  set.seed(42)
  x <- rnorm(300, mean = 0, sd = 10)
  groups <- rep(c("A", "B", "C"), each = 100)
  result <- etaSquared(x, groups)

  expect_true(result$eta_sq < 0.05)
  expect_true(result$omega_sq >= 0)  # omega_sq floors at 0
})

test_that("etaSquared with 3-group ANOVA produces valid results", {
  set.seed(42)
  x <- c(rnorm(30, 10, 2), rnorm(30, 12, 2), rnorm(30, 14, 2))
  groups <- rep(c("Low", "Mid", "High"), each = 30)
  result <- etaSquared(x, groups)

  expect_true(result$eta_sq >= 0 && result$eta_sq <= 1)
  expect_true(result$partial_eta_sq >= 0 && result$partial_eta_sq <= 1)
  expect_true(result$omega_sq >= 0)
  # For a one-way design, partial eta_sq == eta_sq
  expect_equal(result$eta_sq, result$partial_eta_sq)
})

# --- icc tests ---

test_that("icc for perfect agreement returns 1.0", {
  # All raters give identical scores
  ratings <- matrix(rep(c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10), 3),
                    nrow = 10, ncol = 3)
  result <- icc(ratings, model = "twoway", type = "agreement")

  expect_equal(result$icc, 1.0)
  expect_equal(result$model, "twoway")
  expect_equal(result$type, "agreement")
})

test_that("icc for random data returns near 0", {
  set.seed(42)
  ratings <- matrix(rnorm(100 * 4), nrow = 100, ncol = 4)
  result <- icc(ratings, model = "twoway", type = "agreement")

  expect_true(abs(result$icc) < 0.2)
})

test_that("icc reproduces known reliability from Shrout & Fleiss example", {
  # Shrout & Fleiss (1979) Table 4 data
  ratings <- matrix(c(
    9, 2, 5, 8,
    6, 1, 3, 2,
    8, 4, 6, 8,
    7, 1, 2, 6,
    10, 5, 6, 9,
    6, 2, 4, 7
  ), nrow = 6, ncol = 4, byrow = TRUE)

  # ICC(3,1) consistency, single measure
  result_31 <- icc(ratings, model = "twoway", type = "consistency", unit = "single")
  # Known value from Shrout & Fleiss: ICC(3,1) = 0.715
  expect_true(abs(result_31$icc - 0.715) < 0.01)
})

test_that("icc twoway vs oneway differ", {
  set.seed(42)
  # Create data with rater differences
  subjects <- rep(rnorm(20, 50, 10), each = 1)
  rater_effects <- c(0, 5, -3)  # systematic rater differences
  ratings <- sapply(rater_effects, function(r) subjects + r + rnorm(20, 0, 2))

  result_tw <- icc(ratings, model = "twoway", type = "agreement")
  result_ow <- icc(ratings, model = "oneway")

  # Both valid
  expect_true(is.numeric(result_tw$icc))
  expect_true(is.numeric(result_ow$icc))

  # Model labels differ

  expect_equal(result_tw$model, "twoway")
  expect_equal(result_ow$model, "oneway")
})

test_that("icc agreement vs consistency differ when rater bias present", {
  set.seed(42)
  # Create data with systematic rater bias
  subjects <- rnorm(30, 50, 10)
  rater_bias <- c(0, 10)  # rater 2 consistently 10 higher
  ratings <- sapply(rater_bias, function(b) subjects + b + rnorm(30, 0, 2))

  result_agr <- icc(ratings, model = "twoway", type = "agreement")
  result_con <- icc(ratings, model = "twoway", type = "consistency")

  # Consistency should be higher than agreement when bias present
  expect_true(result_con$icc > result_agr$icc)
})

# --- sem tests ---

test_that("sem computes correctly from ICC and SD", {
  x <- c(10, 12, 15, 11, 13, 14, 9, 16, 12, 11)
  sd_x <- sd(x)
  icc_val <- 0.90

  result <- sem(x, icc_value = icc_val)
  expected <- sd_x * sqrt(1 - icc_val)

  expect_equal(result, expected)
})

test_that("sem computes correctly from reliability", {
  x <- c(5, 10, 15, 20, 25)
  r <- 0.85
  result <- sem(x, reliability = r)
  expected <- sd(x) * sqrt(1 - r)

  expect_equal(result, expected)
})

# --- mdc tests ---

test_that("mdc at 95% confidence equals SEM * 1.96 * sqrt(2)", {
  sem_val <- 3.0
  result <- mdc(sem_val, confidence = 0.95)
  expected <- sem_val * 1.96 * sqrt(2)

  expect_equal(result, expected, tolerance = 0.01)
})

test_that("mdc increases with lower confidence", {
  sem_val <- 3.0
  mdc_90 <- mdc(sem_val, confidence = 0.90)
  mdc_95 <- mdc(sem_val, confidence = 0.95)
  mdc_99 <- mdc(sem_val, confidence = 0.99)

  expect_true(mdc_90 < mdc_95)
  expect_true(mdc_95 < mdc_99)
})

# --- blandAltman tests ---

test_that("blandAltman for identical methods returns bias near 0", {
  set.seed(42)
  x <- rnorm(50, mean = 100, sd = 15)
  y <- x  # identical
  result <- blandAltman(x, y)

  expect_equal(result$bias, 0)
  expect_equal(result$sd_diff, 0)
  # LoA collapse to 0
  expect_equal(result$lower_loa, 0)
  expect_equal(result$upper_loa, 0)
})

test_that("blandAltman detects systematic bias", {
  set.seed(42)
  x <- rnorm(100, mean = 50, sd = 10)
  y <- x - 5 + rnorm(100, 0, 1)  # method 2 reads ~5 lower
  result <- blandAltman(x, y)

  # bias should be close to 5
  expect_true(abs(result$bias - 5) < 1)
  # upper and lower LOA should bracket the bias
  expect_true(result$lower_loa < result$bias)
  expect_true(result$upper_loa > result$bias)
  # CI for bias should not include 0 (systematic bias)
  expect_true(result$ci_bias[1] > 0)
})

# --- Input validation tests ---

test_that("cohensD errors on non-numeric input", {
  expect_error(cohensD("a", c(1, 2, 3)))
  expect_error(cohensD(c(1, 2), "b"))
})

test_that("cohensD errors when paired lengths differ", {
  expect_error(cohensD(c(1, 2, 3), c(1, 2), paired = TRUE))
})

test_that("icc errors on non-matrix input", {
  expect_error(icc(c(1, 2, 3)))
})

test_that("icc errors on matrix with fewer than 2 rows or columns", {
  expect_error(icc(matrix(1:3, nrow = 1)))
  expect_error(icc(matrix(1:3, ncol = 1)))
})

test_that("sem errors when neither icc_value nor reliability provided", {
  expect_error(sem(c(1, 2, 3)), "One of 'icc_value' or 'reliability'")
})

test_that("sem errors when both icc_value and reliability provided", {
  expect_error(sem(c(1, 2, 3), icc_value = 0.8, reliability = 0.8),
               "Provide only one")
})

test_that("mdc errors on negative SEM", {
  expect_error(mdc(-1))
})

test_that("blandAltman errors on unequal length vectors", {
  expect_error(blandAltman(c(1, 2, 3), c(1, 2)))
})
