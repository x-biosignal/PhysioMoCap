# Validate marker labels for a marker-trajectory write

Empty labels are indistinguishable from padding in the TRC/C3D layout,
and duplicate labels collapse markers on a C3D write; both silently
corrupt the round-trip, so they are rejected up front.

## Usage

``` r
.validate_marker_labels(markers)
```

## Arguments

- markers:

  Character vector of marker labels.

## Value

Invisibly `TRUE`; stops on empty or duplicated labels.
