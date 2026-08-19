# Posturography: center-of-pressure sway metrics and clinical balance tests
#
# Implements the Prieto et al. (1996) posturographic steadiness battery together
# with the standard NeuroCom-style clinical balance protocols: the Sensory
# Organization Test (SOT), the modified Clinical Test of Sensory Interaction on
# Balance (mCTSIB), and Limits of Stability (LOS). The sway measures reuse the
# center-of-pressure output of [calculateCOP()] / [analyzeForcePlate()], and the
# non-linear complexity measures reuse [sampleEntropy()].
#
# References:
#   Prieto TE, Myklebust JB, Hoffmann RG, Lovett EG, Myklebust BM (1996).
#     "Measures of postural steadiness: differences between healthy young and
#     elderly adults." IEEE Trans Biomed Eng 43(9):956-966.
#   Collins JJ, De Luca CJ (1993). "Open-loop and closed-loop control of posture:
#     a random-walk analysis of center-of-pressure trajectories." Exp Brain Res
#     95:308-318.
#   Nashner LM (1997). "Computerized dynamic posturography." In: Handbook of
#     Balance Function Testing.

# ---- internal helpers -------------------------------------------------------

# Coerce assorted CoP representations to a two-column (ml, ap) matrix.
#
# Accepts, in priority order: explicit `ap`/`ml` numeric vectors; a data.frame
# with `cop_x`/`cop_y` (the [calculateCOP()] convention: x = medio-lateral,
# y = antero-posterior); a data.frame / matrix with columns named "ap"/"ml"
# (case-insensitive); or a bare two-column matrix interpreted as (ml, ap).
.pg_extract_apml <- function(cop, ap = NULL, ml = NULL) {
  if (!is.null(ap) || !is.null(ml)) {
    if (is.null(ap) || is.null(ml)) {
      stop("Supply both `ap` and `ml`, or neither.", call. = FALSE)
    }
    ap <- as.numeric(ap)
    ml <- as.numeric(ml)
    if (length(ap) != length(ml)) {
      stop("`ap` and `ml` must have the same length.", call. = FALSE)
    }
    return(cbind(ml = ml, ap = ap))
  }

  if (is.data.frame(cop)) {
    nm <- tolower(names(cop))
    if (all(c("cop_x", "cop_y") %in% nm)) {
      return(cbind(ml = as.numeric(cop[[which(nm == "cop_x")]]),
                   ap = as.numeric(cop[[which(nm == "cop_y")]])))
    }
    if (all(c("ap", "ml") %in% nm)) {
      return(cbind(ml = as.numeric(cop[[which(nm == "ml")]]),
                   ap = as.numeric(cop[[which(nm == "ap")]])))
    }
    cop <- as.matrix(cop[, seq_len(min(2L, ncol(cop))), drop = FALSE])
  }

  if (is.matrix(cop)) {
    if (ncol(cop) < 2L) {
      stop("`cop` matrix must have at least two columns (ml, ap).", call. = FALSE)
    }
    cn <- tolower(colnames(cop))
    if (!is.null(cn) && all(c("ap", "ml") %in% cn)) {
      return(cbind(ml = as.numeric(cop[, which(cn == "ml")]),
                   ap = as.numeric(cop[, which(cn == "ap")])))
    }
    if (!is.null(cn) && all(c("cop_x", "cop_y") %in% cn)) {
      return(cbind(ml = as.numeric(cop[, which(cn == "cop_x")]),
                   ap = as.numeric(cop[, which(cn == "cop_y")])))
    }
    return(cbind(ml = as.numeric(cop[, 1L]), ap = as.numeric(cop[, 2L])))
  }

  stop("`cop` must be a data.frame or matrix, or supply `ap`/`ml` vectors.",
       call. = FALSE)
}

# Detrended fluctuation analysis exponent (DFA-alpha), order-1 (linear) detrend.
# Integrates the mean-removed series into a profile, then regresses log RMS
# fluctuation on log box size. White noise -> alpha ~ 0.5, Brownian -> ~ 1.5.
.pg_dfa <- function(x, scales = NULL, min_box = 4L) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  N <- length(x)
  if (N < 4L * min_box) {
    return(NA_real_)
  }
  profile <- cumsum(x - mean(x))
  if (is.null(scales)) {
    smax <- floor(N / 4L)
    if (smax <= min_box) {
      return(NA_real_)
    }
    scales <- unique(round(exp(seq(log(min_box), log(smax), length.out = 16L))))
    scales <- scales[scales >= min_box & scales <= smax]
  }
  if (length(scales) < 3L) {
    return(NA_real_)
  }
  fluct <- vapply(scales, function(s) {
    nb <- N %/% s
    if (nb < 1L) {
      return(NA_real_)
    }
    tt <- seq_len(s)
    dm <- cbind(1, tt)
    resid2 <- vapply(seq_len(nb), function(b) {
      seg <- profile[((b - 1L) * s + 1L):(b * s)]
      fit <- stats::lm.fit(dm, seg)
      mean(fit$residuals^2)
    }, numeric(1))
    sqrt(mean(resid2))
  }, numeric(1))
  ok <- is.finite(fluct) & fluct > 0
  if (sum(ok) < 3L) {
    return(NA_real_)
  }
  unname(stats::coef(stats::lm(log(fluct[ok]) ~ log(scales[ok])))[2L])
}

