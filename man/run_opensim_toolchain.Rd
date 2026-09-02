% Please edit documentation in R/opensim-integration.R
\name{run_opensim_toolchain}
\alias{run_opensim_toolchain}
\title{Run OpenSim CLI Toolchain via PhysioOpenSim}
\usage{
run_opensim_toolchain(
  ik_setup = NULL,
  id_setup = NULL,
  so_setup = NULL,
  rra_setup = NULL,
  cmc_setup = NULL,
  analyze_setup = NULL,
  workdir = NULL,
  cli = NULL,
  timeout_sec = 0L,
  fail_on_error = TRUE,
  extra_args = character()
)
}
\arguments{
\item{ik_setup}{Optional path to IK setup XML.}
\item{id_setup}{Optional path to ID setup XML.}
\item{so_setup}{Optional path to SO setup XML.}
\item{rra_setup}{Optional path to RRA setup XML.}
\item{cmc_setup}{Optional path to CMC setup XML.}
\item{analyze_setup}{Optional path to Analyze setup XML.}
\item{workdir}{Optional working directory for all tool runs.}
\item{cli}{Optional OpenSim CLI command/path.}
\item{timeout_sec}{Timeout in seconds for each tool execution.}
\item{fail_on_error}{If \code{TRUE}, abort on non-zero exit status.}
\item{extra_args}{Optional character vector appended to each tool run.}
}
\value{
Named list with entries for executed tools (\code{ik}, \code{id}, \code{so},
\code{rra}, \code{cmc}, \code{analyze}).
}
\description{
Executes OpenSim setup XML files sequentially through \code{PhysioOpenSim}.
}
\seealso{
\code{\link[=batch_analyze_opensim]{batch_analyze_opensim()}}, \code{\link[=create_schema_from_opensim]{create_schema_from_opensim()}}
}
