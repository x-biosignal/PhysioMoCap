# Colorblind-safe Left/Right colours from the shared ecosystem palette.
.side_colours <- function() {
  stats::setNames(PhysioCore::physioPalette(2), c("Left", "Right"))
}

#' Plot waveform comparison across groups
#'
#' Creates a comparison plot showing mean waveforms with confidence bands
#' for multiple groups. Ideal for comparing gait patterns between conditions.
#'
#' @param x A PhysioExperiment object or matrix (time x observations).
#' @param groups Factor or vector indicating group membership.
#' @param channel For PhysioExperiment with multiple channels, which to plot.
#' @param ci Confidence interval level (default: 0.95).
#' @param show_individual Logical; show individual waveforms as thin lines.
#' @param time_axis Optional time axis values (e.g., 0-100 for gait cycle).
#' @param colors Optional color palette for groups.
#' @param title Plot title.
#' @param xlab X-axis label.
#' @param ylab Y-axis label.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotGaitCycle()] for single-group gait cycle visualization,
#'   [plotSymmetry()] for left-right symmetry plots,
#'   [plotSpaghetti()] for individual waveform overlay plots.
#'
#' @export
#' @examples
#' # Compare gait patterns between groups
#' set.seed(123)
#' # Control group
#' control <- sapply(1:15, function(i) sin(seq(0, 2*pi, length.out = 101)) * 30 + rnorm(101, 0, 3))
#' # Patient group (reduced range of motion)
#' patient <- sapply(1:15, function(i) sin(seq(0, 2*pi, length.out = 101)) * 20 + rnorm(101, 0, 3))
#'
#' data <- cbind(control, patient)
#' groups <- factor(rep(c("Control", "Patient"), each = 15))
#'
#' plotWaveformComparison(data, groups, time_axis = 0:100,
#'                        xlab = "Gait Cycle (%)", ylab = "Knee Angle (deg)")
plotWaveformComparison <- function(x, groups, channel = 1L, ci = 0.95,
                                    show_individual = FALSE,
                                    time_axis = NULL, colors = NULL,
                                    title = NULL, xlab = "Time", ylab = "Value") {

  # Extract data
  if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
    if (length(dim(data)) == 3) {
      data <- data[, channel, ]
    }
  } else if (is.matrix(x)) {
    data <- x
  } else {
    stop("Input must be a PhysioExperiment or matrix", call. = FALSE)
  }

  n_time <- nrow(data)
  n_obs <- ncol(data)

  groups <- as.factor(groups)
  if (length(groups) != n_obs) {
    stop("Length of groups must match number of observations", call. = FALSE)
  }

  if (is.null(time_axis)) {
    time_axis <- seq_len(n_time)
  }

  # Calculate statistics for each group
  group_levels <- levels(groups)
  n_groups <- length(group_levels)

  # Build data frame for plotting
  plot_data <- data.frame()
  ribbon_data <- data.frame()

  z_val <- qnorm(1 - (1 - ci) / 2)

  for (g in group_levels) {
    group_data <- data[, groups == g, drop = FALSE]
    n_g <- ncol(group_data)

    mean_vals <- rowMeans(group_data, na.rm = TRUE)
    sd_vals <- apply(group_data, 1, sd, na.rm = TRUE)
    se_vals <- sd_vals / sqrt(n_g)

    ci_lower <- mean_vals - z_val * se_vals
    ci_upper <- mean_vals + z_val * se_vals

    ribbon_data <- rbind(ribbon_data, data.frame(
      time = time_axis,
      mean = mean_vals,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      group = g
    ))

    # Individual waveforms
    if (show_individual) {
      for (i in seq_len(n_g)) {
        plot_data <- rbind(plot_data, data.frame(
          time = time_axis,
          value = group_data[, i],
          group = g,
          subject = paste0(g, "_", i)
        ))
      }
    }
  }

  ribbon_data$group <- factor(ribbon_data$group, levels = group_levels)

  # Set colors
  if (is.null(colors)) {
    colors <- scales::hue_pal()(n_groups)
  }

  # Create plot
  p <- ggplot2::ggplot()

  # Add individual waveforms
  if (show_individual && nrow(plot_data) > 0) {
    plot_data$group <- factor(plot_data$group, levels = group_levels)
    p <- p +
      ggplot2::geom_line(
        data = plot_data,
        ggplot2::aes(x = .data$time, y = .data$value,
                     group = .data$subject, color = .data$group),
        alpha = 0.2, linewidth = 0.3
      )
  }

  # Add CI ribbons
  p <- p +
    ggplot2::geom_ribbon(
      data = ribbon_data,
      ggplot2::aes(x = .data$time, ymin = .data$ci_lower, ymax = .data$ci_upper,
                   fill = .data$group),
      alpha = 0.3
    ) +
    # Add mean lines
    ggplot2::geom_line(
      data = ribbon_data,
      ggplot2::aes(x = .data$time, y = .data$mean, color = .data$group),
      linewidth = 1.2
    ) +
    ggplot2::scale_color_manual(values = colors) +
    ggplot2::scale_fill_manual(values = colors) +
    ggplot2::labs(x = xlab, y = ylab, color = "Group", fill = "Group") +
    ggplot2::theme_minimal()

  if (!is.null(title)) {
    p <- p + ggplot2::ggtitle(title)
  }

  p
}

