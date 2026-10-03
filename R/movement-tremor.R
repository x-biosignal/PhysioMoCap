# Quantitative tremor analysis from a movement signal (accelerometer, gyroscope
# or kinematic axis). Pathological tremor lives in a narrow band (rest ~3-6 Hz,
# postural/action ~4-12 Hz); these functions quantify its frequency, band power
# and amplitude. The power spectrum is a dependency-free Welch periodogram; for
# raw accelerometry remove gravity first (see `removeGravity()`), and pass a
# single axis or the vector magnitude.

# Welch one-sided power spectral density (Hann window, 50% overlap), base-R only.
# Returns list(freq [Hz], psd [signal^2 / Hz]).
.mocap_welch_psd <- function(x, fs, seg_len = NULL, overlap = 0.5) {
  x <- as.numeric(x)
  n <- length(x)
  if (is.null(seg_len)) {
    seg_len <- if (n >= 256) 2^floor(log2(n / 4)) else n
  }
  seg_len <- max(8L, min(as.integer(seg_len), n))
  step <- max(1L, floor(seg_len * (1 - overlap)))
  starts <- seq.int(1L, n - seg_len + 1L, by = step)
  if (!length(starts)) starts <- 1L
  w <- 0.5 - 0.5 * cos(2 * pi * seq.int(0, seg_len - 1) / (seg_len - 1))
  U <- sum(w^2)                                  # window power (normalisation)
  nfreq <- floor(seg_len / 2) + 1L
  acc <- numeric(nfreq)
  for (s in starts) {
    seg <- x[s:(s + seg_len - 1L)]
    seg <- (seg - mean(seg)) * w                 # per-segment detrend + taper
    X <- stats::fft(seg)
    P <- (Mod(X[seq_len(nfreq)])^2) / (fs * U)
    if (nfreq > 2L) P[2:(nfreq - 1L)] <- 2 * P[2:(nfreq - 1L)]  # one-sided
    acc <- acc + P
  }
  list(freq = (seq_len(nfreq) - 1L) * fs / seg_len, psd = acc / length(starts))
}

#' Tremor power spectrum and dominant frequency
#'
#' Estimates the power spectrum of a movement signal (Welch periodogram) and
#' summarises the tremor within a frequency band: the dominant frequency, its
#' peak power, absolute and relative in-band power, the half-power bandwidth
#' (peak sharpness) and the first-harmonic ratio.
#'
#' @param signal Numeric vector: one axis, or the vector magnitude, of an
#'   accelerometer / gyroscope / displacement signal (gravity removed for raw
#'   accelerometry).
#' @param sampling_rate Sampling rate in Hz.
#' @param band Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).
#' @param detrend Remove the signal mean before spectral estimation (default
#'   `TRUE`; each Welch segment is also demeaned).
#' @param seg_sec Optional Welch segment length in seconds (default: about an
#'   eighth of the record, rounded to a power of two).
#' @return A list: `dominant_freq_hz`, `peak_power`, `band_power_abs`,
#'   `band_power_rel` (in-band / total power), `half_power_bw_hz`,
#'   `harmonic_ratio` (power at 2*f0 / power at f0), and the `freq` / `psd`
#'   vectors.
#' @seealso [tremorAmplitude()], [tremorMetrics()]
#' @export
#' @examples
#' fs <- 100; t <- seq(0, 20, by = 1 / fs)
#' x <- 2 * sin(2 * pi * 5 * t)            # a 5 Hz, amplitude-2 tremor
#' tremorSpectrum(x, fs)$dominant_freq_hz
tremorSpectrum <- function(signal, sampling_rate, band = c(3, 12),
                           detrend = TRUE, seg_sec = NULL) {
  x <- as.numeric(signal)
  stopifnot(length(x) >= 8L, is.numeric(sampling_rate), sampling_rate > 0,
            length(band) == 2L, band[1] < band[2])
  if (band[2] >= sampling_rate / 2) {
    stop("the tremor band upper edge must be below the Nyquist frequency.",
         call. = FALSE)
  }
  if (detrend) x <- x - mean(x)
  seg_len <- if (!is.null(seg_sec)) round(seg_sec * sampling_rate) else NULL
  sp <- .mocap_welch_psd(x, sampling_rate, seg_len = seg_len)
  freq <- sp$freq; psd <- sp$psd
  df <- if (length(freq) > 1L) freq[2] - freq[1] else sampling_rate
  in_band <- freq >= band[1] & freq <= band[2]
  if (!any(in_band)) stop("no spectral bins fall inside the tremor band.",
                          call. = FALSE)
  band_psd <- psd; band_psd[!in_band] <- -Inf
  peak_idx <- which.max(band_psd)
  f0 <- freq[peak_idx]; peak_power <- psd[peak_idx]
  band_power_abs <- sum(psd[in_band]) * df
  total_power <- sum(psd) * df
  # half-power bandwidth: contiguous span around the peak with psd >= peak/2
  half <- peak_power / 2
  li <- peak_idx; while (li > 1L && psd[li - 1L] >= half) li <- li - 1L
  ri <- peak_idx; while (ri < length(psd) && psd[ri + 1L] >= half) ri <- ri + 1L
  h2 <- 2 * f0
  harmonic_ratio <- if (h2 < max(freq)) {
    p0 <- psd[which.min(abs(freq - f0))]
    if (p0 > 0) psd[which.min(abs(freq - h2))] / p0 else NA_real_
  } else NA_real_
  list(dominant_freq_hz = f0, peak_power = peak_power,
       band_power_abs = band_power_abs,
       band_power_rel = if (total_power > 0) band_power_abs / total_power else NA_real_,
       half_power_bw_hz = freq[ri] - freq[li], harmonic_ratio = harmonic_ratio,
       freq = freq, psd = psd)
}

