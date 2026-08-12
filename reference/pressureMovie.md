# Construct a plantar-pressure movie

Creates a compact representation of a pressure-sensor grid sampled over
time. Pressure values are expected in kPa, and grid pitch is expressed
in mm. Negative sensor values are clamped to zero.

## Usage

``` r
pressureMovie(
  pressure,
  sampling_rate,
  dx = 1,
  dy = 1,
  side = NA_character_,
  units = "kPa",
  heel_first = TRUE
)
```

## Arguments

- pressure:

  Numeric three-dimensional array with dimensions grid row by grid
  column by frame, or a list of equal-dimension numeric matrices.

- sampling_rate:

  Sampling frequency in Hz.

- dx, dy:

  Sensor-cell pitch in the mediolateral and anteroposterior directions,
  respectively, in mm.

- side:

  Optional foot side, `"left"`, `"right"`, or `NA`.

- units:

  Pressure units recorded in the source data. Calculations assume kPa.

- heel_first:

  Logical; whether grid row 1 is the posterior (heel) end.

## Value

A `pressure_movie` object.

## References

Pataky TC (2012). Spatial resolution in plantar pressure measurement
revisited. *Journal of Biomechanics*, 45:2116-2124.

## Examples

``` r
x <- array(0, dim = c(4, 3, 10))
x[2, 2, ] <- 100
pressureMovie(x, sampling_rate = 100, dx = 5, dy = 5)
#> <pressure_movie> 4 x 3 cells, 10 frames at 100 Hz (unspecified side)
#>   pitch: 5 x 5 mm  duration: 0.09 s  pressure: kPa
```
