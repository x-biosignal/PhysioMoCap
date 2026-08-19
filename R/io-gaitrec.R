# GaitRec Dataset I/O Functions
# Reader for GaitRec clinical gait dataset (Horsak et al., 2020)
# Dataset DOI: 10.6084/m9.figshare.c.4788012.v1

#' Read GaitRec Dataset
#'
#' Reads ground reaction force (GRF) data or spatiotemporal parameters from
#' the GaitRec dataset format (Horsak et al., 2020). GaitRec is a large-scale
#' clinical gait dataset containing GRF waveforms and gait parameters from
#' patients with various lower-limb orthopaedic conditions and healthy controls.
#'
#' @param path Path to a GaitRec CSV file or a directory containing GaitRec
#'   CSV files. When a directory is given, all CSV files matching the specified
#'   `type` are read and combined.
#' @param type Type of data to read: `"grf"` for ground reaction force
#'   waveforms or `"parameters"` for spatiotemporal parameters. Default
#'   `"grf"`.
#' @param sr Sampling rate in Hz. Default `1000` for GaitRec GRF data. For
#'   time-normalised waveforms (101 data points representing 0--100\% of the
#'   gait cycle), this value is used as a nominal sampling rate in the
#'   resulting PhysioExperiment object.
#' @param sep Column separator in the CSV file. Default `","`. Set to
#'   `"\t"` for tab-separated files.
#' @param subject_id Optional subject identifier string to store in the
#'   returned object's metadata. When `path` is a directory this is ignored
#'   and identifiers are extracted from file names.
#'
#' @return For `type = "grf"`: a `PhysioExperiment` object with a `"raw"`
#'   assay containing the GRF data matrix (time points x channels). The
#'   `colData` records channel labels, force component (`"Fx"`, `"Fy"`,
#'   `"Fz"`), plate number, and unit (`"N"`). Metadata includes
#'   `source_file`, `format`, and `subject_id`.
#'
#'   For `type = "parameters"`: a `data.frame` with spatiotemporal gait
#'   parameters extracted from the CSV file.
#'
#' @details
#' ## GaitRec GRF file format
#'
#' GaitRec GRF CSV files typically contain columns for time and force
#' components from two force plates:
#' \itemize{
#'   \item A time column (e.g., `"time"`, `"Time"`, `"t"`)
#'   \item Force columns following naming patterns like `"Fx1"`, `"Fy1"`,
#'     `"Fz1"`, `"Fx2"`, `"Fy2"`, `"Fz2"` (plate number suffix) or
#'     `"FP1_Fx"`, `"FP1_Fy"`, `"FP1_Fz"`, `"FP2_Fx"`, etc. (plate prefix)
#' }
#'
#' The function auto-detects force column naming patterns and extracts the
#' component (x/y/z) and plate number. Columns that do not match recognised
#' force patterns are stored in `metadata(pe)$extra_columns` as a
#' data.frame.
#'
#' Time-normalised waveforms (101 data points, 0--100\% gait cycle) are
#' also supported. The parser detects these by row count and stores a
#' `percent_gait_cycle` vector in the metadata.
#'
#' @references
#' Horsak B, Slijepcevic D, Raberger A-M, Schwab C, Worisch M, Zeppelzauer M
#' (2020). "GaitRec, a large-scale ground reaction force dataset of healthy
#' and impaired gait." *Scientific Data*, 7, 143.
#' \doi{10.1038/s41597-020-0481-z}
#'
#' @seealso [readMoCapCSV()] for generic CSV motion capture data,
#'   [filterGRF()] for low-pass filtering GRF signals,
#'   [analyzeForcePlate()] for force plate analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Read a single GRF file
#' pe <- readGaitRec("path/to/gaitrec_grf.csv")
#'
#' # Read spatiotemporal parameters
#' params <- readGaitRec("path/to/gaitrec_params.csv", type = "parameters")
#'
#' # Read with tab separator
#' pe <- readGaitRec("path/to/gaitrec.tsv", sep = "\t")
#' }
readGaitRec <- function(path,
                        type = c("grf", "parameters"),
                        sr = 1000,
                        sep = ",",
                        subject_id = NULL) {
  type <- match.arg(type)

  # --- Input validation ---
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("'path' must be a non-empty character string.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("Path does not exist: ", path, call. = FALSE)
  }
  stopifnot(is.numeric(sr), length(sr) == 1, sr > 0)

  # --- Directory handling ---
  if (file.info(path)$isdir) {
    return(.read_gaitrec_directory(path, type = type, sr = sr, sep = sep))
  }

  # --- Single file ---
  if (type == "parameters") {
    return(.read_gaitrec_parameters(path, sep = sep))
  }

  .read_gaitrec_grf(path, sr = sr, sep = sep, subject_id = subject_id)
}


