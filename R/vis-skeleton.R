# Skeleton Visualization Functions
# 2D stick-figure visualization of skeleton models from pose estimation or
# motion capture data stored in PhysioExperiment objects.

#' Project 3D coordinates to a 2D plane
#'
#' Selects two of three coordinate axes based on the anatomical plane,
#' returning a data frame with `u` (horizontal) and `v` (vertical) columns.
#'
#' @param x Numeric vector of X (medial-lateral) coordinates.
#' @param y Numeric vector of Y (anterior-posterior) coordinates.
#' @param z Numeric vector of Z (vertical) coordinates.
#' @param plane Character string specifying the projection plane.
#'   One of `"sagittal"`, `"frontal"`, or `"transverse"`.
#'
#' @return A data frame with columns `u` and `v`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [plotSkeleton()] for 2D skeleton visualization,
#'   [plotSkeleton3D()] for pseudo-3D skeleton rendering.
#'
#' @export
#' @examples
#' proj <- projectTo2D(c(1, 2), c(3, 4), c(5, 6), plane = "sagittal")
#' proj$u  # Y values (anterior-posterior)
#' proj$v  # Z values (vertical)
projectTo2D <- function(x, y, z, plane = c("sagittal", "frontal", "transverse")) {
  plane <- match.arg(plane)
  switch(plane,
    sagittal    = data.frame(u = y, v = z),
    frontal     = data.frame(u = x, v = z),
    transverse  = data.frame(u = x, v = y)
  )
}


#' Plot a 2D stick-figure skeleton
#'
#' Draws a single frame from a PhysioExperiment as a 2D stick figure by
#' projecting 3D marker positions onto an anatomical plane.
#'
#' @param pe A PhysioExperiment object with `position_x`, `position_y`, and
#'   `position_z` assays (columns named by keypoint label).
#' @param skeleton A `SkeletonModel` object whose keypoint labels match
#'   column names in the position assays.
#' @param frame Integer frame (row) index to plot (default 1).
#' @param plane Anatomical plane for projection: `"sagittal"` (drop X),
#'   `"frontal"` (drop Y), or `"transverse"` (drop Z).
#' @param show_labels Logical; annotate markers with their labels.
#' @param show_confidence Logical; color markers by confidence if a
#'   `confidence` assay is present.
#' @param point_size Marker point size (default 3).
#' @param segment_color Color for bone segments (default `"gray40"`).
#' @param title Plot title. If `NULL`, auto-generated.
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [plotSkeletonSequence()] for multi-frame faceted display,
#'   [plotSkeletonOverlay()] for overlaid motion visualization,
#'   [plotSkeleton3D()] for pseudo-3D rendering,
#'   [projectTo2D()] for coordinate projection utilities.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readOpenPose("frames/", model = "BODY_25")
#' sk <- define_skeleton("BODY_25")
#' plotSkeleton(pe, sk, frame = 1, plane = "frontal")
#' }
plotSkeleton <- function(pe, skeleton, frame = 1,
                         plane = c("sagittal", "frontal", "transverse"),
                         show_labels = FALSE, show_confidence = FALSE,
                         point_size = 3, segment_color = "gray40",
                         title = NULL) {

  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(inherits(skeleton, "SkeletonModel"))
  plane <- match.arg(plane)

  frame_data <- .extract_frame(pe, frame)
  pos_x <- frame_data$x
  pos_y <- frame_data$y
  pos_z <- frame_data$z
  conf  <- frame_data$confidence

  # Build marker data frame
  marker_df <- .build_marker_df(pos_x, pos_y, pos_z, conf, plane)

  # Build bone segment data frame
  bone_df <- .build_bone_df(marker_df, skeleton)

  # Build the ggplot
  p <- .build_skeleton_plot(marker_df, bone_df,
                            show_labels = show_labels,
                            show_confidence = show_confidence,
                            point_size = point_size,
                            segment_color = segment_color)

  if (is.null(title)) {
    title <- sprintf("Skeleton (%s, frame %d)", plane, frame)
  }

  p <- p + ggplot2::ggtitle(title)
  p
}


