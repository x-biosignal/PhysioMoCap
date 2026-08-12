# Plot a plantar-pressure map

Renders peak, mean, pressure-time-integral, or individual-frame
pressure. For `type = "frame"`, omitting `frame` selects the
peak-total-pressure frame. Supplying `n_facets` explicitly while
omitting `frame` instead displays peak-pressure maps over equal stance
windows.

## Usage

``` r
plotPressureMap(
  pm,
  type = c("peak", "mean", "pti", "frame"),
  frame = NULL,
  n_facets = 6L,
  contact_threshold = 0,
  palette = "viridis",
  flip_ap = FALSE
)
```

## Arguments

- pm:

  A `pressure_movie`.

- type:

  Map aggregation: `"peak"`, `"mean"`, `"pti"`, or `"frame"`.

- frame:

  Frame index for `type = "frame"`.

- n_facets:

  Number of stance windows when explicitly supplied for a faceted frame
  plot.

- contact_threshold:

  Values at or below this pressure are not drawn.

- palette:

  Viridis palette name/option, a single high-end colour, or a vector of
  gradient colours.

- flip_ap:

  Logical; reverse the displayed anteroposterior axis.

## Value

A `ggplot` object.

## Examples

``` r
x <- array(runif(4 * 3 * 10), c(4, 3, 10))
plotPressureMap(pressureMovie(x, 100, dx = 5, dy = 5))
```
