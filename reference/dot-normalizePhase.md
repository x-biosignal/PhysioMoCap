# Phase-based normalization

Normalizes each phase independently to the same length.

## Usage

``` r
.normalizePhase(x, norm_length, schema = NULL, events = NULL, ...)
```

## Arguments

- x:

  Data (segmented_phases preferred)

- norm_length:

  Target length per phase

- schema:

  TaskSchema object

- events:

  detected_events object

- ...:

  Additional arguments

## Value

Normalized data