#' Plot symmetry comparison (left vs right)
#'
#' Creates a symmetry plot comparing bilateral waveforms, useful for
#' gait symmetry analysis.
#'
#' @param left Matrix of left side waveforms (time x observations).
#' @param right Matrix of right side waveforms (time x observations).
#' @param time_axis Optional time axis values.
#' @param ci Confidence interval level.
#' @param show_diagonal Logical; show y=x diagonal reference line.
#' @param plot_type "overlay" for time series, "scatter" for L vs R scatter.
#' @param title Plot title.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotWaveformComparison()] for multi-group waveform comparisons,
#'   [calculateStepSymmetry()] for quantifying gait symmetry,
#'   [symmetryIndex()] for computing symmetry indices.
#'
#' @export
#' @examples
#' # Compare left and right knee angles
#' set.seed(123)
#' t <- seq(0, 100, length.out = 101)
#' left <- sapply(1:20, function(i) sin(2*pi*t/100) * 30 + rnorm(101, 0, 2))
#' right <- sapply(1:20, function(i) sin(2*pi*t/100) * 28 + rnorm(101, 0, 2))  # Slight asymmetry
#'
#' plotSymmetry(left, right, time_axis = t, plot_type = "overlay")
plotSymmetry <- function(left, right, time_axis = NULL, ci = 0.95,
                          show_diagonal = TRUE, plot_type = c("overlay", "scatter"),
                          title = "Symmetry Analysis") {

  plot_type <- match.arg(plot_type)

  if (!is.matrix(left)) left <- as.matrix(left)
  if (!is.matrix(right)) right <- as.matrix(right)

  if (nrow(left) != nrow(right)) {
    stop("Left and right must have same number of time points", call. = FALSE)
  }

  n_time <- nrow(left)
  if (is.null(time_axis)) {
    time_axis <- seq(0, 100, length.out = n_time)
  }

  z_val <- qnorm(1 - (1 - ci) / 2)

  if (plot_type == "overlay") {
    # Compute mean and CI for each side
    left_mean <- rowMeans(left, na.rm = TRUE)
    left_se <- apply(left, 1, sd, na.rm = TRUE) / sqrt(ncol(left))
    right_mean <- rowMeans(right, na.rm = TRUE)
    right_se <- apply(right, 1, sd, na.rm = TRUE) / sqrt(ncol(right))

    df <- data.frame(
      time = rep(time_axis, 2),
      mean = c(left_mean, right_mean),
      ci_lower = c(left_mean - z_val * left_se, right_mean - z_val * right_se),
      ci_upper = c(left_mean + z_val * left_se, right_mean + z_val * right_se),
      side = factor(rep(c("Left", "Right"), each = n_time))
    )

    p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$time)) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$ci_lower, ymax = .data$ci_upper,
                                         fill = .data$side), alpha = 0.3) +
      ggplot2::geom_line(ggplot2::aes(y = .data$mean, color = .data$side), linewidth = 1.2) +
      ggplot2::scale_color_manual(values = .side_colours()) +
      ggplot2::scale_fill_manual(values = .side_colours()) +
      ggplot2::labs(x = "Gait Cycle (%)", y = "Value", color = "Side", fill = "Side") +
      ggplot2::theme_minimal()

  } else {
    # Scatter plot: left vs right at each time point
    df <- data.frame(
      left = as.vector(left),
      right = as.vector(right)
    )

    p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$left, y = .data$right)) +
      ggplot2::geom_point(alpha = 0.3, size = 1) +
      ggplot2::geom_smooth(method = "lm", color = "blue", se = TRUE) +
      ggplot2::labs(x = "Left", y = "Right") +
      ggplot2::theme_minimal() +
      ggplot2::coord_fixed()

    if (show_diagonal) {
      lims <- range(c(df$left, df$right), na.rm = TRUE)
      p <- p + ggplot2::geom_abline(intercept = 0, slope = 1,
                                     linetype = "dashed", color = "gray50")
    }
  }

  if (!is.null(title)) {
    p <- p + ggplot2::ggtitle(title)
  }

  p
}

