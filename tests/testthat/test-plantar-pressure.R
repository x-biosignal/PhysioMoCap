library(testthat)


test_that("constructor stacks frames and validates pressure metadata", {
  frames <- list(matrix(1:4, 2, 2), matrix(5:8, 2, 2))
  pm <- pressureMovie(
    frames, sampling_rate = 200, dx = 4, dy = 6, side = "right"
  )

  expect_s3_class(pm, "pressure_movie")
  expect_equal(dim(pm$pressure), c(2, 2, 2))
  expect_equal(pm$pressure[, , 2], frames[[2]])
  expect_equal(pm$cell_area, 24)
  expect_equal(pm$duration, 1 / 200)
  expect_output(print(pm), "2 x 2 cells")

  negative <- array(c(-1, 2), c(1, 1, 2))
  expect_warning(
    clamped <- pressureMovie(negative, 100),
    "clamped"
  )
  expect_equal(as.vector(clamped$pressure), c(0, 2))

  expect_error(pressureMovie(array(1, c(1, 1, 1)), 0), "sampling_rate")
  expect_error(
    pressureMovie(list(matrix(1, 2, 2), matrix(1, 2, 3)), 100),
    "equal dimensions"
  )
  expect_error(
    pressureMovie(array(NA_real_, c(1, 1, 1)), 100),
    "finite"
  )
  expect_error(
    pressureMovie(array(1, c(1, 1, 1)), 100, side = "bilateral"),
    "side"
  )
})


test_that("peak pressure and PTI are exact for a constant-pressure cell", {
  n <- 11
  fs <- 100
  pressure <- 250
  array <- array(0, dim = c(3, 3, n))
  array[2, 2, ] <- pressure
  pm <- make_pressure_movie(array, fs = fs, dx = 5, dy = 5)

  peak <- peakPressure(pm)
  expect_equal(peak[2, 2], pressure)
  expect_equal(attr(peak, "peak"), pressure)
  expect_equal(attr(peak, "peak_cell"), c(row = 2L, col = 2L))
  expect_equal(attr(peak, "peak_frame"), 1L)
  expect_equal(attr(peak, "contact_area"), 25)
  expect_equal(attr(peak, "mean_pressure"), pressure)

  pti <- pressureTimeIntegral(pm)
  expect_equal(pti[2, 2], pressure * (n - 1) / fs, tolerance = 1e-12)
  expect_equal(attr(pti, "fti"), 6.25 * (n - 1) / fs,
               tolerance = 1e-10)
})


test_that("regional loading is a complete partition", {
  set.seed(1)
  array <- array(runif(6 * 4 * 10, 0, 200), dim = c(6, 4, 10))
  pm <- make_pressure_movie(array, fs = 100, dx = 5, dy = 5)
  loading <- regionalLoading(pm, statistic = "fti")
  fti <- attr(pressureTimeIntegral(pm), "fti")

  expect_s3_class(loading, "regional_loading")
  expect_equal(sum(loading$value), fti, tolerance = 1e-9)
  expect_equal(attr(loading, "total"), fti, tolerance = 1e-9)
  expect_equal(sum(loading$pct_total), 100, tolerance = 1e-9)
  expect_identical(
    loading$region,
    c("rearfoot", "midfoot", "forefoot", "toes")
  )
  expect_equal(loading$n_cells, c(8L, 4L, 4L, 8L))
  expect_output(print(loading), "statistic=fti")
})


test_that("regional loading handles direction and empty footprints", {
  array <- array(0, dim = c(5, 1, 3))
  array[1, 1, ] <- 10
  array[5, 1, ] <- 20

  heel_first <- regionalLoading(make_pressure_movie(array))
  toe_first <- regionalLoading(
    make_pressure_movie(array, heel_first = FALSE)
  )
  expect_equal(heel_first$peak_pressure[c(1, 4)], c(10, 20))
  expect_equal(toe_first$peak_pressure[c(1, 4)], c(20, 10))

  empty <- regionalLoading(make_pressure_movie(array(0, c(4, 3, 3))))
  expect_equal(empty$value, rep(0, 4))
  expect_equal(empty$pct_total, rep(0, 4))
  expect_equal(empty$contact_area, rep(0, 4))
  expect_equal(empty$n_cells, rep(0L, 4))

  expect_error(
    regionalLoading(
      make_pressure_movie(array),
      regions = c(a = 0.5, b = 0.4)
    ),
    "strictly increasing"
  )
})


test_that("copFromPressure returns exact cell centres and silent-frame NAs", {
  array <- array(0, dim = c(4, 4, 2))
  array[3, 2, 1] <- 100
  pm <- make_pressure_movie(array, dx = 5, dy = 5)
  cop <- copFromPressure(pm)

  expect_equal(cop$cop_x[1], (2 - 0.5) * 5)
  expect_equal(cop$cop_y[1], (3 - 0.5) * 5)
  expect_equal(cop$total_force[1], 2.5)
  expect_equal(cop$contact_area[1], 25)
  expect_true(is.na(cop$cop_x[2]))
  expect_true(is.na(cop$cop_y[2]))
  expect_equal(cop$total_force[2], 0)
  expect_equal(cop$contact_area[2], 0)
})


