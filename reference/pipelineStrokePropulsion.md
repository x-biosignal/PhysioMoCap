# Stroke paretic-propulsion pipeline

Quantifies propulsion symmetry after stroke from the anterior-posterior
ground reaction force of each limb: the paretic propulsion `Pp` is the
paretic propulsive (anterior) impulse divided by the total propulsive
impulse of both limbs (Bowden et al. 2006). A symmetric gait gives
`Pp = 0.5`; reduced paretic output gives `Pp < 0.5`.

## Usage

``` r
pipelineStrokePropulsion(ap_paretic, ap_nonparetic, sampling_rate)
```

## Arguments

- ap_paretic, ap_nonparetic:

  Anterior-posterior ground reaction force of the paretic and
  non-paretic limbs over the analysis window (anterior / propulsive
  positive).

- sampling_rate:

  Sampling rate in Hz.

## Value

A `stroke_propulsion_report` object.

## References

Bowden MG, et al. (2006). Stroke 37(3):872-876.
