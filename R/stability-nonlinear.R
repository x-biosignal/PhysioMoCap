# Nonlinear dynamic gait-stability measures: sample entropy (Richman & Moorman),
# largest Lyapunov exponent and local dynamic stability (Rosenstein; Dingwell &
# Cusumano), harmonic ratio (Menz; Bellanca), and time-delay phase-space
# embedding (average-mutual-information delay + false-nearest-neighbour
# dimension).

#' Time-delay phase-space embedding
#'
#' Reconstructs a scalar time series into a delay-embedded phase space
#' \eqn{Y(i) = [x_i, x_{i+\tau}, \dots, x_{i+(m-1)\tau}]}. When `delay` is `NULL`
#' it is chosen at the first local minimum of the average mutual information
#' (AMI); when `dim` is `NULL` it is chosen where the fraction of false nearest
#' neighbours (FNN) first drops below `fnn_threshold`.
#'
#' @param x Numeric time series.
#' @param delay Embedding delay in samples; `NULL` to estimate via AMI.
#' @param dim Embedding dimension; `NULL` to estimate via FNN.
#' @param max_delay Maximum delay searched for the AMI minimum.
#' @param max_dim Maximum embedding dimension searched for FNN.
#' @param n_bins Histogram bins for the AMI estimate.
#' @param fnn_threshold FNN fraction below which the dimension is accepted.
#'
#' @return A `time_delay_embedding` list with `embedded` (matrix, points x dim),
#'   `delay`, `dim`, `ami` (if estimated) and `fnn` (if estimated).
#' @references Fraser AM, Swinney HL (1986); Kennel MB, et al. (1992).
#' @seealso [maxLyapunovExponent()], [sampleEntropy()]
#' @export
#' @examples
#' x <- sin(seq(0, 20 * pi, length.out = 500))
#' emb <- timeDelayEmbed(x, delay = 5, dim = 3)
#' dim(emb$embedded)
timeDelayEmbed <- function(x, delay = NULL, dim = NULL, max_delay = 50L,
                           max_dim = 10L, n_bins = 16L, fnn_threshold = 0.01) {
  x <- as.numeric(x)
  if (length(x) < 10L || any(!is.finite(x))) {
    stop("`x` must be a finite numeric series of length >= 10.", call. = FALSE)
  }
  ami <- NULL
  if (is.null(delay)) {
    if (stats::sd(x) == 0) {
      stop("`x` is constant; cannot estimate an embedding delay.",
           call. = FALSE)
    }
    ami <- .ami_curve(x, min(max_delay, length(x) %/% 2L), n_bins)
    delay <- .first_local_min(ami)
  }
  delay <- as.integer(delay)
  if (is.na(delay) || delay < 1L) {
    stop("`delay` must be a positive integer.", call. = FALSE)
  }
  fnn <- NULL
  if (is.null(dim)) {
    fnn <- .fnn_curve(x, delay, max_dim)
    dim <- .fnn_dimension(fnn, fnn_threshold)
  }
  dim <- as.integer(dim)
  if (is.na(dim) || dim < 1L) {
    stop("`dim` must be a positive integer.", call. = FALSE)
  }

  emb <- .embed(x, delay, dim)
  out <- list(embedded = emb, delay = delay, dim = dim, ami = ami, fnn = fnn)
  class(out) <- "time_delay_embedding"
  out
}

