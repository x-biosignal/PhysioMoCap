#' Dynamic Time Warping (DTW) for Biomechanics
#'
#' Functions for Dynamic Time Warping analysis including distance computation,
#' alignment, averaging, and clustering of biomechanical waveforms.

#' Compute DTW distance between two time series
#'
#' Calculates the Dynamic Time Warping distance and alignment path
#' between two waveforms, allowing for non-linear time alignment.
#'
#' @param x First time series (numeric vector or matrix column).
#' @param y Second time series (numeric vector or matrix column).
#' @param window_size Sakoe-Chiba band width (NULL for no constraint).
#' @param step_pattern Step pattern: "symmetric1", "symmetric2", or "asymmetric".
#' @param normalize Logical; whether to normalize distance by path length.
#'
#' @return A list of class "dtw_result" containing:
#'   \item{distance}{DTW distance}
#'   \item{normalized_distance}{Distance normalized by path length}
#'   \item{path}{Alignment path (matrix with columns 'index1', 'index2')}
#'   \item{cost_matrix}{Accumulated cost matrix}
#'
#' @details
#' DTW finds the optimal alignment between two time series by warping the time
#' axis. It's useful for comparing movements that may occur at different speeds
#' or with timing differences.
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' @seealso [dtwDistanceMatrix()], [dtwAverage()], [dtwClustering()], [dtwWarp()]
#'
#' @export
#' @examples
#' # Two gait cycles with different timing
#' t <- seq(0, 100, length.out = 100)
#' x <- sin(2 * pi * t / 100) * 30
#' y <- sin(2 * pi * (t + 10) / 100) * 30  # Phase shifted
#'
#' result <- dtwDistance(x, y)
#' print(result$distance)
dtwDistance <- function(x, y, window_size = NULL,
                        step_pattern = c("symmetric2", "symmetric1", "asymmetric"),
                        normalize = TRUE) {

  step_pattern <- match.arg(step_pattern)

  # Convert to numeric vectors
  x <- as.numeric(x)
  y <- as.numeric(y)

  n <- length(x)
  m <- length(y)

  if (n == 0 || m == 0) {
    stop("Input vectors cannot be empty", call. = FALSE)
  }

  # Initialize cost matrices
  local_cost <- matrix(NA_real_, nrow = n, ncol = m)
  accumulated_cost <- matrix(Inf, nrow = n, ncol = m)

  # Compute local cost matrix (Euclidean distance)
  for (i in seq_len(n)) {
    for (j in seq_len(m)) {
      # Apply Sakoe-Chiba band constraint
      if (!is.null(window_size)) {
        if (abs(i - j) > window_size) {
          next
        }
      }
      local_cost[i, j] <- (x[i] - y[j])^2
    }
  }

  # Initialize first cell
  accumulated_cost[1, 1] <- local_cost[1, 1]

  # Fill accumulated cost matrix based on step pattern
  if (step_pattern == "symmetric2") {
    # Symmetric2: diagonal(1), horizontal(1), vertical(1) with 2*d for diagonal
    for (i in seq_len(n)) {
      for (j in seq_len(m)) {
        if (is.na(local_cost[i, j])) next
        if (i == 1 && j == 1) next

        candidates <- c(
          if (i > 1 && j > 1) accumulated_cost[i - 1, j - 1] + 2 * local_cost[i, j] else Inf,
          if (i > 1) accumulated_cost[i - 1, j] + local_cost[i, j] else Inf,
          if (j > 1) accumulated_cost[i, j - 1] + local_cost[i, j] else Inf
        )
        accumulated_cost[i, j] <- min(candidates, na.rm = TRUE)
      }
    }
  } else if (step_pattern == "symmetric1") {
    # Symmetric1: all moves cost the same
    for (i in seq_len(n)) {
      for (j in seq_len(m)) {
        if (is.na(local_cost[i, j])) next
        if (i == 1 && j == 1) next

        candidates <- c(
          if (i > 1 && j > 1) accumulated_cost[i - 1, j - 1] else Inf,
          if (i > 1) accumulated_cost[i - 1, j] else Inf,
          if (j > 1) accumulated_cost[i, j - 1] else Inf
        )
        accumulated_cost[i, j] <- min(candidates, na.rm = TRUE) + local_cost[i, j]
      }
    }
  } else {
    # Asymmetric: allows j to repeat but not i
    for (i in seq_len(n)) {
      for (j in seq_len(m)) {
        if (is.na(local_cost[i, j])) next
        if (i == 1 && j == 1) next

        candidates <- c(
          if (i > 1 && j > 1) accumulated_cost[i - 1, j - 1] else Inf,
          if (i > 1) accumulated_cost[i - 1, j] else Inf,
          if (i > 1 && j > 2) accumulated_cost[i - 1, j - 2] else Inf
        )
        accumulated_cost[i, j] <- min(candidates, na.rm = TRUE) + local_cost[i, j]
      }
    }
  }

  # Backtrack to find optimal path
  path <- .backtrackDTW(accumulated_cost, local_cost, step_pattern)

  # Extract distance
  distance <- sqrt(accumulated_cost[n, m])
  normalized_distance <- if (normalize) distance / nrow(path) else distance

  result <- list(
    distance = distance,
    normalized_distance = normalized_distance,
    path = path,
    cost_matrix = accumulated_cost,
    local_cost = local_cost,
    n = n,
    m = m,
    step_pattern = step_pattern
  )

  class(result) <- c("dtw_result", "list")
  result
}

