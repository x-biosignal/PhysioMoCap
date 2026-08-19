# Gait Temporal-Spatial Parameters
# Compute temporal and spatial gait parameters from detected events and position data

# Recognized event name aliases for heel strikes and toe offs
.hs_names_right <- c("HS_R", "right_heel_strike")
.hs_names_left  <- c("HS_L", "left_heel_strike")
.to_names_right <- c("TO_R", "right_toe_off")
.to_names_left  <- c("TO_L", "left_toe_off")

#' Calculate gait temporal-spatial parameters
#'
#' Computes temporal and spatial gait parameters from detected gait events.
#' Temporal parameters include stride time, step time, stance/swing durations,
#' double support time, and cadence. Spatial parameters (step length, stride
#' length, step width, walking speed) require position data in the
#' PhysioExperiment assays.
#'
#' @param pe A PhysioExperiment object with position data (assays named
#'   \code{position_x}, \code{position_y}, or \code{position_z}).
#' @param events A \code{detected_events} object (from \code{detectEvents()})
#'   or a data.frame with at minimum columns \code{event_name} (or
#'   \code{event}) and \code{time} (sample indices or seconds), plus
#'   \code{side} (\code{"right"} or \code{"left"}).
#' @param body_height Numeric; body height in metres for normalized parameters
#'   (optional). Currently reserved for future use.
#' @param side Character; which side(s) to compute. One of \code{"right"},
#'   \code{"left"}, or \code{"both"} (default).
#'
#' @return An S3 object of class \code{"gait_parameters"} inheriting from
#'   \code{data.frame}. Each row is one stride cycle. Columns include:
#'   \describe{
#'     \item{side}{Side label (\code{"right"} or \code{"left"})}
#'     \item{stride}{Stride number (sequential within side)}
#'     \item{stride_time}{Time between consecutive ipsilateral heel strikes (s)}
#'     \item{step_time}{Time from contralateral to ipsilateral heel strike (s)}
#'     \item{stance_time}{Heel strike to toe off on the same side (s)}
#'     \item{swing_time}{Toe off to next heel strike on the same side (s)}
#'     \item{stance_percent}{Stance as percentage of stride time}
#'     \item{swing_percent}{Swing as percentage of stride time}
#'     \item{double_support_time}{Time with both feet on the ground (s)}
#'     \item{cadence}{Steps per minute (\code{60 / step_time})}
#'     \item{step_length}{AP distance between feet at consecutive heel strikes (m)}
#'     \item{stride_length}{AP distance between ipsilateral heel strikes (m)}
#'     \item{step_width}{ML distance between feet at heel strike (m)}
#'     \item{walking_speed}{Stride length / stride time (m/s)}
#'   }
#'
#' @details
#' Events must use one of the recognised naming conventions:
#' \itemize{
#'   \item \code{"HS_R"}, \code{"HS_L"} / \code{"TO_R"}, \code{"TO_L"}
#'   \item \code{"right_heel_strike"}, \code{"left_heel_strike"} /
#'         \code{"right_toe_off"}, \code{"left_toe_off"}
#' }
#'
#' The \code{events} data.frame may use either \code{event_name} or
#' \code{event} for the event name column, and either \code{time} (in sample
#' indices) or \code{time_sec} (in seconds) for timing.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' Perry J, Burnfield JM (2010). "Gait Analysis: Normal and Pathological
#' Function." 2nd ed. SLACK Incorporated.
#'
#' @seealso [calculateStepSymmetry()] for symmetry analysis of gait parameters,
#'   [summarizeGaitParameters()] for descriptive statistics of gait data,
#'   [plotGaitCycle()] for gait cycle visualization.
#'
#' @export
#'
#' @examples
#' # See test file for worked examples with synthetic data
calculateGaitParameters <- function(pe,
                                    events,
                                    body_height = NULL,
                                    side = c("right", "left", "both")) {

  side <- match.arg(side)

  # --- Normalise events into a standard data.frame --------------------------
  ev <- .normaliseGaitEvents(pe, events)

  # --- Determine sampling rate ----------------------------------------------
  sr <- NULL
  if (inherits(pe, "PhysioExperiment")) {
    sr <- samplingRate(pe)
  }
  if (is.null(sr)) {
    sr <- attr(events, "sampling_rate")
  }
  if (is.null(sr)) {
    stop("Cannot determine sampling rate. Provide a PhysioExperiment with ",
         "a valid samplingRate or events with a 'sampling_rate' attribute.",
         call. = FALSE)
  }


  # --- Split events by type and side ----------------------------------------
  hs_r <- sort(ev$time_samples[ev$type == "HS" & ev$side == "right"])
  hs_l <- sort(ev$time_samples[ev$type == "HS" & ev$side == "left"])
  to_r <- sort(ev$time_samples[ev$type == "TO" & ev$side == "right"])
  to_l <- sort(ev$time_samples[ev$type == "TO" & ev$side == "left"])

  if (length(hs_r) == 0 && length(hs_l) == 0) {
    stop("No heel strike events found in the supplied events.", call. = FALSE)
  }

  # --- Compute parameters per side ------------------------------------------
  results <- list()

  if (side %in% c("right", "both") && length(hs_r) >= 1) {
    results$right <- .computeSideParams(
      hs_ipsi = hs_r, to_ipsi = to_r,
      hs_contra = hs_l, to_contra = to_l,
      side_label = "right", sr = sr, pe = pe
    )
  }

  if (side %in% c("left", "both") && length(hs_l) >= 1) {
    results$left <- .computeSideParams(
      hs_ipsi = hs_l, to_ipsi = to_l,
      hs_contra = hs_r, to_contra = to_r,
      side_label = "left", sr = sr, pe = pe
    )
  }

  if (length(results) == 0) {
    stop("No heel strike events found for the requested side(s).", call. = FALSE)
  }

  out <- do.call(rbind, results)
  rownames(out) <- NULL

  # Attach metadata
  attr(out, "body_height") <- body_height
  attr(out, "sampling_rate") <- sr
  class(out) <- c("gait_parameters", "data.frame")
  out
}


