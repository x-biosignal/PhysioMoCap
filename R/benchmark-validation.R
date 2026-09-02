# Benchmark and external-validation helpers
# Data-contract driven benchmarking that can run before real datasets are attached.


#' Get default benchmark thresholds
#'
#' Returns a named list of threshold values used by benchmark pass/fail logic.
#'
#' @param profile Threshold profile: `"balanced"` (default), `"strict"`,
#'   or `"lenient"`.
#'
#' @return Named list with threshold fields:
#' `rmse_max`, `mae_max`, `bias_abs_max`, `cor_min`, `icc_min`.
#'
#' @references
#' Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
#' Rater Reliability." Psychological Bulletin, 86(2), 420-428.
#'
#' @seealso [benchmarkAgreement()] for computing agreement metrics,
#'   [runBenchmarkSuite()] for running a full benchmark suite.
#'
#' @export
#'
#' @examples
#' defaultBenchmarkThresholds()
defaultBenchmarkThresholds <- function(profile = c("balanced", "strict", "lenient")) {
  profile <- match.arg(profile)

  if (profile == "strict") {
    return(list(
      rmse_max = 0.020,
      mae_max = 0.015,
      bias_abs_max = 0.010,
      cor_min = 0.980,
      icc_min = 0.950
    ))
  }

  if (profile == "lenient") {
    return(list(
      rmse_max = 0.100,
      mae_max = 0.080,
      bias_abs_max = 0.050,
      cor_min = 0.850,
      icc_min = 0.800
    ))
  }

  list(
    rmse_max = 0.050,
    mae_max = 0.040,
    bias_abs_max = 0.020,
    cor_min = 0.950,
    icc_min = 0.900
  )
}


#' Create a benchmark manifest template
#'
#' Produces a template data.frame describing benchmark trials and file paths.
#'
#' @param n Number of template rows to create.
#'
#' @return A data.frame manifest template.
#'
#' @references
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [writeBenchmarkManifest()] for writing the template to CSV,
#'   [validateBenchmarkManifest()] for validating manifest structure.
#'
#' @export
#'
#' @examples
#' benchmarkManifestTemplate(2)
benchmarkManifestTemplate <- function(n = 1L) {
  stopifnot(is.numeric(n), length(n) == 1, n >= 1)
  n <- as.integer(n)

  data.frame(
    benchmark_id = paste0("trial_", seq_len(n)),
    prediction_file = paste0("prediction_", seq_len(n), ".csv"),
    reference_file = paste0("reference_", seq_len(n), ".csv"),
    modality = rep("mocap", n),
    units = rep("SI", n),
    coordinate_system = rep("lab", n),
    sampling_rate = rep(100, n),
    notes = rep("", n),
    stringsAsFactors = FALSE
  )
}


#' Write a benchmark manifest template to CSV
#'
#' @param path Output CSV path.
#' @param n Number of template rows.
#' @param overwrite Logical; overwrite existing file if `TRUE`.
#'
#' @return Invisibly returns `path`.
#'
#' @references
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [benchmarkManifestTemplate()] for creating the manifest data.frame,
#'   [validateBenchmarkManifest()] for validating manifest structure.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' writeBenchmarkManifest("benchmark_manifest.csv", n = 3)
#' }
writeBenchmarkManifest <- function(path, n = 1L, overwrite = FALSE) {
  stopifnot(is.character(path), length(path) == 1, nzchar(path))
  stopifnot(is.logical(overwrite), length(overwrite) == 1)

  if (file.exists(path) && !overwrite) {
    stop("File already exists. Use overwrite = TRUE to replace: ", path,
         call. = FALSE)
  }

  manifest <- benchmarkManifestTemplate(n = n)
  utils::write.csv(manifest, path, row.names = FALSE)
  invisible(path)
}


