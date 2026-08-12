# Time-delay phase-space embedding

Reconstructs a scalar time series into a delay-embedded phase space
\\Y(i) = \[x_i, x\_{i+\tau}, \dots, x\_{i+(m-1)\tau}\]\\. When `delay`
is `NULL` it is chosen at the first local minimum of the average mutual
information (AMI); when `dim` is `NULL` it is chosen where the fraction
of false nearest neighbours (FNN) first drops below `fnn_threshold`.

## Usage

``` r
timeDelayEmbed(
  x,
  delay = NULL,
  dim = NULL,
  max_delay = 50L,
  max_dim = 10L,
  n_bins = 16L,
  fnn_threshold = 0.01
)
```

## Arguments

- x:

  Numeric time series.

- delay:

  Embedding delay in samples; `NULL` to estimate via AMI.

- dim:

  Embedding dimension; `NULL` to estimate via FNN.

- max_delay:

  Maximum delay searched for the AMI minimum.

- max_dim:

  Maximum embedding dimension searched for FNN.

- n_bins:

  Histogram bins for the AMI estimate.

- fnn_threshold:

  FNN fraction below which the dimension is accepted.

## Value

A `time_delay_embedding` list with `embedded` (matrix, points x dim),
`delay`, `dim`, `ami` (if estimated) and `fnn` (if estimated).

## References

Fraser AM, Swinney HL (1986); Kennel MB, et al. (1992).

## See also

[`maxLyapunovExponent()`](https://x-biosignal.github.io/PhysioMoCap/reference/maxLyapunovExponent.md),
[`sampleEntropy()`](https://x-biosignal.github.io/PhysioMoCap/reference/sampleEntropy.md)

## Examples

``` r
x <- sin(seq(0, 20 * pi, length.out = 500))
emb <- timeDelayEmbed(x, delay = 5, dim = 3)
dim(emb$embedded)
#> [1] 490   3
```
