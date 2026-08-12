# Read OpenPose JSON output

Reads OpenPose JSON keypoint data from a directory of frame files or a
single JSON file and returns a PhysioExperiment object.

## Usage

``` r
readOpenPose(path, model = c("BODY_25", "COCO"), fps = 30, person_id = 1L)
```

## Arguments

- path:

  Path to a directory of JSON files or a single JSON file.

- model:

  Keypoint model: `"BODY_25"` (25 keypoints) or `"COCO"` (18 keypoints).
  Default `"BODY_25"`.

- fps:

  Frame rate in Hz (frames per second). Default 30.

- person_id:

  Which person to extract (1-based index). Default 1 (first detected
  person).

## Value

A PhysioExperiment with assays:

- keypoint_x:

  X coordinates matrix (frames x keypoints)

- keypoint_y:

  Y coordinates matrix (frames x keypoints)

- confidence:

  Detection confidence matrix (frames x keypoints)

The `colData` contains columns `label` (keypoint name), `type`
(`"keypoint"`), and `model` (the OpenPose model used).

## Details

OpenPose outputs one JSON file per video frame. Each file contains a
`"people"` array where each person's pose is stored as a flat array of
`[x, y, confidence]` triplets.

**BODY_25 model** (25 keypoints): Nose, Neck, RShoulder, RElbow, RWrist,
LShoulder, LElbow, LWrist, MidHip, RHip, RKnee, RAnkle, LHip, LKnee,
LAnkle, REye, LEye, REar, LEar, LBigToe, LSmallToe, LHeel, RBigToe,
RSmallToe, RHeel.

**COCO model** (18 keypoints): Nose, Neck, RShoulder, RElbow, RWrist,
LShoulder, LElbow, LWrist, RHip, RKnee, RAnkle, LHip, LKnee, LAnkle,
REye, LEye, REar, LEar.

Frames where the specified person is not detected will contain `NA`
values for all keypoints.

## References

Cao Z, Hidalgo G, Simon T, Wei SE, Sheikh Y (2019). "OpenPose: Realtime
Multi-Person 2D Pose Estimation Using Part Affinity Fields." IEEE
Transactions on Pattern Analysis and Machine Intelligence, 43(1),
172-186.

## See also

[`readDeepLabCut()`](https://x-biosignal.github.io/PhysioMoCap/reference/readDeepLabCut.md),
[`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md),
[`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Read directory of OpenPose JSON files
pe <- readOpenPose("path/to/openpose_output/", fps = 30)

# Read with COCO model
pe <- readOpenPose("path/to/output/", model = "COCO", fps = 25)

# Extract second person
pe <- readOpenPose("path/to/output/", person_id = 2)
} # }
```
