# Event Detection Functions for Movement Analysis
# Provides automatic and manual event detection based on TaskSchema definitions

#' Detect events in movement data
#'
#' Automatically detects events defined in a TaskSchema based on signal data.
#'
#' @param x PhysioExperiment object or matrix (time x channels)
#' @param schema TaskSchema object defining events to detect
#' @param signals Named list of signal vectors for detection. If NULL and x is
#'   a PhysioExperiment, signals are extracted from column names. If x is a
#'   matrix with named columns, signals are auto-created from those names;
#'   otherwise provide `signals` explicitly.
#' @param method Detection approach:
#'   \itemize{
#'     \item "auto" - Automatic detection using schema definitions
#'     \item "manual" - Use typical_timing from schema as event times
#'     \item "hybrid" - Try auto first, fall back to typical_timing if failed
#'   }
#' @param sampling_rate Sampling rate in Hz. Required if x is a matrix.
#' @param ... Additional arguments passed to detection methods
#'
#' @return A data.frame with columns:
#'   \itemize{
#'     \item event - Event name
#'     \item label - Human-readable label
#'     \item index - Sample index of event
#'     \item time - Time in seconds
#'     \item percent - Percent of movement (if applicable)
#'     \item method - Detection method used
#'     \item confidence - Detection confidence (0-1)
#'   }
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [manualEvents()], [segmentPhases()], [TaskSchema()]
#'
#' @export
#'
#' @examples
#' # Create synthetic gait data
#' set.seed(123)
#' n <- 1000
#' t <- seq(0, 1, length.out = n)
#' vGRF <- c(rep(0, 100), sin(seq(0, pi, length.out = 500)) * 800, rep(0, 400))
#' vGRF <- vGRF + rnorm(n, 0, 10)
#'
#' signals <- list(vGRF = vGRF)
#' events <- detectEvents(as.matrix(vGRF), schema_gait,
#'                        signals = signals, sampling_rate = 1000)
detectEvents <- function(x,
                         schema,
                         signals = NULL,
                         method = c("auto", "manual", "hybrid", "zeni"),
                         sampling_rate = NULL,
                         ...) {

  method <- match.arg(method)
  stopifnot(inherits(schema, "TaskSchema"))

  # Zeni coordinate method: needs marker positions and produces multi-stride
  # events directly (bypasses the per-schema-event loop below).
  if (method == "zeni") {
    if (!inherits(x, "PhysioExperiment")) {
      stop("method = 'zeni' requires a PhysioExperiment with marker position ",
           "assays.", call. = FALSE)
    }
    sr <- if (!is.null(sampling_rate)) sampling_rate else samplingRate(x)
    ev <- detectEventsZeni(x, sampling_rate = sr, ...)
    attr(ev, "schema") <- schema$task_type
    return(ev)
  }

  # Handle PhysioExperiment input
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
    sr <- samplingRate(x)
    if (is.null(signals)) {
      # Try to create signals from column names
      col_names <- colnames(data)
      if (!is.null(col_names)) {
        signals <- setNames(
          lapply(seq_len(ncol(data)), function(i) data[, i]),
          col_names
        )
      }
    }
  } else if (is.matrix(x) || is.numeric(x)) {
    if (is.numeric(x) && !is.matrix(x)) {
      data <- matrix(x, ncol = 1)
    } else {
      data <- x
    }
    if (is.null(sampling_rate)) {
      stop(
        "sampling_rate is required when 'x' is a matrix/vector input.\n",
        "Example: detectEvents(x, schema, sampling_rate = 1000).",
        call. = FALSE
      )
    }
    sr <- sampling_rate

    if (is.null(signals)) {
      col_names <- colnames(data)
      if (!is.null(col_names) && all(nzchar(col_names))) {
        signals <- setNames(
          lapply(seq_len(ncol(data)), function(i) data[, i]),
          col_names
        )
      } else if (ncol(data) == 1) {
        signals <- list(signal = data[, 1])
      } else {
        expected_signals <- unique(vapply(schema$events, function(evt) {
          if (!is.null(evt$detection_params$signal)) {
            as.character(evt$detection_params$signal)
          } else {
            NA_character_
          }
        }, character(1)))
        expected_signals <- expected_signals[!is.na(expected_signals) & nzchar(expected_signals)]

        hint <- if (length(expected_signals) > 0) {
          paste0("Expected signal names from schema: ",
                 paste(expected_signals, collapse = ", "), ".")
        } else {
          "Schema does not define signal names; you may pass any named signals list."
        }

        stop(
          "When 'x' is a multi-column matrix, provide 'signals' as a named list ",
          "or set matrix column names.\n",
          hint,
          call. = FALSE
        )
      }
    }
  } else {
    stop("x must be a PhysioExperiment, numeric vector, or matrix.", call. = FALSE)
  }

  n_samples <- nrow(data)
  total_time <- n_samples / sr

  # Handle schemas with no events
  if (length(schema$events) == 0) {
    empty_df <- data.frame(
      event = character(),
      label = character(),
      index = integer(),
      time = numeric(),
      percent = numeric(),
      method = character(),
      confidence = numeric(),
      stringsAsFactors = FALSE
    )
    class(empty_df) <- c("detected_events", "data.frame")
    attr(empty_df, "schema") <- schema$task_type
    attr(empty_df, "sampling_rate") <- sr
    attr(empty_df, "n_samples") <- n_samples
    return(empty_df)
  }

  # Detect each event
  results <- lapply(schema$events, function(evt) {
    detected <- .detectSingleEvent(
      evt = evt,
      signals = signals,
      data = data,
      n_samples = n_samples,
      sr = sr,
      method = method,
      ...
    )

    data.frame(
      event = evt$name,
      label = evt$label,
      index = detected$index,
      time = detected$time,
      percent = (detected$index - 1) / (n_samples - 1) * 100,
      method = detected$method,
      confidence = detected$confidence,
      stringsAsFactors = FALSE
    )
  })

  result_df <- do.call(rbind, results)
  rownames(result_df) <- NULL

  # Sort by index
  result_df <- result_df[order(result_df$index), ]

  class(result_df) <- c("detected_events", "data.frame")
  attr(result_df, "schema") <- schema$task_type
  attr(result_df, "sampling_rate") <- sr
  attr(result_df, "n_samples") <- n_samples

  result_df
}


