# Gait pathology-pattern detectors. Each applies documented kinematic/kinetic
# criteria (Perry & Burnfield; Rodda & Graham 2004; Winters/Gage) to a
# gait-cycle-normalised waveform, returning a flag and a graded severity that
# increases monotonically with the deviation magnitude.

#' Indices of a percentage window of a normalised gait cycle
#' @keywords internal
#' @noRd
.cycle_window <- function(n, pct) {
  axis <- seq(0, 100, length.out = n)
  idx <- which(axis >= pct[1] & axis <= pct[2])
  if (length(idx) == 0L) {
    stop("gait-cycle window is empty for the given percentages.", call. = FALSE)
  }
  idx
}

#' Validate a gait-cycle waveform
#' @keywords internal
#' @noRd
.check_waveform <- function(x, name) {
  x <- as.numeric(x)
  if (length(x) < 5L || any(!is.finite(x))) {
    stop(sprintf("`%s` must be a finite gait-cycle waveform of length >= 5.",
                 name), call. = FALSE)
  }
  x
}

#' Assemble a gait-pattern flag object
#' @keywords internal
#' @noRd
.gait_pattern_flag <- function(pattern, flagged, severity, metric, metric_name,
                               threshold, normal, criteria, extra = list()) {
  out <- c(list(
    pattern = pattern,
    flagged = isTRUE(flagged),
    # NaN/Inf (e.g. a 0/0 severity from degenerate parameters) map to 0, so the
    # severity invariant [0, 1] always holds.
    severity = if (!is.finite(severity)) 0 else min(1, max(0, severity)),
    metric = metric,
    metric_name = metric_name,
    threshold = threshold,
    normal = normal,
    criteria = criteria
  ), extra)
  class(out) <- "gait_pattern_flag"
  out
}

#' Detect stiff-knee gait (reduced / delayed peak swing knee flexion)
#'
#' Stiff-knee gait is marked by reduced peak knee flexion in swing (normal
#' \eqn{\approx 60^{\circ}} near 73\% of the cycle), often with delayed timing
#' (Perry & Burnfield; Goldberg et al. 2006).
#'
#' @param knee_flexion Knee flexion angle (degrees, flexion positive) over one
#'   normalised gait cycle.
#' @param swing Percentage window of swing phase (default `c(60, 100)`).
#' @param normal_peak Normal peak swing knee flexion in degrees (default 60).
#' @param threshold Peak below which stiff-knee is flagged (default 45).
#' @param severe_floor Peak flexion mapped to severity 1 (default 10).
#' @param delay_threshold Peak-timing percentage above which the peak is
#'   considered delayed (default 80).
#'
#' @return A `gait_pattern_flag` object.
#' @references Perry J, Burnfield JM (2010); Goldberg SR, et al. (2006).
#' @seealso [classifyGaitPatterns()], [gaitPatternLibrary()]
#' @export
#' @examples
#' # normal knee flexion peaks ~60 deg in swing
#' k <- c(seq(5, 18, length.out = 30), seq(18, 5, length.out = 30),
#'        60 * sin(seq(0, pi, length.out = 41)))
#' detectStiffKnee(k)
detectStiffKnee <- function(knee_flexion, swing = c(60, 100), normal_peak = 60,
                            threshold = 45, severe_floor = 10,
                            delay_threshold = 80) {
  knee_flexion <- .check_waveform(knee_flexion, "knee_flexion")
  n <- length(knee_flexion)
  idx <- .cycle_window(n, swing)
  peak <- max(knee_flexion[idx])
  peak_pct <- seq(0, 100, length.out = n)[idx[which.max(knee_flexion[idx])]]

  flagged <- peak < threshold || peak_pct > delay_threshold
  # severity combines the magnitude (reduced peak) and timing (delayed peak)
  # deviations so a delay-flagged case is graded rather than reported as 0.
  mag_sev <- (normal_peak - peak) / (normal_peak - severe_floor)
  delay_sev <- if (peak_pct > delay_threshold) {
    (peak_pct - delay_threshold) / (100 - delay_threshold)
  } else {
    0
  }
  severity <- max(mag_sev, delay_sev)

  .gait_pattern_flag(
    pattern = "stiff_knee", flagged = flagged, severity = severity,
    metric = peak, metric_name = "peak_swing_knee_flexion_deg",
    threshold = threshold, normal = normal_peak,
    criteria = "Peak swing knee flexion < threshold, or peak delayed.",
    extra = list(peak_pct = peak_pct)
  )
}

