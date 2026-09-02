% Please edit documentation in R/opensim-integration.R
\name{readOpenSimOutputs}
\alias{readOpenSimOutputs}
\title{Read OpenSim Output Files}
\usage{
readOpenSimOutputs(files, format = c("auto", "mot", "sto", "trc"))
}
\arguments{
\item{files}{Character vector of file paths.}
\item{format}{One of \code{"auto"}, \code{"mot"}, \code{"sto"}, \code{"trc"}.}
}
\value{
Named list of PhysioExperiment objects.
}
\description{
Reads one or more OpenSim output files and returns PhysioExperiment objects.
}
\seealso{
\code{\link[=readMOT]{readMOT()}}, \code{\link[=readSTO]{readSTO()}}, \code{\link[=readTRC]{readTRC()}}
}