#' Backtrack DTW path
#' @noRd
.backtrackDTW <- function(accumulated_cost, local_cost, step_pattern) {
  n <- nrow(accumulated_cost)
  m <- ncol(accumulated_cost)

  path <- matrix(NA_integer_, nrow = n + m, ncol = 2)
  colnames(path) <- c("index1", "index2")

  i <- n
  j <- m
  k <- 1

  path[k, ] <- c(i, j)

  while (i > 1 || j > 1) {
    if (i == 1) {
      j <- j - 1
    } else if (j == 1) {
      i <- i - 1
    } else {
      # Find where we came from
      candidates <- c(
        accumulated_cost[i - 1, j - 1],  # diagonal
        accumulated_cost[i - 1, j],       # vertical
        accumulated_cost[i, j - 1]        # horizontal
      )

      which_min <- which.min(candidates)

      if (which_min == 1) {
        i <- i - 1
        j <- j - 1
      } else if (which_min == 2) {
        i <- i - 1
      } else {
        j <- j - 1
      }
    }

    k <- k + 1
    path[k, ] <- c(i, j)
  }

  # Reverse path and remove NAs
  path <- path[k:1, , drop = FALSE]
  path
}

#' Compute DTW distance matrix
#'
#' Computes pairwise DTW distances between all columns of a matrix
#' or between observations in a PhysioExperiment.
#'
#' @param x A PhysioExperiment object or matrix (time x observations).
#' @param window_size Sakoe-Chiba band width constraint.
#' @param normalize Logical; normalize by path length.
#' @param parallel Logical; use parallel processing.
#'
#' @return A symmetric distance matrix.
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' @seealso [dtwDistance()], [dtwAverage()], [dtwClustering()]
#'
#' @export
#' @examples
#' # Create matrix of 10 gait cycles
#' set.seed(123)
#' t <- seq(0, 100, length.out = 100)
#' data <- sapply(1:10, function(i) {
#'   phase <- rnorm(1, 0, 10)
#'   sin(2 * pi * (t + phase) / 100) * 30 + rnorm(100, 0, 2)
#' })
#'
#' dist_matrix <- dtwDistanceMatrix(data)
dtwDistanceMatrix <- function(x, window_size = NULL, normalize = TRUE,
                               parallel = FALSE) {

  # Extract data
  if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
  } else if (is.matrix(x)) {
    data <- x
  } else {
    stop("Input must be a PhysioExperiment or matrix", call. = FALSE)
  }

  n_obs <- ncol(data)
  dist_matrix <- matrix(0, nrow = n_obs, ncol = n_obs)

  if (parallel && requireNamespace("parallel", quietly = TRUE)) {
    n_cores <- parallel::detectCores() - 1
    pairs <- t(combn(n_obs, 2))

    results <- parallel::mclapply(seq_len(nrow(pairs)), function(k) {
      i <- pairs[k, 1]
      j <- pairs[k, 2]
      dtw_result <- dtwDistance(data[, i], data[, j],
                                window_size = window_size,
                                normalize = normalize)
      c(i, j, dtw_result$normalized_distance)
    }, mc.cores = n_cores)

    for (res in results) {
      dist_matrix[res[1], res[2]] <- res[3]
      dist_matrix[res[2], res[1]] <- res[3]
    }
  } else {
    for (i in seq_len(n_obs - 1)) {
      for (j in (i + 1):n_obs) {
        dtw_result <- dtwDistance(data[, i], data[, j],
                                  window_size = window_size,
                                  normalize = normalize)
        dist_matrix[i, j] <- dtw_result$normalized_distance
        dist_matrix[j, i] <- dtw_result$normalized_distance
      }
    }
  }

  # Convert to dist object for compatibility with clustering functions
  as.dist(dist_matrix)
}