#' Validate a benchmark manifest
#'
#' Checks structural validity and file existence for benchmark inputs.
#'
#' @param manifest A manifest data.frame or path to a manifest CSV.
#' @param data_dir Base directory used to resolve relative file paths.
#'
#' @return An object of class `"benchmark_manifest_validation"` with fields:
#' `valid`, `issues`, and `manifest`.
#'
#' @references
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [benchmarkManifestTemplate()] for creating manifest templates,
#'   [print.benchmark_manifest_validation()] for displaying validation results.
#'
#' @export
#'
#' @examples
#' m <- benchmarkManifestTemplate(1)
#' v <- validateBenchmarkManifest(m)
#' v$valid
validateBenchmarkManifest <- function(manifest, data_dir = ".") {
  if (is.character(manifest) && length(manifest) == 1) {
    if (!file.exists(manifest)) {
      stop("Manifest file not found: ", manifest, call. = FALSE)
    }
    manifest <- utils::read.csv(manifest, stringsAsFactors = FALSE,
                                check.names = FALSE)
  }

  if (!is.data.frame(manifest)) {
    stop("'manifest' must be a data.frame or a path to CSV.", call. = FALSE)
  }

  req <- c("benchmark_id", "prediction_file", "reference_file")
  issues <- character()

  missing_cols <- setdiff(req, names(manifest))
  if (length(missing_cols) > 0) {
    issues <- c(issues, paste0(
      "Missing required manifest columns: ",
      paste(missing_cols, collapse = ", ")
    ))
  }

  if (nrow(manifest) < 1) {
    issues <- c(issues, "Manifest has no rows.")
  }

  if ("benchmark_id" %in% names(manifest)) {
    ids <- as.character(manifest$benchmark_id)
    if (any(!nzchar(ids))) {
      issues <- c(issues, "benchmark_id contains empty values.")
    }
    if (anyDuplicated(ids)) {
      issues <- c(issues, "benchmark_id contains duplicates.")
    }
  }

  if (all(c("prediction_file", "reference_file") %in% names(manifest))) {
    for (i in seq_len(nrow(manifest))) {
      pred <- file.path(data_dir, manifest$prediction_file[i])
      ref <- file.path(data_dir, manifest$reference_file[i])

      if (!file.exists(pred)) {
        issues <- c(issues, sprintf("Row %d: prediction file not found: %s", i, pred))
      }
      if (!file.exists(ref)) {
        issues <- c(issues, sprintf("Row %d: reference file not found: %s", i, ref))
      }
      if (file.exists(pred) && !.benchmark_supported_file(pred)) {
        issues <- c(issues, sprintf(
          "Row %d: unsupported prediction file format: %s",
          i, pred
        ))
      }
      if (file.exists(ref) && !.benchmark_supported_file(ref)) {
        issues <- c(issues, sprintf(
          "Row %d: unsupported reference file format: %s",
          i, ref
        ))
      }
    }
  }

  out <- list(
    valid = length(issues) == 0,
    issues = issues,
    manifest = manifest
  )
  class(out) <- c("benchmark_manifest_validation", "list")
  out
}


#' Print benchmark manifest validation result
#'
#' @param x A `benchmark_manifest_validation` object.
#' @param ... Additional arguments (unused).
#'
#' @return Invisibly returns `x`.
#'
#' @references
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [validateBenchmarkManifest()] for performing manifest validation.
#'
#' @export
print.benchmark_manifest_validation <- function(x, ...) {
  cat("Benchmark Manifest Validation\n")
  cat("  Valid:", x$valid, "\n")
  cat("  Rows:", nrow(x$manifest), "\n")
  if (length(x$issues) > 0) {
    cat("  Issues:\n")
    for (msg in x$issues) {
      cat("   -", msg, "\n")
    }
  }
  invisible(x)
}


