# Resolve the marker-bearing PhysioExperiment for a C3D write

For a plain `PhysioExperiment` this is the object itself. For a
`MultiRatePhysioExperiment` it is the stream whose assays include the
`"position_*"` markers (falling back to a `"recording"` stream).

## Usage

``` r
.c3d_point_source(x)
```

## Arguments

- x:

  A PhysioExperiment or MultiRatePhysioExperiment.

## Value

A PhysioExperiment holding the marker assays.