#' Plot gait cycle normalized waveforms
#'
#' Plots waveforms normalized to gait cycle (0-100%) with options for
#' displaying multiple trials, mean, and variability bands.
#'
#' @param x A PhysioExperiment, matrix, or list of matrices.
#' @param events Optional data.frame with gait events (heel strike, toe off).
#' @param normalize_to Length to normalize (default: 101 for 0-100%).
#' @param show_events Logical; show vertical lines at gait events.
#' @param show_mean Logical; show mean waveform.
#' @param show_sd Logical; show SD bands.
#' @param show_individual Logical; show individual trials.
#' @param event_labels Labels for gait events.
#' @param title Plot title.
#' @param ylab Y-axis label.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [plotWaveformComparison()] for multi-group comparisons,
#'   [plotSpaghetti()] for individual waveform overlays,
#'   [calculateGaitParameters()] for computing gait metrics.
#'
#' @export
#' @examples
#' # Normalize and plot knee angle across gait cycle
#' set.seed(123)
#' data <- sapply(1:10, function(i) {
#'   n <- sample(90:110, 1)  # Variable cycle length
#'   sin(seq(0, 2*pi, length.out = n)) * 60 + rnorm(n, 0, 3)
#' })
#'
#' plotGaitCycle(data, show_mean = TRUE, show_sd = TRUE,
#'               ylab = "Knee Flexion (deg)")
plotGaitCycle <- function(x, events = NULL, normalize_to = 101,
                           show_events = TRUE, show_mean = TRUE,
                           show_sd = TRUE, show_individual = TRUE,
                           event_labels = c("HS" = 0, "TO" = 60, "HS" = 100),
                           title = "Gait Cycle", ylab = "Value") {

  # Handle different input types
  if (is.list(x) && !is.data.frame(x) && !inherits(x, "PhysioExperiment")) {
    # List of trials with different lengths
    trials <- lapply(x, function(trial) {
      if (is.matrix(trial)) trial[, 1] else as.numeric(trial)
    })
  } else if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
    trials <- lapply(seq_len(ncol(data)), function(i) data[, i])
  } else if (is.matrix(x)) {
    trials <- lapply(seq_len(ncol(x)), function(i) x[, i])
  } else {
    trials <- list(as.numeric(x))
  }

  # Normalize each trial to same length
  normalized <- lapply(trials, function(trial) {
    n <- length(trial)
    stats::approx(seq_len(n), trial, n = normalize_to)$y
  })

  # Convert to matrix
  norm_matrix <- do.call(cbind, normalized)
  n_trials <- ncol(norm_matrix)
  gait_pct <- seq(0, 100, length.out = normalize_to)

  # Build plot data
  plot_data <- data.frame()

  if (show_individual) {
    for (i in seq_len(n_trials)) {
      plot_data <- rbind(plot_data, data.frame(
        gait_pct = gait_pct,
        value = norm_matrix[, i],
        trial = paste0("Trial_", i)
      ))
    }
  }

  # Summary statistics
  mean_vals <- rowMeans(norm_matrix, na.rm = TRUE)
  sd_vals <- apply(norm_matrix, 1, sd, na.rm = TRUE)

  summary_data <- data.frame(
    gait_pct = gait_pct,
    mean = mean_vals,
    sd_lower = mean_vals - sd_vals,
    sd_upper = mean_vals + sd_vals
  )

  # Create plot
  p <- ggplot2::ggplot()

  # Individual trials
  if (show_individual && nrow(plot_data) > 0) {
    p <- p + ggplot2::geom_line(
      data = plot_data,
      ggplot2::aes(x = .data$gait_pct, y = .data$value, group = .data$trial),
      color = "gray70", alpha = 0.5, linewidth = 0.3
    )
  }

  # SD band
  if (show_sd) {
    p <- p + ggplot2::geom_ribbon(
      data = summary_data,
      ggplot2::aes(x = .data$gait_pct, ymin = .data$sd_lower, ymax = .data$sd_upper),
      fill = "steelblue", alpha = 0.3
    )
  }

  # Mean line
  if (show_mean) {
    p <- p + ggplot2::geom_line(
      data = summary_data,
      ggplot2::aes(x = .data$gait_pct, y = .data$mean),
      color = "steelblue", linewidth = 1.5
    )
  }

  # Gait events
  if (show_events && !is.null(event_labels)) {
    for (i in seq_along(event_labels)) {
      event_pct <- event_labels[i]
      event_name <- names(event_labels)[i]

      p <- p +
        ggplot2::geom_vline(xintercept = event_pct, linetype = "dashed",
                            color = "gray40", linewidth = 0.5) +
        ggplot2::annotate("text", x = event_pct, y = Inf, label = event_name,
                          vjust = 2, hjust = 0.5, size = 3, color = "gray40")
    }
  }

  p <- p +
    ggplot2::scale_x_continuous(breaks = seq(0, 100, 20)) +
    ggplot2::labs(x = "Gait Cycle (%)", y = ylab, title = title) +
    ggplot2::theme_minimal()

  p
}