#' DTW Barycenter Averaging (DBA)
#'
#' Computes the average waveform using DTW Barycenter Averaging,
#' which accounts for time warping in the averaging process.
#'
#' @param x A PhysioExperiment object or matrix (time x observations).
#' @param init Initial reference: "medoid", "mean", or a numeric vector.
#' @param max_iter Maximum iterations for DBA.
#' @param tol Convergence tolerance.
#' @param window_size Sakoe-Chiba band width.
#'
#' @return A list containing:
#'   \item{average}{The DTW-averaged waveform}
#'   \item{iterations}{Number of iterations used}
#'   \item{alignments}{List of alignment paths to the average}
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' Petitjean F, Ketterlin A, Gancarski P (2011). "A global averaging method
#' for dynamic time warping, with applications to clustering." Pattern
#' Recognition, 44(3), 678-693.
#'
#' @seealso [dtwDistance()], [dtwDistanceMatrix()], [dtwClustering()]
#'
#' @export
#' @examples
#' # Average multiple gait cycles with timing variation
#' set.seed(123)
#' t <- seq(0, 100, length.out = 100)
#' data <- sapply(1:20, function(i) {
#'   phase <- rnorm(1, 0, 10)
#'   sin(2 * pi * (t + phase) / 100) * 30 + rnorm(100, 0, 2)
#' })
#'
#' avg <- dtwAverage(data)
#' plot(avg$average, type = "l")
dtwAverage <- function(x, init = "medoid", max_iter = 30, tol = 1e-4,
                        window_size = NULL) {

  # Extract data
  if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
  } else if (is.matrix(x)) {
    data <- x
  } else {
    stop("Input must be a PhysioExperiment or matrix", call. = FALSE)
  }

  n_time <- nrow(data)
  n_obs <- ncol(data)

  # Initialize average
  if (is.character(init)) {
    if (init == "medoid") {
      # Find medoid (observation with minimum total distance)
      dist_matrix <- as.matrix(dtwDistanceMatrix(data, window_size = window_size))
      medoid_idx <- which.min(rowSums(dist_matrix))
      average <- data[, medoid_idx]
    } else {
      # Simple mean initialization
      average <- rowMeans(data, na.rm = TRUE)
    }
  } else {
    average <- as.numeric(init)
  }

  # DBA iterations
  for (iter in seq_len(max_iter)) {
    old_average <- average

    # Collect aligned associations
    associations <- vector("list", n_time)
    for (i in seq_len(n_time)) {
      associations[[i]] <- numeric(0)
    }

    # Align each sequence to current average
    for (i in seq_len(n_obs)) {
      dtw_result <- dtwDistance(average, data[, i], window_size = window_size)

      # Collect values associated with each point in average
      for (k in seq_len(nrow(dtw_result$path))) {
        avg_idx <- dtw_result$path[k, 1]
        obs_idx <- dtw_result$path[k, 2]
        associations[[avg_idx]] <- c(associations[[avg_idx]], data[obs_idx, i])
      }
    }

    # Update average
    for (i in seq_len(n_time)) {
      if (length(associations[[i]]) > 0) {
        average[i] <- mean(associations[[i]], na.rm = TRUE)
      }
    }

    # Check convergence
    change <- sqrt(mean((average - old_average)^2, na.rm = TRUE))
    if (change < tol) break
  }

  # Final alignments
  alignments <- lapply(seq_len(n_obs), function(i) {
    dtwDistance(average, data[, i], window_size = window_size)$path
  })

  list(
    average = average,
    iterations = iter,
    alignments = alignments
  )
}

