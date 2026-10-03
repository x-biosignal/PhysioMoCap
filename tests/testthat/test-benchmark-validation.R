library(testthat)
library(PhysioMoCap)


test_that("defaultBenchmarkThresholds returns expected profiles", {
  t_bal <- defaultBenchmarkThresholds("balanced")
  t_str <- defaultBenchmarkThresholds("strict")
  t_len <- defaultBenchmarkThresholds("lenient")

  expect_true(is.list(t_bal))
  expect_true(all(c("rmse_max", "mae_max", "bias_abs_max", "cor_min", "icc_min") %in%
                    names(t_bal)))
  expect_lt(t_str$rmse_max, t_bal$rmse_max)
  expect_gt(t_len$rmse_max, t_bal$rmse_max)
})


test_that("benchmarkManifestTemplate and writeBenchmarkManifest work", {
  m <- benchmarkManifestTemplate(2)
  expect_s3_class(m, "data.frame")
  expect_equal(nrow(m), 2)
  expect_true(all(c("benchmark_id", "prediction_file", "reference_file") %in%
                    names(m)))

  tmp <- tempfile(fileext = ".csv")
  expect_invisible(writeBenchmarkManifest(tmp, n = 2))
  expect_true(file.exists(tmp))
})


test_that("validateBenchmarkManifest flags missing files", {
  m <- benchmarkManifestTemplate(1)
  m$prediction_file <- "does_not_exist_pred.csv"
  m$reference_file <- "does_not_exist_ref.csv"

  v <- validateBenchmarkManifest(m, data_dir = tempdir())
  expect_s3_class(v, "benchmark_manifest_validation")
  expect_false(v$valid)
  expect_true(length(v$issues) >= 1)
  expect_invisible(print(v))
})


test_that("benchmarkAgreement computes metrics and alignment", {
  set.seed(10)
  ref <- data.frame(
    hip = sin(seq(0, 1, length.out = 120)),
    knee = cos(seq(0, 1, length.out = 120))
  )
  pred <- ref + matrix(rnorm(240, sd = 0.01), nrow = 120, ncol = 2)

  out <- benchmarkAgreement(pred, ref, trial_id = "t1",
                            thresholds = defaultBenchmarkThresholds("lenient"))
  expect_s3_class(out, "benchmark_agreement")
  expect_s3_class(out$metrics, "data.frame")
  expect_equal(nrow(out$metrics), 2)
  expect_true(all(c("rmse", "mae", "cor", "icc", "pass") %in% names(out$metrics)))
  expect_true(out$summary$overall_pass)
  expect_invisible(print(out))

  # Different lengths should still work with resample alignment
  pred2 <- pred[1:90, , drop = FALSE]
  out2 <- benchmarkAgreement(pred2, ref, trial_id = "t2",
                             thresholds = defaultBenchmarkThresholds("lenient"),
                             alignment = "resample")
  expect_s3_class(out2, "benchmark_agreement")
  expect_equal(nrow(out2$metrics), 2)
})


test_that("createBenchmarkExample and runBenchmarkSuite execute end-to-end", {
  ex_dir <- tempfile(pattern = "benchmark_example_")
  ex <- createBenchmarkExample(
    output_dir = ex_dir,
    n_trials = 3,
    n_samples = 200,
    noise_sd = 0.01,
    seed = 1
  )

  expect_true(file.exists(ex$manifest_path))
  expect_s3_class(ex$manifest, "data.frame")
  expect_equal(nrow(ex$manifest), 3)

  suite <- runBenchmarkSuite(
    manifest = ex$manifest,
    data_dir = ex$data_dir,
    thresholds = defaultBenchmarkThresholds("lenient"),
    alignment = "truncate"
  )

  expect_s3_class(suite, "benchmark_suite")
  expect_s3_class(suite$summary, "data.frame")
  expect_s3_class(suite$metrics, "data.frame")
  expect_true(all(c("trial_id", "overall_pass") %in% names(suite$summary)))
  expect_true(all(c("trial_id", "variable", "pass") %in% names(suite$metrics)))
  expect_true(nrow(suite$summary) == 3)
  expect_true(nrow(suite$metrics) >= 3)
  expect_invisible(print(suite))

  report_dir <- tempfile(pattern = "benchmark_report_")
  suite2 <- runBenchmarkSuite(
    manifest = ex$manifest_path,
    data_dir = ex$data_dir,
    thresholds = defaultBenchmarkThresholds("lenient"),
    report_dir = report_dir
  )

  expect_s3_class(suite2, "benchmark_suite")
  expect_true(file.exists(file.path(report_dir, "benchmark_summary.csv")))
  expect_true(file.exists(file.path(report_dir, "benchmark_metrics.csv")))
  expect_true(file.exists(file.path(report_dir, "benchmark_suite_summary.csv")))
})


