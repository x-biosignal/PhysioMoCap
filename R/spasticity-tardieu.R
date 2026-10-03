# Instrumented spasticity measurement (Tardieu Scale). Spasticity is a
# velocity-dependent stretch reflex: a fast passive stretch triggers a "catch"
# (a reflexive EMG burst and an arrest of the joint motion) at an angle R1, while
# a slow stretch reaches the full passive range R2; the dynamic component R2-R1
# quantifies the velocity-dependent (spastic) part, separating it from a fixed
# contracture. These functions locate the catch on a joint-angle trace (from an
# EMG burst and/or a velocity arrest) and derive R1, R2 and R2-R1, reusing the
# package's angular-velocity, EMG-alignment and envelope primitives.

# Central-difference angular velocity, length-preserving (reuses differentiate()
# when it aligns; otherwise an explicit central difference).
.tardieu_velocity <- function(angle, dt) {
  n <- length(angle)
  v <- tryCatch(as.numeric(differentiate(angle, dt = dt, method = "central")),
                error = function(e) NULL)
  if (is.null(v) || length(v) != n) {
    v <- c((angle[2] - angle[1]) / dt,
           (angle[seq.int(3, n)] - angle[seq.int(1, n - 2)]) / (2 * dt),
           (angle[n] - angle[n - 1]) / dt)
  }
  v
}

#' Detect the spastic catch on a single passive stretch
#'
#' Locates the Tardieu "catch" on one passive-stretch joint-angle trace and
#' returns the catch angle (R1). The catch is detected from a reflex EMG burst
#' (envelope crossing a baseline mean + `threshold_sd` * SD threshold), from a
#' velocity arrest (angular velocity dropping below `catch_fraction` of its peak
#' after the fastest stretch), or from both.
#'
#' @param angle Numeric joint-angle trace over the stretch (degrees; increasing
#'   as the joint is stretched).
#' @param emg Optional EMG of the stretched muscle (numeric); enables the EMG
#'   reflex-onset trigger.
#' @param sampling_rate Angle sampling rate (Hz).
#' @param emg_sampling_rate EMG sampling rate (Hz); the EMG is resampled onto the
#'   angle time base with [alignEMGtoMoCap()]. Default = `sampling_rate`.
#' @param onset Catch trigger: `"emg"`, `"velocity"` or `"both"` (EMG-preferred,
#'   velocity fallback).
#' @param baseline_sec Baseline window (s) for the EMG threshold (default 0.5).
#' @param threshold_sd EMG onset threshold in baseline SDs (default 3).
#' @param catch_fraction Velocity-arrest fraction of peak velocity (default 0.5).
#' @param envelope_ms EMG RMS-envelope window in ms (default 50).
#' @return An S3 `tardieu_stretch` list: `catch_angle` (R1), `catch_index`,
#'   `catch_velocity`, `peak_velocity`, `rom_max`/`rom_min`, `reflex_latency_ms`
#'   (EMG onset relative to stretch onset), `onset_method`.
#' @seealso [tardieuScore()], [reflexThreshold()]
#' @export
#' @examples
#' fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
#' angle <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
#' tardieuStretch(angle, sampling_rate = fs, onset = "velocity")$catch_angle
tardieuStretch <- function(angle, emg = NULL, sampling_rate,
                           emg_sampling_rate = sampling_rate,
                           onset = c("emg", "velocity", "both"),
                           baseline_sec = 0.5, threshold_sd = 3,
                           catch_fraction = 0.5, envelope_ms = 50) {
  onset <- match.arg(onset)
  angle <- as.numeric(angle)
  n <- length(angle)
  stopifnot(n >= 4L, is.numeric(sampling_rate), sampling_rate > 0)
  if (onset %in% c("emg", "both") && is.null(emg)) {
    if (onset == "emg") stop("onset = 'emg' needs an 'emg' signal.", call. = FALSE)
    onset <- "velocity"                       # 'both' with no EMG -> velocity
  }
  dt <- 1 / sampling_rate
  vel <- .tardieu_velocity(angle, dt)
  peak_velocity <- max(vel, na.rm = TRUE)
  peak_idx <- which.max(vel)
  stretch_onset <- {
    wi <- which(vel > 0.05 * peak_velocity)
    if (length(wi)) wi[1] else 1L
  }

  emg_catch <- NA_integer_; emg_latency_ms <- NA_real_
  if (!is.null(emg) && onset %in% c("emg", "both")) {
    emg <- as.numeric(emg)
    emg_a <- if (length(emg) != n) {
      alignEMGtoMoCap(emg, emg_sampling_rate, mocap_length = n,
                      mocap_sampling_rate = sampling_rate)
    } else emg
    win <- max(1L, round(envelope_ms / 1000 * sampling_rate))
    env <- as.numeric(computeRMSEnvelope(rectifyEMG(as.numeric(emg_a)),
                                         window_samples = win))
    base_n <- max(2L, min(n - 1L, round(baseline_sec * sampling_rate)))
    thr <- mean(env[seq_len(base_n)]) +
      threshold_sd * stats::sd(env[seq_len(base_n)])
    cross <- which(seq_len(n) > base_n & env > thr)
    if (length(cross)) {
      emg_catch <- cross[1]
      emg_latency_ms <- (emg_catch - stretch_onset) / sampling_rate * 1000
    }
  }

  vel_catch <- NA_integer_
  if (onset %in% c("velocity", "both")) {
    after <- which(seq_len(n) > peak_idx & vel < catch_fraction * peak_velocity)
    if (length(after)) vel_catch <- after[1]
  }

  catch_idx <- switch(onset, emg = emg_catch, velocity = vel_catch,
                      both = if (!is.na(emg_catch)) emg_catch else vel_catch)
  if (is.na(catch_idx)) catch_idx <- which.max(angle)  # no catch = full ROM

  structure(list(
    catch_angle = angle[catch_idx], catch_index = as.integer(catch_idx),
    catch_velocity = vel[catch_idx], peak_velocity = peak_velocity,
    rom_max = max(angle), rom_min = min(angle),
    reflex_latency_ms = emg_latency_ms, onset_method = onset,
    sampling_rate = sampling_rate), class = "tardieu_stretch")
}

