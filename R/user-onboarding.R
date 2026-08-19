# Beginner-friendly onboarding helpers.
# Includes synthetic data, auto-import, readiness checks, and quick workflows.

.is_positive_scalar <- function(x) {
  is.numeric(x) && length(x) == 1 && is.finite(x) && x > 0
}

.append_note <- function(notes, msg) {
  if (msg %in% notes) {
    notes
  } else {
    c(notes, msg)
  }
}


#' Create a beginner-friendly demo dataset
#'
#' Generates synthetic motion capture, force, and EMG data so first-time users
#' can run package workflows without external files.
#'
#' @param n_frames Number of MoCap frames to generate.
#' @param sampling_rate MoCap sampling rate in Hz.
#' @param n_markers Number of markers in the synthetic marker set.
#' @param emg_sampling_rate EMG sampling rate in Hz.
#' @param seed Optional random seed for reproducibility. Set to `NULL` to skip
#'   setting a seed.
#'
#' @return A named list with:
#' \describe{
#'   \item{mocap}{A `PhysioExperiment` with `position_x`, `position_y`,
#'     `position_z` assays.}
#'   \item{grf}{Numeric vector of synthetic vertical GRF.}
#'   \item{forces}{Matrix with `force_x`, `force_y`, `force_z` columns.}
#'   \item{joints}{Data frame with 2D joint-center coordinates for ankle,
#'     knee, and hip.}
#'   \item{joint_angles}{Data frame with ankle/knee/hip joint angles
#'     (radians).}
#'   \item{emg}{Matrix of synthetic EMG channels.}
#'   \item{sampling_rate}{MoCap sampling rate (Hz).}
#'   \item{emg_sampling_rate}{EMG sampling rate (Hz).}
#' }
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [quickStartMoCap()] for a complete getting-started workflow,
#'   [assessMoCapReadiness()] for data quality assessment.
#'
#' @export
#'
#' @examples
#' demo <- demoMoCapData(seed = 1)
#' demo$mocap
#' head(demo$joints)
demoMoCapData <- function(n_frames = 300,
                          sampling_rate = 120,
                          n_markers = 8,
                          emg_sampling_rate = 1000,
                          seed = 123) {

  if (!is.numeric(n_frames) || length(n_frames) != 1 || n_frames < 50) {
    stop("'n_frames' must be a numeric scalar >= 50.", call. = FALSE)
  }
  if (!.is_positive_scalar(sampling_rate)) {
    stop("'sampling_rate' must be a positive numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(n_markers) || length(n_markers) != 1 || n_markers < 3) {
    stop("'n_markers' must be a numeric scalar >= 3.", call. = FALSE)
  }
  if (!.is_positive_scalar(emg_sampling_rate)) {
    stop("'emg_sampling_rate' must be a positive numeric scalar.", call. = FALSE)
  }

  n_frames <- as.integer(round(n_frames))
  n_markers <- as.integer(round(n_markers))

  if (!is.null(seed)) {
    set.seed(seed)
  }

  t <- seq(0, (n_frames - 1) / sampling_rate, length.out = n_frames)
  gait_phase <- (t * 1.2) %% 1

  base_names <- c(
    "Pelvis_R", "Pelvis_L", "Knee_R", "Knee_L",
    "Ankle_R", "Ankle_L", "Toe_R", "Toe_L"
  )
  if (n_markers <= length(base_names)) {
    marker_names <- base_names[seq_len(n_markers)]
  } else {
    extra <- paste0("Marker", seq_len(n_markers - length(base_names)))
    marker_names <- c(base_names, extra)
  }

  # Mildly gait-like synthetic marker trajectories.
  pos_x <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_y <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)
  pos_z <- matrix(NA_real_, nrow = n_frames, ncol = n_markers)

  for (j in seq_len(n_markers)) {
    phase_shift <- (j - 1) * 0.22
    side_offset <- if (j %% 2 == 0) -0.08 else 0.08

    pos_x[, j] <- side_offset + 0.02 * sin(2 * pi * (gait_phase + phase_shift)) +
      stats::rnorm(n_frames, sd = 0.002)

    pos_y[, j] <- 0.5 * t + 0.03 * cos(2 * pi * (gait_phase + phase_shift)) +
      stats::rnorm(n_frames, sd = 0.002)

    pos_z[, j] <- 1.0 + 0.04 * sin(2 * pi * (gait_phase + phase_shift))^2 +
      stats::rnorm(n_frames, sd = 0.002)
  }

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  mocap <- PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", n_markers)
    ),
    metadata = list(source = "demoMoCapData"),
    samplingRate = sampling_rate
  )

  grf <- ifelse(
    gait_phase < 0.62,
    sin(pi * gait_phase / 0.62) * 900,
    0
  ) + stats::rnorm(n_frames, sd = 8)
  grf <- pmax(grf, 0)

  forces <- cbind(
    force_x = 10 * sin(2 * pi * gait_phase) + stats::rnorm(n_frames, sd = 1.5),
    force_y = 4 * cos(2 * pi * gait_phase) + stats::rnorm(n_frames, sd = 1.0),
    force_z = grf
  )

  joints <- data.frame(
    ankle_x = 0.02 * sin(2 * pi * gait_phase),
    ankle_y = 0.05 + 0.01 * cos(2 * pi * gait_phase),
    knee_x = 0.01 * sin(2 * pi * gait_phase + 0.2),
    knee_y = 0.45 + 0.02 * cos(2 * pi * gait_phase + 0.2),
    hip_x = 0.005 * sin(2 * pi * gait_phase + 0.4),
    hip_y = 0.85 + 0.01 * cos(2 * pi * gait_phase + 0.4)
  )
  # The foot distal end locates the foot centre of mass, which the Newton-Euler
  # inverse-dynamics chain needs.
  joints$toe_x <- joints$ankle_x + 0.15
  joints$toe_y <- pmax(0, joints$ankle_y - 0.04)

  joint_angles <- data.frame(
    ankle = 0.20 * sin(2 * pi * gait_phase + 0.3),
    knee = 0.55 * sin(2 * pi * gait_phase + 0.8),
    hip = 0.40 * sin(2 * pi * gait_phase + 1.2)
  )

  n_emg <- as.integer(round(n_frames * emg_sampling_rate / sampling_rate))
  t_emg <- seq(0, (n_emg - 1) / emg_sampling_rate, length.out = n_emg)
  emg_phase <- (t_emg * 1.2) %% 1

  emg <- cbind(
    tibialis_anterior = 0.12 * stats::rnorm(n_emg) +
      0.5 * as.numeric(emg_phase > 0.55 & emg_phase < 0.85),
    gastrocnemius = 0.12 * stats::rnorm(n_emg) +
      0.6 * as.numeric(emg_phase > 0.05 & emg_phase < 0.35),
    rectus_femoris = 0.10 * stats::rnorm(n_emg) +
      0.4 * as.numeric(emg_phase > 0.15 & emg_phase < 0.40),
    biceps_femoris = 0.10 * stats::rnorm(n_emg) +
      0.4 * as.numeric(emg_phase > 0.45 & emg_phase < 0.75)
  )

  list(
    mocap = mocap,
    grf = as.numeric(grf),
    forces = forces,
    joints = joints,
    joint_angles = joint_angles,
    emg = emg,
    sampling_rate = sampling_rate,
    emg_sampling_rate = emg_sampling_rate
  )
}