#' Sample entropy (Richman & Moorman)
#'
#' Sample entropy quantifies the irregularity of a time series as the negative
#' natural log of the conditional probability that sequences similar for `m`
#' points remain similar at the next point, within tolerance `r` (self-matches
#' excluded). Larger values indicate greater irregularity/complexity; a perfectly
#' regular signal tends to zero.
#'
#' @param x Numeric time series.
#' @param m Embedding (template) length (default 2).
#' @param r Similarity tolerance. If `normalize = TRUE` (default) it is a
#'   multiple of the series standard deviation (default `0.2`).
#' @param normalize If `TRUE`, `r` is scaled by `sd(x)`.
#'
#' @return A single numeric sample-entropy value (`Inf` if no length-`m+1`
#'   matches occur).
#' @references Richman JS, Moorman JR (2000). Am J Physiol 278(6):H2039-H2049.
#' @seealso [maxLyapunovExponent()]
#' @export
#' @examples
#' sampleEntropy(sin(seq(0, 40 * pi, length.out = 800)))  # ~0 (regular)
sampleEntropy <- function(x, m = 2L, r = 0.2, normalize = TRUE) {
  x <- as.numeric(x)
  N <- length(x)
  m <- as.integer(m)
  if (is.na(m) || m < 1L) {
    stop("`m` must be a positive integer.", call. = FALSE)
  }
  if (N < m + 2L || any(!is.finite(x))) {
    stop("`x` must be finite with length >= m + 2.", call. = FALSE)
  }
  if (!is.numeric(r) || length(r) != 1L || r <= 0) {
    stop("`r` must be a positive number.", call. = FALSE)
  }
  if (isTRUE(normalize)) {
    r <- r * stats::sd(x)
  }
  if (r <= 0) {
    stop("tolerance r resolved to 0 (constant series?).", call. = FALSE)
  }
  ntemp <- N - m
  B <- .cheb_pair_count(x, m, ntemp, r)
  A <- .cheb_pair_count(x, m + 1L, ntemp, r)
  if (B == 0) {
    return(NA_real_)
  }
  if (A == 0) {
    return(Inf)
  }
  -log(A / B)
}

#' Largest Lyapunov exponent (Rosenstein)
#'
#' Estimates the largest Lyapunov exponent from the average logarithmic
#' divergence of initially nearby trajectories in a delay-embedded phase space
#' (Rosenstein et al. 1993). A positive exponent indicates sensitive dependence
#' on initial conditions (chaos / local instability).
#'
#' @param x Numeric time series.
#' @param delay,dim Embedding delay and dimension; `NULL` estimates them via
#'   [timeDelayEmbed()].
#' @param sampling_rate Sampling rate in Hz (scales the exponent to per-second).
#' @param mean_period Theiler window in samples excluding temporally-close
#'   neighbours; `NULL` estimates it from the mean signal period.
#' @param max_steps Number of forward steps to track divergence; `NULL` uses a
#'   default derived from the series length.
#' @param fit_range Integer vector `c(from, to)` (in steps) of the divergence
#'   curve to fit the slope; `NULL` uses an early near-linear window.
#'
#' @return A `lyapunov_exponent` object with `lambda` (per second), the
#'   `divergence` curve, `fit_range`, `delay` and `dim`.
#' @references Rosenstein MT, Collins JJ, De Luca CJ (1993). Physica D 65:117-134.
#' @seealso [localDynamicStability()], [timeDelayEmbed()]
#' @export
maxLyapunovExponent <- function(x, delay = NULL, dim = NULL, sampling_rate = 1,
                                mean_period = NULL, max_steps = NULL,
                                fit_range = NULL) {
  x <- as.numeric(x)
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a positive finite number.", call. = FALSE)
  }
  emb <- timeDelayEmbed(x, delay = delay, dim = dim)
  Y <- emb$embedded
  P <- nrow(Y)

  if (is.null(mean_period)) {
    mean_period <- .mean_period(x)
  }
  theiler <- max(1L, as.integer(mean_period))
  if (is.null(max_steps)) {
    max_steps <- min(as.integer(P %/% 2L), 10L * theiler)
  }
  max_steps <- as.integer(max_steps)
  if (is.na(max_steps) || max_steps < 1L) {
    stop("`max_steps` must be a positive integer.", call. = FALSE)
  }

  divergence <- .rosenstein_divergence(Y, theiler, max_steps)
  steps <- seq_along(divergence) - 1L

  if (is.null(fit_range)) {
    # early, near-linear window: from step 1 up to ~one mean period
    hi <- max(2L, min(theiler, length(divergence) - 1L))
    fit_range <- c(1L, hi)
  }
  idx <- (steps >= fit_range[1]) & (steps <= fit_range[2]) &
    is.finite(divergence)
  if (sum(idx) < 2L) {
    stop("fit_range does not span enough finite divergence points.",
         call. = FALSE)
  }
  fit <- stats::lm(divergence[idx] ~ steps[idx])
  slope_per_step <- unname(stats::coef(fit)[2])
  lambda <- slope_per_step * sampling_rate

  out <- list(
    lambda = lambda,
    divergence = divergence,
    steps = steps,
    fit_range = fit_range,
    delay = emb$delay,
    dim = emb$dim,
    sampling_rate = sampling_rate
  )
  class(out) <- "lyapunov_exponent"
  out
}

