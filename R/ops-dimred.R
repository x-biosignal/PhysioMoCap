#' Dimensionality Reduction for Biomechanics
#'
#' Functions for dimensionality reduction and visualization of high-dimensional
#' biomechanical waveform data including PCA, UMAP, and t-SNE.

#' Extract waveform features for dimensionality reduction
#'
#' Extracts summary features from waveforms for use with standard
#' dimensionality reduction methods.
#'
#' @param x A PhysioExperiment object or matrix (time x observations).
#' @param features Character vector of features to extract:
#'   "raw" (flattened waveform), "statistical" (summary stats),
#'   "frequency" (spectral features), "shape" (curve characteristics).
#' @param n_points For "raw", number of points to resample to.
#'
#' @return A matrix (observations x features) suitable for PCA/UMAP.
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformPCA()], [waveformUMAP()], [waveformTSNE()]
#'
#' @details
#' Feature types:
#' - raw: The raw waveform resampled to n_points
#' - statistical: Mean, SD, min, max, range, skewness, kurtosis
#' - frequency: Dominant frequency, spectral centroid, bandwidth
#' - shape: Peaks, zero crossings, area under curve
#'
#' @export
#' @examples
#' # Extract features from gait data
#' set.seed(123)
#' data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
#' features <- extractWaveformFeatures(data, features = c("statistical", "shape"))
extractWaveformFeatures <- function(x, features = c("statistical", "shape"),
                                     n_points = 50) {

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

  feature_list <- list()

  # Raw features (resampled waveform)
  if ("raw" %in% features) {
    raw_features <- t(apply(data, 2, function(col) {
      stats::approx(seq_len(n_time), col, n = n_points)$y
    }))
    colnames(raw_features) <- paste0("raw_", seq_len(n_points))
    feature_list$raw <- raw_features
  }

  # Statistical features
  if ("statistical" %in% features) {
    stat_features <- t(apply(data, 2, function(col) {
      col <- col[!is.na(col)]
      n <- length(col)
      m <- mean(col)
      s <- sd(col)

      # Skewness
      skew <- if (s > 0) mean(((col - m) / s)^3) else 0

      # Kurtosis (excess)
      kurt <- if (s > 0) mean(((col - m) / s)^4) - 3 else 0

      c(
        mean = m,
        sd = s,
        min = min(col),
        max = max(col),
        range = max(col) - min(col),
        median = median(col),
        iqr = IQR(col),
        skewness = skew,
        kurtosis = kurt
      )
    }))
    feature_list$statistical <- stat_features
  }

  # Frequency features
  if ("frequency" %in% features) {
    freq_features <- t(apply(data, 2, function(col) {
      col <- col[!is.na(col)]
      n <- length(col)

      # FFT
      fft_result <- abs(stats::fft(col)[seq_len(n / 2 + 1)])^2
      freqs <- seq(0, 0.5, length.out = length(fft_result))

      # Normalize
      total_power <- sum(fft_result[-1])  # Exclude DC
      if (total_power > 0) {
        fft_norm <- fft_result[-1] / total_power
        freqs_norm <- freqs[-1]
      } else {
        fft_norm <- rep(0, length(fft_result) - 1)
        freqs_norm <- freqs[-1]
      }

      # Dominant frequency
      dom_freq <- if (length(fft_norm) > 0 && max(fft_norm) > 0) {
        freqs_norm[which.max(fft_norm)]
      } else 0

      # Spectral centroid
      centroid <- if (total_power > 0) sum(freqs_norm * fft_norm) else 0

      # Spectral bandwidth
      bandwidth <- if (total_power > 0) {
        sqrt(sum((freqs_norm - centroid)^2 * fft_norm))
      } else 0

      c(
        dominant_freq = dom_freq,
        spectral_centroid = centroid,
        spectral_bandwidth = bandwidth,
        total_power = total_power
      )
    }))
    feature_list$frequency <- freq_features
  }

  # Shape features
  if ("shape" %in% features) {
    shape_features <- t(apply(data, 2, function(col) {
      col <- col[!is.na(col)]
      n <- length(col)

      # Zero crossings (after centering)
      col_centered <- col - mean(col)
      zero_crossings <- sum(diff(sign(col_centered)) != 0)

      # Peaks and valleys
      d1 <- diff(col)
      peaks <- sum(d1[-length(d1)] > 0 & d1[-1] < 0)
      valleys <- sum(d1[-length(d1)] < 0 & d1[-1] > 0)

      # Area under curve (absolute)
      auc <- sum(abs(col)) / n

      # Root mean square
      rms <- sqrt(mean(col^2))

      # Variability index
      var_index <- sum(abs(diff(col))) / (n - 1)

      # Linearity (R-squared of linear fit)
      time_idx <- seq_len(n)
      lm_fit <- stats::lm.fit(cbind(1, time_idx), col)
      ss_res <- sum(lm_fit$residuals^2)
      ss_tot <- sum((col - mean(col))^2)
      linearity <- if (ss_tot > 0) 1 - ss_res / ss_tot else 1

      c(
        zero_crossings = zero_crossings,
        n_peaks = peaks,
        n_valleys = valleys,
        auc = auc,
        rms = rms,
        variability = var_index,
        linearity = linearity
      )
    }))
    feature_list$shape <- shape_features
  }

  # Combine all features
  do.call(cbind, feature_list)
}