#' Read motion-capture files with automatic format detection
#'
#' Chooses a reader based on file extension and returns a `PhysioExperiment`.
#' This is designed for first-time users who want one entry point for common
#' MoCap formats.
#'
#' @param path Path to a motion-capture file.
#' @param format Reader format. `"auto"` detects from extension (`.c3d`,
#'   `.trc`, `.csv`, `.tsv`, `.bvh`, `.amc`).
#' @param sampling_rate Sampling rate for CSV files when not inferable.
#' @param sep Delimiter used for CSV/TSV files.
#' @param header_rows Number of header rows for CSV/TSV.
#' @param skip Number of lines to skip before data for CSV/TSV.
#' @param include_analog Logical; passed to [readC3D()].
#' @param asf Optional ASF skeleton for AMC files. Either an `ASFSkeleton`
#'   object or a path to an `.asf` file.
#' @param fps Frame rate for AMC files.
#'
#' @return A `PhysioExperiment` object.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [readMoCapCSV()] for CSV/TSV motion capture data,
#'   [readASF()] and [readAMC()] for Acclaim skeleton and motion files,
#'   [assessMoCapReadiness()] for data quality assessment.
#'
#' @export
#'
#' @examples
#' trc_file <- system.file("testdata", "sample.trc", package = "PhysioMoCap")
#' if (nzchar(trc_file)) {
#'   pe <- readMoCapAuto(trc_file)
#'   pe
#' }
readMoCapAuto <- function(path,
                          format = c("auto", "csv", "c3d", "trc", "bvh", "amc"),
                          sampling_rate = NULL,
                          sep = ",",
                          header_rows = 1L,
                          skip = 0L,
                          include_analog = FALSE,
                          asf = NULL,
                          fps = 120) {
  format <- match.arg(format)

  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("File not found: ", path, call. = FALSE)
  }
  if (!is.null(sampling_rate) && !.is_positive_scalar(sampling_rate)) {
    stop("'sampling_rate' must be NULL or a positive numeric scalar.",
         call. = FALSE)
  }
  if (!is.logical(include_analog) || length(include_analog) != 1) {
    stop("'include_analog' must be TRUE or FALSE.", call. = FALSE)
  }
  if (!.is_positive_scalar(fps)) {
    stop("'fps' must be a positive numeric scalar.", call. = FALSE)
  }

  if (format == "auto") {
    ext <- tolower(tools::file_ext(path))
    format <- switch(
      ext,
      c3d = "c3d",
      trc = "trc",
      csv = "csv",
      tsv = "csv",
      txt = "csv",
      bvh = "bvh",
      amc = "amc",
      ""
    )
    if (!nzchar(format)) {
      stop(
        "Could not auto-detect file format from extension '.", ext, "'.\n",
        "Supported: .c3d, .trc, .csv, .tsv, .bvh, .amc.\n",
        "Use 'format = ...' to set it manually.",
        call. = FALSE
      )
    }
  }

  if (format == "csv") {
    # Check for Venus3D format first
    first_line <- readLines(path, n = 1, warn = FALSE)
    if (grepl("^#Venus3D", first_line, ignore.case = TRUE)) {
      return(readVenus3D(path))
    }

    ext <- tolower(tools::file_ext(path))
    if (ext == "tsv" && identical(sep, ",")) {
      sep <- "\t"
    }
    csv_formats <- c("auto", "xyz", "wide", "long", "qualisys", "vicon")
    last_error <- NULL

    for (fmt in csv_formats) {
      parsed <- tryCatch(
        readMoCapCSV(
          path = path,
          format = fmt,
          sampling_rate = sampling_rate,
          header_rows = header_rows,
          skip = skip,
          sep = sep
        ),
        error = function(e) {
          last_error <<- e
          NULL
        }
      )
      if (!is.null(parsed)) {
        return(parsed)
      }
    }

    stop(
      "Could not parse CSV/TSV with readMoCapAuto().\n",
      "Last parser message: ", conditionMessage(last_error), "\n",
      "Try readMoCapCSV(path, format = 'xyz' or 'wide', sampling_rate = ...).",
      call. = FALSE
    )
  }

  if (format == "c3d") {
    return(readC3D(path = path, include_analog = include_analog))
  }

  if (format == "trc") {
    return(readTRC(path = path))
  }

  if (format == "bvh") {
    return(readBVH(path = path))
  }

  if (format == "amc") {
    asf_obj <- asf
    if (is.character(asf_obj) && length(asf_obj) == 1 && nzchar(asf_obj)) {
      if (!file.exists(asf_obj)) {
        stop("ASF file not found: ", asf_obj, call. = FALSE)
      }
      asf_obj <- readASF(asf_obj)
    }
    if (!is.null(asf_obj) && !inherits(asf_obj, "ASFSkeleton")) {
      stop("'asf' must be NULL, an ASFSkeleton object, or a path to an .asf file.",
           call. = FALSE)
    }
    return(readAMC(path = path, asf = asf_obj, fps = fps))
  }

  stop("Unsupported format: ", format, call. = FALSE)
}


