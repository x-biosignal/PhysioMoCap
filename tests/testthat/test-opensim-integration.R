library(testthat)
library(PhysioMoCap)

# --- run_opensim_toolchain/readOpenSimOutputs ---

test_that("run_opensim_toolchain validates prerequisites and arguments", {
  if (!requireNamespace("PhysioOpenSim", quietly = TRUE)) {
    expect_error(run_opensim_toolchain(), "PhysioOpenSim")
  } else {
    expect_error(run_opensim_toolchain(), "At least one")
    expect_error(run_opensim_toolchain(analyze_setup = ""), "non-empty character scalar")
  }
})

test_that("readOpenSimOutputs reads MOT with auto format", {
  f <- tempfile(fileext = ".mot")
  writeLines(
    c(
      "name=demo",
      "nRows=2",
      "nColumns=3",
      "endheader",
      "time\thip_flexion\tknee_angle",
      "0.0\t10\t20",
      "0.1\t11\t21"
    ),
    f
  )

  out <- readOpenSimOutputs(f, format = "auto")
  expect_type(out, "list")
  expect_length(out, 1)
})

# --- create_schema_from_opensim: input adapters ---

test_that("create_schema_from_opensim accepts PhysioOpenSim summary list", {
  summary_model <- list(
    model_name = "demo",
    n_bodies = 10L,
    n_joints = 9L,
    n_markers = 12L,
    n_muscles = 30L,
    total_mass = 70
  )

  schema <- create_schema_from_opensim(
    summary_model, "gait",
    available_signals = c("knee_angle_r"),
    side = "right"
  )

  expect_s3_class(schema, "TaskSchema")
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "peak")
})

test_that("create_schema_from_opensim validates model path existence", {
  expect_error(
    create_schema_from_opensim("this/file/does/not/exist.osim", "gait"),
    "does not exist"
  )
})

test_that("create_schema_from_opensim validates model input type", {
  expect_error(
    create_schema_from_opensim(42, "gait"),
    "must be an OpenSim model object"
  )
})

# --- create_schema_from_opensim: gait ---

test_that("create_schema_from_opensim creates valid schema for gait with GRF", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel", "r_toe", "l_heel"),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("vgrf_r", "knee_angle_r"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  expect_equal(schema$task_type, "gait_opensim")
  expect_true(length(getEventNames(schema)) >= 3)
  # Should use GRF-based threshold detection (GRF available)
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "threshold")
  expect_equal(hs1$detection_params$direction, "rising")
})

test_that("create_schema_from_opensim gait falls back to marker detection", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel", "r_toe", "l_heel"),
    stringsAsFactors = FALSE
  ))
  # No GRF signals, but heel/toe markers exist
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("hip_angle_r"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  hs1 <- getEvent(schema, "hs1")
  # Falls back to marker-based peak detection

  expect_equal(hs1$detection_method, "peak")
})

test_that("create_schema_from_opensim gait falls back to kinematics", {
  # No markers, but kinematics available
  mock_model <- list(markers = data.frame(
    name = character(0),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("knee_angle_r", "hip_flexion"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "peak")
})

test_that("create_schema_from_opensim gait falls back to manual", {
  mock_model <- list(markers = data.frame(
    name = character(0),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("emg_tibant"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "manual")
})

test_that("gait schema has correct phases", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel"),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("vgrf_r"),
    side = "right"
  )
  phase_names <- getPhaseNames(schema)
  expect_true("stance" %in% phase_names)
  expect_true("swing" %in% phase_names)
  expect_equal(schema$normalization, "cycle")
  expect_equal(schema$norm_length, 101L)
})

# --- create_schema_from_opensim: running ---

test_that("create_schema_from_opensim creates valid schema for running with GRF", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(
    mock_model, "running",
    available_signals = c("ground_force_vy_r", "knee_angle_r"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  expect_equal(schema$task_type, "running_opensim")
  event_names <- getEventNames(schema)
  expect_true("ic1" %in% event_names)
  expect_true("to" %in% event_names)
  expect_true("ic2" %in% event_names)
  # GRF-based detection
  ic1 <- getEvent(schema, "ic1")
  expect_equal(ic1$detection_method, "threshold")
})

test_that("create_schema_from_opensim running falls back to manual", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(
    mock_model, "running",
    available_signals = c("emg_data"),
    side = "right"
  )
  ic1 <- getEvent(schema, "ic1")
  expect_equal(ic1$detection_method, "manual")
})

# --- create_schema_from_opensim: jump ---

test_that("create_schema_from_opensim creates valid schema for jump with GRF", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(
    mock_model, "jump",
    available_signals = c("grf_y", "knee_angle_r")
  )
  expect_s3_class(schema, "TaskSchema")
  expect_equal(schema$task_type, "jump_opensim")
  event_names <- getEventNames(schema)
  expect_true("start" %in% event_names)
  expect_true("takeoff" %in% event_names)
  expect_true("landing" %in% event_names)
  expect_true("end" %in% event_names)
  # GRF-based
  takeoff <- getEvent(schema, "takeoff")
  expect_equal(takeoff$detection_method, "threshold")
  # Phases
  phase_names <- getPhaseNames(schema)
  expect_true("preparation" %in% phase_names)
  expect_true("flight" %in% phase_names)
  expect_true("landing" %in% phase_names)
})

test_that("create_schema_from_opensim jump falls back to manual without GRF", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(
    mock_model, "jump",
    available_signals = c("hip_angle")
  )
  takeoff <- getEvent(schema, "takeoff")
  expect_equal(takeoff$detection_method, "manual")
})