#' Compute agreement metrics against a reference signal table
#'
#' Computes per-variable metrics (RMSE, MAE, bias, correlation, R2, ICC,
#' Bland-Altman LoA width) between prediction and reference data.
#'
#' @param prediction Numeric vector/matrix/data.frame.
#' @param reference Numeric vector/matrix/data.frame.
#' @param trial_id Label used in output rows.
#' @param thresholds Optional named list from `defaultBenchmarkThresholds()`.
#' @param alignment Alignment mode when sample lengths differ:
#'   `"truncate"` or `"resample"`.
#'
#' @return Object of class `"benchmark_agreement"` with `metrics`, `summary`,
#'   and `thresholds`.
#'
#' @references
#' Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
#' Rater Reliability." Psychological Bulletin, 86(2), 420-428.
#'
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [defaultBenchmarkThresholds()] for threshold configuration,
#'   [runBenchmarkSuite()] for multi-trial benchmarking,
#'   [blandAltman()] for Bland-Altman agreement analysis.
#'
#' @export
#'
#' @examples
#' ref <- data.frame(a = sin(seq(0, 1, length.out = 100)))
#' pred <- ref + rnorm(100, sd = 0.01)
#' out <- benchmarkAgreement(pred, ref, trial_id = "demo")
#' out$summary
benchmarkAgreement <- function(prediction,
                               reference,
                               trial_id = "trial_1",
                               thresholds = defaultBenchmarkThresholds("balanced"),
                               alignment = c("truncate", "resample")) {

  alignment <- match.arg(alignment)
  .validate_benchmark_thresholds(thresholds)

  aligned <- .align_benchmark_inputs(prediction, reference, method = alignment)
  pred <- aligned$prediction
  ref <- aligned$reference

  vars <- colnames(pred)
  if (is.null(vars)) {
    vars <- paste0("var", seq_len(ncol(pred)))
    colnames(pred) <- vars
    colnames(ref) <- vars
  }

  metric_rows <- lapply(seq_len(ncol(pred)), function(j) {
    m <- .benchmark_metrics_vector(pred[, j], ref[, j])
    data.frame(
      trial_id = trial_id,
      variable = vars[j],
      n = m$n,
      rmse = m$rmse,
      mae = m$mae,
      bias = m$bias,
      cor = m$cor,
      r2 = m$r2,
      icc = m$icc,
      loa_width = m$loa_width,
      pass = .benchmark_pass_row(m, thresholds),
      stringsAsFactors = FALSE
    )
  })

  metrics <- do.call(rbind, metric_rows)
  rownames(metrics) <- NULL

  summary <- data.frame(
    trial_id = trial_id,
    n_variables = nrow(metrics),
    n_pass = sum(metrics$pass, na.rm = TRUE),
    pass_rate = mean(metrics$pass, na.rm = TRUE),
    mean_rmse = mean(metrics$rmse, na.rm = TRUE),
    mean_mae = mean(metrics$mae, na.rm = TRUE),
    mean_cor = mean(metrics$cor, na.rm = TRUE),
    mean_icc = mean(metrics$icc, na.rm = TRUE),
    overall_pass = all(metrics$pass),
    stringsAsFactors = FALSE
  )

  out <- list(
    metrics = metrics,
    summary = summary,
    thresholds = thresholds,
    alignment = alignment
  )
  class(out) <- c("benchmark_agreement", "list")
  out
}


#' Print benchmark agreement summary
#'
#' @param x A `benchmark_agreement` object.
#' @param ... Additional arguments (unused).
#'
#' @return Invisibly returns `x`.
#'
#' @references
#' Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
#' Rater Reliability." Psychological Bulletin, 86(2), 420-428.
#'
#' @seealso [benchmarkAgreement()] for computing agreement metrics.
#'
#' @export
print.benchmark_agreement <- function(x, ...) {
  s <- x$summary
  cat("Benchmark agreement\n")
  cat("  Trial:", s$trial_id, "\n")
  cat("  Variables:", s$n_variables, "\n")
  cat("  Pass rate:", sprintf("%.1f%%", 100 * s$pass_rate), "\n")
  cat("  Overall pass:", s$overall_pass, "\n")
  cat("  Mean RMSE:", signif(s$mean_rmse, 4), "\n")
  cat("  Mean Cor:", signif(s$mean_cor, 4), "\n")
  cat("  Mean ICC:", signif(s$mean_icc, 4), "\n")
  invisible(x)
}


