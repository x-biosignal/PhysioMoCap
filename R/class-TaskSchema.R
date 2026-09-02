# Task Schema Classes for Multi-Task Movement Analysis
# Provides S3 classes for defining movement task structures

#' Create an Event definition
#'
#' Defines an event within a movement task that can be detected automatically
#' or specified manually.
#'
#' @param name Short identifier for the event (e.g., "hs1", "to")
#' @param label Human-readable label (e.g., "Heel Strike", "Toe Off")
#' @param detection_method Method for automatic detection:
#'   \itemize{
#'     \item "threshold" - Signal crosses a threshold value
#'     \item "peak" - Local maximum or minimum
#'     \item "zero_crossing" - Signal crosses zero
#'     \item "angle" - Specific angle value (for cyclic data)
#'     \item "velocity_threshold" - Velocity exceeds threshold
#'     \item "manual" - User-specified timing
#'   }
#' @param detection_params List of parameters for detection method:
#'   \itemize{
#'     \item For "threshold": signal, threshold, direction ("rising"/"falling")
#'     \item For "peak": signal, type ("max"/"min"), prominence
#'     \item For "zero_crossing": signal, direction ("rising"/"falling"/"any")
#'     \item For "angle": signal, value
#'   }
#' @param typical_timing Expected timing as percentage of movement (0-100),
#'   used for validation and as fallback
#'
#' @return An Event object (S3 class)
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [Phase()], [TaskSchema()], [detectEvents()]
#'
#' @export
#'
#' @examples
#' # Heel strike event detected when vertical GRF rises above 10N
#' hs <- Event("hs", "Heel Strike", "threshold",
#'             list(signal = "vGRF", threshold = 10, direction = "rising"),
#'             typical_timing = 0)
#'
#' # Toe off event detected when vertical GRF falls below 10N
#' to <- Event("to", "Toe Off", "threshold",
#'             list(signal = "vGRF", threshold = 10, direction = "falling"),
#'             typical_timing = 60)
#'
#' # Peak knee flexion
#' pk <- Event("peak_flex", "Peak Knee Flexion", "peak",
#'             list(signal = "knee_angle", type = "max"))
Event <- function(name,
                  label,
                  detection_method = "threshold",
                  detection_params = list(),
                  typical_timing = NULL) {

  stopifnot(is.character(name), length(name) == 1)
  stopifnot(is.character(label), length(label) == 1)
  stopifnot(detection_method %in% c("threshold", "peak", "zero_crossing",
                                     "angle", "velocity_threshold", "manual"))
  stopifnot(is.list(detection_params))
  stopifnot(is.null(typical_timing) ||
              (is.numeric(typical_timing) && typical_timing >= 0 && typical_timing <= 100))

structure(
    list(
      name = name,
      label = label,
      detection_method = detection_method,
      detection_params = detection_params,
      typical_timing = typical_timing
    ),
    class = "Event"
  )
}

#' @export
print.Event <- function(x, ...) {
  cat("Event:", x$label, "\n")
  cat("  Name:", x$name, "\n")
  cat("  Detection:", x$detection_method, "\n")
  if (!is.null(x$typical_timing)) {
    cat("  Typical timing:", x$typical_timing, "%\n")
  }
  invisible(x)
}


