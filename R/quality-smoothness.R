# Movement-quality smoothness metrics (SPARC, LDLJ). Sensitive proxies for
# motor-control recovery in rehabilitation (e.g. post-stroke reaching).

# Reject a missing/invalid sampling frequency with a clear message (a bare
# `fs > 0` in stopifnot() silently passes for fs = NULL, since NULL > 0 is
# logical(0)).
.check_fs <- function(fs) {
  if (!is.numeric(fs) || length(fs) != 1L || is.na(fs) || fs <= 0) {
    stop("fs (sampling frequency in Hz) must be a single positive number.",
         call. = FALSE)
  }
}

#' Spectral Arc Length (SPARC) movement smoothness
#'
#' A duration- and amplitude-robust smoothness measure computed from the
#' normalized Fourier magnitude spectrum of a speed profile. More negative =
#' less smooth. A smooth minimum-jerk movement is approximately -1.4.
#'
#' @param speed Numeric speed (tangential velocity magnitude) profile.
#' @param fs Sampling frequency in Hz.
#' @param padlevel Zero-padding exponent added to the FFT length (default 4).
#' @param fc Maximum cutoff frequency in Hz (default 10).
#' @param amp_th Normalized amplitude threshold for the adaptive cutoff (0.05).
#' @return The spectral arc length (negative scalar); \code{NA} if undefined.
#' @references Balasubramanian S, Melendez-Calderon A, Roby-Brami A, Burdet E
#'   (2015). "On the analysis of movement smoothness." J NeuroEng Rehabil 12:112.
#' @examples
#' t <- seq(0, 1, length.out = 200); tau <- t
#' speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4  # minimum-jerk speed
#' sparc(speed, fs = 200)
#' @export
sparc <- function(speed, fs, padlevel = 4, fc = 10, amp_th = 0.05) {
  speed <- as.numeric(speed)
  n <- length(speed)
  stopifnot(n >= 4)
  .check_fs(fs)
  nfft <- 2L^(ceiling(log2(n)) + padlevel)
  # Full nfft-point magnitude spectrum with frequency axis 0, fs/nfft, ... just
  # short of fs (matching the reference toolbox exactly, including the case
  # fc > fs/2 where the mirror bins are selected).
  Mf <- Mod(stats::fft(c(speed, rep(0, nfft - n))))
  mx <- max(Mf)
  if (mx <= 0) return(NA_real_)
  Mf <- Mf / mx
  f <- seq(0, by = fs / nfft, length.out = nfft)

  sel <- f <= fc
  f_sel <- f[sel]
  Mf_sel <- Mf[sel]
  # adaptive cutoff: span from the first to the last frequency above amp_th
  above <- which(Mf_sel >= amp_th)
  if (length(above) < 2L) return(NA_real_)
  idx <- above[1]:above[length(above)]
  f_sel <- f_sel[idx]
  Mf_sel <- Mf_sel[idx]

  df <- diff(f_sel) / (f_sel[length(f_sel)] - f_sel[1])
  dM <- diff(Mf_sel)
  -sum(sqrt(df^2 + dM^2))
}

#' Dimensionless jerk of a speed profile
#'
#' @param speed Numeric speed profile.
#' @param fs Sampling frequency in Hz.
#' @return The (positive) dimensionless jerk. See \code{\link{ldlj}} for the log form.
#' @export
dimensionlessJerk <- function(speed, fs) {
  speed <- as.numeric(speed)
  n <- length(speed)
  stopifnot(n >= 3)
  .check_fs(fs)
  dt <- 1 / fs
  # Movement duration is the sample count times the sample period (n / fs), as
  # in the reference smoothness toolbox (Balasubramanian / Melendez-Calderon).
  duration <- n * dt
  v_peak <- max(abs(speed))
  if (v_peak <= 0) return(NA_real_)
  accel <- diff(speed) / dt
  jerk <- diff(accel) / dt
  jerk_sq_integral <- sum(jerk^2) * dt
  (duration^3 / v_peak^2) * jerk_sq_integral
}

#' Log Dimensionless Jerk (LDLJ) movement smoothness
#'
#' The log of the (speed-based) dimensionless jerk, negated so that more
#' negative = less smooth.
#'
#' @param speed Numeric speed profile.
#' @param fs Sampling frequency in Hz.
#' @return The LDLJ (negative scalar).
#' @references Balasubramanian et al. (2015); Melendez-Calderon et al. (2021).
#' @examples
#' t <- seq(0, 1, length.out = 200); tau <- t
#' speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4
#' ldlj(speed, fs = 200)
#' @export
ldlj <- function(speed, fs) {
  dlj <- dimensionlessJerk(speed, fs)
  if (is.na(dlj) || dlj <= 0) return(NA_real_)
  -log(dlj)
}

