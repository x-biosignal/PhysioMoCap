make_event_pe <- function(times = c(3.42000007629395, 4.48000001907349),
                          first = c(249, 0), rate = 100, nframes = 337) {
  PhysioCore::PhysioExperiment(list(position_x = matrix(0, nframes, 1)),
    samplingRate = rate,
    metadata = list(c3d_parameters = list(POINT = list(RATE = rate),
      TRIAL = list(ACTUAL_START_FIELD = first),
      EVENT = list(USED = length(times), TIMES = rbind(rep(0, length(times)), times),
        LABELS = rep("Foot Strike", length(times)), CONTEXTS = rep("Left", length(times))))))
}

test_that("event clock declaration is explicit and continuous times are preserved", {
  pe <- make_event_pe()
  expect_error(c3dEventTable(pe), "Declare event_time_reference")
  z <- c3dEventTable(pe, "trial")
  expect_equal(z$time, c(3.42000007629395, 4.48000001907349) - 2.48, tolerance = 1e-14)
  expect_equal(z$snap_residual_s, c(0, 0))
  expect_identical(z$event_index, 1:2)
  expect_true(all(z$in_recording))
  expect_equal(z$recording_origin, c(2.48, 2.48))
})

test_that("opt-in point quantization prevents the one-sample event boundary error", {
  pe <- make_event_pe()
  z <- c3dEventTable(pe, "trial", snap = "point")
  expect_equal(z$time, c(.94, 2), tolerance = 1e-14)
  expect_equal(z$raw_time - z$recording_origin - z$time, z$snap_residual_s, tolerance = 1e-14)
  expect_equal(z$raw_seconds, c(3.42000007629395, 4.48000001907349))
  expect_true(all(z$snap_residual_s > 0))
  expect_equal(round(z$time * 1000) + 1, c(941, 2001))
  expect_equal(ceiling(c3dEventTable(pe, "trial")$time * 1000) + 1, c(942, 2002))
  expect_error(c3dEventTable(make_event_pe(3.424), "trial", snap = "point"), "point grid")
  expect_equal(c3dEventTable(make_event_pe(3.424), "trial")$time, .944)
  expect_error(c3dEventTable(pe, "trial", snap = "point", tolerance = .005), "half a point")
})

test_that("minute rollover and unsigned frame words have analytic origins", {
  pe <- make_event_pe(c(.2, 59.9), first = c(5991, 0))
  md <- S4Vectors::metadata(pe); md$c3d_parameters$EVENT$TIMES[1, ] <- c(1, 0)
  S4Vectors::metadata(pe) <- md
  z <- c3dEventTable(pe, "trial", snap = "point")
  expect_equal(z$time, c(.3, 0), tolerance = 1e-12)
  expect_equal(z$raw_minutes, c(1, 0))
  expect_equal(z$event_index, 1:2) # original order retained
  pe <- make_event_pe(655.36, first = c(1, 1))
  expect_equal(c3dEventTable(pe, "trial")$recording_origin, 655.36)
  pe <- make_event_pe(655.34, first = c(-1, 0))
  expect_equal(c3dEventTable(pe, "trial")$first_frame, 65535)
  expect_equal(c3dEventTable(pe, "trial")$time, 0)
})

test_that("missing origin is rejected rather than silently zeroed", {
  pe <- make_event_pe(first = NULL)
  expect_error(c3dEventTable(pe, "trial"), "Supply first_frame")
  expect_equal(c3dEventTable(pe, "trial", first_frame = 249)$recording_origin, c(2.48, 2.48))
  local <- make_event_pe(c(.1, .2), first = NULL)
  expect_equal(c3dEventTable(local, "recording")$time, c(.1, .2))
  expect_error(c3dEventTable(local, "recording", first_frame = 249), "only to trial")
  expect_error(c3dEventTable(pe, "trial", first_frame = 0), "positive one-based")
  expect_error(c3dEventTable(pe, "trial", first_frame = 1.5), "positive one-based")
})

test_that("out-of-range events need an explicit retention policy", {
  pe <- make_event_pe(c(-.1, 0, 3.36, 3.37), first = c(1, 0))
  expect_error(c3dEventTable(pe, "recording"), "outside the stored")
  z <- c3dEventTable(pe, "recording", outside = "keep")
  expect_identical(z$in_recording, c(FALSE, TRUE, TRUE, FALSE))
})

test_that("malformed C3D contracts fail before conversion", {
  pe <- make_event_pe(); md <- S4Vectors::metadata(pe)
  md$c3d_parameters$POINT$RATE <- 200; S4Vectors::metadata(pe) <- md
  expect_error(c3dEventTable(pe, "trial"), "match samplingRate")
  for (bad in list(matrix(1, 2, 1), matrix(NA_real_, 2, 2), c(1, 2))) {
    pe <- make_event_pe(); md <- S4Vectors::metadata(pe)
    md$c3d_parameters$EVENT$TIMES <- bad; S4Vectors::metadata(pe) <- md
    expect_error(c3dEventTable(pe, "trial"), "2 by USED")
  }
  pe <- make_event_pe(); md <- S4Vectors::metadata(pe)
  md$c3d_parameters$EVENT$CONTEXTS <- "Left"; S4Vectors::metadata(pe) <- md
  expect_error(c3dEventTable(pe, "trial"), "labels and contexts")
  expect_error(c3dEventTable(make_event_pe(first = c(-32769, 0)), "trial"), "valid TRIAL")
  expect_error(c3dEventTable(make_event_pe(), "trial", tolerance = NA_real_), "tolerance")
})

test_that("files with no parameter events return a typed empty table", {
  pe <- make_event_pe(numeric(), first = NULL)
  z <- c3dEventTable(pe, "trial")
  expect_equal(nrow(z), 0)
  expect_type(z$time, "double"); expect_type(z$event_index, "integer")
  md <- S4Vectors::metadata(pe); md$c3d_parameters$EVENT <- NULL; S4Vectors::metadata(pe) <- md
  expect_identical(c3dEventTable(pe, "trial"), z)
})


test_that("exact final sample remains in range on nonzero trial clocks", {
  for (snap in c("none", "point")) {
    z <- c3dEventTable(make_event_pe(2.49, nframes = 2), "trial", snap = snap)
    expect_true(z$in_recording)
    expect_equal(z$time, .01, tolerance = 1e-14)
    z <- c3dEventTable(make_event_pe(3.37, nframes = 90), "trial", snap = snap)
    expect_true(z$in_recording)
    expect_equal(z$time, .89, tolerance = 1e-14)
  }
  expect_error(c3dEventTable(make_event_pe(2.490001, nframes = 2), "trial"), "outside")
  expect_error(c3dEventTable(make_event_pe(2.479999, nframes = 2), "trial"), "outside")
})

test_that("NULL or malformed clock declarations never infer a convention", {
  for (clock in list(NULL, NA_character_, c("trial", "recording"), 0, "tr"))
    expect_error(c3dEventTable(make_event_pe(), clock), "Declare event_time_reference")
})


test_that("outside keep cannot admit an unrepresentable clock", {
  expect_error(c3dEventTable(make_event_pe(1, rate = 1e-320), "trial", outside = "keep"), "clock is not finite")
})