#' PCA for waveform data
#'
#' Performs Principal Component Analysis on waveform data,
#' either using extracted features or raw waveforms.
#'
#' @param x A PhysioExperiment object or matrix.
#' @param method Feature extraction method: "features" or "raw".
#' @param features If method = "features", which features to extract.
#' @param n_components Number of PCs to retain.
#' @param scale Logical; scale features to unit variance.
#'
#' @return A list of class "waveform_pca" containing:
#'   \item{scores}{PC scores (observations x components)}
#'   \item{loadings}{PC loadings (features x components)}
#'   \item{variance_explained}{Variance explained by each PC}
#'   \item{cumulative_variance}{Cumulative variance}
#'   \item{center}{Feature means}
#'   \item{scale}{Feature SDs (if scaled)}
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [extractWaveformFeatures()], [waveformUMAP()], [plotPCAScatter()], [plotPCAVariance()]
#'
#' @export
#' @examples
#' # PCA on gait features
#' set.seed(123)
#' data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
#' pca_result <- waveformPCA(data, method = "features")
#' plotPCAScatter(pca_result)
waveformPCA <- function(x, method = c("features", "raw"),
                         features = c("statistical", "shape"),
                         n_components = 10, scale = TRUE) {

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

  # Create feature matrix
  if (method == "features") {
    feature_matrix <- extractWaveformFeatures(data, features = features)
  } else {
    # Use transposed raw data (observations x time points)
    feature_matrix <- t(data)
  }

  # Remove constant columns
  col_vars <- apply(feature_matrix, 2, var, na.rm = TRUE)
  keep_cols <- col_vars > 0 & !is.na(col_vars)
  feature_matrix <- feature_matrix[, keep_cols, drop = FALSE]

  n_obs <- nrow(feature_matrix)
  n_features <- ncol(feature_matrix)
  n_components <- min(n_components, n_obs - 1, n_features)

  # Center and optionally scale
  center <- colMeans(feature_matrix, na.rm = TRUE)
  feature_centered <- sweep(feature_matrix, 2, center, "-")

  if (scale) {
    scale_vals <- apply(feature_matrix, 2, sd, na.rm = TRUE)
    scale_vals[scale_vals == 0] <- 1
    feature_scaled <- sweep(feature_centered, 2, scale_vals, "/")
  } else {
    feature_scaled <- feature_centered
    scale_vals <- rep(1, n_features)
  }

  # SVD for PCA
  svd_result <- svd(feature_scaled, nu = n_components, nv = n_components)

  # Compute variance explained
  eigenvalues <- svd_result$d^2 / (n_obs - 1)
  total_var <- sum(eigenvalues)
  variance_explained <- eigenvalues[seq_len(n_components)] / total_var
  cumulative_variance <- cumsum(variance_explained)

  result <- list(
    scores = svd_result$u %*% diag(svd_result$d[seq_len(n_components)], n_components),
    loadings = svd_result$v,
    singular_values = svd_result$d[seq_len(n_components)],
    variance_explained = variance_explained,
    cumulative_variance = cumulative_variance,
    center = center,
    scale = if (scale) scale_vals else NULL,
    n_components = n_components,
    n_obs = n_obs,
    n_features = n_features,
    feature_names = colnames(feature_matrix)
  )

  class(result) <- c("waveform_pca", "list")
  result
}

