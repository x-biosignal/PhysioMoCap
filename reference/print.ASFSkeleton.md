# Print method for ASFSkeleton objects

Print method for ASFSkeleton objects

## Usage

``` r
# S3 method for class 'ASFSkeleton'
print(x, ...)
```

## Arguments

- x:

  An `ASFSkeleton` object.

- ...:

  Additional arguments (ignored).

## Value

Invisibly returns `x`.

## References

CMU Graphics Lab (2003). "CMU Motion Capture Database."
<http://mocap.cs.cmu.edu/>.

## See also

[`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)
for reading ASF skeleton files,
[`readAMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readAMC.md)
for reading AMC motion data.

## Examples

``` r
f <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
if (nzchar(f)) {
  skeleton <- readASF(f)
  print(skeleton)
}
#> ASF Skeleton
#>   Units: mass = 1, length = 0.45, angle = deg 
#>   Root: position = 0, 0, 0 | order = TX TY TZ RX RY RZ 
#>   Bones: 2 
#>     Names: lfemur, ltibia 
#>   Hierarchy:
#>      root -> lfemur 
#>      lfemur -> ltibia 
```