#' Detect a single event
#' @keywords internal
.detectSingleEvent <- function(evt, signals, data, n_samples, sr, method, ...) {

  # Default fallback using typical timing
  default_result <- function(use_method = "typical") {
    if (!is.null(evt$typical_timing)) {
      idx <- round(evt$typical_timing / 100 * (n_samples - 1)) + 1
      idx <- max(1, min(n_samples, idx))
      list(
        index = idx,
        time = (idx - 1) / sr,
        method = use_method,
        confidence = 0.5
      )
    } else {
      list(
        index = NA_integer_,
        time = NA_real_,
        method = "failed",
        confidence = 0
      )
    }
  }

  # Manual method
  if (method == "manual") {
    return(default_result("manual"))
  }

  # Try automatic detection
  auto_result <- tryCatch({
    .detectByMethod(evt, signals, data, n_samples, sr, ...)
  }, error = function(e) {
    NULL
  })

  # Return result based on method
  if (method == "auto") {
    if (is.null(auto_result) || is.na(auto_result$index)) {
      return(default_result("auto_fallback"))
    }
    return(auto_result)
  }

  # Hybrid: try auto, fall back to typical
  if (method == "hybrid") {
    if (!is.null(auto_result) && !is.na(auto_result$index)) {
      return(auto_result)
    }
    return(default_result("hybrid_fallback"))
  }

  default_result("unknown")
}


