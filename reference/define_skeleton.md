# Create a pre-defined skeleton model

Factory function that returns a `SkeletonModel` for a well-known pose
estimation or motion capture marker set.

## Usage

``` r
define_skeleton(model_name)
```

## Arguments

- model_name:

  Character string. One of:

  `"BODY_25"`

  :   OpenPose BODY_25 model (25 keypoints, 24 bones).

  `"COCO"`

  :   OpenPose COCO model (18 keypoints, 17 bones).

  `"BlazePose"`

  :   MediaPipe BlazePose model (33 keypoints, 35 bones).

  `"PluginGait"`

  :   Vicon Plug-in Gait full-body marker set (39 markers, 38 bones).

## Value

A `SkeletonModel` object.

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
print(sk)
#> SkeletonModel: BODY_25 
#>   Keypoints: 25 
#>   Bones:     24 
#>   Root:      MidHip 
#>   Regions:   head, torso, right_arm, left_arm, pelvis, right_leg, left_leg, left_foot, right_foot 

sk_coco <- define_skeleton("COCO")
get_bone_connections(sk_coco)
#>    from_label  to_label         bone_name
#> 1        Neck RShoulder    right_clavicle
#> 2        Neck LShoulder     left_clavicle
#> 3   RShoulder    RElbow   right_upper_arm
#> 4      RElbow    RWrist     right_forearm
#> 5   LShoulder    LElbow    left_upper_arm
#> 6      LElbow    LWrist      left_forearm
#> 7        Neck      RHip   right_hip_joint
#> 8        RHip     RKnee       right_thigh
#> 9       RKnee    RAnkle       right_shank
#> 10       Neck      LHip    left_hip_joint
#> 11       LHip     LKnee        left_thigh
#> 12      LKnee    LAnkle        left_shank
#> 13       Neck      Nose              neck
#> 14       Nose      REye nose_to_right_eye
#> 15       REye      REar  right_eye_to_ear
#> 16       Nose      LEye  nose_to_left_eye
#> 17       LEye      LEar   left_eye_to_ear
```
