# Marker Tracking for Motion Capture Data
# Resolves frame-by-frame label reassignment (e.g. Venus3D random labels)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Compute Euclidean distance cost matrix between reference and current positions
#'
#' @param ref_pos Matrix of reference positions (n_ref x 3), columns are x, y, z.
#' @param cur_pos Matrix of current positions (n_cur x 3), columns are x, y, z.
#' @return Matrix (n_ref x n_cur) of Euclidean distances.
#' @noRd
.euclidean_cost_matrix <- function(ref_pos, cur_pos) {
  n_ref <- nrow(ref_pos)
  n_cur <- nrow(cur_pos)
  # Vectorised distance computation
  cost <- matrix(NA_real_, nrow = n_ref, ncol = n_cur)
  for (j in seq_len(n_cur)) {
    dx <- ref_pos[, 1] - cur_pos[j, 1]
    dy <- ref_pos[, 2] - cur_pos[j, 2]
    dz <- ref_pos[, 3] - cur_pos[j, 3]
    cost[, j] <- sqrt(dx^2 + dy^2 + dz^2)
  }
  cost
}


#' Pad a rectangular cost matrix to square with dummy high-cost entries
#'
#' @param cost Rectangular cost matrix (n_ref x n_cur).
#' @param n_max Target dimension (max of n_ref, n_cur).
#' @return Square matrix (n_max x n_max).
#' @noRd
.pad_cost_matrix <- function(cost, n_max) {
  n_ref <- nrow(cost)
  n_cur <- ncol(cost)
  if (n_ref == n_max && n_cur == n_max) return(cost)

  dummy_cost <- 1e12
  padded <- matrix(dummy_cost, nrow = n_max, ncol = n_max)
  padded[seq_len(n_ref), seq_len(n_cur)] <- cost
  padded
}


#' Greedy assignment fallback when clue is not available
#'
#' Simple greedy matching: iteratively pick the minimum-cost pair.
#' Not optimal but works as a fallback.
#'
#' @param cost Square cost matrix (n x n).
#' @return Integer vector of length n: `assignment[i]` = column assigned to row i.
#' @noRd
.greedy_assignment <- function(cost) {
  n <- nrow(cost)
  assignment <- rep(NA_integer_, n)
  used_cols <- logical(n)

  for (iter in seq_len(n)) {
    # Find minimum among unassigned
    best_val <- Inf
    best_r <- NA_integer_
    best_c <- NA_integer_
    for (r in seq_len(n)) {
      if (!is.na(assignment[r])) next
      for (cc in seq_len(n)) {
        if (used_cols[cc]) next
        if (cost[r, cc] < best_val) {
          best_val <- cost[r, cc]
          best_r <- r
          best_c <- cc
        }
      }
    }
    if (is.na(best_r)) break
    assignment[best_r] <- best_c
    used_cols[best_c] <- TRUE
  }
  assignment
}


# ---------------------------------------------------------------------------
# trackMarkers
# ---------------------------------------------------------------------------

