# Waveform reliability re-exported from PhysioCore (single source of truth). The
# implementations moved to PhysioCore/R/stats-reliability.R; these re-exports
# keep existing PhysioMoCap::waveformCMC / waveformICC / waveformReliability
# calls working. The print.waveform_icc / print.waveform_reliability S3 methods
# are registered in PhysioCore.

#' @importFrom PhysioCore waveformCMC
#' @export
PhysioCore::waveformCMC

#' @importFrom PhysioCore waveformICC
#' @export
PhysioCore::waveformICC

#' @importFrom PhysioCore waveformReliability
#' @export
PhysioCore::waveformReliability
