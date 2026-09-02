# Instrumented clinical mobility tests: the instrumented Timed Up-and-Go (iTUG;
# Salarian et al. 2010) and the instrumented 10-metre walk test (10mWT).

#' Coerce an angular-velocity input to an n x 3 numeric matrix
#' @keywords internal
#' @noRd
.mob_matrix <- function(x, what) {
  if (is.data.frame(x)) x <- as.matrix(x)
  m <- as.matrix(x)
  if (!is.numeric(m) || ncol(m) != 3L || nrow(m) < 5L) {
    stop(sprintf("`%s` must be an n x 3 numeric matrix (n >= 5).", what),
         call. = FALSE)
  }
  if (any(!is.finite(m))) {
    stop(sprintf("`%s` contains non-finite values.", what), call. = FALSE)
  }
  m
}

#' Contiguous runs where a mask is TRUE (start, end indices)
#' @keywords internal
#' @noRd
.mob_runs <- function(mask) {
  n <- length(mask)
  starts <- integer(0); ends <- integer(0)
  i <- 1L
  while (i <= n) {
    if (isTRUE(mask[i])) {
      j <- i
      while (j < n && isTRUE(mask[j + 1L])) j <- j + 1L
      starts <- c(starts, i); ends <- c(ends, j)
      i <- j + 1L
    } else {
      i <- i + 1L
    }
  }
  list(starts = starts, ends = ends)
}

#' Instrumented Timed Up-and-Go (iTUG)
#'
#' Segments a Timed Up-and-Go trial from a trunk/lumbar inertial sensor into its
#' sub-phases (sit-to-stand, walk, turn, turn-to-sit) using the angular velocity:
#' turns appear as large excursions of the vertical-axis (yaw) angular velocity,
#' and the postural sit-to-stand / turn-to-sit transitions as the trunk
#' flexion-axis (pitch) events that bracket the walking (Salarian et al. 2010).
#'
#' @param angular_velocity An n x 3 matrix of trunk angular velocity (rad/s).
#' @param sampling_rate Sampling rate in Hz.
#' @param turn_axis Column index of the vertical/yaw axis (default 3).
#' @param transition_axis Column index of the trunk flexion/pitch axis
#'   (default 2).
#' @param turn_threshold Angular-velocity threshold (rad/s) that marks a turn;
#'   `NULL` uses `0.15 * max(abs(yaw))`.
#' @param min_turn_sec Minimum turn duration in seconds (default 0.3).
#'
#' @return An `itug_report` object with `total_duration`, a `turns` data frame
#'   (`start`, `end`, `duration`, `peak_velocity`, `angle_deg`), the
#'   `stand_up_time`/`sit_down_time`, and a `phases` data frame.
#' @references Salarian A, et al. (2010). IEEE Trans Neural Syst Rehabil Eng
#'   18(3):303-310.
#' @seealso [instrumented10mWT()]
#' @export
instrumentedTUG <- function(angular_velocity, sampling_rate, turn_axis = 3L,
                            transition_axis = 2L, turn_threshold = NULL,
                            min_turn_sec = 0.3) {
  av <- .mob_matrix(angular_velocity, "angular_velocity")
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  if (length(turn_axis) != 1L || length(transition_axis) != 1L ||
      !isTRUE(turn_axis %in% 1:3) || !isTRUE(transition_axis %in% 1:3)) {
    stop("`turn_axis`/`transition_axis` must each be a single index (1, 2 or 3).",
         call. = FALSE)
  }
  n <- nrow(av)
  dt <- 1 / sampling_rate
  t_axis <- (seq_len(n) - 1) * dt
  yaw <- av[, turn_axis]
  pitch <- av[, transition_axis]

  if (is.null(turn_threshold)) {
    turn_threshold <- 0.15 * max(abs(yaw))
  }
  min_len <- max(1L, as.integer(round(min_turn_sec * sampling_rate)))

  runs <- .mob_runs(abs(yaw) > turn_threshold)
  keep <- (runs$ends - runs$starts + 1L) >= min_len
  ts <- runs$starts[keep]
  te <- runs$ends[keep]
  turns <- data.frame(
    start = t_axis[ts], end = t_axis[te],
    duration = (te - ts) * dt,
    peak_velocity = vapply(seq_along(ts), function(i) {
      max(abs(yaw[ts[i]:te[i]]))
    }, numeric(1)),
    angle_deg = vapply(seq_along(ts), function(i) {
      abs(sum(yaw[ts[i]:te[i]]) * dt) * 180 / pi
    }, numeric(1)),
    stringsAsFactors = FALSE
  )

  # postural transitions: the flexion-axis peaks before the first turn
  # (stand-up) and after the last turn (sit-down). Only meaningful when the
  # trial is segmentable; with no detected turn the two markers are undefined
  # (returning the same global pitch peak for both would be self-contradictory).
  stand_up_time <- NA_real_
  sit_down_time <- NA_real_
  if (nrow(turns) > 0L) {
    first_turn <- ts[1]
    last_turn <- te[length(te)]
    if (first_turn > 2L) {
      stand_up_time <- t_axis[which.max(abs(pitch[seq_len(first_turn - 1L)]))]
    }
    if (last_turn < n - 1L) {
      sit_down_time <- t_axis[last_turn + which.max(abs(pitch[(last_turn + 1L):n]))]
    }
  }

  # phase timeline: build segments with a running cursor so labels always stay
  # aligned to bounds, even when a postural transition is NA or a turn abuts the
  # start/end of the trial. `sit_down_time` stays a reported marker inside the
  # final phase rather than a separate bound (which would leave a trailing gap).
  t_end <- max(t_axis)
  phases <- data.frame(phase = character(0), start = numeric(0),
                       end = numeric(0), stringsAsFactors = FALSE)
  add_seg <- function(df, phase, start, end) {
    if (is.finite(start) && is.finite(end) && end > start) {
      rbind(df, data.frame(phase = phase, start = start, end = end,
                           stringsAsFactors = FALSE))
    } else {
      df
    }
  }
  cursor <- 0
  if (is.finite(stand_up_time) && stand_up_time > 0) {
    phases <- add_seg(phases, "sit_to_stand", 0, stand_up_time)
    cursor <- stand_up_time
  }
  if (nrow(turns) > 0L) {
    for (i in seq_len(nrow(turns))) {
      phases <- add_seg(phases, "walk", cursor, turns$start[i])
      phases <- add_seg(phases, "turn", turns$start[i], turns$end[i])
      cursor <- turns$end[i]
    }
  }
  phases <- add_seg(phases, if (nrow(turns) > 0L) "turn_to_sit" else "walk",
                    cursor, t_end)
  phases$duration <- phases$end - phases$start

  out <- list(
    total_duration = max(t_axis), turns = turns,
    stand_up_time = stand_up_time, sit_down_time = sit_down_time,
    phases = phases,
    signal = data.frame(time = t_axis, yaw = yaw, pitch = pitch)
  )
  class(out) <- "itug_report"
  out
}

