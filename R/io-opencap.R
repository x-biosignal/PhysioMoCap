# OpenCap API Client
# Download motion capture data from the OpenCap cloud platform

#' Read Data from OpenCap Cloud Platform
#'
#' Downloads motion capture session data from the OpenCap API
#' (\url{https://app.opencap.ai}). Marker trajectory data is returned as TRC
#' format and kinematics data as MOT format, both parsed using the existing
#' \code{\link{readTRC}} and \code{\link{readMOT}} functions.
#'
#' @param session_id Character string giving the OpenCap session identifier
#'   (the 36-character UUID at the end of the session URL).
#' @param trial_id Character string giving the trial identifier within the
#'   session. If \code{NULL} (default), the first trial in the session is used.
#' @param api_key Character string with the OpenCap API key. If \code{NULL}
#'   (default), the key is read from the \code{OPENCAP_API_KEY} environment
#'   variable.
#' @param data_type Character string specifying the type of data to download.
#'   One of \code{"markers"} (TRC marker trajectories) or \code{"kinematics"}
#'   (MOT inverse kinematics results). Default is \code{"markers"}.
#' @param base_url Character string giving the base URL for the OpenCap API.
#'   Default is \code{"https://app.opencap.ai/api"}.
#'
#' @return A \code{PhysioExperiment} object. For \code{data_type = "markers"},
#'   this contains \code{position_x}, \code{position_y}, and \code{position_z}
#'   assays (from \code{\link{readTRC}}). For \code{data_type = "kinematics"},
#'   this contains a \code{raw} assay with joint angle data (from
#'   \code{\link{readMOT}}). Session and trial metadata are stored in
#'   \code{metadata()}.
#'
#' @details
#' The function requires the \pkg{httr} package for HTTP requests. If
#' \pkg{httr} is not installed, a clear error message is given.
#'
#' Authentication uses an API key passed via the \code{api_key} parameter or
#' the \code{OPENCAP_API_KEY} environment variable. The key is sent as a
#' Bearer token in the Authorization header.
#'
#' The download workflow is:
#' \enumerate{
#'   \item Retrieve session metadata from
#'     \code{GET /sessions/\{session_id\}/}
#'   \item List trials from
#'     \code{GET /sessions/\{session_id\}/trials/}
#'   \item Download the result file (TRC or MOT) for the selected trial
#'   \item Parse using \code{readTRC()} or \code{readMOT()}
#' }
#'
#' @references
#' Uhlrich SD, Falisse A, Kidzinski L, Muccini J, Ko M, Chaudhari AS,
#' Hicks JL, Delp SL (2023). "OpenCap: Human movement dynamics from
#' smartphone videos." PLoS Computational Biology, 19(10), e1011462.
#'
#' @seealso [readTRC()], [readMOT()], [readC3D()]
#'
#' @export
#' @examples
#' \dontrun{
#' # Download marker data (requires API key)
#' pe <- readOpenCap("abcd1234-5678-90ab-cdef-1234567890ab")
#'
#' # Download kinematics with explicit API key
#' pe <- readOpenCap(
#'   session_id = "abcd1234-5678-90ab-cdef-1234567890ab",
#'   api_key = "my-api-key",
#'   data_type = "kinematics"
#' )
#' }
readOpenCap <- function(session_id,
                        trial_id = NULL,
                        api_key = NULL,
                        data_type = c("markers", "kinematics"),
                        base_url = "https://app.opencap.ai/api") {
  # Check httr is available
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop(
      "The 'httr' package is required to download data from OpenCap. ",
      "Install it with: install.packages('httr')",
      call. = FALSE
    )
  }

  data_type <- match.arg(data_type)

  # Validate session_id
  if (!is.character(session_id) || length(session_id) != 1 || !nzchar(session_id)) {
    stop(
      "'session_id' must be a non-empty character string.\n",
      "Tip: use the session UUID from your OpenCap URL, e.g. ",
      "'abcd1234-5678-90ab-cdef-1234567890ab'.",
      call. = FALSE
    )
  }
  if (!grepl("^[A-Za-z0-9-]{8,}$", session_id)) {
    warning(
      "'session_id' looks unusual. OpenCap session IDs are typically UUID-like ",
      "strings from the session URL.",
      call. = FALSE
    )
  }

  if (!is.null(trial_id) && (!is.character(trial_id) || length(trial_id) != 1 || !nzchar(trial_id))) {
    stop("'trial_id' must be NULL or a non-empty character string.", call. = FALSE)
  }

  # Build authentication header
  auth_header <- .opencap_auth_header(api_key)

  # Normalize base URL (remove trailing slash)
  base_url <- sub("/$", "", base_url)

  # 1-2. Resolve the session and target trial
  ctx <- .opencap_resolve_trial(session_id, trial_id, auth_header, base_url)
  session_info <- ctx$session_info
  trial <- ctx$trial
  trial_id <- ctx$trial_id

  # 3. Determine which result file to download
  if (data_type == "markers") {
    # Download TRC file with marker trajectories
    result_url <- .opencap_result_url(trial, data_type, base_url,
                                      session_id, trial_id)
    dest <- tempfile(fileext = ".trc")
  } else {
    # Download MOT file with kinematics
    result_url <- .opencap_result_url(trial, data_type, base_url,
                                      session_id, trial_id)
    dest <- tempfile(fileext = ".mot")
  }

  .opencap_download_file(result_url, auth_header, dest)

  # 4. Parse with existing reader
  if (data_type == "markers") {
    pe <- readTRC(dest)
  } else {
    pe <- readMOT(dest)
  }

  # Clean up temp file
  unlink(dest)

  # 5. Enrich metadata with OpenCap session info
  md <- S4Vectors::metadata(pe)
  md[["opencap_session_id"]] <- session_id
  md[["opencap_trial_id"]] <- trial_id
  md[["opencap_data_type"]] <- data_type
  md[["opencap_base_url"]] <- base_url
  if (!is.null(trial[["name"]])) {
    md[["opencap_trial_name"]] <- trial[["name"]]
  }
  if (!is.null(session_info[["name"]])) {
    md[["opencap_session_name"]] <- session_info[["name"]]
  }
  md[["source_file"]] <- paste0("opencap://", session_id, "/", trial_id)
  S4Vectors::metadata(pe) <- md


  pe
}


