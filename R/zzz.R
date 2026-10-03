#' @examples
#' # Synthetic demo data gets you started without external files
#' demo <- demoMoCapData(seed = 1)
#' demo$mocap
#' # Most operations take a PhysioExperiment and add a result assay
#' vel <- computeVelocity(demo$mocap)
#' SummarizedExperiment::assayNames(vel)
#' @keywords internal
#' @importFrom stats approx cor fft prcomp sd qnorm pt hclust as.dist setNames
#'   filter ccf lm.fit IQR median cutree var
#' @importFrom utils modifyList combn head
#' @importFrom rlang .data
#' @importFrom PhysioExperiment PhysioExperiment defaultAssay samplingRate channelNames nChannels
"_PACKAGE"