# Mean of the local minima of instantaneous time-to-boundary for one axis.
# `lo`/`hi` are the (signed) boundary positions on that axis in CoP units.
# Instantaneous TTB = distance to the boundary the CoP is moving toward, divided
# by the speed toward it (van Wegen et al. 2002).
.pg_ttb_axis <- function(pos, vel, lo, hi) {
  n <- length(pos)
  ttb <- rep(NA_real_, n)
  moving_pos <- is.finite(vel) & vel > 0
  moving_neg <- is.finite(vel) & vel < 0
  ttb[moving_pos] <- (hi - pos[moving_pos]) / vel[moving_pos]
  ttb[moving_neg] <- (lo - pos[moving_neg]) / vel[moving_neg]
  ttb[is.finite(ttb) & ttb < 0] <- NA_real_
  # local minima of the finite instantaneous-TTB series
  finite <- which(is.finite(ttb))
  if (length(finite) < 3L) {
    return(if (length(finite) == 0L) NA_real_ else mean(ttb[finite]))
  }
  minima <- numeric(0)
  for (i in finite) {
    if (i == 1L || i == n) next
    left <- ttb[i - 1L]
    right <- ttb[i + 1L]
    if (is.finite(left) && is.finite(right) &&
        ttb[i] <= left && ttb[i] <= right) {
      minima <- c(minima, ttb[i])
    }
  }
  if (length(minima) == 0L) {
    return(min(ttb[finite]))
  }
  mean(minima)
}

# Spectral moments mu_k = sum(f^k * G(f)) of a one-sided periodogram, plus the
# derived Prieto frequency-domain measures.
.pg_spectral <- function(x, sampling_rate) {
  x <- as.numeric(x)
  N <- length(x)
  x <- x - mean(x)
  # one-sided power spectrum from the raw periodogram
  fx <- stats::fft(x)
  half <- N %/% 2L
  power <- (Mod(fx[2:(half + 1L)])^2) / N          # drop DC, keep positive freqs
  freq <- seq_len(half) * sampling_rate / N
  m0 <- sum(power)
  if (m0 <= 0) {
    return(list(total_power = 0, f50 = NA_real_, f95 = NA_real_,
                centroidal = NA_real_, dispersion = NA_real_))
  }
  m1 <- sum(freq * power)
  m2 <- sum(freq^2 * power)
  cum <- cumsum(power) / m0
  f50 <- freq[which(cum >= 0.50)[1L]]
  f95 <- freq[which(cum >= 0.95)[1L]]
  centroidal <- sqrt(m2 / m0)
  disp <- sqrt(pmax(0, 1 - (m1^2) / (m0 * m2)))
  list(total_power = m0, f50 = f50, f95 = f95,
       centroidal = centroidal, dispersion = disp)
}

# ---- Prieto sway battery ----------------------------------------------------

