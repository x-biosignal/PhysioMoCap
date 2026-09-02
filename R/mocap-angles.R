# Joint Angle Calculation
# Computes joint angles from 3D marker/keypoint positions using various
# conventions, with quaternion and Euler angle conversion utilities.

#' Calculate joint angles from marker positions
#'
#' Computes joint angles from 3D (or 2D) position data stored in a
#' PhysioExperiment object. Each joint is defined by three points:
#' proximal, joint (vertex), and distal. The angle at the vertex is
#' computed using the specified convention.
#'
#' @param pe A `PhysioExperiment` object with position assays
#'   (`position_x`, `position_y`, and optionally `position_z`).
#' @param joints A named list of joint definitions. For `"3point"`, each element
#'   is a list with components `proximal`, `joint`, and `distal` (marker column
#'   names). For `"groodsuntay"` / `"ISB"`, each element is a list with
#'   `proximal` and `distal` *segment* specs, each itself a list of
#'   `proximal`/`distal`/`lateral` marker names (see
#'   [jointCoordinateSystem()]).
#' @param convention Angle convention: `"3point"` (unsigned angle at the vertex,
#'   the default) or `"groodsuntay"` / `"ISB"` (signed 3-DOF flexion, ab/adduction
#'   and internal/external rotation from anatomical segment frames).
#' @param degrees Logical. If `TRUE` (default), return angles in degrees.
#'   If `FALSE`, return angles in radians.
#' @param signed Logical, `"3point"` only. If `FALSE` (default) the vertex angle
#'   is the unsigned \eqn{[0, 180]} included angle. If `TRUE` the angle carries
#'   the sign of the rotation from the proximal to the distal vector about
#'   `plane_normal`, which separates flexion from hyperextension (see Details).
#' @param plane_normal The axis the signed angle is measured about, used only
#'   when `signed = TRUE`. Either `NULL` (the default: the global z axis for 2D
#'   data, or a best-fit plane normal derived from the data for 3D data), a
#'   length-3 numeric vector, an `n_frames x 3` matrix of per-frame normals, or
#'   a named list giving any of those per joint.
#'
#' @return A `PhysioExperiment` with a `"joint_angles"` assay. For `"3point"`
#'   this is `n_frames x n_joints` (one angle per joint: unsigned in
#'   \eqn{[0, 180]}, or signed in \eqn{(-180, 180]} when `signed = TRUE`). For
#'   `"groodsuntay"` / `"ISB"` it is `n_frames x (3 * n_joints)`: three columns
#'   per joint (`<joint>_flexion`, `<joint>_abduction`, `<joint>_rotation`) with
#'   `colData` carrying the `joint` and `axis` labels.
#'
#' @details
#' For the `"3point"` convention, the angle is computed at the vertex
#' (joint point) between the proximal-to-joint and distal-to-joint
#' direction vectors:
#'
#' \deqn{\theta = \arccos\left(\frac{v_1 \cdot v_2}{|v_1| |v_2|}\right)}
#'
#' where \eqn{v_1 = \text{proximal} - \text{joint}} and
#' \eqn{v_2 = \text{distal} - \text{joint}}.
#'
#' The result is clamped to \eqn{[0, \pi]} (or \eqn{[0, 180]} in
#' degrees). If any of the three points contain `NA` for a given frame,
#' the angle for that frame is `NA`.
#'
#' # Signed vertex angles
#'
#' The unsigned vertex angle cannot tell flexion from hyperextension: a knee
#' flexed 10 degrees and a knee hyperextended 10 degrees both give an included
#' angle of 170 degrees, because \eqn{\arccos} discards which side of the
#' proximal segment the distal segment lies on. With `signed = TRUE` the angle
#' is instead
#'
#' \deqn{\theta = \mathrm{atan2}\left((v_1' \times v_2') \cdot \hat{n},\;
#'   v_1' \cdot v_2'\right)}
#'
#' where \eqn{\hat{n}} is the unit `plane_normal` and \eqn{v_i'} is \eqn{v_i}
#' with its \eqn{\hat{n}} component removed. The magnitude is the same included
#' angle as before whenever the three points lie in the plane; the sign is
#' positive when the rotation from \eqn{v_1} to \eqn{v_2} follows the right-hand
#' rule about \eqn{\hat{n}}, and flips when the distal segment crosses to the
#' other side of the proximal segment. Choose (or negate) `plane_normal` so that
#' this direction is flexion, giving the clinical flexion(+) / extension(-)
#' convention; the corresponding deviation from the straight (anatomically
#' neutral) position is `180 - abs(theta)`.
#'
#' Because the range is \eqn{(-180, 180]}, the signed angle wraps at exactly the
#' straight configuration - the pose whose two sides the sign is there to tell
#' apart. A joint that moves through full extension therefore steps from `+180`
#' to `-180`, and differentiating that series directly gives a spurious spike.
#' Work with `180 - abs(theta)` (which is continuous through the neutral pose)
#' or unwrap the series before differentiating.
#'
#' For 2D data (no `position_z` assay) the default normal is the global z axis,
#' so a positive angle means the distal vector is counter-clockwise from the
#' proximal vector in the x-y plane. For 3D data with `plane_normal = NULL` the
#' normal is the least-variance direction of the two joint vectors over all
#' frames (a best-fit plane), which is only defined up to a global flip; the
#' function warns in that case because the flexion(+) direction is then a
#' property of the data rather than a clinical convention. Because \eqn{v_i} is
#' projected onto the plane, out-of-plane motion makes the signed magnitude
#' smaller than the unsigned 3D angle; the two agree exactly for planar motion.
#'
#' For `"groodsuntay"` / `"ISB"`, a proximal and distal anatomical frame are
#' built for each joint (via [jointCoordinateSystem()]) and the three signed
#' angles are extracted with [groodSuntayAngles()]. This is a *sequence-
#' dependent* Grood-Suntay floating-axis (Z-X-Y Cardan) decomposition: flexion
#' (about the proximal medio-lateral axis) is extracted first and internal/
#' external rotation (about the distal long axis) last.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#' description of three-dimensional motions: application to the knee."
#' Journal of Biomechanical Engineering, 105(2), 136-144.
#'
#' @seealso [vectorAngle()], [quaternionToEuler()], [eulerToQuaternion()]
#'
#' @export
#' @examples
#' \dontrun{
#' pe <- readTRC("markers.trc")
#' joints <- list(
#'   right_elbow = list(
#'     proximal = "RShoulder",
#'     joint    = "RElbow",
#'     distal   = "RWrist"
#'   ),
#'   right_knee = list(
#'     proximal = "RHip",
#'     joint    = "RKnee",
#'     distal   = "RAnkle"
#'   )
#' )
#' pe_angles <- calculateJointAngles(pe, joints)
#' SummarizedExperiment::assay(pe_angles, "joint_angles")
#'
#' # Signed sagittal angles: flexion and hyperextension get opposite signs
#' pe_signed <- calculateJointAngles(pe, joints, signed = TRUE,
#'                                   plane_normal = c(0, 0, 1))
#' }
calculateJointAngles <- function(pe, joints,
                                  convention = c("3point", "ISB",
                                                 "groodsuntay"),
                                  degrees = TRUE,
                                  signed = FALSE,
                                  plane_normal = NULL) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  convention <- match.arg(convention)
  stopifnot(is.logical(degrees) && length(degrees) == 1)
  if (!is.logical(signed) || length(signed) != 1 || is.na(signed)) {
    stop("'signed' must be a single TRUE or FALSE.", call. = FALSE)
  }
  if (!signed && !is.null(plane_normal)) {
    stop("'plane_normal' is only used when 'signed = TRUE'.", call. = FALSE)
  }

  stopifnot(is.list(joints) && length(joints) > 0)
  if (is.null(names(joints)) || any(names(joints) == "")) {
    stop("'joints' must be a fully named list.", call. = FALSE)
  }
  if (anyDuplicated(names(joints))) {
    stop("'joints' must have unique names.", call. = FALSE)
  }

  # Grood-Suntay / ISB: signed 3-DOF angles from anatomical segment frames.
  if (convention %in% c("ISB", "groodsuntay")) {
    if (signed) {
      stop(sprintf(paste0("convention = '%s' already returns signed angles; ",
                          "'signed = TRUE' applies to convention = '3point'."),
                   convention), call. = FALSE)
    }
    return(.jointAnglesGroodSuntay(pe, joints, degrees))
  }

  # Validate each joint definition

  for (nm in names(joints)) {
    j <- joints[[nm]]
    if (!is.list(j) || !all(c("proximal", "joint", "distal") %in% names(j))) {
      stop(sprintf("Joint '%s' must be a list with 'proximal', 'joint', and 'distal' components.",
                    nm), call. = FALSE)
    }
  }

  # Extract position assays
  anames <- SummarizedExperiment::assayNames(pe)
  has_x <- "position_x" %in% anames
  has_y <- "position_y" %in% anames
  has_z <- "position_z" %in% anames

  if (!has_x || !has_y) {
    stop("PhysioExperiment must contain 'position_x' and 'position_y' assays.",
         call. = FALSE)
  }

  pos_x <- SummarizedExperiment::assay(pe, "position_x")
  pos_y <- SummarizedExperiment::assay(pe, "position_y")
  pos_z <- if (has_z) SummarizedExperiment::assay(pe, "position_z") else NULL

  n_frames <- nrow(pos_x)
  n_joints <- length(joints)
  joint_names <- names(joints)

  angle_mat <- matrix(NA_real_, nrow = n_frames, ncol = n_joints)
  colnames(angle_mat) <- joint_names
  normals <- list()

  for (i in seq_len(n_joints)) {
    j <- joints[[i]]

    # Extract coordinate vectors for each landmark
    px <- pos_x[, j$proximal, drop = TRUE]
    py <- pos_y[, j$proximal, drop = TRUE]
    jx <- pos_x[, j$joint, drop = TRUE]
    jy <- pos_y[, j$joint, drop = TRUE]
    dx <- pos_x[, j$distal, drop = TRUE]
    dy <- pos_y[, j$distal, drop = TRUE]

    if (!is.null(pos_z)) {
      pz <- pos_z[, j$proximal, drop = TRUE]
      jz <- pos_z[, j$joint, drop = TRUE]
      dz <- pos_z[, j$distal, drop = TRUE]

      # Build direction vectors (n_frames x 3 matrices)
      v1 <- cbind(px - jx, py - jy, pz - jz)
      v2 <- cbind(dx - jx, dy - jy, dz - jz)
    } else {
      # 2D case: use z = 0
      v1 <- cbind(px - jx, py - jy, rep(0, n_frames))
      v2 <- cbind(dx - jx, dy - jy, rep(0, n_frames))
    }

    if (signed) {
      nrm <- .resolve_plane_normal(plane_normal, joint_names[i], v1, v2,
                                   has_z = !is.null(pos_z))
      normals[[joint_names[i]]] <- nrm
      angle_mat[, i] <- .signed_angle(v1, v2, nrm, degrees = degrees)
    } else {
      angle_mat[, i] <- vectorAngle(v1, v2, degrees = degrees)
    }
  }

  # Build a new PhysioExperiment with the joint_angles assay
  pe_out <- PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(joint_angles = angle_mat),
    colData = S4Vectors::DataFrame(
      label = joint_names,
      type = rep("joint_angle", n_joints),
      unit = rep(if (degrees) "deg" else "rad", n_joints)
    ),
    samplingRate = PhysioCore::samplingRate(pe)
  )

  # Record the sign convention so a downstream consumer can tell which
  # direction is positive. Only attached for signed = TRUE, so the default
  # unsigned output is unchanged.
  if (signed) {
    S4Vectors::metadata(pe_out)$angle_convention <- list(
      convention = "3point", signed = TRUE,
      plane_normal = lapply(normals, .collapse_constant_rows)
    )
  }

  pe_out
}


