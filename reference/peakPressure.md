# Calculate a peak plantar-pressure map

Calculate a peak plantar-pressure map

## Usage

``` r
peakPressure(pm, contact_threshold = 0)
```

## Arguments

- pm:

  A `pressure_movie`.

- contact_threshold:

  Pressure threshold in kPa. Cells must exceed this threshold to count
  toward contact area and mean pressure.

## Value

A numeric peak-pressure matrix in kPa. Attributes contain the global
peak, peak cell and frame, contact area, and mean active pressure.

## References

Rosenbaum D, Becker H-P (1997). Plantar pressure distribution
measurements. *Foot and Ankle Surgery*, 3:1-14.

## Examples

``` r
pm <- pressureMovie(array(1:12, c(2, 2, 3)), 100)
peakPressure(pm)
#>      [,1] [,2]
#> [1,]    9   11
#> [2,]   10   12
#> attr(,"peak")
#> [1] 12
#> attr(,"peak_cell")
#> row col 
#>   2   2 
#> attr(,"peak_frame")
#> [1] 3
#> attr(,"contact_area")
#> [1] 4
#> attr(,"mean_pressure")
#> [1] 6.5
```
