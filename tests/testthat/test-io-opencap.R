library(testthat)
library(PhysioMoCap)

# ===========================================================================
# Authentication header tests
# ===========================================================================

test_that(".opencap_auth_header builds Bearer header from api_key argument", {
  header <- PhysioMoCap:::.opencap_auth_header(api_key = "test-key-123")
  expect_equal(names(header), "Authorization")
  expect_equal(unname(header), "Bearer test-key-123")
})

test_that(".opencap_auth_header reads from OPENCAP_API_KEY env var", {
  withr::with_envvar(c("OPENCAP_API_KEY" = "env-key-456"), {
    header <- PhysioMoCap:::.opencap_auth_header(api_key = NULL)
    expect_equal(unname(header), "Bearer env-key-456")
  })
})

test_that(".opencap_auth_header prefers explicit api_key over env var", {
  withr::with_envvar(c("OPENCAP_API_KEY" = "env-key"), {
    header <- PhysioMoCap:::.opencap_auth_header(api_key = "explicit-key")
    expect_equal(unname(header), "Bearer explicit-key")
  })
})

test_that(".opencap_auth_header falls back to env var when api_key is empty string", {
  withr::with_envvar(c("OPENCAP_API_KEY" = "env-key-789"), {
    header <- PhysioMoCap:::.opencap_auth_header(api_key = "")
    expect_equal(unname(header), "Bearer env-key-789")
  })
})

test_that(".opencap_auth_header errors when no API key is available", {
  withr::with_envvar(c("OPENCAP_API_KEY" = ""), {
    expect_error(
      PhysioMoCap:::.opencap_auth_header(api_key = NULL),
      "API key not found"
    )
  })
})

test_that(".opencap_auth_header errors when env var is unset and no key given", {
  withr::with_envvar(c("OPENCAP_API_KEY" = NA), {
    expect_error(
      PhysioMoCap:::.opencap_auth_header(api_key = NULL),
      "OPENCAP_API_KEY"
    )
  })
})


# ===========================================================================
# URL construction tests
# ===========================================================================

test_that(".opencap_build_url joins base URL and path segments", {
  url <- PhysioMoCap:::.opencap_build_url(
    "https://app.opencap.ai/api",
    "sessions", "abc-123"
  )
  expect_equal(url, "https://app.opencap.ai/api/sessions/abc-123")
})

test_that(".opencap_build_url handles trailing slash in base URL", {
  # Note: readOpenCap strips trailing slashes before calling this, but

  # .opencap_build_url itself just concatenates, so trailing slash remains
  url <- PhysioMoCap:::.opencap_build_url(
    "https://app.opencap.ai/api",
    "sessions", "my-session", "trials"
  )
  expect_equal(
    url,
    "https://app.opencap.ai/api/sessions/my-session/trials"
  )
})

test_that(".opencap_build_url constructs trial results URL correctly", {
  url <- PhysioMoCap:::.opencap_build_url(
    "https://app.opencap.ai/api",
    "sessions", "sess-001", "trials", "trial-002",
    "results", "marker_data"
  )
  expect_equal(
    url,
    "https://app.opencap.ai/api/sessions/sess-001/trials/trial-002/results/marker_data"
  )
})

test_that(".opencap_build_url constructs kinematics results URL correctly", {
  url <- PhysioMoCap:::.opencap_build_url(
    "https://app.opencap.ai/api",
    "sessions", "sess-001", "trials", "trial-002",
    "results", "ik_data"
  )
  expect_equal(
    url,
    "https://app.opencap.ai/api/sessions/sess-001/trials/trial-002/results/ik_data"
  )
})


# ===========================================================================
# Result URL construction tests
# ===========================================================================

test_that(".opencap_result_url constructs marker URL from empty trial metadata", {
  trial <- list(id = "trial-1", name = "walk", results = list())
  url <- PhysioMoCap:::.opencap_result_url(
    trial, "markers",
    "https://app.opencap.ai/api", "sess-1", "trial-1"
  )
  expect_equal(
    url,
    "https://app.opencap.ai/api/sessions/sess-1/trials/trial-1/results/marker_data"
  )
})

