## CRAN Submission Notes (Template)

### Test environments

- Local macOS Sequoia 15.6, R 4.5.2
- `devtools::check(cran = TRUE, remote = FALSE, manual = FALSE)`

### R CMD check results

- 0 errors
- 0 warnings
- 0 notes

### Key changes included in this submission

- Beginner onboarding and readiness assessment:
  - `readMoCapAuto()`
  - `assessMoCapReadiness()`
  - `quickStartMoCap()` enhancements
- Multi-plate force-plate support:
  - `detectForcePlateContacts()`
  - `analyzeForcePlatePE(..., plate_index = "auto" | "all")`
- 3D inverse dynamics:
  - `inverseDynamics3D()`
- Additional tests and vignette updates for first-time users.
