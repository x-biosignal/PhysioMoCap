# Parse wide-format C3D point data into coordinate matrices

Takes the data frame returned by `c3dr::c3d_data(c3d, format = "wide")`
and splits it into separate X, Y, Z matrices with marker name columns.
The wide format has columns named `MarkerName_x`, `MarkerName_y`,
`MarkerName_z` for each marker.

## Usage

``` r
.parse_c3d_wide(point_data)
```

## Arguments

- point_data:

  A data frame from
  [`c3dr::c3d_data()`](https://docs.ropensci.org/c3dr/reference/c3d_data.html)
  in wide format.

## Value

A list with elements `pos_x`, `pos_y`, `pos_z` (matrices) and
`marker_names` (character vector).