test_that("copFromPressure equals force-plate COP for the same loading", {
  set.seed(7)
  nr <- 5
  nc <- 4
  dx <- 5
  dy <- 5
  pressure <- matrix(runif(nr * nc, 0, 300), nr, nc)
  pm <- make_pressure_movie(
    array(pressure, dim = c(nr, nc, 1)),
    dx = dx,
    dy = dy
  )
  cop <- copFromPressure(pm)

  grid <- expand.grid(row = seq_len(nr), col = seq_len(nc))
  x <- (grid$col - 0.5) * dx
  y <- (grid$row - 0.5) * dy
  force <- as.vector(pressure) * (dx * dy) * 1e-3
  fz <- sum(force)
  mx <- sum(y * force)
  my <- -sum(x * force)
  reference <- calculateCOP(
    matrix(c(0, 0, fz), 1),
    matrix(c(mx, my, 0), 1),
    origin = c(0, 0, 0),
    min_vertical_force = 0
  )

  expect_equal(cop$cop_x, reference$cop_x, tolerance = 1e-8)
  expect_equal(cop$cop_y, reference$cop_y, tolerance = 1e-8)
})


test_that("copFromPressure output feeds swayMetrics", {
  set.seed(2)
  array <- array(runif(4 * 4 * 400, 50, 150), dim = c(4, 4, 400))
  pm <- make_pressure_movie(array, fs = 100)
  metrics <- swayMetrics(
    copFromPressure(pm),
    sampling_rate = pm$sampling_rate
  )

  expect_s3_class(metrics, "sway_metrics")
  expect_true(is.finite(metrics$path_length))
})


test_that("pressure asymmetry follows the signed Robinson index", {
  left <- make_pressure_movie(array(100, dim = c(3, 3, 5)))
  right <- make_pressure_movie(array(100, dim = c(3, 3, 5)))
  symmetric <- pressureAsymmetry(left, right, "peak_pressure")
  expect_equal(symmetric$symmetry_index, 0)
  expect_equal(symmetric$ratio, 1)

  half_right <- make_pressure_movie(array(50, dim = c(3, 3, 5)))
  asymmetric <- pressureAsymmetry(left, half_right, "peak_pressure")
  expect_equal(
    asymmetric$symmetry_index,
    100 * (100 - 50) / (0.5 * 150),
    tolerance = 1e-12
  )
  expect_equal(asymmetric$abs_symmetry_index, asymmetric$symmetry_index)
  expect_output(print(asymmetric), "metric=peak_pressure")

  silent <- make_pressure_movie(array(0, dim = c(3, 3, 5)))
  expect_true(is.na(
    pressureAsymmetry(silent, silent, "total_force")$symmetry_index
  ))
})


test_that("readPressureFrame round-trips metadata and row-major frames", {
  file <- withr::local_tempfile(fileext = ".txt")
  writeLines(
    c(
      "# sampling_rate 200", "# dx 5", "# dy 5", "# side right",
      "Frame 0", "1 2", "3 4",
      "Frame 1", "5 6", "7 8"
    ),
    file
  )
  pm <- readPressureFrame(file)

  expect_equal(dim(pm$pressure), c(2, 2, 2))
  expect_equal(pm$sampling_rate, 200)
  expect_equal(pm$side, "right")
  expect_equal(pm$pressure[, , 1], matrix(c(1, 3, 2, 4), 2, 2))
  expect_equal(pm$pressure[2, 2, 2], 8)

  overridden <- readPressureFrame(
    file, sampling_rate = 50, dx = 2, side = "left", units = "custom"
  )
  expect_equal(overridden$sampling_rate, 50)
  expect_equal(overridden$dx, 2)
  expect_equal(overridden$dy, 5)
  expect_equal(overridden$side, "left")
  expect_equal(overridden$units, "custom")
})


test_that("readPressureFrame rejects absent and inconsistent frames", {
  empty <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("# sampling_rate 100", "Frame 0", "not numeric"), empty)
  expect_error(readPressureFrame(empty), "No pressure frames")

  ragged <- withr::local_tempfile(fileext = ".txt")
  writeLines(
    c("# sampling_rate 100", "Frame 0", "1 2", "3"),
    ragged
  )
  expect_error(readPressureFrame(ragged), "ragged rows")

  unequal <- withr::local_tempfile(fileext = ".txt")
  writeLines(
    c(
      "# sampling_rate 100",
      "Frame 0", "1 2", "3 4",
      "Frame 1", "1 2 3", "4 5 6"
    ),
    unequal
  )
  expect_error(readPressureFrame(unequal), "inconsistent with frame 1")
})


test_that("plotPressureMap returns static and stance ggplots", {
  set.seed(24)
  pm <- make_pressure_movie(array(runif(4 * 3 * 12), c(4, 3, 12)))

  expect_s3_class(plotPressureMap(pm), "ggplot")
  expect_s3_class(
    plotPressureMap(pm, type = "mean", flip_ap = TRUE),
    "ggplot"
  )
  expect_s3_class(
    plotPressureMap(pm, type = "frame", frame = 3),
    "ggplot"
  )
  stance <- plotPressureMap(pm, type = "frame", n_facets = 4)
  expect_s3_class(stance, "ggplot")
  expect_s3_class(stance$facet, "FacetWrap")
})


test_that("plotPressureMap thresholds aggregate maps by peak contact", {
  pressure <- array(0, c(2, 2, 11))
  pressure[1, 1, 6] <- 100
  pressure[2, 2, ] <- 5
  pm <- make_pressure_movie(pressure, fs = 10)

  mean_plot <- plotPressureMap(
    pm, type = "mean", contact_threshold = 10
  )
  pti_plot <- plotPressureMap(
    pm, type = "pti", contact_threshold = 10
  )

  expect_true(is.finite(mean_plot$data$value[1]))
  expect_true(is.finite(pti_plot$data$value[1]))
  expect_true(is.na(mean_plot$data$value[4]))
  expect_true(is.na(pti_plot$data$value[4]))
})