#' Assess readiness of a MoCap dataset for downstream analysis
#'
#' Performs a compact quality and metadata checklist so beginners can quickly
#' identify missing requirements before running kinematics or kinetics.
#'
#' @param pe A `PhysioExperiment` object.
#' @param required_assays Character vector of required assay names.
#' @param min_frames Minimum recommended number of frames.
#' @param min_markers Minimum recommended number of markers/channels.
#' @param min_sampling_rate Minimum recommended sampling rate (Hz).
#' @param max_missing_rate Maximum allowed missing-value rate per required assay.
#'
#' @return An S3 object of class `"mocap_readiness"` with score, grade, checks,
#'   and summary metrics.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [print.mocap_readiness()] for formatted display of readiness results,
#'   [quickStartMoCap()] for complete getting-started workflow,
#'   [demoMoCapData()] for generating demo data.
#'
#' @export
#'
#' @examples
#' demo <- demoMoCapData(seed = 1)
#' report <- assessMoCapReadiness(demo$mocap)
#' report
assessMoCapReadiness <- function(
    pe,
    required_assays = c("position_x", "position_y", "position_z"),
    min_frames = 100,
    min_markers = 5,
    min_sampling_rate = 50,
    max_missing_rate = 0.05
) {
  if (!inherits(pe, "PhysioExperiment")) {
    stop("'pe' must be a PhysioExperiment.", call. = FALSE)
  }
  if (!is.character(required_assays) || length(required_assays) == 0) {
    stop("'required_assays' must be a non-empty character vector.", call. = FALSE)
  }
  if (!.is_positive_scalar(min_frames) || !.is_positive_scalar(min_markers) ||
      !.is_positive_scalar(min_sampling_rate)) {
    stop("'min_frames', 'min_markers', and 'min_sampling_rate' must be positive numerics.",
         call. = FALSE)
  }
  if (!is.numeric(max_missing_rate) || length(max_missing_rate) != 1 ||
      !is.finite(max_missing_rate) || max_missing_rate < 0 || max_missing_rate > 1) {
    stop("'max_missing_rate' must be a numeric scalar between 0 and 1.",
         call. = FALSE)
  }

  checks <- data.frame(
    category = character(0),
    check = character(0),
    pass = logical(0),
    value = character(0),
    recommendation = character(0),
    stringsAsFactors = FALSE
  )

  add_check <- function(category, check, pass, value, recommendation) {
    checks <<- rbind(
      checks,
      data.frame(
        category = category,
        check = check,
        pass = isTRUE(pass),
        value = as.character(value),
        recommendation = recommendation,
        stringsAsFactors = FALSE
      )
    )
  }

  assay_names <- SummarizedExperiment::assayNames(pe)
  missing_assays <- setdiff(required_assays, assay_names)
  add_check(
    "Structure",
    "Required assays present",
    length(missing_assays) == 0,
    if (length(missing_assays) == 0) {
      paste(required_assays, collapse = ", ")
    } else {
      paste("Missing:", paste(missing_assays, collapse = ", "))
    },
    "Use readers or preprocessing so required assays exist (e.g. position_x/y/z)."
  )

  if (length(assay_names) > 0) {
    ref <- SummarizedExperiment::assay(pe, assay_names[1])
    n_frames <- nrow(ref)
    n_markers <- ncol(ref)
  } else {
    n_frames <- 0L
    n_markers <- 0L
  }

  add_check(
    "Coverage",
    "Enough frames",
    n_frames >= min_frames,
    sprintf("%d (target >= %d)", n_frames, as.integer(round(min_frames))),
    "Use a longer recording or merge repeated trials."
  )
  add_check(
    "Coverage",
    "Enough markers/channels",
    n_markers >= min_markers,
    sprintf("%d (target >= %d)", n_markers, as.integer(round(min_markers))),
    "Ensure all tracked markers are exported and not dropped during import."
  )

  sr <- samplingRate(pe)
  sr_available <- .is_positive_scalar(sr)
  add_check(
    "Metadata",
    "Sampling rate available",
    sr_available,
    if (sr_available) sprintf("%.3f Hz", sr) else "missing/invalid",
    "Set a positive samplingRate on the PhysioExperiment object."
  )
  if (sr_available) {
    add_check(
      "Metadata",
      "Sampling rate plausible",
      sr >= min_sampling_rate,
      sprintf("%.3f Hz (target >= %.1f)", sr, min_sampling_rate),
      "Set the true recording rate or resample data before derivative analyses."
    )
  }

  if (length(missing_assays) == 0) {
    miss_rates <- vapply(required_assays, function(aname) {
      m <- SummarizedExperiment::assay(pe, aname)
      mean(is.na(m) | !is.finite(m))
    }, numeric(1))
    worst_miss <- max(miss_rates)

    add_check(
      "Signal quality",
      "Missing-value rate",
      worst_miss <= max_missing_rate,
      sprintf("worst %.2f%% (target <= %.2f%%)",
              100 * worst_miss, 100 * max_missing_rate),
      "Use fillGaps(), fillGapsSpline(), or improve marker tracking quality."
    )
  } else {
    add_check(
      "Signal quality",
      "Missing-value rate",
      FALSE,
      "not checked (required assays missing)",
      "Add required assays first, then rerun readiness assessment."
    )
  }

  cd <- as.data.frame(SummarizedExperiment::colData(pe), stringsAsFactors = FALSE)
  has_label <- "label" %in% colnames(cd)
  add_check(
    "Metadata",
    "Marker labels in colData",
    has_label,
    if (has_label) sprintf("%d labels", nrow(cd)) else "missing",
    "Set colData(pe)$label so downstream skeleton/event logic can map channels."
  )
  if (has_label) {
    unique_labels <- length(unique(as.character(cd$label)))
    add_check(
      "Metadata",
      "Unique marker labels",
      unique_labels == n_markers,
      sprintf("%d unique / %d markers", unique_labels, n_markers),
      "Rename duplicated marker labels before analysis."
    )
  }

  score <- as.integer(round(100 * mean(checks$pass)))
  grade <- if (score >= 95) {
    "A+"
  } else if (score >= 90) {
    "A"
  } else if (score >= 80) {
    "B"
  } else if (score >= 70) {
    "C"
  } else {
    "D"
  }

  out <- list(
    score = score,
    grade = grade,
    checks = checks,
    metrics = list(
      n_frames = n_frames,
      n_markers = n_markers,
      sampling_rate = sr,
      required_assays = required_assays
    )
  )
  class(out) <- c("mocap_readiness", "list")
  out
}


