# Inter-joint (inter-segment) coordination analysis.
#
# Smoothness and variability describe a single signal; COORDINATION describes how
# two joints move relative to each other -- thigh vs shank in gait, shoulder vs
# elbow in a reach. Three established methods: continuous relative phase (the
# phase-plane angle difference; Hamill et al. 2000), vector coding (the coupling
# angle on the angle-angle diagram, classified into in-/anti-/proximal-/distal-
# phase; Chang et al. 2008, Needham et al. 2014) and their trial-to-trial
# coordination variability (a marker of motor control, elevated or reduced in
# pathology). Dependency-free base R on joint-angle time series.

# Phase angle from the (normalised) phase portrait: atan2(velocity, position).
# The dt of the centred-difference velocity cancels under normalisation.
.coord_phase_angle <- function(x, normalize = TRUE) {
  n <- length(x)
  v <- c(x[2] - x[1], (x[3:n] - x[1:(n - 2)]) / 2, x[n] - x[n - 1])
  if (normalize) {
    rng <- range(x); span <- diff(rng)
    x <- if (span > 0) 2 * (x - rng[1]) / span - 1 else rep(0, n)
    mv <- max(abs(v)); v <- if (mv > 0) v / mv else rep(0, n)
  }
  atan2(v, x)                                    # radians
}

.wrap_deg <- function(d) ((d + 180) %% 360) - 180   # -> (-180, 180]

#' Continuous relative phase between two joints
#'
#' The phase-plane coordination measure (Hamill et al. 2000): each joint angle is
#' mapped to a phase angle from its (normalised) phase portrait, and the
#' continuous relative phase is their difference through the movement. Its mean
#' absolute value (MARP) summarises whether the joints move more in-phase (near
#' 0) or out-of-phase (near 180).
#'
#' @param angle1,angle2 Numeric joint-angle time series of equal length, one
#'   movement cycle (typically time-normalised); `angle1` is the reference
#'   (e.g. proximal) joint.
#' @param normalize Normalise the phase portrait (recommended; corrects for
#'   amplitude differences).
#' @return a `crp_result` list: `crp` (degrees, wrapped to +/-180), `phase1`,
#'   `phase2` (phase angles, degrees) and `marp` (mean absolute relative phase).
#' @references Hamill J, et al. (2000) Clin Biomech 15:S31-S39.
#' @seealso [vectorCoding()], [coordinationVariability()]
#' @export
#' @examples
#' t <- seq(0, 2 * pi, length.out = 101)
#' continuousRelativePhase(sin(t), sin(t))$marp        # in-phase ~ 0
continuousRelativePhase <- function(angle1, angle2, normalize = TRUE) {
  angle1 <- as.numeric(angle1); angle2 <- as.numeric(angle2)
  if (length(angle1) != length(angle2) || length(angle1) < 3) {
    stop("`angle1` and `angle2` must be equal-length series (>= 3).", call. = FALSE)
  }
  p1 <- .coord_phase_angle(angle1, normalize)
  p2 <- .coord_phase_angle(angle2, normalize)
  crp <- .wrap_deg((p1 - p2) * 180 / pi)
  structure(list(crp = crp, phase1 = p1 * 180 / pi, phase2 = p2 * 180 / pi,
                 marp = mean(abs(crp))), class = "crp_result")
}

#' @export
print.crp_result <- function(x, ...) {
  cat(sprintf("<crp_result> MARP %.1f deg | CRP range [%.0f, %.0f]\n",
              x$marp, min(x$crp), max(x$crp)))
  invisible(x)
}

# 8-bin (22.5 deg) coupling-angle -> 4 coordination patterns (Chang/Needham).
.vc_pattern <- function(ca) {
  b <- findInterval(ca %% 360, seq(0, 360, 22.5), rightmost.closed = TRUE)
  out <- character(length(ca))
  out[b %in% c(2, 3, 10, 11)]  <- "in_phase"
  out[b %in% c(6, 7, 14, 15)]  <- "anti_phase"
  out[b %in% c(1, 8, 9, 16)]   <- "proximal"     # angle1 (proximal) dominant
  out[b %in% c(4, 5, 12, 13)]  <- "distal"       # angle2 (distal) dominant
  factor(out, levels = c("in_phase", "anti_phase", "proximal", "distal"))
}

