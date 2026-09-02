# OpenSim Integration Functions
# Integration between signalIO OpenSim file I/O and PhysioAnalysis workflows

# 'signalIO' is an optional external OpenSim file-I/O provider. It is not on
# CRAN/Bioconductor/r-universe, so it cannot be declared in Suggests without
# breaking dependency resolution for installers. Reference it via this
# indirection so R CMD check does not treat it as an undeclared dependency;
# when it is absent, callers fall back to PhysioOpenSim or raise an error.
.opensim_io_pkg <- "signalIO"

#' Create a TaskSchema from OpenSim model for gait analysis
#'
#' Generates a TaskSchema based on an OpenSim model's markers and available
#' signal channels. This function creates appropriate event definitions that
#' can be used with \code{detectEvents()} for automatic event detection.
#'
#' @param model One of:
#'   \itemize{
#'     \item an OpenSim model object from signalIO's \code{read_osim()},
#'     \item a path to an \code{.osim} model file, or
#'     \item a model summary list from \code{PhysioOpenSim::opensimModelSummary()}.
#'   }
#' @param task_type Type of movement task: "gait", "running", "jump", "generic"
#' @param available_signals Character vector of signal names available in the data
#'   (e.g., from IK, ID, or GRF data)
#' @param side Character, which side to base events on: "right", "left", or "both"
#'
#' @return A TaskSchema object configured for the specified task type
#'
#' @details
#' This function analyzes the model's markers and the available signals to

#' generate an appropriate TaskSchema. For gait analysis, it prefers GRF-based
#' detection if available, falling back to marker-based or kinematic detection.
#'
#' @examples
#' \dontrun{
#' library(signalIO)
#'
#' # Load OpenSim model
#' model <- read_osim("gait2354.osim")
#'
#' # Load IK results
#' ik <- read_mot("ik_results.mot")
#' ik_channels <- rownames(ik)
#'
#' # Create gait schema with available channels
#' schema <- create_schema_from_opensim(model, "gait", ik_channels)
#' print(schema)
#'
#' # Use schema for event detection
#' events <- detectEvents(data, schema)
#' }
#'
#' @references
#' Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
#' Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
#' Dynamic Simulations of Movement." IEEE Transactions on Biomedical
#' Engineering, 54(11), 1940-1950.
#'
#' @seealso [batch_analyze_opensim()] for batch processing of OpenSim sessions,
#'   [detectEvents()] for event detection using task schemas.
#'
#' @export
create_schema_from_opensim <- function(model, task_type = c("gait", "running", "jump", "generic"),
                                       available_signals = NULL, side = "right") {
  task_type <- match.arg(task_type)
  model_info <- .resolve_opensim_model_input(model)

  # Determine side prefix
  side_prefix <- switch(side,
    right = c("r_", "R_", "_r", "_R", "right_", "Right_"),
    left = c("l_", "L_", "_l", "_L", "left_", "Left_"),
    both = c("")
  )

  # Get available marker names from model
  model_markers <- model_info$marker_names

  # Check for GRF availability in signals
  has_grf <- !is.null(available_signals) &&
    any(grepl("(?i)(vgrf|ground_force|grf|fy)", available_signals))

  # Check for specific markers
  has_heel_marker <- any(vapply(model_markers, function(m) {
    any(vapply(side_prefix, function(p) grepl(paste0(p, ".*heel|calcn"), m, ignore.case = TRUE), logical(1)))
  }, logical(1)))

  has_toe_marker <- any(vapply(model_markers, function(m) {
    any(vapply(side_prefix, function(p) grepl(paste0(p, ".*toe|mt"), m, ignore.case = TRUE), logical(1)))
  }, logical(1)))

  # Check for kinematic channels
  has_kinematics <- !is.null(available_signals) &&
    any(grepl("(?i)(knee|hip|ankle).*angle", available_signals))

  # When only summary metadata is available, marker-based heuristics cannot be used.
  if (isTRUE(model_info$marker_summary_only) &&
      task_type == "gait" &&
      !has_grf &&
      !has_kinematics) {
    warning(
      "Marker names are unavailable from summary-only OpenSim input. ",
      "Provide GRF/kinematic signals or a full model object for richer event heuristics.",
      call. = FALSE
    )
  }

  # Build appropriate schema based on task type and available data
  if (task_type == "gait") {
    schema <- .create_gait_schema_opensim(
      has_grf = has_grf,
      has_heel_marker = has_heel_marker,
      has_toe_marker = has_toe_marker,
      has_kinematics = has_kinematics,
      available_signals = available_signals,
      side = side
    )
  } else if (task_type == "running") {
    schema <- .create_running_schema_opensim(
      has_grf = has_grf,
      has_kinematics = has_kinematics,
      available_signals = available_signals,
      side = side
    )
  } else if (task_type == "jump") {
    schema <- .create_jump_schema_opensim(
      has_grf = has_grf,
      has_kinematics = has_kinematics,
      available_signals = available_signals
    )
  } else {
    # Generic schema with minimal events
    schema <- TaskSchema(
      task_type = "generic",
      task_label = "Generic Movement",
      events = list(
        Event("start", "Start", "manual", list(), typical_timing = 0),
        Event("end", "End", "manual", list(), typical_timing = 100)
      ),
      phases = list(
        Phase("main", "Main Phase", "start", "end")
      ),
      normalization = "cycle"
    )
  }

  schema
}

