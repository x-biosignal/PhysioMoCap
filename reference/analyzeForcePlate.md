# Run complete force-plate analysis

Convenience wrapper that filters GRF components and computes COP,
loading rate, and impulse summaries.

## Usage

``` r
analyzeForcePlate(
  forces,
  moments = NULL,
  sampling_rate,
  cutoff = 20,
  threshold = 20,
  order = 4,
  filter_method = c("butterworth", "moving_average"),
  origin = c(0, 0, 0)
)
```

## Arguments

- forces:

  Matrix/data.frame with force components (X, Y, Z).

- moments:

  Optional matrix/data.frame with moment components (X, Y, Z).

- sampling_rate:

  Sampling rate in Hz.

- cutoff:

  Low-pass cutoff for force filtering.

- threshold:

  Contact threshold for stance detection.

- order:

  Butterworth filter order.

- filter_method:

  Filtering method passed to
  [`filterGRF()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterGRF.md).

- origin:

  Force-plate origin used in COP computation.

## Value

A list with elements: `filtered_forces`, `cop`, `loading_rate`,
`impulse`, and `summary`.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. John Wiley & Sons.

## See also

[`filterGRF()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterGRF.md)
for ground reaction force filtering,
[`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md)
for center of pressure computation,
[`computeLoadingRate()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeLoadingRate.md)
for loading rate analysis,
[`analyzeForcePlatePE()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlatePE.md)
for PhysioExperiment-based analysis.

## Examples

``` r
f <- cbind(Fx = rep(0, 1000), Fy = rep(0, 1000),
           Fz = c(rep(0, 200), abs(sin(seq(0, pi, length.out = 600))) * 800,
                  rep(0, 200)))
out <- analyzeForcePlate(f, sampling_rate = 1000)
```