#' Plot phase portrait
#'
#' Creates a phase portrait (angle vs angular velocity) for analyzing
#' movement dynamics and coordination patterns.
#'
#' @param angle Angle time series (vector or matrix).
#' @param velocity Angular velocity. If NULL, computed from angle.
#' @param sampling_rate Sampling rate (needed if velocity computed).
#' @param groups Optional grouping factor.
#' @param normalize Logical; normalize to unit circle.
#' @param title Plot title.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [computeVelocity()] for computing angular velocities from position data,
#'   [plotGaitCycle()] for time-domain gait cycle visualization.
#'
#' @export
#' @examples
#' # Phase portrait of knee angle
#' set.seed(123)
#' t <- seq(0, 2*pi, length.out = 100)
#' angle <- sin(t) * 60
#' velocity <- cos(t) * 60 * (2*pi/100)  # Derivative
#'
#' plotPhasePortrait(angle, velocity)
plotPhasePortrait <- function(angle, velocity = NULL, sampling_rate = 100,
                               groups = NULL, normalize = FALSE, title = "Phase Portrait") {

  if (is.matrix(angle)) {
    angle_vec <- as.vector(angle)
    n_obs <- ncol(angle)
    n_time <- nrow(angle)
    obs_id <- rep(seq_len(n_obs), each = n_time)
  } else {
    angle_vec <- as.numeric(angle)
    n_obs <- 1
    n_time <- length(angle_vec)
    obs_id <- rep(1, n_time)
  }

  # Compute velocity if not provided
  if (is.null(velocity)) {
    if (is.matrix(angle)) {
      velocity <- apply(angle, 2, function(col) {
        c(diff(col) * sampling_rate, NA)
      })
    } else {
      velocity <- c(diff(angle) * sampling_rate, NA)
    }
  }

  velocity_vec <- as.vector(velocity)

  # Normalize if requested
  if (normalize) {
    angle_range <- max(abs(angle_vec), na.rm = TRUE)
    velocity_range <- max(abs(velocity_vec), na.rm = TRUE)

    if (angle_range > 0) angle_vec <- angle_vec / angle_range
    if (velocity_range > 0) velocity_vec <- velocity_vec / velocity_range
  }

  df <- data.frame(
    angle = angle_vec,
    velocity = velocity_vec,
    obs = factor(obs_id)
  )

  if (!is.null(groups)) {
    if (length(groups) == n_obs) {
      df$group <- factor(rep(groups, each = n_time))
    } else {
      df$group <- factor(groups)
    }
  }

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$angle, y = .data$velocity))

  if (!is.null(groups)) {
    p <- p + ggplot2::geom_path(ggplot2::aes(color = .data$group, group = .data$obs),
                                 alpha = 0.7, linewidth = 0.8)
  } else if (n_obs > 1) {
    p <- p + ggplot2::geom_path(ggplot2::aes(group = .data$obs),
                                 color = "steelblue", alpha = 0.5, linewidth = 0.5)
  } else {
    p <- p + ggplot2::geom_path(color = "steelblue", linewidth = 1)
  }

  # Add reference lines
  p <- p +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "gray50")

  axis_label <- if (normalize) {
    list(x = "Normalized Angle", y = "Normalized Angular Velocity")
  } else {
    list(x = "Angle (deg)", y = "Angular Velocity (deg/s)")
  }

  p <- p +
    ggplot2::labs(x = axis_label$x, y = axis_label$y, title = title) +
    ggplot2::theme_minimal() +
    ggplot2::coord_fixed()

  p
}