#' UMAP embedding for waveform data
#'
#' Performs UMAP dimensionality reduction on waveform data
#' for visualization. Requires the uwot package.
#'
#' @param x A PhysioExperiment object, matrix, or waveform_pca result.
#' @param n_neighbors Number of neighbors for UMAP.
#' @param n_components Number of UMAP dimensions (usually 2).
#' @param min_dist Minimum distance parameter.
#' @param metric Distance metric: "euclidean", "cosine", "manhattan".
#' @param features If x is waveform data, features to extract.
#' @param use_pca Logical; pre-reduce with PCA (recommended for high-dim).
#' @param n_pca Number of PCA components to use as input.
#' @param seed Random seed for reproducibility.
#'
#' @return A list of class "waveform_umap" containing:
#'   \item{embedding}{UMAP coordinates (observations x n_components)}
#'   \item{n_obs}{Number of observations}
#'   \item{params}{UMAP parameters used}
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformPCA()], [waveformTSNE()], [plotUMAP()], [extractWaveformFeatures()]
#'
#' @export
#' @examples
#' \dontrun{
#' # UMAP on gait data
#' data <- matrix(rnorm(1000), nrow = 100, ncol = 10)
#' umap_result <- waveformUMAP(data, n_neighbors = 15)
#' plotUMAP(umap_result)
#' }
waveformUMAP <- function(x, n_neighbors = 15, n_components = 2,
                          min_dist = 0.1, metric = "euclidean",
                          features = c("statistical", "shape"),
                          use_pca = TRUE, n_pca = 30, seed = NULL) {

  if (!requireNamespace("uwot", quietly = TRUE)) {
    stop("Package 'uwot' is required for UMAP. Install with: install.packages('uwot')",
         call. = FALSE)
  }

  # Get feature matrix
  if (inherits(x, "waveform_pca")) {
    # Use PCA scores
    feature_matrix <- x$scores
  } else if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
    feature_matrix <- extractWaveformFeatures(data, features = features)
  } else if (is.matrix(x)) {
    if (nrow(x) > ncol(x)) {
      # Assume time x observations, extract features
      feature_matrix <- extractWaveformFeatures(x, features = features)
    } else {
      # Assume already observations x features
      feature_matrix <- x
    }
  } else {
    stop("Input must be a PhysioExperiment, matrix, or waveform_pca", call. = FALSE)
  }

  n_obs <- nrow(feature_matrix)

  # Optional PCA pre-reduction
  if (use_pca && ncol(feature_matrix) > n_pca) {
    pca_result <- stats::prcomp(feature_matrix, center = TRUE, scale. = TRUE,
                                 rank. = n_pca)
    feature_matrix <- pca_result$x
  }

  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Run UMAP
  umap_result <- uwot::umap(
    feature_matrix,
    n_neighbors = min(n_neighbors, n_obs - 1),
    n_components = n_components,
    min_dist = min_dist,
    metric = metric
  )

  result <- list(
    embedding = umap_result,
    n_obs = n_obs,
    params = list(
      n_neighbors = n_neighbors,
      n_components = n_components,
      min_dist = min_dist,
      metric = metric
    )
  )

  class(result) <- c("waveform_umap", "list")
  result
}