#' Print a MoCap readiness report
#'
#' @param x A `mocap_readiness` object from `assessMoCapReadiness()`.
#' @param ... Additional arguments (unused).
#' @return Invisibly returns `x`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [assessMoCapReadiness()] for computing the readiness report.
#'
#' @export
print.mocap_readiness <- function(x, ...) {
  cat("MoCap Readiness Report\n")
  cat("  Score:", x$score, "% (", x$grade, ")\n", sep = "")
  cat("  Frames:", x$metrics$n_frames, "\n")
  cat("  Markers:", x$metrics$n_markers, "\n")

  passed <- sum(x$checks$pass)
  total <- nrow(x$checks)
  cat("  Checks:", passed, "/", total, "passed\n")

  failed <- x$checks[!x$checks$pass, , drop = FALSE]
  if (nrow(failed) > 0) {
    cat("\nAction items:\n")
    for (i in seq_len(nrow(failed))) {
      cat("  -", failed$check[i], "->", failed$recommendation[i], "\n")
    }
  }

  invisible(x)
}


#' Run a one-command beginner workflow
#'
#' Runs a compact end-to-end pipeline for first-time users:
#' kinematics derivatives, readiness scoring, and optional force-plate,
#' inverse-dynamics, and EMG modules.
#'
#' If `mocap` or `path` is omitted, synthetic demo data are generated.
#'
#' @param n_frames Number of MoCap frames for demo mode.
#' @param sampling_rate MoCap sampling rate in Hz. In non-demo mode, if `NULL`,
#'   uses `samplingRate(mocap)`.
#' @param emg_sampling_rate EMG sampling rate in Hz.
#' @param seed Random seed for reproducibility in demo mode.
#' @param mocap Optional `PhysioExperiment` object to analyze.
#' @param path Optional file path to load via `readMoCapAuto()`.
#' @param format Format hint passed to `readMoCapAuto()` when `path` is used.
#' @param forces Optional force matrix/data.frame for force-plate analysis.
#' @param joints Optional joint-center data for inverse dynamics.
#' @param joint_angles Optional joint-angle data for inverse dynamics.
#' @param emg Optional EMG matrix for EMG processing.
#'
#' @return An object of class `"mocap_quickstart"` containing generated outputs,
#'   readiness report, and notes for skipped/failed optional modules.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [demoMoCapData()] for generating demo data without analysis,
#'   [assessMoCapReadiness()] for data quality assessment,
#'   [print.mocap_quickstart()] for formatted display of results.
#'
#' @export
#'
#' @examples
#' qs <- quickStartMoCap(seed = 1)
#' qs
quickStartMoCap <- function(n_frames = 300,
                            sampling_rate = NULL,
                            emg_sampling_rate = 1000,
                            seed = 123,
                            mocap = NULL,
                            path = NULL,
                            format = c("auto", "csv", "c3d", "trc", "bvh", "amc"),
                            forces = NULL,
                            joints = NULL,
                            joint_angles = NULL,
                            emg = NULL) {
  format <- match.arg(format)

  if (!is.null(path) && !is.null(mocap)) {
    stop("Provide either 'path' or 'mocap', not both.", call. = FALSE)
  }

  notes <- character()
  data_source <- "demo"

  if (is.null(path) && is.null(mocap)) {
    demo_sampling_rate <- if (is.null(sampling_rate)) 120 else sampling_rate
    demo_emg_sampling_rate <- if (is.null(emg_sampling_rate)) 1000 else emg_sampling_rate

    demo <- demoMoCapData(
      n_frames = n_frames,
      sampling_rate = demo_sampling_rate,
      emg_sampling_rate = demo_emg_sampling_rate,
      seed = seed
    )

    mocap_data <- demo$mocap
    sr <- demo$sampling_rate
    emg_sr <- demo$emg_sampling_rate

    if (is.null(forces)) {
      forces <- demo$forces
    }
    if (is.null(joints)) {
      joints <- demo$joints
    }
    if (is.null(joint_angles)) {
      joint_angles <- demo$joint_angles
    }
    if (is.null(emg)) {
      emg <- demo$emg
    }
  } else {
    if (!is.null(path)) {
      mocap_data <- readMoCapAuto(
        path = path,
        format = format,
        sampling_rate = sampling_rate
      )
      data_source <- paste0("file:", basename(path))
    } else {
      if (!inherits(mocap, "PhysioExperiment")) {
        stop("'mocap' must be a PhysioExperiment.", call. = FALSE)
      }
      mocap_data <- mocap
      data_source <- "object"
    }

    sr <- sampling_rate
    if (is.null(sr)) {
      sr <- samplingRate(mocap_data)
    }
    if (!.is_positive_scalar(sr)) {
      stop(
        "A valid sampling rate is required.\n",
        "Set 'sampling_rate' explicitly, or provide a PhysioExperiment with ",
        "a valid samplingRate.",
        call. = FALSE
      )
    }

    emg_sr <- emg_sampling_rate

    if (is.null(forces)) {
      notes <- .append_note(
        notes,
        "Skipped force-plate module: provide 'forces' (Nx3 matrix/data.frame)."
      )
    }
    if (is.null(joints) || is.null(joint_angles)) {
      notes <- .append_note(
        notes,
        "Skipped inverse dynamics: provide both 'joints' and 'joint_angles'."
      )
    }
    if (is.null(emg)) {
      notes <- .append_note(
        notes,
        "Skipped EMG module: provide 'emg' and 'emg_sampling_rate'."
      )
    }
  }

  readiness <- assessMoCapReadiness(mocap_data)

  assay_names <- SummarizedExperiment::assayNames(mocap_data)
  has_position <- all(c("position_x", "position_y", "position_z") %in% assay_names)

  pe_vel <- NULL
  pe_acc <- NULL
  if (has_position) {
    pe_vel <- computeVelocity(mocap_data, sampling_rate = sr)
    pe_acc <- computeAcceleration(pe_vel, sampling_rate = sr)
  } else {
    notes <- .append_note(
      notes,
      "Skipped kinematics derivatives: required assays position_x/y/z are missing."
    )
  }

  fp <- NULL
  if (!is.null(forces)) {
    fp <- tryCatch(
      analyzeForcePlate(
        forces = forces,
        sampling_rate = sr,
        cutoff = 20,
        threshold = 20,
        filter_method = "moving_average"
      ),
      error = function(e) {
        notes <<- .append_note(notes, paste0(
          "Force-plate module failed: ", conditionMessage(e)
        ))
        NULL
      }
    )
  }

  id_out <- NULL
  if (!is.null(fp) && !is.null(joints) && !is.null(joint_angles)) {
    id_out <- tryCatch(
      {
        inertial <- estimateSegmentInertia(
          body_mass = 70,
          segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
        )

        inverseDynamics2D(
          joints = joints,
          grf = data.frame(
            fx = fp$filtered_forces$force_x,
            fy = fp$filtered_forces$force_z,
            cop_x = rep(0, nrow(joints)),
            cop_y = rep(0, nrow(joints))
          ),
          sampling_rate = sr,
          angles = joint_angles,
          inertial = inertial
        )
      },
      error = function(e) {
        notes <<- .append_note(notes, paste0(
          "Inverse dynamics module failed: ", conditionMessage(e)
        ))
        NULL
      }
    )
  } else if (!is.null(joints) || !is.null(joint_angles)) {
    notes <- .append_note(
      notes,
      "Inverse dynamics not run: requires force-plate output plus both 'joints' and 'joint_angles'."
    )
  }

  emg_proc <- NULL
  emg_aligned <- NULL
  if (!is.null(emg)) {
    if (!.is_positive_scalar(emg_sr)) {
      stop("'emg_sampling_rate' must be a positive numeric scalar when 'emg' is provided.",
           call. = FALSE)
    }

    emg_proc <- tryCatch(
      processEMG(
        x = emg,
        sampling_rate = emg_sr,
        filter_method = "moving_average"
      ),
      error = function(e) {
        notes <<- .append_note(notes, paste0(
          "EMG processing failed: ", conditionMessage(e)
        ))
        NULL
      }
    )

    if (!is.null(emg_proc) && !is.null(emg_proc$envelope)) {
      mocap_length <- if (has_position) {
        nrow(SummarizedExperiment::assay(mocap_data, "position_x"))
      } else if (!is.null(joints)) {
        nrow(joints)
      } else {
        NULL
      }

      if (is.null(mocap_length)) {
        notes <- .append_note(
          notes,
          "EMG alignment skipped: could not determine MoCap timeline length."
        )
      } else {
        emg_aligned <- tryCatch(
          alignEMGtoMoCap(
            emg = emg_proc$envelope,
            emg_sampling_rate = emg_sr,
            mocap_length = mocap_length,
            mocap_sampling_rate = sr
          ),
          error = function(e) {
            notes <<- .append_note(notes, paste0(
              "EMG alignment failed: ", conditionMessage(e)
            ))
            NULL
          }
        )
      }
    }
  }

  data_bundle <- list(
    mocap = mocap_data,
    forces = forces,
    joints = joints,
    joint_angles = joint_angles,
    emg = emg,
    sampling_rate = sr,
    emg_sampling_rate = emg_sr
  )

  out <- list(
    source = data_source,
    data = data_bundle,
    readiness = readiness,
    velocity = pe_vel,
    acceleration = pe_acc,
    forceplate = fp,
    inverse_dynamics = id_out,
    emg = list(
      processed = emg_proc,
      aligned = emg_aligned
    ),
    notes = notes
  )

  class(out) <- c("mocap_quickstart", "list")
  out
}