#' Signed Grood-Suntay / ISB joint angles from segment frames
#'
#' Computes the three signed clinical joint angles - flexion/extension,
#' ab/adduction and internal/external rotation - from a proximal and a distal
#' anatomical segment frame, following the Grood-Suntay joint coordinate system
#' (the basis of the ISB recommendations). The flexion axis is the proximal
#' medio-lateral (Z) axis, the rotation axis is the distal long (Y) axis, and
#' the ab/adduction axis is the floating axis perpendicular to both. This is
#' equivalent to a Z-X-Y Cardan decomposition of the relative rotation
#' \eqn{R = R_p^\top R_d}; because it is sequence-dependent, the flexion angle is
#' extracted first and the rotation last.
#'
#' @param proximal,distal \code{n x 3 x 3} arrays of per-frame segment axes
#'   (columns X = antero-posterior, Y = long, Z = medio-lateral), as returned by
#'   \code{\link{jointCoordinateSystem}}.
#' @param degrees Logical; return degrees (default) or radians.
#' @return A numeric \code{n x 3} matrix with columns \code{flexion},
#'   \code{abduction} and \code{rotation}.
#' @references
#'   Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#'   description of three-dimensional motions: application to the knee."
#'   J Biomech Eng, 105(2), 136-144.
#' @seealso [jointCoordinateSystem()], [calculateJointAngles()]
#' @export
groodSuntayAngles <- function(proximal, distal, degrees = TRUE) {
  stopifnot(is.array(proximal), is.array(distal),
            length(dim(proximal)) == 3, length(dim(distal)) == 3,
            dim(proximal)[2] == 3, dim(proximal)[3] == 3,
            all(dim(proximal) == dim(distal)))
  # R[a, b] = (t(Rp) %*% Rd)[a, b] = sum_k Rp[, k, a] * Rd[, k, b], per frame.
  n <- dim(proximal)[1]
  axcol <- function(fr, a) matrix(fr[, , a], nrow = n, ncol = 3)
  rab <- function(a, b) rowSums(axcol(proximal, a) * axcol(distal, b))
  r12 <- rab(1, 2); r22 <- rab(2, 2)
  r31 <- rab(3, 1); r32 <- rab(3, 2); r33 <- rab(3, 3)

  abduction <- asin(pmax(-1, pmin(1, r32)))   # floating axis (X)
  flexion   <- atan2(-r12, r22)               # proximal Z axis
  rotation  <- atan2(-r31, r33)               # distal Y axis

  ang <- cbind(flexion = flexion, abduction = abduction, rotation = rotation)
  if (degrees) ang <- ang * (180 / pi)
  n_bad <- sum(!is.finite(rowSums(ang)))
  if (n_bad > 0) {
    warning(sprintf(paste0("%d frame(s) produced non-finite joint angles ",
                          "(degenerate/collinear segment markers)."), n_bad),
            call. = FALSE)
  }
  ang
}


