test_that("plotBlandAltman reference lines are single-sourced from blandAltman()", {
  skip_if_not_installed("ggplot2")
  set.seed(1)
  m1 <- rnorm(30, 50, 10)
  m2 <- m1 + rnorm(30, 0, 3)
  ba <- blandAltman(m1, m2)

  p <- plotBlandAltman(m1, m2)
  expect_s3_class(p, "ggplot")

  hl <- Filter(function(l) inherits(l$geom, "GeomHline"), p$layers)
  expect_length(hl, 3L)
  yi <- unname(sort(vapply(hl, function(l) as.numeric(l$data$yintercept),
                           numeric(1))))
  want <- sort(c(ba$bias, ba$lower_loa, ba$upper_loa))
  expect_equal(yi, want, tolerance = 1e-8)
  # confidence level flows through to blandAltman()
  ba90 <- blandAltman(m1, m2, confidence = 0.90)
  hl90 <- Filter(function(l) inherits(l$geom, "GeomHline"),
                 plotBlandAltman(m1, m2, confidence = 0.90)$layers)
  yi90 <- unname(sort(vapply(hl90, function(l) as.numeric(l$data$yintercept),
                             numeric(1))))
  expect_equal(yi90, sort(c(ba90$bias, ba90$lower_loa, ba90$upper_loa)),
               tolerance = 1e-8)
})

test_that("plotBlandAltman validates inputs like blandAltman()", {
  skip_if_not_installed("ggplot2")
  expect_error(plotBlandAltman(1:3, 1:2))       # unequal lengths
  expect_error(plotBlandAltman(1, 1))           # n < 2
  expect_error(plotBlandAltman(1:5, 1:5, confidence = 1.5))
  # n == 2 is the minimum accepted
  expect_s3_class(plotBlandAltman(c(1, 2), c(1.1, 2.1)), "ggplot")
})

test_that("plotBlandAltman builds in both constant and proportional modes", {
  skip_if_not_installed("ggplot2")
  set.seed(2)
  m1 <- rnorm(40, 100, 15)
  m2 <- m1 * 1.02 + rnorm(40, 0, 4)  # proportional error

  p_const <- plotBlandAltman(m1, m2, units = "N")
  expect_silent(ggplot2::ggplot_build(p_const))
  expect_match(p_const$labels$x, "N")

  p_prop <- plotBlandAltman(m1, m2, proportional_bias = TRUE)
  expect_silent(ggplot2::ggplot_build(p_prop))
  # proportional mode draws sloped lines (geom_abline), not constant hlines
  expect_true(any(vapply(p_prop$layers,
    function(l) inherits(l$geom, "GeomAbline"), logical(1))))
  expect_false(any(vapply(p_prop$layers,
    function(l) inherits(l$geom, "GeomHline"), logical(1))))
})

test_that("proportional mode requires n>=3 and uses residual (n-2) df for the CI band", {
  skip_if_not_installed("ggplot2")
  # n = 2 is degenerate for a regression (residual df 0) -> clear error, not a
  # silent NaN LoA/ribbon
  expect_error(plotBlandAltman(c(1, 2), c(1.1, 2.1), proportional_bias = TRUE),
               "at least 3")

  set.seed(3)
  m1 <- rnorm(8, 100, 15)
  m2 <- m1 * 1.02 + rnorm(8, 0, 4)
  p <- plotBlandAltman(m1, m2, proportional_bias = TRUE)
  rib <- p$layers[[which(vapply(p$layers,
    function(l) inherits(l$geom, "GeomRibbon"), logical(1)))]]$data

  # reference: lm mean-response CI, which internally uses residual df n-2
  dd <- data.frame(ba_mean = (m1 + m2) / 2, ba_diff = m1 - m2)
  fit <- stats::lm(ba_diff ~ ba_mean, data = dd)
  ci <- stats::predict(fit, newdata = data.frame(ba_mean = rib$ba_mean),
                       interval = "confidence", level = 0.95)
  expect_equal(rib$lwr, unname(ci[, "lwr"]), tolerance = 1e-8)
  expect_equal(rib$upr, unname(ci[, "upr"]), tolerance = 1e-8)
})

test_that("colorblind = FALSE still returns a valid plot", {
  skip_if_not_installed("ggplot2")
  p <- plotBlandAltman(c(1, 2, 3, 4), c(1.1, 2.2, 2.9, 4.1), colorblind = FALSE)
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})