#' Vector coding (coupling angle) between two joints
#'
#' Vector coding quantifies coordination from the angle-angle diagram: the
#' coupling angle is the orientation of the vector between successive points, and
#' each frame is classified into in-phase (both joints rotating together),
#' anti-phase (opposite), proximal-phase (`angle1` dominant) or distal-phase
#' (`angle2` dominant) coordination (Chang et al. 2008; Needham et al. 2014).
#'
#' @param angle1,angle2 Numeric joint-angle series of equal length; `angle1` is
#'   the proximal joint (horizontal axis of the angle-angle plot).
#' @return a `vector_coding` list: `coupling_angle` (degrees, 0-360, length n-1),
#'   `pattern` (a factor per frame) and `proportions` (time fraction per pattern).
#' @references Chang R, et al. (2008) J Biomech 41:3101-3105; Needham RA, et al.
#'   (2014) J Biomech 47:1235-1241.
#' @seealso [continuousRelativePhase()], [coordinationVariability()]
#' @export
#' @examples
#' t <- seq(0, 2 * pi, length.out = 101)
#' vectorCoding(sin(t), sin(t))$proportions            # all in-phase
vectorCoding <- function(angle1, angle2) {
  angle1 <- as.numeric(angle1); angle2 <- as.numeric(angle2)
  if (length(angle1) != length(angle2) || length(angle1) < 2) {
    stop("`angle1` and `angle2` must be equal-length series (>= 2).", call. = FALSE)
  }
  ca <- (atan2(diff(angle2), diff(angle1)) * 180 / pi) %% 360
  pattern <- .vc_pattern(ca)
  structure(list(coupling_angle = ca, pattern = pattern,
                 proportions = prop.table(table(pattern))),
            class = "vector_coding")
}

#' @export
print.vector_coding <- function(x, ...) {
  cat("<vector_coding> coordination pattern proportions:\n")
  for (nm in names(x$proportions))
    cat(sprintf("  %-10s %.2f\n", nm, x$proportions[[nm]]))
  invisible(x)
}

# circular standard deviation (degrees) of a set of angles.
.circ_sd_deg <- function(deg) {
  r <- deg * pi / 180
  Rbar <- Mod(mean(exp(1i * r)))
  if (Rbar <= 0) return(NA_real_)
  sqrt(-2 * log(Rbar)) * 180 / pi
}

#' Inter-joint coordination variability across cycles
#'
#' The trial-to-trial (cycle-to-cycle) variability of the coordination measure --
#' the deviation phase for continuous relative phase (linear SD) or the coupling-
#' angle circular SD for vector coding -- computed at each point of the
#' (time-normalised) cycle. Coordination variability is a motor-control marker:
#' abnormally high or low values accompany injury and neurological disease.
#'
#' @param angle1_cycles,angle2_cycles Numeric matrices `cycles x points` (each
#'   row one time-normalised cycle) of the two joints' angles.
#' @param method `"crp"` (deviation phase, linear SD) or `"vector_coding"`
#'   (coupling-angle circular SD).
#' @return a `coordination_variability` list: `method`, `variability` (per-point),
#'   `mean_variability` and `measure` (the per-cycle coordination matrix).
#' @references Hamill (2000); Needham (2014).
#' @seealso [continuousRelativePhase()], [vectorCoding()]
#' @export
#' @examples
#' m <- matrix(sin(seq(0, 2 * pi, length.out = 50)), nrow = 5, ncol = 50,
#'             byrow = TRUE)
#' coordinationVariability(m, m)$mean_variability      # identical cycles -> 0
coordinationVariability <- function(angle1_cycles, angle2_cycles,
                                    method = c("crp", "vector_coding")) {
  method <- match.arg(method)
  a1 <- as.matrix(angle1_cycles); a2 <- as.matrix(angle2_cycles)
  if (!all(dim(a1) == dim(a2)) || nrow(a1) < 2) {
    stop("`angle1_cycles`/`angle2_cycles` must be equal-size matrices with >= 2 rows.",
         call. = FALSE)
  }
  if (method == "crp") {
    M <- t(vapply(seq_len(nrow(a1)), function(i)
      continuousRelativePhase(a1[i, ], a2[i, ])$crp, numeric(ncol(a1))))
    varp <- apply(M, 2, stats::sd)
  } else {
    M <- t(vapply(seq_len(nrow(a1)), function(i)
      vectorCoding(a1[i, ], a2[i, ])$coupling_angle, numeric(ncol(a1) - 1)))
    varp <- apply(M, 2, .circ_sd_deg)
  }
  structure(list(method = method, variability = varp,
                 mean_variability = mean(varp, na.rm = TRUE), measure = M),
            class = "coordination_variability")
}