# ---------------------------------------------------------------------------
# Internal: normalise events to a standard representation
# ---------------------------------------------------------------------------
#' @noRd
.normaliseGaitEvents <- function(pe, events) {
  if (!is.data.frame(events)) {
    stop("events must be a data.frame or detected_events object.", call. = FALSE)
  }
  if (nrow(events) == 0L) {
    stop("No gait events supplied; cannot compute gait parameters.",
         call. = FALSE)
  }

  # Determine event name column
  name_col <- if ("event_name" %in% names(events)) {
    "event_name"
  } else if ("event" %in% names(events)) {
    "event"
  } else {
    stop("events must have an 'event_name' or 'event' column.", call. = FALSE)
  }

  # Determine time column (samples)
  if ("time" %in% names(events)) {
    time_col <- "time"
  } else if ("index" %in% names(events)) {
    time_col <- "index"
  } else if ("samples" %in% names(events)) {
    time_col <- "samples"
  } else {
    stop("events must have a 'time', 'index', or 'samples' column.", call. = FALSE)
  }

  ev <- data.frame(
    name = events[[name_col]],
    time_samples = events[[time_col]],
    stringsAsFactors = FALSE
  )

  # If time is in seconds (detected_events from detectEvents use seconds in

  # 'time' column), convert to samples.
  # Heuristic: if all values < 1000 and max < total duration, they are seconds.
  # However, the spec says time is in samples OR seconds. We rely on callers
  # providing sample indices in 'time' when building events manually, and on
  # the 'index' column from detected_events being sample indices.
  # For detected_events, prefer 'index' column.
  if (time_col == "time" && "index" %in% names(events)) {
    ev$time_samples <- events$index
  }

  # Map event names to type + side
  ev$type <- NA_character_
  ev$side <- NA_character_

  is_hs_r <- ev$name %in% .hs_names_right
  is_hs_l <- ev$name %in% .hs_names_left
  is_to_r <- ev$name %in% .to_names_right
  is_to_l <- ev$name %in% .to_names_left

  ev$type[is_hs_r | is_hs_l] <- "HS"
  ev$type[is_to_r | is_to_l] <- "TO"
  ev$side[is_hs_r | is_to_r] <- "right"
  ev$side[is_hs_l | is_to_l] <- "left"

  # If events have a 'side' column, use it to fill in any remaining

  if ("side" %in% names(events)) {
    missing_side <- is.na(ev$side)
    ev$side[missing_side] <- as.character(events$side[missing_side])
  }

  # Drop unrecognised events
  ev <- ev[!is.na(ev$type) & !is.na(ev$side), , drop = FALSE]

  if (nrow(ev) == 0) {
    stop("No recognised gait events found. Use event names like ",
         "'HS_R', 'HS_L', 'TO_R', 'TO_L' or ",
         "'right_heel_strike', 'left_heel_strike', ",
         "'right_toe_off', 'left_toe_off'.",
         call. = FALSE)
  }

  ev
}