#' Posturographic center-of-pressure sway metrics (Prieto 1996)
#'
#' Computes the full Prieto et al. (1996) battery of postural-steadiness
#' measures from a center-of-pressure (CoP) time series, together with the
#' non-linear complexity descriptors used by [schema_balance]. Distances are
#' reported in the units of the supplied CoP (typically mm or m); frequencies in
#' Hz; areas in CoP-units squared; velocities in CoP-units per second.
#'
#' @details
#' The measures are defined relative to the mean CoP. With \eqn{RD_n} the
#' resultant distance of sample \eqn{n} from the mean CoP and \eqn{T} the trial
#' duration:
#'
#' - **Path length** (total excursion, TOTEX): the summed point-to-point
#'   distance; **mean velocity** is TOTEX / T.
#' - **RMS distance** (RDIST) and **mean distance** (MDIST), resultant and
#'   per-axis.
#' - **95% confidence circle area** (AREA-CC)
#'   \eqn{= \pi (MDIST + z\, s_{RD})^2} with \eqn{z = 1.645}.
#' - **95% confidence ellipse area** (AREA-CE)
#'   \eqn{= 2\pi F_{0.05[2,n-2]} \sqrt{s_{AP}^2 s_{ML}^2 - s_{AP,ML}^2}}.
#' - **Sway area** (AREA-SW), area swept per unit time.
#' - **Mean frequency** (MFREQ), the equivalent rotational frequency
#'   \eqn{MVELO / (2\pi\, MDIST)}.
#' - **Fractal dimension** (FD-CC) and frequency-domain measures (total power,
#'   50%/95% power frequency, centroidal frequency, frequency dispersion).
#' - **Non-linear** sample entropy and DFA-\eqn{\alpha} per axis, and optional
#'   time-to-boundary if a base of support is supplied.
#'
#' @param cop Center-of-pressure data. A `data.frame` from [calculateCOP()]
#'   (columns `cop_x` = ML, `cop_y` = AP), a two-column matrix/`data.frame`
#'   (columns interpreted as `ml`, `ap` unless named), or `NULL` when supplying
#'   `ap`/`ml` directly.
#' @param sampling_rate Sampling rate in Hz.
#' @param ap,ml Optional anteroposterior / mediolateral CoP vectors (override
#'   `cop`).
#' @param detrend Either `"mean"` (subtract the mean CoP, the Prieto
#'   convention) or `"none"`.
#' @param entropy Logical; compute per-axis [sampleEntropy()] and DFA-\eqn{\alpha}
#'   (default `TRUE`).
#' @param m,r Sample-entropy embedding dimension and tolerance (tolerance is a
#'   fraction of each axis SD).
#' @param base_of_support Optional numeric `c(ap = , ml = )` giving the half
#'   extent of the base of support (in CoP units) about the mean CoP, used for
#'   time-to-boundary. `NULL` (default) returns `NA` for the TTB measures.
#'
#' @return A `sway_metrics` object (a named list) with the Prieto measures and,
#'   in `$metrics`, a one-row `data.frame` aligned to the [schema_balance]
#'   metric names.
#'
#' @references
#' Prieto TE, Myklebust JB, Hoffmann RG, Lovett EG, Myklebust BM (1996).
#' "Measures of postural steadiness." IEEE Trans Biomed Eng 43(9):956-966.
#'
#' @seealso [calculateCOP()], [analyzeForcePlate()], [stabilogramDiffusion()],
#'   [sensoryOrganizationTest()], [schema_balance]
#'
#' @export
#'
#' @examples
#' t <- seq(0, 30, by = 0.01)
#' cop <- data.frame(cop_x = 2 * sin(2 * pi * 0.2 * t),
#'                   cop_y = 3 * cos(2 * pi * 0.2 * t))
#' sm <- swayMetrics(cop, sampling_rate = 100)
#' sm$path_length
#' sm$mean_velocity
swayMetrics <- function(cop,
                        sampling_rate,
                        ap = NULL,
                        ml = NULL,
                        detrend = c("mean", "none"),
                        entropy = TRUE,
                        m = 2L,
                        r = 0.2,
                        base_of_support = NULL) {

  detrend <- match.arg(detrend)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1L,
            sampling_rate > 0)

  xy <- .pg_extract_apml(cop, ap = ap, ml = ml)
  ml_v <- xy[, "ml"]
  ap_v <- xy[, "ap"]
  keep <- is.finite(ml_v) & is.finite(ap_v)
  ml_v <- ml_v[keep]
  ap_v <- ap_v[keep]
  N <- length(ap_v)
  if (N < 3L) {
    stop("Need at least 3 valid CoP samples.", call. = FALSE)
  }

  if (detrend == "mean") {
    ap_v <- ap_v - mean(ap_v)
    ml_v <- ml_v - mean(ml_v)
  }

  rd <- sqrt(ap_v^2 + ml_v^2)          # resultant distance from mean CoP
  Tdur <- (N - 1L) / sampling_rate     # trial duration spanned by the samples

  # --- distance measures ---
  mdist <- mean(rd)
  mdist_ap <- mean(abs(ap_v))
  mdist_ml <- mean(abs(ml_v))
  rdist <- sqrt(mean(rd^2))
  rdist_ap <- sqrt(mean(ap_v^2))
  rdist_ml <- sqrt(mean(ml_v^2))
  range_ap <- diff(range(ap_v))
  range_ml <- diff(range(ml_v))

  # --- excursion / velocity ---
  d_ap <- diff(ap_v)
  d_ml <- diff(ml_v)
  totex <- sum(sqrt(d_ap^2 + d_ml^2))
  totex_ap <- sum(abs(d_ap))
  totex_ml <- sum(abs(d_ml))
  mvelo <- totex / Tdur
  mvelo_ap <- totex_ap / Tdur
  mvelo_ml <- totex_ml / Tdur

  # --- 95% confidence circle area (AREA-CC) ---
  # s_RD is the standard deviation of the resultant distance about MDIST.
  s_rd <- sqrt(max(0, rdist^2 - mdist^2))
  z95 <- 1.645
  area_cc <- pi * (mdist + z95 * s_rd)^2

  # --- 95% confidence ellipse area (AREA-CE) ---
  # variances/covariance about the mean (mean already removed above)
  s_ap2 <- mean(ap_v^2)
  s_ml2 <- mean(ml_v^2)
  s_apml <- mean(ap_v * ml_v)
  det_cov <- max(0, s_ap2 * s_ml2 - s_apml^2)
  fval <- if (N > 2L) stats::qf(0.95, 2, N - 2L) else 3
  area_ce <- 2 * pi * fval * sqrt(det_cov)

  # --- sway area (AREA-SW): area swept per unit time ---
  cross <- ap_v[-1L] * ml_v[-N] - ap_v[-N] * ml_v[-1L]
  area_sw <- sum(abs(cross)) / (2 * Tdur)

  # --- mean frequency (MFREQ) ---
  mfreq <- if (mdist > 0) mvelo / (2 * pi * mdist) else NA_real_
  mfreq_ap <- if (mdist_ap > 0) mvelo_ap / (4 * sqrt(2) * mdist_ap) else NA_real_
  mfreq_ml <- if (mdist_ml > 0) mvelo_ml / (4 * sqrt(2) * mdist_ml) else NA_real_

  # --- fractal dimension (FD-CC): d = diameter of the 95% confidence circle ---
  d_cc <- 2 * (mdist + z95 * s_rd)
  fd_cc <- if (totex > 0 && d_cc > 0 && (N * d_cc) != totex) {
    log(N) / log((N * d_cc) / totex)
  } else {
    NA_real_
  }

  # --- frequency-domain measures (resultant of the two axes) ---
  spec_ap <- .pg_spectral(ap_v, sampling_rate)
  spec_ml <- .pg_spectral(ml_v, sampling_rate)

  # --- non-linear complexity ---
  samp_en_ap <- NA_real_
  samp_en_ml <- NA_real_
  dfa_ap <- NA_real_
  dfa_ml <- NA_real_
  if (isTRUE(entropy)) {
    samp_en_ap <- tryCatch(sampleEntropy(ap_v, m = m, r = r),
                           error = function(e) NA_real_)
    samp_en_ml <- tryCatch(sampleEntropy(ml_v, m = m, r = r),
                           error = function(e) NA_real_)
    dfa_ap <- .pg_dfa(ap_v)
    dfa_ml <- .pg_dfa(ml_v)
  }

  # --- time-to-boundary ---
  ttb_ap <- NA_real_
  ttb_ml <- NA_real_
  if (!is.null(base_of_support)) {
    bos <- base_of_support
    if (is.null(names(bos))) names(bos) <- c("ap", "ml")[seq_along(bos)]
    if (!all(c("ap", "ml") %in% names(bos))) {
      stop("`base_of_support` must be named c(ap = , ml = ).", call. = FALSE)
    }
    v_ap <- c(d_ap, d_ap[length(d_ap)]) * sampling_rate
    v_ml <- c(d_ml, d_ml[length(d_ml)]) * sampling_rate
    ttb_ap <- .pg_ttb_axis(ap_v, v_ap, lo = -abs(bos[["ap"]]), hi = abs(bos[["ap"]]))
    ttb_ml <- .pg_ttb_axis(ml_v, v_ml, lo = -abs(bos[["ml"]]), hi = abs(bos[["ml"]]))
  }

  metrics <- data.frame(
    cop_velocity_ap = mvelo_ap,
    cop_velocity_ml = mvelo_ml,
    cop_velocity_resultant = mvelo,
    cop_path_length = totex,
    cop_area_95 = area_cc,
    cop_area_ce = area_ce,
    cop_range_ap = range_ap,
    cop_range_ml = range_ml,
    sway_frequency_ap = mfreq_ap,
    sway_frequency_ml = mfreq_ml,
    sample_entropy_ap = samp_en_ap,
    sample_entropy_ml = samp_en_ml,
    dfa_alpha_ap = dfa_ap,
    dfa_alpha_ml = dfa_ml,
    time_to_boundary_ap = ttb_ap,
    time_to_boundary_ml = ttb_ml,
    stringsAsFactors = FALSE
  )

  structure(
    list(
      n_samples = N,
      duration = Tdur,
      sampling_rate = sampling_rate,
      mean_distance = mdist,
      mean_distance_ap = mdist_ap,
      mean_distance_ml = mdist_ml,
      rms_distance = rdist,
      rms_distance_ap = rdist_ap,
      rms_distance_ml = rdist_ml,
      range_ap = range_ap,
      range_ml = range_ml,
      path_length = totex,
      path_length_ap = totex_ap,
      path_length_ml = totex_ml,
      mean_velocity = mvelo,
      mean_velocity_ap = mvelo_ap,
      mean_velocity_ml = mvelo_ml,
      area_cc = area_cc,
      area_ce = area_ce,
      area_sw = area_sw,
      mean_frequency = mfreq,
      mean_frequency_ap = mfreq_ap,
      mean_frequency_ml = mfreq_ml,
      fractal_dimension = fd_cc,
      total_power_ap = spec_ap$total_power,
      total_power_ml = spec_ml$total_power,
      f50_ap = spec_ap$f50, f50_ml = spec_ml$f50,
      f95_ap = spec_ap$f95, f95_ml = spec_ml$f95,
      centroidal_freq_ap = spec_ap$centroidal,
      centroidal_freq_ml = spec_ml$centroidal,
      freq_dispersion_ap = spec_ap$dispersion,
      freq_dispersion_ml = spec_ml$dispersion,
      sample_entropy_ap = samp_en_ap,
      sample_entropy_ml = samp_en_ml,
      dfa_alpha_ap = dfa_ap,
      dfa_alpha_ml = dfa_ml,
      time_to_boundary_ap = ttb_ap,
      time_to_boundary_ml = ttb_ml,
      metrics = metrics
    ),
    class = "sway_metrics"
  )
}

