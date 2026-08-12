# Sample entropy (Richman & Moorman)

Sample entropy quantifies the irregularity of a time series as the
negative natural log of the conditional probability that sequences
similar for `m` points remain similar at the next point, within
tolerance `r` (self-matches excluded). Larger values indicate greater
irregularity/complexity; a perfectly regular signal tends to zero.

## Usage

``` r
sampleEntropy(x, m = 2L, r = 0.2, normalize = TRUE)
```

## Arguments

- x:

  Numeric time series.

- m:

  Embedding (template) length (default 2).

- r:

  Similarity tolerance. If `normalize = TRUE` (default) it is a multiple
  of the series standard deviation (default `0.2`).

- normalize:

  If `TRUE`, `r` is scaled by `sd(x)`.

## Value

A single numeric sample-entropy value (`Inf` if no length-`m+1` matches
occur).

## References

Richman JS, Moorman JR (2000). Am J Physiol 278(6):H2039-H2049.

## See also

[`maxLyapunovExponent()`](https://x-biosignal.github.io/PhysioMoCap/reference/maxLyapunovExponent.md)

## Examples

``` r
sampleEntropy(sin(seq(0, 40 * pi, length.out = 800)))  # ~0 (regular)
#> [1] 0.2275373
```
