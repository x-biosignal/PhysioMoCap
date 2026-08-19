# Generic Movement Visualization Functions
# Task-aware visualization using TaskSchema definitions

#' Plot normalized movement cycle
#'
#' Creates a waveform plot with automatic phase and event annotations based on
#' the TaskSchema. This is a generalized version of plotGaitCycle.
#'
#' @param x Normalized data (matrix, PhysioExperiment, or 3D array)
#' @param schema TaskSchema object for formatting and annotations
#' @param events Optional detected_events for event markers
#' @param channel Channel index or name to plot (for multi-channel data)
#' @param show_mean Show mean line
#' @param show_sd Show standard deviation band
#' @param show_ci Show confidence interval band
#' @param ci Confidence level (default 0.95)
#' @param show_individual Show individual trials
#' @param show_events Show event markers
#' @param show_phases Show phase regions
#' @param time_axis Custom time axis values
#' @param xlab X-axis label (default from schema)
#' @param ylab Y-axis label
#' @param title Plot title
#' @param colors Named vector of colors for phases
#' @param ... Additional arguments passed to ggplot
#'
#' @return A ggplot object
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotGroupComparison()] for multi-group comparisons,
#'   [plotMultiPanel()] for multi-channel cycle visualization,
#'   [plotPhaseDurations()] for phase duration bar charts.
#'
#' @export
#'
#' @examples
#' # Basic usage with schema
#' data <- matrix(rnorm(101 * 10), nrow = 101)
#' p <- plotCycle(data, schema = schema_gait)
#'
#' # With events
#' events <- manualEvents(schema_gait, c(hs1 = 0, to = 0.6, hs2 = 1.0),
#'                        sampling_rate = 100, n_samples = 101)
#' p <- plotCycle(data, schema = schema_gait, events = events)
plotCycle <- function(x,
                      schema = NULL,
                      events = NULL,
                      channel = 1L,
                      show_mean = TRUE,
                      show_sd = TRUE,
                      show_ci = FALSE,
                      ci = 0.95,
                      show_individual = FALSE,
                      show_events = NULL,
                      show_phases = NULL,
                      time_axis = NULL,
                      xlab = NULL,
                      ylab = "Value",
                      title = NULL,
                      colors = NULL,
                      ...) {

  # Extract data
  data <- .extractPlotData(x, channel)
  n_time <- nrow(data)
  n_trials <- ncol(data)

  # Get defaults from schema
  if (!is.null(schema)) {
    if (is.null(xlab)) xlab <- schema$vis_defaults$xlab %||% paste(schema$task_label, "(%)")
    if (is.null(show_events)) show_events <- schema$vis_defaults$show_events %||% TRUE
    if (is.null(show_phases)) show_phases <- schema$vis_defaults$show_phases %||% TRUE
    if (is.null(colors)) colors <- getPhaseColors(schema)
  } else {
    if (is.null(xlab)) xlab <- "Normalized Time (%)"
    if (is.null(show_events)) show_events <- !is.null(events)
    if (is.null(show_phases)) show_phases <- FALSE
  }

  # Time axis
  if (is.null(time_axis)) {
    time_axis <- seq(0, 100, length.out = n_time)
  }

  # Build plot data
  mean_vals <- rowMeans(data, na.rm = TRUE)
  sd_vals <- apply(data, 1, sd, na.rm = TRUE)

  plot_df <- data.frame(
    time = time_axis,
    mean = mean_vals,
    sd = sd_vals
  )

  # Calculate CI if needed
  if (show_ci) {
    se <- sd_vals / sqrt(n_trials)
    z <- qnorm(1 - (1 - ci) / 2)
    plot_df$ci_lower <- mean_vals - z * se
    plot_df$ci_upper <- mean_vals + z * se
  }

  # Initialize plot
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$time))

  # Add phase regions
  if (show_phases && !is.null(schema) && length(schema$phases) > 0) {
    p <- .addPhaseRegions(p, schema, time_axis, colors)
  }

  # Add individual trials
  if (show_individual && n_trials > 1) {
    for (i in seq_len(n_trials)) {
      trial_df <- data.frame(time = time_axis, value = data[, i])
      p <- p + ggplot2::geom_line(
        data = trial_df,
        ggplot2::aes(x = .data$time, y = .data$value),
        color = "gray70",
        alpha = 0.5,
        linewidth = 0.3
      )
    }
  }

  # Add SD band
  if (show_sd && !show_ci) {
    p <- p + ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$mean - .data$sd, ymax = .data$mean + .data$sd),
      fill = "steelblue",
      alpha = 0.3
    )
  }

  # Add CI band
  if (show_ci) {
    p <- p + ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$ci_lower, ymax = .data$ci_upper),
      fill = "steelblue",
      alpha = 0.3
    )
  }

  # Add mean line
  if (show_mean) {
    p <- p + ggplot2::geom_line(
      ggplot2::aes(y = .data$mean),
      color = "black",
      linewidth = 1
    )
  }

  # Add event markers
  if (show_events && !is.null(events)) {
    p <- .addEventMarkers(p, events, time_axis, schema)
  }

  # Labels and theme
  p <- p +
    ggplot2::labs(x = xlab, y = ylab, title = title) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank()
    )

  p
}


