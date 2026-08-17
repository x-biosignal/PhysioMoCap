# Vector coding (coupling angle) between two joints

Vector coding quantifies coordination from the angle-angle diagram: the
coupling angle is the orientation of the vector between successive
points, and each frame is classified into in-phase (both joints rotating
together), anti-phase (opposite), proximal-phase (`angle1` dominant) or
distal-phase (`angle2` dominant) coordination (Chang et al. 2008;
Needham et al. 2014).

## Usage

``` r
vectorCoding(angle1, angle2)
```

## Arguments

- angle1, angle2:

  Numeric joint-angle series of equal length; `angle1` is the proximal
  joint (horizontal axis of the angle-angle plot).

## Value

a `vector_coding` list: `coupling_angle` (degrees, 0-360, length n-1),
`pattern` (a factor per frame) and `proportions` (time fraction per
pattern).

## References

Chang R, et al. (2008) J Biomech 41:3101-3105; Needham RA, et al. (2014)
J Biomech 47:1235-1241.

## See also

[`continuousRelativePhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/continuousRelativePhase.md),
[`coordinationVariability()`](https://x-biosignal.github.io/PhysioMoCap/reference/coordinationVariability.md)

## Examples

``` r
t <- seq(0, 2 * pi, length.out = 101)
vectorCoding(sin(t), sin(t))$proportions            # all in-phase
#> pattern
#>   in_phase anti_phase   proximal     distal 
#>          1          0          0          0 
```
