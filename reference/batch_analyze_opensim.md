# Batch analyze OpenSim session data

Loads an OpenSim session and performs batch movement analysis using a
TaskSchema for event detection and normalization.

## Usage

``` r
batch_analyze_opensim(
  session_dir,
  schema,
  signal_mapping = list(),
  trials = NULL,
  normalize_method = NULL,
  ...
)
```

## Arguments

- session_dir:

  Directory containing OpenSim output files, or an
  opensim_session/opensim_workflow object from signalIO

- schema:

  A TaskSchema object defining events and phases

- signal_mapping:

  Named list mapping schema signal names to actual channel names in the
  data

- trials:

  Character vector of trial names to analyze. If NULL, analyzes all.

- normalize_method:

  Override schema normalization method

- ...:

  Additional arguments passed to normalizeMovement

## Value

A list containing:

- trials: List of normalized trial data

- events: List of detected events per trial

- phases: List of phase timing per trial

- summary: Summary statistics across trials

## References

Delp SL, Anderson FC, Arnold AS, Loan P, Habib A, John CT, Guendelman E,
Thelen DG (2007). "OpenSim: Open-Source Software to Create and Analyze
Dynamic Simulations of Movement." IEEE Transactions on Biomedical
Engineering, 54(11), 1940-1950.

## See also

[`create_schema_from_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/create_schema_from_opensim.md)
for creating task schemas from OpenSim models.

## Examples

``` r
if (FALSE) { # \dontrun{
library(signalIO)

# Load session and analyze
results <- batch_analyze_opensim(
  "subject01/",
  schema = schema_gait,
  signal_mapping = list(vGRF = "ground_force_vy_r")
)

# Access normalized trials
trial1 <- results$trials[[1]]

# View summary
print(results$summary)
} # }
```
