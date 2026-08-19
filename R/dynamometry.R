# Strength and dynamometry analysis

#' Validate a numeric dynamometry trace
#' @keywords internal
#' @noRd
.dyn_trace <- function(x, name, min_length = 1L) {
  if (!is.numeric(x) || !is.null(dim(x)) || length(x) < min_length) {
    stop(sprintf("%s must be a numeric vector with at least %d sample(s).",
                 name, min_length), call. = FALSE)
  }
  if (any(!is.finite(x))) {
    stop(sprintf("%s must contain only finite values.", name), call. = FALSE)
  }
  as.numeric(x)
}


#' Validate a finite scalar
#' @keywords internal
#' @noRd
.dyn_scalar <- function(x, name, lower = -Inf, inclusive = FALSE) {
  valid <- is.numeric(x) && length(x) == 1L && is.finite(x)
  if (valid) {
    valid <- if (inclusive) x >= lower else x > lower
  }
  if (!valid) {
    relation <- if (inclusive) "at least" else "greater than"
    stop(sprintf("%s must be a finite number %s %s.",
                 name, relation, format(lower)), call. = FALSE)
  }
  as.numeric(x)
}


#' Validate an explicit onset sample
#' @keywords internal
#' @noRd
.dyn_onset_index <- function(onset, n) {
  if (!is.numeric(onset) || length(onset) != 1L || !is.finite(onset) ||
      onset != floor(onset) || onset < 1 || onset > n) {
    stop("onset must be a 1-based integer sample index within torque.",
         call. = FALSE)
  }
  as.integer(onset)
}


#' Detect torque onset
#'
#' The absolute method uses a fixed torque increase above the baseline mean.
#' The SD method uses the baseline mean plus a multiple of its standard
#' deviation.
#'
#' @keywords internal
#' @noRd
.torque_onset <- function(torque,
                          sampling_rate,
                          method = c("absolute", "sd"),
                          threshold = 7.5,
                          baseline_ms = 100,
                          sd_k = 5) {
  method <- match.arg(method)
  torque <- .dyn_trace(torque, "torque")
  sampling_rate <- .dyn_scalar(sampling_rate, "sampling_rate", 0)
  threshold <- .dyn_scalar(threshold, "onset_threshold", 0, inclusive = TRUE)
  baseline_ms <- .dyn_scalar(baseline_ms, "baseline_ms", 0)
  sd_k <- .dyn_scalar(sd_k, "baseline_sd_k", 0, inclusive = TRUE)

  n_base <- as.integer(round(baseline_ms / 1000 * sampling_rate))
  n_base <- min(length(torque), max(1L, n_base))
  baseline <- torque[seq_len(n_base)]
  baseline_mean <- mean(baseline)
  baseline_sd <- if (n_base > 1L) stats::sd(baseline) else 0
  level <- if (method == "absolute") {
    baseline_mean + threshold
  } else {
    baseline_mean + sd_k * baseline_sd
  }

  onset <- which(torque > level)[1L]
  if (is.na(onset)) {
    stop(sprintf("No contraction onset detected above %.3f N m.", level),
         call. = FALSE)
  }
  as.integer(onset)
}


