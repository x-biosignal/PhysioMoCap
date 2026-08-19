# OpenCap -> OpenSim (IK/ID/SO) -> downstream pipeline glue.
#
# The setup-writing and gating logic is exercised without a working OpenSim
# backend (dry_run); the actual tool execution is skip-gated on a backend.

test_that("runOpenSimFromMarkers writes an IK setup from the bundled template", {
  skip_if_not_installed("PhysioOpenSim")
  model <- tempfile(fileext = ".osim"); writeLines("<OpenSimDocument/>", model)
  trc   <- tempfile(fileext = ".trc");  writeLines("markers", trc)

  res <- runOpenSimFromMarkers(model, trc, tools = "ik", dry_run = TRUE)

  expect_s3_class(res, "opensim_run")
  expect_false(res$ran)
  expect_named(res$setups, "ik")
  expect_true(file.exists(res$setups$ik))
  ik_xml <- paste(readLines(res$setups$ik), collapse = "\n")
  expect_true(grepl(basename(model), ik_xml, fixed = TRUE))   # model substituted
  expect_true(grepl(basename(trc), ik_xml, fixed = TRUE))     # markers substituted
  expect_match(res$expected_outputs[["ik"]], "ik\\.mot$")
})

test_that("ID/SO require ground-reaction loads (markerless OpenCap has none)", {
  skip_if_not_installed("PhysioOpenSim")
  model <- tempfile(fileext = ".osim"); writeLines("<OpenSimDocument/>", model)
  trc   <- tempfile(fileext = ".trc");  writeLines("markers", trc)

  expect_error(
    runOpenSimFromMarkers(model, trc, tools = c("ik", "id"), dry_run = TRUE),
    "external_loads_file"
  )
  expect_error(
    runOpenSimFromMarkers(model, trc, tools = c("ik", "so"), dry_run = TRUE),
    "external_loads_file"
  )
})

test_that("ID/SO setups are written when loads are supplied (or GRF is waived)", {
  skip_if_not_installed("PhysioOpenSim")
  model <- tempfile(fileext = ".osim"); writeLines("<OpenSimDocument/>", model)
  trc   <- tempfile(fileext = ".trc");  writeLines("markers", trc)
  grf   <- tempfile(fileext = ".xml");  writeLines("<OpenSimDocument/>", grf)

  res <- runOpenSimFromMarkers(model, trc, tools = c("ik", "id", "so"),
                               external_loads_file = grf, dry_run = TRUE)
  expect_setequal(names(res$setups), c("ik", "id", "so"))
  id_xml <- paste(readLines(res$setups$id), collapse = "\n")
  expect_true(grepl("ik.mot", id_xml, fixed = TRUE))          # consumes IK motion
  expect_true(grepl(basename(grf), id_xml, fixed = TRUE))     # external loads wired

  # kinematics-only inverse dynamics (no GRF) only when explicitly waived
  res2 <- runOpenSimFromMarkers(model, trc, tools = c("ik", "id"),
                                require_external_loads = FALSE, dry_run = TRUE)
  expect_setequal(names(res2$setups), c("ik", "id"))
})

test_that("nonexistent model/marker files are rejected", {
  skip_if_not_installed("PhysioOpenSim")
  good <- tempfile(fileext = ".trc"); writeLines("x", good)
  expect_error(runOpenSimFromMarkers("no_such.osim", good, dry_run = TRUE), "model_file")
  model <- tempfile(fileext = ".osim"); writeLines("<OpenSimDocument/>", model)
  expect_error(runOpenSimFromMarkers(model, "no_such.trc", dry_run = TRUE), "trc_file")
})

test_that("default templates resolve to bundled PhysioOpenSim files", {
  skip_if_not_installed("PhysioOpenSim")
  tpl <- .opensim_default_templates()
  expect_setequal(names(tpl), c("ik", "id", "so"))
  expect_true(all(file.exists(unlist(tpl))))
  # a partial override replaces only that tool; the rest keep the bundled defaults
  merged <- .opensim_default_templates(list(ik = "my_ik.xml"))
  expect_identical(merged$ik, "my_ik.xml")
  expect_true(file.exists(merged$id) && file.exists(merged$so))
})