#' Resolve OpenSim model input into marker metadata
#' @keywords internal
.resolve_opensim_model_input <- function(model) {
  if (is.character(model)) {
    if (length(model) != 1L || is.na(model) || !nzchar(model)) {
      stop("`model` path must be a non-empty character scalar.", call. = FALSE)
    }

    model_path <- normalizePath(model, winslash = "/", mustWork = FALSE)
    if (!file.exists(model_path)) {
      stop("OpenSim model file does not exist: ", model_path, call. = FALSE)
    }

    if (requireNamespace(.opensim_io_pkg, quietly = TRUE) &&
        exists("read_osim", envir = asNamespace(.opensim_io_pkg), mode = "function", inherits = FALSE)) {
      read_osim <- get("read_osim", envir = asNamespace(.opensim_io_pkg), mode = "function", inherits = FALSE)
      return(.resolve_opensim_model_input(read_osim(model_path)))
    }

    if (requireNamespace("PhysioOpenSim", quietly = TRUE)) {
      if (!isTRUE(PhysioOpenSim::opensimAvailable())) {
        stop(
          "Package 'PhysioOpenSim' is installed but OpenSim support is unavailable. ",
          "Install OpenSim and rebuild PhysioOpenSim, or use signalIO::read_osim().",
          call. = FALSE
        )
      }

      summary <- PhysioOpenSim::opensimModelSummary(model_path)
      return(list(
        marker_names = character(),
        marker_summary_only = TRUE,
        model_summary = summary
      ))
    }

    stop(
      "No OpenSim model loader available for character path input. ",
      "Install 'signalIO' (read_osim) or 'PhysioOpenSim'.",
      call. = FALSE
    )
  }

  if (is.list(model) && .looks_like_physioopensim_summary(model)) {
    return(list(
      marker_names = character(),
      marker_summary_only = TRUE,
      model_summary = model
    ))
  }

  if (!is.list(model)) {
    stop(
      "`model` must be an OpenSim model object, `.osim` path, or PhysioOpenSim summary list.",
      call. = FALSE
    )
  }

  marker_names <- character()
  if (!is.null(model$markers)) {
    markers <- model$markers
    if (is.data.frame(markers) && "name" %in% names(markers)) {
      marker_names <- as.character(markers$name)
    } else if (is.vector(markers) && is.character(markers)) {
      marker_names <- as.character(markers)
    }
  }

  list(
    marker_names = marker_names[!is.na(marker_names)],
    marker_summary_only = FALSE,
    model_summary = NULL
  )
}

#' Check whether object has PhysioOpenSim model summary shape
#' @keywords internal
.looks_like_physioopensim_summary <- function(x) {
  is.list(x) && all(
    c("model_name", "n_bodies", "n_joints", "n_markers", "n_muscles", "total_mass") %in% names(x)
  )
}

#' Create gait schema based on available OpenSim data
#' @keywords internal
.create_gait_schema_opensim <- function(has_grf, has_heel_marker, has_toe_marker,
                                        has_kinematics, available_signals, side) {
  events <- list()

  # Determine best detection method for heel strike
  if (has_grf) {
    grf_signal <- .find_signal_match(available_signals, c("vgrf", "ground_force_vy", "grf_y"))
    events$hs1 <- Event("hs1", "Heel Strike", "threshold",
                        list(signal = grf_signal, threshold = 20, direction = "rising"),
                        typical_timing = 0)
    events$to <- Event("to", "Toe Off", "threshold",
                       list(signal = grf_signal, threshold = 20, direction = "falling"),
                       typical_timing = 60)
    events$hs2 <- Event("hs2", "Heel Strike 2", "threshold",
                        list(signal = grf_signal, threshold = 20, direction = "rising"),
                        typical_timing = 100)
  } else if (has_heel_marker) {
    # Use marker-based detection
    heel_signal <- .find_signal_match(available_signals, c("heel_marker_y", "calcn_ty", "R.Heel_Y"))
    events$hs1 <- Event("hs1", "Heel Strike", "peak",
                        list(signal = heel_signal, type = "min"),
                        typical_timing = 0)
    events$to <- Event("to", "Toe Off", "peak",
                       list(signal = if (has_toe_marker) "toe_marker_y" else heel_signal, type = "min"),
                       typical_timing = 60)
    events$hs2 <- Event("hs2", "Heel Strike 2", "peak",
                        list(signal = heel_signal, type = "min"),
                        typical_timing = 100)
  } else if (has_kinematics) {
    # Fall back to kinematic detection
    knee_signal <- .find_signal_match(available_signals, c("knee_angle_r", "knee_flexion_r"))
    events$hs1 <- Event("hs1", "Heel Strike", "peak",
                        list(signal = knee_signal, type = "min"),
                        typical_timing = 0)
    events$to <- Event("to", "Toe Off", "peak",
                       list(signal = knee_signal, type = "max"),
                       typical_timing = 60)
    events$hs2 <- Event("hs2", "Heel Strike 2", "peak",
                        list(signal = knee_signal, type = "min"),
                        typical_timing = 100)
  } else {
    # Manual detection required
    events$hs1 <- Event("hs1", "Heel Strike", "manual", list(), typical_timing = 0)
    events$to <- Event("to", "Toe Off", "manual", list(), typical_timing = 60)
    events$hs2 <- Event("hs2", "Heel Strike 2", "manual", list(), typical_timing = 100)
  }

  TaskSchema(
    task_type = "gait_opensim",
    task_label = "Gait Cycle (OpenSim)",
    events = events,
    phases = list(
      Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8"),
      Phase("swing", "Swing Phase", "to", "hs2", color = "#FFF4E8")
    ),
    normalization = "cycle",
    norm_length = 101L,
    metrics = c("peak_knee_flexion", "peak_hip_flexion", "rom_ankle",
                "stance_time", "swing_time", "stance_ratio"),
    vis_defaults = list(
      xlab = "Gait Cycle (%)",
      ylab = "Angle (deg)",
      show_phases = TRUE,
      show_events = TRUE
    )
  )
}

#' Create running schema based on available OpenSim data
#' @keywords internal
.create_running_schema_opensim <- function(has_grf, has_kinematics, available_signals, side) {
  events <- list()

  if (has_grf) {
    grf_signal <- .find_signal_match(available_signals, c("vgrf", "ground_force_vy", "grf_y"))
    events$ic1 <- Event("ic1", "Initial Contact", "threshold",
                        list(signal = grf_signal, threshold = 50, direction = "rising"),
                        typical_timing = 0)
    events$to <- Event("to", "Toe Off", "threshold",
                       list(signal = grf_signal, threshold = 50, direction = "falling"),
                       typical_timing = 35)
    events$ic2 <- Event("ic2", "Initial Contact 2", "threshold",
                        list(signal = grf_signal, threshold = 50, direction = "rising"),
                        typical_timing = 100)
  } else {
    events$ic1 <- Event("ic1", "Initial Contact", "manual", list(), typical_timing = 0)
    events$to <- Event("to", "Toe Off", "manual", list(), typical_timing = 35)
    events$ic2 <- Event("ic2", "Initial Contact 2", "manual", list(), typical_timing = 100)
  }

  TaskSchema(
    task_type = "running_opensim",
    task_label = "Running Cycle (OpenSim)",
    events = events,
    phases = list(
      Phase("stance", "Stance Phase", "ic1", "to", color = "#E8F8E8"),
      Phase("swing", "Swing Phase", "to", "ic2", color = "#F8E8F8")
    ),
    normalization = "cycle",
    norm_length = 101L,
    metrics = c("contact_time", "flight_time", "step_frequency",
                "peak_vgrf", "loading_rate"),
    vis_defaults = list(
      xlab = "Running Cycle (%)",
      ylab = "Value",
      show_phases = TRUE,
      show_events = TRUE
    )
  )
}

