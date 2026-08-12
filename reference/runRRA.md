# Run Residual Reduction Algorithm (RRA) via OpenSim

Orchestrates the OpenSim Residual Reduction Algorithm through
PhysioOpenSim. RRA has no pure-R fallback, so it requires a working
OpenSim backend.

## Usage

``` r
runRRA(
  rra_setup,
  workdir = NULL,
  cli = NULL,
  timeout_sec = 0L,
  fail_on_error = TRUE
)
```

## Arguments

- rra_setup:

  Path to an OpenSim RRA setup XML.

- workdir, cli, timeout_sec, fail_on_error:

  Passed to
  [`PhysioOpenSim::opensimRunRRA()`](https://x-biosignal.github.io/PhysioOpenSim//reference/opensimRunRRA.html).

## Value

An `opensim_tool_result` list with `tool` (the PhysioOpenSim result).

## See also

[`runStaticOptimization()`](https://x-biosignal.github.io/PhysioMoCap/reference/runStaticOptimization.md),
[`runCMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/runCMC.md)
