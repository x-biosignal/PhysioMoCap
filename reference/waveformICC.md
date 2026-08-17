# Pointwise intraclass correlation across the movement cycle

The reliability *curve*: the between-subject ICC computed frame-by-frame
from repeated trials, using the ecosystem's
[`PhysioCore::icc()`](https://x-biosignal.github.io/PhysioCore//reference/icc.html)
at each cycle point. It shows where along the movement a measurement is
reliable.

## Usage

``` r
waveformICC(x, model = "twoway", type = "agreement", unit = "single")
```

## Arguments

- x:

  A `[subject, trial, frame]` array, or a list of `trials x frames`
  matrices (one per subject). Every subject must have the same trials
  and frames.

- model, type, unit:

  Passed to
  [`PhysioCore::icc()`](https://x-biosignal.github.io/PhysioCore//reference/icc.html)
  (default two-way, absolute agreement, single measure – ICC(2,1)).

## Value

a `waveform_icc` list: `icc`, `ci_lower`, `ci_upper` (per frame),
`mean_icc`, `min_icc`.

## See also

[`waveformReliability()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformReliability.md),
[`waveformCMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformCMC.md)

## Examples

``` r
set.seed(1)
subs <- lapply(1:8, function(s) {
  base <- s + sin(seq(0, 2 * pi, length.out = 101))   # subject offset = signal
  t(sapply(1:3, function(k) base + rnorm(101, 0, 0.1)))
})
waveformICC(subs)$mean_icc                            # high (subjects separable)
#> [1] 0.9982253
```
