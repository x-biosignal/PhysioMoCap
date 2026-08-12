# Conventional and functional hamstring-to-quadriceps ratios

Computes the conventional concentric H:Q ratio and a functional ratio
that compares eccentric antagonist torque with concentric agonist
torque. Optional EMG traces are processed with
[`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
and summarised as the hamstring-to-quadriceps mean-envelope ratio.

## Usage

``` r
hamstringQuadRatio(
  quad_con,
  ham_con,
  ham_ecc = NULL,
  quad_ecc = NULL,
  movement = c("extension", "flexion"),
  emg_ham = NULL,
  emg_quad = NULL,
  emg_sampling_rate = NULL
)
```

## Arguments

- quad_con:

  Concentric quadriceps peak torque or torque trace.

- ham_con:

  Concentric hamstring peak torque or torque trace.

- ham_ecc:

  Optional eccentric hamstring peak torque or torque trace.

- quad_ecc:

  Optional eccentric quadriceps peak torque or torque trace.

- movement:

  Movement direction, `"extension"` or `"flexion"`.

- emg_ham, emg_quad:

  Optional hamstring and quadriceps EMG traces. Supply both or neither.

- emg_sampling_rate:

  EMG sampling rate in Hz, required with EMG traces.

## Value

An `hq_ratio` object containing conventional and functional ratios, peak
torques, movement direction, and optional EMG ratio.

## References

Coombs R, Garbutt G (2002). Developments in the use of the hamstring/
quadriceps ratio for the assessment of muscle balance. *Journal of
Sports Science and Medicine*, 1:56-62.

Aagaard P, Simonsen EB, Magnusson SP, Larsson B, Dyhre-Poulsen P (1998).
A new concept for isokinetic hamstring:quadriceps muscle strength ratio.
*American Journal of Sports Medicine*, 26:231-237.
[doi:10.1177/03635465980260021201](https://doi.org/10.1177/03635465980260021201)

## Examples

``` r
hamstringQuadRatio(quad_con = 200, ham_con = 120, ham_ecc = 150)
#> <hq_ratio> conventional H:Q 0.600
#>   functional (extension): 0.750
```