#' Peak torque from isometric or isokinetic dynamometry
#'
#' Finds the maximum gravity-corrected torque. For isokinetic trials with an
#' angular-velocity trace, the search is restricted to samples within
#' `velocity_tol` of the target velocity so acceleration and deceleration
#' transients do not determine the peak.
#'
#' @param torque Numeric torque trace in N m.
#' @param sampling_rate Sampling rate in Hz.
#' @param mode Either `"isokinetic"` or `"isometric"`.
#' @param angle Optional joint-angle trace in degrees.
#' @param angular_velocity Optional angular-velocity trace in degrees/s.
#' @param target_velocity Optional target angular velocity in degrees/s. The
#'   largest observed absolute velocity is used when omitted.
#' @param velocity_tol Non-negative relative tolerance around target velocity.
#' @param at_angle Optional angles in degrees at which torque is interpolated
#'   along the rising angular limb.
#' @param gravity Optional scalar or sample-wise gravity torque in N m to
#'   subtract before analysis.
#'
#' @return A `peak_torque` object containing the peak value, time, sample,
#'   angle, angle-specific values, mode, and searched sample indices.
#'
#' @references
#' Aagaard P, Simonsen EB, Andersen JL, Magnusson P, Dyhre-Poulsen P (2002).
#' Increased rate of force development and neural drive of human skeletal
#' muscle following resistance training. *Journal of Applied Physiology*,
#' 93:1318-1326. \doi{10.1152/japplphysiol.00283.2002}
#'
#' @export
#'
#' @examples
#' torque <- c(seq(0, 120, length.out = 101), rep(120, 50))
#' peakTorque(torque, sampling_rate = 100, mode = "isometric")
peakTorque <- function(torque,
                       sampling_rate,
                       mode = c("isokinetic", "isometric"),
                       angle = NULL,
                       angular_velocity = NULL,
                       target_velocity = NULL,
                       velocity_tol = 0.10,
                       at_angle = NULL,
                       gravity = NULL) {
  mode <- match.arg(mode)
  torque <- .dyn_trace(torque, "torque")
  sampling_rate <- .dyn_scalar(sampling_rate, "sampling_rate", 0)
  velocity_tol <- .dyn_scalar(velocity_tol, "velocity_tol", 0, inclusive = TRUE)
  n <- length(torque)

  if (!is.null(angle)) {
    angle <- .dyn_trace(angle, "angle")
    if (length(angle) != n) {
      stop("angle must have the same length as torque.", call. = FALSE)
    }
  }
  if (!is.null(angular_velocity)) {
    angular_velocity <- .dyn_trace(angular_velocity, "angular_velocity")
    if (length(angular_velocity) != n) {
      stop("angular_velocity must have the same length as torque.",
           call. = FALSE)
    }
  }
  if (!is.null(target_velocity)) {
    if (!is.numeric(target_velocity) || length(target_velocity) != 1L ||
        !is.finite(target_velocity) || target_velocity == 0) {
      stop("target_velocity must be a finite non-zero number.", call. = FALSE)
    }
    target_velocity <- as.numeric(target_velocity)
  }
  if (!is.null(at_angle)) {
    at_angle <- .dyn_trace(at_angle, "at_angle", min_length = 0L)
    if (is.null(angle)) {
      stop("angle must be supplied when at_angle is requested.", call. = FALSE)
    }
  }

  if (is.null(gravity)) {
    corrected <- torque
  } else {
    gravity <- .dyn_trace(gravity, "gravity")
    if (!length(gravity) %in% c(1L, n)) {
      stop("gravity must be a scalar or have the same length as torque.",
           call. = FALSE)
    }
    corrected <- torque - gravity
  }

  window <- seq_len(n)
  if (mode == "isokinetic" && !is.null(angular_velocity)) {
    target <- if (is.null(target_velocity)) {
      max(abs(angular_velocity))
    } else {
      abs(target_velocity)
    }
    if (target > 0) {
      candidate <- which(
        abs(abs(angular_velocity) - target) <= velocity_tol * target
      )
      if (length(candidate) >= 2L) {
        window <- candidate
      } else {
        warning("Fewer than two constant-velocity samples; using full trace.",
                call. = FALSE)
      }
    } else {
      warning("Angular velocity is zero throughout; using full trace.",
              call. = FALSE)
    }
  }

  peak_index <- window[which.max(corrected[window])]
  angle_specific <- NULL
  if (!is.null(at_angle)) {
    i_min <- which.min(angle)
    i_max <- which.max(angle)
    limb <- seq.int(i_min, i_max)
    x <- angle[limb]
    y <- corrected[limb]
    ord <- order(x)
    x <- x[ord]
    y <- y[ord]
    keep <- !duplicated(x)
    x <- x[keep]
    y <- y[keep]
    if (length(x) < 2L) {
      stop("angle must span at least two unique values for interpolation.",
           call. = FALSE)
    }
    if (any(at_angle < min(x) | at_angle > max(x))) {
      warning("at_angle lies outside the tested rising-limb range; values are clamped.",
              call. = FALSE)
    }
    angle_specific <- stats::approx(
      x = x, y = y, xout = at_angle, rule = 2, ties = "ordered"
    )$y
    names(angle_specific) <- format(at_angle, trim = TRUE)
  }

  out <- list(
    peak = corrected[peak_index],
    peak_time = (peak_index - 1L) / sampling_rate,
    peak_index = as.integer(peak_index),
    peak_angle = if (is.null(angle)) NA_real_ else angle[peak_index],
    angle_specific = angle_specific,
    mode = mode,
    window = as.integer(window)
  )
  class(out) <- "peak_torque"
  out
}