#' t-SNE embedding for waveform data
#'
#' Performs t-SNE dimensionality reduction on waveform data.
#' Requires the Rtsne package.
#'
#' @param x A PhysioExperiment object, matrix, or waveform_pca result.
#' @param perplexity t-SNE perplexity parameter.
#' @param n_components Number of dimensions (usually 2).
#' @param max_iter Maximum iterations.
#' @param features If x is waveform data, features to extract.
#' @param use_pca Logical; pre-reduce with PCA.
#' @param n_pca Number of PCA components.
#' @param seed Random seed.
#'
#' @return A list of class "waveform_tsne" containing:
#'   \item{embedding}{t-SNE coordinates}
#'   \item{n_obs}{Number of observations}
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformPCA()], [waveformUMAP()], [extractWaveformFeatures()]
#'
#' @export
waveformTSNE <- function(x, perplexity = 30, n_components = 2,
                          max_iter = 1000, features = c("statistical", "shape"),
                          use_pca = TRUE, n_pca = 30, seed = NULL) {

  if (!requireNamespace("Rtsne", quietly = TRUE)) {
    stop("Package 'Rtsne' is required for t-SNE. Install with: install.packages('Rtsne')",
         call. = FALSE)
  }

  # Get feature matrix (same as UMAP)
  if (inherits(x, "waveform_pca")) {
    feature_matrix <- x$scores
  } else if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
    feature_matrix <- extractWaveformFeatures(data, features = features)
  } else if (is.matrix(x)) {
    if (nrow(x) > ncol(x)) {
      feature_matrix <- extractWaveformFeatures(x, features = features)
    } else {
      feature_matrix <- x
    }
  } else {
    stop("Input must be a PhysioExperiment, matrix, or waveform_pca", call. = FALSE)
  }

  n_obs <- nrow(feature_matrix)

  # Set seed
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Run t-SNE
  tsne_result <- Rtsne::Rtsne(
    feature_matrix,
    dims = n_components,
    perplexity = min(perplexity, (n_obs - 1) / 3),
    max_iter = max_iter,
    pca = use_pca,
    pca_center = TRUE,
    pca_scale = TRUE,
    initial_dims = if (use_pca) n_pca else ncol(feature_matrix)
  )

  result <- list(
    embedding = tsne_result$Y,
    n_obs = n_obs,
    params = list(
      perplexity = perplexity,
      n_components = n_components,
      max_iter = max_iter
    )
  )

  class(result) <- c("waveform_tsne", "list")
  result
}

#' Plot PCA scatter
#'
#' Creates a scatter plot of PCA scores.
#'
#' @param x A waveform_pca object.
#' @param components Which PCs to plot (length 2).
#' @param groups Optional grouping factor for coloring.
#' @param labels Optional labels for points.
#'
#' @return A ggplot object.
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformPCA()], [plotPCAVariance()], [plotUMAP()]
#'
#' @export
plotPCAScatter <- function(x, components = c(1, 2), groups = NULL, labels = NULL) {

  if (!inherits(x, "waveform_pca")) {
    stop("Input must be a waveform_pca object", call. = FALSE)
  }

  components <- components[seq_len(min(2, length(components)))]
  if (max(components) > x$n_components) {
    stop("Component indices exceed available components", call. = FALSE)
  }

  df <- data.frame(
    PC1 = x$scores[, components[1]],
    PC2 = x$scores[, components[2]]
  )

  if (!is.null(groups)) {
    df$group <- as.factor(groups)
  }
  if (!is.null(labels)) {
    df$label <- labels
  }

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$PC1, y = .data$PC2))

  if (!is.null(groups)) {
    p <- p + ggplot2::geom_point(ggplot2::aes(color = .data$group),
                                  size = 2, alpha = 0.7)
  } else {
    p <- p + ggplot2::geom_point(size = 2, alpha = 0.7)
  }

  p <- p +
    ggplot2::labs(
      x = sprintf("PC%d (%.1f%%)", components[1],
                  x$variance_explained[components[1]] * 100),
      y = sprintf("PC%d (%.1f%%)", components[2],
                  x$variance_explained[components[2]] * 100),
      title = "PCA Scores"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "gray70") +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray70")

  if (!is.null(labels)) {
    p <- p + ggplot2::geom_text(ggplot2::aes(label = .data$label),
                                 vjust = -0.5, size = 3)
  }

  p
}

