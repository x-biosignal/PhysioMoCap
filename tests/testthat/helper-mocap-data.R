# Helper functions for PhysioMoCap tests

#' Create test MoCap data (marker positions)
make_mocap_markers <- function(n_time = 500, n_markers = 10, sr = 120) {
  t <- seq(0, (n_time - 1) / sr, length.out = n_time)
  marker_names <- paste0("Marker", seq_len(n_markers))

  pos_x <- matrix(rnorm(n_time * n_markers), nrow = n_time, ncol = n_markers)
  pos_y <- matrix(rnorm(n_time * n_markers), nrow = n_time, ncol = n_markers)
  pos_z <- matrix(rnorm(n_time * n_markers), nrow = n_time, ncol = n_markers)

  colnames(pos_x) <- marker_names
  colnames(pos_y) <- marker_names
  colnames(pos_z) <- marker_names

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      position_x = pos_x,
      position_y = pos_y,
      position_z = pos_z
    ),
    colData = S4Vectors::DataFrame(
      label = marker_names,
      type = rep("marker", n_markers)
    ),
    samplingRate = sr
  )
}

#' Create test keypoint data (pose estimation)
make_keypoints <- function(n_frames = 100, n_keypoints = 17, sr = 30) {
  kp_names <- c("nose", "neck", "Rshoulder", "Relbow", "Rwrist",
                 "Lshoulder", "Lelbow", "Lwrist", "Rhip", "Rknee",
                 "Rankle", "Lhip", "Lknee", "Lankle", "Reye",
                 "Leye", "Rear")[seq_len(n_keypoints)]

  kp_x <- matrix(runif(n_frames * n_keypoints, 0, 1920), nrow = n_frames)
  kp_y <- matrix(runif(n_frames * n_keypoints, 0, 1080), nrow = n_frames)
  conf <- matrix(runif(n_frames * n_keypoints, 0.5, 1.0), nrow = n_frames)

  colnames(kp_x) <- kp_names
  colnames(kp_y) <- kp_names
  colnames(conf) <- kp_names

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(
      keypoint_x = kp_x,
      keypoint_y = kp_y,
      confidence = conf
    ),
    colData = S4Vectors::DataFrame(
      label = kp_names,
      type = rep("keypoint", n_keypoints)
    ),
    samplingRate = sr
  )
}

#' Create test joint angle data (OpenSim-like)
make_joint_angles <- function(n_time = 1000, sr = 100) {
  t <- seq(0, (n_time - 1) / sr, length.out = n_time)
  joint_names <- c("hip_flexion_r", "knee_angle_r", "ankle_angle_r",
                    "hip_flexion_l", "knee_angle_l", "ankle_angle_l")
  n_joints <- length(joint_names)

  angles <- matrix(NA_real_, nrow = n_time, ncol = n_joints)
  for (i in seq_len(n_joints)) {
    angles[, i] <- sin(2 * pi * t + i * 0.5) * 30 + rnorm(n_time, 0, 2)
  }
  colnames(angles) <- joint_names

  PhysioCore::PhysioExperiment(
    assays = S4Vectors::SimpleList(joint_angles = angles),
    colData = S4Vectors::DataFrame(
      label = joint_names,
      type = rep("joint_angle", n_joints),
      unit = rep("deg", n_joints)
    ),
    samplingRate = sr
  )
}

#' Create synthetic gait GRF signal for testing
make_gait_grf <- function(n_time = 1000, sr = 1000) {
  t <- seq(0, (n_time - 1) / sr, length.out = n_time)
  # Simulate one gait cycle with stance (GRF > 0) and swing (GRF = 0)
  stance_len <- round(n_time * 0.6)
  swing_len <- n_time - stance_len
  grf <- c(sin(seq(0, pi, length.out = stance_len)) * 800,
           rep(0, swing_len))
  grf <- grf + rnorm(n_time, 0, 5)
  grf[grf < 0] <- 0
  grf
}


#' Create a synthetic plantar-pressure movie
make_pressure_movie <- function(pressure, fs = 100, dx = 5, dy = 5,
                                side = "left", heel_first = TRUE) {
  pressureMovie(
    pressure,
    sampling_rate = fs,
    dx = dx,
    dy = dy,
    side = side,
    heel_first = heel_first
  )
}