#' Add phase regions to plot
#' @keywords internal
.addPhaseRegions <- function(p, schema, time_axis, colors = NULL) {
  if (is.null(colors)) {
    colors <- getPhaseColors(schema)
  }

  t_range <- range(time_axis)

  for (phase in schema$phases) {
    # Get phase timing from typical event timing
    start_evt <- getEvent(schema, phase$start_event)
    end_evt <- getEvent(schema, phase$end_event)

    if (is.null(start_evt) || is.null(end_evt)) next

    start_pct <- start_evt$typical_timing %||% 0
    end_pct <- end_evt$typical_timing %||% 100

    # Scale to time axis range
    start_t <- t_range[1] + (start_pct / 100) * (t_range[2] - t_range[1])
    end_t <- t_range[1] + (end_pct / 100) * (t_range[2] - t_range[1])

    fill_color <- phase$color %||% colors[[phase$name]] %||% "gray90"
    alpha <- schema$vis_defaults$phase_alpha %||% 0.3

    p <- p + ggplot2::annotate(
      "rect",
      xmin = start_t, xmax = end_t,
      ymin = -Inf, ymax = Inf,
      fill = fill_color,
      alpha = alpha
    )
  }

  p
}


#' Add event markers to plot
#' @keywords internal
.addEventMarkers <- function(p, events, time_axis, schema = NULL) {
  t_range <- range(time_axis)

  for (i in seq_len(nrow(events))) {
    evt <- events[i, ]

    # Skip if no valid timing
    if (is.na(evt$percent)) next

    # Scale to time axis
    evt_t <- t_range[1] + (evt$percent / 100) * (t_range[2] - t_range[1])

    p <- p + ggplot2::geom_vline(
      xintercept = evt_t,
      linetype = "dashed",
      color = "gray40",
      linewidth = 0.5
    )

    # Add label at top
    p <- p + ggplot2::annotate(
      "text",
      x = evt_t,
      y = Inf,
      label = evt$label,
      vjust = -0.5,
      hjust = 0.5,
      size = 2.5,
      angle = 45
    )
  }

  p
}


#' Extract plot data from various input types
#' @keywords internal
.extractPlotData <- function(x, channel = 1) {
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
  } else if (is.array(x) && length(dim(x)) == 3) {
    # 3D array: time x channels x trials
    if (is.character(channel)) {
      channel <- which(dimnames(x)[[2]] == channel)
    }
    data <- x[, channel, , drop = TRUE]
    if (!is.matrix(data)) data <- matrix(data, ncol = dim(x)[3])
  } else if (is.matrix(x)) {
    data <- x
  } else if (is.numeric(x)) {
    data <- matrix(x, ncol = 1)
  } else {
    stop("Unsupported data type", call. = FALSE)
  }

  data
}


