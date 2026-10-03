# Phase Segmentation Functions for Movement Analysis
# Segments movement data into phases based on detected events

#' Segment data into phases
#'
#' Divides movement data into phases based on detected events and schema definition.
#'
#' @param x PhysioExperiment object or matrix (time x channels)
#' @param events A detected_events data.frame from detectEvents()
#' @param schema TaskSchema object defining phase structure
#' @param include_subphases Whether to include subphases in output
#'
#' @return A segmented_phases object (list) containing:
#'   \itemize{
#'     \item phases - List of phase data
#'     \item metadata - Phase timing information
#'     \item schema - Original schema
#'   }
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [detectEvents()], [extractPhase()], [phaseTiming()], [normalizeMovement()]
#'
#' @export
#'
#' @examples
#' # Assuming events have been detected
#' # phases <- segmentPhases(data, events, schema_gait)
segmentPhases <- function(x,
                          events,
                          schema,
                          include_subphases = TRUE) {

  stopifnot(inherits(events, "detected_events") || is.data.frame(events))
  stopifnot(inherits(schema, "TaskSchema"))

  # Handle PhysioExperiment input
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
    sr <- samplingRate(x)
  } else if (is.matrix(x)) {
    data <- x
    sr <- attr(events, "sampling_rate") %||% 1000
  } else if (is.numeric(x)) {
    data <- matrix(x, ncol = 1)
    sr <- attr(events, "sampling_rate") %||% 1000
  } else {
    stop("x must be a PhysioExperiment or matrix", call. = FALSE)
  }

  n_samples <- nrow(data)
  n_channels <- ncol(data)

  # Create event index lookup
  event_idx <- setNames(events$index, events$event)

  # Segment each phase
  phase_data <- .segmentPhaseList(schema$phases, data, event_idx,
                                   include_subphases, sr)

  # Build metadata
  metadata <- lapply(phase_data, function(p) {
    list(
      name = p$name,
      label = p$label,
      start_idx = p$start_idx,
      end_idx = p$end_idx,
      duration_samples = p$end_idx - p$start_idx + 1,
      duration_seconds = (p$end_idx - p$start_idx + 1) / sr,
      percent_start = (p$start_idx - 1) / (n_samples - 1) * 100,
      percent_end = (p$end_idx - 1) / (n_samples - 1) * 100
    )
  })

  result <- list(
    phases = phase_data,
    metadata = metadata,
    schema = schema,
    events = events,
    sampling_rate = sr,
    n_samples = n_samples,
    n_channels = n_channels
  )

  class(result) <- "segmented_phases"
  result
}


#' Segment a list of phases
#' @keywords internal
.segmentPhaseList <- function(phase_list, data, event_idx,
                               include_subphases, sr) {
  if (length(phase_list) == 0) {
    return(list())
  }

  result <- list()

  for (phase in phase_list) {
    # Get start and end indices
    start_idx <- event_idx[[phase$start_event]]
    end_idx <- event_idx[[phase$end_event]]

    if (is.na(start_idx) || is.na(end_idx)) {
      warning(sprintf("Phase '%s' has missing events, skipping", phase$name),
              call. = FALSE)
      next
    }

    if (end_idx < start_idx) {
      warning(sprintf("Phase '%s' has end before start, skipping", phase$name),
              call. = FALSE)
      next
    }

    # Extract phase data
    phase_data_mat <- data[start_idx:end_idx, , drop = FALSE]

    phase_result <- list(
      name = phase$name,
      label = phase$label,
      data = phase_data_mat,
      start_idx = start_idx,
      end_idx = end_idx,
      start_event = phase$start_event,
      end_event = phase$end_event,
      color = phase$color,
      subphases = list()
    )

    # Process subphases
    if (include_subphases && length(phase$subphases) > 0) {
      phase_result$subphases <- .segmentPhaseList(
        phase$subphases, data, event_idx, include_subphases, sr
      )
    }

    result[[phase$name]] <- phase_result
  }

  result
}