#' Local dynamic stability (short- and long-term divergence)
#'
#' Local dynamic stability quantifies how a system responds to small natural
#' perturbations, as the exponential divergence rate of neighbouring trajectories
#' over the short term (0-1 stride, `lambda_short`) and long term
#' (4-10 strides, `lambda_long`), following Dingwell & Cusumano (2000). Higher
#' divergence means less stable locomotion.
#'
#' @param x Numeric time series (e.g. trunk acceleration or a joint angle).
#' @param stride_samples Samples per stride (sets the divergence windows).
#' @param delay,dim Embedding parameters; `NULL` estimates them.
#' @param sampling_rate Sampling rate in Hz.
#'
#' @return A `local_dynamic_stability` object with `lambda_short`,
#'   `lambda_long` (per stride), the `divergence` curve, and embedding info.
#' @references Dingwell JB, Cusumano JJ (2000). Chaos 10(4):848-863.
#' @seealso [maxLyapunovExponent()]
#' @export
localDynamicStability <- function(x, stride_samples, delay = NULL, dim = NULL,
                                  sampling_rate = 1) {
  if (!is.numeric(stride_samples) || length(stride_samples) != 1L ||
      !is.finite(stride_samples) || stride_samples < 2) {
    stop("`stride_samples` must be a single number >= 2.", call. = FALSE)
  }
  stride_samples <- as.integer(round(stride_samples))
  emb <- timeDelayEmbed(x, delay = delay, dim = dim)
  Y <- emb$embedded

  theiler <- stride_samples
  max_steps <- min(nrow(Y) %/% 2L, 10L * stride_samples)
  divergence <- .rosenstein_divergence(Y, theiler, max_steps)
  steps <- seq_along(divergence) - 1L

  slope <- function(lo, hi) {
    idx <- (steps >= lo) & (steps <= hi) & is.finite(divergence)
    if (sum(idx) < 2L) return(NA_real_)
    # slope per stride = slope per step * stride_samples
    unname(stats::coef(stats::lm(divergence[idx] ~ steps[idx]))[2]) *
      stride_samples
  }
  lambda_short <- slope(1L, stride_samples)
  lambda_long <- slope(4L * stride_samples, min(10L * stride_samples,
                                                max(steps)))

  out <- list(
    lambda_short = lambda_short,
    lambda_long = lambda_long,
    divergence = divergence,
    steps = steps,
    stride_samples = stride_samples,
    delay = emb$delay,
    dim = emb$dim
  )
  class(out) <- "local_dynamic_stability"
  out
}

#' Harmonic ratio of a trunk-acceleration signal
#'
#' The harmonic ratio quantifies the smoothness/rhythmicity of trunk acceleration
#' over a stride from its Fourier series: because there are two steps per stride,
#' the even harmonics carry the step-to-step-symmetric (in-phase) content and the
#' odd harmonics the asymmetric content. For anterior-posterior and vertical
#' acceleration the ratio is even/odd (higher = smoother); for medio-lateral it
#' is odd/even (Menz et al. 2003; Bellanca et al. 2013).
#'
#' @param signal Numeric acceleration over an integer number of strides (a
#'   single stride if `n_strides = 1`).
#' @param n_strides Number of strides spanned by `signal` (default 1); the
#'   Fourier fundamental is the stride frequency.
#' @param direction `"AP"`/`"vertical"` (even/odd) or `"ML"` (odd/even).
#' @param n_harmonics Number of harmonics summed (default 20).
#'
#' @return A `harmonic_ratio` object with `ratio`, `even_sum`, `odd_sum` and
#'   `direction`.
#' @references Menz HB, et al. (2003); Bellanca JL, et al. (2013).
#' @seealso [maxLyapunovExponent()]
#' @export
#' @examples
#' t <- seq(0, 1, length.out = 200)[-200]
#' # a clean 2-steps-per-stride (even-harmonic) signal
#' harmonicRatio(cos(2 * 2 * pi * t), direction = "AP")
harmonicRatio <- function(signal, n_strides = 1L,
                          direction = c("AP", "vertical", "ML"),
                          n_harmonics = 20L) {
  direction <- match.arg(direction)
  signal <- as.numeric(signal)
  N <- length(signal)
  if (N < 4L || any(!is.finite(signal))) {
    stop("`signal` must be a finite series of length >= 4.", call. = FALSE)
  }
  n_strides <- as.integer(n_strides)
  if (is.na(n_strides) || n_strides < 1L) {
    stop("`n_strides` must be a positive integer.", call. = FALSE)
  }
  n_harmonics <- as.integer(n_harmonics)

  sp <- Mod(stats::fft(signal - mean(signal)))
  # harmonic h of the stride fundamental sits at FFT bin h * n_strides + 1
  max_h <- min(n_harmonics, (N %/% 2L) %/% n_strides)
  if (max_h < 2L) {
    stop("signal too short for the requested harmonics.", call. = FALSE)
  }
  h <- seq_len(max_h)
  amp <- sp[h * n_strides + 1L]
  even_sum <- sum(amp[h %% 2L == 0L])
  odd_sum <- sum(amp[h %% 2L == 1L])

  ratio <- if (direction == "ML") {
    if (even_sum == 0) Inf else odd_sum / even_sum
  } else {
    if (odd_sum == 0) Inf else even_sum / odd_sum
  }

  out <- list(ratio = ratio, even_sum = even_sum, odd_sum = odd_sum,
              direction = direction, n_harmonics = max_h)
  class(out) <- "harmonic_ratio"
  out
}

