# Normalization Functions for Movement Analysis
# Provides various time normalization methods for movement data

#' Normalize movement data
#'
#' Normalizes movement data using various methods appropriate for different
#' task types.
#'
#' @param x Data to normalize:
#'   \itemize{
#'     \item PhysioExperiment object
#'     \item Matrix (time x channels)
#'     \item segmented_phases object
#'     \item List of matrices (multiple trials)
#'   }
#' @param method Normalization method:
#'   \itemize{
#'     \item "cycle" - Normalize entire movement to fixed length (0-100%)
#'     \item "phase" - Normalize each phase independently
#'     \item "landmark" - Align to a specific event
#'     \item "dtw" - Dynamic time warping alignment
#'     \item "absolute" - Keep original time (no normalization)
#'   }
#' @param norm_length Target length after normalization (default 101 for 0-100%)
#' @param schema Optional TaskSchema for context
#' @param events Optional detected_events for landmark alignment
#' @param reference Reference trial for DTW (default: mean of all trials)
#' @param ... Additional arguments passed to specific methods
#'
#' @return Normalized data in the same format as input (or matrix for
#'   segmented_phases)
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [batchNormalize()], [normalizedTimeAxis()], [segmentPhases()]
#'
#' @export
#'
#' @examples
#' # Normalize a matrix to 101 points
#' data <- matrix(rnorm(500), nrow = 500, ncol = 3)
#' normalized <- normalizeMovement(data, method = "cycle", norm_length = 101)
normalizeMovement <- function(x,
                               method = c("cycle", "phase", "landmark",
                                          "dtw", "absolute"),
                               norm_length = 101L,
                               schema = NULL,
                               events = NULL,
                               reference = NULL,
                               ...) {

  method <- match.arg(method)

  # Get norm_length from schema if not specified
  if (is.null(norm_length) && !is.null(schema)) {
    norm_length <- schema$norm_length
  }
  norm_length <- as.integer(norm_length %||% 101L)

  # Dispatch based on method
  result <- switch(method,
    "cycle" = .normalizeCycle(x, norm_length, ...),
    "phase" = .normalizePhase(x, norm_length, schema, events, ...),
    "landmark" = .normalizeLandmark(x, norm_length, events, schema, ...),
    "dtw" = .normalizeDTW(x, norm_length, reference, ...),
    "absolute" = x,
    stop("Unknown normalization method", call. = FALSE)
  )

  # Add attributes
  attr(result, "normalization") <- method
  attr(result, "norm_length") <- norm_length

  result
}


#' Cycle normalization
#'
#' Normalizes data to a fixed number of points using linear interpolation.
#'
#' @param x Data (matrix, PhysioExperiment, or list of matrices)
#' @param norm_length Target length
#' @param ... Additional arguments (unused)
#'
#' @return Normalized data
#' @keywords internal
.normalizeCycle <- function(x, norm_length, ...) {

  # Handle different input types
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
    normalized <- .normalizeMatrix(data, norm_length)
    # Return as matrix (could also modify PhysioExperiment)
    return(normalized)
  }

  if (inherits(x, "segmented_phases")) {
    # Normalize each phase to the same length
    phase_data <- getPhaseData(x, include_subphases = FALSE)
    normalized <- lapply(phase_data, function(m) {
      .normalizeMatrix(m, norm_length)
    })
    return(normalized)
  }

  if (is.list(x)) {
    # List of matrices (multiple trials)
    return(lapply(x, function(m) .normalizeMatrix(m, norm_length)))
  }

  if (is.matrix(x)) {
    return(.normalizeMatrix(x, norm_length))
  }

  if (is.numeric(x)) {
    return(.normalizeVector(x, norm_length))
  }

  stop("Unsupported input type", call. = FALSE)
}


