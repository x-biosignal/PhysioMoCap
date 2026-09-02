# Center of Mass and Body Segment Parameter Calculations
# Computes whole-body and per-segment center of mass from marker positions
# using standard body segment inertial parameter (BSIP) tables.

#' Get body segment inertial parameters (BSIP)
#'
#' Returns a data.frame of body segment inertial parameters including
#' mass fractions and center of mass proximal fractions for standard
#' anthropometric models.
#'
#' @param model Character string specifying the anthropometric model.
#'   One of `"deLeva_male"`, `"deLeva_female"`, or `"winter"`.
#'   Default is `"deLeva_male"`.
#'
#' @return A `data.frame` with columns:
#'   \describe{
#'     \item{segment}{Character, name of the body segment.}
#'     \item{mass_fraction}{Numeric, fraction of total body mass
#'       (as percentage, 0-100).}
#'     \item{com_proximal_fraction}{Numeric, fraction of segment length
#'       from the proximal endpoint to the segment center of mass (0-1).}
#'     \item{proximal_marker}{Character, default proximal marker name.}
#'     \item{distal_marker}{Character, default distal marker name.}
#'   }
#'
#' @details
#' The De Leva (1996) tables provide adjusted body segment parameters
#' based on Zatsiorsky's data, separately for males and females. The
#' Winter (2009) model provides a simplified set of parameters commonly
#' used in gait analysis.
#'
#' Segments include: head, trunk, upper_arm_r, upper_arm_l, forearm_r,
#' forearm_l, hand_r, hand_l, thigh_r, thigh_l, shank_r, shank_l,
#' foot_r, foot_l (14 segments total).
#'
#' @references
#' De Leva, P. (1996). Adjustments to Zatsiorsky-Seluyanov's segment
#' inertia parameters. *Journal of Biomechanics*, 29(9), 1223-1230.
#'
#' Winter, D.A. (2009). *Biomechanics and Motor Control of Human
#' Movement* (4th ed.). Wiley.
#'
#' @seealso [calculateCOM()] for whole-body center of mass computation,
#'   [calculateSegmentCOM()] for individual segment center of mass,
#'   [estimateSegmentInertia()] for segment inertial properties.
#'
#' @export
#' @examples
#' bsip <- segmentParameters("deLeva_male")
#' head(bsip)
#' sum(bsip$mass_fraction)  # approximately 100
segmentParameters <- function(model = "deLeva_male") {
  model <- match.arg(model, choices = c("deLeva_male", "deLeva_female", "winter"))

  switch(model,
    deLeva_male   = .bsip_deLeva_male(),
    deLeva_female = .bsip_deLeva_female(),
    winter        = .bsip_winter()
  )
}


