# Assess an upper-limb ADL reach from its speed profile

Computes the standard reach-to-grasp kinematics for one ADL arm
transport and labels it with the ADL task and its ICF code. Works
directly on the end-effector (hand) speed profile, so it needs no full
marker set; derive the speed from a trajectory with
[`computeSpeed()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeSpeed.md)
or pass a hand-sensor speed.

## Usage

``` r
adlReachTask(
  speed,
  sampling_rate,
  task = c("reaching", "drinking", "feeding", "dressing", "grooming"),
  onset_threshold = 0.05
)
```

## Arguments

- speed:

  Numeric hand/end-effector speed profile (one reach).

- sampling_rate:

  Sampling rate in Hz.

- task:

  ADL task: `"reaching"` (default, generic hand-arm use, d445),
  `"drinking"` (d560), `"feeding"` (eating, d550), `"dressing"` (d540)
  or `"grooming"` (d520).

- onset_threshold:

  Movement-onset threshold (fraction of peak speed).

## Value

an `adl_reach_task` list: `task`, `icf_code`, and the kinematics
`movement_time`, `peak_velocity`, `time_to_peak_frac`, `movement_units`
(submovements; 1 = a single smooth transport), `sparc` and `ldlj`
(smoothness; less negative = smoother).

## References

Rohrer B, et al. (2002) J Neurosci 22:8297-8304 (movement units);
Balasubramanian S, et al. (2015) IEEE TBME 62:2137-2147 (SPARC).

## See also

[`reachingKinematics()`](https://x-biosignal.github.io/PhysioMoCap/reference/reachingKinematics.md),
[`movementUnits()`](https://x-biosignal.github.io/PhysioMoCap/reference/movementUnits.md),
[`sparc()`](https://x-biosignal.github.io/PhysioMoCap/reference/sparc.md)

## Examples

``` r
# a single smooth (minimum-jerk) reach: one movement unit
fs <- 100; tt <- seq(0, 1, 1 / fs)
v <- 30 * (tt^2) * (1 - tt)^2                 # bell-shaped speed
adlReachTask(v, fs, task = "drinking")$movement_units
#> [1] 1
```