#' Run a benchmark suite from a manifest
#'
#' Executes all benchmark rows in a manifest and returns aggregate summaries.
#'
#' @param manifest Manifest data.frame or manifest CSV path.
#'   `prediction_file`/`reference_file` can point to `.csv`, `.mot`, `.sto`,
#'   or `.trc` files.
#' @param data_dir Base directory for relative manifest file paths.
#' @param thresholds Named threshold list from `defaultBenchmarkThresholds()`.
#' @param alignment Alignment mode passed to `benchmarkAgreement()`.
#' @param report_dir Optional output directory. If supplied, summary and
#'   detailed CSV reports are written.
#'
#' @return Object of class `"benchmark_suite"` with `summary`, `metrics`,
#'   `manifest`, and `thresholds`.
#'
#' @references
#' Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
#' Rater Reliability." Psychological Bulletin, 86(2), 420-428.
#'
#' @seealso [benchmarkAgreement()] for single-trial agreement analysis,
#'   [createBenchmarkExample()] for generating example benchmark data,
#'   [print.benchmark_suite()] for displaying suite results.
#'
#' @export
#'
#' @examples
#' ex <- createBenchmarkExample(n_trials = 2, seed = 1)
#' suite <- runBenchmarkSuite(ex$manifest, data_dir = ex$data_dir)
#' suite$summary
runBenchmarkSuite <- function(manifest,
                              data_dir = ".",
                              thresholds = defaultBenchmarkThresholds("balanced"),
                              alignment = c("truncate", "resample"),
                              report_dir = NULL) {

  alignment <- match.arg(alignment)
  .validate_benchmark_thresholds(thresholds)

  validation <- validateBenchmarkManifest(manifest, data_dir = data_dir)
  if (!validation$valid) {
    stop(
      "Invalid benchmark manifest:\n",
      paste0("- ", validation$issues, collapse = "\n"),
      call. = FALSE
    )
  }

  man <- validation$manifest
  runs <- vector("list", nrow(man))

  for (i in seq_len(nrow(man))) {
    pred_path <- file.path(data_dir, man$prediction_file[i])
    ref_path <- file.path(data_dir, man$reference_file[i])

    pred <- .read_benchmark_input_table(pred_path, label = "prediction")
    ref <- .read_benchmark_input_table(ref_path, label = "reference")

    runs[[i]] <- benchmarkAgreement(
      prediction = pred,
      reference = ref,
      trial_id = as.character(man$benchmark_id[i]),
      thresholds = thresholds,
      alignment = alignment
    )
  }

  metrics <- do.call(rbind, lapply(runs, `[[`, "metrics"))
  summary <- do.call(rbind, lapply(runs, `[[`, "summary"))
  rownames(metrics) <- NULL
  rownames(summary) <- NULL

  suite_summary <- data.frame(
    n_trials = nrow(summary),
    n_variables = nrow(metrics),
    overall_pass_rate = mean(metrics$pass, na.rm = TRUE),
    trial_pass_rate = mean(summary$overall_pass),
    mean_rmse = mean(metrics$rmse, na.rm = TRUE),
    mean_mae = mean(metrics$mae, na.rm = TRUE),
    mean_cor = mean(metrics$cor, na.rm = TRUE),
    mean_icc = mean(metrics$icc, na.rm = TRUE),
    stringsAsFactors = FALSE
  )

  out <- list(
    summary = summary,
    metrics = metrics,
    suite_summary = suite_summary,
    manifest = man,
    thresholds = thresholds,
    alignment = alignment
  )
  class(out) <- c("benchmark_suite", "list")

  if (!is.null(report_dir)) {
    if (!dir.exists(report_dir)) {
      dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
    }
    utils::write.csv(summary, file.path(report_dir, "benchmark_summary.csv"),
                     row.names = FALSE)
    utils::write.csv(metrics, file.path(report_dir, "benchmark_metrics.csv"),
                     row.names = FALSE)
    utils::write.csv(suite_summary, file.path(report_dir, "benchmark_suite_summary.csv"),
                     row.names = FALSE)
  }

  out
}