#' Read a directory of GaitRec files
#'
#' Scans a directory for CSV files and reads them individually with
#' [readGaitRec()]. GRF files are combined into a list; parameter files are
#' row-bound into a single data.frame.
#'
#' @param dir_path Path to the directory.
#' @param type Data type (`"grf"` or `"parameters"`).
#' @param sr Sampling rate for GRF data.
#' @param sep Column separator.
#'
#' @return For `"grf"`: a named list of PhysioExperiment objects (one per
#'   file). For `"parameters"`: a data.frame combining all parameter files.
#' @keywords internal
#' @noRd
.read_gaitrec_directory <- function(dir_path, type, sr, sep) {
  csv_files <- list.files(dir_path, pattern = "\\.csv$|\\.tsv$",
                          full.names = TRUE, recursive = TRUE)
  if (length(csv_files) == 0) {
    stop("No CSV/TSV files found in directory: ", dir_path, call. = FALSE)
  }

  if (type == "parameters") {
    param_list <- lapply(csv_files, function(f) {
      tryCatch(
        .read_gaitrec_parameters(f, sep = sep),
        error = function(e) NULL
      )
    })
    param_list <- param_list[!vapply(param_list, is.null, logical(1))]
    if (length(param_list) == 0) {
      stop("No valid parameter files found in: ", dir_path, call. = FALSE)
    }
    return(do.call(rbind, param_list))
  }

  # GRF type: return named list of PE objects
  pe_list <- list()
  for (f in csv_files) {
    sid <- tools::file_path_sans_ext(basename(f))
    pe <- tryCatch(
      .read_gaitrec_grf(f, sr = sr, sep = sep, subject_id = sid),
      error = function(e) {
        message("[readGaitRec] Skipping '", basename(f), "': ",
                conditionMessage(e))
        NULL
      }
    )
    if (!is.null(pe)) {
      pe_list[[sid]] <- pe
    }
  }

  if (length(pe_list) == 0) {
    stop("No valid GRF files found in: ", dir_path, call. = FALSE)
  }

  pe_list
}


