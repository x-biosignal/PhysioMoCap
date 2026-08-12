# ACL return-to-sport pipeline (limb symmetry index)

Computes the Limb Symmetry Index (LSI) for a battery of functional tests
and evaluates the return-to-sport (RTS) criterion that every LSI meets a
threshold (default 90\\ tests where a higher score is better, and
inverted otherwise.

## Usage

``` r
pipelineACLrts(tests, threshold = 90)
```

## Arguments

- tests:

  A data frame with columns `test`, `involved`, `uninvolved`, and
  optionally `higher_better` (logical, default `TRUE`); or a named list
  of `c(involved, uninvolved)` pairs.

- threshold:

  LSI percentage required to pass each test (default 90).

## Value

An `acl_rts_report` object with a per-test `lsi` data frame and the
overall `rts_ready` flag.

## References

Grindem H, et al. (2016). Br J Sports Med 50(13):804-808.