#' Create jump schema based on available OpenSim data
#' @keywords internal
.create_jump_schema_opensim <- function(has_grf, has_kinematics, available_signals) {
  events <- list()

  if (has_grf) {
    grf_signal <- .find_signal_match(available_signals, c("vgrf", "ground_force_vy", "grf_y"))
    events$start <- Event("start", "Movement Start", "threshold",
                          list(signal = grf_signal, threshold = "bw-10%", direction = "falling"),
                          typical_timing = 0)
    events$takeoff <- Event("takeoff", "Takeoff", "threshold",
                            list(signal = grf_signal, threshold = 10, direction = "falling"),
                            typical_timing = 40)
    events$landing <- Event("landing", "Landing", "threshold",
                            list(signal = grf_signal, threshold = 10, direction = "rising"),
                            typical_timing = 70)
    events$end <- Event("end", "End", "threshold",
                        list(signal = grf_signal, threshold = "bw-10%", direction = "falling"),
                        typical_timing = 100)
  } else {
    events$start <- Event("start", "Movement Start", "manual", list(), typical_timing = 0)
    events$takeoff <- Event("takeoff", "Takeoff", "manual", list(), typical_timing = 40)
    events$landing <- Event("landing", "Landing", "manual", list(), typical_timing = 70)
    events$end <- Event("end", "End", "manual", list(), typical_timing = 100)
  }

  TaskSchema(
    task_type = "jump_opensim",
    task_label = "Jump (OpenSim)",
    events = events,
    phases = list(
      Phase("preparation", "Preparation", "start", "takeoff", color = "#E8E8F8"),
      Phase("flight", "Flight", "takeoff", "landing", color = "#F8F8E8"),
      Phase("landing", "Landing", "landing", "end", color = "#F8E8E8")
    ),
    normalization = "phase",
    norm_length = 101L,
    metrics = c("jump_height", "peak_power", "contact_time", "flight_time",
                "peak_grf_takeoff", "peak_grf_landing"),
    vis_defaults = list(
      xlab = "Movement Phase (%)",
      ylab = "Value",
      show_phases = TRUE,
      show_events = TRUE
    )
  )
}

#' Find matching signal name from available signals
#' @keywords internal
.find_signal_match <- function(available_signals, patterns) {
  if (is.null(available_signals) || length(available_signals) == 0) {
    return(patterns[1])  # Return first pattern as default
  }

  for (pattern in patterns) {
    matches <- grep(pattern, available_signals, ignore.case = TRUE, value = TRUE)
    if (length(matches) > 0) {
      return(matches[1])
    }
  }

  patterns[1]  # Return first pattern as fallback
}

#' Run OpenSim CLI Toolchain via PhysioOpenSim
#'
#' Executes OpenSim setup XML files sequentially through `PhysioOpenSim`.
#'
#' @param ik_setup Optional path to IK setup XML.
#' @param id_setup Optional path to ID setup XML.
#' @param so_setup Optional path to SO setup XML.
#' @param rra_setup Optional path to RRA setup XML.
#' @param cmc_setup Optional path to CMC setup XML.
#' @param analyze_setup Optional path to Analyze setup XML.
#' @param workdir Optional working directory for all tool runs.
#' @param cli Optional OpenSim CLI command/path.
#' @param timeout_sec Timeout in seconds for each tool execution.
#' @param fail_on_error If `TRUE`, abort when any tool returns non-zero status.
#' @param extra_args Optional character vector appended to every tool run.
#'
#' @return Named list with entries for tools that were executed
#'   (`ik`, `id`, `so`, `rra`, `cmc`, `analyze`).
#'
#' @seealso [batch_analyze_opensim()], [create_schema_from_opensim()]
#' @export
run_opensim_toolchain <- function(ik_setup = NULL,
                                  id_setup = NULL,
                                  so_setup = NULL,
                                  rra_setup = NULL,
                                  cmc_setup = NULL,
                                  analyze_setup = NULL,
                                  workdir = NULL,
                                  cli = NULL,
                                  timeout_sec = 0L,
                                  fail_on_error = TRUE,
                                  extra_args = character()) {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) {
    stop("Package 'PhysioOpenSim' is required for run_opensim_toolchain().", call. = FALSE)
  }

  setups <- list(
    ik = ik_setup,
    id = id_setup,
    so = so_setup,
    rra = rra_setup,
    cmc = cmc_setup,
    analyze = analyze_setup
  )
  provided <- !vapply(setups, is.null, logical(1))
  if (!any(provided)) {
    stop(
      "At least one of ik_setup/id_setup/so_setup/rra_setup/cmc_setup/analyze_setup must be provided.",
      call. = FALSE
    )
  }

  results <- list()
  for (tool_name in names(setups)[provided]) {
    setup_file <- setups[[tool_name]]
    if (!is.character(setup_file) || length(setup_file) != 1L || is.na(setup_file) || !nzchar(setup_file)) {
      stop("`", tool_name, "_setup` must be a non-empty character scalar.", call. = FALSE)
    }

    runner <- switch(tool_name,
      ik = PhysioOpenSim::opensimRunIK,
      id = PhysioOpenSim::opensimRunID,
      so = PhysioOpenSim::opensimRunSO,
      rra = PhysioOpenSim::opensimRunRRA,
      cmc = PhysioOpenSim::opensimRunCMC,
      analyze = PhysioOpenSim::opensimRunAnalyze
    )
    results[[tool_name]] <- runner(
      setup_file = setup_file,
      workdir = workdir,
      cli = cli,
      extra_args = extra_args,
      timeout_sec = timeout_sec,
      fail_on_error = fail_on_error
    )
  }

  results
}

