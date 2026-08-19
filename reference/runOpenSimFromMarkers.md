# Run the local OpenSim toolchain from a model and marker file

Convenience wrapper that wires markers through OpenSim inverse
kinematics (IK) and, optionally, inverse dynamics (ID) and static
optimization (SO): it writes the tool setup XMLs from the bundled
PhysioOpenSim templates, runs them in order via
[`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md),
and parses the results with
[`readOpenSimOutputs()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenSimOutputs.md)
into a downstream-ready form. This is the local counterpart to using
OpenCap's cloud kinematics directly.

## Usage

``` r
runOpenSimFromMarkers(
  model_file,
  trc_file,
  tools = c("ik", "id", "so"),
  external_loads_file = NULL,
  time_range = NULL,
  workdir = NULL,
  templates = NULL,
  cli = NULL,
  require_external_loads = TRUE,
  dry_run = FALSE
)
```

## Arguments

- model_file:

  Path to a scaled OpenSim `.osim` model (e.g. from
  [`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md)).

- trc_file:

  Path to a marker trajectory `.trc` file.

- tools:

  Which tools to run, a subset of `"ik"`, `"id"`, `"so"` (IK is always
  required and run first). Default `"ik"`.

- external_loads_file:

  Path to an OpenSim `ExternalLoads` XML (ground reactions). Required
  for `"id"`/`"so"` unless `require_external_loads` is `FALSE`.

- time_range:

  Optional numeric `c(start, end)` (s) applied to every tool.

- workdir:

  Directory for setup XMLs and outputs (a temporary directory by
  default).

- templates:

  Optional named list of template paths (`ik`/`id`/`so`); defaults to
  the templates bundled with PhysioOpenSim.

- cli:

  Optional path to the `opensim-cmd` CLI (see
  [`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md)).

- require_external_loads:

  If `TRUE` (default) error when `"id"`/`"so"` are requested without
  `external_loads_file`.

- dry_run:

  If `TRUE`, only write the setup XMLs and return them without a working
  OpenSim backend (useful for inspection/testing). Default `FALSE`.

## Value

An `opensim_run` list: `setups` (written XML paths), `workdir`,
`expected_outputs`; and, when run, `toolchain` (raw
[`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md)
result), `files` (produced `.mot`/`.sto`), `outputs` (their parsed
`PhysioExperiment` objects from
[`readOpenSimOutputs()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenSimOutputs.md)),
`motion` (the IK joint-angle object), and `backend`.

## Details

IK needs only the scaled model and markers. **ID and SO additionally
need ground-reaction data** (`external_loads_file`); markerless OpenCap
has no force plates, so you must supply a measured or estimated
`ExternalLoads` XML (or set `require_external_loads = FALSE` to run
kinematics-only inverse dynamics, which is valid only for non-contact
phases such as swing). CMC and RRA need actuator/tracking-task files
beyond what this wrapper infers; run them via
[`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md)
with the corresponding `PhysioOpenSim::opensimWrite*SetupFromTemplate()`
writers.

## See also

[`runOpenSimFromOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/runOpenSimFromOpenCap.md),
[`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md),
[`readOpenSimOutputs()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenSimOutputs.md),
[`downloadOpenCapModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/downloadOpenCapModel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- runOpenSimFromMarkers(
  model_file = "subject_scaled.osim", trc_file = "walk.trc",
  tools = c("ik", "id", "so"), external_loads_file = "walk_grf.xml")
res$motion            # IK joint angles (PhysioExperiment)
calculateJointAngles(res$motion)
} # }
```