#' Detect event by specified method
#' @keywords internal
.detectByMethod <- function(evt, signals, data, n_samples, sr, ...) {

  params <- evt$detection_params
  dm <- evt$detection_method

  # Get the signal
  signal <- NULL
  if (!is.null(params$signal) && !is.null(signals)) {
    if (params$signal %in% names(signals)) {
      signal <- signals[[params$signal]]
    }
  }

  # If no specific signal, use first column of data
  if (is.null(signal) && !is.null(data)) {
    signal <- data[, 1]
  }

  if (is.null(signal)) {
    return(list(index = NA_integer_, time = NA_real_,
                method = dm, confidence = 0))
  }

  result <- switch(dm,
    "threshold" = .detectThreshold(
      signal = signal,
      threshold = params$threshold,
      direction = params$direction %||% "rising",
      sr = sr
    ),
    "peak" = .detectPeak(
      signal = signal,
      type = params$type %||% "max",
      prominence = params$prominence,
      sr = sr
    ),
    "zero_crossing" = .detectZeroCrossing(
      signal = signal,
      direction = params$direction %||% "any",
      sr = sr
    ),
    "angle" = .detectAngle(
      signal = signal,
      value = params$value,
      sr = sr
    ),
    "velocity_threshold" = .detectVelocityThreshold(
      signal = signal,
      threshold = params$threshold,
      direction = params$direction %||% "rising",
      sr = sr
    ),
    "manual" = list(index = NA_integer_, time = NA_real_,
                    method = "manual", confidence = 0),
    list(index = NA_integer_, time = NA_real_,
         method = "unknown", confidence = 0)
  )

  result$method <- dm
  result
}


