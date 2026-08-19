# OpenCap to OpenSim to downstream analysis

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore
```

This vignette connects [OpenCap](https://www.opencap.ai/) (markerless
motion capture from smartphone video) to OpenSim musculoskeletal
computation and on to downstream kinematic/kinetic analysis. There are
**two routes**, and they differ in whether they need a local OpenSim
install.

## Route A – use OpenCap’s cloud OpenSim output (self-contained)

OpenCap already runs OpenSim *in the cloud*: it scales a subject model
and solves inverse kinematics, returning the joint angles as a `.mot`
file. If you only need kinematics, pull that directly – **no local
OpenSim is required**.

``` r

# Joint angles already computed by OpenCap's cloud OpenSim pipeline
pe <- readOpenCap("abcd1234-5678-90ab-cdef-1234567890ab", data_type = "kinematics")

# ... straight into downstream analysis
angles <- calculateJointAngles(pe)
```

## Route B – run OpenSim locally (ID / muscle forces)

To go beyond kinematics – inverse dynamics (joint moments) or static
optimization (muscle activations/forces) – you run OpenSim yourself.
This is an **optional** path: it needs a working OpenSim backend and is
off by default.

### Enabling an OpenSim backend

`PhysioOpenSim` selects a backend automatically: a native library
compiled in, or the `opensim-cmd` command-line tool. The native bridge
is **disabled by default** so ordinary installs stay dependency-free;
opt in one of these ways:

``` r

# (a) put the OpenSim CLI on your PATH (no rebuild) -- e.g. from a conda install:
#     mamba install -c opensim-org opensim
# (b) build PhysioOpenSim against an OpenSim SDK (configure auto-detects it):
#     OPENSIM_HOME=/opt/opensim-core R CMD INSTALL PhysioOpenSim

PhysioOpenSim::opensimDiagnostics()   # backend: "native", "cli", or "none"
```

### From an OpenCap session, end to end

[`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md)
downloads the session’s scaled `.osim` model and marker `.trc`, then
runs the requested tools. **Inverse dynamics and static optimization
need ground-reaction forces**, which markerless OpenCap does not record
– supply a measured or estimated OpenSim `ExternalLoads` XML via
`external_loads_file`.

``` r

res <- runOpenSimFromOpenCap(
  session_id          = "abcd1234-5678-90ab-cdef-1234567890ab",
  tools               = c("ik", "id", "so"),
  external_loads_file = "walk_grf.xml"      # required for id/so
)

res$motion      # IK joint angles as a PhysioExperiment
res$outputs     # parsed .mot/.sto outputs (joint angles, moments, activations)
```

If you already have the model and markers locally (or want to reuse a
model across trials), call the lower half directly:

``` r

model <- downloadOpenCapModel("abcd1234-5678-90ab-cdef-1234567890ab")

res <- runOpenSimFromMarkers(
  model_file          = model,
  trc_file            = "walk.trc",
  tools               = c("ik", "id", "so"),
  external_loads_file = "walk_grf.xml"
)
```

Pass `dry_run = TRUE` to write and inspect the OpenSim setup XMLs
*without* a backend – useful for debugging or customising a template
before running.

### Downstream

The returned `PhysioExperiment` objects flow into the rest of the
ecosystem:

``` r

angles  <- calculateJointAngles(res$motion)
moments <- inverseDynamics3D(res$motion)          # or read res$outputs$id
# ... and on to gait indices, or statistical parametric mapping in PhysioAnalysis:
# PhysioAnalysis::spmAnova(...)
```

## Scope and honest limitations

- **Ground reactions.** OpenCap is video-only, so it has no force
  plates. Inverse dynamics / static optimization therefore require an
  external `ExternalLoads` file (measured GRF, or an estimate). Without
  one, only inverse kinematics runs; set
  `require_external_loads = FALSE` for kinematics-only inverse dynamics,
  which is valid only for non-contact phases (e.g. swing).
- **Model scaling.** `PhysioOpenSim` has no Scale tool; the
  subject-specific model comes from OpenCap
  ([`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md)).
- **CMC / RRA.** These need actuator and tracking-task files beyond what
  this wrapper infers. Run them with
  [`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md)
  together with
  [`PhysioOpenSim::opensimWriteCMCSetupFromTemplate()`](https://x-biosignal.github.io/PhysioOpenSim//reference/opensimWriteCMCSetupFromTemplate.html)
  / `opensimWriteRRASetupFromTemplate()`.
- **CI.** The actual OpenSim execution is exercised only where a backend
  is present; continuous integration installs no OpenSim, so those steps
  are skipped there by design.
