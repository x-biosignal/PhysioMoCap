# Sensory Organization Test (SOT) equilibrium and sensory-ratio scoring

Computes NeuroCom-style Sensory Organization Test equilibrium scores,
composite score, and the four sensory-analysis ratios from either
per-trial equilibrium scores or per-trial peak-to-peak anteroposterior
sway angles.

## Usage

``` r
sensoryOrganizationTest(
  scores = NULL,
  sway_angle = NULL,
  theta_limit = 12.5,
  fall_as_zero = TRUE
)
```

## Arguments

- scores:

  A 6-row (conditions 1-6) numeric matrix / `data.frame` of equilibrium
  scores, columns = trials; or a list of 6 numeric vectors. `NA` entries
  (e.g. a fall) are treated as a fall with score 0 when
  `fall_as_zero = TRUE`.

- sway_angle:

  Alternatively, peak-to-peak AP sway angles (degrees) in the same shape
  as `scores`; converted to equilibrium scores.

- theta_limit:

  Theoretical AP stability limit in degrees (default 12.5).

- fall_as_zero:

  Logical; treat `NA` trials as falls scored 0 (default `TRUE`).

## Value

A `sot_result` object with per-trial `equilibrium`, per-condition
`condition_means`, `composite`, and `ratios` (SOM/VIS/VEST/PREF).

## Details

The equilibrium score for a trial is \\EQ = 100 \times (\theta\_{lim} -
\theta\_{pp}) / \theta\_{lim}\\, where \\\theta\_{pp}\\ is the
peak-to-peak AP sway angle and \\\theta\_{lim}\\ the theoretical AP
stability limit (12.5 deg). The composite is the mean of the condition-1
and condition-2 average scores together with every individual trial
score of conditions 3-6. The sensory ratios use condition average
scores: SOM = C2/C1, VIS = C4/C1, VEST = C5/C1, PREF = (C3+C6)/(C2+C5).

## References

Nashner LM (1997). "Computerized dynamic posturography."

## See also

[`mCTSIB()`](https://x-biosignal.github.io/PhysioMoCap/reference/mCTSIB.md),
[`limitsOfStability()`](https://x-biosignal.github.io/PhysioMoCap/reference/limitsOfStability.md),
[`swayMetrics()`](https://x-biosignal.github.io/PhysioMoCap/reference/swayMetrics.md)

## Examples

``` r
# Three trials per condition, equilibrium scores already computed
sc <- rbind(c(94, 95, 93), c(92, 91, 93), c(88, 90, 89),
            c(85, 84, 86), c(70, 72, 68), c(65, 66, 64))
sensoryOrganizationTest(sc)
#> <sot_result>
#>   condition means: C1=94.0  C2=92.0  C3=89.0  C4=85.0  C5=70.0  C6=65.0 
#>   composite: 79.5
#>   ratios: SOM=0.979  VIS=0.904  VEST=0.745  PREF=0.951 
```
