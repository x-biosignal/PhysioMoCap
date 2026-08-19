# Population-specific clinical gait pipelines. Each orchestrates the ecosystem's
# gait tooling (GDI, joint work, pathology flags) plus a condition-specific
# metric and returns a structured clinical report object.

#' @keywords internal
#' @noRd
.pop_trapz <- function(y, dt) {
  n <- length(y)
  if (n < 2L) 0 else sum((y[-1L] + y[-n]) / 2) * dt
}

# --- Cerebral palsy: GDI + GMFCS-stratified interpretation -------------------

#' Cerebral-palsy gait pipeline (GDI + pathology flags)
#'
#' Computes the Gait Deviation Index (Schwartz & Rozumalski 2008) for a subject's
#' kinematics, categorises it, adds the kinematic pathology flags detectable from
#' the same waveforms (stiff knee, Trendelenburg), and records the GMFCS level
#' for stratified interpretation.
#'
#' @param kinematics Subject kinematics passed to [gaitDeviationIndex()]
#'   (a variables x cycle-points matrix with row names matching the norm).
#' @param norm A `gait_norm` reference (from `PhysioGaitNorm::loadGaitNorm()`);
#'   if `NULL`, the default is loaded from PhysioGaitNorm.
#' @param gmfcs Optional Gross Motor Function Classification System level (I-V).
#'
#' @return A `cp_gait_report` object.
#' @references Schwartz & Rozumalski (2008); Palisano et al. (1997) GMFCS.
#' @seealso [gaitDeviationIndex()], [classifyGaitPatterns()]
#' @export
pipelineCPgait <- function(kinematics, norm = NULL, gmfcs = NULL) {
  gdi_res <- gaitDeviationIndex(kinematics, norm = norm)
  gdi <- gdi_res$gdi
  category <- if (gdi >= 100) "unimpaired" else if (gdi >= 90) "mild" else
    if (gdi >= 80) "moderate" else if (gdi >= 70) "marked" else "severe"

  # kinematic pathology flags available from the GDI variables
  m <- as.matrix(kinematics)
  vars <- list()
  if (!is.null(rownames(m))) {
    if ("knee_flexion" %in% rownames(m)) {
      vars$knee_flexion <- m["knee_flexion", ]
    }
    if ("pelvic_obliquity" %in% rownames(m)) {
      vars$pelvic_obliquity <- m["pelvic_obliquity", ]
    }
  }
  flags <- if (length(vars) > 0L) classifyGaitPatterns(vars) else NULL

  if (!is.null(gmfcs) &&
      !(as.character(gmfcs) %in% c("I", "II", "III", "IV", "V",
                                   as.character(1:5)))) {
    stop("`gmfcs` must be a GMFCS level I-V (or 1-5) or NULL.", call. = FALSE)
  }

  out <- list(
    condition = "cerebral_palsy", gdi = gdi, gdi_category = category,
    gmfcs = gmfcs, pathology = flags
  )
  class(out) <- "cp_gait_report"
  out
}

# --- Stroke: paretic propulsion (Bowden 2006) --------------------------------