#' Normalize a single matrix to fixed length
#' @keywords internal
.normalizeMatrix <- function(mat, norm_length) {
  n_rows <- nrow(mat)
  n_cols <- ncol(mat)

  if (n_rows == norm_length) {
    return(mat)
  }

  # Interpolate each column
  old_x <- seq(0, 1, length.out = n_rows)
  new_x <- seq(0, 1, length.out = norm_length)

  result <- matrix(NA_real_, nrow = norm_length, ncol = n_cols)
  colnames(result) <- colnames(mat)

  for (j in seq_len(n_cols)) {
    result[, j] <- stats::approx(old_x, mat[, j], new_x, method = "linear")$y
  }

  result
}


#' Normalize a single vector to fixed length
#' @keywords internal
.normalizeVector <- function(vec, norm_length) {
  n <- length(vec)

  if (n == norm_length) {
    return(vec)
  }

  old_x <- seq(0, 1, length.out = n)
  new_x <- seq(0, 1, length.out = norm_length)

  stats::approx(old_x, vec, new_x, method = "linear")$y
}


#' Phase-based normalization
#'
#' Normalizes each phase independently to the same length.
#'
#' @param x Data (segmented_phases preferred)
#' @param norm_length Target length per phase
#' @param schema TaskSchema object
#' @param events detected_events object
#' @param ... Additional arguments
#'
#' @return Normalized data
#' @keywords internal
.normalizePhase <- function(x, norm_length, schema = NULL, events = NULL, ...) {

  if (inherits(x, "segmented_phases")) {
    # Get phase data
    phase_data <- getPhaseData(x, include_subphases = FALSE)

    if (length(phase_data) == 0) {
      warning("No phases to normalize", call. = FALSE)
      return(x)
    }

    # Normalize each phase
    normalized_phases <- lapply(phase_data, function(m) {
      .normalizeMatrix(m, norm_length)
    })

    # Combine into single matrix with phase boundaries
    combined <- do.call(rbind, normalized_phases)

    # Add phase info as attribute
    phase_names <- names(normalized_phases)
    phase_boundaries <- cumsum(c(0, rep(norm_length, length(phase_names))))
    attr(combined, "phase_boundaries") <- setNames(phase_boundaries, c("start", phase_names))
    attr(combined, "phase_names") <- phase_names

    return(combined)
  }

  # For non-segmented data, need events and schema
  if (is.null(events) || is.null(schema)) {
    warning("Phase normalization requires segmented_phases or events + schema",
            call. = FALSE)
    return(.normalizeCycle(x, norm_length))
  }

  # Segment and then normalize
  segmented <- segmentPhases(x, events, schema)
  .normalizePhase(segmented, norm_length, schema, events, ...)
}


#' Landmark-based normalization
#'
#' Aligns data to a specific event (landmark).
#'
#' @param x Data
#' @param norm_length Target length
#' @param events detected_events object
#' @param schema TaskSchema object
#' @param landmark_event Name of event to align to
#' @param window_before Samples/percent before landmark
#' @param window_after Samples/percent after landmark
#' @param ... Additional arguments
#'
#' @return Normalized data
#' @keywords internal
.normalizeLandmark <- function(x, norm_length, events = NULL, schema = NULL,
                                landmark_event = NULL, window_before = NULL,
                                window_after = NULL, ...) {

  # Get landmark event name
  if (is.null(landmark_event)) {
    if (!is.null(schema) && !is.null(schema$vis_defaults$landmark_event)) {
      landmark_event <- schema$vis_defaults$landmark_event
    } else {
      warning("No landmark event specified, using cycle normalization",
              call. = FALSE)
      return(.normalizeCycle(x, norm_length))
    }
  }

  # Get data matrix
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
  } else if (is.matrix(x)) {
    data <- x
  } else if (is.numeric(x)) {
    data <- matrix(x, ncol = 1)
  } else {
    stop("Unsupported input type for landmark normalization", call. = FALSE)
  }

  n_samples <- nrow(data)

  # Get landmark index
  if (is.null(events)) {
    warning("No events provided for landmark alignment", call. = FALSE)
    return(.normalizeCycle(data, norm_length))
  }

  landmark_idx <- events$index[events$event == landmark_event]
  if (length(landmark_idx) == 0 || is.na(landmark_idx)) {
    warning(sprintf("Landmark event '%s' not found", landmark_event),
            call. = FALSE)
    return(.normalizeCycle(data, norm_length))
  }

  # Determine window
  if (is.null(window_before)) {
    window_before <- landmark_idx - 1
  }
  if (is.null(window_after)) {
    window_after <- n_samples - landmark_idx
  }

  # Extract window around landmark
  start_idx <- max(1, landmark_idx - window_before)
  end_idx <- min(n_samples, landmark_idx + window_after)

  windowed <- data[start_idx:end_idx, , drop = FALSE]

  # Normalize to target length
  normalized <- .normalizeMatrix(windowed, norm_length)

  # Calculate landmark position in normalized data
  landmark_position <- round((landmark_idx - start_idx) /
                              (end_idx - start_idx) * (norm_length - 1)) + 1
  attr(normalized, "landmark_position") <- landmark_position

  normalized
}