# --- internal helpers --------------------------------------------------------

#' Delay-embed a scalar series into a points x dim matrix
#' @keywords internal
#' @noRd
.embed <- function(x, delay, dim) {
  n <- length(x) - (dim - 1L) * delay
  if (n < 2L) {
    stop("series too short for the requested delay/dimension.", call. = FALSE)
  }
  out <- matrix(0, n, dim)
  for (d in seq_len(dim)) {
    lo <- 1L + (d - 1L) * delay
    out[, d] <- x[lo:(lo + n - 1L)]
  }
  out
}

#' Average mutual information at each lag (histogram estimator)
#' @keywords internal
#' @noRd
.ami_curve <- function(x, max_lag, n_bins) {
  breaks <- seq(min(x), max(x), length.out = n_bins + 1L)
  breaks[1] <- breaks[1] - 1e-9
  breaks[length(breaks)] <- breaks[length(breaks)] + 1e-9
  bin <- cut(x, breaks, labels = FALSE)
  vapply(seq_len(max_lag), function(tau) {
    n <- length(x) - tau
    a <- bin[1:n]
    b <- bin[(1 + tau):(n + tau)]
    joint <- table(a, b) / n
    pa <- rowSums(joint)
    pb <- colSums(joint)
    nz <- joint > 0
    outer_p <- outer(pa, pb)
    sum(joint[nz] * log(joint[nz] / outer_p[nz]))
  }, numeric(1))
}

#' First local minimum of a curve (fallback: global minimum)
#' @keywords internal
#' @noRd
.first_local_min <- function(v) {
  if (length(v) < 3L) return(which.min(v))
  for (i in 2:(length(v) - 1L)) {
    if (v[i] < v[i - 1L] && v[i] <= v[i + 1L]) {
      return(i)
    }
  }
  which.min(v)
}

#' False-nearest-neighbour fraction per embedding dimension
#' @keywords internal
#' @noRd
.fnn_curve <- function(x, delay, max_dim, rtol = 15, atol = 2) {
  sd_x <- stats::sd(x)
  # cap the searched dimension so the d+1 embedding stays within the series:
  # .embed(x, delay, d + 1) needs length(x) - d*delay >= 2.
  feasible <- (length(x) - 2L) %/% delay
  max_dim <- max(1L, min(as.integer(max_dim), as.integer(feasible)))
  vapply(seq_len(max_dim), function(d) {
    Y <- .embed(x, delay, d)
    n <- nrow(Y)
    # need one more coordinate available for each point in dimension d+1
    Yn <- .embed(x, delay, d + 1L)
    m <- nrow(Yn)
    false <- 0L
    total <- 0L
    for (i in seq_len(m)) {
      di <- sqrt(colSums((t(Y[seq_len(m), , drop = FALSE]) - Y[i, ])^2))
      di[i] <- Inf
      j <- which.min(di)
      rd <- di[j]
      if (!is.finite(rd) || rd == 0) next
      extra <- abs(Yn[i, d + 1L] - Yn[j, d + 1L])
      total <- total + 1L
      if (extra / rd > rtol || sqrt(rd^2 + extra^2) / sd_x > atol) {
        false <- false + 1L
      }
    }
    if (total == 0L) 0 else false / total
  }, numeric(1))
}

