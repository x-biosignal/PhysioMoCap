# Create a TaskSchema from OpenSim model for gait analysis

Generates a TaskSchema based on an OpenSim model's markers and available
signal channels. This function creates appropriate event definitions
that can be used with
[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)
for automatic event detection.

## Usage

``` r
create_schema_from_opensim(
  model,
  task_type = c("gait", "running", "jump", "generic"),
  available_signals = NULL,
  side = "right"
)
```

## Arguments

- model:

  One of:

  - an OpenSim model object from signalIO's `read_osim()`,

  - a path to an `.osim` model file, or

  - a model summary list from
    [`PhysioOpenSim::opensimModelSummary()`](https://x-biosignal.github.io/PhysioOpenSim//reference/opensimModelSummary.html).

- task_type:

  Type of movement task: "gait", "running", "jump", "generic"

- available_signals:

  Character vector of signal names available in the data (e.g., from IK,
  ID, or GRF data)

- side:

  Character, which side to base events on: "right", "left", or "both"

## Value

A TaskSchema object configured for the specified task type

## Details

This function analyzes the model's markers and the available signals to
generate an appropriate TaskSchema. For gait analysis, it prefers
GRF-based detection if available, falling back to marker-based or
kinematic detection.

## References

Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
Dynamic Simulations of Movement." IEEE Transactions on Biomedical
Engineering, 54(11), 1940-1950.

## See also

[`batch_analyze_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/batch_analyze_opensim.md)
for batch processing of OpenSim sessions,
[`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)
for event detection using task schemas.

## Examples

``` r
if (FALSE) { # \dontrun{
library(signalIO)

# Load OpenSim model
model <- read_osim("gait2354.osim")

# Load IK results
ik <- read_mot("ik_results.mot")
ik_channels <- rownames(ik)

# Create gait schema with available channels
schema <- create_schema_from_opensim(model, "gait", ik_channels)
print(schema)

# Use schema for event detection
events <- detectEvents(data, schema)
} # }
```
