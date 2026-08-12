# Force Plate and Inverse Dynamics Workflow

This vignette demonstrates a standard lower-limb kinetics workflow in
`PhysioMoCap`:

1.  Filter force-plate GRF signals.
2.  Compute center of pressure (COP).
3.  Extract loading rate and impulse.
4.  Estimate joint moments and power with planar inverse dynamics.
5.  Run multi-plate selection and 3D inverse dynamics.

## 1. Simulate force-plate inputs

``` r

library(PhysioMoCap)
#> Loading required package: PhysioCore

set.seed(1)
n <- 1000
sr <- 1000

forces <- cbind(
  Fx = rnorm(n, 0, 8),
  Fy = rnorm(n, 0, 8),
  Fz = c(rep(0, 200), abs(sin(seq(0, pi, length.out = 600))) * 900, rep(0, 200))
)

moments <- cbind(
  Mx = rnorm(n, 0, 25),
  My = rnorm(n, 0, 25),
  Mz = rnorm(n, 0, 10)
)
```

## 2. Run force-plate analysis

``` r

out <- analyzeForcePlate(
  forces = forces,
  moments = moments,
  sampling_rate = sr,
  cutoff = 20,
  threshold = 20,
  filter_method = "moving_average"
)

out$summary
#>   peak_vertical_force max_loading_rate total_impulse n_stances
#> 1            897.3174         4664.171      342.8947         1
head(out$loading_rate)
#>   stance onset peak time_to_peak peak_force loading_rate
#> 1      1   197  500        0.303   897.3174     4664.171
head(out$impulse)
#>   stance onset offset duration_s  impulse
#> 1      1   197    804      0.607 342.8947
```

## 3. Build inverse-dynamics inputs

``` r

t <- seq(0, (n - 1) / sr, length.out = n)

joints <- data.frame(
  ankle_x = rep(0.00, n),
  ankle_y = rep(0.05, n),
  toe_x = rep(0.15, n),
  toe_y = rep(0.01, n),
  knee_x = rep(0.00, n),
  knee_y = rep(0.45, n),
  hip_x = rep(0.00, n),
  hip_y = rep(0.85, n)
)

grf_2d <- data.frame(
  fx = out$filtered_forces$force_x,
  fy = out$filtered_forces$force_z,
  cop_x = if (!is.null(out$cop)) out$cop$cop_x else rep(0, n),
  cop_y = if (!is.null(out$cop)) out$cop$cop_y else rep(0, n)
)

angles <- data.frame(
  ankle = 0.20 * sin(2 * pi * 1 * t),
  knee = 0.45 * sin(2 * pi * 1 * t + 0.2),
  hip = 0.35 * sin(2 * pi * 1 * t + 0.4)
)
```

## 4. Estimate inertial parameters and compute moments/power