#' Plot effect size forest plot
#'
#' Creates a forest plot displaying effect sizes with confidence intervals,
#' commonly used for meta-analysis style visualization of multiple comparisons.
#'
#' @param effects Named vector or data.frame of effect sizes.
#' @param ci_lower Lower confidence interval bounds.
#' @param ci_upper Upper confidence interval bounds.
#' @param labels Labels for each effect (uses names if not provided).
#' @param null_value Reference line value (default: 0).
#' @param sort_by How to sort: "none", "effect", "name".
#' @param title Plot title.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [cohensD()] for computing Cohen's d effect sizes,
#'   [etaSquared()] for computing eta-squared effect sizes,
#'   [plotCorrelationMatrix()] for correlation heatmaps.
#'
#' @export
#' @examples
#' # Forest plot of effect sizes across joints
#' effects <- c(Hip = 0.8, Knee = 1.2, Ankle = 0.3)
#' ci_lower <- c(0.4, 0.8, -0.1)
#' ci_upper <- c(1.2, 1.6, 0.7)
#'
#' plotEffectSizeForest(effects, ci_lower, ci_upper)
plotEffectSizeForest <- function(effects, ci_lower, ci_upper,
                                  labels = NULL, null_value = 0,
                                  sort_by = c("none", "effect", "name"),
                                  title = "Effect Sizes") {

  sort_by <- match.arg(sort_by)

  if (is.null(labels)) {
    labels <- names(effects)
    if (is.null(labels)) {
      labels <- paste0("Effect_", seq_along(effects))
    }
  }

  df <- data.frame(
    label = labels,
    effect = as.numeric(effects),
    ci_lower = as.numeric(ci_lower),
    ci_upper = as.numeric(ci_upper)
  )

  # Sort
  if (sort_by == "effect") {
    df <- df[order(df$effect), ]
  } else if (sort_by == "name") {
    df <- df[order(df$label), ]
  }

  df$label <- factor(df$label, levels = df$label)

  # Significance indicator
 df$significant <- !(df$ci_lower <= null_value & df$ci_upper >= null_value)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$effect, y = .data$label)) +
    # CI error bars
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = .data$ci_lower, xmax = .data$ci_upper),
      width = 0.2, color = "gray40"
    ) +
    # Effect points
    ggplot2::geom_point(
      ggplot2::aes(color = .data$significant),
      size = 3
    ) +
    # Null reference line
    ggplot2::geom_vline(xintercept = null_value, linetype = "dashed", color = "gray50") +
    ggplot2::scale_color_manual(
      values = c("TRUE" = "steelblue", "FALSE" = "gray60"),
      labels = c("TRUE" = "Significant", "FALSE" = "Not significant"),
      name = ""
    ) +
    ggplot2::labs(x = "Effect Size", y = "", title = title) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "bottom")

  p
}