#' Plot a sequence of skeleton frames
#'
#' Creates a multi-panel faceted plot showing the skeleton at several frames.
#'
#' @inheritParams plotSkeleton
#' @param frames Integer vector of frame indices to plot.
#' @param ncol Number of columns in the faceted layout (default 3).
#'
#' @return A ggplot object with facets.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotSkeleton()] for single-frame skeleton visualization,
#'   [plotSkeletonOverlay()] for overlaid frames on a single plot.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readOpenPose("frames/", model = "BODY_25")
#' sk <- define_skeleton("BODY_25")
#' plotSkeletonSequence(pe, sk, frames = c(1, 10, 20), ncol = 3)
#' }
plotSkeletonSequence <- function(pe, skeleton, frames,
                                 plane = c("sagittal", "frontal", "transverse"),
                                 ncol = 3, show_labels = FALSE,
                                 show_confidence = FALSE,
                                 point_size = 2, segment_color = "gray40",
                                 title = NULL) {

  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(inherits(skeleton, "SkeletonModel"))
  plane <- match.arg(plane)
  stopifnot(is.numeric(frames) && length(frames) >= 1)

  all_markers <- list()
  all_bones   <- list()

  for (f in frames) {
    frame_data <- .extract_frame(pe, f)
    mdf <- .build_marker_df(frame_data$x, frame_data$y, frame_data$z,
                            frame_data$confidence, plane)
    bdf <- .build_bone_df(mdf, skeleton)

    frame_label <- paste0("Frame ", f)
    mdf$frame <- frame_label
    bdf$frame <- frame_label

    all_markers[[length(all_markers) + 1]] <- mdf
    all_bones[[length(all_bones) + 1]]     <- bdf
  }

  marker_df <- do.call(rbind, all_markers)
  bone_df   <- do.call(rbind, all_bones)

  # Preserve frame ordering
  frame_levels <- paste0("Frame ", frames)
  marker_df$frame <- factor(marker_df$frame, levels = frame_levels)
  bone_df$frame   <- factor(bone_df$frame, levels = frame_levels)

  p <- .build_skeleton_plot(marker_df, bone_df,
                            show_labels = show_labels,
                            show_confidence = show_confidence,
                            point_size = point_size,
                            segment_color = segment_color)

  p <- p + ggplot2::facet_wrap(~ frame, ncol = ncol)

  if (is.null(title)) {
    title <- sprintf("Skeleton Sequence (%s)", plane)
  }
  p <- p + ggplot2::ggtitle(title)

  p
}


#' Plot overlaid skeleton frames
#'
#' Draws multiple frames on the same plot. Earlier frames are rendered with
#' lower opacity when `alpha_decay = TRUE`.
#'
#' @inheritParams plotSkeleton
#' @param frames Integer vector of frame indices to overlay.
#' @param alpha_decay Logical; if `TRUE`, earlier frames have lower
#'   opacity (linearly from 0.2 to 1.0).
#' @param base_alpha Minimum alpha for the earliest frame (default 0.2).
#'
#' @return A ggplot object.
#'
#' @references
#' Wickham H (2016). "ggplot2: Elegant Graphics for Data Analysis." Springer.
#'
#' @seealso [plotSkeleton()] for single-frame skeleton visualization,
#'   [plotSkeletonSequence()] for multi-frame faceted display.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readOpenPose("frames/", model = "BODY_25")
#' sk <- define_skeleton("BODY_25")
#' plotSkeletonOverlay(pe, sk, frames = c(1, 5, 10, 15, 20))
#' }
plotSkeletonOverlay <- function(pe, skeleton, frames,
                                plane = c("sagittal", "frontal", "transverse"),
                                alpha_decay = TRUE, base_alpha = 0.2,
                                show_labels = FALSE,
                                point_size = 3, segment_color = "gray40",
                                title = NULL) {

  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(inherits(skeleton, "SkeletonModel"))
  plane <- match.arg(plane)
  stopifnot(is.numeric(frames) && length(frames) >= 1)

  n_frames <- length(frames)

  # Calculate alpha values
  if (alpha_decay && n_frames > 1) {
    alphas <- seq(base_alpha, 1.0, length.out = n_frames)
  } else {
    alphas <- rep(1.0, n_frames)
  }

  # Start building the plot
  p <- ggplot2::ggplot() +
    ggplot2::theme_minimal() +
    ggplot2::coord_fixed()

  axis_labels <- .plane_axis_labels(plane)

  for (i in seq_along(frames)) {
    f <- frames[i]
    a <- alphas[i]

    frame_data <- .extract_frame(pe, f)
    mdf <- .build_marker_df(frame_data$x, frame_data$y, frame_data$z,
                            frame_data$confidence, plane)
    bdf <- .build_bone_df(mdf, skeleton)

    # Draw bone segments
    if (nrow(bdf) > 0) {
      p <- p + ggplot2::geom_segment(
        data = bdf,
        ggplot2::aes(x = .data$u_from, y = .data$v_from,
                     xend = .data$u_to, yend = .data$v_to),
        color = segment_color,
        linewidth = 0.8,
        alpha = a
      )
    }

    # Draw marker points (no confidence coloring in overlay)
    valid <- !is.na(mdf$u) & !is.na(mdf$v)
    if (any(valid)) {
      p <- p + ggplot2::geom_point(
        data = mdf[valid, , drop = FALSE],
        ggplot2::aes(x = .data$u, y = .data$v),
        size = point_size,
        alpha = a,
        color = "steelblue"
      )
    }

    # Labels for last frame only if requested
    if (show_labels && i == n_frames) {
      label_df <- mdf[valid, , drop = FALSE]
      if (nrow(label_df) > 0) {
        p <- p + ggplot2::geom_text(
          data = label_df,
          ggplot2::aes(x = .data$u, y = .data$v, label = .data$label),
          size = 2.5, nudge_y = 0.02 * diff(range(mdf$v, na.rm = TRUE)),
          alpha = a
        )
      }
    }
  }

  p <- p + ggplot2::labs(x = axis_labels$x, y = axis_labels$y)

  if (is.null(title)) {
    title <- sprintf("Skeleton Overlay (%s, %d frames)", plane, n_frames)
  }
  p <- p + ggplot2::ggtitle(title)

  p
}


