# Pre-built Task Schemas for Common Movement Tasks
# These schemas provide ready-to-use definitions for common biomechanics analyses

#' Pre-built Gait Cycle Schema
#'
#' Task schema for walking gait analysis with standard events and phases.
#'
#' @format A TaskSchema object with:
#' \describe{
#'   \item{events}{Heel strike (x2), foot flat, midstance, heel off, toe off}
#'   \item{phases}{Stance (with loading, midstance, propulsion subphases), Swing}
#'   \item{normalization}{cycle (0-100%)}
#' }
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [getSchema()], [schema_running]
#'
#' @examples
#' print(schema_gait)
#' getEventNames(schema_gait)
#' getPhaseNames(schema_gait)
#'
#' @export
schema_gait <- TaskSchema(
  task_type = "gait",
  task_label = "Gait Cycle",

  events = list(
    Event("hs1", "Heel Strike", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "rising"),
          typical_timing = 0),
    Event("ff", "Foot Flat", "peak",
          list(signal = "ankle_angle", type = "max"),
          typical_timing = 12),
    Event("ms", "Midstance", "zero_crossing",
          list(signal = "ankle_moment"),
          typical_timing = 30),
    Event("ho", "Heel Off", "threshold",
          list(signal = "heel_marker_z", threshold = 0.02, direction = "rising"),
          typical_timing = 40),
    Event("to", "Toe Off", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "falling"),
          typical_timing = 60),
    Event("hs2", "Heel Strike 2", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "rising"),
          typical_timing = 100)
  ),

  phases = list(
    Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8",
          subphases = list(
            Phase("loading", "Loading Response", "hs1", "ff", color = "#B8D4E3"),
            Phase("midstance", "Midstance", "ff", "ho", color = "#A8C4D3"),
            Phase("propulsion", "Propulsion", "ho", "to", color = "#98B4C3")
          )),
    Phase("swing", "Swing Phase", "to", "hs2", color = "#FFF4E8")
  ),

  normalization = "cycle",
  norm_length = 101L,

  metrics = c("peak_flexion", "peak_extension", "rom", "peak_moment",
              "peak_power", "stance_time", "swing_time", "stance_ratio",
              "step_length", "stride_length", "cadence", "velocity",
              "symmetry_index", "gait_deviation_index"),

  vis_defaults = list(
    xlab = "Gait Cycle (%)",
    ylab = "Value",
    show_phases = TRUE,
    show_events = TRUE,
    phase_alpha = 0.3
  )
)


#' Pre-built Running Schema
#'
#' Task schema for running gait analysis.
#'
#' @format A TaskSchema object with running-specific events and phases.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_jump]
#'
#' @examples
#' print(schema_running)
#'
#' @export
schema_running <- TaskSchema(
  task_type = "running",
  task_label = "Running Cycle",

  events = list(
    Event("ic1", "Initial Contact", "threshold",
          list(signal = "vGRF", threshold = 50, direction = "rising"),
          typical_timing = 0),
    Event("ms", "Midstance", "peak",
          list(signal = "vGRF", type = "max"),
          typical_timing = 20),
    Event("to", "Toe Off", "threshold",
          list(signal = "vGRF", threshold = 50, direction = "falling"),
          typical_timing = 40),
    Event("ms_swing", "Mid-Swing", "peak",
          list(signal = "knee_angle", type = "max"),
          typical_timing = 70),
    Event("ic2", "Initial Contact 2", "threshold",
          list(signal = "vGRF", threshold = 50, direction = "rising"),
          typical_timing = 100)
  ),

  phases = list(
    Phase("stance", "Stance Phase", "ic1", "to", color = "#E8F8E8",
          subphases = list(
            Phase("absorption", "Absorption", "ic1", "ms", color = "#C8E8C8"),
            Phase("propulsion", "Propulsion", "ms", "to", color = "#A8D8A8")
          )),
    Phase("swing", "Swing Phase", "to", "ic2", color = "#F8E8F8",
          subphases = list(
            Phase("early_swing", "Early Swing", "to", "ms_swing", color = "#F8D8F8"),
            Phase("late_swing", "Late Swing", "ms_swing", "ic2", color = "#F8C8F8")
          ))
  ),

  normalization = "cycle",
  norm_length = 101L,

  metrics = c("contact_time", "flight_time", "duty_factor", "step_frequency",
              "step_length", "vertical_oscillation", "leg_stiffness",
              "peak_vgrf", "loading_rate", "braking_impulse", "propulsive_impulse"),

  vis_defaults = list(
    xlab = "Running Cycle (%)",
    show_phases = TRUE,
    show_events = TRUE,
    phase_alpha = 0.3
  )
)


