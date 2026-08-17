# Floquet multipliers (orbital stability of a cyclic movement)

Quantifies how quickly perturbations to a limit-cycle movement (e.g.
gait) decay from one stride to the next. At each phase of the cycle a
linear Poincare (return) map is fitted between the SAME phase in
consecutive strides (`dS_{n+1} = J dS_n`); the Floquet multipliers are
its eigenvalues. The maximum modulus \< 1 means the movement is
orbitally stable (perturbations shrink stride to stride).

## Usage

``` r
floquetMultipliers(states)
```

## Arguments

- states:

  Either a `[stride, phase, state]` array, or a list of `phase x state`
  matrices (one per stride). Strides must be consecutive and sampled at
  the same phases; the state is a vector (e.g. joint angles and
  velocities).

## Value

a `floquet_result`: `max_multiplier` (largest modulus over phases),
`multipliers` (eigenvalues of the section return map), `per_phase_max`
(the Dingwell per-phase maximum multiplier) and `orbitally_stable`.

## References

Hurmuzlu Y, Basdogan C (1994) J Biomech Eng 116:30-36; Dingwell JB, Kang
HG (2007) J Biomech Eng 129:586-593.

## See also

[`recurrenceQuantification()`](https://x-biosignal.github.io/PhysioMoCap/reference/recurrenceQuantification.md),
[`maxLyapunovExponent()`](https://x-biosignal.github.io/PhysioMoCap/reference/maxLyapunovExponent.md)

## Examples

``` r
set.seed(1)
A <- matrix(c(0.5, 0.1, 0, 0.3), 2, 2)             # stride-to-stride return map
P <- 4; nS <- 80; strides <- array(0, c(nS, P, 2)); d <- rnorm(2)
cyc <- cbind(sin(1:P), cos(1:P))
for (n in 1:nS) { for (k in 1:P) strides[n, k, ] <- cyc[k, ] + d
  d <- as.numeric(A %*% d) + rnorm(2, 0, 0.01) }
floquetMultipliers(strides)$max_multiplier          # ~ 0.5 (< 1, stable)
#> [1] 0.4317407
```