#' First (interpolated) time a monotone signal reaches a level
#' @keywords internal
#' @noRd
.mob_cross_time <- function(position, level, times) {
  hit <- which(position >= level)
  if (length(hit) == 0L) {
    return(NA_real_)
  }
  i <- hit[1]
  if (i == 1L) {
    return(times[1])
  }
  p0 <- position[i - 1L]; p1 <- position[i]
  if (p1 == p0) {
    return(times[i])
  }
  times[i - 1L] + (level - p0) / (p1 - p0) * (times[i] - times[i - 1L])
}

#' Instrumented 10-metre walk test (10mWT)
#'
#' Extracts steady-state gait speed (and cadence) over the middle section of a
#' 10-metre walk, excluding the acceleration and deceleration zones, from the
#' forward walking distance over time (e.g. the ZUPT-integrated foot trajectory
#' from [footImuGait()] or a marker distance).
#'
#' @param position Cumulative forward distance walked (m) over time.
#' @param sampling_rate Sampling rate in Hz.
#' @param total_distance Total walkway length in m (default 10).
#' @param mid_start,mid_end Start/end of the timed steady-state section in m
#'   (defaults 2 and 8).
#' @param events Optional heel-strike sample indices or times (s) for cadence.
#' @param events_unit Unit of `events`: `"auto"` (default) guesses indices vs
#'   seconds, or force `"index"` / `"seconds"`. Pass an explicit unit when
#'   heel-strike times are whole-number seconds (which `"auto"` would otherwise
#'   read as sample indices).
#'
#' @return A `walk_test_report` object with `gait_speed` (m/s), `mid_distance`,
#'   `mid_time`, `cadence_spm` (or `NA`), and the section boundary times.
#' @references Standard 10-metre walk test protocol.
#' @seealso [instrumentedTUG()], [footImuGait()]
#' @export
instrumented10mWT <- function(position, sampling_rate, total_distance = 10,
                              mid_start = 2, mid_end = 8, events = NULL,
                              events_unit = c("auto", "index", "seconds")) {
  events_unit <- match.arg(events_unit)
  position <- as.numeric(position)
  n <- length(position)
  if (n < 5L || any(!is.finite(position))) {
    stop("`position` must be a finite numeric series of length >= 5.",
         call. = FALSE)
  }
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("`sampling_rate` must be a single positive number.", call. = FALSE)
  }
  if (!all(vapply(list(total_distance, mid_start, mid_end),
                  function(v) is.numeric(v) && length(v) == 1L && is.finite(v),
                  logical(1)))) {
    stop("`total_distance`, `mid_start`, `mid_end` must each be a single ",
         "finite number.", call. = FALSE)
  }
  if (!(mid_start >= 0 && mid_end > mid_start && mid_end <= total_distance)) {
    stop("require 0 <= mid_start < mid_end <= total_distance.", call. = FALSE)
  }
  times <- (seq_len(n) - 1) / sampling_rate

  t_start <- .mob_cross_time(position, mid_start, times)
  t_end <- .mob_cross_time(position, mid_end, times)
  if (!is.finite(t_start) || !is.finite(t_end) || t_end <= t_start) {
    stop("`position` does not span the timed mid-section [mid_start, mid_end].",
         call. = FALSE)
  }
  mid_time <- t_end - t_start
  mid_distance <- mid_end - mid_start
  gait_speed <- mid_distance / mid_time

  cadence <- NA_real_
  if (!is.null(events)) {
    events <- as.numeric(events)
    if (length(events) == 0L || any(!is.finite(events))) {
      stop("`events` must be a non-empty finite numeric vector.", call. = FALSE)
    }
    unit <- if (events_unit == "auto") {
      if (all(events == round(events)) && max(events) <= n) "index" else "seconds"
    } else {
      events_unit
    }
    ev_t <- if (unit == "index") (events - 1) / sampling_rate else events
    n_steps <- sum(ev_t >= t_start & ev_t <= t_end)
    cadence <- if (mid_time > 0) n_steps / mid_time * 60 else NA_real_
  }

  out <- list(
    gait_speed = gait_speed, mid_distance = mid_distance, mid_time = mid_time,
    cadence_spm = cadence, mid_start_time = t_start, mid_end_time = t_end,
    total_distance = total_distance
  )
  class(out) <- "walk_test_report"
  out
}