#' @export
print.sway_metrics <- function(x, ...) {
  cat("<sway_metrics>\n")
  cat(sprintf("  samples: %d   duration: %.2f s   fs: %g Hz\n",
              x$n_samples, x$duration, x$sampling_rate))
  cat(sprintf("  path length (TOTEX): %.4g   mean velocity: %.4g /s\n",
              x$path_length, x$mean_velocity))
  cat(sprintf("  RMS distance: %.4g   mean distance: %.4g\n",
              x$rms_distance, x$mean_distance))
  cat(sprintf("  95%% conf. circle area: %.4g   ellipse area: %.4g\n",
              x$area_cc, x$area_ce))
  cat(sprintf("  sway area: %.4g   mean frequency: %.4g Hz\n",
              x$area_sw, x$mean_frequency))
  invisible(x)
}

#' Stabilogram diffusion analysis (Collins & De Luca 1993)
#'
#' Computes the mean square displacement (MSD) of the CoP as a function of the
#' time interval and extracts the short-term and long-term diffusion
#' coefficients and the critical point (the crossover between open-loop and
#' closed-loop postural control). Planar (resultant) and per-axis analyses are
#' returned.
#'
#' @param cop,ap,ml,sampling_rate,detrend As in [swayMetrics()].
#' @param max_interval Maximum time interval in seconds over which to compute the
#'   MSD (default 10, capped at half the record length).
#' @param short_max,long_min Interval boundaries (seconds) for the short-term
#'   (default `<= 1 s`) and long-term (default `>= 2.5 s`) linear regions used to
#'   estimate the diffusion coefficients.
#'
#' @return A `stabilogram_diffusion` object with, per component (`planar`, `ap`,
#'   `ml`), the short/long diffusion coefficients, scaling exponents (Hurst) and
#'   the critical-point interval and MSD.
#'
#' @references
#' Collins JJ, De Luca CJ (1993). Exp Brain Res 95:308-318.
#'
#' @seealso [swayMetrics()]
#'
#' @export
#'
#' @examples
#' set.seed(1)
#' n <- 3000
#' cop <- data.frame(cop_x = cumsum(rnorm(n)) * 0.05,
#'                   cop_y = cumsum(rnorm(n)) * 0.05)
#' stabilogramDiffusion(cop, sampling_rate = 100)
stabilogramDiffusion <- function(cop,
                                 sampling_rate,
                                 ap = NULL,
                                 ml = NULL,
                                 detrend = c("mean", "none"),
                                 max_interval = 10,
                                 short_max = 1,
                                 long_min = 2.5) {

  detrend <- match.arg(detrend)
  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1L,
            sampling_rate > 0)

  xy <- .pg_extract_apml(cop, ap = ap, ml = ml)
  ml_v <- xy[, "ml"]
  ap_v <- xy[, "ap"]
  keep <- is.finite(ml_v) & is.finite(ap_v)
  ml_v <- ml_v[keep]
  ap_v <- ap_v[keep]
  N <- length(ap_v)
  if (N < 20L) {
    stop("Need at least 20 valid CoP samples for diffusion analysis.",
         call. = FALSE)
  }
  if (detrend == "mean") {
    ap_v <- ap_v - mean(ap_v)
    ml_v <- ml_v - mean(ml_v)
  }

  max_lag <- min(floor(max_interval * sampling_rate), N %/% 2L)
  lags <- seq_len(max_lag)
  intervals <- lags / sampling_rate

  msd <- function(v) {
    vapply(lags, function(k) mean((v[(k + 1L):N] - v[1:(N - k)])^2), numeric(1))
  }
  msd_ap <- msd(ap_v)
  msd_ml <- msd(ml_v)
  msd_planar <- msd_ap + msd_ml

  fit_component <- function(msd_vals, planar = FALSE) {
    short_idx <- which(intervals <= short_max)
    long_idx <- which(intervals >= long_min)
    # diffusion coefficient D = slope(MSD vs dt) / (2 * dimension)
    dim_factor <- if (planar) 4 else 2
    d_short <- d_long <- h_short <- h_long <- NA_real_
    if (length(short_idx) >= 2L) {
      s <- stats::coef(stats::lm(msd_vals[short_idx] ~ intervals[short_idx]))[2L]
      d_short <- unname(s) / dim_factor
      pos <- msd_vals[short_idx] > 0
      if (sum(pos) >= 2L) {
        h_short <- unname(stats::coef(stats::lm(
          log(msd_vals[short_idx][pos]) ~ log(intervals[short_idx][pos])))[2L]) / 2
      }
    }
    if (length(long_idx) >= 2L) {
      s <- stats::coef(stats::lm(msd_vals[long_idx] ~ intervals[long_idx]))[2L]
      d_long <- unname(s) / dim_factor
      pos <- msd_vals[long_idx] > 0
      if (sum(pos) >= 2L) {
        h_long <- unname(stats::coef(stats::lm(
          log(msd_vals[long_idx][pos]) ~ log(intervals[long_idx][pos])))[2L]) / 2
      }
    }
    # critical point: intersection of the short and long linear fits
    crit_time <- crit_msd <- NA_real_
    if (length(short_idx) >= 2L && length(long_idx) >= 2L) {
      cs <- stats::coef(stats::lm(msd_vals[short_idx] ~ intervals[short_idx]))
      cl <- stats::coef(stats::lm(msd_vals[long_idx] ~ intervals[long_idx]))
      denom <- cs[2L] - cl[2L]
      if (is.finite(denom) && abs(denom) > .Machine$double.eps) {
        crit_time <- unname((cl[1L] - cs[1L]) / denom)
        crit_msd <- unname(cs[1L] + cs[2L] * crit_time)
      }
    }
    list(d_short = d_short, d_long = d_long,
         h_short = h_short, h_long = h_long,
         crit_time = crit_time, crit_msd = crit_msd)
  }

  structure(
    list(
      intervals = intervals,
      msd_planar = msd_planar,
      msd_ap = msd_ap,
      msd_ml = msd_ml,
      planar = fit_component(msd_planar, planar = TRUE),
      ap = fit_component(msd_ap),
      ml = fit_component(msd_ml)
    ),
    class = "stabilogram_diffusion"
  )
}