#' Download the OpenSim Model for an OpenCap Session
#'
#' Downloads the subject-specific, scaled OpenSim model (\code{.osim}) that
#' OpenCap produced for a session. This model is the input the local OpenSim
#' toolchain needs (\code{\link{runOpenSimFromMarkers}} /
#' \code{\link{runOpenSimFromOpenCap}}): OpenCap builds and scales it in the
#' cloud from the neutral/calibration trial, and \pkg{PhysioOpenSim} provides no
#' scaling tool of its own, so the model must come from OpenCap.
#'
#' @inheritParams readOpenCap
#' @param dest Character path to write the model to. If \code{NULL} (default) a
#'   temporary \code{.osim} file is created.
#' @return The local path to the downloaded \code{.osim} model (invisibly).
#' @details Requires the \pkg{httr} package and an OpenCap API key (see
#'   \code{\link{readOpenCap}}). The model URL is taken from the session
#'   metadata when present and otherwise constructed from the documented
#'   session endpoint.
#' @seealso [readOpenCap()], [runOpenSimFromOpenCap()], [runOpenSimFromMarkers()]
#' @references
#' Uhlrich SD, Falisse A, Kidzinski L, Muccini J, Ko M, Chaudhari AS,
#' Hicks JL, Delp SL (2023). "OpenCap: Human movement dynamics from
#' smartphone videos." PLoS Computational Biology, 19(10), e1011462.
#' @export
#' @examples
#' \dontrun{
#' osim <- downloadOpenCapModel("abcd1234-5678-90ab-cdef-1234567890ab")
#' }
downloadOpenCapModel <- function(session_id,
                                 trial_id = NULL,
                                 api_key = NULL,
                                 base_url = "https://app.opencap.ai/api",
                                 dest = NULL) {
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop(
      "The 'httr' package is required to download data from OpenCap. ",
      "Install it with: install.packages('httr')",
      call. = FALSE
    )
  }
  if (!is.character(session_id) || length(session_id) != 1 || !nzchar(session_id)) {
    stop("'session_id' must be a non-empty character string.", call. = FALSE)
  }
  if (!is.null(trial_id) && (!is.character(trial_id) || length(trial_id) != 1 || !nzchar(trial_id))) {
    stop("'trial_id' must be NULL or a non-empty character string.", call. = FALSE)
  }
  if (is.null(dest)) {
    dest <- tempfile(fileext = ".osim")
  } else if (!is.character(dest) || length(dest) != 1 || !nzchar(dest)) {
    stop("'dest' must be NULL or a non-empty character string.", call. = FALSE)
  }

  auth_header <- .opencap_auth_header(api_key)
  base_url <- sub("/$", "", base_url)
  ctx <- .opencap_resolve_trial(session_id, trial_id, auth_header, base_url)
  model_url <- .opencap_model_url(ctx$session_info, ctx$trial, base_url, session_id)
  .opencap_download_file(model_url, auth_header, dest)
  invisible(dest)
}