#' @export
print.peak_torque <- function(x, ...) {
  cat(sprintf("<peak_torque> %.3f N m at %.3f s (sample %d)\n",
              x$peak, x$peak_time, x$peak_index))
  if (is.finite(x$peak_angle)) {
    cat(sprintf("  angle: %.2f deg\n", x$peak_angle))
  }
  invisible(x)
}


#' Rate of force development
#'
#' Computes sequential interval RFD from contraction onset and the maximum
#' moving-window slope. RFD is expressed in N m/s.
#'
#' @param torque Numeric torque trace in N m.
#' @param sampling_rate Sampling rate in Hz.
#' @param onset Optional 1-based integer onset sample. When `NULL`, onset is
#'   detected from the baseline.
#' @param onset_method Either a fixed `"absolute"` increase above baseline or
#'   a baseline `"sd"` rule.
#' @param onset_threshold Absolute onset threshold in N m above baseline.
#' @param baseline_ms Baseline duration in milliseconds.
#' @param baseline_sd_k Number of baseline SDs used by the `"sd"` method.
#' @param windows_ms Positive interval widths in milliseconds.
#' @param peak_window_ms Positive moving-window width in milliseconds.
#'
#' @return An `rfd` object containing onset details, interval RFD values, and
#'   peak moving-window RFD.
#'
#' @references
#' Aagaard P, Simonsen EB, Andersen JL, Magnusson P, Dyhre-Poulsen P (2002).
#' Increased rate of force development and neural drive of human skeletal
#' muscle following resistance training. *Journal of Applied Physiology*,
#' 93:1318-1326. \doi{10.1152/japplphysiol.00283.2002}
#'
#' Maffiuletti NA, Aagaard P, Blazevich AJ, Folland J, Tillin N, Duchateau J
#' (2016). Rate of force development: physiological and methodological
#' considerations. *European Journal of Applied Physiology*, 116:1091-1116.
#' \doi{10.1007/s00421-016-3346-6}
#'
#' @export
#'
#' @examples
#' torque <- c(rep(0, 100), seq(0.4, 120, by = 0.4), rep(120, 100))
#' rateOfForceDevelopment(torque, sampling_rate = 1000, onset_method = "sd")
rateOfForceDevelopment <- function(torque,
                                   sampling_rate,
                                   onset = NULL,
                                   onset_method = c("absolute", "sd"),
                                   onset_threshold = 7.5,
                                   baseline_ms = 100,
                                   baseline_sd_k = 5,
                                   windows_ms = c(50, 100, 200),
                                   peak_window_ms = 20) {
  onset_method <- match.arg(onset_method)
  torque <- .dyn_trace(torque, "torque")
  sampling_rate <- .dyn_scalar(sampling_rate, "sampling_rate", 0)
  onset_threshold <- .dyn_scalar(
    onset_threshold, "onset_threshold", 0, inclusive = TRUE
  )
  baseline_ms <- .dyn_scalar(baseline_ms, "baseline_ms", 0)
  baseline_sd_k <- .dyn_scalar(
    baseline_sd_k, "baseline_sd_k", 0, inclusive = TRUE
  )
  windows_ms <- .dyn_trace(windows_ms, "windows_ms")
  if (any(windows_ms <= 0)) {
    stop("windows_ms must contain only positive values.", call. = FALSE)
  }
  peak_window_ms <- .dyn_scalar(peak_window_ms, "peak_window_ms", 0)

  onset_index <- if (is.null(onset)) {
    .torque_onset(
      torque, sampling_rate, onset_method, onset_threshold,
      baseline_ms, baseline_sd_k
    )
  } else {
    .dyn_onset_index(onset, length(torque))
  }
  onset_torque <- torque[onset_index]

  offsets <- as.integer(round(windows_ms / 1000 * sampling_rate))
  if (any(offsets < 1L)) {
    stop("Each windows_ms value must span at least one sample.",
         call. = FALSE)
  }
  end_indices <- onset_index + offsets
  in_range <- end_indices <= length(torque)
  delta_torque <- rep(NA_real_, length(windows_ms))
  delta_torque[in_range] <- torque[end_indices[in_range]] - onset_torque
  interval_rfd <- delta_torque / (windows_ms / 1000)

  windows <- data.frame(
    window_ms = windows_ms,
    end_index = as.integer(end_indices),
    delta_torque = delta_torque,
    rfd = interval_rfd,
    stringsAsFactors = FALSE
  )

  peak_width <- max(
    1L, as.integer(round(peak_window_ms / 1000 * sampling_rate))
  )
  if (length(torque) - onset_index < peak_width) {
    warning("Torque trace is too short for the requested peak RFD window.",
            call. = FALSE)
    peak_rfd <- NA_real_
    peak_rfd_time <- NA_real_
  } else {
    starts <- seq.int(onset_index, length(torque) - peak_width)
    slopes <- (
      torque[starts + peak_width] - torque[starts]
    ) / (peak_width / sampling_rate)
    winner <- which.max(slopes)
    peak_rfd <- slopes[winner]
    peak_rfd_time <- (
      starts[winner] - 1 + peak_width / 2
    ) / sampling_rate
  }

  out <- list(
    onset_index = onset_index,
    onset_time = (onset_index - 1L) / sampling_rate,
    onset_torque = onset_torque,
    windows = windows,
    peak_rfd = peak_rfd,
    peak_rfd_time = peak_rfd_time,
    peak_window_ms = peak_window_ms
  )
  class(out) <- "rfd"
  out
}


