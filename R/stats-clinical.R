# Clinimetrics re-exported from PhysioCore (single source of truth).
# The implementations live in PhysioCore/R/clinimetrics.R; these re-exports keep
# existing PhysioMoCap::icc / sem / mdc / cohensD / etaSquared / blandAltman
# calls working for back-compatibility.

#' @importFrom PhysioExperiment icc
#' @export
PhysioExperiment::icc

#' @importFrom PhysioExperiment sem
#' @export
PhysioExperiment::sem

#' @importFrom PhysioExperiment mdc
#' @export
PhysioExperiment::mdc

#' @importFrom PhysioExperiment cohensD
#' @export
PhysioExperiment::cohensD

#' @importFrom PhysioExperiment etaSquared
#' @export
PhysioExperiment::etaSquared

#' @importFrom PhysioExperiment blandAltman
#' @export
PhysioExperiment::blandAltman