#' Detect push-off deficit (reduced ankle A2 power / plantarflexor output)
#'
#' Reduced ankle plantarflexor push-off is quantified from the peak positive
#' ankle power in late stance (the A2 burst; normal \eqn{\approx 3-4} W/kg) or,
#' equivalently, the peak late-stance plantarflexor moment.
#'
#' @param ankle_power Ankle joint power over one gait cycle. Interpreted as
#'   W/kg (or the peak ankle plantarflexor moment if `metric_name` is set).
#' @param window Percentage window of late stance / push-off
#'   (default `c(40, 62)`).
#' @param normal_peak Normal peak A2 power (default 3.5 W/kg).
#' @param threshold Peak below which a deficit is flagged (default 2.0).
#' @param metric_name Label for the metric (default `"peak_ankle_A2_power"`).
#'
#' @return A `gait_pattern_flag` object.
#' @references Perry J, Burnfield JM (2010); Winter DA (2009).
#' @seealso [classifyGaitPatterns()]
#' @export
detectPushOffDeficit <- function(ankle_power, window = c(40, 62),
                                 normal_peak = 3.5, threshold = 2.0,
                                 metric_name = "peak_ankle_A2_power") {
  ankle_power <- .check_waveform(ankle_power, "ankle_power")
  n <- length(ankle_power)
  peak <- max(ankle_power[.cycle_window(n, window)])

  flagged <- peak < threshold
  severity <- (normal_peak - peak) / normal_peak

  .gait_pattern_flag(
    pattern = "push_off_deficit", flagged = flagged, severity = severity,
    metric = peak, metric_name = metric_name, threshold = threshold,
    normal = normal_peak,
    criteria = "Peak late-stance ankle generation power below threshold."
  )
}

#' Detect circumduction (excessive lateral swing trajectory)
#'
#' Circumduction is a lateral (outward) swing of the foot/hip used to advance a
#' functionally long limb (e.g. with stiff knee or drop foot). It is quantified
#' as the peak lateral excursion of the foot (or hip) during swing relative to
#' the stance-phase baseline.
#'
#' @param foot_ml Medio-lateral foot (or hip) position over one gait cycle, in
#'   metres, with lateral being positive (see `lateral_sign`).
#' @param swing,stance Percentage windows of swing and stance
#'   (defaults `c(60, 100)` and `c(0, 55)`).
#' @param threshold Lateral excursion (m) above which circumduction is flagged
#'   (default 0.04).
#' @param severe Lateral excursion mapped to severity 1 (default 0.12 m).
#' @param lateral_sign `+1` if positive `foot_ml` is lateral, `-1` otherwise.
#'
#' @return A `gait_pattern_flag` object.
#' @references Perry J, Burnfield JM (2010); Kerrigan DC, et al. (2000).
#' @seealso [classifyGaitPatterns()]
#' @export
detectCircumduction <- function(foot_ml, swing = c(60, 100), stance = c(0, 55),
                                threshold = 0.04, severe = 0.12,
                                lateral_sign = 1) {
  foot_ml <- .check_waveform(foot_ml, "foot_ml")
  if (!lateral_sign %in% c(-1, 1)) {
    stop("`lateral_sign` must be +1 or -1.", call. = FALSE)
  }
  n <- length(foot_ml)
  baseline <- mean(foot_ml[.cycle_window(n, stance)])
  excursion <- max(lateral_sign * (foot_ml[.cycle_window(n, swing)] - baseline))
  excursion <- max(0, excursion)

  flagged <- excursion > threshold
  severity <- excursion / severe

  .gait_pattern_flag(
    pattern = "circumduction", flagged = flagged, severity = severity,
    metric = excursion, metric_name = "swing_lateral_excursion_m",
    threshold = threshold, normal = 0,
    criteria = "Peak lateral foot excursion in swing exceeds threshold."
  )
}

#' Detect Trendelenburg sign (excessive contralateral pelvic drop)
#'
#' A Trendelenburg gait reflects hip-abductor weakness on the stance limb: the
#' contralateral (swing-side) pelvis drops during single-limb stance beyond the
#' normal small obliquity (\eqn{\approx 4-5^{\circ}}).
#'
#' @param pelvic_obliquity Pelvic obliquity (degrees) over one gait cycle,
#'   with the contralateral drop being positive (see `drop_sign`).
#' @param stance Percentage window of stance (default `c(10, 50)`, single-limb).
#' @param threshold Drop (deg) above which Trendelenburg is flagged (default 5).
#' @param severe Drop mapped to severity 1 (default 15 deg).
#' @param drop_sign `+1` if positive obliquity is a contralateral drop,
#'   `-1` otherwise.
#'
#' @return A `gait_pattern_flag` object.
#' @references Perry J, Burnfield JM (2010).
#' @seealso [classifyGaitPatterns()]
#' @export
detectTrendelenburg <- function(pelvic_obliquity, stance = c(10, 50),
                                threshold = 5, severe = 15, drop_sign = 1) {
  pelvic_obliquity <- .check_waveform(pelvic_obliquity, "pelvic_obliquity")
  if (!drop_sign %in% c(-1, 1)) {
    stop("`drop_sign` must be +1 or -1.", call. = FALSE)
  }
  n <- length(pelvic_obliquity)
  drop <- max(drop_sign * pelvic_obliquity[.cycle_window(n, stance)])
  drop <- max(0, drop)

  flagged <- drop > threshold
  severity <- drop / severe

  .gait_pattern_flag(
    pattern = "trendelenburg", flagged = flagged, severity = severity,
    metric = drop, metric_name = "contralateral_pelvic_drop_deg",
    threshold = threshold, normal = 4,
    criteria = "Peak contralateral pelvic drop in stance exceeds threshold."
  )
}