#' Plot group comparison with task context
#'
#' Compares waveforms between groups with schema-aware formatting.
#'
#' @param x Normalized data (matrix: time x samples)
#' @param groups Factor or character vector indicating group membership
#' @param schema TaskSchema object
#' @param events Optional detected_events
#' @param show_individual Show individual waveforms
#' @param ci Confidence interval level
#' @param xlab X-axis label
#' @param ylab Y-axis label
#' @param title Plot title
#' @param group_colors Named vector of colors for groups
#' @param ... Additional arguments
#'
#' @return A ggplot object
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotCycle()] for single-group cycle visualization,
#'   [plotWaveformComparison()] for alternative group comparison plots.
#'
#' @export
plotGroupComparison <- function(x,
                                 groups,
                                 schema = NULL,
                                 events = NULL,
                                 show_individual = FALSE,
                                 ci = 0.95,
                                 xlab = NULL,
                                 ylab = "Value",
                                 title = NULL,
                                 group_colors = NULL,
                                 ...) {

  # Get data
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
  } else {
    data <- as.matrix(x)
  }

  n_time <- nrow(data)
  n_samples <- ncol(data)

  groups <- as.factor(groups)
  if (length(groups) != n_samples) {
    stop("groups length must match number of samples", call. = FALSE)
  }

  # Get defaults from schema
  if (!is.null(schema)) {
    if (is.null(xlab)) xlab <- schema$vis_defaults$xlab %||% paste(schema$task_label, "(%)")
  } else {
    if (is.null(xlab)) xlab <- "Normalized Time (%)"
  }

  time_axis <- seq(0, 100, length.out = n_time)

  # Calculate group statistics
  group_stats <- lapply(levels(groups), function(g) {
    idx <- which(groups == g)
    group_data <- data[, idx, drop = FALSE]
    n <- length(idx)

    mean_vals <- rowMeans(group_data, na.rm = TRUE)
    sd_vals <- apply(group_data, 1, sd, na.rm = TRUE)
    se <- sd_vals / sqrt(n)
    z <- qnorm(1 - (1 - ci) / 2)

    data.frame(
      time = time_axis,
      group = g,
      mean = mean_vals,
      ci_lower = mean_vals - z * se,
      ci_upper = mean_vals + z * se
    )
  })

  plot_df <- do.call(rbind, group_stats)

  # Initialize plot
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$time, color = .data$group, fill = .data$group))

  # Add CI ribbons
  p <- p + ggplot2::geom_ribbon(
    ggplot2::aes(ymin = .data$ci_lower, ymax = .data$ci_upper),
    alpha = 0.3,
    color = NA
  )

  # Add individual lines if requested
  if (show_individual) {
    for (i in seq_len(n_samples)) {
      ind_df <- data.frame(
        time = time_axis,
        value = data[, i],
        group = groups[i]
      )
      p <- p + ggplot2::geom_line(
        data = ind_df,
        ggplot2::aes(x = .data$time, y = .data$value, color = .data$group),
        alpha = 0.3,
        linewidth = 0.3
      )
    }
  }

  # Add mean lines
  p <- p + ggplot2::geom_line(
    ggplot2::aes(y = .data$mean),
    linewidth = 1
  )

  # Colors
  if (!is.null(group_colors)) {
    p <- p + ggplot2::scale_color_manual(values = group_colors) +
      ggplot2::scale_fill_manual(values = group_colors)
  }

  # Add events
  if (!is.null(events)) {
    p <- .addEventMarkers(p, events, time_axis, schema)
  }

  # Labels and theme
  p <- p +
    ggplot2::labs(x = xlab, y = ylab, title = title, color = "Group", fill = "Group") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )

  p
}


#' Plot movement trajectory (2D)
#'
#' Plots 2D trajectory, useful for balance (CoP) or cutting (CoM) analysis.
#'
#' @param x X-coordinate data
#' @param y Y-coordinate data
#' @param schema TaskSchema object
#' @param show_path Show trajectory path
#' @param show_points Show individual points
#' @param show_ellipse Show confidence ellipse
#' @param ellipse_ci Confidence level for ellipse
#' @param show_start_end Mark start and end points
#' @param color_by Optional variable for coloring (e.g., time)
#' @param xlab X-axis label
#' @param ylab Y-axis label
#' @param title Plot title
#' @param ... Additional arguments
#'
#' @return A ggplot object
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotSkeleton()] for full-body skeleton visualization,
#'   [plotPhasePortrait()] for phase-space trajectory plots.
#'
#' @export
plotTrajectory <- function(x,
                            y,
                            schema = NULL,
                            show_path = TRUE,
                            show_points = FALSE,
                            show_ellipse = TRUE,
                            ellipse_ci = 0.95,
                            show_start_end = TRUE,
                            color_by = NULL,
                            xlab = NULL,
                            ylab = NULL,
                            title = NULL,
                            ...) {

  if (length(x) != length(y)) {
    stop("x and y must have the same length", call. = FALSE)
  }

  n <- length(x)

  # Get defaults from schema
  if (!is.null(schema) && schema$task_type == "balance") {
    if (is.null(xlab)) xlab <- "ML Position (mm)"
    if (is.null(ylab)) ylab <- "AP Position (mm)"
  } else {
    if (is.null(xlab)) xlab <- "X"
    if (is.null(ylab)) ylab <- "Y"
  }

  # Build data frame
  plot_df <- data.frame(x = x, y = y)
  if (!is.null(color_by)) {
    plot_df$color <- color_by
  } else {
    plot_df$color <- seq_len(n)
  }

  # Initialize plot
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$x, y = .data$y))

  # Add ellipse
  if (show_ellipse) {
    p <- p + ggplot2::stat_ellipse(
      level = ellipse_ci,
      geom = "polygon",
      fill = "steelblue",
      alpha = 0.2
    )
  }

  # Add path
  if (show_path) {
    p <- p + ggplot2::geom_path(
      ggplot2::aes(color = .data$color),
      linewidth = 0.5,
      alpha = 0.7
    )
  }

  # Add points
  if (show_points) {
    p <- p + ggplot2::geom_point(
      ggplot2::aes(color = .data$color),
      size = 0.5,
      alpha = 0.5
    )
  }

  # Mark start and end
  if (show_start_end) {
    p <- p +
      ggplot2::geom_point(
        data = plot_df[1, ],
        color = "green",
        size = 3,
        shape = 16
      ) +
      ggplot2::geom_point(
        data = plot_df[n, ],
        color = "red",
        size = 3,
        shape = 16
      )
  }

  # Labels and theme
  p <- p +
    ggplot2::labs(x = xlab, y = ylab, title = title) +
    ggplot2::coord_equal() +
    ggplot2::scale_color_viridis_c(option = "plasma") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = "none"
    )

  p
}


