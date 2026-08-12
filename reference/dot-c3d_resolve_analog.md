# Resolve analog data to write into a C3D file

Returns the analog data frame (class `c3d_analog`), its sampling rate,
and the integer analog-subframes-per-point-frame ratio, or `NULL` if the
object carries no analog data.

## Usage

``` r
.c3d_resolve_analog(x, point_pe, n_frames, point_rate)
```

## Arguments

- x:

  The original PhysioExperiment or MultiRatePhysioExperiment.

- point_pe:

  The marker-bearing PhysioExperiment (may equal `x`).

- n_frames:

  Number of point frames.

- point_rate:

  Point sampling rate (Hz).

## Value

A list `list(df, rate, perframe)` or `NULL`.