#' Track Markers Across Frames
#'
#' Resolves inconsistent marker labelling across frames by establishing
#' frame-to-frame correspondences using the Hungarian algorithm.
#' This is essential for Venus3D data where marker IDs are randomly
#' reassigned each frame.
#'
#' @param pe A PhysioExperiment with `position_x`, `position_y`, `position_z`
#'   assays (frames x markers).
#' @param method Assignment method: `"hungarian"` (optimal, requires the
#'   `clue` package) or `"greedy"` (fast approximate). Default `"hungarian"`.
#' @param max_distance Maximum allowed assignment distance. Assignments
#'   exceeding this threshold are set to `NA`. Default `Inf` (no limit).
#' @param use_prediction Logical. If `TRUE`, use linear velocity prediction
#'   for the reference positions instead of raw previous-frame positions.
#'   Improves tracking of fast-moving markers. Default `FALSE`.
#' @param assay_prefix Prefix for position assay names. Default `"position"`.
#'
#' @return A PhysioExperiment where columns consistently correspond to the
#'   same physical marker across all frames. The `metadata$tracking` list
#'   contains:
#'   \describe{
#'     \item{assignment}{Integer matrix (frames x markers) of column indices
#'       from the original data used at each frame.}
#'     \item{cost}{Numeric matrix (frames x markers) of assignment costs
#'       (Euclidean distances) at each frame.}
#'     \item{method}{Character string indicating the method used.}
#'   }
#'
#' @details
#' The algorithm:
#' \enumerate{
#'   \item Frame 1 defines the reference labelling.
#'   \item For each subsequent frame, a Euclidean distance cost matrix is
#'     computed between reference positions and observed positions.
#'   \item The cost matrix is solved via `clue::solve_LSAP()` (Hungarian
#'     algorithm) or a greedy heuristic.
#'   \item If marker counts differ between frames, the cost matrix is padded
#'     with dummy entries (cost = 1e12).
#'   \item Assignments exceeding `max_distance` are marked as `NA`.
#'   \item With `use_prediction = TRUE`, reference positions are extrapolated
#'     using velocity from the two preceding frames.
#' }
#'
#' @examples
#' \dontrun{
#' pe <- readVenus3D("capture.csv")
#' pe_tracked <- trackMarkers(pe)
#'
#' # With velocity prediction for fast movements
#' pe_tracked <- trackMarkers(pe, use_prediction = TRUE, max_distance = 50)
#' }
#'
#' @references
#' Kuhn HW (1955). "The Hungarian Method for the Assignment Problem."
#' Naval Research Logistics Quarterly, 2(1-2), 83-97.
#'
#' @seealso [readVenus3D()] for reading Venus3D data, [detectSwaps()] and
#'   [correctSwaps()] for post-tracking swap repair.
#'
#' @export
trackMarkers <- function(pe,
                         method = "hungarian",
                         max_distance = Inf,
                         use_prediction = FALSE,
                         assay_prefix = "position") {
  stopifnot(inherits(pe, "PhysioExperiment"))
  method <- match.arg(method, c("hungarian", "greedy"))

  ax <- paste0(assay_prefix, "_x")
  ay <- paste0(assay_prefix, "_y")
  az <- paste0(assay_prefix, "_z")

  if (!all(c(ax, ay, az) %in% SummarizedExperiment::assayNames(pe))) {
    stop(
      "Required assays not found: ", ax, ", ", ay, ", ", az,
      call. = FALSE
    )
  }

  pos_x <- SummarizedExperiment::assay(pe, ax)
  pos_y <- SummarizedExperiment::assay(pe, ay)
  pos_z <- SummarizedExperiment::assay(pe, az)

  n_frames <- nrow(pos_x)
  n_markers <- ncol(pos_x)

  if (n_frames < 2) return(pe)

  # Check clue availability for Hungarian method
  use_clue <- FALSE
  if (method == "hungarian") {
    if (requireNamespace("clue", quietly = TRUE)) {
      use_clue <- TRUE
    } else {
      warning(
        "Package 'clue' not available. Falling back to greedy assignment.",
        call. = FALSE
      )
    }
  }

  # Output matrices (reordered)
  out_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  out_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  out_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  # Tracking records
  assignment_mat <- matrix(NA_integer_, nrow = n_frames, ncol = n_markers)
  cost_mat <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  # Frame 1: identity mapping (defines reference)
  out_x[1, ] <- pos_x[1, ]
  out_y[1, ] <- pos_y[1, ]
  out_z[1, ] <- pos_z[1, ]
  assignment_mat[1, ] <- seq_len(n_markers)
  cost_mat[1, ] <- 0

  # Previous frame positions for prediction
  prev_x <- pos_x[1, ]
  prev_y <- pos_y[1, ]
  prev_z <- pos_z[1, ]
  prev2_x <- NULL
  prev2_y <- NULL
  prev2_z <- NULL

  for (t in 2:n_frames) {
    # Current frame observed positions
    cur_x <- pos_x[t, ]
    cur_y <- pos_y[t, ]
    cur_z <- pos_z[t, ]

    # Reference positions (tracked previous frame)
    ref_x <- out_x[t - 1, ]
    ref_y <- out_y[t - 1, ]
    ref_z <- out_z[t - 1, ]

    # Velocity prediction
    if (use_prediction && t >= 3) {
      ref2_x <- out_x[t - 2, ]
      ref2_y <- out_y[t - 2, ]
      ref2_z <- out_z[t - 2, ]

      # Linear extrapolation: pos_predicted = pos_prev + (pos_prev - pos_prev2)
      valid <- !is.na(ref_x) & !is.na(ref2_x)
      if (any(valid)) {
        ref_x[valid] <- 2 * ref_x[valid] - ref2_x[valid]
        ref_y[valid] <- 2 * ref_y[valid] - ref2_y[valid]
        ref_z[valid] <- 2 * ref_z[valid] - ref2_z[valid]
      }
    }

    # Identify valid (non-NA) markers in reference and current
    ref_valid <- !is.na(ref_x)
    cur_valid <- !is.na(cur_x)

    n_ref_valid <- sum(ref_valid)
    n_cur_valid <- sum(cur_valid)

    if (n_ref_valid == 0 || n_cur_valid == 0) {
      # All NA — carry forward NA
      out_x[t, ] <- NA_real_
      out_y[t, ] <- NA_real_
      out_z[t, ] <- NA_real_
      assignment_mat[t, ] <- NA_integer_
      cost_mat[t, ] <- NA_real_
      next
    }

    ref_idx <- which(ref_valid)
    cur_idx <- which(cur_valid)

    # Build position matrices for cost computation
    ref_pos <- cbind(ref_x[ref_idx], ref_y[ref_idx], ref_z[ref_idx])
    cur_pos <- cbind(cur_x[cur_idx], cur_y[cur_idx], cur_z[cur_idx])

    cost <- .euclidean_cost_matrix(ref_pos, cur_pos)

    # Pad to square if needed
    n_max <- max(n_ref_valid, n_cur_valid)
    cost_sq <- .pad_cost_matrix(cost, n_max)

    # Solve assignment
    if (use_clue) {
      sol <- clue::solve_LSAP(cost_sq)
      assignment <- as.integer(sol)
    } else {
      assignment <- .greedy_assignment(cost_sq)
    }

    # Map back to full marker indices and apply
    for (i in seq_along(ref_idx)) {
      ri <- ref_idx[i]     # original reference marker index
      ai <- assignment[i]  # assigned column in cost matrix

      if (ai > n_cur_valid) {
        # Assigned to dummy → marker lost
        out_x[t, ri] <- NA_real_
        out_y[t, ri] <- NA_real_
        out_z[t, ri] <- NA_real_
        assignment_mat[t, ri] <- NA_integer_
        cost_mat[t, ri] <- NA_real_
      } else {
        ci <- cur_idx[ai]  # original current marker index
        d <- cost[i, ai]

        if (d > max_distance) {
          out_x[t, ri] <- NA_real_
          out_y[t, ri] <- NA_real_
          out_z[t, ri] <- NA_real_
          assignment_mat[t, ri] <- ci
          cost_mat[t, ri] <- d
        } else {
          out_x[t, ri] <- cur_x[ci]
          out_y[t, ri] <- cur_y[ci]
          out_z[t, ri] <- cur_z[ci]
          assignment_mat[t, ri] <- ci
          cost_mat[t, ri] <- d
        }
      }
    }

    # Reference markers that were NA remain NA
    na_refs <- which(!ref_valid)
    for (ri in na_refs) {
      out_x[t, ri] <- NA_real_
      out_y[t, ri] <- NA_real_
      out_z[t, ri] <- NA_real_
      assignment_mat[t, ri] <- NA_integer_
      cost_mat[t, ri] <- NA_real_
    }
  }

  # Apply column names
  cnames <- colnames(pos_x)
  colnames(out_x) <- cnames
  colnames(out_y) <- cnames
  colnames(out_z) <- cnames
  colnames(assignment_mat) <- cnames
  colnames(cost_mat) <- cnames

  # Build output PhysioExperiment
  SummarizedExperiment::assay(pe, ax) <- out_x
  SummarizedExperiment::assay(pe, ay) <- out_y
  SummarizedExperiment::assay(pe, az) <- out_z

  md <- S4Vectors::metadata(pe)
  md$tracking <- list(
    assignment = assignment_mat,
    cost = cost_mat,
    method = if (use_clue) "hungarian" else "greedy"
  )
  S4Vectors::metadata(pe) <- md

  pe
}


