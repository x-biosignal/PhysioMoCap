# Run OpenSim CLI Toolchain via PhysioOpenSim

Executes OpenSim setup XML files sequentially through `PhysioOpenSim`.

## Usage

``` r
run_opensim_toolchain(
  ik_setup = NULL,
  id_setup = NULL,
  so_setup = NULL,
  rra_setup = NULL,
  cmc_setup = NULL,
  analyze_setup = NULL,
  workdir = NULL,
  cli = NULL,
  timeout_sec = 0L,
  fail_on_error = TRUE,
  extra_args = character()
)
```

## Arguments

- ik_setup:

  Optional path to IK setup XML.

- id_setup:

  Optional path to ID setup XML.

- so_setup:

  Optional path to SO setup XML.

- rra_setup:

  Optional path to RRA setup XML.

- cmc_setup:

  Optional path to CMC setup XML.

- analyze_setup:

  Optional path to Analyze setup XML.

- workdir:

  Optional working directory for all tool runs.

- cli:

  Optional OpenSim CLI command/path.

- timeout_sec:

  Timeout in seconds for each tool execution.

- fail_on_error:

  If `TRUE`, abort when any tool returns non-zero status.

- extra_args:

  Optional character vector appended to every tool run.

## Value

Named list with entries for tools that were executed (`ik`, `id`, `so`,
`rra`, `cmc`, `analyze`).

## Details

Requires a native OpenSim installation and tool setup XML files, so the
example cannot run offline and is not executed.

## See also

[`batch_analyze_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/batch_analyze_opensim.md),
[`create_schema_from_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/create_schema_from_opensim.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires a native OpenSim installation and OpenSim setup XML files.
run_opensim_toolchain(ik_setup = "ik_setup.xml")
} # }
```
