# Reconstruct waveforms from fPCA

Reconstructs individual waveforms using a subset of principal
components.

## Usage

``` r
reconstructFPCA(fpca_result, n_components = NULL, observation = NULL)
```

## Arguments

- fpca_result:

  An fpca_result object from fPCA().

- n_components:

  Number of components to use for reconstruction.

- observation:

  Indices of observations to reconstruct. If NULL, all.

## Value

Matrix of reconstructed waveforms (time x observations).

## References

Ramsay JO, Silverman BW (2005). "Functional Data Analysis." 2nd ed.
Springer.

## See also

[`fPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/fPCA.md)
for performing the decomposition,
[`plotFPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotFPCA.md)
for visualizing fPCA results.

## Examples

``` r
# Create sample data and run fPCA first
set.seed(123)
t <- seq(0, 100, length.out = 100)
base_curve <- sin(2 * pi * t / 100) * 30
data <- sapply(1:20, function(i) base_curve * rnorm(1, 1, 0.2) + rnorm(100, 0, 2))
fpca_result <- fPCA(data, n_components = 4)

# Reconstruct using only first 2 PCs
reconstructed <- reconstructFPCA(fpca_result, n_components = 2)
```