#' Create a Phase definition
#'
#' Defines a phase within a movement task, bounded by start and end events.
#'
#' @param name Short identifier for the phase (e.g., "stance", "swing")
#' @param label Human-readable label (e.g., "Stance Phase")
#' @param start_event Name of the event marking phase start
#' @param end_event Name of the event marking phase end
#' @param color Optional color for visualization (hex code)
#' @param subphases Optional list of Phase objects for nested phases
#'
#' @return A Phase object (S3 class)
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [Event()], [TaskSchema()], [segmentPhases()]
#'
#' @export
#'
#' @examples
#' # Simple phase definition
#' stance <- Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8")
#'
#' # Phase with subphases
#' stance <- Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8",
#'                 subphases = list(
#'                   Phase("loading", "Loading Response", "hs1", "ff"),
#'                   Phase("midstance", "Midstance", "ff", "ho"),
#'                   Phase("propulsion", "Propulsion", "ho", "to")
#'                 ))
Phase <- function(name,
                  label,
                  start_event,
                  end_event,
                  color = NULL,
                  subphases = list()) {

  stopifnot(is.character(name), length(name) == 1)
  stopifnot(is.character(label), length(label) == 1)
  stopifnot(is.character(start_event), length(start_event) == 1)
  stopifnot(is.character(end_event), length(end_event) == 1)
  stopifnot(is.null(color) || (is.character(color) && length(color) == 1))
  stopifnot(is.list(subphases))

  # Validate subphases are Phase objects
  if (length(subphases) > 0) {
    for (sp in subphases) {
      if (!inherits(sp, "Phase")) {
        stop("All subphases must be Phase objects", call. = FALSE)
      }
    }
  }

  structure(
    list(
      name = name,
      label = label,
      start_event = start_event,
      end_event = end_event,
      color = color,
      subphases = subphases
    ),
    class = "Phase"
  )
}

#' @export
print.Phase <- function(x, indent = 0, ...) {
  prefix <- paste(rep("  ", indent), collapse = "")
  cat(prefix, "Phase:", x$label, "\n", sep = "")
  cat(prefix, "  Name: ", x$name, "\n", sep = "")
  cat(prefix, "  Events: ", x$start_event, " -> ", x$end_event, "\n", sep = "")
  if (!is.null(x$color)) {
    cat(prefix, "  Color: ", x$color, "\n", sep = "")
  }
  if (length(x$subphases) > 0) {
    cat(prefix, "  Subphases:\n", sep = "")
    for (sp in x$subphases) {
      print.Phase(sp, indent = indent + 2)
    }
  }
  invisible(x)
}


