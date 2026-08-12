# Read AMC Motion Capture File (.amc)

Parses an Acclaim Motion Capture (AMC) file containing frame-by-frame
joint angle data. AMC files store joint angles per frame, with each
frame listing joint names followed by their DOF values. An optional ASF
skeleton can be provided for validation and DOF mapping.

## Usage

``` r
readAMC(path, asf = NULL, fps = 120)
```

## Arguments

- path:

  Character string giving the path to the `.amc` file.

- asf:

  An `ASFSkeleton` object (from
  [`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)),
  or `NULL`. If provided, used for DOF validation and enriched metadata.

- fps:

  Numeric frame rate in Hz. AMC files do not store frame rate, so this
  must be specified (default: 120).

## Value

A `PhysioExperiment` object with:

- assays:

  `rotation_x`, `rotation_y`, `rotation_z` for all joints; `position_x`,
  `position_y`, `position_z` for the root joint only.

- colData:

  DataFrame with `label` (joint names), `type` (`"root"` or `"joint"`),
  and `dof_count` (number of DOFs).

- metadata:

  List with `asf_skeleton` (if provided), `source_file`, and `units`
  (from ASF if provided).

- samplingRate:

  Set to `fps`.

## References

CMU Graphics Lab (2003). "CMU Motion Capture Database."
<http://mocap.cs.cmu.edu/>.

## See also

[`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)
for reading skeleton definitions in ASF format,
[`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md)
for reading motion capture data from CSV files.

## Examples

``` r
asf_file <- system.file("testdata", "sample.asf", package = "PhysioMoCap")
amc_file <- system.file("testdata", "sample.amc", package = "PhysioMoCap")
if (nzchar(asf_file) && nzchar(amc_file)) {
  skel <- readASF(asf_file)
  pe <- readAMC(amc_file, asf = skel)
  pe
}
#> class: PhysioExperiment
#> dim: 3 x 3 
#> assays(6): rotation_x, rotation_y, rotation_z ...
#> samplingRate: 120 Hz
#> channels(3): root, lfemur, ltibia
#> colData names(3): label, type, dof_count
```
