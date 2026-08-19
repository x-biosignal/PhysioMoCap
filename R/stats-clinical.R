# Clinimetrics re-exported from PhysioCore (single source of truth).
# The implementations live in PhysioCore/R/clinimetrics.R; these re-exports keep
# existing PhysioMoCap::icc / sem / mdc / cohensD / etaSquared / blandAltman
# calls working for back-compatibility.

#' @importFrom PhysioCore icc
#' @export
PhysioCore::icc

#' @importFrom PhysioCore sem
#' @export
PhysioCore::sem

#' @importFrom PhysioCore mdc
#' @export
PhysioCore::mdc

#' @importFrom PhysioCore cohensD
#' @export
PhysioCore::cohensD

#' @importFrom PhysioCore etaSquared
#' @export
PhysioCore::etaSquared

#' @importFrom PhysioCore blandAltman
#' @export
PhysioCore::blandAltman