#' Pre-built Jump Schema
#'
#' Task schema for vertical jump analysis (countermovement, drop jump, etc.).
#'
#' @format A TaskSchema object with jump-specific events and phases.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_throw]
#'
#' @examples
#' print(schema_jump)
#'
#' @export
schema_jump <- TaskSchema(
  task_type = "jump",
  task_label = "Jump",

  events = list(
    Event("start", "Movement Start", "threshold",
          list(signal = "vGRF", threshold = "bw-10%", direction = "falling"),
          typical_timing = 0),
    Event("unweighting_end", "Unweighting End", "peak",
          list(signal = "vGRF", type = "min"),
          typical_timing = 15),
    Event("takeoff", "Takeoff", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "falling"),
          typical_timing = 35),
    Event("peak_height", "Peak Height", "peak",
          list(signal = "com_z", type = "max"),
          typical_timing = 55),
    Event("landing", "Landing", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "rising"),
          typical_timing = 75),
    Event("peak_grf", "Peak Landing GRF", "peak",
          list(signal = "vGRF", type = "max"),
          typical_timing = 80),
    Event("stabilization", "Stabilization", "threshold",
          list(signal = "com_velocity", threshold = 0.05, direction = "falling"),
          typical_timing = 100)
  ),

  phases = list(
    Phase("unweighting", "Unweighting", "start", "unweighting_end", color = "#E8E8F8"),
    Phase("propulsion", "Propulsion", "unweighting_end", "takeoff", color = "#E8F8E8"),
    Phase("flight", "Flight", "takeoff", "landing", color = "#F8F8E8"),
    Phase("landing", "Landing", "landing", "stabilization", color = "#F8E8E8",
          subphases = list(
            Phase("impact", "Impact Absorption", "landing", "peak_grf", color = "#F8D8D8"),
            Phase("recovery", "Recovery", "peak_grf", "stabilization", color = "#F8E8E8")
          ))
  ),

  normalization = "phase",
  norm_length = 101L,

  metrics = c("jump_height", "peak_power", "mean_power", "peak_velocity",
              "peak_grf_takeoff", "rfd", "contact_time", "flight_time",
              "rsi", "peak_grf_landing", "loading_rate_landing",
              "knee_flexion_landing", "landing_stiffness"),

  vis_defaults = list(
    xlab = "Movement Phase (%)",
    show_phases = TRUE,
    show_events = TRUE,
    phase_alpha = 0.3
  )
)


#' Pre-built Throwing Schema
#'
#' Task schema for throwing motion analysis (baseball, softball, etc.).
#'
#' @format A TaskSchema object with throwing-specific events and phases.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_cutting]
#'
#' @examples
#' print(schema_throw)
#'
#' @export
schema_throw <- TaskSchema(
  task_type = "throw",
  task_label = "Throwing Motion",

  events = list(
    Event("windup_start", "Wind-up Start", "velocity_threshold",
          list(signal = "shoulder_velocity", threshold = 50, direction = "rising"),
          typical_timing = 0),
    Event("lead_leg_max", "Lead Leg Max Height", "peak",
          list(signal = "lead_knee_height", type = "max"),
          typical_timing = 25),
    Event("stride_foot", "Stride Foot Contact", "threshold",
          list(signal = "lead_foot_grf", threshold = 10, direction = "rising"),
          typical_timing = 45),
    Event("max_er", "Max External Rotation", "peak",
          list(signal = "shoulder_external_rotation", type = "max"),
          typical_timing = 75),
    Event("release", "Ball Release", "peak",
          list(signal = "wrist_velocity", type = "max"),
          typical_timing = 82),
    Event("max_ir", "Max Internal Rotation", "peak",
          list(signal = "shoulder_internal_rotation", type = "max"),
          typical_timing = 92),
    Event("follow_through", "Follow Through End", "velocity_threshold",
          list(signal = "arm_velocity", threshold = 100, direction = "falling"),
          typical_timing = 100)
  ),

  phases = list(
    Phase("windup", "Wind-up", "windup_start", "lead_leg_max", color = "#E8E8F8"),
    Phase("stride", "Stride", "lead_leg_max", "stride_foot", color = "#E8F8E8"),
    Phase("cocking", "Arm Cocking", "stride_foot", "max_er", color = "#F8F8E8"),
    Phase("acceleration", "Arm Acceleration", "max_er", "release", color = "#F8E8E8"),
    Phase("deceleration", "Arm Deceleration", "release", "max_ir", color = "#F8E8F8"),
    Phase("follow_through", "Follow Through", "max_ir", "follow_through", color = "#E8F8F8")
  ),

  normalization = "landmark",
  norm_length = 101L,

  metrics = c("ball_velocity", "shoulder_er_velocity", "shoulder_ir_velocity",
              "elbow_extension_velocity", "trunk_rotation_velocity",
              "shoulder_distraction_force", "elbow_valgus_torque",
              "stride_length", "trunk_tilt", "lead_knee_flexion"),

  vis_defaults = list(
    xlab = "Throwing Phase (%)",
    show_phases = TRUE,
    show_events = TRUE,
    landmark_event = "release",
    phase_alpha = 0.3
  )
)


