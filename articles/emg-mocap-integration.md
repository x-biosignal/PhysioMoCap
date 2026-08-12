# EMG and MoCap Integration Workflow

This vignette shows how to process EMG and align it with motion-capture
data.

## 1. Simulate MoCap and EMG data

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore

set.seed(42)

mocap_sr <- 120
emg_sr <- 1000

n_mocap <- 600
n_emg <- 5000

mocap <- cbind(
  knee_angle = sin(seq(0, 8 * pi, length.out = n_mocap)) * 40,
  hip_angle = sin(seq(0, 8 * pi, length.out = n_mocap) + 0.5) * 30
)

emg <- cbind(
  tibialis_anterior = rnorm(n_emg, 0, 0.2),
  gastrocnemius = rnorm(n_emg, 0, 0.2),
  rectus_femoris = rnorm(n_emg, 0, 0.2)
)
```

## 2. Process EMG (rectify + RMS envelope + smoothing)

``` r

emg_proc <- processEMG(
  x = emg,
  sampling_rate = emg_sr,
  bandpass = c(20, 450),
  envelope_cutoff = 6,
  rms_window_ms = 50,
  filter_method = "moving_average"
)

str(emg_proc, max.level = 1)
#> List of 3
#>  $ filtered : num [1:5000, 1:3] NA NA NA NA NA NA NA NA NA NA ...
#>   ..- attr(*, "dimnames")=List of 2
#>  $ rectified: num [1:5000, 1:3] NA NA NA NA NA NA NA NA NA NA ...
#>   ..- attr(*, "dimnames")=List of 2
#>  $ envelope : num [1:5000, 1:3] NA NA NA NA NA NA NA NA NA NA ...
#>   ..- attr(*, "dimnames")=List of 2
```

## 3. Align EMG to MoCap timeline

``` r

emg_aligned <- alignEMGtoMoCap(
  emg = emg_proc$envelope,
  emg_sampling_rate = emg_sr,
  mocap_length = n_mocap,
  mocap_sampling_rate = mocap_sr
)

dim(emg_aligned)
#> [1] 600   3
```

## 4. Build an integrated analysis table

``` r

integrated <- integrateEMGMoCap(
  mocap = mocap,
  emg = emg,
  mocap_sampling_rate = mocap_sr,
  emg_sampling_rate = emg_sr,
  process = TRUE,
  rms_window_ms = 50,
  envelope_cutoff = 6,
  filter_method = "moving_average"
)

head(integrated$combined)
#>          time mocap_knee_angle mocap_hip_angle emg_tibialis_anterior
#> 1 0.000000000         0.000000        14.38277                    NA
#> 2 0.008333333         1.677821        15.47443                    NA
#> 3 0.016666667         3.352688        16.53885                    NA
#> 4 0.025000000         5.021655        17.57416                    NA
#> 5 0.033333333         6.681782        18.57854                    NA
#> 6 0.041666667         8.330147        19.55022                    NA
#>   emg_gastrocnemius emg_rectus_femoris
#> 1                NA                 NA
#> 2                NA                 NA
#> 3                NA                 NA
#> 4                NA                 NA
#> 5                NA                 NA
#> 6                NA                 NA
```

## Notes

- If MVC trials are available, pass `mvc = ...` to
  [`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
  for `%MVC` scaling.
- For event-locked studies, align on synchronization pulses or known
  trigger markers before integrating.
