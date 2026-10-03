# Read MediaPipe landmark output

Reads MediaPipe landmark data from a directory of per-frame JSON files
or a single CSV file and returns a PhysioExperiment object.

## Usage

``` r
readMediaPipe(path, model = c("pose", "hand"), fps = 30)
```

## Arguments

- path:

  Path to a directory of JSON files or a single CSV file.

- model:

  Landmark model: `"pose"` (33 landmarks) or `"hand"` (21 landmarks).
  Default `"pose"`.

- fps:

  Frame rate in Hz (frames per second). Default 30.

## Value

A PhysioExperiment with assays:

- landmark_x:

  X coordinates matrix (frames x landmarks)

- landmark_y:

  Y coordinates matrix (frames x landmarks)

- landmark_z:

  Z coordinates matrix (frames x landmarks)

- visibility:

  Visibility scores matrix (frames x landmarks)

If world landmarks are present (JSON with `world_landmarks` field),
additional assays are included:

- world_x:

  World X coordinates matrix

- world_y:

  World Y coordinates matrix

- world_z:

  World Z coordinates matrix

The `colData` contains columns `label` (landmark name), `type`
(`"landmark"`), `model` (the MediaPipe model used), and `landmark_idx`
(0-based landmark index).

## Details

MediaPipe can output landmarks in two formats:

**JSON (directory of per-frame files):** Each JSON file contains a
`"landmarks"` array where each element has `x`, `y`, `z`, and
`visibility` fields. Optionally, a `"world_landmarks"` array may be
present with world-space coordinates.

**CSV (single file):** Columns named `landmark_0_x`, `landmark_0_y`,
`landmark_0_z`, `landmark_0_visibility`, `landmark_1_x`, etc. Each row
corresponds to one frame.

**Pose model** (33 landmarks): Full body landmarks from nose to feet.

**Hand model** (21 landmarks): Hand landmarks from wrist to fingertips.

## References

Lugaresi C, Tang J, Nash H, McClanahan C, Uboweja E, Hays M, Zhang F,
Chang CL, Yong MG, Lee J, et al. (2019). "MediaPipe: A Framework for
Building Perception Pipelines." arXiv:1906.08172.

## See also

[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md),
[`readDeepLabCut()`](https://x-biosignal.github.io/PhysioMoCap/reference/readDeepLabCut.md),
[`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md)

## Examples

``` r
set.seed(42)
cols <- list()
for (j in 0:32) {
  cols[[paste0("landmark_", j, "_x")]] <- runif(5)
  cols[[paste0("landmark_", j, "_y")]] <- runif(5)
  cols[[paste0("landmark_", j, "_z")]] <- runif(5, -0.1, 0.1)
  cols[[paste0("landmark_", j, "_visibility")]] <- runif(5, 0.5, 1.0)
}
path <- tempfile(fileext = ".csv")
write.csv(as.data.frame(cols), path, row.names = FALSE)
pe <- readMediaPipe(path, model = "pose", fps = 30)
pe
#> class: PhysioExperiment
#> dim: 5 x 33 
#> assays(4): landmark_x, landmark_y, landmark_z ...
#> samplingRate: 30 Hz
#> channels(33): nose, left_eye_inner, left_eye, left_eye_outer, right_eye_inner ...
#> colData names(4): label, type, model, landmark_idx
```