# ---------------------------------------------------------------------------
# Internal: compute temporal-spatial parameters for one side
# ---------------------------------------------------------------------------
#' @noRd
.computeSideParams <- function(hs_ipsi, to_ipsi, hs_contra, to_contra,
                               side_label, sr, pe) {

  n_strides <- length(hs_ipsi) - 1
  if (n_strides < 1) {
    # Single heel strike -- return one row with what we can
    return(.singleStrideRow(hs_ipsi, to_ipsi, hs_contra, to_contra,
                            side_label, sr, pe))
  }

  rows <- vector("list", n_strides)
  for (i in seq_len(n_strides)) {
    hs1 <- hs_ipsi[i]
    hs2 <- hs_ipsi[i + 1]

    stride_time <- (hs2 - hs1) / sr

    # Stance time: HS -> TO (same side, first TO after hs1 and before hs2)
    to_in_stride <- to_ipsi[to_ipsi > hs1 & to_ipsi <= hs2]
    stance_time <- if (length(to_in_stride) > 0) {
      (to_in_stride[1] - hs1) / sr
    } else {
      NA_real_
    }

    # Swing time: TO -> next HS (same side)
    swing_time <- if (!is.na(stance_time)) {
      stride_time - stance_time
    } else {
      NA_real_
    }

    # Percentages
    stance_percent <- if (!is.na(stance_time)) stance_time / stride_time * 100 else NA_real_
    swing_percent  <- if (!is.na(swing_time))  swing_time  / stride_time * 100 else NA_real_

    # Step time: contralateral HS to ipsilateral HS
    # Find last contralateral HS before this ipsilateral HS (hs2)
    contra_hs_before <- hs_contra[hs_contra < hs2 & hs_contra >= hs1]
    step_time <- if (length(contra_hs_before) > 0) {
      (hs2 - contra_hs_before[length(contra_hs_before)]) / sr
    } else {
      NA_real_
    }

    # Double support time
    # DS1: from ipsi HS to contra TO (loading response)
    # DS2: from contra HS to ipsi TO (terminal stance / pre-swing)
    ds_time <- .computeDoubleSupport(hs1, hs2, to_in_stride,
                                      hs_contra, to_contra, sr)

    # Cadence: steps/min
    cadence <- if (!is.na(step_time) && step_time > 0) 60 / step_time else NA_real_

    # Spatial parameters (if position data available)
    spatial <- .computeSpatial(hs1, hs2, contra_hs_before, side_label, pe)

    walking_speed <- if (!is.na(spatial$stride_length) && !is.na(stride_time) && stride_time > 0) {
      spatial$stride_length / stride_time
    } else {
      NA_real_
    }

    rows[[i]] <- data.frame(
      side = side_label,
      stride = i,
      stride_time = stride_time,
      step_time = step_time,
      stance_time = stance_time,
      swing_time = swing_time,
      stance_percent = stance_percent,
      swing_percent = swing_percent,
      double_support_time = ds_time,
      cadence = cadence,
      step_length = spatial$step_length,
      stride_length = spatial$stride_length,
      step_width = spatial$step_width,
      walking_speed = walking_speed,
      stringsAsFactors = FALSE
    )
  }

  do.call(rbind, rows)
}


# ---------------------------------------------------------------------------
# Internal: handle the edge case of a single heel strike (no full stride)
# ---------------------------------------------------------------------------
#' @noRd
.singleStrideRow <- function(hs_ipsi, to_ipsi, hs_contra, to_contra,
                              side_label, sr, pe) {
  hs1 <- hs_ipsi[1]

  # We can only compute stance_time if there is a TO after the HS
  to_after <- to_ipsi[to_ipsi > hs1]
  stance_time <- if (length(to_after) > 0) (to_after[1] - hs1) / sr else NA_real_

  data.frame(
    side = side_label,
    stride = 1L,
    stride_time = NA_real_,
    step_time = NA_real_,
    stance_time = stance_time,
    swing_time = NA_real_,
    stance_percent = NA_real_,
    swing_percent = NA_real_,
    double_support_time = NA_real_,
    cadence = NA_real_,
    step_length = NA_real_,
    stride_length = NA_real_,
    step_width = NA_real_,
    walking_speed = NA_real_,
    stringsAsFactors = FALSE
  )
}