#' DTW-based normalization
#'
#' Aligns data using Dynamic Time Warping.
#'
#' @param x Data (list of matrices for multiple trials)
#' @param norm_length Target length
#' @param reference Reference trial or "mean"
#' @param ... Additional arguments passed to dtwDistance
#'
#' @return Normalized data
#' @keywords internal
.normalizeDTW <- function(x, norm_length, reference = NULL, ...) {

  # Handle single trial
  if (is.matrix(x) || (is.numeric(x) && !is.list(x))) {
    return(.normalizeCycle(x, norm_length))
  }

  if (!is.list(x)) {
    stop("DTW normalization requires a list of trials", call. = FALSE)
  }

  n_trials <- length(x)

  if (n_trials == 1) {
    return(lapply(x, function(m) .normalizeMatrix(m, norm_length)))
  }

  # First normalize all trials to same length
  normalized <- lapply(x, function(m) {
    if (is.matrix(m)) .normalizeMatrix(m, norm_length)
    else .normalizeVector(m, norm_length)
  })

  # Compute reference
  if (is.null(reference) || identical(reference, "mean")) {
    # Use mean as reference
    if (is.matrix(normalized[[1]])) {
      ref <- Reduce(`+`, normalized) / n_trials
    } else {
      ref <- Reduce(`+`, normalized) / n_trials
    }
  } else if (is.numeric(reference) && reference <= n_trials) {
    ref <- normalized[[reference]]
  } else if (is.matrix(reference) || is.numeric(reference)) {
    ref <- reference
  } else {
    ref <- normalized[[1]]
  }

  # Warp each trial to reference using simple DTW
  aligned <- lapply(normalized, function(trial) {
    .dtwAlign(trial, ref)
  })

  aligned
}


#' Simple DTW alignment
#' @keywords internal
.dtwAlign <- function(query, reference) {

  if (is.matrix(query)) {
    # Multi-channel: use first channel for alignment, apply to all
    path <- .computeDTWPath(query[, 1], reference[, 1])

    # Apply warping to all channels
    result <- matrix(NA_real_, nrow = length(reference[, 1]), ncol = ncol(query))
    for (j in seq_len(ncol(query))) {
      result[, j] <- .applyWarpPath(query[, j], path, length(reference[, 1]))
    }
    colnames(result) <- colnames(query)
    return(result)
  }

  # Single channel
  path <- .computeDTWPath(query, reference)
  .applyWarpPath(query, path, length(reference))
}