#' Movement-smoothness battery (SPARC + LDLJ)
#'
#' Computes the SPARC and log dimensionless jerk smoothness metrics for a speed
#' profile. Accepts either a numeric speed vector (with \code{fs}) or a
#' \code{PhysioExperiment}, in which case the speed profile is pulled from the
#' \code{assay} (computing it with \code{\link{computeVelocity}} /
#' \code{\link{computeSpeed}} when absent) and the sampling rate from the object.
#' When several markers are present each is scored.
#'
#' @param x A numeric speed profile, or a \code{PhysioExperiment}.
#' @param fs Sampling frequency in Hz (ignored / taken from the object when
#'   \code{x} is a \code{PhysioExperiment}).
#' @param assay Speed assay to use for a \code{PhysioExperiment} (default
#'   \code{"speed"}).
#' @param marker Optional marker (column) name or index to score; by default all
#'   markers of the speed assay are scored.
#' @param ... Passed to \code{\link{sparc}}.
#' @return An S3 \code{"movement_smoothness"} object: a list with \code{sparc}
#'   and \code{ldlj} (named by marker when a \code{PhysioExperiment} is scored),
#'   \code{dimensionless_jerk}, \code{fs} and \code{n}.
#' @references Balasubramanian et al. (2015); Melendez-Calderon et al. (2021).
#' @examples
#' t <- seq(0, 1, length.out = 200); tau <- t
#' speed <- 30 * tau^2 - 60 * tau^3 + 30 * tau^4
#' movementSmoothness(speed, fs = 200)
#' @export
movementSmoothness <- function(x, fs = NULL, assay = "speed", marker = NULL,
                               ...) {
  if (inherits(x, "PhysioExperiment")) {
    if (!(assay %in% SummarizedExperiment::assayNames(x))) {
      vel <- c("velocity_x", "velocity_y", "velocity_z", "velocity_kp_x",
               "velocity_kp_y")
      if (!any(vel %in% SummarizedExperiment::assayNames(x))) {
        x <- computeVelocity(x)
      }
      x <- computeSpeed(x)
      assay <- "speed"
    }
    speed_mat <- as.matrix(SummarizedExperiment::assay(x, assay))
    if (!is.null(marker)) speed_mat <- speed_mat[, marker, drop = FALSE]
    if (is.null(fs)) fs <- as.numeric(samplingRate(x))[1]

    cols <- seq_len(ncol(speed_mat))
    sparc_v <- vapply(cols, function(j) sparc(speed_mat[, j], fs, ...),
                      numeric(1))
    ldlj_v <- vapply(cols, function(j) ldlj(speed_mat[, j], fs), numeric(1))
    dj_v <- vapply(cols, function(j) dimensionlessJerk(speed_mat[, j], fs),
                   numeric(1))
    labs <- colnames(speed_mat)
    if (!is.null(labs)) {
      names(sparc_v) <- labs; names(ldlj_v) <- labs; names(dj_v) <- labs
    }
    obj <- list(sparc = sparc_v, ldlj = ldlj_v, dimensionless_jerk = dj_v,
                marker = labs, fs = fs, n = nrow(speed_mat))
  } else {
    speed <- as.numeric(x)
    obj <- list(sparc = sparc(speed, fs, ...), ldlj = ldlj(speed, fs),
                dimensionless_jerk = dimensionlessJerk(speed, fs),
                marker = NULL, fs = fs, n = length(speed))
  }
  structure(obj, class = "movement_smoothness")
}

#' @export
print.movement_smoothness <- function(x, ...) {
  cat("<movement_smoothness>\n")
  cat(sprintf("  samples: %d  |  sampling rate: %s Hz\n", x$n,
              format(x$fs)))
  if (length(x$sparc) > 1 && !is.null(names(x$sparc))) {
    tab <- data.frame(SPARC = x$sparc, LDLJ = x$ldlj,
                      row.names = names(x$sparc))
    print(round(tab, 4))
  } else {
    cat(sprintf("  SPARC: %.4f\n", x$sparc[1]))
    cat(sprintf("  LDLJ:  %.4f\n", x$ldlj[1]))
  }
  invisible(x)
}