#' Read a single GaitRec GRF CSV file
#'
#' Parses a CSV file containing ground reaction force data and returns a
#' PhysioExperiment object.
#'
#' @param path File path.
#' @param sr Sampling rate in Hz.
#' @param sep Column separator.
#' @param subject_id Optional subject identifier.
#'
#' @return A PhysioExperiment object.
#' @keywords internal
#' @noRd
.read_gaitrec_grf <- function(path, sr, sep, subject_id = NULL) {
  # Read the CSV
  data <- utils::read.csv(path, sep = sep, header = TRUE,
                          stringsAsFactors = FALSE, check.names = FALSE)

  if (nrow(data) == 0) {
    stop("GRF file is empty: ", basename(path), call. = FALSE)
  }

  col_names <- colnames(data)

  # --- Detect and extract time column ---
  time_col_idx <- which(tolower(col_names) %in% c("time", "t", "time_s",
                                                    "frame_time"))
  time_values <- NULL
  if (length(time_col_idx) > 0) {
    time_values <- suppressWarnings(as.numeric(data[[time_col_idx[1]]]))
    if (all(is.na(time_values))) {
      time_values <- NULL
    }
  }

  # --- Detect force columns ---
  # Supported naming patterns:
  #   Pattern 1: Fx1, Fy1, Fz1, Fx2, Fy2, Fz2 (component + plate suffix)
  #   Pattern 2: FP1_Fx, FP1_Fy, FP1_Fz, FP2_Fx, ... (plate prefix)
  #   Pattern 3: Force_Fx_1, Force_Fy_1, ... (longer descriptive)
  #   Pattern 4: GRF_X_1, GRF_Y_1, GRF_Z_1 (GRF prefix)
  #   Pattern 5: Fx, Fy, Fz (single force plate, no number)
  force_info <- .detect_gaitrec_force_columns(col_names)

  if (length(force_info$indices) == 0) {
    stop(
      "No force columns detected in: ", basename(path), "\n",
      "Expected column patterns like Fx1/Fy1/Fz1, FP1_Fx/FP1_Fy/FP1_Fz, ",
      "or similar.\n",
      "Found columns: ", paste(col_names, collapse = ", "),
      call. = FALSE
    )
  }

  # --- Build data matrix ---
  force_data <- as.matrix(data[, force_info$indices, drop = FALSE])
  storage.mode(force_data) <- "double"
  n_time <- nrow(force_data)
  n_channels <- ncol(force_data)

  channel_labels <- force_info$labels
  colnames(force_data) <- channel_labels
  rownames(force_data) <- as.character(seq_len(n_time))

  # --- Build colData ---
  col_data <- S4Vectors::DataFrame(
    label = channel_labels,
    component = force_info$components,
    plate = force_info$plates,
    unit = rep("N", n_channels),
    type = rep("force", n_channels),
    row.names = channel_labels
  )

  # --- Build metadata ---
  meta <- list(
    format = "gaitrec",
    source_file = basename(path)
  )

  if (!is.null(subject_id)) {
    meta[["subject_id"]] <- subject_id
  }

  if (!is.null(time_values)) {
    meta[["time"]] <- time_values
  }

  # Detect time-normalised waveforms (101 points = 0-100% gait cycle)
  if (n_time == 101) {
    meta[["percent_gait_cycle"]] <- seq(0, 100, length.out = 101)
    meta[["time_normalized"]] <- TRUE
  }

  # Store any extra (non-force, non-time) columns in metadata
  all_used_idx <- c(time_col_idx, force_info$indices)
  extra_idx <- setdiff(seq_along(col_names), all_used_idx)
  if (length(extra_idx) > 0) {
    meta[["extra_columns"]] <- data[, extra_idx, drop = FALSE]
  }

  PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = force_data),
    colData = col_data,
    metadata = meta,
    samplingRate = sr
  )
}


