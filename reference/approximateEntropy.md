# Approximate entropy (Pincus)

The regularity of a time series: the (negative) log-likelihood that
patterns close for `m` samples stay close for `m + 1`. Lower = more
regular/predictable, higher = more irregular. The ApEn complement to the
package's sample entropy (ApEn includes self-matches and is more biased
for short series, but is the classical measure).

## Usage

``` r
approximateEntropy(x, m = 2L, r = NULL)
```

## Arguments

- x:

  Numeric time series.

- m:

  Pattern length (default 2).

- r:

  Tolerance; if `NULL`, `0.2 * sd(x)`.

## Value

the approximate entropy (scalar).

## References

Pincus SM (1991) PNAS 88:2297-2301.

## See also

[`recurrenceQuantification()`](https://x-biosignal.github.io/PhysioMoCap/reference/recurrenceQuantification.md),
[`sampleEntropy()`](https://x-biosignal.github.io/PhysioMoCap/reference/sampleEntropy.md)

## Examples

``` r
t <- seq(0, 20 * pi, length.out = 500)
approximateEntropy(sin(t))                          # low (regular)
#> [1] 0.2403023
set.seed(1); approximateEntropy(rnorm(500))         # high (irregular)
#> [1] 1.284492
```
