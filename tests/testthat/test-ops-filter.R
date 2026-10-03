library(testthat)
library(PhysioMoCap)

# --- butterworthFilter: lowpass ---

test_that("butterworthFilter lowpass removes high frequencies", {
  skip_if_not_installed("signal")

  sr <- 1000
  n <- 2000
  t <- seq(0, (n - 1) / sr, length.out = n)

  # Signal: 5 Hz + 100 Hz

  x <- sin(2 * pi * 5 * t) + sin(2 * pi * 100 * t)

  filtered <- butterworthFilter(x, cutoff = 20, sampling_rate = sr,
                                type = "lowpass", order = 4)

  # Verify with FFT: power at 100 Hz should be greatly attenuated
  spec_orig <- Mod(fft(x))
  spec_filt <- Mod(fft(filtered))

  freq_bins <- (seq_len(n) - 1) * sr / n
  idx_5hz <- which.min(abs(freq_bins - 5))
  idx_100hz <- which.min(abs(freq_bins - 100))

  # 5 Hz component should be largely preserved
  ratio_5hz <- spec_filt[idx_5hz] / spec_orig[idx_5hz]
  expect_gt(ratio_5hz, 0.5)

  # 100 Hz component should be strongly attenuated
  ratio_100hz <- spec_filt[idx_100hz] / spec_orig[idx_100hz]
  expect_lt(ratio_100hz, 0.1)
})


# --- butterworthFilter: highpass ---

test_that("butterworthFilter highpass removes low frequencies", {
  skip_if_not_installed("signal")

  sr <- 1000
  n <- 2000
  t <- seq(0, (n - 1) / sr, length.out = n)

  # Signal: 5 Hz + 100 Hz
  x <- sin(2 * pi * 5 * t) + sin(2 * pi * 100 * t)

  filtered <- butterworthFilter(x, cutoff = 50, sampling_rate = sr,
                                type = "highpass", order = 4)

  spec_orig <- Mod(fft(x))
  spec_filt <- Mod(fft(filtered))

  freq_bins <- (seq_len(n) - 1) * sr / n
  idx_5hz <- which.min(abs(freq_bins - 5))
  idx_100hz <- which.min(abs(freq_bins - 100))

  # 5 Hz should be strongly attenuated
  ratio_5hz <- spec_filt[idx_5hz] / spec_orig[idx_5hz]
  expect_lt(ratio_5hz, 0.1)

  # 100 Hz should be preserved
  ratio_100hz <- spec_filt[idx_100hz] / spec_orig[idx_100hz]
  expect_gt(ratio_100hz, 0.5)
})


# --- butterworthFilter: bandpass ---

test_that("butterworthFilter bandpass passes only target band", {
  skip_if_not_installed("signal")

  sr <- 1000
  n <- 2000
  t <- seq(0, (n - 1) / sr, length.out = n)

  # Signal: 5 Hz + 50 Hz + 200 Hz
  x <- sin(2 * pi * 5 * t) + sin(2 * pi * 50 * t) + sin(2 * pi * 200 * t)

  filtered <- butterworthFilter(x, cutoff = c(30, 80), sampling_rate = sr,
                                type = "bandpass", order = 4)

  spec_orig <- Mod(fft(x))
  spec_filt <- Mod(fft(filtered))

  freq_bins <- (seq_len(n) - 1) * sr / n
  idx_5hz <- which.min(abs(freq_bins - 5))
  idx_50hz <- which.min(abs(freq_bins - 50))
  idx_200hz <- which.min(abs(freq_bins - 200))

  # 5 Hz and 200 Hz should be attenuated, 50 Hz should pass
  ratio_5hz <- spec_filt[idx_5hz] / spec_orig[idx_5hz]
  ratio_50hz <- spec_filt[idx_50hz] / spec_orig[idx_50hz]
  ratio_200hz <- spec_filt[idx_200hz] / spec_orig[idx_200hz]

  expect_lt(ratio_5hz, 0.15)
  expect_gt(ratio_50hz, 0.5)
  expect_lt(ratio_200hz, 0.15)
})


# --- Zero-phase filtering ---

test_that("butterworthFilter produces zero-phase output (no phase shift)", {
  skip_if_not_installed("signal")

  sr <- 1000
  n <- 2000
  t <- seq(0, (n - 1) / sr, length.out = n)

  # Pure sine wave
  x <- sin(2 * pi * 10 * t)

  filtered <- butterworthFilter(x, cutoff = 50, sampling_rate = sr,
                                type = "lowpass", order = 4)

  # For a signal well within the passband, filtfilt should preserve phase.
  # Check that the peak locations match (no phase shift).
  peaks_orig <- which(diff(sign(diff(x))) == -2) + 1
  peaks_filt <- which(diff(sign(diff(filtered))) == -2) + 1

  # Peak locations should be identical or very close
  n_peaks <- min(length(peaks_orig), length(peaks_filt))
  if (n_peaks > 2) {
    # Skip edge peaks (first and last), compare interior
    interior <- 2:(n_peaks - 1)
    max_shift <- max(abs(peaks_orig[interior] - peaks_filt[interior]))
    expect_lte(max_shift, 1)  # at most 1 sample difference
  }
})


