# Read ASF Skeleton Definition File (.asf)

Parses an Acclaim Skeleton File (ASF) that defines the skeleton
hierarchy, bone properties, and degrees of freedom. ASF files contain
sections for units, root configuration, bone data, and hierarchy
relationships.

## Usage

``` r
readASF(path)
```

## Arguments

- path:

  Character string giving the path to the `.asf` file.

## Value

An S3 object of class `"ASFSkeleton"` with components:

- units:

  Named list of unit definitions (mass, length, angle).

- root:

  List with root joint configuration: position, orientation, order, and
  axis.

- bones:

  Named list of bone definitions, each with id, name, direction, length,
  axis, dof, and limits.

- hierarchy:

  Named list mapping parent joint names to character vectors of child
  joint names.

## References

CMU Graphics Lab (2003). "CMU Motion Capture Database."
<http://mocap.cs.cmu.edu/>.

## See also

[`readAMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readAMC.md)
for reading motion data in AMC format,
[`print.ASFSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/print.ASFSkeleton.md)
for displaying skeleton structure.

## Examples

``` r
asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
if (nzchar(asf_file)) {
  skel <- readASF(asf_file)
  skel
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
