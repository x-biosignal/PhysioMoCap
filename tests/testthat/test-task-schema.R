library(testthat)
library(PhysioMoCap)

test_that("Event creates valid event object", {
  evt <- Event("hs", "Heel Strike", "threshold",
               list(signal = "vGRF", threshold = 10, direction = "rising"),
               typical_timing = 0)
  expect_s3_class(evt, "Event")
  expect_equal(evt$name, "hs")
  expect_equal(evt$detection_method, "threshold")
})

test_that("Phase creates valid phase object", {
  p <- Phase("stance", "Stance Phase", "hs1", "to", color = "#E8F4F8")
  expect_s3_class(p, "Phase")
  expect_equal(p$name, "stance")
})

test_that("TaskSchema creates valid schema", {
  schema <- TaskSchema(
    task_type = "test",
    task_label = "Test Task",
    events = list(
      Event("start", "Start", "manual", list(), typical_timing = 0),
      Event("end", "End", "manual", list(), typical_timing = 100)
    ),
    phases = list(
      Phase("main", "Main Phase", "start", "end")
    ),
    normalization = "cycle"
  )
  expect_s3_class(schema, "TaskSchema")
  expect_equal(length(getEventNames(schema)), 2)
  expect_equal(length(getPhaseNames(schema)), 1)
})

test_that("Pre-built schemas are valid", {
  expect_s3_class(schema_gait, "TaskSchema")
  expect_s3_class(schema_running, "TaskSchema")
  expect_s3_class(schema_jump, "TaskSchema")
  expect_s3_class(schema_balance, "TaskSchema")

  expect_true(length(getEventNames(schema_gait)) >= 4)
  expect_true(length(getPhaseNames(schema_gait)) >= 2)
})
