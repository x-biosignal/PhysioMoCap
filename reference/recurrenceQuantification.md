# Recurrence quantification analysis (RQA)

Reconstructs the attractor by delay embedding and quantifies its
recurrence structure: recurrence rate, determinism, laminarity and
diagonal/vertical line statistics. High determinism indicates
deterministic (periodic/chaotic) rather than stochastic dynamics.

## Usage

``` r
recurrenceQuantification(
  x,
  m = 3L,
  tau = 1L,
  radius = NULL,
  target_rr = 0.1,
  lmin = 2L,
  vmin = 2L,
  max_n = 1500L
)
```

## Arguments

- x:

  Numeric time series.

- m:

  Embedding dimension (default 3).

- tau:

  Embedding delay (default 1).

- radius:

  Recurrence threshold; if `NULL`, chosen to reach `target_rr`.

- target_rr:

  Target recurrence rate when `radius` is `NULL` (default 0.1).

- lmin, vmin:

  Minimum diagonal / vertical line lengths (default 2).

- max_n:

  Cap on embedded points (subsampled if longer; default 1500).

## Value

an `rqa_result`: `RR`, `DET`, `LAM`, `Lmax`, `Lmean`, `TT` (trapping
time), `ENTR` (diagonal line entropy), `radius`.

## References

Marwan N, et al. (2007) Phys Rep 438:237-329.

## See also

[`floquetMultipliers()`](https://x-biosignal.github.io/PhysioMoCap/reference/floquetMultipliers.md),
[`approximateEntropy()`](https://x-biosignal.github.io/PhysioMoCap/reference/approximateEntropy.md)

## Examples

``` r
t <- seq(0, 20 * pi, length.out = 800)
recurrenceQuantification(sin(t))$DET               # ~1 (deterministic)
#> [1] 0.9536178
```
