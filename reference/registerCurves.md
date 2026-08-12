# Curve registration (time warping)

Aligns waveforms by estimating and removing phase variation. Uses
landmark registration or continuous registration.

## Usage

``` r
registerCurves(
  x,
  method = c("continuous", "landmark"),
  landmarks = NULL,
  template = NULL
)
```

## Arguments

- x:

  A PhysioExperiment object or matrix (time x observations).

- method:

  Registration method: "landmark" or "continuous".

- landmarks:

  For landmark method, matrix of landmark times (landmarks x obs).

- template:

  Template curve to align to. If NULL, uses mean.

## Value

A list containing:

- registered:

  Registered waveforms

- warping:

  Warping functions

- template:

  Template used for registration

## Details

Phase variation (timing differences) can obscure amplitude differences
in biomechanical data. Registration separates phase and amplitude
variation.

## References

Ramsay JO, Silverman BW (2005). "Functional Data Analysis." 2nd ed.
Springer.

## See also

[`fPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/fPCA.md)
for functional PCA after registration,
[`plotGaitCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGaitCycle.md)
for plotting registered gait waveforms.

## Examples

``` r
# Simulate data with phase variation
set.seed(123)
t <- seq(0, 100, length.out = 100)

data <- sapply(1:20, function(i) {
  phase_shift <- rnorm(1, 0, 10)
  t_shifted <- t + phase_shift
  sin(2 * pi * t_shifted / 100) * 30 + rnorm(100, 0, 2)
})

pe <- PhysioExperiment(assays = list(values = data), samplingRate = 100)
reg_result <- registerCurves(pe, method = "continuous")
```
