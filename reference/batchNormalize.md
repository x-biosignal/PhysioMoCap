# Batch normalize multiple trials

Normalizes multiple trials and returns them in a consistent format.

## Usage

``` r
batchNormalize(
  trials,
  method = "cycle",
  norm_length = 101L,
  schema = NULL,
  ...
)
```

## Arguments

- trials:

  List of matrices or PhysioExperiment objects

- method:

  Normalization method

- norm_length:

  Target length

- schema:

  Optional TaskSchema

- ...:

  Additional arguments

## Value

3D array (time x channels x trials) or list

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md),
[`normalizedTimeAxis()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizedTimeAxis.md),
[`combineTrials()`](https://x-biosignal.github.io/PhysioMoCap/reference/combineTrials.md)

## Examples

``` r
set.seed(1)
trials <- list(matrix(rnorm(200), 100, 2), matrix(rnorm(180), 90, 2))
norm <- batchNormalize(trials, method = "cycle")
dim(norm[[1]])
#> NULL
```