#' @export
print.stabilogram_diffusion <- function(x, ...) {
  cat("<stabilogram_diffusion>\n")
  for (comp in c("planar", "ap", "ml")) {
    cc <- x[[comp]]
    cat(sprintf("  %-6s Ds=%.4g Dl=%.4g Hs=%.3f Hl=%.3f crit=(%.3g s, %.3g)\n",
                comp, cc$d_short, cc$d_long, cc$h_short, cc$h_long,
                cc$crit_time, cc$crit_msd))
  }
  invisible(x)
}

# ---- Sensory Organization Test ---------------------------------------------

#' Sensory Organization Test (SOT) equilibrium and sensory-ratio scoring
#'
#' Computes NeuroCom-style Sensory Organization Test equilibrium scores,
#' composite score, and the four sensory-analysis ratios from either per-trial
#' equilibrium scores or per-trial peak-to-peak anteroposterior sway angles.
#'
#' The equilibrium score for a trial is
#' \eqn{EQ = 100 \times (\theta_{lim} - \theta_{pp}) / \theta_{lim}}, where
#' \eqn{\theta_{pp}} is the peak-to-peak AP sway angle and \eqn{\theta_{lim}} the
#' theoretical AP stability limit (12.5 deg). The composite is the mean of the
#' condition-1 and condition-2 average scores together with every individual
#' trial score of conditions 3-6. The sensory ratios use condition average
#' scores: SOM = C2/C1, VIS = C4/C1, VEST = C5/C1, PREF = (C3+C6)/(C2+C5).
#'
#' @param scores A 6-row (conditions 1-6) numeric matrix / `data.frame` of
#'   equilibrium scores, columns = trials; or a list of 6 numeric vectors. `NA`
#'   entries (e.g. a fall) are treated as a fall with score 0 when
#'   `fall_as_zero = TRUE`.
#' @param sway_angle Alternatively, peak-to-peak AP sway angles (degrees) in the
#'   same shape as `scores`; converted to equilibrium scores.
#' @param theta_limit Theoretical AP stability limit in degrees (default 12.5).
#' @param fall_as_zero Logical; treat `NA` trials as falls scored 0
#'   (default `TRUE`).
#'
#' @return A `sot_result` object with per-trial `equilibrium`, per-condition
#'   `condition_means`, `composite`, and `ratios` (SOM/VIS/VEST/PREF).
#'
#' @references
#' Nashner LM (1997). "Computerized dynamic posturography."
#'
#' @seealso [mCTSIB()], [limitsOfStability()], [swayMetrics()]
#'
#' @export
#'
#' @examples
#' # Three trials per condition, equilibrium scores already computed
#' sc <- rbind(c(94, 95, 93), c(92, 91, 93), c(88, 90, 89),
#'             c(85, 84, 86), c(70, 72, 68), c(65, 66, 64))
#' sensoryOrganizationTest(sc)
sensoryOrganizationTest <- function(scores = NULL,
                                    sway_angle = NULL,
                                    theta_limit = 12.5,
                                    fall_as_zero = TRUE) {

  if (is.null(scores) && is.null(sway_angle)) {
    stop("Supply either `scores` or `sway_angle`.", call. = FALSE)
  }
  if (!is.null(scores) && !is.null(sway_angle)) {
    stop("Supply only one of `scores` or `sway_angle`.", call. = FALSE)
  }

  # Coerce list/matrix/data.frame input to a numeric matrix and record which
  # cells are *structural padding* (introduced when a ragged list of unequal
  # trial counts is rbind-ed) versus user-supplied cells. Padding must never be
  # confused with a genuine fall (a user-supplied NA).
  to_matrix <- function(z) {
    padding <- NULL
    if (is.list(z) && !is.data.frame(z)) {
      lens <- vapply(z, length, integer(1))
      n <- max(lens)
      padding <- do.call(rbind, lapply(lens, function(L) {
        c(rep(FALSE, L), rep(TRUE, n - L))
      }))
      z <- do.call(rbind, lapply(z, function(v) {
        length(v) <- n
        v
      }))
    }
    z <- as.matrix(z)
    storage.mode(z) <- "double"
    if (is.null(padding)) {
      padding <- matrix(FALSE, nrow(z), ncol(z))
    }
    attr(z, "padding") <- padding
    z
  }

  if (!is.null(sway_angle)) {
    ang <- to_matrix(sway_angle)
    padding <- attr(ang, "padding")
    stopifnot(is.numeric(theta_limit), length(theta_limit) == 1L,
              theta_limit > 0)
    eq <- 100 * (theta_limit - ang) / theta_limit
  } else {
    eq <- to_matrix(scores)
    padding <- attr(eq, "padding")
  }
  eq <- as.matrix(eq)
  attr(eq, "padding") <- NULL

  if (nrow(eq) != 6L) {
    stop("SOT requires exactly 6 conditions (rows).", call. = FALSE)
  }
  # Genuine falls (user NAs) become 0; structural padding stays NA so it is
  # ignored by rowMeans(na.rm) and the tail-trial drop.
  if (isTRUE(fall_as_zero)) {
    eq[is.na(eq) & !padding] <- 0
  }

  condition_means <- rowMeans(eq, na.rm = TRUE)
  names(condition_means) <- paste0("C", seq_len(6L))

  # Composite: mean(C1) + mean(C2) + every individual trial of C3..C6, over the
  # total number of contributing values.
  c1 <- condition_means[["C1"]]
  c2 <- condition_means[["C2"]]
  tail_trials <- as.numeric(eq[3:6, , drop = FALSE])
  tail_trials <- tail_trials[!is.na(tail_trials)]
  composite <- (c1 + c2 + sum(tail_trials)) / (2 + length(tail_trials))

  cm <- condition_means
  ratios <- c(
    SOM = cm[["C2"]] / cm[["C1"]],
    VIS = cm[["C4"]] / cm[["C1"]],
    VEST = cm[["C5"]] / cm[["C1"]],
    PREF = (cm[["C3"]] + cm[["C6"]]) / (cm[["C2"]] + cm[["C5"]])
  )

  structure(
    list(
      equilibrium = eq,
      condition_means = condition_means,
      composite = composite,
      ratios = ratios,
      theta_limit = theta_limit
    ),
    class = "sot_result"
  )
}

