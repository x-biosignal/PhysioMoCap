# Get body segment inertial parameters (BSIP)

Returns a data.frame of body segment inertial parameters including mass
fractions and center of mass proximal fractions for standard
anthropometric models.

## Usage

``` r
segmentParameters(model = "deLeva_male")
```

## Arguments

- model:

  Character string specifying the anthropometric model. One of
  `"deLeva_male"`, `"deLeva_female"`, or `"winter"`. Default is
  `"deLeva_male"`.

## Value

A `data.frame` with columns:

- segment:

  Character, name of the body segment.

- mass_fraction:

  Numeric, fraction of total body mass (as percentage, 0-100).

- com_proximal_fraction:

  Numeric, fraction of segment length from the proximal endpoint to the
  segment center of mass (0-1).

- proximal_marker:

  Character, default proximal marker name.

- distal_marker:

  Character, default distal marker name.

## Details

The De Leva (1996) tables provide adjusted body segment parameters based
on Zatsiorsky's data, separately for males and females. The Winter
(2009) model provides a simplified set of parameters commonly used in
gait analysis.

Segments include: head, trunk, upper_arm_r, upper_arm_l, forearm_r,
forearm_l, hand_r, hand_l, thigh_r, thigh_l, shank_r, shank_l, foot_r,
foot_l (14 segments total).

## References

De Leva, P. (1996). Adjustments to Zatsiorsky-Seluyanov's segment
inertia parameters. *Journal of Biomechanics*, 29(9), 1223-1230.

Winter, D.A. (2009). *Biomechanics and Motor Control of Human Movement*
(4th ed.). Wiley.

## See also

[`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md)
for whole-body center of mass computation,
[`calculateSegmentCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateSegmentCOM.md)
for individual segment center of mass,
[`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
for segment inertial properties.

## Examples

``` r
bsip <- segmentParameters("deLeva_male")
head(bsip)
#>       segment mass_fraction com_proximal_fraction proximal_marker distal_marker
#> 1        head          6.94                0.5002            Neck          Nose
#> 2       trunk         43.46                0.4486            Neck        MidHip
#> 3 upper_arm_r          2.71                0.5772       RShoulder        RElbow
#> 4 upper_arm_l          2.71                0.5772       LShoulder        LElbow
#> 5   forearm_r          1.62                0.4574          RElbow        RWrist
#> 6   forearm_l          1.62                0.4574          LElbow        LWrist
sum(bsip$mass_fraction)  # approximately 100
#> [1] 100
```