#' Plot an instrumented TUG timeline
#'
#' Plots the trunk yaw angular velocity with the detected turns shaded and the
#' sit-to-stand / turn-to-sit transitions marked.
#'
#' @param report An `itug_report` from [instrumentedTUG()].
#' @param title Plot title.
#' @return A `ggplot` object.
#' @seealso [instrumentedTUG()]
#' @export
plotTUG <- function(report, title = "Instrumented TUG") {
  if (!inherits(report, "itug_report")) {
    stop("`report` must be an itug_report object.", call. = FALSE)
  }
  sig <- report$signal
  p <- ggplot2::ggplot(sig, ggplot2::aes(x = .data$time, y = .data$yaw))
  if (nrow(report$turns) > 0L) {
    p <- p + ggplot2::geom_rect(
      data = report$turns,
      ggplot2::aes(xmin = .data$start, xmax = .data$end, ymin = -Inf,
                   ymax = Inf),
      inherit.aes = FALSE, fill = "#F58518", alpha = 0.25)
  }
  for (v in c(report$stand_up_time, report$sit_down_time)) {
    if (is.finite(v)) {
      p <- p + ggplot2::geom_vline(xintercept = v, linetype = "dashed",
                                   color = "#4C78A8")
    }
  }
  p +
    ggplot2::geom_line() +
    ggplot2::labs(x = "time (s)", y = "yaw angular velocity (rad/s)",
                  title = title) +
    ggplot2::theme_minimal()
}

#' @export
print.itug_report <- function(x, ...) {
  cat(sprintf("<itug_report> total duration %.2f s, %d turn(s)\n",
              x$total_duration, nrow(x$turns)))
  if (nrow(x$turns) > 0L) {
    for (i in seq_len(nrow(x$turns))) {
      cat(sprintf("  turn %d: %.2f-%.2f s (%.2f s, peak %.2f rad/s, %.0f deg)\n",
                  i, x$turns$start[i], x$turns$end[i], x$turns$duration[i],
                  x$turns$peak_velocity[i], x$turns$angle_deg[i]))
    }
  }
  cat(sprintf("  stand-up %.2f s, sit-down %.2f s\n",
              x$stand_up_time, x$sit_down_time))
  invisible(x)
}

#' @export
print.walk_test_report <- function(x, ...) {
  cat("<walk_test_report>\n")
  cat(sprintf("  gait speed: %.3f m/s over %.1f m (%.2f s)\n",
              x$gait_speed, x$mid_distance, x$mid_time))
  if (!is.na(x$cadence_spm)) {
    cat(sprintf("  cadence: %.1f steps/min\n", x$cadence_spm))
  }
  invisible(x)
}