#' Plot phase duration comparison
#'
#' Visualizes phase durations across conditions or groups.
#'
#' @param phases_list List of segmented_phases objects or timing data.frames
#' @param labels Labels for each entry
#' @param unit "percent" or "seconds"
#' @param show_values Show duration values on bars
#' @param title Plot title
#' @param ... Additional arguments
#'
#' @return A ggplot object
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotCycle()] for cycle-normalized waveform visualization,
#'   [calculateGaitParameters()] for computing gait phase parameters.
#'
#' @export
plotPhaseDurations <- function(phases_list,
                                labels = NULL,
                                unit = c("percent", "seconds"),
                                show_values = TRUE,
                                title = "Phase Durations",
                                ...) {

  unit <- match.arg(unit)

  # Handle different input types
  if (inherits(phases_list, "segmented_phases")) {
    phases_list <- list(phases_list)
  }

  if (is.null(labels)) {
    labels <- paste0("Trial_", seq_along(phases_list))
  }

  # Extract timing data
  timing_list <- lapply(seq_along(phases_list), function(i) {
    p <- phases_list[[i]]
    if (inherits(p, "segmented_phases")) {
      timing <- phaseTiming(p, as_percent = (unit == "percent"))
      timing$trial <- labels[i]
    } else if (is.data.frame(p)) {
      timing <- p
      timing$trial <- labels[i]
    } else {
      stop("Invalid input type", call. = FALSE)
    }
    timing
  })

  plot_df <- do.call(rbind, timing_list)

  # Create plot
  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = .data$trial, y = .data$duration, fill = .data$phase)
  ) +
    ggplot2::geom_bar(stat = "identity", position = "stack") +
    ggplot2::labs(
      x = "",
      y = if (unit == "percent") "Duration (%)" else "Duration (s)",
      title = title,
      fill = "Phase"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  if (show_values) {
    p <- p + ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.1f", .data$duration)),
      position = ggplot2::position_stack(vjust = 0.5),
      size = 3
    )
  }

  p
}


#' Plot multi-panel movement data
#'
#' Creates a faceted plot showing multiple channels or variables.
#'
#' @param x Normalized data (matrix or 3D array)
#' @param schema TaskSchema object
#' @param channels Channels to plot (indices or names)
#' @param facet_scales Scales for faceting ("free_y", "fixed", etc.)
#' @param show_mean Show mean across trials
#' @param show_sd Show SD bands
#' @param ... Additional arguments passed to plotCycle
#'
#' @return A ggplot object
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotCycle()] for single-channel cycle visualization,
#'   [plotGroupComparison()] for between-group comparisons.
#'
#' @export
plotMultiPanel <- function(x,
                            schema = NULL,
                            channels = NULL,
                            facet_scales = "free_y",
                            show_mean = TRUE,
                            show_sd = TRUE,
                            ...) {

  # Get data as matrix
  if (inherits(x, "PhysioExperiment")) {
    data <- SummarizedExperiment::assay(x, defaultAssay(x))
  } else {
    data <- as.matrix(x)
  }

  n_time <- nrow(data)
  n_channels <- ncol(data)

  # Select channels
  if (is.null(channels)) {
    channels <- seq_len(min(n_channels, 6))  # Max 6 channels
  }

  channel_names <- colnames(data)
  if (is.null(channel_names)) {
    channel_names <- paste0("Ch", seq_len(n_channels))
  }

  time_axis <- seq(0, 100, length.out = n_time)

  # Build long-format data
  plot_data <- do.call(rbind, lapply(channels, function(ch) {
    ch_name <- if (is.character(ch)) ch else channel_names[ch]
    ch_idx <- if (is.character(ch)) which(channel_names == ch) else ch

    data.frame(
      time = time_axis,
      value = data[, ch_idx],
      channel = ch_name
    )
  }))

  # Get xlab from schema
  xlab <- if (!is.null(schema)) {
    schema$vis_defaults$xlab %||% paste(schema$task_label, "(%)")
  } else {
    "Normalized Time (%)"
  }

  # Create plot
  p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$time, y = .data$value)) +
    ggplot2::geom_line(color = "steelblue", linewidth = 0.8) +
    ggplot2::facet_wrap(~ .data$channel, scales = facet_scales, ncol = 2) +
    ggplot2::labs(x = xlab, y = "Value") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(face = "bold")
    )

  p
}
