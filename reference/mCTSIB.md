# Modified Clinical Test of Sensory Interaction on Balance (mCTSIB)

Summarises sway velocity (or any sway index) across the four mCTSIB
sensory conditions (eyes open / closed on a firm surface and on foam)
and returns the per-condition means and the composite (mean of the four
condition means).

## Usage

``` r
mCTSIB(
  eyes_open_firm = NULL,
  eyes_closed_firm = NULL,
  eyes_open_foam = NULL,
  eyes_closed_foam = NULL,
  conditions = NULL
)
```

## Arguments

- eyes_open_firm, eyes_closed_firm, eyes_open_foam, eyes_closed_foam:

  Numeric vectors of per-trial sway velocities (or another sway index)
  for each condition. Missing conditions may be `NULL`.

- conditions:

  Alternatively, a named list with those four elements.

## Value

An `mctsib_result` object with `condition_means`, `condition_sd`,
`n_trials` and the `composite` mean.

## References

Cohen H, Blatchly CA, Gombash LL (1993). Phys Ther 73(6):346-351.

## See also

[`sensoryOrganizationTest()`](https://x-biosignal.github.io/PhysioMoCap/reference/sensoryOrganizationTest.md),
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md)

## Examples

``` r
mCTSIB(eyes_open_firm = c(0.4, 0.5),
       eyes_closed_firm = c(0.6, 0.7),
       eyes_open_foam = c(0.9, 1.0),
       eyes_closed_foam = c(1.6, 1.8))
#> <mctsib_result>
#>   eyes_open_firm     mean=0.45  (n=2)
#>   eyes_closed_firm   mean=0.65  (n=2)
#>   eyes_open_foam     mean=0.95  (n=2)
#>   eyes_closed_foam   mean=1.7  (n=2)
#>   composite: 0.9375
```