#' Build OpenCap Authentication Header
#'
#' Constructs an HTTP Authorization header from the supplied API key or the
#' \code{OPENCAP_API_KEY} environment variable.
#'
#' @param api_key Character string with the API key, or \code{NULL} to read
#'   from the environment variable.
#' @return A named character vector suitable for use as an HTTP header.
#' @keywords internal
.opencap_auth_header <- function(api_key = NULL) {
  if (is.null(api_key) || !nzchar(api_key)) {
    api_key <- Sys.getenv("OPENCAP_API_KEY", unset = "")
  }
  if (!nzchar(api_key)) {
    stop(
      "OpenCap API key not found. Provide 'api_key' argument or set the ",
      "OPENCAP_API_KEY environment variable.",
      call. = FALSE
    )
  }
  c("Authorization" = paste("Bearer", api_key))
}


#' Build an OpenCap API URL
#'
#' Constructs a URL by joining the base URL with path segments.
#'
#' @param base_url Character string with the base API URL.
#' @param ... Character path segments to append.
#' @return A single character string URL.
#' @keywords internal
.opencap_build_url <- function(base_url, ...) {
  segments <- c(...)
  # URL-encode each segment, then join with "/"
  segments <- vapply(segments, utils::URLencode, character(1),
                     reserved = FALSE)
  paste(c(base_url, segments), collapse = "/")
}


#' Determine the Result File URL for an OpenCap Trial
#'
#' Extracts or constructs the download URL for a trial's TRC or MOT file.
#'
#' @param trial List with trial metadata from the API.
#' @param data_type Character, either \code{"markers"} or \code{"kinematics"}.
#' @param base_url Character string with the base API URL.
#' @param session_id Character string with the session identifier.
#' @param trial_id Character string with the trial identifier.
#' @return A character URL for downloading the file.
#' @keywords internal
.opencap_result_url <- function(trial, data_type, base_url, session_id,
                                trial_id) {
  # Check if the trial object has a direct result URL
  if (data_type == "markers") {
    # Look for a marker result URL in the trial metadata
    url <- trial[["results"]][["marker_data"]]
    if (is.null(url) || !nzchar(url)) {
      # Fall back to constructing the URL
      url <- .opencap_build_url(
        base_url, "sessions", session_id, "trials", trial_id,
        "results", "marker_data"
      )
    }
  } else {
    # kinematics
    url <- trial[["results"]][["ik_data"]]
    if (is.null(url) || !nzchar(url)) {
      url <- .opencap_build_url(
        base_url, "sessions", session_id, "trials", trial_id,
        "results", "ik_data"
      )
    }
  }
  url
}