#' Create a Task Schema
#'
#' Defines a complete movement task schema including events, phases,
#' normalization method, metrics, and visualization defaults.
#'
#' @param task_type Short identifier for the task type (e.g., "gait", "jump")
#' @param task_label Human-readable label (e.g., "Gait Cycle", "Vertical Jump")
#' @param events List of Event objects defining key timepoints
#' @param phases List of Phase objects defining movement phases
#' @param normalization Normalization method:
#'   \itemize{
#'     \item "cycle" - Normalize entire movement to 0-100%
#'     \item "phase" - Normalize each phase independently to 0-100%
#'     \item "landmark" - Align to a specific event
#'     \item "dtw" - Dynamic time warping alignment
#'     \item "absolute" - Keep original time (no normalization)
#'   }
#' @param norm_length Target length after normalization (default 101 for 0-100%)
#' @param metrics Character vector of recommended metrics for this task
#' @param vis_defaults List of default visualization parameters:
#'   \itemize{
#'     \item xlab - X-axis label
#'     \item ylab - Y-axis label
#'     \item show_phases - Whether to show phase regions
#'     \item show_events - Whether to show event markers
#'     \item phase_alpha - Transparency for phase shading
#'     \item landmark_event - Event to align to (for landmark normalization)
#'   }
#'
#' @return A TaskSchema object (S3 class)
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [Event()], [Phase()], [getSchema()], [validateSchema()]
#'
#' @export
#'
#' @examples
#' # Simple task schema
#' my_task <- TaskSchema(
#'   task_type = "simple",
#'   task_label = "Simple Movement",
#'   events = list(
#'     Event("start", "Start", "threshold",
#'           list(signal = "velocity", threshold = 0.1, direction = "rising")),
#'     Event("end", "End", "threshold",
#'           list(signal = "velocity", threshold = 0.1, direction = "falling"))
#'   ),
#'   phases = list(
#'     Phase("main", "Main Phase", "start", "end")
#'   ),
#'   normalization = "cycle"
#' )
TaskSchema <- function(task_type,
                       task_label = task_type,
                       events = list(),
                       phases = list(),
                       normalization = c("cycle", "phase", "landmark", "dtw", "absolute"),
                       norm_length = 101L,
                       metrics = character(),
                       vis_defaults = list()) {

  normalization <- match.arg(normalization)

  stopifnot(is.character(task_type), length(task_type) == 1)
  stopifnot(is.character(task_label), length(task_label) == 1)
  stopifnot(is.list(events))
  stopifnot(is.list(phases))
  stopifnot(is.null(norm_length) || (is.numeric(norm_length) && norm_length > 0))
  stopifnot(is.character(metrics))
  stopifnot(is.list(vis_defaults))

  # Validate events are Event objects
  for (e in events) {
    if (!inherits(e, "Event")) {
      stop("All events must be Event objects", call. = FALSE)
    }
  }

  # Validate phases are Phase objects
  for (p in phases) {
    if (!inherits(p, "Phase")) {
      stop("All phases must be Phase objects", call. = FALSE)
    }
  }

  # Check phase events reference valid events
  event_names <- vapply(events, function(e) e$name, character(1))
  .validatePhaseEvents <- function(phase_list, event_names) {
    for (p in phase_list) {
      if (!p$start_event %in% event_names) {
        warning(sprintf("Phase '%s' references unknown start event '%s'",
                        p$name, p$start_event), call. = FALSE)
      }
      if (!p$end_event %in% event_names) {
        warning(sprintf("Phase '%s' references unknown end event '%s'",
                        p$name, p$end_event), call. = FALSE)
      }
      if (length(p$subphases) > 0) {
        .validatePhaseEvents(p$subphases, event_names)
      }
    }
  }
  if (length(phases) > 0 && length(events) > 0) {
    .validatePhaseEvents(phases, event_names)
  }

  # Set default vis_defaults
  default_vis <- list(
    xlab = paste(task_label, "(%)"),
    ylab = "Value",
    show_phases = length(phases) > 0,
    show_events = length(events) > 0,
    phase_alpha = 0.3
  )
  vis_defaults <- modifyList(default_vis, vis_defaults)

  structure(
    list(
      task_type = task_type,
      task_label = task_label,
      events = events,
      phases = phases,
      normalization = normalization,
      norm_length = as.integer(norm_length),
      metrics = metrics,
      vis_defaults = vis_defaults
    ),
    class = "TaskSchema"
  )
}

#' @export
print.TaskSchema <- function(x, ...) {
  cat("TaskSchema:", x$task_label, "\n")
  cat("  Type:", x$task_type, "\n")
  cat("  Normalization:", x$normalization, "\n")
  if (!is.null(x$norm_length)) {
    cat("  Normalized length:", x$norm_length, "\n")
  }
  cat("  Events:", length(x$events), "\n")
  if (length(x$events) > 0) {
    event_names <- vapply(x$events, function(e) e$label, character(1))
    cat("    ", paste(event_names, collapse = " -> "), "\n")
  }
  cat("  Phases:", length(x$phases), "\n")
  if (length(x$phases) > 0) {
    phase_names <- vapply(x$phases, function(p) p$label, character(1))
    cat("    ", paste(phase_names, collapse = ", "), "\n")
  }
  if (length(x$metrics) > 0) {
    cat("  Metrics:", length(x$metrics), "\n")
    cat("    ", paste(head(x$metrics, 5), collapse = ", "),
        if (length(x$metrics) > 5) ", ..." else "", "\n")
  }
  invisible(x)
}


#' Get event names from a TaskSchema
#'
#' @param schema A TaskSchema object
#' @return Character vector of event names
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getPhaseNames()], [getEvent()], [TaskSchema()]
#'
#' @export
getEventNames <- function(schema) {
  stopifnot(inherits(schema, "TaskSchema"))
  vapply(schema$events, function(e) e$name, character(1))
}