# Grood-Suntay path for calculateJointAngles: each joint = list(proximal =, and
# distal =) where each is a segment marker spec (proximal/distal/lateral).
# Output: 3 columns per joint (flexion / abduction / rotation).
.jointAnglesGroodSuntay <- function(pe, joints, degrees) {
  for (nm in names(joints)) {
    j <- joints[[nm]]
    if (!is.list(j) || !all(c("proximal", "distal") %in% names(j)) ||
        !is.list(j$proximal) || !is.list(j$distal)) {
      stop(sprintf(paste0("Grood-Suntay joint '%s' must be a list with ",
                          "'proximal' and 'distal' segment specs, each a list ",
                          "with 'proximal'/'distal'/'lateral' markers."), nm),
           call. = FALSE)
    }
  }
  seg_specs <- list()
  for (nm in names(joints)) {
    seg_specs[[paste0(nm, "::prox")]] <- joints[[nm]]$proximal
    seg_specs[[paste0(nm, "::dist")]] <- joints[[nm]]$distal
  }
  frames <- jointCoordinateSystem(pe, seg_specs)

  axes <- c("flexion", "abduction", "rotation")
  blocks <- list()
  labels <- character(0)
  for (nm in names(joints)) {
    ang <- groodSuntayAngles(frames[[paste0(nm, "::prox")]],
                             frames[[paste0(nm, "::dist")]], degrees = degrees)
    blocks[[nm]] <- ang
    labels <- c(labels, paste0(nm, "_", axes))
  }
  angle_mat <- do.call(cbind, blocks)
  colnames(angle_mat) <- labels

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(joint_angles = angle_mat),
    colData = S4Vectors::DataFrame(
      label = labels,
      joint = rep(names(joints), each = 3L),
      axis = rep(axes, times = length(joints)),
      type = "joint_angle",
      unit = if (degrees) "deg" else "rad"),
    samplingRate = PhysioCore::samplingRate(pe))
}


