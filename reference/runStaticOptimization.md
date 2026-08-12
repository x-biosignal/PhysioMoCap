# Run static optimization (OpenSim, or a pure-R fallback)

Resolves net joint moments into muscle activations. When an OpenSim
backend is available and a Static Optimization setup file is supplied,
it runs the OpenSim Static Optimization tool via PhysioOpenSim;
otherwise it falls back to
[`staticOptimizationR()`](https://x-biosignal.github.io/PhysioMoCap/reference/staticOptimizationR.md),
the pure-R quadratic muscle-effort solver, using the supplied moment
arms, maximum forces and joint moments.

## Usage

``` r
runStaticOptimization(
  so_setup = NULL,
  moment_arms = NULL,
  max_force = NULL,
  joint_moments = NULL,
  execution = c("auto", "opensim", "r"),
  workdir = NULL,
  cli = NULL,
  timeout_sec = 0L,
  fail_on_error = TRUE,
  ...
)
```

## Arguments

- so_setup:

  Path to an OpenSim Static Optimization setup XML (OpenSim backend).

- moment_arms, max_force, joint_moments:

  Inputs for the pure-R fallback, passed to
  [`staticOptimizationR()`](https://x-biosignal.github.io/PhysioMoCap/reference/staticOptimizationR.md).

- execution:

  Backend selection: `"auto"` (default; OpenSim when available and
  `so_setup` is given, else pure-R), `"opensim"`, or `"r"`.

- workdir, cli, timeout_sec, fail_on_error:

  Passed to
  [`PhysioOpenSim::opensimRunSO()`](https://x-biosignal.github.io/PhysioOpenSim//reference/opensimRunSO.html)
  for the OpenSim backend.

- ...:

  Additional arguments passed to
  [`staticOptimizationR()`](https://x-biosignal.github.io/PhysioMoCap/reference/staticOptimizationR.md)
  for the pure-R backend (e.g. `weights`, `activation_bounds`).

## Value

An `opensim_so_result` list with `backend` (`"opensim"` or `"r"`) and
either `tool` (the PhysioOpenSim tool result) or `static_optimization`
(the
[`staticOptimizationR()`](https://x-biosignal.github.io/PhysioMoCap/reference/staticOptimizationR.md)
result).

## See also

[`staticOptimizationR()`](https://x-biosignal.github.io/PhysioMoCap/reference/staticOptimizationR.md),
[`runRRA()`](https://x-biosignal.github.io/PhysioMoCap/reference/runRRA.md),
[`runCMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/runCMC.md)