#' Read OpenSim Output Files
#'
#' Reads one or more OpenSim output files and returns PhysioExperiment objects.
#'
#' @param files Character vector of file paths.
#' @param format One of `\"auto\"`, `\"mot\"`, `\"sto\"`, `\"trc\"`.
#'
#' @return Named list of PhysioExperiment objects.
#'
#' @seealso [readMOT()], [readSTO()], [readTRC()]
#' @export
readOpenSimOutputs <- function(files, format = c("auto", "mot", "sto", "trc")) {
  format <- match.arg(format)
  if (!is.character(files) || length(files) == 0L || any(is.na(files)) || any(!nzchar(files))) {
    stop("`files` must be a non-empty character vector of paths.", call. = FALSE)
  }
  if (!all(file.exists(files))) {
    missing <- files[!file.exists(files)]
    stop("OpenSim output file(s) do not exist: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  out <- vector("list", length(files))
  for (i in seq_along(files)) {
    f <- files[[i]]
    f_format <- if (format == "auto") {
      tolower(tools::file_ext(f))
    } else {
      format
    }

    out[[i]] <- switch(f_format,
      mot = readMOT(f),
      sto = readSTO(f),
      trc = readTRC(f),
      stop(
        "Unsupported OpenSim file extension for auto format: ",
        f, ". Supported: .mot, .sto, .trc",
        call. = FALSE
      )
    )
  }

  names(out) <- make.unique(tools::file_path_sans_ext(basename(files)))
  out
}


#' Batch analyze OpenSim session data
#'
#' Loads an OpenSim session and performs batch movement analysis using
#' a TaskSchema for event detection and normalization.
#'
#' @param session_dir Directory containing OpenSim output files, or an
#'   opensim_session/opensim_workflow object from signalIO
#' @param schema A TaskSchema object defining events and phases
#' @param signal_mapping Named list mapping schema signal names to actual
#'   channel names in the data
#' @param trials Character vector of trial names to analyze. If NULL, analyzes all.
#' @param normalize_method Override schema normalization method
#' @param ... Additional arguments passed to normalizeMovement
#'
#' @return A list containing:
#'   - trials: List of normalized trial data
#'   - events: List of detected events per trial
#'   - phases: List of phase timing per trial
#'   - summary: Summary statistics across trials
#'
#' @examples
#' \dontrun{
#' library(signalIO)
#'
#' # Load session and analyze
#' results <- batch_analyze_opensim(
#'   "subject01/",
#'   schema = schema_gait,
#'   signal_mapping = list(vGRF = "ground_force_vy_r")
#' )
#'
#' # Access normalized trials
#' trial1 <- results$trials[[1]]
#'
#' # View summary
#' print(results$summary)
#' }
#'
#' @references
#' Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
#' Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
#' Dynamic Simulations of Movement." IEEE Transactions on Biomedical
#' Engineering, 54(11), 1940-1950.
#'
#' @seealso [create_schema_from_opensim()] for creating task schemas from
#'   OpenSim models.
#'
#' @export
batch_analyze_opensim <- function(session_dir, schema,
                                  signal_mapping = list(),
                                  trials = NULL,
                                  normalize_method = NULL,
                                  ...) {
  # Check for signalIO
  if (!requireNamespace(.opensim_io_pkg, quietly = TRUE)) {
    stop("Package 'signalIO' is required for batch_analyze_opensim()", call. = FALSE)
  }

  stopifnot(inherits(schema, "TaskSchema"))

  # Load session if directory path provided
  if (is.character(session_dir)) {
    if (exists("read_opensim_session", envir = asNamespace(.opensim_io_pkg),
               mode = "function", inherits = FALSE)) {
      reader <- get("read_opensim_session", envir = asNamespace(.opensim_io_pkg),
                    mode = "function", inherits = FALSE)
      session <- reader(session_dir)
    } else if (exists("opensim_workflow", envir = asNamespace(.opensim_io_pkg),
                      mode = "function", inherits = FALSE)) {
      # Backward compatibility for older signalIO versions.
      workflow_fun <- get("opensim_workflow", envir = asNamespace(.opensim_io_pkg),
                          mode = "function", inherits = FALSE)
      session <- workflow_fun(session_dir, sync_time = TRUE)
    } else {
      stop(
        "No compatible OpenSim session loader found in signalIO. ",
        "Expected read_opensim_session() or opensim_workflow().",
        call. = FALSE
      )
    }

    if (is.null(session)) {
      stop("Failed to load OpenSim session from: ", session_dir, call. = FALSE)
    }
  } else if (inherits(session_dir, c("opensim_session", "opensim_workflow"))) {
    session <- session_dir
  } else {
    stop("session_dir must be a directory path or opensim_session object", call. = FALSE)
  }

  # Determine normalization method
  norm_method <- if (!is.null(normalize_method)) normalize_method else schema$normalization

  # Identify trials to analyze
  exp_names <- names(session$experiments)
  if (!is.null(trials)) {
    exp_names <- exp_names[exp_names %in% trials]
  }

  if (length(exp_names) == 0) {
    warning("No trials found to analyze")
    return(list(trials = list(), events = list(), phases = list(), summary = NULL))
  }

  # Analyze each trial
  results <- list(
    trials = list(),
    events = list(),
    phases = list(),
    raw = list()
  )

  for (trial_name in exp_names) {
    trial_data <- session$experiments[[trial_name]]

    # Extract assay data
    assay_data <- SummarizedExperiment::assay(trial_data)

    # Get signal data for event detection
    signals_for_detection <- list()
    for (schema_signal in names(signal_mapping)) {
      data_signal <- signal_mapping[[schema_signal]]
      row_data <- SummarizedExperiment::rowData(trial_data)

      if ("channel_name" %in% names(row_data)) {
        channel_names <- row_data$channel_name
      } else {
        channel_names <- rownames(trial_data)
      }

      signal_idx <- match(data_signal, channel_names)
      if (!is.na(signal_idx)) {
        signals_for_detection[[schema_signal]] <- assay_data[signal_idx, ]
      }
    }

    # Detect events
    tryCatch({
      events <- detectEvents(assay_data, schema, signals = signals_for_detection)
      results$events[[trial_name]] <- events

      # Segment phases
      phases <- segmentPhases(assay_data, events, schema)
      results$phases[[trial_name]] <- phases

      # Normalize
      normalized <- normalizeMovement(
        assay_data,
        events = events,
        method = norm_method,
        norm_length = schema$norm_length,
        ...
      )
      results$trials[[trial_name]] <- normalized
      results$raw[[trial_name]] <- assay_data

    }, error = function(e) {
      warning(sprintf("Failed to analyze trial '%s': %s", trial_name, e$message))
    })
  }

  # Generate summary statistics
  results$summary <- .summarize_batch_results(results, schema)

  results
}

#' Generate summary statistics from batch results
#' @keywords internal
.summarize_batch_results <- function(results, schema) {
  if (length(results$trials) == 0) {
    return(NULL)
  }

  # Collect phase durations
  phase_names <- getPhaseNames(schema)
  durations_list <- lapply(results$phases, function(phases) {
    if (is.null(phases)) return(NULL)
    phaseDurations(phases)
  })
  durations_list <- durations_list[!vapply(durations_list, is.null, logical(1))]

  # Calculate mean/SD for phase durations
  if (length(durations_list) > 0 && length(phase_names) > 0) {
    duration_summary <- do.call(rbind, lapply(phase_names, function(pname) {
      vals <- vapply(durations_list, function(d) {
        if (pname %in% names(d)) d[[pname]] else NA_real_
      }, numeric(1))
      vals <- vals[!is.na(vals)]

      if (length(vals) > 0) {
        data.frame(
          phase = pname,
          mean_duration = mean(vals),
          sd_duration = sd(vals),
          n = length(vals),
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
    }))
    duration_summary <- duration_summary[!vapply(duration_summary, is.null, logical(1))]
    if (length(duration_summary) > 0) {
      duration_summary <- do.call(rbind, duration_summary)
    } else {
      duration_summary <- NULL
    }
  } else {
    duration_summary <- NULL
  }

  list(
    n_trials = length(results$trials),
    n_failed = length(results$events) - length(results$trials),
    duration_summary = duration_summary
  )
}


# --- SO / RRA / CMC orchestrators --------------------------------------------

#' Whether an OpenSim backend (native or CLI) is reachable
#' @keywords internal
#' @noRd
.opensim_backend_available <- function(cli = NULL) {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) {
    return(FALSE)
  }
  isTRUE(PhysioOpenSim::opensimAvailable()) ||
    isTRUE(PhysioOpenSim::opensimCLIAvailable(cli))
}

#' @keywords internal
#' @noRd
.require_opensim <- function(what, cli = NULL) {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) {
    stop("Package 'PhysioOpenSim' is required for ", what, ".", call. = FALSE)
  }
  if (!.opensim_backend_available(cli)) {
    stop(what, " requires a working OpenSim backend (native library or the ",
         "opensim-cmd CLI).", call. = FALSE)
  }
}

#' Run static optimization (OpenSim, or a pure-R fallback)
#'
#' Resolves net joint moments into muscle activations. When an OpenSim backend
#' is available and a Static Optimization setup file is supplied, it runs the
#' OpenSim Static Optimization tool via PhysioOpenSim; otherwise it falls back to
#' [staticOptimizationR()], the pure-R quadratic muscle-effort solver, using the
#' supplied moment arms, maximum forces and joint moments.
#'
#' @param so_setup Path to an OpenSim Static Optimization setup XML (OpenSim
#'   backend).
#' @param moment_arms,max_force,joint_moments Inputs for the pure-R fallback,
#'   passed to [staticOptimizationR()].
#' @param execution Backend selection: `"auto"` (default; OpenSim when available
#'   and `so_setup` is given, else pure-R), `"opensim"`, or `"r"`.
#' @param workdir,cli,timeout_sec,fail_on_error Passed to
#'   `PhysioOpenSim::opensimRunSO()` for the OpenSim backend.
#' @param ... Additional arguments passed to [staticOptimizationR()] for the
#'   pure-R backend (e.g. `weights`, `activation_bounds`).
#'
#' @return An `opensim_so_result` list with `backend` (`"opensim"` or `"r"`) and
#'   either `tool` (the PhysioOpenSim tool result) or `static_optimization` (the
#'   [staticOptimizationR()] result).
#'
#' @seealso [staticOptimizationR()], [runRRA()], [runCMC()]
#' @export
runStaticOptimization <- function(so_setup = NULL,
                                  moment_arms = NULL, max_force = NULL,
                                  joint_moments = NULL,
                                  execution = c("auto", "opensim", "r"),
                                  workdir = NULL, cli = NULL,
                                  timeout_sec = 0L, fail_on_error = TRUE, ...) {
  execution <- match.arg(execution)
  opensim_ok <- .opensim_backend_available(cli)

  use_r <- switch(execution,
    r = TRUE,
    opensim = FALSE,
    auto = !(opensim_ok && !is.null(so_setup))
  )

  if (execution == "opensim" && !opensim_ok) {
    stop("execution = 'opensim' requires a working OpenSim backend.",
         call. = FALSE)
  }

  if (use_r) {
    if (is.null(moment_arms) || is.null(max_force) || is.null(joint_moments)) {
      stop("Pure-R static optimization needs `moment_arms`, `max_force` and ",
           "`joint_moments`.", call. = FALSE)
    }
    res <- staticOptimizationR(moment_arms, max_force, joint_moments, ...)
    out <- list(backend = "r", static_optimization = res)
    class(out) <- "opensim_so_result"
    return(out)
  }

  if (is.null(so_setup)) {
    stop("`so_setup` is required for the OpenSim backend.", call. = FALSE)
  }
  tool <- PhysioOpenSim::opensimRunSO(
    setup_file = so_setup, workdir = workdir, cli = cli,
    timeout_sec = timeout_sec, fail_on_error = fail_on_error
  )
  out <- list(backend = "opensim", tool = tool)
  class(out) <- "opensim_so_result"
  out
}

#' Run Residual Reduction Algorithm (RRA) via OpenSim
#'
#' Orchestrates the OpenSim Residual Reduction Algorithm through PhysioOpenSim.
#' RRA has no pure-R fallback, so it requires a working OpenSim backend.
#'
#' @param rra_setup Path to an OpenSim RRA setup XML.
#' @param workdir,cli,timeout_sec,fail_on_error Passed to
#'   `PhysioOpenSim::opensimRunRRA()`.
#' @return An `opensim_tool_result` list with `tool` (the PhysioOpenSim result).
#' @seealso [runStaticOptimization()], [runCMC()]
#' @export
runRRA <- function(rra_setup, workdir = NULL, cli = NULL,
                   timeout_sec = 0L, fail_on_error = TRUE) {
  if (!is.character(rra_setup) || length(rra_setup) != 1L ||
      is.na(rra_setup) || !nzchar(rra_setup)) {
    stop("`rra_setup` must be a non-empty character scalar.", call. = FALSE)
  }
  .require_opensim("runRRA()", cli = cli)
  tool <- PhysioOpenSim::opensimRunRRA(
    setup_file = rra_setup, workdir = workdir, cli = cli,
    timeout_sec = timeout_sec, fail_on_error = fail_on_error
  )
  out <- list(tool = tool, tool_type = "rra")
  class(out) <- "opensim_tool_result"
  out
}

#' Run Computed Muscle Control (CMC) via OpenSim
#'
#' Orchestrates the OpenSim Computed Muscle Control tool through PhysioOpenSim.
#' CMC has no pure-R fallback, so it requires a working OpenSim backend.
#'
#' @param cmc_setup Path to an OpenSim CMC setup XML.
#' @param workdir,cli,timeout_sec,fail_on_error Passed to
#'   `PhysioOpenSim::opensimRunCMC()`.
#' @return An `opensim_tool_result` list with `tool` (the PhysioOpenSim result).
#' @seealso [runStaticOptimization()], [runRRA()]
#' @export
runCMC <- function(cmc_setup, workdir = NULL, cli = NULL,
                   timeout_sec = 0L, fail_on_error = TRUE) {
  if (!is.character(cmc_setup) || length(cmc_setup) != 1L ||
      is.na(cmc_setup) || !nzchar(cmc_setup)) {
    stop("`cmc_setup` must be a non-empty character scalar.", call. = FALSE)
  }
  .require_opensim("runCMC()", cli = cli)
  tool <- PhysioOpenSim::opensimRunCMC(
    setup_file = cmc_setup, workdir = workdir, cli = cli,
    timeout_sec = timeout_sec, fail_on_error = fail_on_error
  )
  out <- list(tool = tool, tool_type = "cmc")
  class(out) <- "opensim_tool_result"
  out
}

#' @export
print.opensim_so_result <- function(x, ...) {
  cat("<opensim_so_result> backend:", x$backend, "\n")
  if (identical(x$backend, "r")) {
    print(x$static_optimization)
  }
  invisible(x)
}

#' @export
print.opensim_tool_result <- function(x, ...) {
  cat("<opensim_tool_result> tool:", x$tool_type, "\n")
  invisible(x)
}


# Validate a single readable file path argument.
.assert_readable_file <- function(path, arg) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("`", arg, "` must be a single non-empty file path.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("`", arg, "` does not exist: ", path, call. = FALSE)
  }
  invisible(path)
}

# Resolve the setup-template paths. A user `templates` list overrides the bundled
# PhysioOpenSim defaults per tool (a partial list keeps the defaults for the rest).
.opensim_default_templates <- function(templates = NULL) {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) {
    stop("Package 'PhysioOpenSim' is required to resolve the OpenSim templates.", call. = FALSE)
  }
  base <- list(
    ik = PhysioOpenSim::opensimTemplatePath("ik"),
    id = PhysioOpenSim::opensimTemplatePath("id"),
    so = PhysioOpenSim::opensimTemplatePath("so")
  )
  if (is.null(templates)) return(base)
  if (!is.list(templates)) stop("`templates` must be a named list of template paths.", call. = FALSE)
  utils::modifyList(base, templates)
}