#' Detect force column naming patterns in GaitRec data
#'
#' Identifies columns that represent force components and extracts their
#' component label (Fx/Fy/Fz) and plate number.
#'
#' @param col_names Character vector of column names.
#' @return A list with elements:
#'   - `indices`: integer vector of column positions
#'   - `labels`: character vector of standardised labels (e.g., "Fx1", "Fy1")
#'   - `components`: character vector of force components ("Fx", "Fy", "Fz")
#'   - `plates`: integer vector of plate numbers
#' @keywords internal
#' @noRd
.detect_gaitrec_force_columns <- function(col_names) {
  indices <- integer(0)
  labels <- character(0)
  components <- character(0)
  plates <- integer(0)

  # Pattern 1: Fx1, Fy1, Fz1, Fx2, Fy2, Fz2
  pat1 <- "^[Ff]([xyzXYZ])([0-9]+)$"
  matches1 <- grep(pat1, col_names)
  if (length(matches1) >= 2) {
    for (idx in matches1) {
      m <- regmatches(col_names[idx], regexec(pat1, col_names[idx]))[[1]]
      comp <- paste0("F", tolower(m[2]))
      plate <- as.integer(m[3])
      indices <- c(indices, idx)
      labels <- c(labels, paste0(comp, plate))
      components <- c(components, comp)
      plates <- c(plates, plate)
    }
    return(list(indices = indices, labels = labels,
                components = components, plates = plates))
  }

  # Pattern 2: FP1_Fx, FP1_Fy, FP1_Fz, FP2_Fx, ...
  pat2 <- "^[Ff][Pp]([0-9]+)[_]([Ff][xyzXYZ])$"
  matches2 <- grep(pat2, col_names)
  if (length(matches2) >= 2) {
    for (idx in matches2) {
      m <- regmatches(col_names[idx], regexec(pat2, col_names[idx]))[[1]]
      plate <- as.integer(m[2])
      comp <- paste0("F", tolower(substring(m[3], 2)))
      indices <- c(indices, idx)
      labels <- c(labels, paste0(comp, plate))
      components <- c(components, comp)
      plates <- c(plates, plate)
    }
    return(list(indices = indices, labels = labels,
                components = components, plates = plates))
  }

  # Pattern 3: Force_Fx_1, Force_Fy_1, Force_Fz_1, ...
  pat3 <- "^[Ff]orce[_]([Ff][xyzXYZ])[_]([0-9]+)$"
  matches3 <- grep(pat3, col_names)
  if (length(matches3) >= 2) {
    for (idx in matches3) {
      m <- regmatches(col_names[idx], regexec(pat3, col_names[idx]))[[1]]
      comp <- paste0("F", tolower(substring(m[2], 2)))
      plate <- as.integer(m[3])
      indices <- c(indices, idx)
      labels <- c(labels, paste0(comp, plate))
      components <- c(components, comp)
      plates <- c(plates, plate)
    }
    return(list(indices = indices, labels = labels,
                components = components, plates = plates))
  }

  # Pattern 4: GRF_X_1, GRF_Y_1, GRF_Z_1, ...
  pat4 <- "^[Gg][Rr][Ff][_]([xyzXYZ])[_]([0-9]+)$"
  matches4 <- grep(pat4, col_names)
  if (length(matches4) >= 2) {
    for (idx in matches4) {
      m <- regmatches(col_names[idx], regexec(pat4, col_names[idx]))[[1]]
      comp <- paste0("F", tolower(m[2]))
      plate <- as.integer(m[3])
      indices <- c(indices, idx)
      labels <- c(labels, paste0(comp, plate))
      components <- c(components, comp)
      plates <- c(plates, plate)
    }
    return(list(indices = indices, labels = labels,
                components = components, plates = plates))
  }

  # Pattern 5: Fx, Fy, Fz (single plate, no number suffix)
  pat5 <- "^[Ff]([xyzXYZ])$"
  matches5 <- grep(pat5, col_names)
  if (length(matches5) >= 2) {
    for (idx in matches5) {
      m <- regmatches(col_names[idx], regexec(pat5, col_names[idx]))[[1]]
      comp <- paste0("F", tolower(m[2]))
      indices <- c(indices, idx)
      labels <- c(labels, comp)
      components <- c(components, comp)
      plates <- c(plates, 1L)
    }
    return(list(indices = indices, labels = labels,
                components = components, plates = plates))
  }

  list(indices = indices, labels = labels,
       components = components, plates = plates)
}


#' Read GaitRec spatiotemporal parameter file
#'
#' Reads a CSV file containing spatiotemporal gait parameters (e.g., stride
#' length, cadence, stance time) and returns a data.frame.
#'
#' @param path File path.
#' @param sep Column separator.
#' @return A data.frame with gait parameters.
#' @keywords internal
#' @noRd
.read_gaitrec_parameters <- function(path, sep) {
  data <- utils::read.csv(path, sep = sep, header = TRUE,
                          stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(data) == 0) {
    stop("Parameter file is empty: ", basename(path), call. = FALSE)
  }

  # Add source file column for traceability
  data[["source_file"]] <- basename(path)

  data
}
