# Instrumented Nine-Hole-Peg dexterity from a hand-speed profile

Turns the hand-speed profile of a peg-transport task (the Nine-Hole-Peg
Test of fine hand use) into instrumented dexterity metrics: the number
of detected peg transports (speed peaks), the transport rate, the mean
and coefficient of variation of the inter-transport intervals (movement
consistency) and the overall smoothness. This is the sensor-derived
complement to the clinical timed NHPT score, and realises ICF `d440`
(fine hand use).

## Usage

``` r
nhptDexterity(speed, sampling_rate, ...)
```

## Arguments

- speed:

  Numeric hand speed profile over the whole task.

- sampling_rate:

  Sampling rate in Hz.

- ...:

  Passed to
  [`movementUnits()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementUnits.md)
  (peak height/prominence controls).

## Value

an `nhpt_dexterity` list: `icf_code`, `n_transports`, `total_time`,
`transport_rate` (transports/s), `mean_interval`, `cv_interval`
(interval consistency) and `smoothness` (SPARC).

## References

Mathiowetz V, et al. (1985) Am J Occup Ther 39:386-391 (NHPT).

## See also

[`movementUnits()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementUnits.md),
[`adlReachTask()`](https://x-biosignal.github.io/PhysioMoCap/reference/adlReachTask.md)

## Examples

``` r
fs <- 100
bell <- function(n) { u <- seq(0, 1, length.out = n); 30 * u^2 * (1 - u)^2 }
# nine evenly spaced transports
v <- unlist(replicate(9, c(bell(40), numeric(20)), simplify = FALSE))
nhptDexterity(v, fs)$n_transports
#> [1] 9
```
