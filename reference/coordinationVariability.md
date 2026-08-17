# Inter-joint coordination variability across cycles

The trial-to-trial (cycle-to-cycle) variability of the coordination
measure – the deviation phase for continuous relative phase (linear SD)
or the coupling- angle circular SD for vector coding – computed at each
point of the (time-normalised) cycle. Coordination variability is a
motor-control marker: abnormally high or low values accompany injury and
neurological disease.

## Usage

``` r
coordinationVariability(
  angle1_cycles,
  angle2_cycles,
  method = c("crp", "vector_coding")
)
```

## Arguments

- angle1_cycles, angle2_cycles:

  Numeric matrices `cycles x points` (each row one time-normalised
  cycle) of the two joints' angles.

- method:

  `"crp"` (deviation phase, linear SD) or `"vector_coding"`
  (coupling-angle circular SD).

## Value

a `coordination_variability` list: `method`, `variability` (per-point),
`mean_variability` and `measure` (the per-cycle coordination matrix).

## References

Hamill (2000); Needham (2014).

## See also

[`continuousRelativePhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/continuousRelativePhase.md),
[`vectorCoding()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorCoding.md)

## Examples

``` r
m <- matrix(sin(seq(0, 2 * pi, length.out = 50)), nrow = 5, ncol = 50,
            byrow = TRUE)
coordinationVariability(m, m)$mean_variability      # identical cycles -> 0
#> [1] 0
```
