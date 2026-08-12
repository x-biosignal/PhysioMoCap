# Report summary statistics for detected gaps

Prints a human-readable summary of gap statistics including total number
of gaps, average gap size, and percentage of missing data.

## Usage

``` r
reportGaps(gaps, sampling_rate)
```

## Arguments

- gaps:

  A data.frame as returned by
  [`detectGaps`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md)

- sampling_rate:

  Sampling rate in Hz (used to report gap durations)

## Value

Invisibly returns a list with summary statistics:

- total_gaps - Total number of gaps

- avg_size - Average gap size in samples

- total_missing - Total number of missing samples

- pct_missing - Percentage of missing data (if computable)

## References

Federolf PA (2013). "A novel approach to solve the 'missing marker
problem' in marker-based motion analysis that does not require
additional assumptions about the biodynamic model." Journal of
Biomechanics, 46(13), 2173-2178.

## See also

[`detectGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md),
[`fillGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGaps.md),
[`fillGapsLinear()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsLinear.md)

## Examples

``` r
gaps <- data.frame(
  channel = c("M1", "M1", "M2"),
  start = c(10, 50, 20),
  end = c(15, 55, 30),
  size = c(6, 6, 11)
)
reportGaps(gaps, sampling_rate = 120)
#> Gap Report
#>   Total gaps:       3
#>   Average size:     7.7 samples (0.0639 s)
#>   Total missing:    23 samples
#>   Channels affected: 2
```
