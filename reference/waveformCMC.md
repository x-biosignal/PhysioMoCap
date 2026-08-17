# Coefficient of multiple correlation for repeated waveforms (Kadaba CMC)

The waveform analogue of a reliability coefficient (Kadaba et al. 1989):
how similar a set of repeated curves are, relative to the curve's own
variation. With `groups = NULL` the rows of `x` are repeated trials and
the result is the **within-day** repeatability; pass `groups` (e.g. a
session/day label per row) for the **between-day** CMC of the
session-mean waveforms.

## Usage

``` r
waveformCMC(x, groups = NULL)
```

## Arguments

- x:

  A `trials x frames` numeric matrix: each row one waveform (e.g. a
  joint angle over the time-normalised cycle), columns the cycle points.

- groups:

  Optional grouping (length `nrow(x)`); when given, the CMC is computed
  between the group-mean waveforms (between-day/-condition).

## Value

The CMC in \[0, 1\] (higher = more repeatable), or `NA` with a warning
when the radicand is negative (waveform variation too small for a
defined CMC – a known limitation for low-excursion curves).

## References

Kadaba MP, et al. (1989) J Orthop Res 7:849-860.

## See also

[`waveformICC()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformICC.md),
[`waveformReliability()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformReliability.md)

## Examples

``` r
base <- sin(seq(0, 2 * pi, length.out = 101))
trials <- t(sapply(1:5, function(i) base + rnorm(101, 0, 0.02)))
waveformCMC(trials)                                  # ~ 1 (repeatable)
#> [1] 0.9995692
```
