# Embedded anatomical segment frames for joint-coordinate-system (JCS) angles.
#
# Each segment gets a right-handed orthonormal frame with columns
#   X = antero-posterior, Y = long (proximal-pointing), Z = medio-lateral
# built per time frame from three markers: a proximal end, a distal end, and a
# lateral marker that fixes the frontal plane. These frames feed the
# Grood-Suntay / ISB joint angles (see groodSuntayAngles()).

# Build a per-frame segment frame (n x 3 x 3 array, columns X/Y/Z) from three
# n x 3 marker-position matrices.
.build_segment_frame <- function(prox, dist, lateral) {
  yaxis <- .normalize_rows(prox - dist)               # long axis (proximal)
  zref <- lateral - dist                              # rough medio-lateral
  xaxis <- .normalize_rows(.cross_product(yaxis, zref))  # antero-posterior
  zaxis <- .cross_product(xaxis, yaxis)               # medio-lateral (unit)
  n <- nrow(prox)
  fr <- array(NA_real_, dim = c(n, 3, 3))
  fr[, , 1] <- xaxis
  fr[, , 2] <- yaxis
  fr[, , 3] <- zaxis
  fr
}

#' Build embedded anatomical segment coordinate systems from marker clusters
#'
#' Constructs a per-frame right-handed orthonormal coordinate system for each
#' named body segment (e.g. pelvis, thigh/femur, shank/tibia, foot) from three
#' markers: a proximal end, a distal end, and a lateral marker. The axes are
#' \code{X} (antero-posterior), \code{Y} (long axis, pointing proximally) and
#' \code{Z} (medio-lateral). These segment frames are the input to
#' \code{\link{groodSuntayAngles}} and to the Grood-Suntay / ISB conventions of
#' \code{\link{calculateJointAngles}}.
#'
#' @param pe A \code{PhysioExperiment} with \code{"position_x"},
#'   \code{"position_y"} and \code{"position_z"} assays.
#' @param segments A named list; each element is a list with \code{proximal},
#'   \code{distal} and \code{lateral} marker names (columns of the position
#'   assays).
#' @return A named list of \code{n_frames x 3 x 3} arrays (one per segment); for
#'   each the three columns are the X (AP), Y (long) and Z (ML) unit axes.
#' @references
#'   Grood ES, Suntay WJ (1983). "A joint coordinate system for the clinical
#'   description of three-dimensional motions." J Biomech Eng, 105(2), 136-144.
#'   Wu G, et al. (2002, 2005). "ISB recommendation on definitions of joint
#'   coordinate systems." J Biomech.
#' @seealso [groodSuntayAngles()], [calculateJointAngles()]
#' @export
#' @examples
#' \dontrun{
#' segs <- list(
#'   femur = list(proximal = "HIP", distal = "KNEE", lateral = "THIGH"),
#'   tibia = list(proximal = "KNEE", distal = "ANKLE", lateral = "SHANK"))
#' frames <- jointCoordinateSystem(pe, segs)
#' }
jointCoordinateSystem <- function(pe, segments) {
  stopifnot(inherits(pe, "PhysioExperiment"))
  stopifnot(is.list(segments) && length(segments) > 0)
  if (is.null(names(segments)) || any(names(segments) == "")) {
    stop("'segments' must be a fully named list.", call. = FALSE)
  }
  anames <- SummarizedExperiment::assayNames(pe)
  if (!all(c("position_x", "position_y", "position_z") %in% anames)) {
    stop("jointCoordinateSystem requires 'position_x', 'position_y' and ",
         "'position_z' assays.", call. = FALSE)
  }
  px <- SummarizedExperiment::assay(pe, "position_x")
  py <- SummarizedExperiment::assay(pe, "position_y")
  pz <- SummarizedExperiment::assay(pe, "position_z")

  marker <- function(m) {
    if (is.numeric(m)) {                       # integer column index
      idx <- as.integer(m)[1]
      if (is.na(idx) || idx < 1L || idx > ncol(px)) {
        stop("marker index out of range: ", m, call. = FALSE)
      }
      return(cbind(px[, idx], py[, idx], pz[, idx]))
    }
    if (!(m %in% colnames(px)) || !(m %in% colnames(py)) ||
        !(m %in% colnames(pz))) {
      stop("marker not found in all position assays: ", m, call. = FALSE)
    }
    cbind(px[, m], py[, m], pz[, m])
  }

  out <- lapply(names(segments), function(nm) {
    s <- segments[[nm]]
    if (!all(c("proximal", "distal", "lateral") %in% names(s))) {
      stop(sprintf("segment '%s' must have 'proximal', 'distal' and 'lateral'.",
                   nm), call. = FALSE)
    }
    .build_segment_frame(marker(s$proximal), marker(s$distal),
                         marker(s$lateral))
  })
  stats::setNames(out, names(segments))
}