#' @export
print.rfd <- function(x, ...) {
  cat(sprintf("<rfd> onset %.3f s (sample %d)\n",
              x$onset_time, x$onset_index))
  for (i in seq_len(nrow(x$windows))) {
    cat(sprintf("  0-%g ms: %s N m/s\n",
                x$windows$window_ms[i],
                if (is.na(x$windows$rfd[i])) {
                  "NA"
                } else {
                  sprintf("%.3f", x$windows$rfd[i])
                }))
  }
  cat(sprintf("  peak (%g ms): %s N m/s\n",
              x$peak_window_ms,
              if (is.na(x$peak_rfd)) "NA" else sprintf("%.3f", x$peak_rfd)))
  invisible(x)
}


#' Time to peak torque
#'
#' @inheritParams rateOfForceDevelopment
#'
#' @return A named list containing time from onset, time from trace start, peak
#'   and onset indices, and peak torque.
#'
#' @export
#'
#' @examples
#' torque <- c(rep(0, 100), seq(0.4, 120, by = 0.4), rep(120, 100))
#' timeToPeakTorque(torque, sampling_rate = 1000, onset_method = "sd")
timeToPeakTorque <- function(torque,
                             sampling_rate,
                             onset = NULL,
                             onset_method = c("absolute", "sd"),
                             onset_threshold = 7.5,
                             baseline_ms = 100,
                             baseline_sd_k = 5) {
  onset_method <- match.arg(onset_method)
  torque <- .dyn_trace(torque, "torque")
  sampling_rate <- .dyn_scalar(sampling_rate, "sampling_rate", 0)
  onset_threshold <- .dyn_scalar(
    onset_threshold, "onset_threshold", 0, inclusive = TRUE
  )
  baseline_ms <- .dyn_scalar(baseline_ms, "baseline_ms", 0)
  baseline_sd_k <- .dyn_scalar(
    baseline_sd_k, "baseline_sd_k", 0, inclusive = TRUE
  )

  onset_index <- if (is.null(onset)) {
    .torque_onset(
      torque, sampling_rate, onset_method, onset_threshold,
      baseline_ms, baseline_sd_k
    )
  } else {
    .dyn_onset_index(onset, length(torque))
  }
  peak_index <- which.max(torque)

  list(
    time_from_onset = (peak_index - onset_index) / sampling_rate,
    time_from_start = (peak_index - 1L) / sampling_rate,
    peak_index = as.integer(peak_index),
    onset_index = onset_index,
    peak = torque[peak_index]
  )
}


