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
print.multi_trial_phases <- function(x, ...) {
  cat("Multi-Trial Segmented Phases\n")
  cat("Schema:", x$schema$task_label, "\n")
  cat("Number of trials:", x$n_trials, "\n")
  cat("Trial labels:", paste(names(x$trials), collapse = ", "), "\n")
  invisible(x)
}
