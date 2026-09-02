# Functional PCA re-exported from PhysioCore (single source of truth). The
# ggplot2 visualiser plotFPCA stays here (visualization layer). fPCA's
# print.fpca_result S3 method is registered in PhysioCore.

#' @importFrom PhysioCore fPCA
#' @export
PhysioCore::fPCA

#' @importFrom PhysioCore reconstructFPCA
#' @export
PhysioCore::reconstructFPCA

#' @importFrom PhysioCore registerCurves
#' @export
PhysioCore::registerCurves

#' Plot fPCA results
#'
#' Visualizes functional PCA results including loadings and variance explained.
#'
#' @param x An fpca_result object.
#' @param type Plot type: "loadings", "variance", "scores", or "all".
#' @param components Which components to plot.
#' @param time_axis Optional time axis values.
#'
#' @return A ggplot object (or list of plots for type = "all").
#'
#' @references
#' Ramsay JO, Silverman BW (2005). "Functional Data Analysis." 2nd ed. Springer.
#'
#' @seealso [fPCA()] for computing fPCA results,
#'   [reconstructFPCA()] for waveform reconstruction.
#'
#' @export
plotFPCA <- function(x, type = c("loadings", "variance", "scores", "all"),
                     components = 1:4, time_axis = NULL) {

  if (!inherits(x, "fpca_result")) {
    stop("Input must be an fpca_result object", call. = FALSE)
  }

  type <- match.arg(type)
  components <- components[components <= x$n_components]

  if (is.null(time_axis)) {
    time_axis <- seq(0, 100, length.out = x$n_time)
  }

  plots <- list()

  # Loadings plot
  if (type %in% c("loadings", "all")) {
    loadings_df <- data.frame(
      time = rep(time_axis, length(components)),
      value = as.vector(x$loadings[, components]),
      component = factor(rep(paste0("PC", components), each = x$n_time))
    )

    # Add mean function for reference
    mean_df <- data.frame(
      time = time_axis,
      value = x$mean_function,
      component = "Mean"
    )

    p_loadings <- ggplot2::ggplot() +
      ggplot2::geom_line(data = mean_df,
                         ggplot2::aes(x = .data$time, y = .data$value),
                         color = "black", linewidth = 1.5, linetype = "dashed") +
      ggplot2::geom_hline(yintercept = 0, color = "gray70") +
      ggplot2::geom_line(data = loadings_df,
                         ggplot2::aes(x = .data$time, y = .data$value, color = .data$component),
                         linewidth = 1) +
      ggplot2::facet_wrap(~component, scales = "free_y") +
      ggplot2::labs(x = "Time (%)", y = "Loading",
                    title = "fPCA Loadings (Modes of Variation)") +
      ggplot2::theme_minimal() +
      ggplot2::theme(legend.position = "none")

    plots$loadings <- p_loadings
  }

  # Variance explained plot
  if (type %in% c("variance", "all")) {
    var_df <- data.frame(
      component = seq_len(x$n_components),
      variance = x$variance_explained * 100,
      cumulative = x$cumulative_variance * 100
    )

    p_var <- ggplot2::ggplot(var_df) +
      ggplot2::geom_col(ggplot2::aes(x = .data$component, y = .data$variance),
                        fill = "steelblue", alpha = 0.7) +
      ggplot2::geom_line(ggplot2::aes(x = .data$component, y = .data$cumulative),
                         color = "red", linewidth = 1) +
      ggplot2::geom_point(ggplot2::aes(x = .data$component, y = .data$cumulative),
                          color = "red", size = 2) +
      ggplot2::labs(x = "Principal Component", y = "Variance Explained (%)",
                    title = "Variance Explained by Each PC") +
      ggplot2::theme_minimal()

    plots$variance <- p_var
  }

  # Scores plot
  if (type %in% c("scores", "all") && length(components) >= 2) {
    scores_df <- data.frame(
      PC1 = x$scores[, 1],
      PC2 = x$scores[, 2],
      obs = seq_len(x$n_obs)
    )

    p_scores <- ggplot2::ggplot(scores_df,
                                 ggplot2::aes(x = .data$PC1, y = .data$PC2)) +
      ggplot2::geom_point(size = 2, alpha = 0.7) +
      ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
      ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
      ggplot2::labs(x = sprintf("PC1 (%.1f%%)", x$variance_explained[1] * 100),
                    y = sprintf("PC2 (%.1f%%)", x$variance_explained[2] * 100),
                    title = "fPCA Scores") +
      ggplot2::theme_minimal()

    plots$scores <- p_scores
  }

  if (type == "all") {
    return(plots)
  } else {
    return(plots[[type]])
  }
}