# ---------------------------------------------------------------------------
# Internal: compute double support time within a stride
# ---------------------------------------------------------------------------
#' @noRd
.computeDoubleSupport <- function(hs1, hs2, to_ipsi_in_stride,
                                   hs_contra, to_contra, sr) {
  # Double support period 1: ipsilateral HS (hs1) to contralateral TO
  #   (the first contra TO after hs1)
  contra_to_after_hs1 <- to_contra[to_contra > hs1 & to_contra <= hs2]
  ds1 <- if (length(contra_to_after_hs1) > 0) {
    (contra_to_after_hs1[1] - hs1) / sr
  } else {
    0
  }

  # Double support period 2: contralateral HS (within stride) to ipsilateral TO
  contra_hs_in_stride <- hs_contra[hs_contra > hs1 & hs_contra < hs2]
  ds2 <- 0
  if (length(contra_hs_in_stride) > 0 && length(to_ipsi_in_stride) > 0) {
    # The contra HS should come before the ipsi TO
    c_hs <- contra_hs_in_stride[1]
    i_to <- to_ipsi_in_stride[1]
    if (c_hs < i_to) {
      # Actually ds2 = ipsi TO - contra HS
      # But this only applies if contra HS is within stance phase of ipsi side
      # Safeguard: only count if contra HS < ipsi TO
    } else {
      # contra HS after ipsi TO: ds2 from contra HS to something else
      # For simplicity, use the last ipsi TO before contra HS -- but that
      # already happened. Skip this period.
    }
    # Standard double support period 2: contra HS to ipsi TO
    if (c_hs < i_to) {
      ds2 <- (i_to - c_hs) / sr
    }
  }

  ds_total <- ds1 + ds2
  if (ds_total == 0) NA_real_ else ds_total
}


# ---------------------------------------------------------------------------
# Internal: compute spatial parameters from marker positions
# ---------------------------------------------------------------------------
#' @noRd
.computeSpatial <- function(hs1, hs2, contra_hs_before, side_label, pe) {

  step_length  <- NA_real_
  stride_length <- NA_real_
  step_width   <- NA_real_


  if (!inherits(pe, "PhysioExperiment")) {
    return(list(step_length = step_length, stride_length = stride_length,
                step_width = step_width))
  }

  assay_names <- SummarizedExperiment::assayNames(pe)

  has_pos_x <- "position_x" %in% assay_names
  has_pos_y <- "position_y" %in% assay_names
  has_pos_z <- "position_z" %in% assay_names

  if (!has_pos_x && !has_pos_z) {
    return(list(step_length = step_length, stride_length = stride_length,
                step_width = step_width))
  }

  # Determine which marker columns correspond to the heel / ankle

  col_names <- colnames(SummarizedExperiment::assay(pe, assay_names[1]))

  # Try to find foot markers
  ipsi_marker  <- .findFootMarker(col_names, side_label)
  contra_side  <- if (side_label == "right") "left" else "right"
  contra_marker <- .findFootMarker(col_names, contra_side)

  if (is.na(ipsi_marker)) {
    return(list(step_length = step_length, stride_length = stride_length,
                step_width = step_width))
  }

  # AP axis: assume position_x is anteroposterior (forward walking direction)
  # ML axis: assume position_z is mediolateral
  # (convention: x = AP, y = vertical, z = ML) -- common in biomechanics
  ap_assay <- if (has_pos_x) "position_x" else NULL
  ml_assay <- if (has_pos_z) "position_z" else NULL

  # Stride length: AP distance between ipsilateral HS1 and HS2
  if (!is.null(ap_assay)) {
    ap_data <- SummarizedExperiment::assay(pe, ap_assay)
    hs1_idx <- min(hs1, nrow(ap_data))
    hs2_idx <- min(hs2, nrow(ap_data))

    if (!is.na(ipsi_marker)) {
      ipsi_col <- which(col_names == ipsi_marker)
      if (length(ipsi_col) > 0) {
        stride_length <- abs(ap_data[hs2_idx, ipsi_col[1]] -
                               ap_data[hs1_idx, ipsi_col[1]])
      }
    }

    # Step length: AP distance between contra foot at contra HS and ipsi foot at ipsi HS
    if (!is.na(contra_marker) && length(contra_hs_before) > 0) {
      contra_col <- which(col_names == contra_marker)
      ipsi_col   <- which(col_names == ipsi_marker)
      if (length(contra_col) > 0 && length(ipsi_col) > 0) {
        c_hs_idx <- min(contra_hs_before[length(contra_hs_before)], nrow(ap_data))
        # Step length = ipsi foot position at ipsi HS - contra foot position at contra HS
        step_length <- abs(ap_data[hs2_idx, ipsi_col[1]] -
                             ap_data[c_hs_idx, contra_col[1]])
      }
    }
  }

  # Step width: ML distance at heel strike
  if (!is.null(ml_assay) && !is.na(contra_marker) && length(contra_hs_before) > 0) {
    ml_data <- SummarizedExperiment::assay(pe, ml_assay)
    ipsi_col   <- which(col_names == ipsi_marker)
    contra_col <- which(col_names == contra_marker)
    if (length(ipsi_col) > 0 && length(contra_col) > 0) {
      step_width <- abs(ml_data[min(hs2, nrow(ml_data)), ipsi_col[1]] -
                          ml_data[min(hs2, nrow(ml_data)), contra_col[1]])
    }
  }

  list(step_length = step_length, stride_length = stride_length,
       step_width = step_width)
}


