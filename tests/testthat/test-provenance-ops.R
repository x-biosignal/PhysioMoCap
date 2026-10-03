library(testthat)
library(PhysioMoCap)

# DMIO-03: every exported ops-* that returns a modified PhysioExperiment must
# record exactly one W3C PROV activity. make_mocap_markers() is from
# helper-mocap-data.R (position_x/y/z assays).

.run_plus1 <- function(pe, call_fn) {
  before <- nrow(provenance(pe))
  out <- call_fn(pe)
  expect_s4_class(out, "PhysioExperiment")
  expect_equal(nrow(provenance(out)) - before, 1L)
  out
}

test_that("every PE-returning MoCap ops appends exactly one provenance record", {
  .run_plus1(make_mocap_markers(200, 3, 120), function(p) computeVelocity(p))
  .run_plus1(make_mocap_markers(200, 3, 120), function(p) computeAcceleration(p))
  .run_plus1(make_mocap_markers(200, 3, 120), function(p) computeJerk(p))
  .run_plus1(computeVelocity(make_mocap_markers(200, 3, 120)),
             function(p) computeSpeed(p))
  .run_plus1(make_mocap_markers(200, 3, 120),
             function(p) filterSignals(p, cutoff = 6))
  .run_plus1(make_mocap_markers(200, 3, 120),
             function(p) resampleSignal(p, target_rate = 60))
})

test_that("freshly-constructed resampleSignal carries the input provenance forward", {
  pe <- computeVelocity(make_mocap_markers(200, 3, 120))   # 1 record
  out <- resampleSignal(pe, target_rate = 60)              # fresh object, carries -> 2
  prov <- provenance(out)
  expect_equal(nrow(prov), 2L)
  expect_equal(prov$activity, c("computeVelocity", "resampleSignal"))
  expect_equal(unique(prov$version),
               as.character(utils::packageVersion("PhysioMoCap")))
})

test_that("the recorded activity name matches the ops function", {
  pe <- filterSignals(make_mocap_markers(200, 3, 120), cutoff = 6)
  prov <- provenance(pe)
  expect_equal(prov$activity[1], "filterSignals")
  expect_match(prov$params_json[1], "cutoff")
})