#' Print a quick-start summary
#'
#' @param x A `mocap_quickstart` object.
#' @param ... Additional arguments (unused).
#' @return Invisibly returns `x`.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. John Wiley & Sons.
#'
#' @seealso [quickStartMoCap()] for the complete getting-started workflow.
#'
#' @export
print.mocap_quickstart <- function(x, ...) {
  assays <- SummarizedExperiment::assayNames(x$data$mocap)
  marker_count <- NA_integer_
  frame_count <- NA_integer_
  if ("position_x" %in% assays) {
    px <- SummarizedExperiment::assay(x$data$mocap, "position_x")
    frame_count <- nrow(px)
    marker_count <- ncol(px)
  } else if (length(assays) > 0) {
    ref <- SummarizedExperiment::assay(x$data$mocap, assays[1])
    frame_count <- nrow(ref)
    marker_count <- ncol(ref)
  }

  cat("PhysioMoCap Quick Start\n")
  cat("  Source:", x$source, "\n")
  cat("  Frames:", frame_count, "\n")
  cat("  Markers:", marker_count, "\n")
  cat("  Sampling rate:", sprintf("%.3f", x$data$sampling_rate), "Hz\n")
  if (!is.null(x$readiness)) {
    cat("  Readiness:", x$readiness$score, "% (", x$readiness$grade, ")\n",
        sep = "")
  }

  cat("\nGenerated outputs:\n")
  cat("  - velocity / acceleration:", !is.null(x$velocity), "\n")
  cat("  - forceplate summary:", !is.null(x$forceplate), "\n")
  cat("  - inverse dynamics:", !is.null(x$inverse_dynamics), "\n")
  cat("  - EMG processed/aligned:",
      !is.null(x$emg$processed), "/", !is.null(x$emg$aligned), "\n")

  if (length(x$notes) > 0) {
    cat("\nNotes:\n")
    for (note in x$notes) {
      cat("  -", note, "\n")
    }
  }

  cat("\nNext steps:\n")
  cat("  1) Check readiness details: x$readiness\n")
  cat("  2) View force summary: x$forceplate$summary\n")
  cat("  3) Start from your own file: quickStartMoCap(path = 'trial.c3d')\n")

  invisible(x)
}