#' Angle between two 3D vectors
#'
#' Computes the angle between pairs of 3D vectors. Accepts either
#' single vectors (length-3 numeric) or matrices where each row is a
#' vector (n x 3). Vectorized for efficient computation across time
#' frames.
#'
#' @param v1 Numeric vector of length 3 or matrix with 3 columns.
#' @param v2 Numeric vector of length 3 or matrix with 3 columns.
#' @param degrees Logical. If `TRUE` (default), return angles in
#'   degrees. If `FALSE`, return in radians.
#'
#' @return Numeric vector of angles. Length 1 for vector inputs,
#'   or `nrow(v1)` for matrix inputs.
#'
#' @details
#' The angle is computed as:
#' \deqn{\theta = \arccos\left(\frac{v_1 \cdot v_2}{|v_1| |v_2|}\right)}
#'
#' The dot product is clamped to \eqn{[-1, 1]} before applying
#' `acos` to avoid numerical issues. If either vector has zero
#' magnitude, the result is `NA`.
#'
#' The result is unsigned, in \eqn{[0, 180]}: it says how far apart the two
#' vectors are but not which side of `v1` that `v2` lies on, so mirror-image
#' configurations (joint flexion versus hyperextension) are indistinguishable.
#' For the signed variant, measured about a plane normal and therefore able to
#' separate the two, use `calculateJointAngles(..., signed = TRUE)`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#' description of three-dimensional motions: application to the knee."
#' Journal of Biomechanical Engineering, 105(2), 136-144.
#'
#' @seealso [calculateJointAngles()], [quaternionToEuler()], [eulerToQuaternion()]
#'
#' @export
#' @examples
#' # 90-degree angle
#' vectorAngle(c(1, 0, 0), c(0, 1, 0))
#'
#' # Vectorized across rows
#' v1 <- matrix(c(1,0,0, 0,1,0), nrow = 2, byrow = TRUE)
#' v2 <- matrix(c(0,1,0, 0,0,1), nrow = 2, byrow = TRUE)
#' vectorAngle(v1, v2)
vectorAngle <- function(v1, v2, degrees = TRUE) {
  # Coerce to matrix form if vectors

  if (is.null(dim(v1))) v1 <- matrix(v1, nrow = 1)
  if (is.null(dim(v2))) v2 <- matrix(v2, nrow = 1)

  stopifnot(ncol(v1) == 3 && ncol(v2) == 3)
  stopifnot(nrow(v1) == nrow(v2))

  dot <- .dot_product(v1, v2)
  mag1 <- sqrt(rowSums(v1^2))
  mag2 <- sqrt(rowSums(v2^2))

  # Compute cosine, handling zero-magnitude vectors and NAs
  cos_angle <- rep(NA_real_, length(dot))
  valid <- !is.na(mag1) & !is.na(mag2) & mag1 > 0 & mag2 > 0 & !is.na(dot)
  cos_angle[valid] <- dot[valid] / (mag1[valid] * mag2[valid])

  # Clamp to [-1, 1] to handle floating point errors
  cos_angle <- pmax(-1, pmin(1, cos_angle))

  angle <- acos(cos_angle)

  if (degrees) {
    angle * 180 / pi
  } else {
    angle
  }
}


