# Landmark-based normalization

Aligns data to a specific event (landmark).

## Usage

``` r
.normalizeLandmark(
  x,
  norm_length,
  events = NULL,
  schema = NULL,
  landmark_event = NULL,
  window_before = NULL,
  window_after = NULL,
  ...
)
```

## Arguments

- x:

  Data

- norm_length:

  Target length

- events:

  detected_events object

- schema:

  TaskSchema object

- landmark_event:

  Name of event to align to

- window_before:

  Samples/percent before landmark

- window_after:

  Samples/percent after landmark

- ...:

  Additional arguments

## Value

Normalized data
