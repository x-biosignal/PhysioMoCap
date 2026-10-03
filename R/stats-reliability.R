# Waveform reliability re-exported from PhysioCore (single source of truth). The
# implementations moved to PhysioCore/R/stats-reliability.R; these re-exports
# keep existing PhysioMoCap::waveformCMC / waveformICC / waveformReliability
# calls working. The print.waveform_icc / print.waveform_reliability S3 methods
# are registered in PhysioCore.

#' @importFrom PhysioExperiment waveformCMC
#' @export
PhysioExperiment::waveformCMC

#' @importFrom PhysioExperiment waveformICC
#' @export
PhysioExperiment::waveformICC

#' @importFrom PhysioExperiment waveformReliability
#' @export
PhysioExperiment::waveformReliability