test_that("runBenchmarkSuite supports OpenSim reference outputs", {
  write_opensim_tabular <- function(path, data, format = c("mot", "sto")) {
    format <- match.arg(format)
    time <- seq(0, by = 0.01, length.out = nrow(data))
    header <- c(
      sprintf("name=%s_demo", format),
      sprintf("nRows=%d", nrow(data)),
      sprintf("nColumns=%d", ncol(data) + 1L),
      "endheader",
      paste(c("time", colnames(data)), collapse = "\t")
    )
    rows <- vapply(seq_len(nrow(data)), function(i) {
      paste(c(time[i], as.numeric(data[i, ])), collapse = "\t")
    }, character(1))
    writeLines(c(header, rows), path)
  }

  write_trc <- function(path, markers_xyz, data_rate = 100) {
    stopifnot(length(dim(markers_xyz)) == 3L, dim(markers_xyz)[3] == 3L)
    n_frames <- dim(markers_xyz)[1]
    markers <- dimnames(markers_xyz)[[2]]
    if (is.null(markers)) {
      markers <- paste0("M", seq_len(dim(markers_xyz)[2]))
      dimnames(markers_xyz)[[2]] <- markers
    }

    line1 <- "PathFileType\t4\t(X/Y/Z)\tbenchmark.trc"
    line2 <- paste(
      c("DataRate", "CameraRate", "NumFrames", "NumMarkers",
        "Units", "OrigDataRate", "OrigDataStartFrame", "OrigNumFrames"),
      collapse = "\t"
    )
    line3 <- paste(
      c(data_rate, data_rate, n_frames, length(markers), "m", data_rate, 1, n_frames),
      collapse = "\t"
    )

    marker_line <- c("Frame#", "Time")
    for (mk in markers) {
      marker_line <- c(marker_line, mk, "", "")
    }
    coord_line <- c("", "")
    for (i in seq_along(markers)) {
      coord_line <- c(coord_line, paste0("X", i), paste0("Y", i), paste0("Z", i))
    }

    t <- seq(0, by = 1 / data_rate, length.out = n_frames)
    data_lines <- vapply(seq_len(n_frames), function(i) {
      vals <- as.numeric(markers_xyz[i, , ])
      paste(c(i, t[i], vals), collapse = "\t")
    }, character(1))

    writeLines(c(
      line1, line2, line3,
      paste(marker_line, collapse = "\t"),
      paste(coord_line, collapse = "\t"),
      data_lines
    ), path)
  }

  td <- tempfile("benchmark_opensim_")
  dir.create(td, recursive = TRUE)

  set.seed(42)
  n <- 120
  t <- seq(0, 1, length.out = n)
  ref_tab <- data.frame(
    hip = sin(2 * pi * t),
    knee = cos(2 * pi * t),
    stringsAsFactors = FALSE
  )
  pred_tab <- ref_tab + matrix(rnorm(n * ncol(ref_tab), sd = 0.01), nrow = n)
  pred_tab <- as.data.frame(pred_tab, stringsAsFactors = FALSE)
  names(pred_tab) <- names(ref_tab)

  utils::write.csv(pred_tab, file.path(td, "prediction_csv.csv"), row.names = FALSE)
  utils::write.csv(ref_tab, file.path(td, "reference_csv.csv"), row.names = FALSE)
  write_opensim_tabular(file.path(td, "reference.mot"), ref_tab, format = "mot")
  write_opensim_tabular(file.path(td, "reference.sto"), ref_tab, format = "sto")

  marker_names <- c("RASI", "LASI")
  ref_xyz <- array(0, dim = c(n, length(marker_names), 3),
                   dimnames = list(NULL, marker_names, c("x", "y", "z")))
  ref_xyz[, 1, 1] <- sin(2 * pi * t)
  ref_xyz[, 1, 2] <- cos(2 * pi * t)
  ref_xyz[, 1, 3] <- 1 + 0.2 * sin(2 * pi * t)
  ref_xyz[, 2, 1] <- 0.9 * sin(2 * pi * t + 0.1)
  ref_xyz[, 2, 2] <- 0.9 * cos(2 * pi * t + 0.1)
  ref_xyz[, 2, 3] <- 1 + 0.2 * sin(2 * pi * t + 0.1)
  pred_xyz <- ref_xyz + array(rnorm(length(ref_xyz), sd = 0.003), dim = dim(ref_xyz))
  dimnames(pred_xyz) <- dimnames(ref_xyz)

  write_trc(file.path(td, "prediction.trc"), pred_xyz)
  write_trc(file.path(td, "reference.trc"), ref_xyz)

  man <- benchmarkManifestTemplate(3)
  man$benchmark_id <- c("mot_ref", "sto_ref", "trc_ref")
  man$prediction_file <- c("prediction_csv.csv", "prediction_csv.csv", "prediction.trc")
  man$reference_file <- c("reference.mot", "reference.sto", "reference.trc")

  suite <- runBenchmarkSuite(
    manifest = man,
    data_dir = td,
    thresholds = defaultBenchmarkThresholds("lenient")
  )

  expect_s3_class(suite, "benchmark_suite")
  expect_equal(nrow(suite$summary), 3)
  expect_true(all(suite$summary$overall_pass))
})


test_that("validateBenchmarkManifest reports unsupported file format", {
  td <- tempfile("benchmark_format_")
  dir.create(td, recursive = TRUE)
  pred <- file.path(td, "prediction.json")
  ref <- file.path(td, "reference.json")
  writeLines("{}", pred)
  writeLines("{}", ref)

  man <- benchmarkManifestTemplate(1)
  man$prediction_file <- basename(pred)
  man$reference_file <- basename(ref)

  v <- validateBenchmarkManifest(man, data_dir = td)
  expect_false(v$valid)
  expect_true(any(grepl("unsupported prediction file format", v$issues)))
  expect_true(any(grepl("unsupported reference file format", v$issues)))
})