#' DTW-based clustering
#'
#' Clusters waveforms using DTW distance with hierarchical or k-medoids method.
#'
#' @param x A PhysioExperiment object or matrix (time x observations).
#' @param k Number of clusters.
#' @param method Clustering method: "hierarchical" or "kmedoids".
#' @param linkage For hierarchical: "ward.D2", "complete", "average", etc.
#' @param window_size Sakoe-Chiba band width.
#'
#' @return A list containing:
#'   \item{clusters}{Cluster assignments}
#'   \item{centers}{Cluster centers (medoids or DBA averages)}
#'   \item{distance_matrix}{DTW distance matrix used}
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' @seealso [dtwDistance()], [dtwDistanceMatrix()], [dtwAverage()]
#'
#' @export
#' @examples
#' # Cluster gait patterns
#' set.seed(123)
#' t <- seq(0, 100, length.out = 100)
#'
#' # Generate two groups with different patterns
#' group1 <- sapply(1:15, function(i) {
#'   sin(2 * pi * t / 100) * 30 + rnorm(100, 0, 3)
#' })
#' group2 <- sapply(1:15, function(i) {
#'   sin(2 * pi * t / 100 + pi/4) * 20 + rnorm(100, 0, 3)
#' })
#' data <- cbind(group1, group2)
#'
#' result <- dtwClustering(data, k = 2)
#' table(result$clusters)
dtwClustering <- function(x, k = 2, method = c("hierarchical", "kmedoids"),
                           linkage = "ward.D2", window_size = NULL) {

  method <- match.arg(method)

  # Extract data
  if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
  } else if (is.matrix(x)) {
    data <- x
  } else {
    stop("Input must be a PhysioExperiment or matrix", call. = FALSE)
  }

  n_obs <- ncol(data)

  # Compute distance matrix
  dist_obj <- dtwDistanceMatrix(data, window_size = window_size)
  dist_matrix <- as.matrix(dist_obj)

  if (method == "hierarchical") {
    # Hierarchical clustering
    hc <- stats::hclust(dist_obj, method = linkage)
    clusters <- stats::cutree(hc, k = k)

    # Compute cluster centers (medoids)
    centers <- matrix(NA_real_, nrow = nrow(data), ncol = k)
    for (i in seq_len(k)) {
      cluster_idx <- which(clusters == i)
      if (length(cluster_idx) == 1) {
        centers[, i] <- data[, cluster_idx]
      } else {
        # Find medoid within cluster
        cluster_dist <- dist_matrix[cluster_idx, cluster_idx, drop = FALSE]
        medoid_local <- which.min(rowSums(cluster_dist))
        centers[, i] <- data[, cluster_idx[medoid_local]]
      }
    }

    result <- list(
      clusters = clusters,
      centers = centers,
      distance_matrix = dist_matrix,
      dendrogram = hc
    )

  } else {
    # K-medoids (PAM-like algorithm)
    result <- .kmedoidsDTW(data, dist_matrix, k)
  }

  class(result) <- c("dtw_clustering", "list")
  result
}