#' @export
print.sot_result <- function(x, ...) {
  cat("<sot_result>\n")
  cat("  condition means:",
      paste(sprintf("%s=%.1f", names(x$condition_means), x$condition_means),
            collapse = "  "), "\n")
  cat(sprintf("  composite: %.1f\n", x$composite))
  cat("  ratios:",
      paste(sprintf("%s=%.3f", names(x$ratios), x$ratios), collapse = "  "),
      "\n")
  invisible(x)
}

# ---- modified CTSIB ---------------------------------------------------------

#' Modified Clinical Test of Sensory Interaction on Balance (mCTSIB)
#'
#' Summarises sway velocity (or any sway index) across the four mCTSIB sensory
#' conditions (eyes open / closed on a firm surface and on foam) and returns the
#' per-condition means and the composite (mean of the four condition means).
#'
#' @param eyes_open_firm,eyes_closed_firm,eyes_open_foam,eyes_closed_foam
#'   Numeric vectors of per-trial sway velocities (or another sway index) for
#'   each condition. Missing conditions may be `NULL`.
#' @param conditions Alternatively, a named list with those four elements.
#'
#' @return An `mctsib_result` object with `condition_means`, `condition_sd`,
#'   `n_trials` and the `composite` mean.
#'
#' @references
#' Cohen H, Blatchly CA, Gombash LL (1993). Phys Ther 73(6):346-351.
#'
#' @seealso [sensoryOrganizationTest()], [swayMetrics()]
#'
#' @export
#'
#' @examples
#' mCTSIB(eyes_open_firm = c(0.4, 0.5),
#'        eyes_closed_firm = c(0.6, 0.7),
#'        eyes_open_foam = c(0.9, 1.0),
#'        eyes_closed_foam = c(1.6, 1.8))
mCTSIB <- function(eyes_open_firm = NULL,
                   eyes_closed_firm = NULL,
                   eyes_open_foam = NULL,
                   eyes_closed_foam = NULL,
                   conditions = NULL) {

  labels <- c("eyes_open_firm", "eyes_closed_firm",
              "eyes_open_foam", "eyes_closed_foam")
  if (!is.null(conditions)) {
    if (!is.list(conditions) || is.null(names(conditions))) {
      stop("`conditions` must be a named list.", call. = FALSE)
    }
    cond <- conditions[labels]
  } else {
    cond <- list(eyes_open_firm, eyes_closed_firm,
                 eyes_open_foam, eyes_closed_foam)
    names(cond) <- labels
  }

  present <- !vapply(cond, is.null, logical(1))
  if (!any(present)) {
    stop("Supply at least one condition.", call. = FALSE)
  }

  means <- vapply(cond, function(v) {
    if (is.null(v)) NA_real_ else mean(as.numeric(v), na.rm = TRUE)
  }, numeric(1))
  sds <- vapply(cond, function(v) {
    if (is.null(v) || length(v) < 2L) NA_real_ else stats::sd(as.numeric(v),
                                                              na.rm = TRUE)
  }, numeric(1))
  ns <- vapply(cond, function(v) {
    if (is.null(v)) 0L else sum(is.finite(as.numeric(v)))
  }, integer(1))

  composite <- mean(means[present], na.rm = TRUE)

  structure(
    list(
      condition_means = means,
      condition_sd = sds,
      n_trials = ns,
      composite = composite
    ),
    class = "mctsib_result"
  )
}