#' Convert quaternion to Euler angles
#'
#' Converts a quaternion (w, x, y, z) representation to Euler angles
#' (roll, pitch, yaw) using the specified rotation order.
#'
#' @param w Numeric. Scalar (real) part of the quaternion.
#' @param x Numeric. First imaginary component.
#' @param y Numeric. Second imaginary component.
#' @param z Numeric. Third imaginary component.
#' @param order Character. Rotation order. Default `"ZYX"`.
#' @param degrees Logical. If `TRUE` (default), return Euler angles
#'   in degrees. If `FALSE`, return in radians.
#'
#' @return A matrix with columns `roll`, `pitch`, `yaw`. If inputs
#'   are scalars, returns a 1-row matrix. If inputs are vectors,
#'   returns a matrix with one row per element.
#'
#' @details
#' For the `"ZYX"` (Tait-Bryan) convention:
#' \itemize{
#'   \item roll = rotation about X axis
#'   \item pitch = rotation about Y axis
#'   \item yaw = rotation about Z axis
#' }
#'
#' The quaternion is assumed to be unit (normalized). If not unit,
#' it is normalized internally before conversion.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#' description of three-dimensional motions: application to the knee."
#' Journal of Biomechanical Engineering, 105(2), 136-144.
#'
#' @seealso [eulerToQuaternion()], [calculateJointAngles()], [vectorAngle()]
#'
#' @export
#' @examples
#' # Identity quaternion -> zero Euler angles
#' quaternionToEuler(1, 0, 0, 0)
#'
#' # 90-degree rotation about Z axis
#' quaternionToEuler(cos(pi/4), 0, 0, sin(pi/4))
quaternionToEuler <- function(w, x, y, z, order = "ZYX", degrees = TRUE) {
  stopifnot(length(w) == length(x))
  stopifnot(length(w) == length(y))
  stopifnot(length(w) == length(z))
  order <- match.arg(order, choices = c("ZYX"))

  n <- length(w)

  # Normalize quaternion
  norm_q <- sqrt(w^2 + x^2 + y^2 + z^2)
  w <- w / norm_q
  x <- x / norm_q
  y <- y / norm_q
  z <- z / norm_q

  # ZYX (Tait-Bryan) convention
  # roll (X), pitch (Y), yaw (Z)
  roll <- atan2(2 * (w * x + y * z), 1 - 2 * (x^2 + y^2))

  # Clamp the argument of asin to [-1, 1]
  sinp <- 2 * (w * y - z * x)
  sinp <- pmax(-1, pmin(1, sinp))
  pitch <- asin(sinp)

  yaw <- atan2(2 * (w * z + x * y), 1 - 2 * (y^2 + z^2))

  result <- cbind(roll = roll, pitch = pitch, yaw = yaw)

  if (degrees) {
    result <- result * 180 / pi
  }

  result
}


