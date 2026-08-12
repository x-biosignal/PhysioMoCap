# Trunk compensation during reaching

Decomposes hand transport into trunk translation and arm-relative
transport, and optionally computes signed axial trunk rotation from
shoulder markers.

## Usage

``` r
trunkCompensation(
  trunk,
  hand,
  shoulder_r = NULL,
  shoulder_l = NULL,
  reach_axis = NULL,
  vertical_axis = 3L,
  onset = NULL,
  offset = NULL
)
```

## Arguments

- trunk, hand:

  Numeric `n` by 3 position matrices in a common coordinate frame and
  unit.

- shoulder_r, shoulder_l:

  Optional right and left shoulder position matrices used for axial
  rotation. Supply both or neither.

- reach_axis:

  Optional length-3 reach-direction vector. The net hand displacement is
  used by default.

- vertical_axis:

  Index (1, 2, or 3) of the vertical coordinate axis.

- onset, offset:

  Optional 1-based sample bounds.

## Value

A `trunk_compensation` object containing trunk, hand, and arm transport,
trunk contribution, signed rotation in degrees, and reach axis.

## References

Cirstea MC, Levin MF (2000). Compensatory strategies for reaching in
stroke. *Brain*, 123:940-953.
[doi:10.1093/brain/123.5.940](https://doi.org/10.1093/brain/123.5.940)

## Examples

``` r
hand <- cbind(seq(0, 0.4, length.out = 20), 0, 0)
trunk <- cbind(seq(0, 0.1, length.out = 20), 0, 0)
trunkCompensation(trunk, hand)
#> <trunk_compensation>
#>   hand: 0.4  trunk: 0.1  arm: 0.3
#>   trunk contribution: 0.250  rotation: NA deg
```
