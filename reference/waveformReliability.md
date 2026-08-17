# Waveform reliability report: CMC, ICC / SEM / MDC curves

The integrated movement-waveform reliability summary. It combines the
within-subject repeatability (per-subject Kadaba
[`waveformCMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformCMC.md))
with the between-subject pointwise ICC curve and the frame-by-frame
standard error of measurement and minimal detectable change (from
[`PhysioCore::sem()`](https://x-biosignal.github.io/PhysioCore//reference/sem.html)
/
[`PhysioCore::mdc()`](https://x-biosignal.github.io/PhysioCore//reference/mdc.html),
the same definitions as the scalar clinimetrics).

## Usage

``` r
waveformReliability(x, model = "twoway", type = "agreement", confidence = 0.95)
```

## Arguments

- x:

  A `[subject, trial, frame]` array, or a list of `trials x frames`
  matrices (one per subject).

- model, type:

  Passed to
  [`PhysioCore::icc()`](https://x-biosignal.github.io/PhysioCore//reference/icc.html)
  for the pointwise ICC.

- confidence:

  Confidence level for the MDC (default 0.95).

## Value

a `waveform_reliability` object with per-subject `cmc`, the `icc`,
`sem`, `mdc` curves (+ ICC CIs), and scalar summaries (`mean_cmc`,
`mean_icc`, `peak_mdc`, ...). The SEM curve is the between-subject SD at
each frame times sqrt(1 - ICC); the MDC curve is the 95% minimal
detectable change in the measurement's own units.

## References

Kadaba MP, et al. (1989) J Orthop Res 7:849-860; Weir JP (2005) J
Strength Cond Res 19:231-240 (SEM/MDC).

## See also

[`waveformCMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformCMC.md),
[`waveformICC()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformICC.md)

## Examples

``` r
set.seed(1)
subs <- lapply(1:10, function(s) {
  base <- s + 5 * sin(seq(0, 2 * pi, length.out = 101))
  t(sapply(1:3, function(k) base + rnorm(101, 0, 0.3)))
})
r <- waveformReliability(subs)
r$mean_cmc; r$mean_icc; r$peak_mdc
#> [1] 0.9961583
#> [1] 0.9896484
#> [1] 1.139571
```