#' Plot correlation matrix heatmap
#'
#' Creates a heatmap visualization of a correlation matrix with optional
#' clustering and significance masking.
#'
#' @param x A correlation matrix, data.frame, or PhysioExperiment.
#' @param method If x is data, correlation method: "pearson", "spearman", "kendall".
#' @param cluster Logical; apply hierarchical clustering to reorder.
#' @param show_values Logical; display correlation values in cells.
#' @param show_significance Logical; mask non-significant correlations.
#' @param alpha Significance threshold for masking.
#' @param colors Color palette (low, mid, high).
#' @param title Plot title.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotEffectSizeForest()] for forest plots of effect sizes,
#'   [plotWaveformComparison()] for comparing waveform patterns across groups.
#'
#' @export
#' @examples
#' # Correlation matrix of joint angles
#' set.seed(123)
#' data <- data.frame(
#'   Hip = rnorm(100),
#'   Knee = rnorm(100),
#'   Ankle = rnorm(100)
#' )
#' data$Knee <- data$Hip * 0.7 + rnorm(100, 0, 0.5)  # Correlated
#'
#' plotCorrelationMatrix(data)
plotCorrelationMatrix <- function(x, method = "pearson", cluster = TRUE,
                                   show_values = TRUE, show_significance = FALSE,
                                   alpha = 0.05, colors = c("#B2182B", "white", "#2166AC"),
                                   title = "Correlation Matrix") {

  # Compute correlation matrix if needed
  if (inherits(x, "PhysioExperiment")) {
    assay_name <- defaultAssay(x)
    data <- SummarizedExperiment::assay(x, assay_name)
    cor_matrix <- cor(t(data), method = method, use = "pairwise.complete.obs")
  } else if (is.data.frame(x)) {
    cor_matrix <- cor(x, method = method, use = "pairwise.complete.obs")
  } else if (is.matrix(x)) {
    # Check if already a correlation matrix
    if (all(diag(x) == 1, na.rm = TRUE) && all(x >= -1 & x <= 1, na.rm = TRUE)) {
      cor_matrix <- x
    } else {
      cor_matrix <- cor(x, method = method, use = "pairwise.complete.obs")
    }
  } else {
    stop("Input must be a matrix, data.frame, or PhysioExperiment", call. = FALSE)
  }

  var_names <- rownames(cor_matrix)
  if (is.null(var_names)) {
    var_names <- paste0("V", seq_len(nrow(cor_matrix)))
  }

  # Hierarchical clustering for ordering
  if (cluster && nrow(cor_matrix) > 2) {
    hc <- hclust(as.dist(1 - cor_matrix), method = "complete")
    order_idx <- hc$order
    cor_matrix <- cor_matrix[order_idx, order_idx]
    var_names <- var_names[order_idx]
  }

  # Convert to long format
  n <- nrow(cor_matrix)
  df <- expand.grid(
    var1 = var_names,
    var2 = var_names
  )
  df$correlation <- as.vector(cor_matrix)
  df$var1 <- factor(df$var1, levels = var_names)
  df$var2 <- factor(df$var2, levels = rev(var_names))

  # Significance masking
  if (show_significance) {
    # Compute p-values (approximate)
    n_obs <- ifelse(is.data.frame(x), nrow(x),
                    ifelse(inherits(x, "PhysioExperiment"), ncol(SummarizedExperiment::assay(x)), 30))
    t_stat <- df$correlation * sqrt(n_obs - 2) / sqrt(1 - df$correlation^2)
    df$p_value <- 2 * pt(-abs(t_stat), df = n_obs - 2)
    df$significant <- df$p_value < alpha
    df$correlation[!df$significant & df$var1 != df$var2] <- NA
  }

  # Create heatmap
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$var1, y = .data$var2, fill = .data$correlation)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::scale_fill_gradient2(
      low = colors[1], mid = colors[2], high = colors[3],
      midpoint = 0, limits = c(-1, 1),
      name = "Correlation",
      na.value = "gray90"
    ) +
    ggplot2::labs(x = "", y = "", title = title) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid = ggplot2::element_blank()
    ) +
    ggplot2::coord_fixed()

  # Add correlation values
  if (show_values) {
    label_df <- df
    label_df$label <- sprintf("%.2f", label_df$correlation)
    label_df$label[is.na(label_df$correlation)] <- ""

    p <- p + ggplot2::geom_text(
      data = label_df,
      ggplot2::aes(x = .data$var1, y = .data$var2, label = .data$label),
      size = 3, color = "black"
    )
  }

  p
}

