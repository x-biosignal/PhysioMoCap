# Run Computed Muscle Control (CMC) via OpenSim

Orchestrates the OpenSim Computed Muscle Control tool through
PhysioOpenSim. CMC has no pure-R fallback, so it requires a working
OpenSim backend.

## Usage

``` r
runCMC(
  cmc_setup,
  workdir = NULL,
  cli = NULL,
  timeout_sec = 0L,
  fail_on_error = TRUE
)
```

## Arguments

- cmc_setup:

  Path to an OpenSim CMC setup XML.

- workdir, cli, timeout_sec, fail_on_error:

  Passed to
  [`PhysioOpenSim::opensimRunCMC()`](https://x-biosignal.github.io/PhysioOpenSim//reference/opensimRunCMC.html).

## Value

An `opensim_tool_result` list with `tool` (the PhysioOpenSim result).

## See also

[`runStaticOptimization()`](https://x-biosignal.github.io/PhysioMoCap/reference/runStaticOptimization.md),
[`runRRA()`](https://x-biosignal.github.io/PhysioMoCap/reference/runRRA.md)
