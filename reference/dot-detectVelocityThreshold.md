# Velocity threshold detection

Detects when the derivative of a signal crosses a threshold.

## Usage

``` r
.detectVelocityThreshold(signal, threshold, direction = "rising", sr = 1000)
```

## Arguments

- signal:

  Numeric vector

- threshold:

  Velocity threshold

- direction:

  "rising" or "falling"

- sr:

  Sampling rate

## Value

List with index, time, confidence