# Time span (c(start, end), seconds) covered by a TRC marker file, so the tool
# setups run over the WHOLE trial. Without this the templates' <time_range>0 1</...>
# would silently truncate every trial to its first second. Returns NULL if the
# file is not a parseable TRC (the caller then leaves time_range unset).
.trc_time_range <- function(trc_file) {
  lines <- tryCatch(readLines(trc_file, warn = FALSE), error = function(e) character())
  hdr <- grep("^Frame#", lines)
  if (!length(hdr) || hdr[1] >= length(lines)) return(NULL)
  rows <- lines[(hdr[1] + 1):length(lines)]
  times <- vapply(rows, function(ln) {
    f <- strsplit(trimws(ln), "[[:space:]]+")[[1]]
    if (length(f) < 2) return(NA_real_)
    fr <- suppressWarnings(as.numeric(f[1]))       # a data row starts with a numeric frame number
    tm <- suppressWarnings(as.numeric(f[2]))       # ... then the time
    if (is.na(fr)) NA_real_ else tm
  }, numeric(1), USE.NAMES = FALSE)
  times <- times[!is.na(times)]
  if (!length(times)) return(NULL)
  c(min(times), max(times))
}

# Read OpenSim output files into named PhysioExperiments, skipping empty or
# unreadable ones (one malformed .mot/.sto must not abort the whole readback).
.read_opensim_safely <- function(files) {
  files <- files[file.exists(files) & file.size(files) > 0]
  out <- list()
  for (f in files) {
    pe <- tryCatch(readOpenSimOutputs(f)[[1]],
                   error = function(e) {
                     warning("Skipping unreadable OpenSim output '", basename(f), "': ",
                             conditionMessage(e), call. = FALSE)
                     NULL
                   })
    if (!is.null(pe)) out[[tools::file_path_sans_ext(basename(f))]] <- pe
  }
  out
}