#' Band-limited tremor amplitude (RMS)
#'
#' Band-pass filters the signal to the tremor band and returns its root-mean-
#' square amplitude (in the units of the input signal).
#'
#' @param signal Numeric movement signal.
#' @param sampling_rate Sampling rate in Hz.
#' @param band Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).
#' @param order Butterworth filter order (default 4).
#' @return A list with `rms` and the `band` used.
#' @seealso [tremorSpectrum()], [tremorMetrics()]
#' @export
#' @examples
#' fs <- 100; t <- seq(0, 20, by = 1 / fs)
#' tremorAmplitude(2 * sin(2 * pi * 5 * t), fs)$rms   # ~ 2 / sqrt(2)
tremorAmplitude <- function(signal, sampling_rate, band = c(3, 12), order = 4) {
  x <- as.numeric(signal)
  stopifnot(length(x) >= 8L, length(band) == 2L, band[1] < band[2])
  filt <- butterworthFilter(x, cutoff = band, sampling_rate = sampling_rate,
                            type = "bandpass", order = order)
  list(rms = sqrt(mean(as.numeric(filt)^2)), band = band)
}

#' Tremor metrics (frequency + amplitude, with a task tag)
#'
#' Combines [tremorSpectrum()] and [tremorAmplitude()] into a single tremor
#' summary, tagged with the recording condition. The rest / postural / kinetic
#' distinction is task-context metadata supplied by the caller (the segment
#' recorded under that condition), not a separate algorithm.
#'
#' @param signal Numeric movement signal (one axis or magnitude).
#' @param sampling_rate Sampling rate in Hz.
#' @param condition Recording condition: `"rest"`, `"postural"` or `"kinetic"`.
#' @param band Length-2 tremor band `c(low, high)` in Hz (default `c(3, 12)`).
#' @param ... Passed to [tremorSpectrum()].
#' @return An S3 `tremor_metrics` list: `dominant_freq_hz`, `band_power_abs`,
#'   `band_power_rel`, `rms_amplitude`, `half_power_bw_hz`, `harmonic_ratio`,
#'   `condition`, `band`, `sampling_rate`.
#' @seealso [tremorSpectrum()], [tremorAmplitude()]
#' @export
#' @examples
#' fs <- 100; t <- seq(0, 20, by = 1 / fs)
#' tremorMetrics(1.5 * sin(2 * pi * 6 * t), fs, condition = "postural")
tremorMetrics <- function(signal, sampling_rate,
                          condition = c("rest", "postural", "kinetic"),
                          band = c(3, 12), ...) {
  condition <- match.arg(condition)
  sp <- tremorSpectrum(signal, sampling_rate, band = band, ...)
  amp <- tremorAmplitude(signal, sampling_rate, band = band)
  structure(list(
    dominant_freq_hz = sp$dominant_freq_hz, band_power_abs = sp$band_power_abs,
    band_power_rel = sp$band_power_rel, rms_amplitude = amp$rms,
    half_power_bw_hz = sp$half_power_bw_hz, harmonic_ratio = sp$harmonic_ratio,
    condition = condition, band = band, sampling_rate = sampling_rate),
    class = "tremor_metrics")
}

#' @export
print.tremor_metrics <- function(x, ...) {
  cat(sprintf("Tremor metrics (%s, %g-%g Hz)\n", x$condition, x$band[1], x$band[2]))
  cat(sprintf("  dominant frequency : %.2f Hz\n", x$dominant_freq_hz))
  cat(sprintf("  RMS amplitude      : %.4g\n", x$rms_amplitude))
  cat(sprintf("  in-band power      : %.4g (%.0f%% of total)\n",
              x$band_power_abs, 100 * x$band_power_rel))
  cat(sprintf("  half-power bandwidth: %.2f Hz | harmonic ratio: %.3f\n",
              x$half_power_bw_hz, x$harmonic_ratio))
  invisible(x)
}