#' Threshold-based event detection
#'
#' Detects when a signal crosses a threshold value.
#'
#' @param signal Numeric vector
#' @param threshold Threshold value (numeric or "bw-X%" for body weight relative)
#' @param direction "rising" (crosses from below), "falling" (crosses from above),
#'   or "any"
#' @param sr Sampling rate
#' @param min_duration Minimum duration above/below threshold (seconds)
#'
#' @return List with index, time, confidence
#' @keywords internal
.detectThreshold <- function(signal, threshold, direction = "rising",
                             sr = 1000, min_duration = 0.01) {

  n <- length(signal)

  # Handle body weight relative threshold
  if (is.character(threshold) && grepl("^bw", threshold)) {
    # Parse "bw-10%" or "bw+10%" format
    bw_match <- regmatches(threshold, regexec("bw([+-]?)(\\d+)%?", threshold))[[1]]
    if (length(bw_match) >= 3) {
      sign <- ifelse(bw_match[2] == "-", -1, 1)
      pct <- as.numeric(bw_match[3])
      # Estimate body weight as mean of middle portion
      mid_start <- round(n * 0.4)
      mid_end <- round(n * 0.6)
      bw <- mean(signal[mid_start:mid_end], na.rm = TRUE)
      threshold <- bw + sign * (bw * pct / 100)
    } else {
      threshold <- 0
    }
  }
  threshold <- as.numeric(threshold)

  # Find crossings
  above <- signal > threshold
  crossings <- which(diff(above) != 0) + 1

  if (length(crossings) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Filter by direction
  if (direction == "rising") {
    crossings <- crossings[signal[crossings] > signal[crossings - 1]]
  } else if (direction == "falling") {
    crossings <- crossings[signal[crossings] < signal[crossings - 1]]
  }

  if (length(crossings) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Take first valid crossing
  idx <- crossings[1]

  list(
    index = as.integer(idx),
    time = (idx - 1) / sr,
    confidence = 0.9
  )
}


#' Peak-based event detection
#'
#' Detects local maxima or minima in a signal.
#'
#' @param signal Numeric vector
#' @param type "max" for maximum, "min" for minimum
#' @param prominence Minimum prominence of peak (NULL for global max/min)
#' @param sr Sampling rate
#'
#' @return List with index, time, confidence
#' @keywords internal
.detectPeak <- function(signal, type = "max", prominence = NULL, sr = 1000) {

  n <- length(signal)

  if (is.null(prominence)) {
    # Find global max/min
    if (type == "max") {
      idx <- which.max(signal)
    } else {
      idx <- which.min(signal)
    }
    return(list(
      index = as.integer(idx),
      time = (idx - 1) / sr,
      confidence = 0.95
    ))
  }

  # Find local peaks with prominence
  peaks <- .findLocalPeaks(signal, type)

  if (length(peaks) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Filter by prominence
  prominences <- .calculateProminence(signal, peaks, type)
  valid_peaks <- peaks[prominences >= prominence]

  if (length(valid_peaks) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Return first prominent peak
  idx <- valid_peaks[1]

  list(
    index = as.integer(idx),
    time = (idx - 1) / sr,
    confidence = 0.85
  )
}


#' Find local peaks
#' @keywords internal
.findLocalPeaks <- function(signal, type = "max") {
  n <- length(signal)
  if (n < 3) return(integer())

  if (type == "max") {
    peaks <- which(
      signal[2:(n-1)] > signal[1:(n-2)] &
      signal[2:(n-1)] > signal[3:n]
    ) + 1
  } else {
    peaks <- which(
      signal[2:(n-1)] < signal[1:(n-2)] &
      signal[2:(n-1)] < signal[3:n]
    ) + 1
  }

  peaks
}


#' Calculate peak prominence
#' @keywords internal
.calculateProminence <- function(signal, peaks, type = "max") {
  vapply(peaks, function(pk) {
    left_base <- if (pk > 1) {
      if (type == "max") min(signal[1:(pk-1)]) else max(signal[1:(pk-1)])
    } else {
      signal[pk]
    }
    right_base <- if (pk < length(signal)) {
      if (type == "max") min(signal[(pk+1):length(signal)]) else max(signal[(pk+1):length(signal)])
    } else {
      signal[pk]
    }

    base <- if (type == "max") max(left_base, right_base) else min(left_base, right_base)

    abs(signal[pk] - base)
  }, numeric(1))
}


#' Zero-crossing detection
#'
#' Detects when a signal crosses zero.
#'
#' @param signal Numeric vector
#' @param direction "rising", "falling", or "any"
#' @param sr Sampling rate
#'
#' @return List with index, time, confidence
#' @keywords internal
.detectZeroCrossing <- function(signal, direction = "any", sr = 1000) {

  n <- length(signal)

  # Find sign changes
  signs <- sign(signal)
  sign_changes <- which(diff(signs) != 0)

  if (length(sign_changes) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Filter by direction
  if (direction == "rising") {
    sign_changes <- sign_changes[signs[sign_changes + 1] > signs[sign_changes]]
  } else if (direction == "falling") {
    sign_changes <- sign_changes[signs[sign_changes + 1] < signs[sign_changes]]
  }

  if (length(sign_changes) == 0) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  # Interpolate to find exact crossing
  idx <- sign_changes[1]
  # Linear interpolation
  if (signal[idx] != signal[idx + 1]) {
    frac <- -signal[idx] / (signal[idx + 1] - signal[idx])
    exact_idx <- idx + frac
  } else {
    exact_idx <- idx
  }

  list(
    index = as.integer(round(exact_idx)),
    time = (exact_idx - 1) / sr,
    confidence = 0.85
  )
}


#' Angle-based event detection
#'
#' Detects when an angular signal reaches a specific value.
#'
#' @param signal Numeric vector (angle in degrees)
#' @param value Target angle value
#' @param sr Sampling rate
#' @param tolerance Tolerance for matching (degrees)
#'
#' @return List with index, time, confidence
#' @keywords internal
.detectAngle <- function(signal, value, sr = 1000, tolerance = 5) {

  n <- length(signal)

  # Normalize to 0-360 range
  signal_norm <- signal %% 360
  value_norm <- value %% 360

  # Find closest point to target angle
  diff_angle <- abs(signal_norm - value_norm)
  diff_angle <- pmin(diff_angle, 360 - diff_angle)  # Handle wraparound

  idx <- which.min(diff_angle)

  if (diff_angle[idx] > tolerance) {
    return(list(index = NA_integer_, time = NA_real_, confidence = 0))
  }

  list(
    index = as.integer(idx),
    time = (idx - 1) / sr,
    confidence = 1 - diff_angle[idx] / tolerance
  )
}


#' Velocity threshold detection
#'
#' Detects when the derivative of a signal crosses a threshold.
#'
#' @param signal Numeric vector
#' @param threshold Velocity threshold
#' @param direction "rising" or "falling"
#' @param sr Sampling rate
#'
#' @return List with index, time, confidence
#' @keywords internal
.detectVelocityThreshold <- function(signal, threshold, direction = "rising",
                                     sr = 1000) {
  # Compute velocity (derivative)
  velocity <- c(0, diff(signal) * sr)

  # Use threshold detection on velocity
  .detectThreshold(velocity, threshold, direction, sr)
}


#' Print method for detected events
#' @param x A detected_events object
#' @param ... Additional arguments (unused)
#' @export
print.detected_events <- function(x, ...) {
  cat("Detected Events\n")
  cat("Schema:", attr(x, "schema"), "\n")
  cat("Sampling rate:", attr(x, "sampling_rate"), "Hz\n")
  cat("Total samples:", attr(x, "n_samples"), "\n")
  cat("\n")

  if (nrow(x) == 0) {
    cat("No events detected\n")
  } else {
    print.data.frame(x, row.names = FALSE)
  }

  invisible(x)
}


#' Manually specify event times
#'
#' Create a detected_events object from manually specified times or indices.
#'
#' @param schema TaskSchema object
#' @param times Named numeric vector of event times in seconds
#' @param indices Named integer vector of event indices
#' @param sampling_rate Sampling rate (required if using times)
#' @param n_samples Total number of samples (required)
#'
#' @return A detected_events data.frame
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [detectEvents()], [segmentPhases()], [TaskSchema()]
#'
#' @export
#'
#' @examples
#' events <- manualEvents(
#'   schema_gait,
#'   times = c(hs1 = 0, to = 0.6, hs2 = 1.0),
#'   sampling_rate = 1000,
#'   n_samples = 1000
#' )
manualEvents <- function(schema,
                         times = NULL,
                         indices = NULL,
                         sampling_rate = NULL,
                         n_samples) {

  stopifnot(inherits(schema, "TaskSchema"))
  stopifnot(!is.null(times) || !is.null(indices))
  stopifnot(is.numeric(n_samples), n_samples > 0)

  if (!is.null(times) && is.null(sampling_rate)) {
    stop("sampling_rate required when specifying times", call. = FALSE)
  }

  sr <- sampling_rate %||% 1000

  # Build results for each event in schema
  results <- lapply(schema$events, function(evt) {
    idx <- NA_integer_
    tm <- NA_real_

    # Check if event is specified
    if (!is.null(indices) && evt$name %in% names(indices)) {
      idx <- as.integer(indices[[evt$name]])
      tm <- (idx - 1) / sr
    } else if (!is.null(times) && evt$name %in% names(times)) {
      tm <- times[[evt$name]]
      idx <- as.integer(round(tm * sr) + 1)
    } else if (!is.null(evt$typical_timing)) {
      # Fall back to typical timing
      idx <- round(evt$typical_timing / 100 * (n_samples - 1)) + 1
      idx <- as.integer(max(1, min(n_samples, idx)))
      tm <- (idx - 1) / sr
    }

    data.frame(
      event = evt$name,
      label = evt$label,
      index = idx,
      time = tm,
      percent = if (!is.na(idx)) (idx - 1) / (n_samples - 1) * 100 else NA_real_,
      method = "manual",
      confidence = if (!is.na(idx)) 1.0 else 0.0,
      stringsAsFactors = FALSE
    )
  })

  result_df <- do.call(rbind, results)
  rownames(result_df) <- NULL

  result_df <- result_df[order(result_df$index), ]

  class(result_df) <- c("detected_events", "data.frame")
  attr(result_df, "schema") <- schema$task_type
  attr(result_df, "sampling_rate") <- sr
  attr(result_df, "n_samples") <- as.integer(n_samples)

  result_df
}


#' Null coalescing operator
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a