# --- NA handling ---

test_that("butterworthFilter handles NAs correctly: NAs restored after filtering", {
  skip_if_not_installed("signal")

  sr <- 500
  n <- 1000
  t <- seq(0, (n - 1) / sr, length.out = n)

  x <- sin(2 * pi * 5 * t)
  na_positions <- c(50, 100, 500)
  x[na_positions] <- NA

  filtered <- butterworthFilter(x, cutoff = 20, sampling_rate = sr,
                                type = "lowpass", order = 4)

  # NAs should be restored at original positions
  expect_true(all(is.na(filtered[na_positions])))
  # Non-NA positions should have valid values
  expect_false(any(is.na(filtered[-na_positions])))
})


# --- savgolFilter: smoothing ---

test_that("savgolFilter smoothing reduces noise (lower variance)", {
  set.seed(42)
  n <- 500
  t <- seq(0, 2 * pi, length.out = n)
  clean <- sin(t)
  noisy <- clean + rnorm(n, sd = 0.3)

  smoothed <- savgolFilter(noisy, window_length = 21, poly_order = 3, deriv = 0)

  # Exclude edge NAs for comparison
  valid <- !is.na(smoothed)

  # Variance of (smoothed - clean) should be much less than variance of noise
  residual_var <- var(smoothed[valid] - clean[valid])
  noise_var <- var(noisy[valid] - clean[valid])

  expect_lt(residual_var, noise_var * 0.5)
})


# --- savgolFilter: derivative ---

test_that("savgolFilter derivative matches known analytical derivative", {
  n <- 500
  t <- seq(0, 2 * pi, length.out = n)
  dt <- t[2] - t[1]

  x <- sin(t)
  # Analytical first derivative: cos(t)
  analytical_deriv <- cos(t)

  sg_deriv <- savgolFilter(x, window_length = 11, poly_order = 5, deriv = 1)

  # Scale: SG derivative is in terms of index spacing, divide by dt not needed
  # because it computes d/di, so multiply analytical by dt to compare
  # Actually, SG with deriv=1 computes d/di (derivative w.r.t. index),
  # so the numerical derivative = sg_deriv, and analytical = cos(t) * dt
  expected <- analytical_deriv * dt

  # Compare interior points (avoid edges)
  margin <- 20
  interior <- (margin + 1):(n - margin)
  valid <- interior[!is.na(sg_deriv[interior])]

  correlation <- cor(sg_deriv[valid], expected[valid])
  expect_gt(correlation, 0.99)
})


# --- savgolFilter vs moving average ---

test_that("savgolFilter preserves peaks better than movingAverage", {
  set.seed(123)
  n <- 200
  t <- seq(0, 2 * pi, length.out = n)
  # Signal with a sharp peak
  x <- exp(-((t - pi)^2) / 0.1) + rnorm(n, sd = 0.05)
  true_peak <- exp(0)  # peak value of the Gaussian = 1

  sg <- savgolFilter(x, window_length = 11, poly_order = 3)
  ma <- movingAverage(x, window = 11)

  # Find peak values (in the middle region where the Gaussian peak is)
  mid <- (n %/% 3):(2 * n %/% 3)
  sg_peak <- max(sg[mid], na.rm = TRUE)
  ma_peak <- max(ma[mid], na.rm = TRUE)

  # SG should preserve peak height better (closer to true peak)
  expect_gt(sg_peak, ma_peak)
})


# --- movingAverage ---

test_that("movingAverage reduces variance", {
  set.seed(42)
  n <- 500
  x <- rnorm(n)

  smoothed <- movingAverage(x, window = 11)

  # Non-NA variance should be reduced
  valid <- !is.na(smoothed)
  expect_lt(var(smoothed[valid]), var(x))
})


# --- filterSignals wrapper: returns PE with new assay ---

test_that("filterSignals returns PE with new assay", {
  skip_if_not_installed("signal")

  pe <- make_mocap_markers(n_time = 500, n_markers = 4, sr = 120)

  pe_filt <- filterSignals(pe, type = "lowpass", cutoff = 10)

  expect_s4_class(pe_filt, "PhysioExperiment")
  expect_true("position_x_filtered" %in% SummarizedExperiment::assayNames(pe_filt))
  # Original assay should still exist
  expect_true("position_x" %in% SummarizedExperiment::assayNames(pe_filt))
  # Dimensions should match
  expect_equal(
    dim(SummarizedExperiment::assay(pe_filt, "position_x_filtered")),
    dim(SummarizedExperiment::assay(pe_filt, "position_x"))
  )
})


# --- filterSignals wrapper: correct assay naming ---

