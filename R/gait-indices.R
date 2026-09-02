# Gait indices: Gait Deviation Index (Schwartz & Rozumalski 2008) and the
# Gait Profile Score / Gait Variable Score / Movement Analysis Profile
# (Baker et al. 2009). Kinematics are compared against a normative reference
# from PhysioGaitNorm::loadGaitNorm().

#' Resolve a normative gait reference
#' @keywords internal
#' @noRd
.gi_resolve_norm <- function(norm) {
  if (is.null(norm)) {
    if (!requireNamespace("PhysioGaitNorm", quietly = TRUE)) {
      stop("`norm` is NULL and PhysioGaitNorm is not installed. Install ",
           "PhysioGaitNorm or pass a normative reference via `norm`.",
           call. = FALSE)
    }
    norm <- PhysioGaitNorm::loadGaitNorm()
  }
  if (!is.list(norm) || is.null(norm$mean) || is.null(norm$variables)) {
    stop("`norm` must be a gait_norm object (from ",
         "PhysioGaitNorm::loadGaitNorm()) with `mean` and `variables`.",
         call. = FALSE)
  }
  if (is.null(dim(norm$mean)) || is.null(rownames(norm$mean))) {
    stop("`norm$mean` must be a matrix with row names matching ",
         "`norm$variables`.", call. = FALSE)
  }
  miss <- setdiff(norm$variables, rownames(norm$mean))
  if (length(miss) > 0) {
    stop("`norm$variables` not found in `norm$mean` rows: ",
         paste(miss, collapse = ", "), ".", call. = FALSE)
  }
  norm
}

#' Align subject kinematics to a variables x points matrix on a target grid
#' @keywords internal
#' @noRd
.gi_align_kinematics <- function(kinematics, vars, n_points) {
  # Named list of per-variable curves -> matrix (variables x points)
  if (is.list(kinematics) && !is.data.frame(kinematics) &&
      !is.matrix(kinematics)) {
    if (is.null(names(kinematics))) {
      stop("a list of kinematic curves must be named by variable.",
           call. = FALSE)
    }
    lens <- vapply(kinematics, length, integer(1))
    if (length(unique(lens)) != 1L) {
      stop("all kinematic curves must have the same length.", call. = FALSE)
    }
    kinematics <- do.call(rbind, kinematics)
  }
  m <- as.matrix(kinematics)
  if (!is.numeric(m)) {
    stop("kinematics must be numeric.", call. = FALSE)
  }

  # Select / order the required variables by row name, or assume canonical order
  if (!is.null(rownames(m))) {
    missing <- setdiff(vars, rownames(m))
    if (length(missing) > 0) {
      stop("kinematics is missing required variables: ",
           paste(missing, collapse = ", "), ".", call. = FALSE)
    }
    # Name-based selection keeps only the first row of a duplicated name, which
    # would silently score the wrong curve; reject duplicated variable rows.
    dup <- intersect(vars, rownames(m)[duplicated(rownames(m))])
    if (length(dup) > 0) {
      stop("kinematics has duplicated variable rows: ",
           paste(unique(dup), collapse = ", "), ".", call. = FALSE)
    }
    m <- m[vars, , drop = FALSE]
  } else {
    if (nrow(m) != length(vars)) {
      stop(sprintf(paste0("kinematics has %d rows but %d variables are ",
                          "required; supply row names to disambiguate."),
                   nrow(m), length(vars)), call. = FALSE)
    }
    rownames(m) <- vars
  }
  if (any(!is.finite(m))) {
    stop("kinematics contains non-finite values.", call. = FALSE)
  }

  # Time-normalise each curve to the target grid (rows = variables, so the
  # time dimension is the columns; normalizeMovement resamples rows).
  if (ncol(m) != n_points) {
    resampled <- normalizeMovement(t(m), method = "cycle",
                                   norm_length = n_points)
    m <- t(as.matrix(resampled))
    rownames(m) <- vars
  }
  m
}

