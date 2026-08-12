# Detect Trendelenburg sign (excessive contralateral pelvic drop)

A Trendelenburg gait reflects hip-abductor weakness on the stance limb:
the contralateral (swing-side) pelvis drops during single-limb stance
beyond the normal small obliquity (\\\approx 4-5^{\circ}\\).

## Usage

``` r
detectTrendelenburg(
  pelvic_obliquity,
  stance = c(10, 50),
  threshold = 5,
  severe = 15,
  drop_sign = 1
)
```

## Arguments

- pelvic_obliquity:

  Pelvic obliquity (degrees) over one gait cycle, with the contralateral
  drop being positive (see `drop_sign`).

- stance:

  Percentage window of stance (default `c(10, 50)`, single-limb).

- threshold:

  Drop (deg) above which Trendelenburg is flagged (default 5).

- severe:

  Drop mapped to severity 1 (default 15 deg).

- drop_sign:

  `+1` if positive obliquity is a contralateral drop, `-1` otherwise.

## Value

A `gait_pattern_flag` object.

## References

Perry J, Burnfield JM (2010).

## See also

[`classifyGaitPatterns()`](https://x-biosignal.github.io/PhysioMoCap/reference/classifyGaitPatterns.md)