test_that("filterSignals uses correct assay naming with custom names", {
  skip_if_not_installed("signal")

  pe <- make_mocap_markers(n_time = 500, n_markers = 4, sr = 120)

  pe_filt <- filterSignals(pe, type = "lowpass", cutoff = 10,
                           assay_name = "position_y",
                           output_assay = "pos_y_smooth")

  expect_true("pos_y_smooth" %in% SummarizedExperiment::assayNames(pe_filt))
  expect_equal(
    dim(SummarizedExperiment::assay(pe_filt, "pos_y_smooth")),
    dim(SummarizedExperiment::assay(pe_filt, "position_y"))
  )
})


# --- Error on missing signal package ---

test_that("butterworthFilter errors informatively when signal package is missing", {
  skip_if_not(exists("local_mocked_bindings", mode = "function"),
              "local_mocked_bindings() not available")

  local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (identical(pkg, "signal")) {
        return(FALSE)
      }
      base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )

  expect_error(
    butterworthFilter(1:100, cutoff = 10, sampling_rate = 100, type = "lowpass"),
    "signal.*package.*required|Install it with"
  )
})


# --- Error on invalid filter type ---

test_that("butterworthFilter errors on invalid filter type", {
  skip_if_not_installed("signal")

  expect_error(
    butterworthFilter(1:100, cutoff = 10, sampling_rate = 100, type = "invalid"),
    "arg"
  )
})


# --- Error on cutoff > Nyquist ---

test_that("butterworthFilter errors when cutoff exceeds Nyquist frequency", {
  skip_if_not_installed("signal")

  expect_error(
    butterworthFilter(1:100, cutoff = 60, sampling_rate = 100, type = "lowpass"),
    "Nyquist"
  )
})


# --- Matrix input (multi-channel) ---

test_that("butterworthFilter handles matrix input (multi-channel)", {
  skip_if_not_installed("signal")

  sr <- 500
  n <- 1000
  t <- seq(0, (n - 1) / sr, length.out = n)

  # 3 channels with different frequencies
  mat <- cbind(
    ch1 = sin(2 * pi * 5 * t) + sin(2 * pi * 100 * t),
    ch2 = sin(2 * pi * 10 * t) + sin(2 * pi * 80 * t),
    ch3 = cos(2 * pi * 3 * t) + sin(2 * pi * 150 * t)
  )

  filtered <- butterworthFilter(mat, cutoff = 30, sampling_rate = sr,
                                type = "lowpass", order = 4)

  expect_true(is.matrix(filtered))
  expect_equal(dim(filtered), dim(mat))
  expect_equal(colnames(filtered), colnames(mat))

  # Each channel should have reduced high-frequency content
  for (j in 1:3) {
    expect_lt(var(filtered[, j]), var(mat[, j]))
  }
})


# --- savgolFilter on matrix ---

test_that("savgolFilter works on matrix input", {
  set.seed(42)
  n <- 200
  mat <- matrix(rnorm(n * 3), nrow = n, ncol = 3)
  colnames(mat) <- c("x", "y", "z")

  smoothed <- savgolFilter(mat, window_length = 11, poly_order = 3)

  expect_true(is.matrix(smoothed))
  expect_equal(dim(smoothed), dim(mat))
  expect_equal(colnames(smoothed), colnames(mat))
})


# --- Edge case: single channel ---

test_that("butterworthFilter works on single-column matrix", {
  skip_if_not_installed("signal")

  sr <- 500
  n <- 500
  t <- seq(0, (n - 1) / sr, length.out = n)
  mat <- matrix(sin(2 * pi * 5 * t), ncol = 1)
  colnames(mat) <- "ch1"

  filtered <- butterworthFilter(mat, cutoff = 20, sampling_rate = sr,
                                type = "lowpass")

  expect_true(is.matrix(filtered))
  expect_equal(ncol(filtered), 1)
  expect_equal(colnames(filtered), "ch1")
})


# --- Edge case: very short signal ---

test_that("savgolFilter handles very short signal gracefully", {
  # Signal shorter than window
  x <- c(1, 2, 3)

  expect_warning(
    result <- savgolFilter(x, window_length = 11, poly_order = 3),
    "shorter than window_length"
  )
  expect_true(all(is.na(result)))
  expect_equal(length(result), 3)
})


# --- Error: bandpass with single cutoff ---

test_that("butterworthFilter errors on bandpass with single cutoff", {
  skip_if_not_installed("signal")

  expect_error(
    butterworthFilter(1:100, cutoff = 10, sampling_rate = 100, type = "bandpass"),
    "length-2"
  )
})


# --- savgolFilter parameter validation ---

test_that("savgolFilter errors on even window_length", {
  expect_error(
    savgolFilter(1:100, window_length = 10),
    "odd integer"
  )
})

test_that("savgolFilter errors when poly_order >= window_length", {
  expect_error(
    savgolFilter(1:100, window_length = 5, poly_order = 5),
    "poly_order must be less than window_length"
  )
})
