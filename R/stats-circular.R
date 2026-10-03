# Circular statistics re-exported from PhysioCore (single source of truth).
# The implementations moved to PhysioCore/R/stats-circular.R; these re-exports
# keep existing PhysioMoCap::circularSummary / rayleighTest / watsonWilliamsTest
# / circularLinearCorrelation calls working. The print.circular_summary S3
# method is registered in PhysioCore and dispatches wherever PhysioCore is
# loaded.

#' @importFrom PhysioExperiment circularSummary
#' @export
PhysioExperiment::circularSummary

#' @importFrom PhysioExperiment rayleighTest
#' @export
PhysioExperiment::rayleighTest

#' @importFrom PhysioExperiment watsonWilliamsTest
#' @export
PhysioExperiment::watsonWilliamsTest

#' @importFrom PhysioExperiment circularLinearCorrelation
#' @export
PhysioExperiment::circularLinearCorrelation