#' Pre-built Balance Schema
#'
#' Task schema for postural control/balance analysis.
#'
#' @format A TaskSchema object for continuous balance assessment.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_cutting]
#'
#' @examples
#' print(schema_balance)
#'
#' @export
schema_balance <- TaskSchema(
  task_type = "balance",
  task_label = "Postural Control",

  events = list(),
  phases = list(),

  normalization = "absolute",
  norm_length = NULL,

  metrics = c("cop_velocity_ap", "cop_velocity_ml", "cop_velocity_resultant",
              "cop_path_length", "cop_area_95", "cop_area_ce",
              "cop_range_ap", "cop_range_ml",
              "sway_frequency_ap", "sway_frequency_ml",
              "sample_entropy_ap", "sample_entropy_ml",
              "dfa_alpha_ap", "dfa_alpha_ml",
              "time_to_boundary_ap", "time_to_boundary_ml"),

  vis_defaults = list(
    xlab = "Time (s)",
    ylab = "Position (mm)",
    plot_type = "trajectory",
    show_ellipse = TRUE,
    show_phases = FALSE,
    show_events = FALSE
  )
)


#' Pre-built Cutting/Change of Direction Schema
#'
#' Task schema for cutting and change of direction analysis.
#'
#' @format A TaskSchema object with COD-specific events and phases.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_running]
#'
#' @examples
#' print(schema_cutting)
#'
#' @export
schema_cutting <- TaskSchema(
  task_type = "cutting",
  task_label = "Change of Direction",

  events = list(
    Event("approach", "Approach Start", "velocity_threshold",
          list(signal = "com_velocity", threshold = 2.0, direction = "rising"),
          typical_timing = 0),
    Event("penultimate", "Penultimate Contact", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "rising"),
          typical_timing = 50),
    Event("penultimate_to", "Penultimate Toe Off", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "falling"),
          typical_timing = 65),
    Event("plant", "Plant Foot Contact", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "rising"),
          typical_timing = 70),
    Event("peak_flex", "Peak Knee Flexion", "peak",
          list(signal = "knee_angle", type = "max"),
          typical_timing = 80),
    Event("push_off", "Push Off", "threshold",
          list(signal = "vGRF", threshold = 10, direction = "falling"),
          typical_timing = 90),
    Event("reaccel", "Re-acceleration", "velocity_threshold",
          list(signal = "com_velocity", threshold = 2.0, direction = "rising"),
          typical_timing = 100)
  ),

  phases = list(
    Phase("approach", "Approach", "approach", "penultimate", color = "#E8F8E8"),
    Phase("penultimate", "Penultimate Step", "penultimate", "penultimate_to", color = "#F8F8E8"),
    Phase("weight_acceptance", "Weight Acceptance", "plant", "peak_flex", color = "#F8E8E8"),
    Phase("push_off", "Push Off", "peak_flex", "push_off", color = "#E8E8F8"),
    Phase("reacceleration", "Re-acceleration", "push_off", "reaccel", color = "#F8E8F8")
  ),

  normalization = "phase",
  norm_length = 101L,

  metrics = c("approach_velocity", "exit_velocity", "velocity_deficit",
              "deceleration_impulse", "braking_force", "medial_force",
              "peak_knee_flexion", "peak_knee_abduction", "trunk_lean",
              "contact_time", "penultimate_contact_time",
              "cutting_angle", "completion_time"),

  vis_defaults = list(
    xlab = "COD Phase (%)",
    show_phases = TRUE,
    show_events = TRUE,
    phase_alpha = 0.3
  )
)