#' Print benchmark suite summary
#'
#' @param x A `benchmark_suite` object.
#' @param ... Additional arguments (unused).
#'
#' @return Invisibly returns `x`.
#'
#' @references
#' Shrout PE, Fleiss JL (1979). "Intraclass Correlations: Uses in Assessing
#' Rater Reliability." Psychological Bulletin, 86(2), 420-428.
#'
#' @seealso [runBenchmarkSuite()] for running the benchmark suite.
#'
#' @export
print.benchmark_suite <- function(x, ...) {
  s <- x$suite_summary
  cat("Benchmark suite\n")
  cat("  Trials:", s$n_trials, "\n")
  cat("  Variables:", s$n_variables, "\n")
  cat("  Variable pass rate:", sprintf("%.1f%%", 100 * s$overall_pass_rate), "\n")
  cat("  Trial pass rate:", sprintf("%.1f%%", 100 * s$trial_pass_rate), "\n")
  cat("  Mean RMSE:", signif(s$mean_rmse, 4), "\n")
  cat("  Mean Cor:", signif(s$mean_cor, 4), "\n")
  cat("  Mean ICC:", signif(s$mean_icc, 4), "\n")
  invisible(x)
}


#' Create a synthetic benchmark dataset bundle
#'
#' Generates prediction/reference CSV pairs and a manifest for dry-run
#' validation benchmarking when external data are not yet available.
#'
#' @param output_dir Output directory where files are written.
#' @param n_trials Number of synthetic trials.
#' @param n_samples Samples per trial.
#' @param variables Character vector of variable names.
#' @param noise_sd Prediction noise SD relative to the generated reference.
#' @param seed Random seed.
#'
#' @return A list with `manifest`, `manifest_path`, and `data_dir`.
#'
#' @references
#' Bland JM, Altman DG (1986). "Statistical Methods for Assessing Agreement
#' Between Two Methods of Clinical Measurement." Lancet, 327(8476), 307-310.
#'
#' @seealso [runBenchmarkSuite()] for running the benchmark suite,
#'   [benchmarkManifestTemplate()] for creating empty manifest templates.
#'
#' @export
#'
#' @examples
#' ex <- createBenchmarkExample(n_trials = 2, seed = 1)
#' runBenchmarkSuite(ex$manifest, data_dir = ex$data_dir)
createBenchmarkExample <- function(output_dir = tempdir(),
                                   n_trials = 3L,
                                   n_samples = 300L,
                                   variables = c("hip_angle", "knee_angle", "ankle_angle"),
                                   noise_sd = 0.02,
                                   seed = 1) {
  stopifnot(is.character(output_dir), length(output_dir) == 1, nzchar(output_dir))
  stopifnot(is.numeric(n_trials), length(n_trials) == 1, n_trials >= 1)
  stopifnot(is.numeric(n_samples), length(n_samples) == 1, n_samples >= 20)
  stopifnot(is.character(variables), length(variables) >= 1)
  stopifnot(is.numeric(noise_sd), length(noise_sd) == 1, noise_sd >= 0)
  stopifnot(is.numeric(seed), length(seed) == 1)

  n_trials <- as.integer(n_trials)
  n_samples <- as.integer(n_samples)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  set.seed(seed)
  t <- seq(0, 1, length.out = n_samples)

  manifest <- benchmarkManifestTemplate(n_trials)
  manifest$modality <- "synthetic_mocap"
  manifest$units <- "arbitrary"
  manifest$sampling_rate <- 100

  for (i in seq_len(n_trials)) {
    ref <- sapply(seq_along(variables), function(j) {
      amp <- 1 + 0.2 * j
      phase <- (i - 1) * 0.1 + j * 0.2
      amp * sin(2 * pi * t + phase)
    })
    ref <- as.data.frame(ref, stringsAsFactors = FALSE)
    names(ref) <- variables

    pred <- ref + matrix(
      stats::rnorm(n_samples * length(variables), sd = noise_sd),
      nrow = n_samples, ncol = length(variables)
    )
    pred <- as.data.frame(pred, stringsAsFactors = FALSE)
    names(pred) <- variables

    pred_file <- paste0("prediction_", i, ".csv")
    ref_file <- paste0("reference_", i, ".csv")

    utils::write.csv(pred, file.path(output_dir, pred_file), row.names = FALSE)
    utils::write.csv(ref, file.path(output_dir, ref_file), row.names = FALSE)

    manifest$benchmark_id[i] <- paste0("synthetic_", i)
    manifest$prediction_file[i] <- pred_file
    manifest$reference_file[i] <- ref_file
    manifest$notes[i] <- "synthetic example"
  }

  manifest_path <- file.path(output_dir, "benchmark_manifest.csv")
  utils::write.csv(manifest, manifest_path, row.names = FALSE)

  list(
    manifest = manifest,
    manifest_path = manifest_path,
    data_dir = output_dir
  )
}


