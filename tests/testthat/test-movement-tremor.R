# Quantitative tremor analysis.

test_that("tremorSpectrum recovers a planted tremor frequency and power", {
  set.seed(1)
  fs <- 100; t <- seq(0, 20, by = 1 / fs)
  x <- 2 * sin(2 * pi * 5 * t) + rnorm(length(t), 0, 0.05)
  sp <- tremorSpectrum(x, fs, band = c(3, 12))
  expect_equal(sp$dominant_freq_hz, 5, tolerance = 0.5)   # nearest bin to 5 Hz
  expect_gt(sp$band_power_rel, 0.9)                        # almost all power in band
  expect_gt(sp$peak_power, 0)
})

test_that("a sub-band (1 Hz) sway is not counted as tremor", {
  fs <- 100; t <- seq(0, 20, by = 1 / fs)
  sp <- tremorSpectrum(sin(2 * pi * 1 * t), fs, band = c(3, 12))
  expect_lt(sp$band_power_rel, 0.1)
})

test_that("harmonic ratio detects a first harmonic", {
  fs <- 100; t <- seq(0, 20, by = 1 / fs)
  x <- sin(2 * pi * 5 * t) + 0.5 * sin(2 * pi * 10 * t)   # f0=5, 2f0=10
  sp <- tremorSpectrum(x, fs, band = c(3, 12))
  expect_equal(sp$dominant_freq_hz, 5, tolerance = 0.5)
  expect_gt(sp$harmonic_ratio, 0.1)
  expect_lt(sp$harmonic_ratio, 0.5)                        # ~ (0.5^2)/(1^2)
})

test_that("tremorAmplitude recovers band-limited RMS", {
  fs <- 100; t <- seq(0, 20, by = 1 / fs)
  amp <- tremorAmplitude(2 * sin(2 * pi * 5 * t), fs, band = c(3, 12))
  expect_equal(amp$rms, 2 / sqrt(2), tolerance = 0.1)      # A / sqrt(2)
})

test_that("tremorMetrics assembles and tags the condition", {
  fs <- 100; t <- seq(0, 20, by = 1 / fs)
  m <- tremorMetrics(1.5 * sin(2 * pi * 6 * t), fs, condition = "postural")
  expect_s3_class(m, "tremor_metrics")
  expect_equal(m$dominant_freq_hz, 6, tolerance = 0.5)
  expect_equal(m$condition, "postural")
  expect_equal(m$rms_amplitude, 1.5 / sqrt(2), tolerance = 0.1)
  # band above Nyquist is rejected
  expect_error(tremorSpectrum(sin(2 * pi * 6 * t), fs, band = c(3, 60)), "Nyquist")
})