[`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
runs a recursive link-segment Newton-Euler chain (foot -\> shank -\>
thigh), so it needs each segment’s mass and centre of mass as well as
the foot distal end (`toe_x`, `toe_y`). The legacy massless-segment
approximation is still reachable as `model = "quasi_static"`, but it
omits segment weight and inertia entirely - it returns zero moments
through the whole swing phase - and is kept only for reproducing older
analyses.

``` r

inertial <- estimateSegmentInertia(
  body_mass = 70,
  segment_lengths = c(foot = 0.25, shank = 0.43, thigh = 0.45)
)

id_out <- inverseDynamics2D(
  joints = joints,
  grf = grf_2d,
  sampling_rate = sr,
  angles = angles,
  inertial = inertial
)

# The moving-average filter leaves NA at the ends of the force trace, so look
# at frames from the middle of the trial.
id_out[seq(round(n / 2), length.out = 6), ]
#>      time ankle_moment knee_moment hip_moment ankle_power knee_power hip_power
#> 500 0.499    11.925723   12.051072  12.176421   -14.98591  -33.43605 -24.72844
#> 501 0.500    13.840715   14.156527  14.472339   -17.39264  -39.22851 -29.31380
#> 502 0.501    10.227280   10.469405  10.711531   -12.85164  -28.97377 -21.63820
#> 503 0.502   -14.814776  -14.623840 -14.432904    18.61520   40.41704  29.07630
#> 504 0.503   -13.560032  -13.397200 -13.234367    17.03690   36.97593  26.58790
#> 505 0.504     8.597176    8.825936   9.054695   -10.80005  -24.32484 -18.13968
#>      ankle_fx  ankle_fy   knee_fx   knee_fy    hip_fx    hip_fy
#> 500 0.3133714 -887.3636 0.3133714 -855.4430 0.3133714 -758.2394
#> 501 0.7895306 -887.3636 0.7895306 -855.4430 0.7895306 -758.2394
#> 502 0.6053136 -887.3389 0.6053136 -855.4183 0.6053136 -758.2148
#> 503 0.4773404 -887.2896 0.4773404 -855.3689 0.4773404 -758.1654
#> 504 0.4070816 -887.2155 0.4070816 -855.2949 0.4070816 -758.0914
#> 505 0.5718985 -887.1168 0.5718985 -855.1961 0.5718985 -757.9926
```

The moments jitter from frame to frame because the simulated plate
moments are white noise, so the centre of pressure jitters too and
swings the ground reaction force about the joint centres. Real data
needs the forces, the centre of pressure and the markers low-pass
filtered before inverse dynamics.

## 5. Multi-plate selection and 3D inverse dynamics

``` r

force_z <- cbind(
  fp1 = out$filtered_forces$force_z * 0.6,
  fp2 = out$filtered_forces$force_z
)

pe_fp <- PhysioCore::PhysioExperiment(
  assays = S4Vectors::SimpleList(
    force_x = cbind(fp1 = out$filtered_forces$force_x * 0.6,
                    fp2 = out$filtered_forces$force_x),
    force_y = cbind(fp1 = out$filtered_forces$force_y * 0.6,
                    fp2 = out$filtered_forces$force_y),
    force_z = force_z
  ),
  colData = S4Vectors::DataFrame(
    label = c("fp1", "fp2"),
    type = c("forceplate", "forceplate")
  ),
  samplingRate = sr
)

fp_auto <- analyzeForcePlatePE(pe_fp, plate_index = "auto", threshold = 20,
                               cutoff = 20, filter_method = "moving_average")
fp_auto$selected_plate
#> [1] 2
```

``` r

# Keep the vertical along y so that it matches `vertical = "y"` below, and add
# a lateral (z) coordinate.
joints_3d <- transform(
  joints,
  ankle_z = 0, toe_z = 0, knee_z = 0, hip_z = 0
)

grf_3d <- data.frame(
  fx = out$filtered_forces$force_x,
  fy = out$filtered_forces$force_z,
  fz = out$filtered_forces$force_y,
  cop_x = rep(0, n),
  cop_y = rep(0, n),
  cop_z = rep(0, n)
)

angles_3d <- data.frame(
  ankle_x = angles$ankle, ankle_y = 0 * angles$ankle, ankle_z = 0 * angles$ankle,
  knee_x = angles$knee,   knee_y = 0 * angles$knee,   knee_z = 0 * angles$knee,
  hip_x = angles$hip,     hip_y = 0 * angles$hip,     hip_z = 0 * angles$hip
)

id3 <- inverseDynamics3D(
  joints = joints_3d,
  grf = grf_3d,
  sampling_rate = sr,
  angles = angles_3d,
  inertial = inertial,
  vertical = "y"
)

id3[seq(round(n / 2), length.out = 6), 1:7]
#>      time ankle_moment_x ankle_moment_y ankle_moment_z knee_moment_x
#> 500 0.499    0.029164240              0      0.7621998    0.26247816
#> 501 0.500    0.018411492              0      0.7860078    0.16570343
#> 502 0.501    0.023687534              0      0.7767969    0.21318780
#> 503 0.502    0.008193719              0      0.7703983    0.07374347
#> 504 0.503    0.005924800              0      0.7668853    0.05332320
#> 505 0.504    0.028390158              0      0.7751262    0.25551143
#>     knee_moment_y knee_moment_z
#> 500             0     0.8875484
#> 501             0     1.1018200
#> 502             0     1.0189224
#> 503             0     0.9613344
#> 504             0     0.9297180
#> 505             0     1.0038855
```

## Notes

- For publication-grade kinetics, verify sign conventions and coordinate
  frames from your lab’s force-plate and marker setup.
- Use subject-specific segment lengths and MVC/body-mass normalization
  where appropriate.