#' @export
print.mctsib_result <- function(x, ...) {
  cat("<mctsib_result>\n")
  for (nm in names(x$condition_means)) {
    cat(sprintf("  %-18s mean=%.4g  (n=%d)\n", nm,
                x$condition_means[[nm]], x$n_trials[[nm]]))
  }
  cat(sprintf("  composite: %.4g\n", x$composite))
  invisible(x)
}

# ---- Limits of Stability ----------------------------------------------------

#' Limits of Stability (LOS) reaction time, excursion and directional control
#'
#' Quantifies a single limits-of-stability leaning trial toward a target
#' direction from a CoP trace: reaction time, endpoint and maximum excursion
#' (optionally as a percentage of a theoretical limit), and directional control.
#'
#' The CoP is projected onto the unit vector toward the target. Reaction time is
#' the delay from the go cue to movement onset (projection first exceeding
#' `onset_frac` of the maximum excursion). Endpoint excursion is the projection
#' at the end of the initial movement (its first local maximum after onset);
#' maximum excursion is the largest projection. Directional control is
#' \eqn{100 \times} the path travelled toward the target divided by the total
#' path length.
#'
#' @param cop,ap,ml CoP trace, as in [swayMetrics()] (a single leaning trial).
#' @param sampling_rate Sampling rate in Hz.
#' @param target Target direction: an angle in degrees (0 = +AP/forward,
#'   90 = +ML/right, measured counter-clockwise from forward) or a length-2
#'   numeric `c(ap, ml)` direction vector.
#' @param onset_cue Sample index of the go cue (default 1).
#' @param onset_frac Fraction of the maximum excursion defining movement onset
#'   (default 0.05).
#' @param los_distance Optional theoretical limit-of-stability distance (CoP
#'   units) for the target; if supplied, excursions are also returned as a
#'   percentage of it.
#'
#' @return A `los_result` object with `reaction_time`, `endpoint_excursion`,
#'   `max_excursion`, optional `endpoint_pct` / `max_pct`, and
#'   `directional_control`.
#'
#' @references
#' Nashner LM (1997). "Computerized dynamic posturography."
#'
#' @seealso [sensoryOrganizationTest()], [swayMetrics()]
#'
#' @export
#'
#' @examples
#' t <- seq(0, 3, by = 0.01)
#' lean <- pmin(t / 1.5, 1) * 5             # ramp forward to 5 units
#' cop <- data.frame(cop_x = rnorm(length(t), 0, 0.02), cop_y = lean)
#' limitsOfStability(cop, sampling_rate = 100, target = 0)
limitsOfStability <- function(cop,
                              sampling_rate,
                              target,
                              ap = NULL,
                              ml = NULL,
                              onset_cue = 1L,
                              onset_frac = 0.05,
                              los_distance = NULL) {

  stopifnot(is.numeric(sampling_rate), length(sampling_rate) == 1L,
            sampling_rate > 0)
  stopifnot(is.numeric(onset_frac), length(onset_frac) == 1L,
            onset_frac >= 0, onset_frac < 1)

  xy <- .pg_extract_apml(cop, ap = ap, ml = ml)
  ml_v <- xy[, "ml"]
  ap_v <- xy[, "ap"]
  N <- length(ap_v)
  if (N < 3L) {
    stop("Need at least 3 CoP samples.", call. = FALSE)
  }
  onset_cue <- as.integer(onset_cue)
  if (onset_cue < 1L || onset_cue > N) {
    stop("`onset_cue` out of range.", call. = FALSE)
  }

  # unit vector toward target
  if (length(target) == 1L) {
    ang <- target * pi / 180
    u <- c(ap = cos(ang), ml = sin(ang))
  } else if (length(target) == 2L) {
    u <- c(ap = as.numeric(target[1L]), ml = as.numeric(target[2L]))
    nrm <- sqrt(sum(u^2))
    if (nrm == 0) stop("`target` direction vector is zero.", call. = FALSE)
    u <- u / nrm
  } else {
    stop("`target` must be an angle or a length-2 direction vector.",
         call. = FALSE)
  }

  # reference at the go cue
  ap0 <- ap_v[onset_cue]
  ml0 <- ml_v[onset_cue]
  proj <- (ap_v - ap0) * u[["ap"]] + (ml_v - ml0) * u[["ml"]]

  idx <- onset_cue:N
  proj_after <- proj[idx]
  max_exc <- max(proj_after)
  max_at <- idx[which.max(proj_after)]

  # reaction time: first crossing of onset threshold after the cue
  thr <- onset_frac * max_exc
  onset_rel <- which(proj_after >= thr)
  reaction_time <- if (length(onset_rel) > 0 && max_exc > 0) {
    (onset_rel[1L] - 1L) / sampling_rate
  } else {
    NA_real_
  }

  # endpoint excursion: first local maximum after onset (end of primary move)
  endpoint_excursion <- max_exc
  if (length(onset_rel) > 0) {
    start <- onset_rel[1L]
    seg <- proj_after[start:length(proj_after)]
    if (length(seg) >= 3L) {
      dseg <- diff(seg)
      turn <- which(dseg[-length(dseg)] > 0 & dseg[-1L] <= 0)
      if (length(turn) > 0) {
        endpoint_excursion <- seg[turn[1L] + 1L]
      }
    }
  }

  # directional control: path toward target / total path
  d_ap <- diff(ap_v)
  d_ml <- diff(ml_v)
  d_proj <- diff(proj)
  path_total <- sum(sqrt(d_ap^2 + d_ml^2))
  path_toward <- sum(pmax(d_proj, 0))
  directional_control <- if (path_total > 0) 100 * path_toward / path_total else NA_real_

  endpoint_pct <- max_pct <- NA_real_
  if (!is.null(los_distance)) {
    stopifnot(is.numeric(los_distance), length(los_distance) == 1L,
              los_distance > 0)
    endpoint_pct <- 100 * endpoint_excursion / los_distance
    max_pct <- 100 * max_exc / los_distance
  }

  structure(
    list(
      reaction_time = reaction_time,
      endpoint_excursion = endpoint_excursion,
      max_excursion = max_exc,
      max_excursion_time = (max_at - onset_cue) / sampling_rate,
      endpoint_pct = endpoint_pct,
      max_pct = max_pct,
      directional_control = directional_control,
      target_unit = u
    ),
    class = "los_result"
  )
}

#' @export
print.los_result <- function(x, ...) {
  cat("<los_result>\n")
  cat(sprintf("  reaction time: %.3f s\n", x$reaction_time))
  cat(sprintf("  endpoint excursion: %.4g   max excursion: %.4g\n",
              x$endpoint_excursion, x$max_excursion))
  if (!is.na(x$max_pct)) {
    cat(sprintf("  endpoint: %.1f%%   max: %.1f%% of LOS\n",
                x$endpoint_pct, x$max_pct))
  }
  cat(sprintf("  directional control: %.1f%%\n", x$directional_control))
  invisible(x)
}