#' Angular work and impulse for strength-test repetitions
#'
#' Integrates torque over time to obtain angular impulse and, when angle or
#' angular velocity is available, integrates torque over angular displacement
#' to obtain mechanical work.
#'
#' @param torque Numeric torque trace in N m.
#' @param sampling_rate Sampling rate in Hz.
#' @param angle Optional angle trace in degrees.
#' @param angular_velocity Optional angular-velocity trace in degrees/s, used
#'   when `angle` is not supplied.
#' @param reps Optional named list of strictly increasing integer sample-index
#'   vectors. When `NULL`, repetitions are segmented with [computeImpulse()].
#' @param onset_threshold Non-negative torque threshold used for automatic
#'   repetition segmentation.
#' @param body_mass Optional positive body mass in kg.
#'
#' @return A `contraction_work` data frame with angular impulse (N m s), work
#'   (J), and optional mass-normalised values for each repetition.
#'
#' @references
#' Winter DA (2009). *Biomechanics and Motor Control of Human Movement*.
#' 4th ed. John Wiley & Sons.
#'
#' @export
#'
#' @examples
#' torque <- c(seq(0, 100, length.out = 51), seq(98, 0, length.out = 50))
#' contractionWork(torque, sampling_rate = 100,
#'                 reps = list(rep1 = seq_along(torque)))
contractionWork <- function(torque,
                            sampling_rate,
                            angle = NULL,
                            angular_velocity = NULL,
                            reps = NULL,
                            onset_threshold = 7.5,
                            body_mass = NULL) {
  torque <- .dyn_trace(torque, "torque")
  sampling_rate <- .dyn_scalar(sampling_rate, "sampling_rate", 0)
  onset_threshold <- .dyn_scalar(
    onset_threshold, "onset_threshold", 0, inclusive = TRUE
  )
  n <- length(torque)

  if (!is.null(angle)) {
    angle <- .dyn_trace(angle, "angle")
    if (length(angle) != n) {
      stop("angle must have the same length as torque.", call. = FALSE)
    }
  }
  if (!is.null(angular_velocity)) {
    angular_velocity <- .dyn_trace(angular_velocity, "angular_velocity")
    if (length(angular_velocity) != n) {
      stop("angular_velocity must have the same length as torque.",
           call. = FALSE)
    }
  }
  if (!is.null(body_mass)) {
    body_mass <- .dyn_scalar(body_mass, "body_mass", 0)
  }

  if (is.null(reps)) {
    contacts <- computeImpulse(
      pmax(torque, 0), sampling_rate = sampling_rate,
      threshold = onset_threshold
    )
    if (nrow(contacts) == 0L) {
      reps <- list(rep1 = seq_len(n))
    } else {
      reps <- Map(seq.int, contacts$onset, contacts$offset)
      names(reps) <- paste0("rep", seq_along(reps))
    }
  }

  if (!is.list(reps) || is.null(names(reps)) ||
      anyNA(names(reps)) || any(names(reps) == "") ||
      anyDuplicated(names(reps))) {
    stop("reps must be a named list with unique, non-empty names.",
         call. = FALSE)
  }
  if (length(reps) == 0L) {
    stop("reps must contain at least one repetition.", call. = FALSE)
  }

  validated_reps <- lapply(names(reps), function(name) {
    idx <- reps[[name]]
    if (!is.numeric(idx) || length(idx) == 0L || any(!is.finite(idx)) ||
        any(idx != floor(idx)) || any(idx < 1) || any(idx > n)) {
      stop(sprintf("Repetition '%s' must contain in-range integer indices.",
                   name), call. = FALSE)
    }
    idx <- as.integer(idx)
    if (is.unsorted(idx, strictly = TRUE)) {
      stop(sprintf("Repetition '%s' indices must be strictly increasing.",
                   name), call. = FALSE)
    }
    idx
  })
  names(validated_reps) <- names(reps)

  dt <- 1 / sampling_rate
  rows <- lapply(names(validated_reps), function(name) {
    idx <- validated_reps[[name]]
    moment <- torque[idx]
    nr <- length(idx)
    sample_steps <- diff(idx)
    angular_impulse <- if (nr < 2L) {
      0
    } else if (all(sample_steps == 1L)) {
      .trapz(moment, dt)
    } else {
      sum(0.5 * (moment[-1L] + moment[-nr]) *
            sample_steps / sampling_rate)
    }

    if (!is.null(angle)) {
      theta <- angle[idx] * pi / 180
      work <- if (nr < 2L) {
        0
      } else {
        sum(0.5 * (moment[-1L] + moment[-nr]) * diff(theta))
      }
    } else if (!is.null(angular_velocity)) {
      omega <- angular_velocity[idx] * pi / 180
      power <- moment * omega
      work <- if (nr < 2L) {
        0
      } else if (all(sample_steps == 1L)) {
        .trapz(power, dt)
      } else {
        sum(0.5 * (power[-1L] + power[-nr]) *
              sample_steps / sampling_rate)
      }
    } else {
      work <- NA_real_
    }

    data.frame(
      rep = name,
      onset_index = idx[1L],
      offset_index = idx[length(idx)],
      angular_impulse = angular_impulse,
      work = work,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL

  if (!is.null(body_mass)) {
    out$angular_impulse_per_kg <- out$angular_impulse / body_mass
    out$work_per_kg <- out$work / body_mass
  }
  attr(out, "sampling_rate") <- sampling_rate
  attr(out, "body_mass") <- body_mass
  class(out) <- c("contraction_work", "data.frame")
  out
}


#' @export
print.contraction_work <- function(x, ...) {
  cat(sprintf("<contraction_work> %d repetition(s) at %g Hz\n",
              nrow(x), attr(x, "sampling_rate")))
  print.data.frame(x, row.names = FALSE)
  invisible(x)
}


#' Conventional and functional hamstring-to-quadriceps ratios
#'
#' Computes the conventional concentric H:Q ratio and a functional ratio that
#' compares eccentric antagonist torque with concentric agonist torque.
#' Optional EMG traces are processed with [processEMG()] and summarised as the
#' hamstring-to-quadriceps mean-envelope ratio.
#'
#' @param quad_con Concentric quadriceps peak torque or torque trace.
#' @param ham_con Concentric hamstring peak torque or torque trace.
#' @param ham_ecc Optional eccentric hamstring peak torque or torque trace.
#' @param quad_ecc Optional eccentric quadriceps peak torque or torque trace.
#' @param movement Movement direction, `"extension"` or `"flexion"`.
#' @param emg_ham,emg_quad Optional hamstring and quadriceps EMG traces. Supply
#'   both or neither.
#' @param emg_sampling_rate EMG sampling rate in Hz, required with EMG traces.
#'
#' @return An `hq_ratio` object containing conventional and functional ratios,
#'   peak torques, movement direction, and optional EMG ratio.
#'
#' @references
#' Coombs R, Garbutt G (2002). Developments in the use of the hamstring/
#' quadriceps ratio for the assessment of muscle balance. *Journal of Sports
#' Science and Medicine*, 1:56-62.
#'
#' Aagaard P, Simonsen EB, Magnusson SP, Larsson B, Dyhre-Poulsen P (1998).
#' A new concept for isokinetic hamstring:quadriceps muscle strength ratio.
#' *American Journal of Sports Medicine*, 26:231-237.
#' \doi{10.1177/03635465980260021201}
#'
#' @export
#'
#' @examples
#' hamstringQuadRatio(quad_con = 200, ham_con = 120, ham_ecc = 150)
hamstringQuadRatio <- function(quad_con,
                               ham_con,
                               ham_ecc = NULL,
                               quad_ecc = NULL,
                               movement = c("extension", "flexion"),
                               emg_ham = NULL,
                               emg_quad = NULL,
                               emg_sampling_rate = NULL) {
  movement <- match.arg(movement)
  peak_of <- function(x, name) {
    x <- .dyn_trace(x, name)
    max(x)
  }

  quad_con_peak <- peak_of(quad_con, "quad_con")
  ham_con_peak <- peak_of(ham_con, "ham_con")
  ham_ecc_peak <- if (is.null(ham_ecc)) {
    NA_real_
  } else {
    peak_of(ham_ecc, "ham_ecc")
  }
  quad_ecc_peak <- if (is.null(quad_ecc)) {
    NA_real_
  } else {
    peak_of(quad_ecc, "quad_ecc")
  }

  if (quad_con_peak <= 0) {
    stop("Quadriceps peak torque must be positive.", call. = FALSE)
  }
  conventional <- ham_con_peak / quad_con_peak
  functional <- if (movement == "extension") {
    if (is.na(ham_ecc_peak)) NA_real_ else ham_ecc_peak / quad_con_peak
  } else {
    if (is.na(quad_ecc_peak)) {
      NA_real_
    } else {
      if (quad_ecc_peak <= 0) {
        stop("Eccentric quadriceps peak torque must be positive.",
             call. = FALSE)
      }
      ham_con_peak / quad_ecc_peak
    }
  }

  emg_supplied <- c(!is.null(emg_ham), !is.null(emg_quad))
  if (xor(emg_supplied[1L], emg_supplied[2L])) {
    stop("emg_ham and emg_quad must be supplied together.", call. = FALSE)
  }
  emg_ratio <- NULL
  if (all(emg_supplied)) {
    emg_ham <- .dyn_trace(emg_ham, "emg_ham")
    emg_quad <- .dyn_trace(emg_quad, "emg_quad")
    emg_sampling_rate <- .dyn_scalar(
      emg_sampling_rate, "emg_sampling_rate", 0
    )
    ham_envelope <- processEMG(
      emg_ham, emg_sampling_rate
    )$envelope
    quad_envelope <- processEMG(
      emg_quad, emg_sampling_rate
    )$envelope
    numerator <- mean(ham_envelope)
    denominator <- mean(quad_envelope)
    if (!is.finite(numerator) || numerator < 0) {
      stop("Hamstring EMG envelope mean must be finite and non-negative.",
           call. = FALSE)
    }
    if (!is.finite(denominator) || denominator <= 0) {
      stop("Quadriceps EMG envelope mean must be positive.", call. = FALSE)
    }
    emg_ratio <- numerator / denominator
  }

  out <- list(
    conventional = conventional,
    functional = functional,
    movement = movement,
    peaks = c(
      quad_con = quad_con_peak,
      ham_con = ham_con_peak,
      ham_ecc = ham_ecc_peak,
      quad_ecc = quad_ecc_peak
    ),
    emg_ratio = emg_ratio
  )
  class(out) <- "hq_ratio"
  out
}


#' @export
print.hq_ratio <- function(x, ...) {
  cat(sprintf("<hq_ratio> conventional H:Q %.3f\n", x$conventional))
  cat(sprintf("  functional (%s): %s\n", x$movement,
              if (is.na(x$functional)) "NA" else sprintf("%.3f", x$functional)))
  if (!is.null(x$emg_ratio)) {
    cat(sprintf("  EMG envelope H:Q: %.3f\n", x$emg_ratio))
  }
  invisible(x)
}