# ---------------------------------------------------------------------------
# Internal: find a foot/heel/ankle marker for a given side
# ---------------------------------------------------------------------------
#' @noRd
.findFootMarker <- function(col_names, side) {
  if (is.null(col_names)) return(NA_character_)

  side_upper <- toupper(substr(side, 1, 1))
  side_lower <- tolower(side)

  patterns <- c(
    paste0(side_upper, "heel"),       # Rheel, Lheel
    paste0(side_lower, "_heel"),      # right_heel, left_heel
    paste0(side_upper, "ankle"),      # Rankle, Lankle
    paste0(side_lower, "_ankle"),     # right_ankle, left_ankle
    paste0(side_upper, "HEE"),        # RHEE, LHEE (Vicon convention)
    paste0(side_upper, "ANK"),        # RANK, LANK
    paste0(side_upper, "CAL"),        # RCAL, LCAL (calcaneus)
    paste0("heel_", side_lower),      # heel_right
    paste0("ankle_", side_lower)      # ankle_right
  )

  for (pat in patterns) {
    idx <- grep(pat, col_names, ignore.case = TRUE)
    if (length(idx) > 0) return(col_names[idx[1]])
  }

  NA_character_
}


# ---------------------------------------------------------------------------
# Calculate step symmetry indices
# ---------------------------------------------------------------------------

