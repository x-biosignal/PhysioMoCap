# DTW Barycenter Averaging (DBA)

Computes the average waveform using DTW Barycenter Averaging, which
accounts for time warping in the averaging process.

## Usage

``` r
dtwAverage(x, init = "medoid", max_iter = 30, tol = 1e-04, window_size = NULL)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- init:

  Initial reference: "medoid", "mean", or a numeric vector.

- max_iter:

  Maximum iterations for DBA.

- tol:

  Convergence tolerance.

- window_size:

  Sakoe-Chiba band width.

## Value

A list containing:

- average:

  The DTW-averaged waveform

- iterations:

  Number of iterations used

- alignments:

  List of alignment paths to the average

## References

Sakoe H, Chiba S (1978). "Dynamic programming algorithm optimization for
spoken word recognition." IEEE Transactions on Acoustics, Speech, and
Signal Processing, 26(1), 43-49.

Petitjean F, Ketterlin A, Gancarski P (2011). "A global averaging method
for dynamic time warping, with applications to clustering." Pattern
Recognition, 44(3), 678-693.

## See also

[`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md),
[`dtwDistanceMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistanceMatrix.md),
[`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md)

## Examples

``` r
# Average multiple gait cycles with timing variation
set.seed(123)
t <- seq(0, 100, length.out = 100)
data <- sapply(1:20, function(i) {
  phase <- rnorm(1, 0, 10)
  sin(2 * pi * (t + phase) / 100) * 30 + rnorm(100, 0, 2)
})

avg <- dtwAverage(data)
plot(avg$average, type = "l")
```
