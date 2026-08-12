# Summarize plantar loading by anatomical region

Partitions the active footprint along its anteroposterior extent using
cumulative Cavanagh-style region bounds.

## Usage

``` r
regionalLoading(
  pm,
  statistic = c("fti", "peak_force", "mean_force"),
  regions = c(rearfoot = 0.3, midfoot = 0.6, forefoot = 0.8, toes = 1),
  contact_threshold = 0,
  force_factor = 0.001
)
```

## Arguments

- pm:

  A `pressure_movie`.

- statistic:

  Regional statistic: force-time integral, peak force, or mean force.

- regions:

  Named, strictly increasing cumulative upper bounds ending at

  1.  Defaults to rearfoot, midfoot, forefoot, and toes.

- contact_threshold:

  Pressure threshold in kPa defining loaded cells.

- force_factor:

  Conversion from pressure times cell area to force.

## Value

A `regional_loading` data frame with one row per region. Attributes
contain the regional total and selected statistic.

## References

Cavanagh PR, Rodgers MM, Iiboshi A (1987). Pressure distribution under
symptom-free feet during barefoot standing. *Foot and Ankle*, 7:262-276.

## Examples

``` r
pm <- pressureMovie(array(100, c(10, 4, 11)), 100, dx = 5, dy = 5)
regionalLoading(pm)
#> <regional_loading> statistic=fti, total=10
#>    region value pct_total peak_pressure contact_area n_cells
#>  rearfoot     3        30           100          300      12
#>   midfoot     3        30           100          300      12
#>  forefoot     2        20           100          200       8
#>      toes     2        20           100          200       8
```