#' Stroke paretic-propulsion pipeline
#'
#' Quantifies propulsion symmetry after stroke from the anterior-posterior ground
#' reaction force of each limb: the paretic propulsion `Pp` is the paretic
#' propulsive (anterior) impulse divided by the total propulsive impulse of both
#' limbs (Bowden et al. 2006). A symmetric gait gives `Pp = 0.5`; reduced paretic
#' output gives `Pp < 0.5`.
#'
#' @param ap_paretic,ap_nonparetic Anterior-posterior ground reaction force of
#'   the paretic and non-paretic limbs over the analysis window (anterior /
#'   propulsive positive).
#' @param sampling_rate Sampling rate in Hz.
#'
#' @return A `stroke_propulsion_report` object.
#' @references Bowden MG, et al. (2006). Stroke 37(3):872-876.
#' @export
pipelineStrokePropulsion <- function(ap_paretic, ap_nonparetic, sampling_rate) {
  ap_paretic <- as.numeric(ap_paretic)
  ap_nonparetic <- as.numeric(ap_nonparetic)
  if (any(!is.finite(ap_paretic)) || any(!is.finite(ap_nonparetic))) {
    stop("AP force signals must be finite numeric.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  dt <- 1 / sampling_rate
  prop_p <- .pop_trapz(pmax(ap_paretic, 0), dt)
  prop_np <- .pop_trapz(pmax(ap_nonparetic, 0), dt)
  total <- prop_p + prop_np
  pp <- if (total > 0) prop_p / total else NA_real_
  symmetry <- if (prop_np > 0) prop_p / prop_np else NA_real_

  out <- list(
    condition = "stroke", paretic_propulsion = pp,
    propulsive_impulse_paretic = prop_p,
    propulsive_impulse_nonparetic = prop_np,
    propulsion_symmetry_ratio = symmetry
  )
  class(out) <- "stroke_propulsion_report"
  out
}

# --- Parkinson's disease: freezing-of-gait freeze index (Bachlin 2010) -------

#' Parkinson's freezing-of-gait pipeline (freeze index)
#'
#' Detects freezing of gait (FOG) from a windowed spectral freeze index: the
#' ratio of power in the freeze band (default 3-8 Hz) to power in the locomotor
#' band (default 0.5-3 Hz) of an accelerometer signal (Moore et al. 2008;
#' Bachlin et al. 2010). A window is flagged as FOG when the freeze index exceeds
#' `fi_threshold` and the band power exceeds `power_threshold` (excluding rest).
#'
#' @param accel Accelerometer signal (e.g. shank/trunk vertical or resultant).
#' @param sampling_rate Sampling rate in Hz.
#' @param window_sec,step_sec Sliding-window length and step (seconds).
#' @param freeze_band,locomotor_band Frequency bands (Hz).
#' @param fi_threshold Freeze-index threshold for FOG (default 2).
#' @param power_threshold Minimum band power for a window to be considered
#'   (excludes rest). `NULL` uses the 10th percentile of windowed band power as a
#'   quiet-baseline floor (robust to a loud walking bout, unlike a
#'   maximum-relative gate); pass a fixed absolute value if the sensor units are
#'   known.
#'
#' @return A `pd_fog_report` object with a per-window `windows` data frame
#'   (`time`, `freeze_index`, `power`, `fog`) and the overall `fog_fraction`.
#' @references Moore ST, et al. (2008); Bachlin M, et al. (2010).
#' @export
pipelinePDfog <- function(accel, sampling_rate, window_sec = 4, step_sec = 0.5,
                          freeze_band = c(3, 8), locomotor_band = c(0.5, 3),
                          fi_threshold = 2, power_threshold = NULL) {
  accel <- as.numeric(accel)
  if (any(!is.finite(accel))) {
    stop("`accel` must be finite numeric.", call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  pos1 <- function(v, nm) {
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v <= 0) {
      stop(sprintf("`%s` must be a single positive number.", nm), call. = FALSE)
    }
  }
  pos1(window_sec, "window_sec")
  pos1(step_sec, "step_sec")
  band <- function(b, nm) {
    if (!is.numeric(b) || length(b) != 2L || any(!is.finite(b)) ||
        b[1] < 0 || b[2] <= b[1] || b[2] > sampling_rate / 2) {
      stop(sprintf("`%s` must be c(low, high) within [0, Nyquist].", nm),
           call. = FALSE)
    }
  }
  band(freeze_band, "freeze_band")
  band(locomotor_band, "locomotor_band")

  win <- max(4L, as.integer(round(window_sec * sampling_rate)))
  step <- max(1L, as.integer(round(step_sec * sampling_rate)))
  n <- length(accel)
  if (n < win) {
    stop("signal shorter than one analysis window.", call. = FALSE)
  }

  starts <- seq(1L, n - win + 1L, by = step)
  # rfft bin frequencies (correct for even and odd window lengths)
  freqs <- (0:(win %/% 2L)) * sampling_rate / win
  # half-open locomotor band so the shared boundary bin is not double-counted
  fb <- freqs >= freeze_band[1] & freqs <= freeze_band[2]
  lb <- freqs >= locomotor_band[1] & freqs < locomotor_band[2]

  fi <- numeric(length(starts))
  power <- numeric(length(starts))
  for (k in seq_along(starts)) {
    seg <- accel[starts[k]:(starts[k] + win - 1L)]
    ps <- Mod(stats::fft(seg - mean(seg)))[seq_len(win %/% 2L + 1L)]^2
    fp <- sum(ps[fb])
    lp <- sum(ps[lb])
    fi[k] <- if (lp > 0) fp / lp else if (fp > 0) Inf else 0
    power[k] <- fp + lp
  }
  if (is.null(power_threshold)) {
    # quiet-baseline floor (10th percentile) rather than a max-relative gate, so
    # low-amplitude FOG is not masked by a loud walking bout elsewhere.
    power_threshold <- stats::quantile(power, 0.1, names = FALSE)
  }
  fog <- fi > fi_threshold & power > power_threshold

  windows <- data.frame(
    time = (starts - 1 + win / 2) / sampling_rate,
    freeze_index = fi, power = power, fog = fog, stringsAsFactors = FALSE
  )
  out <- list(
    condition = "parkinsons", windows = windows,
    fog_fraction = mean(fog), n_fog_windows = sum(fog),
    fi_threshold = fi_threshold, power_threshold = power_threshold
  )
  class(out) <- "pd_fog_report"
  out
}

# --- Amputee: prosthetic-side work asymmetry ---------------------------------

#' Amputee prosthetic-side work-asymmetry pipeline
#'
#' Compares the positive (concentric) joint work generated by the prosthetic and
#' intact limbs (via [jointWork()]) and reports a work-asymmetry index. A value
#' near 0 is symmetric; positive values indicate the intact limb generates more
#' positive work than the prosthetic limb.
#'
#' @param power_prosthetic,power_intact Joint power time series (W or W/kg) for
#'   the prosthetic and intact limbs.
#' @param sampling_rate Sampling rate in Hz.
#' @param body_mass Optional body mass (kg) for mass-normalised work.
#'
#' @return An `amputee_report` object.
#' @references Winter DA (2009); Nolan & Lees (2000).
#' @seealso [jointWork()]
#' @export
pipelineAmputee <- function(power_prosthetic, power_intact, sampling_rate,
                            body_mass = NULL) {
  if (any(!is.finite(as.numeric(power_prosthetic))) ||
      any(!is.finite(as.numeric(power_intact)))) {
    stop("power traces must be finite numeric.", call. = FALSE)
  }
  wp <- jointWork(power_prosthetic, sampling_rate, body_mass = body_mass)
  wi <- jointWork(power_intact, sampling_rate, body_mass = body_mass)
  # report mass-normalised work (J/kg) when body_mass is supplied
  conc <- if (is.null(body_mass)) "concentric_work" else "concentric_work_per_kg"
  net <- if (is.null(body_mass)) "net_work" else "net_work_per_kg"
  pos_p <- wp[[conc]][1]
  pos_i <- wi[[conc]][1]
  denom <- pos_i + pos_p
  asymmetry <- if (isTRUE(denom > 0)) (pos_i - pos_p) / denom else NA_real_

  out <- list(
    condition = "amputee",
    positive_work_prosthetic = pos_p,
    positive_work_intact = pos_i,
    net_work_prosthetic = wp[[net]][1],
    net_work_intact = wi[[net]][1],
    work_asymmetry_index = asymmetry
  )
  class(out) <- "amputee_report"
  out
}

# --- ACL reconstruction: limb symmetry index + return-to-sport ---------------

#' ACL return-to-sport pipeline (limb symmetry index)
#'
#' Computes the Limb Symmetry Index (LSI) for a battery of functional tests and
#' evaluates the return-to-sport (RTS) criterion that every LSI meets a threshold
#' (default 90\%; Grindem et al. 2016). LSI is `involved / uninvolved * 100` for
#' tests where a higher score is better, and inverted otherwise.
#'
#' @param tests A data frame with columns `test`, `involved`, `uninvolved`, and
#'   optionally `higher_better` (logical, default `TRUE`); or a named list of
#'   `c(involved, uninvolved)` pairs.
#' @param threshold LSI percentage required to pass each test (default 90).
#'
#' @return An `acl_rts_report` object with a per-test `lsi` data frame and the
#'   overall `rts_ready` flag.
#' @references Grindem H, et al. (2016). Br J Sports Med 50(13):804-808.
#' @export
pipelineACLrts <- function(tests, threshold = 90) {
  if (is.list(tests) && !is.data.frame(tests)) {
    if (is.null(names(tests))) {
      stop("a list of tests must be named.", call. = FALSE)
    }
    if (any(vapply(tests, length, integer(1)) != 2L)) {
      stop("each test must be a c(involved, uninvolved) pair.", call. = FALSE)
    }
    tests <- data.frame(
      test = names(tests),
      involved = vapply(tests, function(v) as.numeric(v[[1]]), numeric(1)),
      uninvolved = vapply(tests, function(v) as.numeric(v[[2]]), numeric(1)),
      stringsAsFactors = FALSE
    )
  }
  if (!is.data.frame(tests) ||
      !all(c("test", "involved", "uninvolved") %in% names(tests))) {
    stop("`tests` must have columns test, involved, uninvolved.", call. = FALSE)
  }
  if (is.null(tests$higher_better)) {
    tests$higher_better <- TRUE
  }
  if (any(!is.finite(tests$involved)) || any(!is.finite(tests$uninvolved)) ||
      any(tests$involved < 0) || any(tests$uninvolved <= 0)) {
    stop("involved/uninvolved must be finite, non-negative, uninvolved > 0.",
         call. = FALSE)
  }
  # a lower-is-better test divides by `involved`, so it must be strictly > 0
  if (any(!tests$higher_better & tests$involved <= 0)) {
    stop("`involved` must be > 0 for lower-is-better tests.", call. = FALSE)
  }

  lsi <- ifelse(tests$higher_better,
                tests$involved / tests$uninvolved,
                tests$uninvolved / tests$involved) * 100
  lsi_tab <- data.frame(
    test = tests$test, involved = tests$involved, uninvolved = tests$uninvolved,
    lsi = lsi, pass = lsi >= threshold, stringsAsFactors = FALSE
  )

  out <- list(
    condition = "acl_rts", lsi = lsi_tab, threshold = threshold,
    rts_ready = all(lsi_tab$pass), n_pass = sum(lsi_tab$pass),
    n_tests = nrow(lsi_tab)
  )
  class(out) <- "acl_rts_report"
  out
}

# --- print methods -----------------------------------------------------------

#' @export
print.cp_gait_report <- function(x, ...) {
  cat("<cp_gait_report>\n")
  cat(sprintf("  GDI: %.1f (%s)%s\n", x$gdi, x$gdi_category,
              if (!is.null(x$gmfcs)) paste0("  GMFCS ", x$gmfcs) else ""))
  if (!is.null(x$pathology)) {
    flagged <- x$pathology$pattern[x$pathology$flagged]
    cat("  pathology flags:",
        if (length(flagged)) paste(flagged, collapse = ", ") else "none", "\n")
  }
  invisible(x)
}

#' @export
print.stroke_propulsion_report <- function(x, ...) {
  cat("<stroke_propulsion_report>\n")
  cat(sprintf("  paretic propulsion Pp: %.3f (0.5 = symmetric)\n",
              x$paretic_propulsion))
  cat(sprintf("  propulsive impulse: paretic %.3g / non-paretic %.3g\n",
              x$propulsive_impulse_paretic, x$propulsive_impulse_nonparetic))
  invisible(x)
}

#' @export
print.pd_fog_report <- function(x, ...) {
  cat("<pd_fog_report>\n")
  cat(sprintf("  windows: %d, FOG windows: %d (%.1f%%)\n",
              nrow(x$windows), x$n_fog_windows, 100 * x$fog_fraction))
  cat(sprintf("  freeze-index threshold: %.2g\n", x$fi_threshold))
  invisible(x)
}

#' @export
print.amputee_report <- function(x, ...) {
  cat("<amputee_report>\n")
  cat(sprintf("  positive work: prosthetic %.3g / intact %.3g\n",
              x$positive_work_prosthetic, x$positive_work_intact))
  cat(sprintf("  work asymmetry index: %.3f (0 = symmetric)\n",
              x$work_asymmetry_index))
  invisible(x)
}

#' @export
print.acl_rts_report <- function(x, ...) {
  cat("<acl_rts_report>\n")
  cat(sprintf("  RTS ready: %s (%d/%d tests >= %g%% LSI)\n",
              x$rts_ready, x$n_pass, x$n_tests, x$threshold))
  for (i in seq_len(nrow(x$lsi))) {
    cat(sprintf("    %-16s LSI %.1f%% %s\n", x$lsi$test[i], x$lsi$lsi[i],
                if (x$lsi$pass[i]) "pass" else "FAIL"))
  }
  invisible(x)
}