#' Convert Euler angles to quaternion
#'
#' Converts Euler angles (roll, pitch, yaw) to quaternion (w, x, y, z)
#' representation using the specified rotation order.
#'
#' @param roll Numeric. Rotation about X axis (in radians by default,
#'   or degrees if values > 2*pi suggest degree input).
#' @param pitch Numeric. Rotation about Y axis.
#' @param yaw Numeric. Rotation about Z axis.
#' @param order Character. Rotation order. Default `"ZYX"`.
#'
#' @return A matrix with columns `w`, `x`, `y`, `z`. If inputs are
#'   scalars, returns a 1-row matrix. If inputs are vectors, returns
#'   a matrix with one row per element.
#'
#' @details
#' Input angles are assumed to be in **radians**. For the `"ZYX"`
#' convention, the combined quaternion is computed as:
#' \eqn{q = q_z \otimes q_y \otimes q_x}
#'
#' The resulting quaternion is always returned with \eqn{w \geq 0}
#' (canonical form).
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#' description of three-dimensional motions: application to the knee."
#' Journal of Biomechanical Engineering, 105(2), 136-144.
#'
#' @seealso [quaternionToEuler()], [calculateJointAngles()], [vectorAngle()]
#'
#' @export
#' @examples
#' # Zero rotation -> identity quaternion
#' eulerToQuaternion(0, 0, 0)
#'
#' # 90-degree rotation about Z axis (input in radians)
#' eulerToQuaternion(0, 0, pi/2)
eulerToQuaternion <- function(roll, pitch, yaw, order = "ZYX") {
  stopifnot(length(roll) == length(pitch))
  stopifnot(length(roll) == length(yaw))
  order <- match.arg(order, choices = c("ZYX"))

  # Half angles
  cr <- cos(roll / 2)
  sr <- sin(roll / 2)
  cp <- cos(pitch / 2)
  sp <- sin(pitch / 2)
  cy <- cos(yaw / 2)
  sy <- sin(yaw / 2)

  # ZYX convention: q = qz * qy * qx
  w <- cr * cp * cy + sr * sp * sy
  x <- sr * cp * cy - cr * sp * sy
  y <- cr * sp * cy + sr * cp * sy
  z <- cr * cp * sy - sr * sp * cy

  result <- cbind(w = w, x = x, y = y, z = z)

  result
}


