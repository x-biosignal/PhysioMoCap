# Read a plantar-pressure ASCII export

Reads frame-delimited Novel/Tekscan-style text exports. Comment metadata
may define `sampling_rate` (or `fs`), `dx`, `dy`, `side`, and `units`.
Explicit function arguments take precedence over file metadata.

## Usage

``` r
readPressureFrame(
  file,
  sampling_rate = NULL,
  dx = NULL,
  dy = NULL,
  side = NA_character_,
  units = "kPa",
  heel_first = TRUE,
  frame_marker = "^\\s*(Frame|ASCII_DATA|Time)",
  comment = "#"
)
```

## Arguments

- file:

  Path to an ASCII pressure export.

- sampling_rate, dx, dy:

  Optional overrides for file metadata.

- side:

  Optional side override.

- units:

  Pressure-unit override. When omitted, file metadata is used, falling
  back to `"kPa"`.

- heel_first:

  Logical; whether row 1 represents the heel.

- frame_marker:

  Regular expression identifying frame-header lines.

- comment:

  Literal prefix identifying metadata/comment lines.

## Value

A `pressure_movie` object.

## Examples

``` r
f <- tempfile(fileext = ".txt")
writeLines(c("# sampling_rate 100", "Frame 0", "1 2", "3 4"), f)
readPressureFrame(f)
#> <pressure_movie> 2 x 2 cells, 1 frames at 100 Hz (unspecified side)
#>   pitch: 1 x 1 mm  duration: 0 s  pressure: kPa
unlink(f)
```
