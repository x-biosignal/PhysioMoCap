# Circular statistics re-exported from PhysioCore (single source of truth).
# The implementations moved to PhysioCore/R/stats-circular.R; these re-exports
# keep existing PhysioMoCap::circularSummary / rayleighTest / watsonWilliamsTest
# / circularLinearCorrelation calls working. The print.circular_summary S3
# method is registered in PhysioCore and dispatches wherever PhysioCore is
# loaded.

#' @importFrom PhysioCore circularSummary
#' @export
PhysioCore::circularSummary

#' @importFrom PhysioCore rayleighTest
#' @export
PhysioCore::rayleighTest

#' @importFrom PhysioCore watsonWilliamsTest
#' @export
PhysioCore::watsonWilliamsTest

#' @importFrom PhysioCore circularLinearCorrelation
#' @export
PhysioCore::circularLinearCorrelation