#' Signed angle between two vectors about a normal axis
#'
#' Returns the angle from `v1` to `v2` measured about `normal`, positive when
#' the rotation follows the right-hand rule about that axis. Both vectors are
#' first projected onto the plane perpendicular to `normal`, so the result is a
#' genuine planar angle in \eqn{(-\pi, \pi]}; for vectors that already lie in
#' that plane its magnitude equals the unsigned angle from [vectorAngle()].
#'
#' @param v1,v2 Numeric `n x 3` matrices.
#' @param normal Numeric `n x 3` matrix of (not necessarily unit) axis vectors.
#' @param degrees Logical; return degrees (default) or radians.
#' @return Numeric vector of length `nrow(v1)`; `NA` where an input is `NA` or a
#'   projected vector has zero length.
#' @keywords internal
#' @noRd
.signed_angle <- function(v1, v2, normal, degrees = TRUE) {
  nhat <- .normalize_rows(normal)
  # Drop the component along the axis: the angle is measured in the plane.
  v1p <- v1 - nhat * .dot_product(v1, nhat)
  v2p <- v2 - nhat * .dot_product(v2, nhat)

  num <- .dot_product(.cross_product(v1p, v2p), nhat)
  den <- .dot_product(v1p, v2p)
  mag1 <- sqrt(rowSums(v1p^2))
  mag2 <- sqrt(rowSums(v2p^2))

  ang <- rep(NA_real_, nrow(v1))
  ok <- !is.na(num) & !is.na(den) & !is.na(mag1) & !is.na(mag2) &
    mag1 > 0 & mag2 > 0
  ang[ok] <- atan2(num[ok], den[ok])

  if (degrees) ang * 180 / pi else ang
}


#' Resolve the plane normal for a signed joint angle
#'
#' Turns the user-facing `plane_normal` argument into an `n x 3` matrix of
#' per-frame axis vectors for one joint. `NULL` means the global z axis for 2D
#' data, or a best-fit plane normal derived from the joint vectors for 3D data.
#'
#' @param plane_normal `NULL`, a length-3 numeric, an `n x 3` matrix, or a named
#'   list of any of those keyed by joint name.
#' @param joint_name Name of the joint being resolved (for list lookup/errors).
#' @param v1,v2 The joint's `n x 3` direction vectors.
#' @param has_z Logical; whether the source data carried a `position_z` assay.
#' @return Numeric `n x 3` matrix.
#' @keywords internal
#' @noRd
.resolve_plane_normal <- function(plane_normal, joint_name, v1, v2, has_z) {
  n_frames <- nrow(v1)

  pn <- plane_normal
  if (is.list(pn) && !is.data.frame(pn)) {
    if (is.null(names(pn)) || !joint_name %in% names(pn)) {
      stop(sprintf(paste0("'plane_normal' is a list but has no entry for ",
                          "joint '%s'."), joint_name), call. = FALSE)
    }
    pn <- pn[[joint_name]]
  }

  if (is.null(pn)) {
    if (!has_z) {
      # 2D data: the sagittal plane is the x-y plane, so the axis is global z.
      return(matrix(c(0, 0, 1), nrow = n_frames, ncol = 3, byrow = TRUE))
    }
    return(.derive_plane_normal(v1, v2, joint_name))
  }

  if (is.data.frame(pn)) pn <- as.matrix(pn)
  if (is.null(dim(pn))) {
    if (!is.numeric(pn) || length(pn) != 3) {
      stop(sprintf(paste0("'plane_normal' for joint '%s' must be a length-3 ",
                          "numeric vector or an n x 3 matrix."), joint_name),
           call. = FALSE)
    }
    pn <- matrix(as.numeric(pn), nrow = n_frames, ncol = 3, byrow = TRUE)
  } else {
    if (!is.numeric(pn) || ncol(pn) != 3) {
      stop(sprintf(paste0("'plane_normal' for joint '%s' must be a numeric ",
                          "matrix with 3 columns."), joint_name), call. = FALSE)
    }
    if (nrow(pn) == 1L) {
      pn <- matrix(as.numeric(pn), nrow = n_frames, ncol = 3, byrow = TRUE)
    } else if (nrow(pn) != n_frames) {
      stop(sprintf(paste0("'plane_normal' for joint '%s' has %d rows but the ",
                          "data has %d frames."), joint_name, nrow(pn),
                   n_frames), call. = FALSE)
    }
    pn <- matrix(as.numeric(pn), nrow = n_frames, ncol = 3)
  }

  # A zero-length or non-finite axis cannot be normalised; fail loudly rather
  # than let .normalize_rows turn it into a column of silent NAs.
  len <- rowSums(pn^2)
  if (any(!is.finite(len) | len == 0)) {
    stop(sprintf(paste0("'plane_normal' for joint '%s' has a degenerate axis: ",
                        "it must be finite and of non-zero length."),
                 joint_name), call. = FALSE)
  }
  pn
}