#' Calculate whole-body center of mass from marker positions
#'
#' Computes the whole-body center of mass (COM) at each time frame from
#' 3D (or 2D) marker position data and body segment inertial parameters.
#'
#' @param pe A `PhysioExperiment` object containing `position_x`,
#'   `position_y`, and optionally `position_z` assays.
#' @param body_mass Numeric scalar, body mass in kilograms. Must be
#'   positive.
#' @param skeleton Optional `SkeletonModel` object used for automatic
#'   marker mapping. If provided and `marker_map` is `NULL`, a default
#'   mapping is generated from the skeleton model.
#' @param bsip Optional data.frame of body segment parameters (as
#'   returned by [segmentParameters()]). If `NULL` (default), uses
#'   `segmentParameters("deLeva_male")`.
#' @param marker_map Optional named list mapping each segment to its
#'   proximal and distal marker names. Each element should be a character
#'   vector of length 2: `c(proximal_marker, distal_marker)`. Segment
#'   names must match those in the `bsip` table. Example:
#'   `list(thigh_r = c("RHip", "RKnee"), thigh_l = c("LHip", "LKnee"))`.
#'
#' @return A `PhysioExperiment` object with additional assays `com_x`,
#'   `com_y`, and (if 3D) `com_z`. Each assay is a single-column matrix
#'   with column name `"COM"` and the same number of rows as the input.
#'
#' @details
#' The algorithm proceeds as follows:
#' \enumerate{
#'   \item For each body segment, compute the segment COM position as:
#'     \deqn{COM_{seg} = P_{prox} + f \times (P_{dist} - P_{prox})}
#'     where \eqn{f} is the COM proximal fraction from the BSIP table.
#'   \item Compute the whole-body COM as the mass-weighted average of
#'     all segment COMs:
#'     \deqn{COM_{body} = \frac{\sum_i m_i \times COM_i}{M}}
#'     where \eqn{m_i = M \times f_i} is the segment mass and \eqn{M}
#'     is the total body mass.
#' }
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' Zatsiorsky VM (2002). "Kinetics of Human Motion." Human Kinetics.
#'
#' @seealso [segmentParameters()] for body segment inertial parameters,
#'   [calculateSegmentCOM()] for individual segment center of mass,
#'   [symmetryIndex()] for bilateral symmetry assessment.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readTRC("markers.trc")
#' result <- calculateCOM(pe, body_mass = 75)
#' com_x <- SummarizedExperiment::assay(result, "com_x")
#' }
calculateCOM <- function(pe, body_mass, skeleton = NULL, bsip = NULL,
                         marker_map = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  if (!is.numeric(body_mass) || length(body_mass) != 1 || body_mass <= 0) {
    stop("'body_mass' must be a positive numeric scalar.", call. = FALSE)
  }

  # Get assays

anames <- SummarizedExperiment::assayNames(pe)
  if (!("position_x" %in% anames) || !("position_y" %in% anames)) {
    stop("PhysioExperiment must contain 'position_x' and 'position_y' assays.",
         call. = FALSE)
  }
  has_z <- "position_z" %in% anames

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- if (has_z) SummarizedExperiment::assay(pe, "position_z") else NULL

  n_frames <- nrow(pos_x)

  # Get BSIP parameters
  if (is.null(bsip)) {
    bsip <- segmentParameters("deLeva_male")
  }

  # Resolve marker mapping
  if (is.null(marker_map)) {
    if (!is.null(skeleton)) {
      marker_map <- .auto_marker_map(skeleton, bsip)
    } else {
      # Use default markers from BSIP table
      marker_map <- stats::setNames(
        lapply(seq_len(nrow(bsip)), function(i) {
          c(bsip$proximal_marker[i], bsip$distal_marker[i])
        }),
        bsip$segment
      )
    }
  }

  # Validate that all required markers exist
  col_names <- colnames(pos_x)
  all_markers <- unique(unlist(marker_map))
  missing <- setdiff(all_markers, col_names)
  if (length(missing) > 0) {
    stop("Missing markers in position data: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  # Calculate per-segment COM and mass-weighted sum
  com_x <- rep(0, n_frames)
  com_y <- rep(0, n_frames)
  com_z <- if (has_z) rep(0, n_frames) else NULL

  total_mass_fraction <- 0

  for (seg_name in names(marker_map)) {
    seg_row <- which(bsip$segment == seg_name)
    if (length(seg_row) == 0) {
      warning("Segment '", seg_name, "' not found in BSIP table, skipping.",
              call. = FALSE)
      next
    }

    markers <- marker_map[[seg_name]]
    prox_marker <- markers[1]
    dist_marker <- markers[2]

    mass_frac <- bsip$mass_fraction[seg_row] / 100  # convert from % to fraction
    com_frac <- bsip$com_proximal_fraction[seg_row]

    # Segment COM = proximal + fraction * (distal - proximal)
    seg_com_x <- pos_x[, prox_marker] +
      com_frac * (pos_x[, dist_marker] - pos_x[, prox_marker])
    seg_com_y <- pos_y[, prox_marker] +
      com_frac * (pos_y[, dist_marker] - pos_y[, prox_marker])

    com_x <- com_x + mass_frac * seg_com_x
    com_y <- com_y + mass_frac * seg_com_y

    if (has_z) {
      seg_com_z <- pos_z[, prox_marker] +
        com_frac * (pos_z[, dist_marker] - pos_z[, prox_marker])
      com_z <- com_z + mass_frac * seg_com_z
    }

    total_mass_fraction <- total_mass_fraction + mass_frac
  }

  # Normalize by total mass fraction used (should be ~1.0 if all segments)
  if (total_mass_fraction > 0) {
    com_x <- com_x / total_mass_fraction
    com_y <- com_y / total_mass_fraction
    if (has_z) com_z <- com_z / total_mass_fraction
  }

  # Package results as single-column matrices
  com_x_mat <- matrix(com_x, ncol = 1, dimnames = list(NULL, "COM"))
  com_y_mat <- matrix(com_y, ncol = 1, dimnames = list(NULL, "COM"))

  com_coldata <- S4Vectors::DataFrame(
    label = "COM",
    type = "com"
  )

  new_assays <- list(com_x = com_x_mat, com_y = com_y_mat)
  if (has_z) {
    com_z_mat <- matrix(com_z, ncol = 1, dimnames = list(NULL, "COM"))
    new_assays$com_z <- com_z_mat
  }

  # Build new PE with COM assays
  pe_com <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(new_assays),
    colData = com_coldata,
    samplingRate = PhysioCore::samplingRate(pe)
  )

  pe_com
}


#' Calculate per-segment centers of mass
#'
#' Lower-level function that computes the center of mass for individual
#' body segments from marker position data.
#'
#' @param pe A `PhysioExperiment` object with `position_x`, `position_y`,
#'   and optionally `position_z` assays.
#' @param proximal_markers Character vector of proximal marker names,
#'   one per segment.
#' @param distal_markers Character vector of distal marker names,
#'   one per segment (same length as `proximal_markers`).
#' @param com_fractions Numeric vector of COM proximal fractions (0-1),
#'   one per segment (same length as `proximal_markers`).
#'
#' @return A named list of matrices, one per segment. Each matrix has
#'   dimensions (n_frames x 2) for 2D data or (n_frames x 3) for 3D
#'   data, with columns named `"x"`, `"y"`, and (optionally) `"z"`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [calculateCOM()] for whole-body center of mass,
#'   [segmentParameters()] for body segment inertial parameters.
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readTRC("markers.trc")
#' seg_coms <- calculateSegmentCOM(
#'   pe,
#'   proximal_markers = c("RHip", "LHip"),
#'   distal_markers   = c("RKnee", "LKnee"),
#'   com_fractions    = c(0.4095, 0.4095)
#' )
#' }
calculateSegmentCOM <- function(pe, proximal_markers, distal_markers,
                                com_fractions) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(is.character(proximal_markers))
  stopifnot(is.character(distal_markers))
  stopifnot(is.numeric(com_fractions))
  stopifnot(length(proximal_markers) == length(distal_markers))
  stopifnot(length(proximal_markers) == length(com_fractions))

  anames <- SummarizedExperiment::assayNames(pe)
  if (!("position_x" %in% anames) || !("position_y" %in% anames)) {
    stop("PhysioExperiment must contain 'position_x' and 'position_y' assays.",
         call. = FALSE)
  }
  has_z <- "position_z" %in% anames

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- if (has_z) SummarizedExperiment::assay(pe, "position_z") else NULL

  col_names <- colnames(pos_x)
  all_markers <- unique(c(proximal_markers, distal_markers))
  missing <- setdiff(all_markers, col_names)
  if (length(missing) > 0) {
    stop("Missing markers in position data: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  n_frames <- nrow(pos_x)
  n_segments <- length(proximal_markers)

  result <- vector("list", n_segments)
  names(result) <- paste0(proximal_markers, "_to_", distal_markers)

  for (i in seq_len(n_segments)) {
    prox <- proximal_markers[i]
    dist <- distal_markers[i]
    frac <- com_fractions[i]

    seg_x <- pos_x[, prox] + frac * (pos_x[, dist] - pos_x[, prox])
    seg_y <- pos_y[, prox] + frac * (pos_y[, dist] - pos_y[, prox])

    if (has_z) {
      seg_z <- pos_z[, prox] + frac * (pos_z[, dist] - pos_z[, prox])
      result[[i]] <- matrix(
        c(seg_x, seg_y, seg_z),
        nrow = n_frames, ncol = 3,
        dimnames = list(NULL, c("x", "y", "z"))
      )
    } else {
      result[[i]] <- matrix(
        c(seg_x, seg_y),
        nrow = n_frames, ncol = 2,
        dimnames = list(NULL, c("x", "y"))
      )
    }
  }

  result
}


#' Compute bilateral symmetry index
#'
#' Calculates a symmetry index between left and right side measurements
#' using standard methods from the biomechanics literature.
#'
#' @param left Numeric vector or matrix of left-side values.
#' @param right Numeric vector or matrix of right-side values (same
#'   dimensions as `left`).
#' @param method Character string specifying the symmetry index method.
#'   `"robinson"` (default): Robinson (1987) symmetry index
#'   \eqn{SI = |L - R| / (0.5 \times (L + R)) \times 100}.
#'   `"ratio"`: simple ratio \eqn{L / R}.
#'
#' @return For vectors, a numeric vector of symmetry indices. For
#'   matrices, row-wise symmetry indices (a numeric vector of length
#'   equal to `nrow(left)`).
#'
#' @details
#' The Robinson (1987) symmetry index returns 0 for perfect symmetry
#' and larger values for greater asymmetry. It is expressed as a
#' percentage. The ratio method returns 1.0 for perfect symmetry.
#'
#' @references
#' Robinson, R.O., Herzog, W., & Nigg, B.M. (1987). Use of force
#' platform variables to quantify the effects of chiropractic
#' manipulation on gait symmetry. *Journal of Manipulative and
#' Physiological Therapeutics*, 10(4), 172-176.
#'
#' @seealso [calculateStepSymmetry()] for gait-specific symmetry metrics,
#'   [plotSymmetry()] for symmetry visualization,
#'   [calculateGaitParameters()] for comprehensive gait analysis.
#'
#' @export
#' @examples
#' # Perfect symmetry
#' symmetryIndex(10, 10)   # returns 0
#'
#' # Known asymmetry
#' symmetryIndex(10, 8)    # returns ~22.2%
#'
#' # Ratio method
#' symmetryIndex(10, 8, method = "ratio")  # returns 1.25
symmetryIndex <- function(left, right, method = "robinson") {
  method <- match.arg(method, choices = c("robinson", "ratio"))

  if (is.matrix(left) && is.matrix(right)) {
    stopifnot(nrow(left) == nrow(right))
    stopifnot(ncol(left) == ncol(right))
    # Row-wise computation
    left_vals <- rowMeans(left)
    right_vals <- rowMeans(right)
  } else {
    left_vals <- as.numeric(left)
    right_vals <- as.numeric(right)
    stopifnot(length(left_vals) == length(right_vals))
  }

  switch(method,
    robinson = {
      mean_val <- 0.5 * (left_vals + right_vals)
      si <- abs(left_vals - right_vals) / mean_val * 100
      si[mean_val == 0] <- 0  # avoid division by zero when both are 0
      si
    },
    ratio = {
      si <- left_vals / right_vals
      si[right_vals == 0] <- NA_real_
      si
    }
  )
}


# ---------------------------------------------------------------------------
# Internal BSIP table builders
# ---------------------------------------------------------------------------

#' De Leva (1996) male body segment parameters
#' @keywords internal
#' @noRd
.bsip_deLeva_male <- function() {
  data.frame(
    segment = c(
      "head", "trunk",
      "upper_arm_r", "upper_arm_l",
      "forearm_r", "forearm_l",
      "hand_r", "hand_l",
      "thigh_r", "thigh_l",
      "shank_r", "shank_l",
      "foot_r", "foot_l"
    ),
    mass_fraction = c(
      6.94, 43.46,
      2.71, 2.71,
      1.62, 1.62,
      0.61, 0.61,
      14.16, 14.16,
      4.33, 4.33,
      1.37, 1.37
    ),
    com_proximal_fraction = c(
      0.5002, 0.4486,
      0.5772, 0.5772,
      0.4574, 0.4574,
      0.7900, 0.7900,
      0.4095, 0.4095,
      0.4459, 0.4459,
      0.4415, 0.4415
    ),
    proximal_marker = c(
      "Neck", "Neck",
      "RShoulder", "LShoulder",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RHip", "LHip",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle"
    ),
    distal_marker = c(
      "Nose", "MidHip",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RWrist", "LWrist",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle",
      "RHeel", "LHeel"
    ),
    stringsAsFactors = FALSE
  )
}


#' De Leva (1996) female body segment parameters
#' @keywords internal
#' @noRd
.bsip_deLeva_female <- function() {
  data.frame(
    segment = c(
      "head", "trunk",
      "upper_arm_r", "upper_arm_l",
      "forearm_r", "forearm_l",
      "hand_r", "hand_l",
      "thigh_r", "thigh_l",
      "shank_r", "shank_l",
      "foot_r", "foot_l"
    ),
    mass_fraction = c(
      6.68, 42.57,
      2.55, 2.55,
      1.38, 1.38,
      0.56, 0.56,
      14.78, 14.78,
      4.81, 4.81,
      1.29, 1.29
    ),
    com_proximal_fraction = c(
      0.4841, 0.4964,
      0.5754, 0.5754,
      0.4559, 0.4559,
      0.7474, 0.7474,
      0.3612, 0.3612,
      0.4416, 0.4416,
      0.4014, 0.4014
    ),
    proximal_marker = c(
      "Neck", "Neck",
      "RShoulder", "LShoulder",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RHip", "LHip",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle"
    ),
    distal_marker = c(
      "Nose", "MidHip",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RWrist", "LWrist",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle",
      "RHeel", "LHeel"
    ),
    stringsAsFactors = FALSE
  )
}


#' Winter (2009) body segment parameters
#' @keywords internal
#' @noRd
.bsip_winter <- function() {
  data.frame(
    segment = c(
      "head", "trunk",
      "upper_arm_r", "upper_arm_l",
      "forearm_r", "forearm_l",
      "hand_r", "hand_l",
      "thigh_r", "thigh_l",
      "shank_r", "shank_l",
      "foot_r", "foot_l"
    ),
    mass_fraction = c(
      8.10, 49.70,
      2.80, 2.80,
      1.60, 1.60,
      0.60, 0.60,
      10.00, 10.00,
      4.65, 4.65,
      1.45, 1.45
    ),
    com_proximal_fraction = c(
      0.5000, 0.3960,
      0.4360, 0.4360,
      0.4300, 0.4300,
      0.5060, 0.5060,
      0.4330, 0.4330,
      0.4330, 0.4330,
      0.5000, 0.5000
    ),
    proximal_marker = c(
      "Neck", "Neck",
      "RShoulder", "LShoulder",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RHip", "LHip",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle"
    ),
    distal_marker = c(
      "Nose", "MidHip",
      "RElbow", "LElbow",
      "RWrist", "LWrist",
      "RWrist", "LWrist",
      "RKnee", "LKnee",
      "RAnkle", "LAnkle",
      "RHeel", "LHeel"
    ),
    stringsAsFactors = FALSE
  )
}


#' Auto-generate marker mapping from a SkeletonModel
#' @keywords internal
#' @noRd
.auto_marker_map <- function(skeleton, bsip) {
  stopifnot(inherits(skeleton, "SkeletonModel"))

  kp_labels <- as.character(skeleton$keypoints$label)

  marker_map <- list()
  for (i in seq_len(nrow(bsip))) {
    prox <- bsip$proximal_marker[i]
    dist <- bsip$distal_marker[i]

    if (prox %in% kp_labels && dist %in% kp_labels) {
      marker_map[[bsip$segment[i]]] <- c(prox, dist)
    }
  }

  if (length(marker_map) == 0) {
    stop("No matching markers found between skeleton and BSIP table. ",
         "Please provide a 'marker_map' manually.", call. = FALSE)
  }

  marker_map
}
