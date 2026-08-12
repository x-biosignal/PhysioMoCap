# Threshold-based event detection

Detects when a signal crosses a threshold value.

## Usage

``` r
.detectThreshold(
  signal,
  threshold,
  direction = "rising",
  sr = 1000,
  min_duration = 0.01
)
```

## Arguments

- signal:

  Numeric vector

- threshold:

  Threshold value (numeric or "bw-X%" for body weight relative)

- direction:

  "rising" (crosses from below), "falling" (crosses from above), or
  "any"

- sr:

  Sampling rate

- min_duration:

  Minimum duration above/below threshold (seconds)

## Value

List with index, time, confidence