#' Tardieu score: R1, R2 and the dynamic component
#'
#' Combines a fast-velocity stretch (the catch angle R1) and a slow-velocity
#' stretch (the full passive range R2) into the Tardieu dynamic component
#' `R2 - R1` - the velocity-dependent (spastic) part of the range, distinct from
#' a fixed contracture.
#'
#' @param fast A [tardieuStretch()] result (fast stretch), or a raw fast-stretch
#'   angle trace (then scored with `onset = "velocity"`).
#' @param slow A [tardieuStretch()] result or a raw slow-stretch angle trace; R2
#'   is its end-range angle (`rom_max` / `max(angle)`).
#' @param sampling_rate Required only when `fast` is a raw angle trace.
#' @param ... Passed to [tardieuStretch()] when `fast` is raw.
#' @return An S3 `tardieu_score` list: `R1`, `R2`, `dynamic_component`.
#' @seealso [tardieuStretch()], [reflexThreshold()]
#' @export
#' @examples
#' fs <- 200; t <- seq(0, 0.6, by = 1 / fs)
#' fast <- ifelse(t <= 0.25, 25 * t / 0.25, 25 + 5 * (t - 0.25) / 0.35)
#' slow <- 40 * t / 0.6
#' tardieuScore(tardieuStretch(fast, sampling_rate = fs, onset = "velocity"), slow)
tardieuScore <- function(fast, slow, sampling_rate = NULL, ...) {
  R1 <- if (inherits(fast, "tardieu_stretch")) {
    fast$catch_angle
  } else {
    if (is.null(sampling_rate)) {
      stop("'sampling_rate' is required when 'fast' is a raw angle trace.",
           call. = FALSE)
    }
    tardieuStretch(fast, sampling_rate = sampling_rate, onset = "velocity",
                   ...)$catch_angle
  }
  R2 <- if (inherits(slow, "tardieu_stretch")) slow$rom_max else max(as.numeric(slow))
  structure(list(R1 = R1, R2 = R2, dynamic_component = R2 - R1),
            class = "tardieu_score")
}

#' Velocity-dependent reflex threshold
#'
#' Regresses the catch angle against the peak stretch velocity across a series of
#' passive stretches at varying velocities. A negative slope is the signature of
#' velocity-dependent spasticity (the catch occurs earlier - at a smaller angle -
#' as the stretch gets faster).
#'
#' @param stretches A list of [tardieuStretch()] results (>= 2), one per stretch.
#' @return An S3 `reflex_threshold` list: `slope` (deg per deg/s), `intercept`,
#'   `catch_angles`, `peak_velocities` and the linear `model`.
#' @seealso [tardieuStretch()], [tardieuScore()]
#' @export
#' @examples
#' fs <- 200
#' mk <- function(catch, rise, total = 0.8) {
#'   t <- seq(0, total, by = 1 / fs)
#'   ifelse(t <= rise, catch * t / rise, catch + 8 * (t - rise) / (total - rise))
#' }
#' st <- lapply(list(c(30, .5), c(20, .25), c(15, .13)),
#'              function(p) tardieuStretch(mk(p[1], p[2]), sampling_rate = fs,
#'                                         onset = "velocity"))
#' reflexThreshold(st)$slope
reflexThreshold <- function(stretches) {
  if (!length(stretches) || length(stretches) < 2L ||
      !all(vapply(stretches, inherits, logical(1), "tardieu_stretch"))) {
    stop("'stretches' must be a list of >= 2 tardieu_stretch objects.",
         call. = FALSE)
  }
  ca <- vapply(stretches, `[[`, numeric(1), "catch_angle")
  pv <- vapply(stretches, `[[`, numeric(1), "peak_velocity")
  fit <- stats::lm(ca ~ pv)
  co <- stats::coef(fit)
  structure(list(slope = unname(co[2L]), intercept = unname(co[1L]),
                 catch_angles = ca, peak_velocities = pv, model = fit),
            class = "reflex_threshold")
}

#' @export
print.tardieu_stretch <- function(x, ...) {
  cat(sprintf("Tardieu stretch (onset = %s)\n", x$onset_method))
  cat(sprintf("  catch angle R1 : %.1f deg  (peak velocity %.1f deg/s)\n",
              x$catch_angle, x$peak_velocity))
  if (!is.na(x$reflex_latency_ms)) {
    cat(sprintf("  reflex latency : %.0f ms\n", x$reflex_latency_ms))
  }
  invisible(x)
}

#' @export
print.tardieu_score <- function(x, ...) {
  cat(sprintf("Tardieu score: R1 = %.1f deg, R2 = %.1f deg, dynamic (R2-R1) = %.1f deg\n",
              x$R1, x$R2, x$dynamic_component))
  invisible(x)
}

#' @export
print.reflex_threshold <- function(x, ...) {
  cat(sprintf("Velocity-dependent reflex threshold: slope = %.4f deg per deg/s\n",
              x$slope))
  cat(sprintf("  catch angle = %.1f + %.4f * peak_velocity\n",
              x$intercept, x$slope))
  invisible(x)
}