#' First dimension where FNN drops below the threshold
#' @keywords internal
#' @noRd
.fnn_dimension <- function(fnn, threshold) {
  hit <- which(fnn <= threshold)
  if (length(hit) > 0L) hit[1] else which.min(fnn)
}

#' Chebyshev-distance pair count for sample entropy
#' @keywords internal
#' @noRd
.cheb_pair_count <- function(x, len, ntemp, r) {
  emb <- matrix(0, ntemp, len)
  for (k in seq_len(len)) {
    emb[, k] <- x[k:(k + ntemp - 1L)]
  }
  cnt <- 0
  for (i in seq_len(ntemp - 1L)) {
    rows <- (i + 1L):ntemp
    diffs <- abs(emb[rows, , drop = FALSE] -
                   matrix(emb[i, ], length(rows), len, byrow = TRUE))
    dmax <- if (len == 1L) diffs[, 1] else apply(diffs, 1, max)
    cnt <- cnt + sum(dmax <= r)
  }
  cnt
}

#' Mean signal period (samples) from the mean rate of zero crossings
#'
#' Uses zero crossings of the mean-subtracted signal, which track the dominant
#' oscillation rather than a low-frequency spectral peak; the mean period is
#' `2 * (N - 1) / n_crossings`. Used as the Theiler window for the Rosenstein
#' nearest-neighbour search.
#' @keywords internal
#' @noRd
.mean_period <- function(x) {
  xc <- x - mean(x)
  n <- length(xc)
  zc <- sum(xc[-1] * xc[-n] < 0)
  if (zc < 2L) {
    return(max(1L, n %/% 10L))
  }
  max(1L, as.integer(round(2 * (n - 1L) / zc)))
}

#' Rosenstein average logarithmic divergence of nearest-neighbour pairs
#' @keywords internal
#' @noRd
.rosenstein_divergence <- function(Y, theiler, max_steps) {
  P <- nrow(Y)
  # nearest neighbour of each reference point outside the Theiler window;
  # points whose entire candidate set is excluded (Theiler window covers the
  # trajectory) get NA rather than a fabricated index-1 neighbour.
  nn <- rep(NA_integer_, P)
  for (i in seq_len(P)) {
    d <- sqrt(colSums((t(Y) - Y[i, ])^2))
    excl <- max(1L, i - theiler):min(P, i + theiler)
    d[excl] <- Inf
    j <- which.min(d)
    if (length(j) == 1L && is.finite(d[j])) {
      nn[i] <- j
    }
  }
  if (sum(!is.na(nn)) < 2L) {
    stop("Theiler window too large: no valid nearest neighbours remain. ",
         "Reduce `mean_period`/`stride_samples` or use a longer series.",
         call. = FALSE)
  }
  div <- rep(NA_real_, max_steps + 1L)
  for (k in 0:max_steps) {
    ok <- !is.na(nn) & (seq_len(P) + k <= P) & (nn + k <= P)
    ok[is.na(ok)] <- FALSE
    if (!any(ok)) break
    ii <- which(ok)
    dd <- sqrt(rowSums((Y[ii + k, , drop = FALSE] -
                          Y[nn[ii] + k, , drop = FALSE])^2))
    dd <- dd[dd > 0]
    if (length(dd) > 0L) {
      div[k + 1L] <- mean(log(dd))
    }
  }
  div[!is.na(div)]
}

#' @export
print.time_delay_embedding <- function(x, ...) {
  cat(sprintf("<time_delay_embedding> delay=%d dim=%d, %d points\n",
              x$delay, x$dim, nrow(x$embedded)))
  invisible(x)
}

#' @export
print.lyapunov_exponent <- function(x, ...) {
  cat(sprintf("<lyapunov_exponent> lambda = %.4f /s (delay=%d, dim=%d)\n",
              x$lambda, x$delay, x$dim))
  invisible(x)
}

#' @export
print.local_dynamic_stability <- function(x, ...) {
  cat("<local_dynamic_stability>\n")
  cat(sprintf("  lambda_short: %.4f /stride\n", x$lambda_short))
  cat(sprintf("  lambda_long : %.4f /stride\n", x$lambda_long))
  invisible(x)
}

#' @export
print.harmonic_ratio <- function(x, ...) {
  cat(sprintf("<harmonic_ratio> (%s) ratio = %.3f (even=%.3g, odd=%.3g)\n",
              x$direction, x$ratio, x$even_sum, x$odd_sum))
  invisible(x)
}