#' Gait Variable Score (per-variable RMS deviation from the norm)
#'
#' The Gait Variable Score (Baker et al. 2009) is the root-mean-square
#' difference, over the gait cycle, between a subject's kinematic curve and the
#' normative mean, computed separately for each kinematic variable (degrees).
#'
#' @param kinematics Subject kinematics: a numeric matrix with one row per
#'   kinematic variable (row names matching `norm$variables`) and one column per
#'   gait-cycle point, or a named list of per-variable curves. Curves are
#'   time-normalised to the norm's cycle length via [normalizeMovement()].
#' @param norm A `gait_norm` normative reference (from
#'   `PhysioGaitNorm::loadGaitNorm()`); if `NULL`, the default reference is
#'   loaded from PhysioGaitNorm.
#' @return A named numeric vector of GVS values (degrees), one per variable.
#' @references Baker R, et al. (2009). Gait & Posture 30(3):265-269.
#' @seealso [gaitProfileScore()], [movementAnalysisProfile()]
#' @export
#' @examples
#' norm <- list(variables = c("a", "b"),
#'              mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
#'              cycle_length = 51)
#' gaitVariableScore(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)), norm)
gaitVariableScore <- function(kinematics, norm = NULL) {
  norm <- .gi_resolve_norm(norm)
  n_points <- ncol(norm$mean)
  m <- .gi_align_kinematics(kinematics, norm$variables, n_points)
  diff <- m - norm$mean[norm$variables, , drop = FALSE]
  gvs <- sqrt(rowMeans(diff^2))
  names(gvs) <- norm$variables
  gvs
}

#' Gait Profile Score (overall RMS deviation from the norm)
#'
#' The Gait Profile Score (Baker et al. 2009) summarises overall gait deviation
#' as the root-mean-square of the Gait Variable Scores across all kinematic
#' variables (degrees). It is always non-negative and is zero when the subject
#' equals the normative mean.
#'
#' @inheritParams gaitVariableScore
#' @return A single non-negative numeric (degrees).
#' @references Baker R, et al. (2009). Gait & Posture 30(3):265-269.
#' @seealso [gaitVariableScore()], [movementAnalysisProfile()]
#' @export
#' @examples
#' norm <- list(variables = c("a", "b"),
#'              mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
#'              cycle_length = 51)
#' gaitProfileScore(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)), norm)
gaitProfileScore <- function(kinematics, norm = NULL) {
  gvs <- gaitVariableScore(kinematics, norm)
  sqrt(mean(gvs^2))
}

#' Movement Analysis Profile (GVS per variable plus the GPS)
#'
#' The Movement Analysis Profile (Baker et al. 2009) collects the per-variable
#' Gait Variable Scores together with the overall Gait Profile Score.
#'
#' @inheritParams gaitVariableScore
#' @return A `movement_analysis_profile` object: a list with `gvs` (named
#'   numeric vector), `gps` (numeric), `variables`, and `cycle_length`.
#' @references Baker R, et al. (2009). Gait & Posture 30(3):265-269.
#' @seealso [gaitProfileScore()], [gaitVariableScore()], [plotMAP()]
#' @export
#' @examples
#' norm <- list(variables = c("a", "b"),
#'              mean = matrix(0, 2, 51, dimnames = list(c("a", "b"), NULL)),
#'              cycle_length = 51)
#' movementAnalysisProfile(matrix(1, 2, 51, dimnames = list(c("a", "b"), NULL)),
#'                         norm)
movementAnalysisProfile <- function(kinematics, norm = NULL) {
  norm <- .gi_resolve_norm(norm)
  gvs <- gaitVariableScore(kinematics, norm)
  out <- list(
    gvs = gvs,
    gps = sqrt(mean(gvs^2)),
    variables = norm$variables,
    cycle_length = ncol(norm$mean)
  )
  class(out) <- "movement_analysis_profile"
  out
}

#' Build a Gait Deviation Index feature basis from a normative reference
#'
#' Computes the singular-value-decomposition feature basis of the normative
#' feature population used to score the Gait Deviation Index
#' (Schwartz & Rozumalski 2008), together with the control-population log-distance
#' mean and standard deviation used to standardise the index.
#'
#' @param norm A `gait_norm` reference with a `features` matrix (subjects x
#'   concatenated kinematics); if `NULL`, loaded from PhysioGaitNorm.
#' @param n_features Number of singular vectors (gait features) to retain
#'   (default 15).
#' @return A `gdi_basis` object.
#' @references Schwartz MH, Rozumalski A (2008). Gait & Posture 28(3):351-357.
#' @seealso [gaitDeviationIndex()]
#' @export
gdiBasis <- function(norm = NULL, n_features = 15L) {
  norm <- .gi_resolve_norm(norm)
  if (is.null(norm$features)) {
    stop("`norm` has no `features` matrix; load with features = TRUE.",
         call. = FALSE)
  }
  G <- as.matrix(norm$features)
  n_features <- as.integer(n_features)
  if (is.na(n_features) || n_features < 1L || n_features > min(dim(G))) {
    stop(sprintf("n_features must be between 1 and %d.", min(dim(G))),
         call. = FALSE)
  }
  n_points <- ncol(G) / length(norm$variables)
  if (n_points != round(n_points)) {
    stop("feature matrix width is not a multiple of the number of variables.",
         call. = FALSE)
  }

  gbar <- colMeans(G)
  Gc <- sweep(G, 2, gbar)
  V <- svd(Gc)$v[, seq_len(n_features), drop = FALSE]
  d_ctrl <- sqrt(rowSums((Gc %*% V)^2))
  if (any(d_ctrl <= 0)) {
    stop("degenerate normative feature population (a control equals the mean).",
         call. = FALSE)
  }
  ln <- log(d_ctrl)

  out <- list(
    mean = gbar,
    V = V,
    n_features = n_features,
    n_points = as.integer(n_points),
    variables = norm$variables,
    ln_mean = mean(ln),
    ln_sd = stats::sd(ln)
  )
  class(out) <- "gdi_basis"
  out
}

