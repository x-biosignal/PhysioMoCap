# Peak-based event detection

Detects local maxima or minima in a signal.

## Usage

``` r
.detectPeak(signal, type = "max", prominence = NULL, sr = 1000)
```

## Arguments

- signal:

  Numeric vector

- type:

  "max" for maximum, "min" for minimum

- prominence:

  Minimum prominence of peak (NULL for global max/min)

- sr:

  Sampling rate

## Value

List with index, time, confidence