#' Coerce input to numeric matrix
#' @keywords internal
#' @noRd
.as_numeric_matrix <- function(x, label = "input") {
  if (is.vector(x) && is.numeric(x)) {
    x <- matrix(x, ncol = 1)
  } else if (is.data.frame(x) || is.matrix(x)) {
    x <- as.matrix(x)
  } else {
    stop(label, " must be numeric vector/matrix/data.frame.", call. = FALSE)
  }

  if (!is.numeric(x)) {
    stop(label, " must be numeric.", call. = FALSE)
  }
  x
}


#' Align prediction/reference tables
#' @keywords internal
#' @noRd
.align_benchmark_inputs <- function(prediction, reference, method = c("truncate", "resample")) {
  method <- match.arg(method)

  pred <- .as_numeric_matrix(prediction, "prediction")
  ref <- .as_numeric_matrix(reference, "reference")

  pred_names <- colnames(pred)
  ref_names <- colnames(ref)

  if (!is.null(pred_names) && !is.null(ref_names)) {
    common <- intersect(pred_names, ref_names)
    if (length(common) > 0) {
      pred <- pred[, common, drop = FALSE]
      ref <- ref[, common, drop = FALSE]
    }
  }

  if (ncol(pred) != ncol(ref)) {
    stop("prediction/reference must have matching columns or common names.",
         call. = FALSE)
  }

  if (is.null(colnames(pred))) {
    nm <- paste0("var", seq_len(ncol(pred)))
    colnames(pred) <- nm
    colnames(ref) <- nm
  }

  if (nrow(pred) == nrow(ref)) {
    return(list(prediction = pred, reference = ref))
  }

  if (method == "truncate") {
    n <- min(nrow(pred), nrow(ref))
    return(list(
      prediction = pred[seq_len(n), , drop = FALSE],
      reference = ref[seq_len(n), , drop = FALSE]
    ))
  }

  n <- max(nrow(pred), nrow(ref))
  pred_rs <- apply(pred, 2, function(v) .resample_vector(v, n))
  ref_rs <- apply(ref, 2, function(v) .resample_vector(v, n))

  pred_rs <- as.matrix(pred_rs)
  ref_rs <- as.matrix(ref_rs)
  colnames(pred_rs) <- colnames(pred)
  colnames(ref_rs) <- colnames(ref)

  list(prediction = pred_rs, reference = ref_rs)
}


#' Resample vector to target length
#' @keywords internal
#' @noRd
.resample_vector <- function(v, n_target) {
  v <- as.numeric(v)
  if (length(v) == n_target) {
    return(v)
  }
  if (length(v) < 2) {
    return(rep(v[1], n_target))
  }

  x <- seq_len(length(v))
  xout <- seq(1, length(v), length.out = n_target)
  stats::approx(x = x, y = v, xout = xout, method = "linear", rule = 2)$y
}


#' Per-variable benchmark metric set
#' @keywords internal
#' @noRd
.benchmark_metrics_vector <- function(pred, ref) {
  idx <- is.finite(pred) & is.finite(ref)
  n <- sum(idx)

  if (n < 2) {
    return(list(
      n = n,
      rmse = NA_real_,
      mae = NA_real_,
      bias = NA_real_,
      cor = NA_real_,
      r2 = NA_real_,
      icc = NA_real_,
      loa_width = NA_real_
    ))
  }

  pred <- pred[idx]
  ref <- ref[idx]
  diff <- pred - ref

  cor_val <- suppressWarnings(stats::cor(pred, ref))
  if (!is.finite(cor_val)) {
    cor_val <- NA_real_
  }

  r2 <- if (is.na(cor_val)) NA_real_ else cor_val^2

  icc_val <- tryCatch(
    {
      out <- icc(cbind(pred, ref), model = "twoway", type = "agreement",
                 unit = "single")
      as.numeric(out$icc)
    },
    error = function(e) NA_real_
  )

  loa_width <- tryCatch({
    ba <- blandAltman(pred, ref)
    as.numeric(ba$upper_loa - ba$lower_loa)
  }, error = function(e) NA_real_)

  list(
    n = n,
    rmse = sqrt(mean(diff^2)),
    mae = mean(abs(diff)),
    bias = mean(diff),
    cor = cor_val,
    r2 = r2,
    icc = icc_val,
    loa_width = loa_width
  )
}


