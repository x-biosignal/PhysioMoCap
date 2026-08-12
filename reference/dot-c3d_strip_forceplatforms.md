# Drop force-platform parameters/data from a c3d object

Force-platform parameters (`FORCE_PLATFORM:CHANNEL`, `CORNERS`, ...)
index specific analog channels; removing them lets a c3d object with an
arbitrary number of markers/analog channels be written by c3dr.

## Usage

``` r
.c3d_strip_forceplatforms(obj)
```

## Arguments

- obj:

  A `c3d` object.

## Value

The object with force platforms cleared.
