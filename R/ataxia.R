# Quantitative ataxia metrics. Limb ataxia is quantified from reaching
# kinematics (dysmetria = endpoint error via `endpointError()`; decomposition =
# submovement count via `movementUnits()`; smoothness via `sparc()` / `ldlj()`;
# path irregularity via `pathStraightness()` below). Gait ataxia is quantified
# from spatiotemporal gait variability (`summarizeGaitParameters()` coefficients
# of variation) and trunk sway (`swayMetrics()`). The index functions here are
# thin, honest aggregators: they combine those already-validated sub-metrics and,
# only when a healthy `reference` sample is supplied, standardise them into a
# composite z-score (no population weights or cut-offs are fabricated).

#' Movement-path straightness
#'
#' The straightness of a movement trajectory: the ratio of the straight-line
#' (direct) distance between the first and last points to the travelled path
#' length. A straight reach scores 1; a curved or decomposed path scores below 1.
#' The reciprocal (index of curvature) grows with path irregularity, a
#' hallmark of limb ataxia.
#'
#' @param trajectory Numeric matrix of positions over time (rows = samples,
#'   columns = 1-3 spatial axes), or a numeric vector for a single axis.
#' @return A list: `path_length`, `direct_distance`, `straightness`
#'   (direct / path, in `(0, 1]`) and `index_of_curvature` (path / direct,
#'   `>= 1`).
#' @seealso [reachingKinematics()], [limbAtaxiaIndex()]
#' @export
#' @examples
#' pathStraightness(cbind(c(0, 0, 1), c(0, 1, 1)))$straightness   # L-path
pathStraightness <- function(trajectory) {
  m <- if (is.null(dim(trajectory))) {
    matrix(as.numeric(trajectory), ncol = 1L)
  } else as.matrix(trajectory)
  storage.mode(m) <- "double"
  if (nrow(m) < 2L) stop("trajectory needs at least two points.", call. = FALSE)
  if (any(!is.finite(m))) stop("trajectory must be finite.", call. = FALSE)
  steps <- diff(m)
  path_length <- sum(sqrt(rowSums(steps^2)))
  direct <- sqrt(sum((m[nrow(m), ] - m[1L, ])^2))
  list(path_length = path_length, direct_distance = direct,
       straightness = if (path_length > 0) direct / path_length else NA_real_,
       index_of_curvature = if (direct > 0) path_length / direct else NA_real_)
}

# Standardise a set of "higher = worse" sub-metrics against a healthy reference
# and weight-average into a composite z. Without a reference the composite is NA
# (heterogeneous units cannot be honestly combined) and only the sub-metrics are
# reported.
.ataxia_composite <- function(metrics, reference = NULL, weights = NULL) {
  metrics <- metrics[!vapply(metrics, function(v) is.null(v) || is.na(v), logical(1))]
  z <- stats::setNames(rep(NA_real_, length(metrics)), names(metrics))
  composite <- NA_real_
  if (length(metrics) && !is.null(reference)) {
    ref <- as.data.frame(reference)
    for (nm in names(metrics)) {
      if (!nm %in% names(ref)) next
      col <- as.numeric(ref[[nm]])
      mu <- mean(col, na.rm = TRUE); s <- stats::sd(col, na.rm = TRUE)
      if (is.finite(s) && s > 0) z[[nm]] <- (metrics[[nm]] - mu) / s
    }
    zv <- z[is.finite(z)]
    if (length(zv)) {
      w <- if (is.null(weights)) rep(1, length(zv)) else {
        ww <- weights[names(zv)]; ww[is.na(ww)] <- 0; ww
      }
      if (sum(w) > 0) composite <- sum(zv * (w / sum(w)))
    }
  }
  list(metrics = unlist(metrics), z = z, composite = composite)
}