#' Best-fit plane normal for a joint's direction vectors
#'
#' The least-variance direction of `v1` and `v2` pooled over all frames, i.e.
#' the normal of the plane the joint moves in. Only defined up to a global
#' flip, so the caller is warned that the sign convention comes from the data.
#'
#' @param v1,v2 Numeric `n x 3` matrices.
#' @param joint_name Joint name, used in messages.
#' @return Numeric `n x 3` matrix repeating the unit normal.
#' @keywords internal
#' @noRd
.derive_plane_normal <- function(v1, v2, joint_name) {
  n_frames <- nrow(v1)
  x <- rbind(v1, v2)
  keep <- stats::complete.cases(x) & rowSums(x^2) > 0
  x <- x[keep, , drop = FALSE]
  if (nrow(x) < 3L) {
    stop(sprintf(paste0("Cannot derive a plane normal for joint '%s' from %d ",
                        "usable frame vector(s); supply 'plane_normal'."),
                 joint_name, nrow(x)), call. = FALSE)
  }

  sv <- svd(x)
  nrm <- sv$v[, 3L]
  # The SVD normal is arbitrary up to sign: fix it deterministically so repeated
  # runs on the same data agree.
  k <- which.max(abs(nrm))
  if (nrm[k] < 0) nrm <- -nrm

  flatness <- if (sv$d[2L] > 0) sv$d[3L] / sv$d[2L] else 0
  msg <- sprintf(paste0("Joint '%s': 'plane_normal' was derived from the data ",
                        "(c(%s)); its direction, and therefore the sign of the ",
                        "angle, is not a clinical convention. Supply ",
                        "'plane_normal' to fix flexion as positive."),
                 joint_name, paste(sprintf("%.3f", nrm), collapse = ", "))
  if (flatness > 0.1) {
    msg <- paste0(msg, sprintf(paste0(" The motion is also poorly planar ",
                                      "(out-of-plane / in-plane spread = ",
                                      "%.2f), so the signed magnitude will be ",
                                      "smaller than the unsigned angle."),
                               flatness))
  }
  warning(msg, call. = FALSE)

  matrix(nrm, nrow = n_frames, ncol = 3, byrow = TRUE)
}


#' Collapse a constant-row matrix to a single row
#'
#' @param m Numeric matrix.
#' @return The first row if every row is identical, otherwise `m` unchanged.
#' @keywords internal
#' @noRd
.collapse_constant_rows <- function(m) {
  if (nrow(m) <= 1L) return(drop(m))
  same <- all(vapply(seq_len(ncol(m)),
                     function(k) all(m[, k] == m[1L, k]), logical(1)))
  if (isTRUE(same)) m[1L, ] else m
}


#' Normalize rows of a matrix to unit vectors
#'
#' Computes row-wise unit vectors by dividing each row by its
#' Euclidean norm. Rows with zero magnitude are returned as `NA`.
#'
#' @param mat Numeric matrix.
#' @return Matrix of the same dimensions with unit-length rows.
#' @keywords internal
#' @noRd
.normalize_rows <- function(mat) {
  norms <- sqrt(rowSums(mat^2))
  # Avoid division by zero
  norms[norms == 0] <- NA_real_
  mat / norms
}


#' Vectorized cross product
#'
#' Computes the cross product of corresponding rows of two matrices
#' (each n x 3).
#'
#' @param v1 Numeric matrix with 3 columns.
#' @param v2 Numeric matrix with 3 columns.
#' @return Numeric matrix (n x 3) of cross products.
#' @keywords internal
#' @noRd
.cross_product <- function(v1, v2) {
  cbind(
    v1[, 2] * v2[, 3] - v1[, 3] * v2[, 2],
    v1[, 3] * v2[, 1] - v1[, 1] * v2[, 3],
    v1[, 1] * v2[, 2] - v1[, 2] * v2[, 1]
  )
}


#' Vectorized dot product
#'
#' Computes the dot product of corresponding rows of two matrices
#' (each n x 3).
#'
#' @param v1 Numeric matrix with 3 columns.
#' @param v2 Numeric matrix with 3 columns.
#' @return Numeric vector of length n.
#' @keywords internal
#' @noRd
.dot_product <- function(v1, v2) {
  rowSums(v1 * v2)
}