#' Plot a skeleton frame in pseudo-3D
#'
#' Renders one frame of a skeleton in a perspective-like 3D projection using
#' a lightweight base graphics backend (no external 3D dependency required).
#'
#' @param pe A PhysioExperiment object with `position_x`, `position_y`,
#'   and `position_z` assays.
#' @param skeleton A `SkeletonModel` object.
#' @param frame Integer frame index.
#' @param azimuth View azimuth angle in degrees.
#' @param elevation View elevation angle in degrees.
#' @param distance Perspective distance (larger = weaker perspective).
#' @param show_labels Logical; if `TRUE`, draws keypoint labels.
#' @param point_col Point color.
#' @param segment_col Segment color.
#' @param point_cex Point size.
#' @param segment_lwd Segment line width.
#' @param main Plot title. If `NULL`, auto-generated.
#' @param draw Logical; if `TRUE`, draws to current graphics device.
#'
#' @return Invisibly returns a list with projected coordinates and view
#'   parameters.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [plotSkeleton()] for 2D skeleton visualization,
#'   [projectTo2D()] for manual coordinate projection.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' pe <- readOpenPose("frames/", model = "BODY_25")
#' sk <- define_skeleton("BODY_25")
#' plotSkeleton3D(pe, sk, frame = 10, azimuth = 35, elevation = 20)
#' }
plotSkeleton3D <- function(pe, skeleton, frame = 1,
                           azimuth = 35, elevation = 20, distance = 6,
                           show_labels = FALSE,
                           point_col = "steelblue", segment_col = "gray40",
                           point_cex = 1.1, segment_lwd = 1.5,
                           main = NULL, draw = TRUE) {

  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(inherits(skeleton, "SkeletonModel"))
  stopifnot(is.numeric(frame), length(frame) == 1, frame >= 1)
  stopifnot(is.numeric(azimuth), length(azimuth) == 1)
  stopifnot(is.numeric(elevation), length(elevation) == 1)
  stopifnot(is.numeric(distance), length(distance) == 1, distance > 0)
  stopifnot(is.logical(show_labels), length(show_labels) == 1)
  stopifnot(is.logical(draw), length(draw) == 1)

  frame_data <- .extract_frame(pe, as.integer(frame))

  coords <- data.frame(
    label = names(frame_data$x),
    x = as.numeric(frame_data$x),
    y = as.numeric(frame_data$y),
    z = as.numeric(frame_data$z),
    stringsAsFactors = FALSE
  )

  rot <- .rotation_matrix_3d(azimuth = azimuth, elevation = elevation)
  proj <- .project_3d_points(coords[, c("x", "y", "z"), drop = FALSE],
                             rot = rot, distance = distance)

  draw_df <- cbind(coords["label"], proj)

  if (draw) {
    valid <- is.finite(draw_df$u) & is.finite(draw_df$v)
    plot_df <- draw_df[valid, , drop = FALSE]

    if (nrow(plot_df) == 0) {
      stop("No finite points available for plotting.", call. = FALSE)
    }

    if (is.null(main)) {
      main <- sprintf("Skeleton 3D (frame %d)", as.integer(frame))
    }

    graphics::plot(
      plot_df$u, plot_df$v,
      type = "n",
      asp = 1,
      xlab = "Projected X",
      ylab = "Projected Y",
      main = main
    )

    # Draw segments
    bones <- get_bone_connections(skeleton)
    u <- stats::setNames(draw_df$u, draw_df$label)
    v <- stats::setNames(draw_df$v, draw_df$label)

    for (i in seq_len(nrow(bones))) {
      fl <- bones$from_label[i]
      tl <- bones$to_label[i]

      if (!(fl %in% names(u)) || !(tl %in% names(u))) {
        next
      }
      if (!is.finite(u[[fl]]) || !is.finite(v[[fl]]) ||
          !is.finite(u[[tl]]) || !is.finite(v[[tl]])) {
        next
      }

      graphics::segments(
        x0 = u[[fl]], y0 = v[[fl]],
        x1 = u[[tl]], y1 = v[[tl]],
        col = segment_col, lwd = segment_lwd
      )
    }

    graphics::points(plot_df$u, plot_df$v, pch = 16, cex = point_cex, col = point_col)

    if (show_labels) {
      graphics::text(plot_df$u, plot_df$v, labels = plot_df$label, pos = 3, cex = 0.7)
    }
  }

  invisible(list(
    data = draw_df,
    rotation = rot,
    azimuth = azimuth,
    elevation = elevation,
    distance = distance
  ))
}