# Name of the backend that would actually run (native > cli > none).
.opensim_active_backend <- function(cli = NULL) {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) return("none")
  if (isTRUE(PhysioOpenSim::opensimAvailable())) return("native")
  if (isTRUE(PhysioOpenSim::opensimCLIAvailable(cli))) return("cli")
  "none"
}

#' Run the local OpenSim toolchain from a model and marker file
#'
#' Convenience wrapper that wires markers through OpenSim inverse kinematics
#' (IK) and, optionally, inverse dynamics (ID) and static optimization (SO): it
#' writes the tool setup XMLs from the bundled \pkg{PhysioOpenSim} templates,
#' runs them in order via [run_opensim_toolchain()], and parses the results with
#' [readOpenSimOutputs()] into a downstream-ready form. This is the local
#' counterpart to using OpenCap's cloud kinematics directly.
#'
#' IK needs only the scaled model and markers. **ID and SO additionally need
#' ground-reaction data** (`external_loads_file`); markerless OpenCap has no
#' force plates, so you must supply a measured or estimated `ExternalLoads` XML
#' (or set `require_external_loads = FALSE` to run kinematics-only inverse
#' dynamics, which is valid only for non-contact phases such as swing). CMC and
#' RRA need actuator/tracking-task files beyond what this wrapper infers; run
#' them via [run_opensim_toolchain()] with the corresponding
#' `PhysioOpenSim::opensimWrite*SetupFromTemplate()` writers.
#'
#' @param model_file Path to a scaled OpenSim `.osim` model (e.g. from
#'   [downloadOpenCapModel()]).
#' @param trc_file Path to a marker trajectory `.trc` file.
#' @param tools Which tools to run, a subset of `"ik"`, `"id"`, `"so"` (IK is
#'   always required and run first). Default `"ik"`.
#' @param external_loads_file Path to an OpenSim `ExternalLoads` XML (ground
#'   reactions). Required for `"id"`/`"so"` unless `require_external_loads` is
#'   `FALSE`.
#' @param time_range Optional numeric `c(start, end)` (s) applied to every tool.
#'   If `NULL` (default) the whole trial is used, read from `trc_file` (otherwise
#'   the tool templates' own `<time_range>` would truncate the trial to 0-1 s).
#' @param workdir Directory for setup XMLs and outputs (a temporary directory by
#'   default).
#' @param templates Optional named list of template paths (`ik`/`id`/`so`);
#'   defaults to the templates bundled with \pkg{PhysioOpenSim}.
#' @param cli Optional path to the `opensim-cmd` CLI (see [run_opensim_toolchain()]).
#' @param require_external_loads If `TRUE` (default) error when `"id"`/`"so"`
#'   are requested without `external_loads_file`.
#' @param dry_run If `TRUE`, only write the setup XMLs and return them without a
#'   working OpenSim backend (useful for inspection/testing). Default `FALSE`.
#' @return An `opensim_run` list: `setups` (written XML paths), `workdir`,
#'   `expected_outputs`; and, when run, `toolchain` (raw [run_opensim_toolchain()]
#'   result), `files` (produced `.mot`/`.sto`), `outputs` (their parsed
#'   `PhysioExperiment` objects from [readOpenSimOutputs()]), `motion` (the IK
#'   joint-angle object), and `backend`.
#' @seealso [runOpenSimFromOpenCap()], [run_opensim_toolchain()],
#'   [readOpenSimOutputs()], [downloadOpenCapModel()]
#' @export
#' @examples
#' \dontrun{
#' res <- runOpenSimFromMarkers(
#'   model_file = "subject_scaled.osim", trc_file = "walk.trc",
#'   tools = c("ik", "id", "so"), external_loads_file = "walk_grf.xml")
#' res$motion            # IK joint angles (PhysioExperiment)
#' calculateJointAngles(res$motion)
#' }
runOpenSimFromMarkers <- function(model_file, trc_file,
                                  tools = "ik",
                                  external_loads_file = NULL,
                                  time_range = NULL,
                                  workdir = NULL,
                                  templates = NULL,
                                  cli = NULL,
                                  require_external_loads = TRUE,
                                  dry_run = FALSE) {
  tools <- match.arg(tools, c("ik", "id", "so"), several.ok = TRUE)
  tools <- union("ik", tools)                       # IK is always required and first
  .assert_readable_file(model_file, "model_file")
  .assert_readable_file(trc_file, "trc_file")

  needs_grf <- intersect(tools, c("id", "so"))
  if (length(needs_grf) && is.null(external_loads_file) && isTRUE(require_external_loads)) {
    stop(sprintf(
      paste0("%s require `external_loads_file` (an OpenSim ExternalLoads / ground-reaction XML). ",
             "Markerless OpenCap has no force plates: supply measured GRF or an estimated ExternalLoads ",
             "file, or set require_external_loads = FALSE for kinematics-only inverse dynamics ",
             "(valid only for non-contact phases such as swing)."),
      paste(toupper(needs_grf), collapse = "/")), call. = FALSE)
  }
  if (!is.null(external_loads_file)) .assert_readable_file(external_loads_file, "external_loads_file")

  # Default to the whole trial; otherwise the templates' <time_range>0 1</...>
  # truncates every trial to its first second.
  if (is.null(time_range)) time_range <- .trc_time_range(trc_file)

  if (is.null(workdir)) workdir <- tempfile("opensim_")
  dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
  tpl <- .opensim_default_templates(templates)

  ik_setup <- file.path(workdir, "ik_setup.xml")
  ik_mot   <- file.path(workdir, "ik.mot")
  id_sto   <- file.path(workdir, "id.sto")

  # Write the ID/SO setups (they reference the IK motion as their coordinates file).
  write_id_so <- function() {
    if ("id" %in% tools) {
      id_setup <- file.path(workdir, "id_setup.xml")
      PhysioOpenSim::opensimWriteIDSetupFromTemplate(
        template_file = tpl$id, output_file = id_setup, model_file = model_file,
        coordinates_file = ik_mot, output_gen_force_file = id_sto,
        external_loads_file = external_loads_file, time_range = time_range,
        results_directory = workdir)
      setups$id <<- id_setup; expected["id"] <<- id_sto
    }
    if ("so" %in% tools) {
      so_setup <- file.path(workdir, "so_setup.xml")
      PhysioOpenSim::opensimWriteSOSetupFromTemplate(
        template_file = tpl$so, output_file = so_setup, model_file = model_file,
        coordinates_file = ik_mot, external_loads_file = external_loads_file,
        time_range = time_range, results_directory = workdir)
      setups$so <<- so_setup
    }
  }

  # IK setup (always).
  PhysioOpenSim::opensimWriteIKSetupFromTemplate(
    template_file = tpl$ik, output_file = ik_setup, model_file = model_file,
    marker_file = trc_file, output_motion_file = ik_mot,
    time_range = time_range, results_directory = workdir)
  setups <- list(ik = ik_setup)
  expected <- c(ik = ik_mot)

  if (isTRUE(dry_run)) {
    # No backend: touch a placeholder so the ID/SO writers' must-exist check on
    # the (not-yet-produced) IK motion passes for inspection only.
    if (("id" %in% tools || "so" %in% tools) && !file.exists(ik_mot)) file.create(ik_mot)
    write_id_so()
    return(structure(list(setups = setups, workdir = workdir,
                          expected_outputs = expected, ran = FALSE,
                          backend = .opensim_active_backend(cli)),
                     class = "opensim_run"))
  }

  .require_opensim("runOpenSimFromMarkers", cli)

  # Snapshot pre-existing outputs so a reused workdir's stale files are not
  # attributed to this run.
  before <- list.files(workdir, pattern = "\\.(mot|sto)$", full.names = TRUE)

  # Run IK first so its motion really exists before the ID/SO setups reference it
  # (no empty-placeholder shortcut, which would hide an IK failure and later crash
  # the MOT reader on a 0-byte file).
  toolchain <- run_opensim_toolchain(ik_setup = ik_setup, workdir = workdir, cli = cli)
  if (!file.exists(ik_mot) || file.size(ik_mot) == 0) {
    stop("Inverse kinematics produced no motion file (", basename(ik_mot),
         "); cannot run downstream tools or read results.", call. = FALSE)
  }
  if ("id" %in% tools || "so" %in% tools) {
    write_id_so()
    toolchain <- c(toolchain, run_opensim_toolchain(
      ik_setup = NULL, id_setup = setups$id, so_setup = setups$so,
      workdir = workdir, cli = cli))
  }

  produced <- setdiff(list.files(workdir, pattern = "\\.(mot|sto)$", full.names = TRUE), before)
  outputs <- .read_opensim_safely(produced)

  structure(list(setups = setups, toolchain = toolchain, workdir = workdir,
                 expected_outputs = expected, files = produced, outputs = outputs,
                 motion = outputs[["ik"]], ran = TRUE,
                 backend = .opensim_active_backend(cli)),
            class = "opensim_run")
}