#' Compute DTW path
#' @keywords internal
.computeDTWPath <- function(query, reference) {
  n <- length(query)
  m <- length(reference)

  # Cost matrix
  D <- matrix(Inf, nrow = n + 1, ncol = m + 1)
  D[1, 1] <- 0

  # Fill cost matrix
  for (i in seq_len(n)) {
    for (j in seq_len(m)) {
      cost <- abs(query[i] - reference[j])
      D[i + 1, j + 1] <- cost + min(D[i, j + 1], D[i + 1, j], D[i, j])
    }
  }

  # Backtrack to find path
  path_query <- integer()
  path_ref <- integer()
  i <- n
  j <- m

  while (i > 0 && j > 0) {
    path_query <- c(i, path_query)
    path_ref <- c(j, path_ref)

    candidates <- c(D[i, j + 1], D[i + 1, j], D[i, j])
    step <- which.min(candidates)

    if (step == 1) {
      i <- i - 1
    } else if (step == 2) {
      j <- j - 1
    } else {
      i <- i - 1
      j <- j - 1
    }
  }

  list(query = path_query, reference = path_ref)
}


#' Apply warp path to data
#' @keywords internal
.applyWarpPath <- function(data, path, target_length) {
  # Map query indices to reference indices
  mapping <- stats::approx(
    x = path$query,
    y = path$reference,
    xout = seq_len(length(data)),
    method = "linear",
    rule = 2
  )$y

  # Interpolate to target length
  stats::approx(
    x = mapping,
    y = data,
    xout = seq_len(target_length),
    method = "linear",
    rule = 2
  )$y
}


#' Time axis for normalized data
#'
#' Generates an appropriate time axis for normalized data.
#'
#' @param norm_length Length of normalized data
#' @param method Normalization method used
#' @param unit Output unit ("percent", "normalized", "degrees")
#'
#' @return Numeric vector of time values
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [normalizeMovement()], [batchNormalize()], [segmentPhases()]
#'
#' @export
#'
#' @examples
#' # 0-100% axis
#' t_pct <- normalizedTimeAxis(101, method = "cycle", unit = "percent")
#'
#' # 0-360 degrees for cycling
#' t_deg <- normalizedTimeAxis(361, method = "cycle", unit = "degrees")
normalizedTimeAxis <- function(norm_length,
                                method = "cycle",
                                unit = c("percent", "normalized", "degrees")) {
  unit <- match.arg(unit)

  switch(unit,
    percent = seq(0, 100, length.out = norm_length),
    normalized = seq(0, 1, length.out = norm_length),
    degrees = seq(0, 360, length.out = norm_length)
  )
}


#' Batch normalize multiple trials
#'
#' Normalizes multiple trials and returns them in a consistent format.
#'
#' @param trials List of matrices or PhysioExperiment objects
#' @param method Normalization method
#' @param norm_length Target length
#' @param schema Optional TaskSchema
#' @param ... Additional arguments
#'
#' @return 3D array (time x channels x trials) or list
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [normalizeMovement()], [normalizedTimeAxis()], [combineTrials()]
#'
#' @export
batchNormalize <- function(trials,
                           method = "cycle",
                           norm_length = 101L,
                           schema = NULL,
                           ...) {

  # Normalize each trial
  normalized <- lapply(trials, function(trial) {
    normalizeMovement(trial, method = method, norm_length = norm_length,
                      schema = schema, ...)
  })

  # Try to combine into 3D array
  if (all(vapply(normalized, is.matrix, logical(1)))) {
    dims <- lapply(normalized, dim)
    if (length(unique(dims)) == 1) {
      # All same dimensions
      n_time <- dims[[1]][1]
      n_channels <- dims[[1]][2]
      n_trials <- length(normalized)

      result <- array(NA_real_, dim = c(n_time, n_channels, n_trials))
      for (i in seq_len(n_trials)) {
        result[, , i] <- normalized[[i]]
      }

      # Add dimnames
      dimnames(result) <- list(
        time = NULL,
        channel = colnames(normalized[[1]]),
        trial = names(trials) %||% paste0("trial_", seq_len(n_trials))
      )

      return(result)
    }
  }

  # Return as list if can't combine
  normalized
}