#' Limb-ataxia composite from reaching sub-metrics
#'
#' Aggregates the standard limb-ataxia sub-metrics, each oriented so that a
#' higher value means more ataxic movement. Supply them from the existing
#' primitives: `dysmetria` from [endpointError()] (`absolute_error` or the
#' magnitude of `constant_error`), `decomposition` from [movementUnits()] (the
#' submovement count), `smoothness` as a jerk/roughness score where higher is
#' worse (e.g. `-sparc` from [sparc()], since SPARC is more negative for less
#' smooth movement, or `ldlj` magnitude), and `irregularity` from
#' [pathStraightness()] (`index_of_curvature`).
#'
#' @param dysmetria,decomposition,smoothness,irregularity Numeric sub-metrics
#'   (higher = more ataxic); any may be `NA` to omit it.
#' @param reference Optional data.frame of the same-named columns measured in a
#'   healthy reference sample; when given, each sub-metric is z-standardised
#'   against it and averaged into `composite`. Without a reference the composite
#'   is `NA` and only the sub-metrics are returned.
#' @param weights Optional named weights for the composite (default equal).
#' @return An S3 `limb_ataxia` list: `metrics`, per-metric `z`, and `composite`.
#' @seealso [pathStraightness()], [reachingKinematics()], [gaitAtaxiaIndex()]
#' @export
#' @examples
#' limbAtaxiaIndex(dysmetria = 3.2, decomposition = 4, smoothness = 5.1,
#'                 irregularity = 1.4)
limbAtaxiaIndex <- function(dysmetria = NA_real_, decomposition = NA_real_,
                            smoothness = NA_real_, irregularity = NA_real_,
                            reference = NULL, weights = NULL) {
  res <- .ataxia_composite(
    list(dysmetria = dysmetria, decomposition = decomposition,
         smoothness = smoothness, irregularity = irregularity),
    reference = reference, weights = weights)
  structure(res, class = "limb_ataxia")
}

#' Gait-ataxia composite from gait-variability sub-metrics
#'
#' Aggregates the standard gait-ataxia sub-metrics (each higher = more ataxic):
#' the coefficients of variation of step width, stride length and stride time
#' (from [summarizeGaitParameters()], the `cv` column, in per cent) and trunk
#' sway (e.g. `cop_path_length` from [swayMetrics()], or trunk-marker RMS).
#'
#' @param step_width_cv,stride_length_cv,stride_time_cv Gait coefficients of
#'   variation (per cent); any may be `NA`.
#' @param trunk_sway Trunk-sway magnitude (higher = worse); optional.
#' @param reference,weights As in [limbAtaxiaIndex()].
#' @return An S3 `gait_ataxia` list: `metrics`, per-metric `z`, and `composite`.
#' @seealso [summarizeGaitParameters()], [swayMetrics()], [limbAtaxiaIndex()]
#' @export
#' @examples
#' gaitAtaxiaIndex(step_width_cv = 28, stride_length_cv = 9, stride_time_cv = 6)
gaitAtaxiaIndex <- function(step_width_cv = NA_real_, stride_length_cv = NA_real_,
                            stride_time_cv = NA_real_, trunk_sway = NA_real_,
                            reference = NULL, weights = NULL) {
  res <- .ataxia_composite(
    list(step_width_cv = step_width_cv, stride_length_cv = stride_length_cv,
         stride_time_cv = stride_time_cv, trunk_sway = trunk_sway),
    reference = reference, weights = weights)
  structure(res, class = "gait_ataxia")
}

#' @export
print.limb_ataxia <- function(x, ...) {
  cat("Limb-ataxia sub-metrics (higher = more ataxic):\n")
  for (nm in names(x$metrics)) cat(sprintf("  %-14s %.4g\n", nm, x$metrics[[nm]]))
  cat(sprintf("  composite z    : %s\n",
              if (is.na(x$composite)) "NA (no reference supplied)"
              else sprintf("%.3f", x$composite)))
  invisible(x)
}

#' @export
print.gait_ataxia <- function(x, ...) {
  cat("Gait-ataxia sub-metrics (higher = more ataxic):\n")
  for (nm in names(x$metrics)) cat(sprintf("  %-16s %.4g\n", nm, x$metrics[[nm]]))
  cat(sprintf("  composite z      : %s\n",
              if (is.na(x$composite)) "NA (no reference supplied)"
              else sprintf("%.3f", x$composite)))
  invisible(x)
}