#' Run the local OpenSim toolchain directly from an OpenCap session
#'
#' End-to-end bridge: downloads an OpenCap session's scaled OpenSim model
#' ([downloadOpenCapModel()]) and marker `.trc`, then runs the local OpenSim
#' toolchain ([runOpenSimFromMarkers()]). Requires a working OpenSim backend
#' (native \pkg{PhysioOpenSim} build or the `opensim-cmd` CLI) and, for ID/SO,
#' an `external_loads_file` (OpenCap is markerless and has no ground reactions).
#'
#' With `dry_run = TRUE` the model and markers are still downloaded (they are
#' needed to write the setups); only the OpenSim tool execution is skipped. For a
#' fully offline dry run, call [runOpenSimFromMarkers()] with local files.
#'
#' @inheritParams readOpenCap
#' @param model_file Optional local `.osim` model; if `NULL` (default) it is
#'   downloaded from the session with [downloadOpenCapModel()].
#' @param tools,external_loads_file,time_range,workdir,templates,cli,require_external_loads,dry_run
#'   Passed to [runOpenSimFromMarkers()].
#' @return An `opensim_run` object (see [runOpenSimFromMarkers()]).
#' @seealso [runOpenSimFromMarkers()], [readOpenCap()], [downloadOpenCapModel()]
#' @export
#' @examples
#' \dontrun{
#' res <- runOpenSimFromOpenCap(
#'   session_id = "abcd1234-5678-90ab-cdef-1234567890ab",
#'   tools = c("ik", "id", "so"), external_loads_file = "walk_grf.xml")
#' res$outputs
#' }
runOpenSimFromOpenCap <- function(session_id, trial_id = NULL, api_key = NULL,
                                  base_url = "https://app.opencap.ai/api",
                                  model_file = NULL,
                                  tools = "ik",
                                  external_loads_file = NULL,
                                  time_range = NULL, workdir = NULL,
                                  templates = NULL, cli = NULL,
                                  require_external_loads = TRUE, dry_run = FALSE) {
  # Validate ids and fail fast on the GRF requirement (and a bad loads path),
  # before any network download.
  if (!is.character(session_id) || length(session_id) != 1 || !nzchar(session_id)) {
    stop("'session_id' must be a non-empty character string.", call. = FALSE)
  }
  if (!is.null(trial_id) && (!is.character(trial_id) || length(trial_id) != 1 || !nzchar(trial_id))) {
    stop("'trial_id' must be NULL or a non-empty character string.", call. = FALSE)
  }
  tools <- match.arg(tools, c("ik", "id", "so"), several.ok = TRUE)
  if (isTRUE(require_external_loads) &&
      length(intersect(tools, c("id", "so"))) && is.null(external_loads_file)) {
    stop("ID/SO require `external_loads_file` (an OpenSim ExternalLoads / ground-reaction ",
         "XML); OpenCap is markerless and has no force plates. Supply it, drop \"id\"/\"so\" ",
         "from `tools`, or set require_external_loads = FALSE. (Checked before downloading ",
         "the session.)", call. = FALSE)
  }
  if (!is.null(external_loads_file)) .assert_readable_file(external_loads_file, "external_loads_file")
  if (!is.null(model_file)) .assert_readable_file(model_file, "model_file")

  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("The 'httr' package is required to download from OpenCap. ",
         "Install it with: install.packages('httr')", call. = FALSE)
  }
  auth <- .opencap_auth_header(api_key)
  burl <- sub("/$", "", base_url)
  # Resolve the session + trial ONCE and derive both downloads from it, so the
  # model and markers always come from the same trial and the trials list is not
  # fetched twice.
  ctx <- .opencap_resolve_trial(session_id, trial_id, auth, burl)

  if (is.null(model_file)) {
    model_file <- tempfile(fileext = ".osim")
    .opencap_download_file(.opencap_model_url(ctx$session_info, ctx$trial, burl, session_id),
                           auth, model_file)
  }
  trc_file <- tempfile(fileext = ".trc")
  .opencap_download_file(.opencap_result_url(ctx$trial, "markers", burl, session_id, ctx$trial_id),
                         auth, trc_file)

  res <- runOpenSimFromMarkers(
    model_file = model_file, trc_file = trc_file, tools = tools,
    external_loads_file = external_loads_file, time_range = time_range,
    workdir = workdir, templates = templates, cli = cli,
    require_external_loads = require_external_loads, dry_run = dry_run)
  res$opencap <- list(session_id = session_id, trial_id = ctx$trial_id,
                      model_file = model_file, trc_file = trc_file)
  res
}

#' @export
print.opensim_run <- function(x, ...) {
  cat("<opensim_run>", if (isTRUE(x$ran)) "(ran)" else "(dry run)",
      " backend:", x$backend %||% "none", "\n", sep = "")
  cat("  setups:", paste(names(x$setups), collapse = ", "), "\n")
  if (isTRUE(x$ran)) {
    cat("  outputs:", if (length(x$files)) paste(basename(x$files), collapse = ", ") else "(none)", "\n")
  }
  cat("  workdir:", x$workdir, "\n")
  invisible(x)
}
