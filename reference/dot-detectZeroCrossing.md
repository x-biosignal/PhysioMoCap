# Zero-crossing detection

Detects when a signal crosses zero.

## Usage

``` r
.detectZeroCrossing(signal, direction = "any", sr = 1000)
```

## Arguments

- signal:

  Numeric vector

- direction:

  "rising", "falling", or "any"

- sr:

  Sampling rate

## Value

List with index, time, confidence
