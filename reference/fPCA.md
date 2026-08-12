# Functional Data Analysis (FDA) for Biomechanics

Functions for functional data analysis including functional PCA (fPCA),
functional regression, and curve registration. These methods treat
biomechanical waveforms as continuous functions. Functional Principal
Component Analysis (fPCA)

## Usage

``` r
fPCA(x, n_components = 5, smooth = FALSE, smooth_param = 10)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- n_components:

  Number of principal components to retain.

- smooth:

  Logical; if TRUE, smooths the data before analysis.

- smooth_param:

  Smoothing parameter (higher = smoother).

## Value

A list of class "fpca_result" containing:

- scores:

  PC scores for each observation (observations x components)

- loadings:

  PC loadings/eigenfunctions (time x components)

- variance_explained:

  Proportion of variance explained by each PC

- cumulative_variance:

  Cumulative variance explained

- mean_function:

  Mean waveform across observations

## Details

Performs functional PCA on waveform data to identify the main modes of
variation in movement patterns.

fPCA decomposes waveform variability into orthogonal modes. In gait
analysis, PC1 often represents overall amplitude, PC2 timing/phase
shifts, and subsequent PCs capture more subtle shape variations.

## References

Ramsay JO, Silverman BW (2005). "Functional Data Analysis." 2nd ed.
Springer.

## See also

[`reconstructFPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/reconstructFPCA.md)
for waveform reconstruction from fPCA results,
[`plotFPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotFPCA.md)
for visualization of fPCA results,
[`registerCurves()`](https://x-biosignal.github.io/PhysioMoCap/reference/registerCurves.md)
for separating phase and amplitude variation.

## Examples

``` r
# Simulate gait angle data (100 time points x 30 subjects)
set.seed(123)
t <- seq(0, 100, length.out = 100)
base_curve <- sin(2 * pi * t / 100) * 30

# Add subject variability
data <- sapply(1:30, function(i) {
  amplitude <- rnorm(1, 1, 0.2)
  phase <- rnorm(1, 0, 5)
  base_curve * amplitude + rnorm(100, 0, 2)
})

pe <- PhysioExperiment(assays = list(values = data), samplingRate = 100)
fpca_result <- fPCA(pe, n_components = 4)

# Plot first two PC loadings
plotFPCA(fpca_result)
```
