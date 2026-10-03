# Upper-limb ADL task assessment from reach kinematics.
#
# Reaching to a cup, to the mouth with a spoon, to an armhole -- the goal-directed
# arm transports that underlie the self-care ADLs -- are assessed by the SAME
# reach-kinematics the package already computes (movement time, peak velocity,
# time-to-peak, submovement count, SPARC / LDLJ smoothness). This wraps those
# low-level metrics as a named ADL task (drinking, feeding, dressing, grooming),
# attaching the ICF Activities & Participation code the task realises so the
# result plugs into the cross-modal ICF construct. A single smooth transport is
# one movement unit with a high (near-zero) SPARC; impaired reaches fragment into
# several submovements with a more negative SPARC.

.adl_reach_icf <- function(task) {
  c(reaching = "d445", drinking = "d560", feeding = "d550",
    dressing = "d540", grooming = "d520")[[task]]
}

#' Assess an upper-limb ADL reach from its speed profile
#'
#' Computes the standard reach-to-grasp kinematics for one ADL arm transport and
#' labels it with the ADL task and its ICF code. Works directly on the
#' end-effector (hand) speed profile, so it needs no full marker set; derive the
#' speed from a trajectory with [computeSpeed()] or pass a hand-sensor speed.
#'
#' @param speed Numeric hand/end-effector speed profile (one reach).
#' @param sampling_rate Sampling rate in Hz.
#' @param task ADL task: `"reaching"` (default, generic hand-arm use, d445),
#'   `"drinking"` (d560), `"feeding"` (eating, d550), `"dressing"` (d540) or
#'   `"grooming"` (d520).
#' @param onset_threshold Movement-onset threshold (fraction of peak speed).
#' @return an `adl_reach_task` list: `task`, `icf_code`, and the kinematics
#'   `movement_time`, `peak_velocity`, `time_to_peak_frac`, `movement_units`
#'   (submovements; 1 = a single smooth transport), `sparc` and `ldlj`
#'   (smoothness; less negative = smoother).
#' @references Rohrer B, et al. (2002) J Neurosci 22:8297-8304 (movement units);
#'   Balasubramanian S, et al. (2015) IEEE TBME 62:2137-2147 (SPARC).
#' @seealso [reachingKinematics()], [movementUnits()], [sparc()]
#' @export
#' @examples
#' # a single smooth (minimum-jerk) reach: one movement unit
#' fs <- 100; tt <- seq(0, 1, 1 / fs)
#' v <- 30 * (tt^2) * (1 - tt)^2                 # bell-shaped speed
#' adlReachTask(v, fs, task = "drinking")$movement_units
adlReachTask <- function(speed, sampling_rate,
                         task = c("reaching", "drinking", "feeding",
                                  "dressing", "grooming"),
                         onset_threshold = 0.05) {
  task <- match.arg(task)
  speed <- as.numeric(speed)
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  mt <- movementTime(speed, sampling_rate, onset_threshold = onset_threshold)
  onset <- attr(mt, "onset"); offset <- attr(mt, "offset")
  segment <- if (!is.na(onset) && !is.na(offset)) speed[seq.int(onset, offset)]
             else speed
  fin <- segment[is.finite(segment)]
  smooth_ok <- length(segment) >= 4L && length(fin) && max(fin) > 0

  out <- list(
    task = task, icf_code = .adl_reach_icf(task),
    movement_time = unname(mt),
    peak_velocity = unname(peakVelocity(speed)),
    time_to_peak_frac = timeToPeakVelocity(speed, sampling_rate,
                                           onset_threshold = onset_threshold,
                                           normalize = TRUE),
    movement_units = as.integer(movementUnits(speed, sampling_rate)),
    sparc = if (smooth_ok) as.numeric(sparc(segment, sampling_rate)) else NA_real_,
    ldlj = if (smooth_ok) as.numeric(ldlj(segment, sampling_rate)) else NA_real_)
  class(out) <- "adl_reach_task"
  out
}

#' @export
print.adl_reach_task <- function(x, ...) {
  cat(sprintf("<adl_reach_task> %s (ICF %s)\n", x$task, x$icf_code))
  cat(sprintf("  movement time %.2f s | peak vel %.3f | time-to-peak %.2f\n",
              x$movement_time, x$peak_velocity, x$time_to_peak_frac))
  cat(sprintf("  movement units %d | SPARC %s | LDLJ %s\n",
              x$movement_units,
              if (is.na(x$sparc)) "NA" else sprintf("%.2f", x$sparc),
              if (is.na(x$ldlj)) "NA" else sprintf("%.2f", x$ldlj)))
  invisible(x)
}

#' Instrumented Nine-Hole-Peg dexterity from a hand-speed profile
#'
#' Turns the hand-speed profile of a peg-transport task (the Nine-Hole-Peg Test
#' of fine hand use) into instrumented dexterity metrics: the number of detected
#' peg transports (speed peaks), the transport rate, the mean and coefficient of
#' variation of the inter-transport intervals (movement consistency) and the
#' overall smoothness. This is the sensor-derived complement to the clinical
#' timed NHPT score, and realises ICF `d440` (fine hand use).
#'
#' @param speed Numeric hand speed profile over the whole task.
#' @param sampling_rate Sampling rate in Hz.
#' @param ... Passed to [movementUnits()] (peak height/prominence controls).
#' @return an `nhpt_dexterity` list: `icf_code`, `n_transports`, `total_time`,
#'   `transport_rate` (transports/s), `mean_interval`, `cv_interval` (interval
#'   consistency) and `smoothness` (SPARC).
#' @references Mathiowetz V, et al. (1985) Am J Occup Ther 39:386-391 (NHPT).
#' @seealso [movementUnits()], [adlReachTask()]
#' @export
#' @examples
#' fs <- 100
#' bell <- function(n) { u <- seq(0, 1, length.out = n); 30 * u^2 * (1 - u)^2 }
#' # nine evenly spaced transports
#' v <- unlist(replicate(9, c(bell(40), numeric(20)), simplify = FALSE))
#' nhptDexterity(v, fs)$n_transports
nhptDexterity <- function(speed, sampling_rate, ...) {
  speed <- as.numeric(speed)
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  mu <- movementUnits(speed, sampling_rate, ...)
  peaks <- attr(mu, "peaks")
  n <- length(peaks)
  total_time <- length(speed) / sampling_rate
  intervals <- if (n >= 2L) diff(peaks) / sampling_rate else numeric(0)
  fin <- speed[is.finite(speed)]
  smooth <- if (length(speed) >= 4L && length(fin) && max(fin) > 0)
    as.numeric(sparc(speed, sampling_rate)) else NA_real_

  out <- list(
    icf_code = "d440", n_transports = n, total_time = total_time,
    transport_rate = if (total_time > 0) n / total_time else NA_real_,
    mean_interval = if (length(intervals)) mean(intervals) else NA_real_,
    cv_interval = if (length(intervals) && mean(intervals) > 0)
      stats::sd(intervals) / mean(intervals) else NA_real_,
    smoothness = smooth)
  class(out) <- "nhpt_dexterity"
  out
}

#' @export
print.nhpt_dexterity <- function(x, ...) {
  cat(sprintf("<nhpt_dexterity> (ICF %s) %d transports in %.1f s\n",
              x$icf_code, x$n_transports, x$total_time))
  cat(sprintf("  rate %.2f/s | interval mean %.2f s (CV %.2f) | SPARC %s\n",
              x$transport_rate, x$mean_interval, x$cv_interval,
              if (is.na(x$smoothness)) "NA" else sprintf("%.2f", x$smoothness)))
  invisible(x)
}