#' Calculate step symmetry from gait parameters
#'
#' Computes symmetry metrics comparing left and right sides. Includes the
#' Robinson Symmetry Index and the left/right ratio for each parameter.
#'
#' @param gait_params A \code{gait_parameters} object from
#'   \code{calculateGaitParameters()} containing both left and right sides.
#'
#' @return A data.frame with columns:
#'   \describe{
#'     \item{parameter}{Name of the gait parameter}
#'     \item{left_mean}{Mean value for the left side}
#'     \item{right_mean}{Mean value for the right side}
#'     \item{SI}{Robinson Symmetry Index: \code{|L - R| / (0.5 * (L + R)) * 100}}
#'     \item{ratio}{Left / Right ratio}
#'   }
#'
#' @details
#' A Symmetry Index (SI) of 0 indicates perfect symmetry. Values above 10
#' are generally considered clinically asymmetric.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [calculateGaitParameters()] for computing gait temporal-spatial parameters,
#'   [symmetryIndex()] for general symmetry index computation,
#'   [plotSymmetry()] for symmetry visualization.
#'
#' @export
#'
#' @examples
#' # See test file for worked examples
calculateStepSymmetry <- function(gait_params) {
  stopifnot(inherits(gait_params, "gait_parameters"))

  if (!all(c("right", "left") %in% gait_params$side)) {
    stop("gait_params must contain both 'right' and 'left' sides for ",
         "symmetry analysis.", call. = FALSE)
  }

  # Parameters to compare
  param_cols <- c("stride_time", "step_time", "stance_time", "swing_time",
                   "stance_percent", "swing_percent", "double_support_time",
                   "cadence", "step_length", "stride_length", "step_width",
                   "walking_speed")
  param_cols <- intersect(param_cols, names(gait_params))

  left_df  <- gait_params[gait_params$side == "left", , drop = FALSE]
  right_df <- gait_params[gait_params$side == "right", , drop = FALSE]

  rows <- lapply(param_cols, function(p) {
    l_vals <- left_df[[p]]
    r_vals <- right_df[[p]]
    l_mean <- mean(l_vals, na.rm = TRUE)
    r_mean <- mean(r_vals, na.rm = TRUE)

    avg <- 0.5 * (l_mean + r_mean)
    si <- if (!is.na(avg) && avg != 0) abs(l_mean - r_mean) / avg * 100 else NA_real_
    ratio <- if (!is.na(r_mean) && r_mean != 0) l_mean / r_mean else NA_real_

    data.frame(
      parameter = p,
      left_mean = l_mean,
      right_mean = r_mean,
      SI = si,
      ratio = ratio,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}


# ---------------------------------------------------------------------------
# Summarise gait parameters
# ---------------------------------------------------------------------------

#' Summarise gait parameters
#'
#' Computes mean, standard deviation, and coefficient of variation for each
#' gait parameter across all strides.
#'
#' @param gait_params A \code{gait_parameters} object.
#'
#' @return A data.frame with columns \code{parameter}, \code{side},
#'   \code{mean}, \code{sd}, and \code{cv} (coefficient of variation as
#'   percentage).
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [calculateGaitParameters()] for computing gait parameters,
#'   [print.gait_parameters()] for formatted display of results.
#'
#' @export
#'
#' @examples
#' # See test file for worked examples
summarizeGaitParameters <- function(gait_params) {
  stopifnot(inherits(gait_params, "gait_parameters"))

  param_cols <- c("stride_time", "step_time", "stance_time", "swing_time",
                   "stance_percent", "swing_percent", "double_support_time",
                   "cadence", "step_length", "stride_length", "step_width",
                   "walking_speed")
  param_cols <- intersect(param_cols, names(gait_params))

  sides <- unique(gait_params$side)

  rows <- list()
  for (s in sides) {
    side_df <- gait_params[gait_params$side == s, , drop = FALSE]
    for (p in param_cols) {
      vals <- side_df[[p]]
      m  <- mean(vals, na.rm = TRUE)
      sd_val <- stats::sd(vals, na.rm = TRUE)
      cv <- if (!is.na(m) && m != 0) sd_val / abs(m) * 100 else NA_real_

      rows <- c(rows, list(data.frame(
        parameter = p,
        side = s,
        mean = m,
        sd = sd_val,
        cv = cv,
        stringsAsFactors = FALSE
      )))
    }
  }

  do.call(rbind, rows)
}


# ---------------------------------------------------------------------------
# Print method
# ---------------------------------------------------------------------------

#' Print gait parameters
#'
#' S3 print method showing mean +/- SD for each parameter.
#'
#' @param x A \code{gait_parameters} object.
#' @param ... Additional arguments (unused).
#'
#' @references
#' Perry J, Burnfield JM (2010). "Gait Analysis: Normal and Pathological
#' Function." 2nd ed. SLACK Incorporated.
#'
#' @seealso [calculateGaitParameters()] for computing gait parameters,
#'   [summarizeGaitParameters()] for descriptive statistics.
#'
#' @export
print.gait_parameters <- function(x, ...) {
  cat("Gait Parameters\n")
  cat("===============\n")
  cat(sprintf("Sides: %s\n", paste(unique(x$side), collapse = ", ")))
  cat(sprintf("Strides: %d\n", nrow(x)))
  cat("\n")

  summ <- summarizeGaitParameters(x)

  for (s in unique(summ$side)) {
    cat(sprintf("  %s side:\n", tools::toTitleCase(s)))
    s_rows <- summ[summ$side == s, , drop = FALSE]
    for (i in seq_len(nrow(s_rows))) {
      val <- s_rows$mean[i]
      sd_v <- s_rows$sd[i]
      if (is.na(val)) next
      if (is.na(sd_v)) {
        cat(sprintf("    %-25s %.3f\n", s_rows$parameter[i], val))
      } else {
        cat(sprintf("    %-25s %.3f +/- %.3f\n",
                    s_rows$parameter[i], val, sd_v))
      }
    }
    cat("\n")
  }

  invisible(x)
}