# ---------------------------------------------------------------------------
# Internal helper functions
# ---------------------------------------------------------------------------

#' Extract position data for a single frame
#' @keywords internal
#' @noRd
.extract_frame <- function(pe, frame) {
  anames <- SummarizedExperiment::assayNames(pe)

  has_pos_x <- "position_x" %in% anames
  has_pos_y <- "position_y" %in% anames
  has_pos_z <- "position_z" %in% anames

  if (!has_pos_x || !has_pos_y || !has_pos_z) {
    stop("PhysioExperiment must contain 'position_x', 'position_y', ",
         "and 'position_z' assays for skeleton visualization.",
         call. = FALSE)
  }

  n_frames <- nrow(SummarizedExperiment::assay(pe, "position_x"))
  if (frame < 1 || frame > n_frames) {
    stop(sprintf("frame must be between 1 and %d, got %d", n_frames, frame),
         call. = FALSE)
  }

  x <- as.numeric(SummarizedExperiment::assay(pe, "position_x")[frame, ])
  y <- as.numeric(SummarizedExperiment::assay(pe, "position_y")[frame, ])
  z <- as.numeric(SummarizedExperiment::assay(pe, "position_z")[frame, ])
  names(x) <- colnames(SummarizedExperiment::assay(pe, "position_x"))
  names(y) <- colnames(SummarizedExperiment::assay(pe, "position_y"))
  names(z) <- colnames(SummarizedExperiment::assay(pe, "position_z"))

  # Optional confidence
  conf <- NULL
  if ("confidence" %in% anames) {
    conf <- as.numeric(SummarizedExperiment::assay(pe, "confidence")[frame, ])
    names(conf) <- colnames(SummarizedExperiment::assay(pe, "confidence"))
  }

  list(x = x, y = y, z = z, confidence = conf)
}


#' Build marker data frame with projected 2D coordinates
#' @keywords internal
#' @noRd
.build_marker_df <- function(pos_x, pos_y, pos_z, confidence, plane) {
  proj <- projectTo2D(pos_x, pos_y, pos_z, plane = plane)
  df <- data.frame(
    label = names(pos_x),
    u = proj$u,
    v = proj$v,
    stringsAsFactors = FALSE
  )
  if (!is.null(confidence)) {
    df$confidence <- confidence[names(pos_x)]
  } else {
    df$confidence <- NA_real_
  }
  df
}