#' Pre-built Cycling Schema
#'
#' Task schema for cycling pedal stroke analysis.
#'
#' @format A TaskSchema object with cycling-specific events and phases.
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [TaskSchema()], [schema_gait], [schema_running]
#'
#' @examples
#' print(schema_cycling)
#'
#' @export
schema_cycling <- TaskSchema(
  task_type = "cycling",
  task_label = "Pedal Cycle",

  events = list(
    Event("tdc", "Top Dead Center", "angle",
          list(signal = "crank_angle", value = 0),
          typical_timing = 0),
    Event("power_start", "Power Phase Start", "angle",
          list(signal = "crank_angle", value = 15),
          typical_timing = 4),
    Event("peak_torque", "Peak Torque", "peak",
          list(signal = "crank_torque", type = "max"),
          typical_timing = 25),
    Event("bdc", "Bottom Dead Center", "angle",
          list(signal = "crank_angle", value = 180),
          typical_timing = 50),
    Event("recovery_mid", "Recovery Midpoint", "angle",
          list(signal = "crank_angle", value = 270),
          typical_timing = 75),
    Event("tdc2", "Top Dead Center 2", "angle",
          list(signal = "crank_angle", value = 360),
          typical_timing = 100)
  ),

  phases = list(
    Phase("extension", "Extension/Power", "tdc", "bdc", color = "#E8F8E8",
          subphases = list(
            Phase("early_extension", "Early Extension", "tdc", "peak_torque", color = "#C8E8C8"),
            Phase("late_extension", "Late Extension", "peak_torque", "bdc", color = "#A8D8A8")
          )),
    Phase("flexion", "Flexion/Recovery", "bdc", "tdc2", color = "#F8E8E8",
          subphases = list(
            Phase("early_flexion", "Early Flexion", "bdc", "recovery_mid", color = "#F8D8D8"),
            Phase("late_flexion", "Late Flexion", "recovery_mid", "tdc2", color = "#F8C8C8")
          ))
  ),

  normalization = "cycle",
  norm_length = 361L,  # 0-360 degrees

  metrics = c("peak_torque", "mean_torque", "peak_power", "mean_power",
              "cadence", "index_of_effectiveness", "dead_spot_score",
              "power_asymmetry", "torque_effectiveness", "pedal_smoothness",
              "peak_force_angle", "peak_force_magnitude"),

  vis_defaults = list(
    xlab = "Crank Angle (\u00B0)",
    show_phases = TRUE,
    show_events = TRUE,
    phase_alpha = 0.3
  )
)


#' Get list of all pre-built schemas
#'
#' @return Named list of all available pre-built TaskSchema objects
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [getSchema()], [TaskSchema()], [validateSchema()]
#'
#' @export
#'
#' @examples
#' schemas <- listSchemas()
#' names(schemas)
listSchemas <- function() {
  list(
    gait = schema_gait,
    running = schema_running,
    jump = schema_jump,
    throw = schema_throw,
    balance = schema_balance,
    cutting = schema_cutting,
    cycling = schema_cycling
  )
}


#' Get a pre-built schema by name
#'
#' @param name Name of the schema ("gait", "running", "jump", "throw",
#'   "balance", "cutting", "cycling")
#' @return A TaskSchema object
#'
#' @references
#' Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
#' 4th ed. Wiley.
#'
#' @seealso [listSchemas()], [TaskSchema()], [validateSchema()]
#'
#' @export
#'
#' @examples
#' gait <- getSchema("gait")
#' jump <- getSchema("jump")
getSchema <- function(name) {
  schemas <- listSchemas()
  if (!name %in% names(schemas)) {
    stop(sprintf("Unknown schema '%s'. Available: %s",
                 name, paste(names(schemas), collapse = ", ")),
         call. = FALSE)
  }
  schemas[[name]]
}