#' Get phase names from a TaskSchema
#'
#' @param schema A TaskSchema object
#' @param include_subphases Whether to include subphase names
#' @return Character vector of phase names
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getEventNames()], [getPhase()], [getPhaseColors()]
#'
#' @export
getPhaseNames <- function(schema, include_subphases = FALSE) {
  stopifnot(inherits(schema, "TaskSchema"))

  .extractNames <- function(phase_list, include_sub) {
    names <- character()
    for (p in phase_list) {
      names <- c(names, p$name)
      if (include_sub && length(p$subphases) > 0) {
        names <- c(names, .extractNames(p$subphases, include_sub))
      }
    }
    names
  }

  .extractNames(schema$phases, include_subphases)
}

#' Get an event by name from a TaskSchema
#'
#' @param schema A TaskSchema object
#' @param event_name Name of the event to retrieve
#' @return An Event object or NULL if not found
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getEventNames()], [getPhase()], [TaskSchema()]
#'
#' @export
getEvent <- function(schema, event_name) {
  stopifnot(inherits(schema, "TaskSchema"))
  for (e in schema$events) {
    if (e$name == event_name) return(e)
  }
  NULL
}

#' Get a phase by name from a TaskSchema
#'
#' @param schema A TaskSchema object
#' @param phase_name Name of the phase to retrieve
#' @param search_subphases Whether to search within subphases
#' @return A Phase object or NULL if not found
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getPhaseNames()], [getPhaseColors()], [getEvent()]
#'
#' @export
getPhase <- function(schema, phase_name, search_subphases = TRUE) {
  stopifnot(inherits(schema, "TaskSchema"))

  .findPhase <- function(phase_list, name, search_sub) {
    for (p in phase_list) {
      if (p$name == name) return(p)
      if (search_sub && length(p$subphases) > 0) {
        found <- .findPhase(p$subphases, name, search_sub)
        if (!is.null(found)) return(found)
      }
    }
    NULL
  }

  .findPhase(schema$phases, phase_name, search_subphases)
}

#' Get phase colors from a TaskSchema
#'
#' @param schema A TaskSchema object
#' @param include_subphases Whether to include subphase colors
#' @return Named character vector of colors (phase name -> color)
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getPhaseNames()], [getPhase()], [TaskSchema()]
#'
#' @export
getPhaseColors <- function(schema, include_subphases = FALSE) {
  stopifnot(inherits(schema, "TaskSchema"))

  .extractColors <- function(phase_list, include_sub) {
    colors <- character()
    for (p in phase_list) {
      if (!is.null(p$color)) {
        colors <- c(colors, setNames(p$color, p$name))
      }
      if (include_sub && length(p$subphases) > 0) {
        colors <- c(colors, .extractColors(p$subphases, include_sub))
      }
    }
    colors
  }

  .extractColors(schema$phases, include_subphases)
}

#' Validate a TaskSchema
#'
#' Checks that a TaskSchema is internally consistent.
#'
#' @param schema A TaskSchema object
#' @return TRUE if valid, otherwise throws an error
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [getSchema()], [listSchemas()]
#'
#' @export
validateSchema <- function(schema) {
  stopifnot(inherits(schema, "TaskSchema"))

  # Check for duplicate event names
  event_names <- getEventNames(schema)
  if (anyDuplicated(event_names)) {
    dups <- event_names[duplicated(event_names)]
    stop(sprintf("Duplicate event names: %s", paste(dups, collapse = ", ")),
         call. = FALSE)
  }

  # Check for duplicate phase names
  phase_names <- getPhaseNames(schema, include_subphases = TRUE)
  if (anyDuplicated(phase_names)) {
    dups <- phase_names[duplicated(phase_names)]
    stop(sprintf("Duplicate phase names: %s", paste(dups, collapse = ", ")),
         call. = FALSE)
  }

  # Check normalization consistency
  if (schema$normalization == "landmark") {
    if (is.null(schema$vis_defaults$landmark_event)) {
      warning("Landmark normalization specified but no landmark_event in vis_defaults",
              call. = FALSE)
    }
  }

  # Check that continuous tasks have no phases/events
  if (schema$normalization == "absolute" && length(schema$phases) > 0) {
    warning("Absolute normalization with phases defined - phases may not be applicable",
            call. = FALSE)
  }

  TRUE
}
