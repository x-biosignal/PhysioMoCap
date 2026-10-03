# Print a SkeletonModel object

Print a SkeletonModel object

## Usage

``` r
# S3 method for class 'SkeletonModel'
print(x, ...)
```

## Arguments

- x:

  A `SkeletonModel` object.

- ...:

  Additional arguments (ignored).

## Value

Invisibly returns `x`.

## Examples

``` r
kp <- data.frame(id = 0:2, label = c("Head", "Torso", "Hip"),
                 body_region = c("head", "torso", "pelvis"),
                 stringsAsFactors = FALSE)
bones <- data.frame(from_id = c(0, 1), to_id = c(1, 2),
                    bone_name = c("neck", "spine"), stringsAsFactors = FALSE)
sk <- SkeletonModel("mini", kp, bones, list(Head = "Torso", Torso = "Hip"), "Head")
print(sk)
#> SkeletonModel: mini 
#>   Keypoints: 3 
#>   Bones:     2 
#>   Root:      Head 
#>   Regions:   head, torso, pelvis 
```