#' K-medoids clustering using DTW distances
#' @noRd
.kmedoidsDTW <- function(data, dist_matrix, k, max_iter = 100) {
  n_obs <- ncol(data)

  # Initialize medoids randomly
  medoid_idx <- sample(n_obs, k)

  for (iter in seq_len(max_iter)) {
    old_medoids <- medoid_idx

    # Assign to nearest medoid
    clusters <- apply(dist_matrix[, medoid_idx, drop = FALSE], 1, which.min)

    # Update medoids
    for (i in seq_len(k)) {
      cluster_idx <- which(clusters == i)
      if (length(cluster_idx) == 0) next

      if (length(cluster_idx) == 1) {
        medoid_idx[i] <- cluster_idx
      } else {
        # Find best medoid in cluster
        cluster_dist <- dist_matrix[cluster_idx, cluster_idx, drop = FALSE]
        best_local <- which.min(rowSums(cluster_dist))
        medoid_idx[i] <- cluster_idx[best_local]
      }
    }

    # Check convergence
    if (all(sort(medoid_idx) == sort(old_medoids))) break
  }

  # Final assignment
  clusters <- apply(dist_matrix[, medoid_idx, drop = FALSE], 1, which.min)
  centers <- data[, medoid_idx, drop = FALSE]

  list(
    clusters = clusters,
    centers = centers,
    medoid_indices = medoid_idx,
    distance_matrix = dist_matrix,
    iterations = iter
  )
}

#' Warp a waveform using DTW alignment
#'
#' Applies a DTW alignment path to warp one waveform to match another.
#'
#' @param x Waveform to warp.
#' @param dtw_result DTW result from dtwDistance().
#' @param to Which series to warp to: "query" (index1) or "reference" (index2).
#'
#' @return Warped waveform.
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' @seealso [dtwDistance()], [dtwAverage()], [normalizeMovement()]
#'
#' @export
dtwWarp <- function(x, dtw_result, to = c("query", "reference")) {
  to <- match.arg(to)

  if (!inherits(dtw_result, "dtw_result")) {
    stop("dtw_result must be from dtwDistance()", call. = FALSE)
  }

  path <- dtw_result$path

  if (to == "query") {
    # Warp to match query (index1)
    target_length <- dtw_result$n
    # Map reference points to query positions
    warped <- numeric(target_length)
    counts <- numeric(target_length)

    for (k in seq_len(nrow(path))) {
      query_idx <- path[k, 1]
      ref_idx <- path[k, 2]
      warped[query_idx] <- warped[query_idx] + x[ref_idx]
      counts[query_idx] <- counts[query_idx] + 1
    }

    warped <- warped / pmax(counts, 1)

  } else {
    # Warp to match reference (index2)
    target_length <- dtw_result$m
    warped <- numeric(target_length)
    counts <- numeric(target_length)

    for (k in seq_len(nrow(path))) {
      query_idx <- path[k, 1]
      ref_idx <- path[k, 2]
      warped[ref_idx] <- warped[ref_idx] + x[query_idx]
      counts[ref_idx] <- counts[ref_idx] + 1
    }

    warped <- warped / pmax(counts, 1)
  }

  warped
}