#' Perform a GET Request to the OpenCap API and Parse JSON
#'
#' @param url Character string with the full URL.
#' @param auth_header Named character vector with the Authorization header.
#' @return Parsed JSON response as a list.
#' @keywords internal
.opencap_get_json <- function(url, auth_header) {
  response <- httr::GET(
    url,
    httr::add_headers(.headers = auth_header),
    httr::content_type_json()
  )

  if (httr::http_error(response)) {
    status <- httr::status_code(response)
    msg <- tryCatch(
      httr::content(response, as = "text", encoding = "UTF-8"),
      error = function(e) ""
    )
    stop(
      sprintf("OpenCap API request failed (HTTP %d): %s\nURL: %s",
              status, msg, url),
      call. = FALSE
    )
  }

  httr::content(response, as = "parsed", type = "application/json")
}


#' Download a File from the OpenCap API
#'
#' Downloads a file (TRC or MOT) from the given URL to a local destination
#' with appropriate error handling.
#'
#' @param url Character string with the full download URL.
#' @param auth_header Named character vector with the Authorization header.
#' @param dest Character string giving the local file path to write to.
#' @return The destination path (invisibly).
#' @keywords internal
.opencap_download_file <- function(url, auth_header, dest) {
  response <- httr::GET(
    url,
    httr::add_headers(.headers = auth_header),
    httr::write_disk(dest, overwrite = TRUE)
  )

  if (httr::http_error(response)) {
    status <- httr::status_code(response)
    # Clean up partial download
    unlink(dest)
    stop(
      sprintf("Failed to download file from OpenCap (HTTP %d)\nURL: %s",
              status, url),
      call. = FALSE
    )
  }

  invisible(dest)
}


#' Resolve an OpenCap Session and Target Trial
#'
#' Fetches session metadata and the trial list, then selects the requested
#' trial (or the first trial when \code{trial_id} is \code{NULL}).
#'
#' @param session_id,trial_id,base_url As in \code{\link{readOpenCap}}.
#' @param auth_header Named character vector Authorization header.
#' @return A list with \code{session_info}, \code{trial}, and \code{trial_id}.
#' @keywords internal
.opencap_resolve_trial <- function(session_id, trial_id, auth_header, base_url) {
  session_url <- .opencap_build_url(base_url, "sessions", session_id)
  session_info <- .opencap_get_json(session_url, auth_header)

  trials_url <- .opencap_build_url(base_url, "sessions", session_id, "trials")
  trials_info <- .opencap_get_json(trials_url, auth_header)
  if (length(trials_info) == 0) {
    stop("No trials found for session: ", session_id, call. = FALSE)
  }

  if (is.null(trial_id)) {
    trial <- trials_info[[1]]
    trial_id <- trial[["id"]]
  } else {
    trial <- NULL
    for (t in trials_info) {
      if (identical(t[["id"]], trial_id)) {
        trial <- t
        break
      }
    }
    if (is.null(trial)) {
      stop("Trial '", trial_id, "' not found in session: ", session_id, call. = FALSE)
    }
  }

  list(session_info = session_info, trial = trial, trial_id = trial_id)
}


#' Determine the OpenSim Model URL for an OpenCap Session
#'
#' OpenCap scales one OpenSim model per session (from the neutral/calibration
#' trial). Prefer a URL supplied in the session (or trial) metadata; otherwise
#' construct it from the documented session endpoint.
#'
#' @param session_info List of session metadata from the API.
#' @param trial List of trial metadata (may be \code{NULL}).
#' @param base_url,session_id As in \code{\link{readOpenCap}}.
#' @return A character URL for the \code{.osim} model.
#' @keywords internal
.opencap_model_url <- function(session_info, trial, base_url, session_id) {
  # Accept a metadata value only if it is a single, non-NA, non-empty string;
  # anything else (NULL, "", NA, a nested object, a vector) falls through.
  as_url <- function(x) {
    if (is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)) x else NULL
  }
  url <- as_url(session_info[["openSimModel"]]) %||%
    as_url(session_info[["opensim_model"]]) %||%
    as_url(session_info[["model"]])
  if (is.null(url) && !is.null(trial)) {
    url <- as_url(trial[["results"]][["model"]])
  }
  if (is.null(url)) {
    url <- .opencap_build_url(base_url, "sessions", session_id, "opensim_model")
  }
  url
}
