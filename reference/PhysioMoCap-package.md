# PhysioMoCap: Motion Capture and Biomechanics Analysis for PhysioExperiment Objects

Provides motion capture, pose estimation, and biomechanical simulation
analysis for PhysioExperiment objects. Includes I/O for C3D, Venus3D,
GaitRec, OpenPose, DeepLabCut, MediaPipe, BVH, ASF/AMC, OpenSim, and
generic CSV formats. Provides marker tracking (Hungarian algorithm),
signal filtering, numerical differentiation, resampling, center of mass
calculation, gait parameters, clinical statistics (ICC, SEM, MDC,
Bland-Altman), movement phase segmentation, dynamic time warping,
movement normalization, functional PCA, force-plate kinetics (GRF
filtering, COP, loading rate, impulse), planar inverse dynamics (joint
moments/power), EMG integration (rectification, RMS envelope, MVC
normalization), gait/running/jump task schemas, OpenSim workflow
integration, and biomechanics-specific visualization.

## See also

Useful links:

- <https://github.com/x-biosignal/PhysioMoCap>

- <https://x-biosignal.r-universe.dev/PhysioMoCap>

- <https://x-biosignal.github.io/PhysioMoCap/>

- Report bugs at <https://github.com/x-biosignal/PhysioMoCap/issues>

## Author

**Maintainer**: Yusuke Matsui <mail.to.matsui@gmail.com>

## Examples

``` r
# Synthetic demo data gets you started without external files
demo <- demoMoCapData(seed = 1)
demo$mocap
#> class: PhysioExperiment
#> dim: 300 x 8 
#> assays(3): position_x, position_y, position_z
#> samplingRate: 120 Hz
#> channels(8): Pelvis_R, Pelvis_L, Knee_R, Knee_L, Ankle_R ...
#> colData names(2): label, type
# Most operations take a PhysioExperiment and add a result assay
vel <- computeVelocity(demo$mocap)
SummarizedExperiment::assayNames(vel)
#> [1] "position_x" "position_y" "position_z" "velocity_x" "velocity_y"
#> [6] "velocity_z"
```
