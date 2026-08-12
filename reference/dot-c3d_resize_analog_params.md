# Resize per-channel ANALOG parameter vectors to a new channel count

Resize per-channel ANALOG parameter vectors to a new channel count

## Usage

``` r
.c3d_resize_analog_params(obj, labels)
```

## Arguments

- obj:

  A `c3d` object (after `c3d_setdata`).

- labels:

  Character vector of analog channel labels.

## Value

The object with `ANALOG` parameter vectors sized to `labels`.