# --- create_schema_from_opensim: generic ---

test_that("create_schema_from_opensim creates generic schema", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(mock_model, "generic")
  expect_s3_class(schema, "TaskSchema")
  expect_equal(schema$task_type, "generic")
  event_names <- getEventNames(schema)
  expect_true("start" %in% event_names)
  expect_true("end" %in% event_names)
  expect_equal(length(getPhaseNames(schema)), 1)
})

# --- Side parameter ---

test_that("create_schema_from_opensim respects side parameter", {
  mock_model_right <- list(markers = data.frame(
    name = c("r_heel", "r_toe"),
    stringsAsFactors = FALSE
  ))
  mock_model_left <- list(markers = data.frame(
    name = c("l_heel", "l_toe"),
    stringsAsFactors = FALSE
  ))
  # Right side should detect right-side markers
  schema_r <- create_schema_from_opensim(
    mock_model_right, "gait",
    available_signals = c("knee_angle_r"),
    side = "right"
  )
  expect_s3_class(schema_r, "TaskSchema")

  # Left side should detect left-side markers
  schema_l <- create_schema_from_opensim(
    mock_model_left, "gait",
    available_signals = c("knee_angle_l"),
    side = "left"
  )
  expect_s3_class(schema_l, "TaskSchema")
})

# --- .find_signal_match ---

test_that(".find_signal_match returns first matching signal", {
  signals <- c("hip_moment_r", "vgrf_right", "knee_angle_r")
  # Access internal function
  result <- PhysioMoCap:::.find_signal_match(signals, c("vgrf", "grf_y"))
  expect_equal(result, "vgrf_right")
})

test_that(".find_signal_match returns first pattern as fallback", {
  signals <- c("emg_tibant", "emg_gastroc")
  result <- PhysioMoCap:::.find_signal_match(signals, c("vgrf", "grf_y"))
  expect_equal(result, "vgrf")
})

test_that(".find_signal_match handles NULL and empty signals", {
  result_null <- PhysioMoCap:::.find_signal_match(NULL, c("vgrf", "grf_y"))
  expect_equal(result_null, "vgrf")

  result_empty <- PhysioMoCap:::.find_signal_match(character(0), c("vgrf", "grf_y"))
  expect_equal(result_empty, "vgrf")
})

# --- batch_analyze_opensim ---

test_that("batch_analyze_opensim requires signalIO package", {
  skip_if(requireNamespace("signalIO", quietly = TRUE),
          "signalIO is installed, skip missing-package test")
  schema <- TaskSchema(
    task_type = "test", task_label = "Test",
    events = list(
      Event("start", "Start", "manual", list(), typical_timing = 0),
      Event("end", "End", "manual", list(), typical_timing = 100)
    ),
    phases = list(Phase("main", "Main", "start", "end")),
    normalization = "cycle"
  )
  expect_error(
    batch_analyze_opensim("/nonexistent/path", schema),
    "signalIO"
  )
})

test_that("batch_analyze_opensim validates schema argument", {
  skip_if_not_installed("signalIO")
  expect_error(
    batch_analyze_opensim("/some/path", "not_a_schema"),
    "TaskSchema"
  )
})

# --- Schema validation ---

test_that("opensim schemas pass validateSchema", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel", "r_toe"),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("vgrf_r"),
    side = "right"
  )
  expect_true(validateSchema(schema))
})

test_that("opensim gait schema has expected vis_defaults", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel"),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("vgrf_r"),
    side = "right"
  )
  expect_equal(schema$vis_defaults$xlab, "Gait Cycle (%)")
  expect_true(schema$vis_defaults$show_phases)
  expect_true(schema$vis_defaults$show_events)
})

test_that("opensim jump schema uses phase normalization", {
  mock_model <- list(markers = data.frame(name = character(0)))
  schema <- create_schema_from_opensim(
    mock_model, "jump",
    available_signals = c("grf_y")
  )
  expect_equal(schema$normalization, "phase")
})

# --- Model with NULL markers ---

test_that("create_schema_from_opensim handles model without markers", {
  mock_model <- list()  # No markers field
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = c("vgrf_r"),
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  # GRF still available, should use threshold detection
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "threshold")
})

test_that("create_schema_from_opensim with NULL available_signals", {
  mock_model <- list(markers = data.frame(
    name = c("r_heel"),
    stringsAsFactors = FALSE
  ))
  schema <- create_schema_from_opensim(
    mock_model, "gait",
    available_signals = NULL,
    side = "right"
  )
  expect_s3_class(schema, "TaskSchema")
  # No GRF, but has heel marker -> peak detection
  hs1 <- getEvent(schema, "hs1")
  expect_equal(hs1$detection_method, "peak")
})
