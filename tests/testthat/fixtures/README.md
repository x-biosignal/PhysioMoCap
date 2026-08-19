# PhysioMoCap test fixtures

## `gaitcycle_id_reference.rds` — gait-cycle inverse-dynamics reference (WSCB-08, WSCB-09)

An independent joint-moment reference used to cross-validate the recursive
Newton-Euler inverse dynamics behind `inverseDynamics2D()`.

- **Reference method**: a two-link (thigh + shank) swing chain with
  gait-cycle-shaped absolute segment angles. The hip and knee joint moments are
  derived from the **Lagrangian** (energy) formalism —
  `d/dt(∂L/∂q̇) − ∂L/∂q = τ` in absolute segment angles, with
  `M_knee = τ₂` and `M_hip = τ₁ + τ₂`. This is wholly independent of the
  Newton-Euler recursion the package uses, so agreement is a genuine
  cross-check rather than a snapshot.
- **Contents**: `joints` (marker trajectories with a vestigial toe marker),
  `grf` (zero — swing phase), `inertia` (segment mass / COM / moment table),
  `sampling_rate`, `reference` (`hip_moment`, `knee_moment`), `provenance`.
- **Gate** (`test-inverse-dynamics.R`): `inverseDynamics2D(model = "newton_euler")`
  reproduces the Lagrangian hip and knee moments with correlation r > 0.95 and
  peak error < 10% (measured r = 1.000, peak error ≈ 0.2%). The differentiation
  edges (first/last five frames) are excluded.
- **Scope / follow-up**: the reference covers the swing phase (no ground
  contact), which exercises the segment-weight `m·g`, linear-inertia `m·a_com`
  and angular-inertia `I·α` terms and the distal→proximal chaining that WSCB-08
  fixed. A full stance-phase reference against the OpenSim 4.x Inverse Dynamics
  Tool is a follow-up (OpenSim is not available in this environment); the
  separate `gait2392_id_reference.rds` slot in `test-inverse-dynamics.R` is
  reserved for it and its test skips until that file is bundled.

Regenerate with:

```r
Rscript physio-ecosystem/publication/scripts/validate_correctness_fixes.R --write
```