#' Plot PCA variance explained
#'
#' Creates a scree plot showing variance explained by each PC.
#'
#' @param x A waveform_pca object.
#' @param n_components Number of components to show.
#'
#' @return A ggplot object.
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformPCA()], [plotPCAScatter()], [plotUMAP()]
#'
#' @export
plotPCAVariance <- function(x, n_components = NULL) {

  if (!inherits(x, "waveform_pca")) {
    stop("Input must be a waveform_pca object", call. = FALSE)
  }

  if (is.null(n_components)) {
    n_components <- x$n_components
  }
  n_components <- min(n_components, x$n_components)

  df <- data.frame(
    component = seq_len(n_components),
    variance = x$variance_explained[seq_len(n_components)] * 100,
    cumulative = x$cumulative_variance[seq_len(n_components)] * 100
  )

  p <- ggplot2::ggplot(df) +
    ggplot2::geom_col(ggplot2::aes(x = .data$component, y = .data$variance),
                      fill = "steelblue", alpha = 0.7) +
    ggplot2::geom_line(ggplot2::aes(x = .data$component, y = .data$cumulative),
                        color = "red", linewidth = 1) +
    ggplot2::geom_point(ggplot2::aes(x = .data$component, y = .data$cumulative),
                         color = "red", size = 2) +
    ggplot2::labs(
      x = "Principal Component",
      y = "Variance Explained (%)",
      title = "PCA Scree Plot"
    ) +
    ggplot2::theme_minimal()

  p
}

#' Plot UMAP embedding
#'
#' Creates a scatter plot of UMAP embedding.
#'
#' @param x A waveform_umap object.
#' @param groups Optional grouping factor.
#' @param labels Optional point labels.
#'
#' @return A ggplot object.
#'
#' @references
#' van der Maaten L, Hinton G (2008). "Visualizing Data using t-SNE."
#' Journal of Machine Learning Research, 9, 2579-2605.
#'
#' @seealso [waveformUMAP()], [plotPCAScatter()], [waveformPCA()]
#'
#' @export
plotUMAP <- function(x, groups = NULL, labels = NULL) {

  if (!inherits(x, "waveform_umap")) {
    stop("Input must be a waveform_umap object", call. = FALSE)
  }

  df <- data.frame(
    UMAP1 = x$embedding[, 1],
    UMAP2 = x$embedding[, 2]
  )

  if (!is.null(groups)) {
    df$group <- as.factor(groups)
  }
  if (!is.null(labels)) {
    df$label <- labels
  }

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$UMAP1, y = .data$UMAP2))

  if (!is.null(groups)) {
    p <- p + ggplot2::geom_point(ggplot2::aes(color = .data$group),
                                  size = 2, alpha = 0.7)
  } else {
    p <- p + ggplot2::geom_point(size = 2, alpha = 0.7)
  }

  p <- p +
    ggplot2::labs(
      x = "UMAP 1", y = "UMAP 2",
      title = "UMAP Embedding"
    ) +
    ggplot2::theme_minimal()

  if (!is.null(labels)) {
    p <- p + ggplot2::geom_text(ggplot2::aes(label = .data$label),
                                 vjust = -0.5, size = 3)
  }

  p
}

#' Print waveform PCA result
#' @param x A waveform_pca object
#' @param ... Additional arguments (unused)
#' @export
print.waveform_pca <- function(x, ...) {
  cat("Waveform PCA Result\n")
  cat("===================\n")
  cat(sprintf("Observations: %d\n", x$n_obs))
  cat(sprintf("Features: %d\n", x$n_features))
  cat(sprintf("Components retained: %d\n", x$n_components))
  cat("\nVariance explained:\n")

  for (i in seq_len(min(5, x$n_components))) {
    cat(sprintf("  PC%d: %.1f%% (cumulative: %.1f%%)\n",
                i, x$variance_explained[i] * 100, x$cumulative_variance[i] * 100))
  }

  invisible(x)
}

#' Print waveform UMAP result
#' @param x A waveform_umap object
#' @param ... Additional arguments (unused)
#' @export
print.waveform_umap <- function(x, ...) {
  cat("Waveform UMAP Result\n")
  cat("====================\n")
  cat(sprintf("Observations: %d\n", x$n_obs))
  cat(sprintf("Components: %d\n", x$params$n_components))
  cat(sprintf("Neighbors: %d\n", x$params$n_neighbors))
  cat(sprintf("Min distance: %.2f\n", x$params$min_dist))
  invisible(x)
}
