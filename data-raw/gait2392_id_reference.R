#!/usr/bin/env Rscript
# OpenSim gait2392 inverse-dynamics reference generator for PhysioMoCap (WSCB-12).
#
# Produces inst/extdata/gait2392_id_reference.rds, the INDEPENDENT cross-tool
# fixture that test-inverse-dynamics.R uses to validate inverseDynamicsRNE()
# against OpenSim's InverseDynamicsTool (not against the package itself).
#
# Provenance
# ----------
#   Data   : opensim-org/opensim-models @ d9b05d47, Pipelines/Gait2392_Simbody
#            (Apache-2.0). Scaled model subject01_simbody.osim, trial
#            subject01_walk1 (walking), right leg, time range 0.40-1.60 s.
#   Tool   : OpenSim 4.6 InverseDynamicsTool, coordinates low-pass filtered at
#            6 Hz, muscles excluded, external GRF loads applied to calcn_r/l.
#   Frame  : sagittal plane, ground X = anterior, Y = vertical (metres).
#
# The reference joint moments ($reference) are OpenSim's own ID output. The
# joint-centre positions ($joints) and segment inertia ($inertia) are derived
# from the SAME model and 6 Hz-filtered kinematics, so the RNE and OpenSim see
# a consistent problem. On this fixture the RNE reproduces OpenSim to
# r > 0.99 and < 8% peak error for hip / knee / ankle.
#
# Two-step pipeline (OpenSim is only needed for step 1):
#   1. OpenSim/Python extraction  -> CSV/JSON in a working directory:
#        micromamba run -n opensim python \
#          data-raw/gait2392_id_reference_extract.py
#      (edit WD/paths in the .py; it downloads the pinned inputs itself or
#       reads them from a local checkout of the pinned commit).
#   2. This script assembles the .rds from those CSV/JSON outputs.
#
# Run step 2 from the package root, pointing WD at step 1's output directory:
#   WD=/path/to/extraction/outputs \
#     Rscript data-raw/gait2392_id_reference.R

WD <- Sys.getenv("WD", "/tmp/wscb12")
stopifnot(dir.exists(WD))

joints  <- read.csv(file.path(WD, "joints.csv"))
grf     <- read.csv(file.path(WD, "grf.csv"))
ref     <- read.csv(file.path(WD, "reference.csv"))
inertia <- jsonlite::fromJSON(file.path(WD, "inertia.json"))
meta    <- jsonlite::fromJSON(file.path(WD, "meta.json"))

inertia <- inertia[, c("segment", "length", "mass",
                       "com_proximal_fraction", "inertia")]
joints <- joints[, c("ankle_x", "ankle_y", "toe_x", "toe_y",
                     "knee_x", "knee_y", "hip_x", "hip_y")]
grf <- grf[, c("fx", "fy", "cop_x", "cop_y")]

fixture <- list(
  joints        = joints,
  grf           = grf,
  inertia       = inertia,
  sampling_rate = round(meta$sampling_rate, 6),
  reference = list(
    hip_moment   = ref$hip_moment,
    knee_moment  = ref$knee_moment,
    ankle_moment = ref$ankle_moment
  ),
  provenance = list(
    description = paste(
      "OpenSim gait2392 inverse-dynamics reference (right leg, subject01_walk1).",
      "$reference: OpenSim ID joint moments (N.m). $joints: sagittal",
      "joint-centre positions (ground X=anterior, Y=vertical, m). $inertia:",
      "segment mass/COM/Izz from the scaled model."),
    source_repo     = "github.com/opensim-org/opensim-models",
    source_commit   = "d9b05d470b1a481c222372c85b75772faf8f7792",
    source_path     = "Pipelines/Gait2392_Simbody",
    model           = "subject01_simbody.osim (scaled gait2392)",
    trial           = "subject01_walk1",
    time_range_s    = c(0.414, 1.598),
    lowpass_hz      = 6,
    tool            = "OpenSim InverseDynamicsTool",
    opensim_version = "4.6",
    leg             = "right",
    license         = "OpenSim example data, Apache-2.0 (opensim-models)",
    generated_by    = "data-raw/gait2392_id_reference.R"
  )
)

out <- file.path("inst", "extdata", "gait2392_id_reference.rds")
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
saveRDS(fixture, out, version = 2, compress = "xz")
message(sprintf("wrote %s (%d frames, %.1f Hz, %d bytes)",
                out, nrow(joints), fixture$sampling_rate, file.info(out)$size))
