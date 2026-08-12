# Angle-based event detection

Detects when an angular signal reaches a specific value.

## Usage

``` r
.detectAngle(signal, value, sr = 1000, tolerance = 5)
```

## Arguments

- signal:

  Numeric vector (angle in degrees)

- value:

  Target angle value

- sr:

  Sampling rate

- tolerance:

  Tolerance for matching (degrees)

## Value

List with index, time, confidence