#' Gait Deviation Index (Schwartz & Rozumalski 2008)
#'
#' Scores overall gait pathology on a scale where the normative control
#' population averages 100 with a standard deviation of 10 (by construction);
#' values below 100 indicate greater deviation, each 10 points corresponding to
#' one standard deviation. The subject's nine kinematic curves are projected onto
#' the normative feature basis, and the log of the distance to the control mean
#' is standardised against the control distribution.
#'
#' @param kinematics Subject kinematics (see [gaitVariableScore()]); curves are
#'   time-normalised to the basis's point count (typically 51).
#' @param norm A `gait_norm` reference (from `PhysioGaitNorm::loadGaitNorm()`);
#'   if `NULL`, loaded from PhysioGaitNorm. Ignored when `basis` is supplied.
#' @param basis An optional precomputed [gdiBasis()] (reuse across many
#'   subjects); if `NULL` it is built from `norm`.
#' @param n_features Number of gait features when building the basis
#'   (default 15).
#' @return A `gait_deviation_index` object: a list with `gdi` (numeric),
#'   `distance`, `z`, and `n_features`.
#' @references Schwartz MH, Rozumalski A (2008). Gait & Posture 28(3):351-357.
#' @seealso [gdiBasis()], [gaitProfileScore()]
#' @export
gaitDeviationIndex <- function(kinematics, norm = NULL, basis = NULL,
                               n_features = 15L) {
  if (is.null(basis)) {
    basis <- gdiBasis(norm, n_features = n_features)
  }
  if (!inherits(basis, "gdi_basis")) {
    stop("`basis` must be a gdi_basis object.", call. = FALSE)
  }

  m <- .gi_align_kinematics(kinematics, basis$variables, basis$n_points)
  # variable-major concatenation to match the feature column order
  g <- as.vector(t(m))
  if (length(g) != length(basis$mean)) {
    stop("subject feature length does not match the basis.", call. = FALSE)
  }

  scores <- as.numeric((g - basis$mean) %*% basis$V)
  distance <- sqrt(sum(scores^2))
  if (distance <= 0) {
    # The subject coincides with the control-population mean: theoretically the
    # most-normal gait, giving an unbounded GDI. Warn rather than silently
    # returning an Inf that would poison downstream summaries.
    warning("subject coincides with the normative mean; GDI is unbounded (Inf).",
            call. = FALSE)
  }
  z <- (log(distance) - basis$ln_mean) / basis$ln_sd
  gdi <- 100 - 10 * z

  out <- list(gdi = gdi, distance = distance, z = z,
              n_features = basis$n_features)
  class(out) <- "gait_deviation_index"
  out
}

#' @export
print.movement_analysis_profile <- function(x, ...) {
  cat("<movement_analysis_profile>\n")
  cat(sprintf("  GPS (overall): %.2f deg\n", x$gps))
  cat("  GVS per variable (deg):\n")
  for (v in x$variables) {
    cat(sprintf("    %-20s %.2f\n", v, x$gvs[[v]]))
  }
  invisible(x)
}

#' @export
print.gait_deviation_index <- function(x, ...) {
  cat(sprintf("<gait_deviation_index> GDI = %.1f (z = %.2f, %d features)\n",
              x$gdi, x$z, x$n_features))
  invisible(x)
}

#' @export
print.gdi_basis <- function(x, ...) {
  cat(sprintf("<gdi_basis> %d features, %d variables x %d points\n",
              x$n_features, length(x$variables), x$n_points))
  invisible(x)
}