#' Validate threshold list
#' @keywords internal
#' @noRd
.validate_benchmark_thresholds <- function(thresholds) {
  if (!is.list(thresholds)) {
    stop("thresholds must be a named list.", call. = FALSE)
  }

  need <- c("rmse_max", "mae_max", "bias_abs_max", "cor_min", "icc_min")
  miss <- setdiff(need, names(thresholds))
  if (length(miss) > 0) {
    stop("thresholds is missing: ", paste(miss, collapse = ", "), call. = FALSE)
  }

  for (nm in need) {
    val <- thresholds[[nm]]
    if (!is.numeric(val) || length(val) != 1 || !is.finite(val)) {
      stop("thresholds$", nm, " must be a finite numeric scalar.", call. = FALSE)
    }
  }
}


#' Apply pass/fail thresholds to one metric row
#' @keywords internal
#' @noRd
.benchmark_pass_row <- function(m, thresholds) {
  checks <- c(
    is.finite(m$rmse) && m$rmse <= thresholds$rmse_max,
    is.finite(m$mae) && m$mae <= thresholds$mae_max,
    is.finite(m$bias) && abs(m$bias) <= thresholds$bias_abs_max,
    is.finite(m$cor) && m$cor >= thresholds$cor_min,
    is.finite(m$icc) && m$icc >= thresholds$icc_min
  )
  all(checks)
}


#' Supported benchmark file extensions
#' @keywords internal
#' @noRd
.benchmark_supported_extensions <- function() {
  c("csv", "mot", "sto", "trc")
}


#' Check whether file extension is supported by benchmark loader
#' @keywords internal
#' @noRd
.benchmark_supported_file <- function(path) {
  ext <- tolower(tools::file_ext(path))
  nzchar(ext) && ext %in% .benchmark_supported_extensions()
}


#' Read benchmark input table (CSV or OpenSim output)
#' @keywords internal
#' @noRd
.read_benchmark_input_table <- function(path, label = "input") {
  ext <- tolower(tools::file_ext(path))

  if (ext == "csv") {
    return(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }

  if (ext %in% c("mot", "sto", "trc")) {
    pe <- switch(ext,
      mot = readMOT(path),
      sto = readSTO(path),
      trc = readTRC(path)
    )
    return(.benchmark_pe_to_table(pe))
  }

  stop(
    "Unsupported ", label, " file extension '.", ext, "'. ",
    "Supported: ", paste(.benchmark_supported_extensions(), collapse = ", "), ".",
    call. = FALSE
  )
}


#' Convert PhysioExperiment assays to a flat numeric table for benchmarking
#' @keywords internal
#' @noRd
.benchmark_pe_to_table <- function(pe) {
  assay_names <- SummarizedExperiment::assayNames(pe)
  if (length(assay_names) < 1) {
    stop("OpenSim input does not contain any assay data.", call. = FALSE)
  }

  use_prefix <- length(assay_names) > 1L
  out <- list()
  for (nm in assay_names) {
    mat <- .as_numeric_matrix(SummarizedExperiment::assay(pe, nm), label = nm)

    if (is.null(colnames(mat))) {
      colnames(mat) <- paste0("var", seq_len(ncol(mat)))
    }
    if (use_prefix) {
      colnames(mat) <- paste0(nm, "__", colnames(mat))
    }
    out[[length(out) + 1L]] <- as.data.frame(mat, stringsAsFactors = FALSE)
  }

  table <- do.call(cbind, out)
  rownames(table) <- NULL
  table
}