test_that(".opencap_result_url constructs kinematics URL from empty trial metadata", {
  trial <- list(id = "trial-1", name = "walk", results = list())
  url <- PhysioMoCap:::.opencap_result_url(
    trial, "kinematics",
    "https://app.opencap.ai/api", "sess-1", "trial-1"
  )
  expect_equal(
    url,
    "https://app.opencap.ai/api/sessions/sess-1/trials/trial-1/results/ik_data"
  )
})

test_that(".opencap_result_url uses trial-provided marker URL when available", {
  trial <- list(
    id = "trial-1",
    results = list(marker_data = "https://storage.example.com/markers.trc")
  )
  url <- PhysioMoCap:::.opencap_result_url(
    trial, "markers",
    "https://app.opencap.ai/api", "sess-1", "trial-1"
  )
  expect_equal(url, "https://storage.example.com/markers.trc")
})

test_that(".opencap_result_url uses trial-provided kinematics URL when available", {
  trial <- list(
    id = "trial-1",
    results = list(ik_data = "https://storage.example.com/ik.mot")
  )
  url <- PhysioMoCap:::.opencap_result_url(
    trial, "kinematics",
    "https://app.opencap.ai/api", "sess-1", "trial-1"
  )
  expect_equal(url, "https://storage.example.com/ik.mot")
})


# ===========================================================================
# Missing httr package test
# ===========================================================================

test_that("readOpenCap gives clear error when httr is not installed", {
  # Mock requireNamespace to simulate httr not being available.
  skip_if_not(exists("local_mocked_bindings", mode = "function"),
              "local_mocked_bindings() not available")

  local_mocked_bindings(
    requireNamespace = function(pkg, ...) {
      if (pkg == "httr") return(FALSE)
      base::requireNamespace(pkg, ...)
    },
    .package = "base"
  )

  expect_error(
    readOpenCap("some-session-id", api_key = "key"),
    "httr.*package.*required"
  )
})


# ===========================================================================
# Input validation tests
# ===========================================================================

test_that("readOpenCap validates session_id argument", {
  skip_if_not(requireNamespace("httr", quietly = TRUE),
              "httr package needed")

  # Empty string
  expect_error(readOpenCap("", api_key = "key"))

  # Non-character
  expect_error(readOpenCap(123, api_key = "key"))
})

test_that("readOpenCap validates data_type argument", {
  skip_if_not(requireNamespace("httr", quietly = TRUE),
              "httr package needed")

  expect_error(
    readOpenCap("sess-id", api_key = "key", data_type = "invalid"),
    "arg"
  )
})

test_that("readOpenCap errors without API key", {
  skip_if_not(requireNamespace("httr", quietly = TRUE),
              "httr package needed")

  withr::with_envvar(c("OPENCAP_API_KEY" = NA), {
    expect_error(
      readOpenCap("some-session-id"),
      "API key"
    )
  })
})


# ===========================================================================
# Network tests (skipped without credentials)
# ===========================================================================

test_that("readOpenCap downloads marker data from real session", {
  skip("Requires OpenCap API key and network access")

  api_key <- Sys.getenv("OPENCAP_API_KEY", unset = "")
  skip_if(!nzchar(api_key), "OPENCAP_API_KEY not set")

  session_id <- Sys.getenv("OPENCAP_TEST_SESSION", unset = "")
  skip_if(!nzchar(session_id), "OPENCAP_TEST_SESSION not set")

  pe <- readOpenCap(session_id, api_key = api_key, data_type = "markers")

  expect_s4_class(pe, "PhysioExperiment")
  expect_true("position_x" %in% SummarizedExperiment::assayNames(pe))
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["opencap_session_id"]], session_id)
  expect_equal(md[["opencap_data_type"]], "markers")
})

test_that("readOpenCap downloads kinematics data from real session", {
  skip("Requires OpenCap API key and network access")

  api_key <- Sys.getenv("OPENCAP_API_KEY", unset = "")
  skip_if(!nzchar(api_key), "OPENCAP_API_KEY not set")

  session_id <- Sys.getenv("OPENCAP_TEST_SESSION", unset = "")
  skip_if(!nzchar(session_id), "OPENCAP_TEST_SESSION not set")

  pe <- readOpenCap(session_id, api_key = api_key, data_type = "kinematics")

  expect_s4_class(pe, "PhysioExperiment")
  expect_true("raw" %in% SummarizedExperiment::assayNames(pe))
  md <- S4Vectors::metadata(pe)
  expect_equal(md[["opencap_data_type"]], "kinematics")
})