#' Extract a single phase from segmented data
#'
#' @param x A segmented_phases object
#' @param phase_name Name of the phase to extract
#' @param search_subphases Whether to search within subphases
#'
#' @return A matrix of phase data
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [segmentPhases()], [phaseTiming()], [getPhaseData()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phases <- segmentPhases(data, events, schema_gait)
#' extractPhase(phases, getPhaseNames(schema_gait)[1])
extractPhase <- function(x, phase_name, search_subphases = TRUE) {
  stopifnot(inherits(x, "segmented_phases"))

  phase <- .findPhaseInList(x$phases, phase_name, search_subphases)

  if (is.null(phase)) {
    stop(sprintf("Phase '%s' not found", phase_name), call. = FALSE)
  }

  phase$data
}


#' Find phase in nested list
#' @keywords internal
.findPhaseInList <- function(phase_list, name, search_sub) {
  for (phase in phase_list) {
    if (phase$name == name) return(phase)
    if (search_sub && length(phase$subphases) > 0) {
      found <- .findPhaseInList(phase$subphases, name, search_sub)
      if (!is.null(found)) return(found)
    }
  }
  NULL
}


#' Get phase timing information
#'
#' @param x A segmented_phases object
#' @param as_percent Return timing as percentage (TRUE) or seconds (FALSE)
#'
#' @return A data.frame with phase timing information
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [segmentPhases()], [phaseDurations()], [phaseRatios()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phaseTiming(segmentPhases(data, events, schema_gait))
phaseTiming <- function(x, as_percent = TRUE) {
  stopifnot(inherits(x, "segmented_phases"))

  timing_df <- do.call(rbind, lapply(x$metadata, function(m) {
    data.frame(
      phase = m$name,
      label = m$label,
      start = if (as_percent) m$percent_start else m$start_idx / x$sampling_rate,
      end = if (as_percent) m$percent_end else m$end_idx / x$sampling_rate,
      duration = if (as_percent) {
        m$percent_end - m$percent_start
      } else {
        m$duration_seconds
      },
      stringsAsFactors = FALSE
    )
  }))

  rownames(timing_df) <- NULL
  timing_df
}


#' Get phase durations
#'
#' @param x A segmented_phases object
#' @param unit "samples", "seconds", or "percent"
#'
#' @return Named numeric vector of phase durations
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [phaseTiming()], [phaseRatios()], [segmentPhases()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phaseDurations(segmentPhases(data, events, schema_gait))
phaseDurations <- function(x, unit = c("percent", "seconds", "samples")) {
  stopifnot(inherits(x, "segmented_phases"))
  unit <- match.arg(unit)

  durations <- vapply(x$metadata, function(m) {
    switch(unit,
      percent = m$percent_end - m$percent_start,
      seconds = m$duration_seconds,
      samples = m$duration_samples
    )
  }, numeric(1))

  names(durations) <- vapply(x$metadata, function(m) m$name, character(1))
  durations
}


#' Calculate phase ratios
#'
#' @param x A segmented_phases object
#' @param reference Reference for ratio calculation ("total" or phase name)
#'
#' @return Named numeric vector of phase ratios
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [phaseDurations()], [phaseTiming()], [segmentPhases()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phaseRatios(segmentPhases(data, events, schema_gait))
phaseRatios <- function(x, reference = "total") {
  stopifnot(inherits(x, "segmented_phases"))

  durations <- phaseDurations(x, unit = "samples")

  if (reference == "total") {
    ref_duration <- sum(durations, na.rm = TRUE)
  } else if (reference %in% names(durations)) {
    ref_duration <- durations[[reference]]
  } else {
    stop(sprintf("Unknown reference '%s'", reference), call. = FALSE)
  }

  if (ref_duration == 0) {
    warning("Reference duration is zero, returning NA", call. = FALSE)
    return(setNames(rep(NA_real_, length(durations)), names(durations)))
  }

  durations / ref_duration
}


#' Print method for segmented phases
#' @param x A segmented_phases object
#' @param ... Additional arguments (unused)
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' print(segmentPhases(data, events, schema_gait))
print.segmented_phases <- function(x, ...) {
  cat("Segmented Phases\n")
  cat("Schema:", x$schema$task_label, "\n")
  cat("Sampling rate:", x$sampling_rate, "Hz\n")
  cat("Total samples:", x$n_samples, "\n")
  cat("Channels:", x$n_channels, "\n")
  cat("\nPhases:\n")

  timing <- phaseTiming(x, as_percent = TRUE)
  for (i in seq_len(nrow(timing))) {
    cat(sprintf("  %s: %.1f%% - %.1f%% (%.1f%%)\n",
                timing$label[i], timing$start[i], timing$end[i],
                timing$duration[i]))
  }

  invisible(x)
}


#' Get data for all phases as a list of matrices
#'
#' @param x A segmented_phases object
#' @param include_subphases Whether to include subphases
#'
#' @return Named list of matrices
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [segmentPhases()], [extractPhase()], [hasValidPhases()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phases <- segmentPhases(data, events, schema_gait)
#' head(getPhaseData(phases))
getPhaseData <- function(x, include_subphases = FALSE) {
  stopifnot(inherits(x, "segmented_phases"))

  .extractDataList <- function(phase_list, include_sub) {
    result <- list()
    for (phase in phase_list) {
      result[[phase$name]] <- phase$data
      if (include_sub && length(phase$subphases) > 0) {
        sub_result <- .extractDataList(phase$subphases, include_sub)
        result <- c(result, sub_result)
      }
    }
    result
  }

  .extractDataList(x$phases, include_subphases)
}


#' Check if all phases are valid
#'
#' @param x A segmented_phases object
#'
#' @return Logical indicating if all phases have valid data
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [segmentPhases()], [getPhaseData()], [extractPhase()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' hasValidPhases(segmentPhases(data, events, schema_gait))
hasValidPhases <- function(x) {
  stopifnot(inherits(x, "segmented_phases"))

  all(vapply(x$phases, function(p) {
    !is.null(p$data) && nrow(p$data) > 0
  }, logical(1)))
}


#' Combine multiple trials with segmented phases
#'
#' @param ... segmented_phases objects to combine
#' @param labels Optional labels for each trial
#'
#' @return A multi_trial_phases object
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [segmentPhases()], [batchNormalize()], [normalizeMovement()]
#'
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phases <- segmentPhases(data, events, schema_gait)
#' combineTrials(phases, phases, labels = c("t1", "t2"))
combineTrials <- function(..., labels = NULL) {
  trials <- list(...)

  # Validate all are segmented_phases
  for (i in seq_along(trials)) {
    if (!inherits(trials[[i]], "segmented_phases")) {
      stop(sprintf("Argument %d is not a segmented_phases object", i),
           call. = FALSE)
    }
  }

  # Check schema compatibility
  schema_types <- vapply(trials, function(t) t$schema$task_type, character(1))
  if (length(unique(schema_types)) > 1) {
    warning("Combining trials with different schema types", call. = FALSE)
  }

  if (is.null(labels)) {
    labels <- paste0("Trial_", seq_along(trials))
  }

  result <- list(
    trials = setNames(trials, labels),
    n_trials = length(trials),
    schema = trials[[1]]$schema
  )

  class(result) <- "multi_trial_phases"
  result
}


#' Print method for multi-trial phases
#' @param x A multi_trial_phases object
#' @param ... Additional arguments (unused)
#' @export
#' @examples
#' set.seed(123)
#' data <- matrix(rnorm(200), 100, 2)
#' events <- data.frame(
#'   event = c("hs1","ff","ms","ho","to","hs2"),
#'   label = c("Heel Strike","Foot Flat","Midstance","Heel Off","Toe Off","Heel Strike 2"),
#'   index = c(1, 13, 31, 41, 61, 100), time = c(0, .12, .30, .40, .60, 1.0),
#'   percent = c(0, 12, 30, 40, 60, 100), method = rep("manual", 6),
#'   confidence = rep(1, 6), stringsAsFactors = FALSE)
#' class(events) <- c("detected_events", "data.frame")
#' attr(events, "sampling_rate") <- 100
#' phases <- segmentPhases(data, events, schema_gait)
#' print(combineTrials(phases, phases, labels = c("t1", "t2")))
print.multi_trial_phases <- function(x, ...) {
  cat("Multi-Trial Segmented Phases\n")
  cat("Schema:", x$schema$task_label, "\n")
  cat("Number of trials:", x$n_trials, "\n")
  cat("Trial labels:", paste(names(x$trials), collapse = ", "), "\n")
  invisible(x)
}

#' Segment matched cycles on native modality sampling grids
#'
#' Applies explicit shared-clock intervals to multiple modalities from one
#' participant and trial. All cycle rows and their identifiers are retained.
#' Intervals are half-open: `[start_time, end_time)`. Recording coverage is
#' `[origin, origin + n_samples / sampling_rate)`, treating each acquired sample
#' as the start of a sample interval. No interpolation or endpoint extension is
#' performed. Boundary roundoff is tolerated up to one millionth of a sample.
#'
#' @param streams Uniquely named list of modalities. Each entry is a list with
#'   `data` (nonempty real numeric matrix, time by channels), `sampling_rate`
#'   (positive finite Hz), `start_time` (finite shared-clock seconds), and
#'   nonempty character scalars `participant_id` and `trial_id`. All entries
#'   must declare the same participant and trial.
#' @param cycles Nonempty data.frame with character columns `participant_id`,
#'   `trial_id`, `side`, `cycle_id` and numeric `start_time`, `end_time` in seconds.
#'   Composite identifiers must be unique; participant/trial must match streams.
#'   Additional columns are retained. Missing boundaries are reported as
#'   incomplete cycles. The caller supplies event-derived boundaries; this
#'   function does not infer cycles, verify event meaning, or select channels
#'   anatomically from the side label.
#' @param incomplete Either `"error"` (default) or `"retain"`. In retain mode,
#'   incomplete modality/cycle segments are `NULL`, with explicit reasons.
#' @return A `multimodal_cycles` list with `cycles`, `segments` (modality then
#'   cycle row; each valid segment contains `data`, `time`, `sample_index`),
#'   `status` (keys, cycle row, modality, complete flag, reason and sample count),
#'   `complete_cycles`, `recordings` metadata and `key_columns`.
#'   Reasons are `ok`, `missing_boundary`, `invalid_interval`, `out_of_range`,
#'   `no_samples`, or `nonfinite_data`. Internal nonfinite samples invalidate
#'   a segment; they are never silently interpolated or dropped.
#' @seealso [summarizeCycleFeatures()]
#' @export
#' @examples
#' s <- list(data = matrix(rep(2, 20), ncol = 1), sampling_rate = 10,
#'           start_time = 0, participant_id = "P1", trial_id = "T1")
#' c <- data.frame(participant_id = "P1", trial_id = "T1", side = "L",
#'                 cycle_id = c("C1", "C2"), start_time = 0:1, end_time = 1:2)
#' z <- segmentMultimodalCycles(list(emg = s, motion = s), c)
#' z$status
segmentMultimodalCycles <- function(streams, cycles,
                                   incomplete = c("error", "retain")) {
  incomplete <- match.arg(incomplete)
  key <- c("participant_id", "trial_id", "side", "cycle_id")
  nm <- names(streams)
  text_scalar <- function(x) is.character(x) && length(x) == 1L &&
    !is.na(x) && nzchar(x)
  real_scalar <- function(x) is.numeric(x) && !is.complex(x) &&
    length(x) == 1L && is.finite(x)
  if (!is.list(streams) || length(streams) < 2L || is.null(nm) ||
      anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm))
    stop("streams must be a uniquely named list of at least two modalities.", call. = FALSE)
  for (j in seq_along(streams)) {
    s <- streams[[j]]
    if (!is.list(s) || anyDuplicated(names(s)) ||
        !all(c("data", "sampling_rate", "start_time", "participant_id", "trial_id") %in% names(s)) ||
        !is.matrix(s$data) || !is.numeric(s$data) ||
        is.complex(s$data) || !nrow(s$data) || !ncol(s$data) ||
        !real_scalar(s$sampling_rate) || s$sampling_rate <= 0 ||
        !real_scalar(s$start_time) || !text_scalar(s$participant_id) ||
        !text_scalar(s$trial_id))
      stop("Invalid recording metadata or data for modality: ", nm[j], call. = FALSE)
    t <- s$start_time + (seq_len(nrow(s$data)) - 1) / s$sampling_rate
    end <- s$start_time + nrow(s$data) / s$sampling_rate
    if (any(!is.finite(t)) || !is.finite(end) || any(diff(c(t, end)) <= 0))
      stop("Recording clock is not representable for modality: ", nm[j], call. = FALSE)
    if (!identical(s$participant_id, streams[[1]]$participant_id) ||
        !identical(s$trial_id, streams[[1]]$trial_id))
      stop("All modalities must declare the same participant and trial.", call. = FALSE)
  }
  if (!is.data.frame(cycles) || !nrow(cycles) || anyDuplicated(names(cycles)) ||
      !all(c(key, "start_time", "end_time") %in% names(cycles)))
    stop("cycles must contain unique column names, keys and time boundaries.", call. = FALSE)
  cycles <- as.data.frame(cycles)
  if (!all(vapply(cycles[key], function(x) is.character(x) &&
                 !anyNA(x) && all(nzchar(x)), logical(1))))
    stop("Cycle identifiers must be complete nonempty character columns.", call. = FALSE)
  if (anyDuplicated(cycles[key])) stop("Duplicate cycle keys.", call. = FALSE)
  if (any(cycles$participant_id != streams[[1]]$participant_id) ||
      any(cycles$trial_id != streams[[1]]$trial_id))
    stop("Cycle participant/trial does not match the recordings.", call. = FALSE)
  if (!all(vapply(cycles[c("start_time", "end_time")], function(x)
      is.numeric(x) && !is.complex(x), logical(1))))
    stop("Cycle boundaries must be numeric seconds.", call. = FALSE)
  segments <- setNames(lapply(streams, function(s) vector("list", nrow(cycles))), nm)
  rows <- list()
  complete <- rep(TRUE, nrow(cycles))
  for (j in seq_along(streams)) {
    s <- streams[[j]]
    for (i in seq_len(nrow(cycles))) {
      a <- cycles$start_time[i]; b <- cycles$end_time[i]
      reason <- "ok"; index <- integer()
      if (is.na(a) || is.na(b)) reason <- "missing_boundary"
      else if (!is.finite(a) || !is.finite(b) || b <= a) reason <- "invalid_interval"
      else {
        lo <- (a - s$start_time) * s$sampling_rate
        hi <- (b - s$start_time) * s$sampling_rate
        tol <- min(1e-6, 8 * .Machine$double.eps *
                     max(1, abs(a), abs(b), abs(s$start_time)) * s$sampling_rate)
        if (!is.finite(lo) || !is.finite(hi) || lo < -tol || hi > nrow(s$data) + tol)
          reason <- "out_of_range"
        else {
          first <- max(0, ceiling(lo - tol))
          last <- min(nrow(s$data) - 1, ceiling(hi - tol) - 1)
          if (last < first) reason <- "no_samples"
          else {
            index <- seq.int(first, last) + 1L
            if (any(!is.finite(s$data[index, , drop = FALSE]))) reason <- "nonfinite_data"
          }
        }
      }
      ok <- identical(reason, "ok")
      complete[i] <- complete[i] && ok
      if (ok) segments[[j]][[i]] <- list(
        data = s$data[index, , drop = FALSE], sample_index = index,
        time = s$start_time + (index - 1) / s$sampling_rate)
      rows[[length(rows) + 1L]] <- data.frame(cycles[i, key, drop = FALSE],
        cycle_row = i, modality = nm[j], complete = ok, reason = reason,
        n_samples = length(index), stringsAsFactors = FALSE)
    }
  }
  status <- do.call(rbind, rows); rownames(status) <- NULL
  if (incomplete == "error" && any(!complete)) {
    bad <- status[which(!status$complete)[1], ]
    stop("Incomplete cycle row ", bad$cycle_row, " in ", bad$modality,
         ": ", bad$reason, ". Use incomplete = 'retain' for diagnostics.", call. = FALSE)
  }
  recordings <- lapply(streams, function(s) list(participant_id = s$participant_id,
    trial_id = s$trial_id, sampling_rate = s$sampling_rate, start_time = s$start_time,
    n_samples = nrow(s$data), channels = colnames(s$data)))
  structure(list(cycles = cycles, segments = segments, status = status,
    complete_cycles = complete, recordings = recordings, key_columns = key),
    class = "multimodal_cycles")
}

#' Summarize matched cycles into keyed feature blocks
#'
#' Applies the selected modality's feature function to each native-grid segment and preserves
#' its observation keys. A row is one cycle, not an independent participant.
#' This function does not fit statistical models or enforce grouped train/test
#' splits. Retain participant identifiers when building such analyses.
#'
#' @param x Result of [segmentMultimodalCycles()] or [segmentCohortCycles()].
#' @param FUN Function, or a uniquely named list of functions matching modalities.
#'   Each function accepts a time-by-channel matrix and returns a
#'   nonempty, uniquely named, finite real numeric vector. Feature names must
#'   match across cycles within each modality; their order is reconciled by name.
#'   The function must handle the native grid appropriately; sampling rates
#'   are not equalized and samples are not weighted by duration automatically.
#'   Bind rate-dependent settings in per-modality functions using the recording
#'   metadata; metadata are not passed as implicit arguments to `FUN`.
#' @param ... Additional arguments passed to `FUN`.
#' @param incomplete `"error"` (default) or explicit `"exclude"`. Exclusion
#'   removes a cycle from all blocks if any modality was incomplete.
#' @return List with numeric matrix `blocks`, matching per-modality key tables
#'   `keys`, retained cycle `observations`, all original `status` rows,
#'   `cycle_rows` and `excluded_cycles` (original cycle row indices), and
#'   `recordings` metadata.
#'   Blocks and keys can be passed to PhysioCrossModal's keyed block adapter.
#'   No invalid cycle is silently imputed or treated as a complete observation.
#' @seealso [segmentMultimodalCycles()]
#' @export
#' @examples
#' # Given segmented cycles z and appropriately named matrix columns:
#' # features <- summarizeCycleFeatures(z, colMeans)
summarizeCycleFeatures <- function(x, FUN, ..., incomplete = c("error", "exclude")) {
  incomplete <- match.arg(incomplete)
  if (!inherits(x, "multimodal_cycles"))
    stop("x must come from segmentMultimodalCycles().", call. = FALSE)
  modalities <- names(x$segments)
  if (is.list(FUN)) {
    if (is.null(names(FUN)) || anyNA(names(FUN)) || anyDuplicated(names(FUN)) ||
        !setequal(names(FUN), modalities))
      stop("FUN list must name each modality exactly once.", call. = FALSE)
    functions <- lapply(FUN[modalities], match.fun)
  } else functions <- rep(list(match.fun(FUN)), length(modalities))
  if (any(!x$complete_cycles) && incomplete == "error")
    stop("Incomplete cycles present; use incomplete = 'exclude' explicitly.", call. = FALSE)
  keep <- which(x$complete_cycles)
  if (!length(keep)) stop("No complete cycles remain.", call. = FALSE)
  blocks <- lapply(seq_along(modalities), function(j) {
    segments <- x$segments[[j]]
    fun <- functions[[j]]
    values <- lapply(keep, function(i) {
      v <- fun(segments[[i]]$data, ...)
      if (!is.numeric(v) || is.complex(v) || !is.null(dim(v)) || !length(v) ||
          any(!is.finite(v)) || is.null(names(v)) || anyNA(names(v)) ||
          any(!nzchar(names(v))) || anyDuplicated(names(v)))
        stop("FUN must return uniquely named finite real numeric features.", call. = FALSE)
      v
    })
    labels <- names(values[[1]])
    if (!all(vapply(values, function(v) setequal(names(v), labels), logical(1))))
      stop("Feature names differ between cycles within a modality.", call. = FALSE)
    do.call(rbind, lapply(values, function(v) v[labels]))
  })
  names(blocks) <- modalities
  observations <- x$cycles[keep, , drop = FALSE]; rownames(observations) <- NULL
  keys <- lapply(blocks, function(b) observations[, x$key_columns, drop = FALSE])
  list(blocks = blocks, keys = keys, observations = observations,
       status = x$status, cycle_rows = keep,
       excluded_cycles = which(!x$complete_cycles),
       recordings = x$recordings, cohort_design = x$cohort_design)
}

#' Segment cohort recordings while preserving subject and session identity
#'
#' Reuses the PhysioCore cohort hierarchy and [segmentMultimodalCycles()].
#' Sessions must be `MultiPhysioExperiment` objects with at least two
#' consistently named streams. No resampling or synchronization is performed.
#'
#' @param x A PhysioCore `PhysioCohort`.
#' @param cycles Nonempty data frame with character `subject_id`, `session_id`,
#'   `trial_id`, `side`, `cycle_id`, and numeric `start_time`, `end_time`.
#'   Times are seconds relative to each session's master-clock `t0`, as in
#'   `PhysioExperiment::streamTimeIndex()`. Trial IDs describe intervals within a
#'   session; they are never inferred from session IDs. Additional columns are
#'   retained. An optional `participant_id` must equal `subject_id`.
#' @param assay A single assay name used in every stream (default `"raw"`).
#'   Assays must be numeric time-by-channel matrices.
#' @param incomplete Passed to [segmentMultimodalCycles()].
#' @return A `multimodal_cycles` object accepted by [summarizeCycleFeatures()].
#'   Canonical keys include subject, session, trial, side and cycle. The
#'   `participant_id` alias is derived from `subject_id`. `cohort_design`
#'   contains the source cohort's subject/session table; `recordings` contains
#'   one entry per selected subject/session/trial context, including clock and
#'   per-modality acquisition metadata. Cycle rows retain input order.
#' @details Subject-level splits can be made using existing cohort subsetting
#'   before extraction, together with the corresponding cycle rows. This bridge
#'   does not enforce statistical independence or downstream training splits.
#'   Units, anatomical channel meaning, and event detection remain the caller's
#'   responsibility. The selected sessions must share stream names; feature
#'   summarization additionally checks feature names within each stream. Feature
#'   callbacks receive matrices, not recording metadata. For rate-dependent
#'   features, process contexts with their own rate settings before pooling;
#'   a single fixed-rate callback is inappropriate when session rates differ.
#' @seealso [segmentMultimodalCycles()], [summarizeCycleFeatures()]
#' @export
#' @details Operates on a `PhysioCohort` multi-subject container (package
#'   PhysioCohort), which is not among this package's dependencies, so the
#'   example cannot run offline and is not executed.
#' @examples
#' \dontrun{
#' # `cohort` is a PhysioCohort object; see the PhysioCohort package.
#' segmentCohortCycles(cohort, cycles = cohort_cycles)
#' }
segmentCohortCycles <- function(x, cycles, assay = "raw",
                                incomplete = c("error", "retain")) {
  incomplete <- match.arg(incomplete)
  if (!inherits(x, "PhysioCohort"))
    stop("x must be a PhysioCohort.", call. = FALSE)
  key <- c("subject_id", "session_id", "trial_id", "side", "cycle_id")
  if (!is.data.frame(cycles) || !nrow(cycles) || anyDuplicated(names(cycles)) ||
      !all(c(key, "start_time", "end_time") %in% names(cycles)))
    stop("cycles must contain cohort keys and time boundaries.", call. = FALSE)
  cycles <- as.data.frame(cycles)
  if (!all(vapply(cycles[key], function(v) is.character(v) &&
      !anyNA(v) && all(nzchar(v)), logical(1))))
    stop("Cohort cycle identifiers must be nonempty character columns.", call. = FALSE)
  if (anyDuplicated(cycles[key])) stop("Duplicate cohort cycle keys.", call. = FALSE)
  if ("participant_id" %in% names(cycles) &&
      !identical(cycles$participant_id, cycles$subject_id))
    stop("participant_id must match the cohort subject_id.", call. = FALSE)
  cycles$participant_id <- cycles$subject_id
  if (!is.character(assay) || length(assay) != 1L || is.na(assay) || !nzchar(assay))
    stop("assay must be a single nonempty name.", call. = FALSE)
  if (any(!cycles$subject_id %in% PhysioExperiment::subjectIds(x)))
    stop("Unknown cohort subject_id.", call. = FALSE)
  context_key <- c("subject_id", "session_id", "trial_id")
  contexts <- unique(cycles[context_key])
  segments <- NULL; complete <- rep(FALSE, nrow(cycles))
  status <- vector("list", nrow(contexts))
  recordings <- vector("list", nrow(contexts))
  modalities <- NULL
  for (k in seq_len(nrow(contexts))) {
    ctx <- contexts[k, , drop = FALSE]
    rows <- which(cycles$subject_id == ctx$subject_id &
                  cycles$session_id == ctx$session_id & cycles$trial_id == ctx$trial_id)
    pl <- PhysioExperiment::subject(x, ctx$subject_id)
    # Exact session IDs, not session()'s visit-label-first lookup.
    ss <- PhysioExperiment::sessions(pl)
    if (!ctx$session_id %in% names(ss)) stop("Unknown session_id for subject: ",
      ctx$subject_id, "/", ctx$session_id, call. = FALSE)
    mr <- ss[[ctx$session_id]]
    if (!inherits(mr, "MultiPhysioExperiment"))
      stop("Selected sessions must be MultiPhysioExperiment objects.", call. = FALSE)
    s <- PhysioExperiment::streams(mr); nm <- names(s)
    if (length(s) < 2L || is.null(nm) || anyNA(nm) || any(!nzchar(nm)) || anyDuplicated(nm))
      stop("Sessions require at least two uniquely named streams.", call. = FALSE)
    if (is.null(modalities)) {
      modalities <- nm
      segments <- stats::setNames(lapply(nm, function(z) vector("list", nrow(cycles))), nm)
    } else if (!setequal(nm, modalities))
      stop("Stream names differ between selected sessions.", call. = FALSE)
    clock <- PhysioExperiment::commonClock(mr)
    off <- clock$offsets
    if (!is.numeric(off) || is.complex(off) || is.null(names(off)) ||
        anyNA(names(off)) || anyDuplicated(names(off)) ||
        !all(modalities %in% names(off)) || any(!is.finite(off[modalities])))
      stop("Each selected stream needs an explicit finite clock offset.", call. = FALSE)
    descriptors <- stats::setNames(lapply(modalities, function(n) {
      pe <- s[[n]]
      if (!assay %in% SummarizedExperiment::assayNames(pe))
        stop("Missing selected assay in stream: ", n, call. = FALSE)
      list(data = SummarizedExperiment::assay(pe, assay),
        sampling_rate = PhysioExperiment::samplingRate(pe), start_time = unname(off[n]),
        participant_id = ctx$subject_id, trial_id = ctx$trial_id)
    }), modalities)
    part <- segmentMultimodalCycles(descriptors, cycles[rows, , drop = FALSE], "retain")
    for (n in modalities) segments[[n]][rows] <- part$segments[[n]]
    complete[rows] <- part$complete_cycles
    st <- part$status
    st$cycle_row <- rows[st$cycle_row]
    st$subject_id <- ctx$subject_id; st$session_id <- ctx$session_id
    status[[k]] <- st
    recordings[[k]] <- list(context = ctx, clock = clock, streams = part$recordings)
  }
  status <- do.call(rbind, status)
  status <- status[order(match(status$modality, modalities), status$cycle_row), , drop = FALSE]
  rownames(status) <- NULL
  if (incomplete == "error" && any(!complete)) {
    bad <- status[which(!status$complete)[1], ]
    stop("Incomplete cohort cycle row ", bad$cycle_row, " (", bad$subject_id,
      "/", bad$session_id, "/", bad$trial_id, ") in ", bad$modality, ": ",
      bad$reason, ". Use incomplete = 'retain' for diagnostics.", call. = FALSE)
  }
  structure(list(cycles = cycles, segments = segments, status = status,
    complete_cycles = complete, recordings = recordings, key_columns = key,
    cohort_design = PhysioExperiment::cohortDesign(x)), class = "multimodal_cycles")
}