#' Plot DTW alignment
#'
#' Visualizes the DTW alignment between two waveforms.
#'
#' @param dtw_result A dtw_result object from dtwDistance().
#' @param x First waveform (optional, for overlay).
#' @param y Second waveform (optional, for overlay).
#' @param type Plot type: "alignment", "cost", "waveforms", or "all".
#'
#' @return A ggplot object or list of plots.
#'
#' @references
#' Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization
#' for spoken word recognition." IEEE Transactions on Acoustics, Speech,
#' and Signal Processing, 26(1), 43-49.
#'
#' @seealso [dtwDistance()], [dtwWarp()], [dtwClustering()]
#'
#' @export
plotDTW <- function(dtw_result, x = NULL, y = NULL,
                     type = c("alignment", "cost", "waveforms", "all")) {

  if (!inherits(dtw_result, "dtw_result")) {
    stop("Input must be a dtw_result object", call. = FALSE)
  }

  type <- match.arg(type)
  plots <- list()

  # Alignment plot (warping path)
  if (type %in% c("alignment", "all")) {
    path_df <- data.frame(
      index1 = dtw_result$path[, 1],
      index2 = dtw_result$path[, 2]
    )

    p_align <- ggplot2::ggplot(path_df,
                                ggplot2::aes(x = .data$index1, y = .data$index2)) +
      ggplot2::geom_line(color = "blue", linewidth = 1) +
      ggplot2::geom_abline(slope = dtw_result$m / dtw_result$n,
                           intercept = 0, linetype = "dashed", color = "gray50") +
      ggplot2::labs(x = "Query index", y = "Reference index",
                    title = sprintf("DTW Alignment Path (distance: %.2f)",
                                    dtw_result$normalized_distance)) +
      ggplot2::theme_minimal()

    plots$alignment <- p_align
  }

  # Cost matrix heatmap
  if (type %in% c("cost", "all")) {
    cost_df <- expand.grid(
      index1 = seq_len(dtw_result$n),
      index2 = seq_len(dtw_result$m)
    )
    cost_df$cost <- as.vector(dtw_result$cost_matrix)
    cost_df$cost[is.infinite(cost_df$cost)] <- NA

    p_cost <- ggplot2::ggplot(cost_df,
                               ggplot2::aes(x = .data$index1, y = .data$index2,
                                            fill = .data$cost)) +
      ggplot2::geom_raster() +
      ggplot2::scale_fill_viridis_c(option = "plasma", na.value = "white") +
      ggplot2::geom_path(data = data.frame(
        index1 = dtw_result$path[, 1],
        index2 = dtw_result$path[, 2]
      ), color = "white", linewidth = 1) +
      ggplot2::labs(x = "Query index", y = "Reference index",
                    title = "DTW Accumulated Cost Matrix",
                    fill = "Cost") +
      ggplot2::theme_minimal() +
      ggplot2::coord_fixed()

    plots$cost <- p_cost
  }

  # Waveform comparison
  if (type %in% c("waveforms", "all") && !is.null(x) && !is.null(y)) {
    n <- length(x)
    m <- length(y)

    wave_df <- data.frame(
      time = c(seq_len(n), seq_len(m)),
      value = c(x, y),
      series = factor(rep(c("Query", "Reference"), c(n, m)))
    )

    p_waves <- ggplot2::ggplot(wave_df,
                                ggplot2::aes(x = .data$time, y = .data$value,
                                             color = .data$series)) +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::labs(x = "Time", y = "Value", color = "Series",
                    title = "Waveform Comparison") +
      ggplot2::theme_minimal()

    plots$waveforms <- p_waves
  }

  if (type == "all") {
    return(plots)
  } else {
    return(plots[[type]])
  }
}

#' Print DTW result
#' @param x A dtw_result object
#' @param ... Additional arguments (unused)
#' @export
print.dtw_result <- function(x, ...) {
  cat("DTW Result\n")
  cat("==========\n")
  cat(sprintf("Query length: %d\n", x$n))
  cat(sprintf("Reference length: %d\n", x$m))
  cat(sprintf("Distance: %.4f\n", x$distance))
  cat(sprintf("Normalized distance: %.4f\n", x$normalized_distance))
  cat(sprintf("Path length: %d\n", nrow(x$path)))
  cat(sprintf("Step pattern: %s\n", x$step_pattern))
  invisible(x)
}

#' Print DTW clustering result
#' @param x A dtw_clustering object
#' @param ... Additional arguments (unused)
#' @export
print.dtw_clustering <- function(x, ...) {
  cat("DTW Clustering Result\n")
  cat("====================\n")
  cat(sprintf("Observations: %d\n", length(x$clusters)))
  cat(sprintf("Clusters: %d\n", max(x$clusters)))
  cat("\nCluster sizes:\n")
  print(table(x$clusters))
  invisible(x)
}