test_that(".trc_time_range reads the whole trial span from a TRC", {
  trc <- tempfile(fileext = ".trc")
  writeLines(c(
    "PathFileType\t4\t(X/Y/Z)\tsample.trc",
    "DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames",
    "100.0\t100.0\t3\t1\tmm\t100.0\t1\t3",
    "Frame#\tTime\tM1",
    "\t\tX1\tY1\tZ1",
    "1\t0.50\t1\t2\t3",
    "2\t0.51\t1\t2\t3",
    "3\t0.75\t1\t2\t3"
  ), trc)
  expect_equal(.trc_time_range(trc), c(0.50, 0.75))
  # a non-TRC file yields NULL (caller then leaves time_range unset)
  bogus <- tempfile(fileext = ".trc"); writeLines("not a trc", bogus)
  expect_null(.trc_time_range(bogus))
})

test_that(".opencap_model_url tolerates empty, NA, and non-scalar metadata", {
  base <- "https://app.opencap.ai/api"; sid <- "s1"
  # empty first key must not shadow a valid later key
  u1 <- .opencap_model_url(list(openSimModel = "", opensim_model = "https://x/m.osim"),
                           NULL, base, sid)
  expect_identical(u1, "https://x/m.osim")
  # NA / non-scalar values fall through to the constructed endpoint, not a crash
  u2 <- .opencap_model_url(list(openSimModel = NA_character_,
                                model = list(nested = TRUE)), NULL, base, sid)
  expect_match(u2, "sessions/s1/opensim_model$")
})

test_that("a real run without an OpenSim backend fails with a clear message", {
  skip_if_not_installed("PhysioOpenSim")
  if (.opensim_backend_available()) skip("An OpenSim backend is available")
  model <- tempfile(fileext = ".osim"); writeLines("<OpenSimDocument/>", model)
  trc   <- tempfile(fileext = ".trc");  writeLines("markers", trc)
  expect_error(
    runOpenSimFromMarkers(model, trc, tools = "ik", dry_run = FALSE),
    "OpenSim backend"
  )
})

test_that("downloadOpenCapModel validates inputs and needs an API key", {
  # missing key (and no env var) -> clear error, no network
  withr::local_envvar(OPENCAP_API_KEY = "")
  expect_error(downloadOpenCapModel("abcd1234-5678-90ab-cdef-1234567890ab"),
               "API key")
  expect_error(downloadOpenCapModel(""), "session_id")
  expect_error(downloadOpenCapModel("abcd1234", dest = 123), "dest")
})

test_that(".opencap_model_url prefers session metadata, else constructs a URL", {
  base <- "https://app.opencap.ai/api"; sid <- "sess-1"
  # explicit model URL in session metadata wins
  u1 <- .opencap_model_url(list(openSimModel = "https://x/model.osim"), NULL, base, sid)
  expect_identical(u1, "https://x/model.osim")
  # fall back to the trial results, then to a constructed endpoint
  u2 <- .opencap_model_url(list(), list(results = list(model = "https://y/m.osim")), base, sid)
  expect_identical(u2, "https://y/m.osim")
  u3 <- .opencap_model_url(list(), NULL, base, sid)
  expect_match(u3, "sessions/sess-1/opensim_model$")
})

test_that("runOpenSimFromOpenCap fails fast on missing GRF before any download", {
  # id/so requested, no loads -> must error before touching the network
  expect_error(
    runOpenSimFromOpenCap("abcd1234-5678-90ab-cdef-1234567890ab",
                          tools = c("ik", "id")),
    "external_loads_file"
  )
})

test_that("the full OpenCap->OpenSim run executes when a backend is present", {
  skip_if_not_installed("PhysioOpenSim")
  if (!.opensim_backend_available()) skip("No OpenSim backend (native or opensim-cmd)")
  skip("Requires a matching scaled model + marker fixture (gait); not bundled")
})