# ---------------------------------------------------------------------------
# detectSwaps
# ---------------------------------------------------------------------------

#' Detect Marker Label Swaps
#'
#' Identifies frames where two or more marker trajectories abruptly swap
#' positions, indicating a labelling error. Swaps are detected by velocity
#' spikes that exceed `median + 5 * MAD` and show a cross-over pattern
#' between marker pairs.
#'
#' @param pe A PhysioExperiment with position assays.
#' @param threshold Velocity threshold for spike detection. If `NULL`
#'   (default), computed as `median + 5 * MAD` of each marker's velocity.
#' @param window Number of frames around a spike to check for cross-over
#'   patterns. Default 5.
#' @param assay_prefix Prefix for position assay names. Default `"position"`.
#'
#' @return A `data.frame` with columns:
#' \describe{
#'   \item{frame}{Frame index where the swap was detected.}
#'   \item{marker_a}{Name or index of the first marker in the swap pair.}
#'   \item{marker_b}{Name or index of the second marker.}
#'   \item{velocity_a}{Velocity of marker_a at the swap frame.}
#'   \item{velocity_b}{Velocity of marker_b at the swap frame.}
#'   \item{confidence}{Confidence score (0-1) based on how closely the
#'     cross-over distances match.}
#' }
#'
#' If no swaps are detected, an empty data.frame with the same columns is
#' returned.
#'
#' @examples
#' \dontrun{
#' pe <- readVenus3D("capture.csv")
#' pe_tracked <- trackMarkers(pe)
#' swaps <- detectSwaps(pe_tracked)
#' if (nrow(swaps) > 0) {
#'   pe_fixed <- correctSwaps(pe_tracked, swaps)
#' }
#' }
#'
#' @seealso [trackMarkers()], [correctSwaps()]
#'
#' @export
detectSwaps <- function(pe,
                        threshold = NULL,
                        window = 5,
                        assay_prefix = "position") {
  stopifnot(inherits(pe, "PhysioExperiment"))

  ax <- paste0(assay_prefix, "_x")
  ay <- paste0(assay_prefix, "_y")
  az <- paste0(assay_prefix, "_z")

  pos_x <- SummarizedExperiment::assay(pe, ax)
  pos_y <- SummarizedExperiment::assay(pe, ay)
  pos_z <- SummarizedExperiment::assay(pe, az)

  n_frames <- nrow(pos_x)
  n_markers <- ncol(pos_x)
  marker_names <- colnames(pos_x)
  if (is.null(marker_names)) marker_names <- seq_len(n_markers)

  empty_result <- data.frame(
    frame = integer(0),
    marker_a = character(0),
    marker_b = character(0),
    velocity_a = numeric(0),
    velocity_b = numeric(0),
    confidence = numeric(0),
    stringsAsFactors = FALSE
  )

  if (n_frames < 3) return(empty_result)

  # Compute frame-to-frame velocities (Euclidean distance)
  vel <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  for (t in 2:n_frames) {
    dx <- pos_x[t, ] - pos_x[t - 1, ]
    dy <- pos_y[t, ] - pos_y[t - 1, ]
    dz <- pos_z[t, ] - pos_z[t - 1, ]
    vel[t, ] <- sqrt(dx^2 + dy^2 + dz^2)
  }

  # Per-marker thresholds
  if (is.null(threshold)) {
    thresh <- rep(NA_real_, n_markers)
    for (m in seq_len(n_markers)) {
      v <- vel[, m]
      v <- v[!is.na(v)]
      if (length(v) > 0) {
        med <- stats::median(v)
        mad_val <- stats::mad(v, constant = 1.4826)
        thresh[m] <- med + 5 * mad_val
      } else {
        thresh[m] <- Inf
      }
    }
  } else {
    thresh <- rep(threshold, n_markers)
  }

  # Find spike frames for each marker
  spike_frames <- list()
  for (m in seq_len(n_markers)) {
    spikes <- which(!is.na(vel[, m]) & vel[, m] > thresh[m])
    spike_frames[[m]] <- spikes
  }

  # Check pairs of markers with simultaneous spikes for cross-over
  results <- list()
  checked_pairs <- list()

  for (m1 in seq_len(n_markers - 1)) {
    for (m2 in (m1 + 1):n_markers) {
      # Find frames where both have spikes within `window` of each other
      for (f1 in spike_frames[[m1]]) {
        nearby <- spike_frames[[m2]]
        nearby <- nearby[abs(nearby - f1) <= window]
        for (f2 in nearby) {
          swap_frame <- min(f1, f2)
          pair_key <- paste(swap_frame, m1, m2, sep = "-")
          if (pair_key %in% checked_pairs) next
          checked_pairs <- c(checked_pairs, pair_key)

          # Check cross-over: after the swap, marker_a is closer to marker_b's
          # pre-swap position and vice versa
          pre <- swap_frame - 1
          post <- swap_frame
          if (pre < 1 || post > n_frames) next

          # Pre-swap positions
          pre_a <- c(pos_x[pre, m1], pos_y[pre, m1], pos_z[pre, m1])
          pre_b <- c(pos_x[pre, m2], pos_y[pre, m2], pos_z[pre, m2])
          # Post-swap positions
          post_a <- c(pos_x[post, m1], pos_y[post, m1], pos_z[post, m1])
          post_b <- c(pos_x[post, m2], pos_y[post, m2], pos_z[post, m2])

          if (any(is.na(c(pre_a, pre_b, post_a, post_b)))) next

          # Distance: post_a to pre_b vs post_a to pre_a (cross-over check)
          d_cross_a <- sqrt(sum((post_a - pre_b)^2))
          d_same_a <- sqrt(sum((post_a - pre_a)^2))
          d_cross_b <- sqrt(sum((post_b - pre_a)^2))
          d_same_b <- sqrt(sum((post_b - pre_b)^2))

          # Swap if cross distances are smaller than same distances
          if (d_cross_a < d_same_a && d_cross_b < d_same_b) {
            # Confidence based on ratio
            ratio_a <- d_same_a / (d_cross_a + 1e-10)
            ratio_b <- d_same_b / (d_cross_b + 1e-10)
            conf <- min(1, (ratio_a + ratio_b - 2) / 4)
            conf <- max(0, conf)

            results[[length(results) + 1]] <- data.frame(
              frame = swap_frame,
              marker_a = as.character(marker_names[m1]),
              marker_b = as.character(marker_names[m2]),
              velocity_a = vel[f1, m1],
              velocity_b = vel[f2, m2],
              confidence = conf,
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }
  }

  if (length(results) == 0) return(empty_result)

  do.call(rbind, results)
}


# ---------------------------------------------------------------------------
# correctSwaps
# ---------------------------------------------------------------------------

#' Correct Marker Label Swaps
#'
#' Repairs marker trajectories by swapping the data columns of detected swap
#' pairs from the swap frame onward.
#'
#' @param pe A PhysioExperiment with position assays.
#' @param swaps A `data.frame` as returned by [detectSwaps()], containing
#'   at minimum `frame`, `marker_a`, `marker_b`, and `confidence` columns.
#' @param assay_prefix Prefix for position assay names. Default `"position"`.
#' @param min_confidence Minimum confidence threshold for applying a
#'   correction. Swaps below this threshold are skipped. Default 0.5.
#'
#' @return A PhysioExperiment with corrected position assays.
#'
#' @examples
#' \dontrun{
#' swaps <- detectSwaps(pe)
#' pe_fixed <- correctSwaps(pe, swaps, min_confidence = 0.3)
#' }
#'
#' @seealso [detectSwaps()], [trackMarkers()]
#'
#' @export
correctSwaps <- function(pe,
                         swaps,
                         assay_prefix = "position",
                         min_confidence = 0.5) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(is.data.frame(swaps))

  if (nrow(swaps) == 0) return(pe)

  ax <- paste0(assay_prefix, "_x")
  ay <- paste0(assay_prefix, "_y")
  az <- paste0(assay_prefix, "_z")

  pos_x <- SummarizedExperiment::assay(pe, ax)
  pos_y <- SummarizedExperiment::assay(pe, ay)
  pos_z <- SummarizedExperiment::assay(pe, az)

  n_frames <- nrow(pos_x)
  marker_names <- colnames(pos_x)

  # Filter by confidence
  swaps <- swaps[swaps$confidence >= min_confidence, , drop = FALSE]
  if (nrow(swaps) == 0) return(pe)

  # Sort by frame (process earliest swaps first)
  swaps <- swaps[order(swaps$frame), , drop = FALSE]

  for (i in seq_len(nrow(swaps))) {
    f <- swaps$frame[i]
    ma <- swaps$marker_a[i]
    mb <- swaps$marker_b[i]

    # Find column indices
    idx_a <- match(ma, marker_names)
    idx_b <- match(mb, marker_names)
    if (is.na(idx_a) || is.na(idx_b)) next
    if (f > n_frames) next

    # Swap columns from frame f onward
    frames <- f:n_frames

    tmp_x <- pos_x[frames, idx_a]
    pos_x[frames, idx_a] <- pos_x[frames, idx_b]
    pos_x[frames, idx_b] <- tmp_x

    tmp_y <- pos_y[frames, idx_a]
    pos_y[frames, idx_a] <- pos_y[frames, idx_b]
    pos_y[frames, idx_b] <- tmp_y

    tmp_z <- pos_z[frames, idx_a]
    pos_z[frames, idx_a] <- pos_z[frames, idx_b]
    pos_z[frames, idx_b] <- tmp_z
  }

  SummarizedExperiment::assay(pe, ax) <- pos_x
  SummarizedExperiment::assay(pe, ay) <- pos_y
  SummarizedExperiment::assay(pe, az) <- pos_z

  pe
}
