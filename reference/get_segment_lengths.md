# Compute segment lengths from a PhysioExperiment and skeleton

Calculates the Euclidean distance between connected keypoints for each
frame. The PhysioExperiment must contain `position_x`, `position_y`, and
(optionally) `position_z` assays with columns matching skeleton keypoint
labels.

## Usage

``` r
get_segment_lengths(pe, skeleton)
```

## Arguments

- pe:

  A `PhysioExperiment` object with position assays.

- skeleton:

  A `SkeletonModel` object whose keypoint labels match column names in
  the position assays.

## Value

A matrix of segment lengths with dimensions (n_frames x n_bones). Column
names are bone names.

## References

Winter DA (2009). "Biomechanics and Motor Control of Human Movement."
4th ed. Wiley.

## See also

[`SkeletonModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/SkeletonModel.md),
[`get_bone_connections()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_bone_connections.md),
[`get_limb_pairs()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_limb_pairs.md)

## Examples

``` r
sk <- define_skeleton("BODY_25")
labels <- sk$keypoints$label
set.seed(42)
nk <- length(labels); nf <- 10
mk <- function(b) matrix(rep(b, each = nf), nf)
px <- mk(rnorm(nk, 0, 0.3)); py <- mk(rnorm(nk, 0, 0.3))
pz <- mk(seq(1.8, 0, length.out = nk))
colnames(px) <- colnames(py) <- colnames(pz) <- labels
pe <- PhysioExperiment(assays = S4Vectors::SimpleList(
    position_x = px, position_y = py, position_z = pz),
  colData = S4Vectors::DataFrame(label = labels, type = rep("keypoint", nk)),
  samplingRate = 30)
get_segment_lengths(pe, sk)
#>           spine right_clavicle left_clavicle right_upper_arm right_forearm
#>  [1,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [2,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [3,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [4,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [5,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [6,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [7,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [8,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>  [9,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#> [10,] 0.9419561      0.5359077     0.3932471       0.6760421     0.3453205
#>       left_upper_arm left_forearm right_hip_joint right_thigh right_shank
#>  [1,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [2,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [3,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [4,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [5,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [6,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [7,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [8,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>  [9,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#> [10,]      0.4967219    0.4976197       0.7121046   0.7863153   0.4130895
#>       left_hip_joint left_thigh left_shank      neck nose_to_right_eye
#>  [1,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [2,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [3,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [4,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [5,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [6,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [7,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [8,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>  [9,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#> [10,]        1.06777   0.580069  0.7402028 0.5878213          1.162198
#>       right_eye_to_ear nose_to_left_eye left_eye_to_ear left_ankle_to_bigtoe
#>  [1,]         1.012687         1.298849       0.6730276            0.7129228
#>  [2,]         1.012687         1.298849       0.6730276            0.7129228
#>  [3,]         1.012687         1.298849       0.6730276            0.7129228
#>  [4,]         1.012687         1.298849       0.6730276            0.7129228
#>  [5,]         1.012687         1.298849       0.6730276            0.7129228
#>  [6,]         1.012687         1.298849       0.6730276            0.7129228
#>  [7,]         1.012687         1.298849       0.6730276            0.7129228
#>  [8,]         1.012687         1.298849       0.6730276            0.7129228
#>  [9,]         1.012687         1.298849       0.6730276            0.7129228
#> [10,]         1.012687         1.298849       0.6730276            0.7129228
#>       left_bigtoe_to_smalltoe left_ankle_to_heel right_ankle_to_bigtoe
#>  [1,]               0.7319496          0.7646555               1.29291
#>  [2,]               0.7319496          0.7646555               1.29291
#>  [3,]               0.7319496          0.7646555               1.29291
#>  [4,]               0.7319496          0.7646555               1.29291
#>  [5,]               0.7319496          0.7646555               1.29291
#>  [6,]               0.7319496          0.7646555               1.29291
#>  [7,]               0.7319496          0.7646555               1.29291
#>  [8,]               0.7319496          0.7646555               1.29291
#>  [9,]               0.7319496          0.7646555               1.29291
#> [10,]               0.7319496          0.7646555               1.29291
#>       right_bigtoe_to_smalltoe right_ankle_to_heel
#>  [1,]                0.7037424            1.072878
#>  [2,]                0.7037424            1.072878
#>  [3,]                0.7037424            1.072878
#>  [4,]                0.7037424            1.072878
#>  [5,]                0.7037424            1.072878
#>  [6,]                0.7037424            1.072878
#>  [7,]                0.7037424            1.072878
#>  [8,]                0.7037424            1.072878
#>  [9,]                0.7037424            1.072878
#> [10,]                0.7037424            1.072878
```