#' Plot spaghetti plot (all subjects with mean)
#'
#' Creates a spaghetti plot showing individual subject waveforms
#' with a highlighted mean trajectory.
#'
#' @param x A PhysioExperiment or matrix (time x observations).
#' @param time_axis Optional time axis values.
#' @param highlight_mean Logical; highlight mean with thick line.
#' @param individual_color Color for individual lines.
#' @param mean_color Color for mean line.
#' @param alpha Transparency for individual lines.
#' @param title Plot title.
#' @param xlab X-axis label.
#' @param ylab Y-axis label.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotGaitCycle()] for gait cycle visualization with event markers,
#'   [plotWaveformComparison()] for multi-group waveform comparisons.
#'
#' @export
plotSpaghetti <- function(x, time_axis = NULL, highlight_mean = TRUE,
                           individual_color = "gray60", mean_color = "red",
                           alpha = 0.4, title = NULL, xlab = "Time", ylab = "Value") {

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

  if (is.null(time_axis)) {
    time_axis <- seq_len(n_time)
  }

  # Build data frame
  plot_data <- data.frame(
    time = rep(time_axis, n_obs),
    value = as.vector(data),
    subject = factor(rep(seq_len(n_obs), each = n_time))
  )

  mean_data <- data.frame(
    time = time_axis,
    value = rowMeans(data, na.rm = TRUE)
  )

  p <- ggplot2::ggplot() +
    ggplot2::geom_line(
      data = plot_data,
      ggplot2::aes(x = .data$time, y = .data$value, group = .data$subject),
      color = individual_color, alpha = alpha, linewidth = 0.5
    )

  if (highlight_mean) {
    p <- p + ggplot2::geom_line(
      data = mean_data,
      ggplot2::aes(x = .data$time, y = .data$value),
      color = mean_color, linewidth = 1.5
    )
  }

  p <- p +
    ggplot2::labs(x = xlab, y = ylab, title = title) +
    ggplot2::theme_minimal()

  p
}


#' Plot a Movement Analysis Profile
#'
#' Draws the Movement Analysis Profile (Baker et al. 2009) as a bar chart of the
#' Gait Variable Score for each kinematic variable, with a reference line at the
#' overall Gait Profile Score.
#'
#' @param map A `movement_analysis_profile` object from
#'   [movementAnalysisProfile()].
#' @param title Plot title.
#' @return A `ggplot` object.
#' @seealso [movementAnalysisProfile()]
#' @export
#' @examples
#' norm <- list(variables = c("a", "b"),
#'              mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
#'              cycle_length = 51)
#' map <- movementAnalysisProfile(
#'   matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)), norm)
#' plotMAP(map)
plotMAP <- function(map, title = "Movement Analysis Profile") {
  if (!inherits(map, "movement_analysis_profile")) {
    stop("`map` must be a movement_analysis_profile object.", call. = FALSE)
  }
  df <- data.frame(
    variable = factor(map$variables, levels = map$variables),
    gvs = as.numeric(map$gvs[map$variables]),
    stringsAsFactors = FALSE
  )
  ggplot2::ggplot(df, ggplot2::aes(x = .data$variable, y = .data$gvs)) +
    ggplot2::geom_col(fill = "#4C78A8") +
    ggplot2::geom_hline(yintercept = map$gps, linetype = "dashed",
                        color = "#E45756") +
    ggplot2::labs(x = NULL, y = "Gait Variable Score (deg)",
                  title = title,
                  subtitle = sprintf("GPS = %.2f deg", map$gps)) +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}