#' Build bone segment data frame from marker positions and skeleton model
#' @keywords internal
#' @noRd
.build_bone_df <- function(marker_df, skeleton) {
  edges <- get_bone_connections(skeleton)
  marker_labels <- marker_df$label

  # Pre-index marker positions by label for fast lookup
  u_vals <- stats::setNames(marker_df$u, marker_df$label)
  v_vals <- stats::setNames(marker_df$v, marker_df$label)

  bone_rows <- list()
  for (i in seq_len(nrow(edges))) {
    fl <- edges$from_label[i]
    tl <- edges$to_label[i]

    if (!(fl %in% marker_labels) || !(tl %in% marker_labels)) next

    u_from <- u_vals[[fl]]
    v_from <- v_vals[[fl]]
    u_to   <- u_vals[[tl]]
    v_to   <- v_vals[[tl]]

    # Skip if any endpoint is NA
    if (is.na(u_from) || is.na(v_from) || is.na(u_to) || is.na(v_to)) next

    bone_rows[[length(bone_rows) + 1]] <- data.frame(
      bone_name = edges$bone_name[i],
      u_from = u_from, v_from = v_from,
      u_to = u_to, v_to = v_to,
      stringsAsFactors = FALSE
    )
  }

  if (length(bone_rows) == 0) {
    return(data.frame(
      bone_name = character(0),
      u_from = numeric(0), v_from = numeric(0),
      u_to = numeric(0), v_to = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  do.call(rbind, bone_rows)
}


#' Build skeleton ggplot from marker and bone data frames
#' @keywords internal
#' @noRd
.build_skeleton_plot <- function(marker_df, bone_df,
                                 show_labels = FALSE,
                                 show_confidence = FALSE,
                                 point_size = 3,
                                 segment_color = "gray40") {

  p <- ggplot2::ggplot()

  # Draw bone segments
  if (nrow(bone_df) > 0) {
    p <- p + ggplot2::geom_segment(
      data = bone_df,
      ggplot2::aes(x = .data$u_from, y = .data$v_from,
                   xend = .data$u_to, yend = .data$v_to),
      color = segment_color,
      linewidth = 0.8
    )
  }

  # Draw marker points
  valid <- !is.na(marker_df$u) & !is.na(marker_df$v)
  valid_markers <- marker_df[valid, , drop = FALSE]

  if (nrow(valid_markers) > 0) {
    if (show_confidence && any(!is.na(valid_markers$confidence))) {
      p <- p + ggplot2::geom_point(
        data = valid_markers,
        ggplot2::aes(x = .data$u, y = .data$v, color = .data$confidence),
        size = point_size
      ) +
        ggplot2::scale_color_viridis_c(
          name = "Confidence",
          limits = c(0, 1),
          na.value = "gray60"
        )
    } else {
      p <- p + ggplot2::geom_point(
        data = valid_markers,
        ggplot2::aes(x = .data$u, y = .data$v),
        size = point_size,
        color = "steelblue"
      )
    }
  }

  # Add labels
  if (show_labels && nrow(valid_markers) > 0) {
    nudge <- if (nrow(valid_markers) > 1) {
      0.02 * diff(range(valid_markers$v, na.rm = TRUE))
    } else {
      0.5
    }
    p <- p + ggplot2::geom_text(
      data = valid_markers,
      ggplot2::aes(x = .data$u, y = .data$v, label = .data$label),
      size = 2.5,
      nudge_y = nudge
    )
  }

  # Determine axis labels from the data (use a default plane for standalone usage)
  # The axis labels will be set by the caller if needed
  p <- p +
    ggplot2::theme_minimal() +
    ggplot2::coord_fixed() +
    ggplot2::labs(x = "u", y = "v")

  p
}


#' Get axis labels for a projection plane
#' @keywords internal
#' @noRd
.plane_axis_labels <- function(plane) {
  switch(plane,
    sagittal    = list(x = "Y (anterior-posterior)", y = "Z (vertical)"),
    frontal     = list(x = "X (medial-lateral)",     y = "Z (vertical)"),
    transverse  = list(x = "X (medial-lateral)",     y = "Y (anterior-posterior)")
  )
}


#' Build 3D rotation matrix from azimuth/elevation
#' @keywords internal
#' @noRd
.rotation_matrix_3d <- function(azimuth, elevation) {
  az <- azimuth * pi / 180
  el <- elevation * pi / 180

  # Rotation around Z (azimuth)
  rz <- matrix(c(
    cos(az), -sin(az), 0,
    sin(az),  cos(az), 0,
    0,        0,       1
  ), nrow = 3, byrow = TRUE)

  # Rotation around X (elevation)
  rx <- matrix(c(
    1, 0,        0,
    0, cos(el), -sin(el),
    0, sin(el),  cos(el)
  ), nrow = 3, byrow = TRUE)

  rx %*% rz
}


#' Project 3D points to 2D with simple perspective
#' @keywords internal
#' @noRd
.project_3d_points <- function(xyz, rot, distance = 6) {
  xyz <- as.matrix(xyz)
  if (ncol(xyz) != 3) {
    stop("xyz must have exactly 3 columns.", call. = FALSE)
  }

  transformed <- xyz %*% t(rot)
  depth <- transformed[, 3]
  scale <- distance / (distance + depth)

  data.frame(
    u = transformed[, 1] * scale,
    v = transformed[, 2] * scale,
    depth = depth,
    stringsAsFactors = FALSE
  )
}