#' Registry of supported gait pathology patterns
#'
#' Documents the gait deviation patterns detected by this package, their input
#' variable, detector, threshold and clinical reference.
#'
#' @return A data frame (class `gait_pattern_library`).
#' @seealso [classifyGaitPatterns()], [detectStiffKnee()],
#'   [detectPushOffDeficit()], [detectCircumduction()], [detectTrendelenburg()]
#' @export
#' @examples
#' gaitPatternLibrary()
gaitPatternLibrary <- function() {
  lib <- data.frame(
    pattern = c("stiff_knee", "push_off_deficit", "circumduction",
                "trendelenburg"),
    variable = c("knee_flexion", "ankle_power", "foot_ml", "pelvic_obliquity"),
    detector = c("detectStiffKnee", "detectPushOffDeficit",
                 "detectCircumduction", "detectTrendelenburg"),
    metric = c("peak_swing_knee_flexion_deg", "peak_ankle_A2_power",
               "swing_lateral_excursion_m", "contralateral_pelvic_drop_deg"),
    threshold = c(45, 2.0, 0.04, 5),
    description = c(
      "Reduced or delayed peak swing knee flexion",
      "Reduced ankle plantarflexor push-off power",
      "Lateral swing trajectory of a functionally long limb",
      "Contralateral pelvic drop from hip-abductor weakness"),
    reference = c("Perry & Burnfield; Goldberg 2006", "Perry & Burnfield",
                  "Kerrigan 2000", "Perry & Burnfield"),
    stringsAsFactors = FALSE
  )
  class(lib) <- c("gait_pattern_library", "data.frame")
  lib
}

#' Classify gait pathology patterns from a bundle of gait variables
#'
#' Runs each applicable detector on the supplied gait-cycle waveforms and
#' returns a per-pattern flag and severity. A pattern is evaluated only when its
#' input variable is present in `variables`.
#'
#' @param variables A named list of gait-cycle waveforms. Recognised names:
#'   `knee_flexion`, `ankle_power`, `foot_ml`, `pelvic_obliquity`.
#' @param params Optional named list of per-pattern argument lists forwarded to
#'   the individual detectors (e.g. `list(stiff_knee = list(threshold = 40))`).
#'
#' @return A data frame (class `gait_pattern_classification`) with columns
#'   `pattern`, `flagged`, `severity`, `metric`, `threshold`, one row per
#'   evaluated pattern.
#' @seealso [gaitPatternLibrary()]
#' @export
#' @examples
#' vars <- list(knee_flexion = 60 * sin(seq(0, pi, length.out = 101)))
#' classifyGaitPatterns(vars)
classifyGaitPatterns <- function(variables, params = list()) {
  if (!is.list(variables) || is.null(names(variables))) {
    stop("`variables` must be a named list of gait-cycle waveforms.",
         call. = FALSE)
  }
  detectors <- list(
    stiff_knee = list(var = "knee_flexion", fn = detectStiffKnee),
    push_off_deficit = list(var = "ankle_power", fn = detectPushOffDeficit),
    circumduction = list(var = "foot_ml", fn = detectCircumduction),
    trendelenburg = list(var = "pelvic_obliquity", fn = detectTrendelenburg)
  )

  rows <- list()
  for (nm in names(detectors)) {
    d <- detectors[[nm]]
    if (!d$var %in% names(variables)) {
      next
    }
    args <- c(list(variables[[d$var]]), params[[nm]] %||% list())
    flag <- do.call(d$fn, args)
    rows[[nm]] <- data.frame(
      pattern = flag$pattern, flagged = flag$flagged,
      severity = flag$severity, metric = flag$metric,
      threshold = flag$threshold, stringsAsFactors = FALSE
    )
  }
  if (length(rows) == 0L) {
    stop("no recognised gait variables supplied; see gaitPatternLibrary().",
         call. = FALSE)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  class(out) <- c("gait_pattern_classification", "data.frame")
  out
}

#' @export
print.gait_pattern_flag <- function(x, ...) {
  cat(sprintf("<gait_pattern_flag> %s: %s (severity %.2f)\n",
              x$pattern, if (x$flagged) "FLAGGED" else "normal", x$severity))
  cat(sprintf("  %s = %.4g (threshold %.4g, normal %.4g)\n",
              x$metric_name, x$metric, x$threshold, x$normal))
  invisible(x)
}

#' @export
print.gait_pattern_classification <- function(x, ...) {
  cat("Gait pathology classification:\n")
  for (i in seq_len(nrow(x))) {
    cat(sprintf("  %-18s %s (severity %.2f)\n", x$pattern[i],
                if (x$flagged[i]) "FLAGGED" else "normal", x$severity[i]))
  }
  invisible(x)
}

#' @export
print.gait_pattern_library <- function(x, ...) {
  cat("Gait pattern library (", nrow(x), " patterns):\n", sep = "")
  for (i in seq_len(nrow(x))) {
    cat(sprintf("  - %-18s [%s] %s\n", x$pattern[i], x$variable[i],
                x$description[i]))
  }
  invisible(x)
}
