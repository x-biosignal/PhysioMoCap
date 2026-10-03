cohort_cycle_fixture <- function() {
  pe <- function(fs, base) PhysioCore::PhysioExperiment(
    S4Vectors::SimpleList(raw = cbind(signal = base + (0:(2*fs-1))/fs)), samplingRate = fs)
  visit <- function(base) PhysioCore::MultiRatePhysioExperiment(
    emg = pe(20, base), motion = pe(10, base), t0 = 1000,
    offsets = c(emg = .25, motion = .25))
  person <- function(id, base) PhysioCore::PhysioLongitudinal(
    baseline = visit(base), followup = visit(base + 10),
    subject = S4Vectors::DataFrame(id = id),
    design = S4Vectors::DataFrame(session_id = c("baseline", "followup"),
      visit_label = c("followup", "baseline"), days_from_baseline = c(0, 10)))
  x <- PhysioCore::PhysioCohort(P1 = person("P1", 100), P2 = person("P2", 200),
                              group = c("A", "B"))
  c <- expand.grid(cycle_id = c("C1", "C2"), session_id = c("baseline", "followup"),
                   subject_id = c("P1", "P2"), stringsAsFactors = FALSE)
  c$trial_id <- "T1"; c$side <- "L"
  c$start_time <- rep(c(.25, 1.25), 4); c$end_time <- c$start_time + 1
  list(x = x, cycles = c)
}

test_that("cohort identities, exact session IDs and native clocks reach features", {
  f <- cohort_cycle_fixture()
  y <- summarizeCycleFeatures(segmentCohortCycles(f$x, f$cycles), colMeans)
  expect_identical(y$observations$participant_id, f$cycles$subject_id)
  expect_identical(y$keys$emg, f$cycles[c("subject_id","session_id","trial_id","side","cycle_id")])
  expect_identical(y$keys$emg, y$keys$motion)
  # Analytic arithmetic means of uniform native samples, not a software reference.
  base <- rep(c(100,110,200,210), each = 2) + rep(0:1,4)
  expect_equal(unname(y$blocks$emg[,1]), base + 19/40)
  expect_equal(unname(y$blocks$motion[,1]), base + 9/20)
  expect_equal(nrow(y$cohort_design), 4)
  expect_equal(length(y$recordings), 4)
  expect_identical(y$recordings[[1]]$context$session_id, "baseline")
  expect_equal(y$recordings[[1]]$clock$t0, 1000)
  expect_equal(y$recordings[[1]]$streams$emg$start_time, .25)
  expect_equal(y$cycle_rows, 1:8)
})

test_that("interleaved cohort rows and paired exclusions keep global row identity", {
  f <- cohort_cycle_fixture(); ord <- c(8,1,6,3,2,7,4,5)
  c <- f$cycles[ord,]; rownames(c) <- NULL
  c$end_time[3] <- NA_real_
  z <- segmentCohortCycles(f$x,c,incomplete="retain")
  y <- summarizeCycleFeatures(z,colMeans,incomplete="exclude")
  expect_equal(y$excluded_cycles,3L)
  expect_equal(y$cycle_rows,(1:8)[-3])
  expect_identical(y$observations$subject_id,c$subject_id[-3])
  expect_equal(unname(y$blocks$emg[,1]),
               (rep(c(100,110,200,210),each=2)+rep(0:1,4)+19/40)[ord][-3])
  expect_equal(z$status$cycle_row[!z$status$complete],c(3,3))
  expect_true(all(z$status$session_id[!z$status$complete]==c$session_id[3]))
  expect_null(z$segments$emg[[3]])
})

test_that("existing cohort subject subsets separate all descendant cycles", {
  f <- cohort_cycle_fixture()
  run <- function(id) summarizeCycleFeatures(segmentCohortCycles(f$x[id],
    f$cycles[f$cycles$subject_id==id,]),colMeans)
  train <- run("P1"); valid <- run("P2")
  expect_length(intersect(train$observations$subject_id,valid$observations$subject_id),0)
  expect_equal(nrow(train$blocks$emg),4)
  expect_setequal(train$observations$session_id,c("baseline","followup"))
  expect_equal(nrow(train$cohort_design),2)
  expect_error(segmentCohortCycles(f$x["P1"],f$cycles),"Unknown cohort")
})

test_that("cohort adapter rejects ambiguous or unknown identity", {
  f <- cohort_cycle_fixture()
  bad <- f$cycles; bad$participant_id <- "wrong"
  expect_error(segmentCohortCycles(f$x,bad),"participant_id")
  bad <- f$cycles; bad$session_id[1] <- "unknown"
  expect_error(segmentCohortCycles(f$x,bad),"Unknown session")
  expect_error(segmentCohortCycles(f$x,rbind(f$cycles,f$cycles[1,])),"Duplicate")
  bad <- f$cycles; bad$subject_id <- factor(bad$subject_id)
  expect_error(segmentCohortCycles(f$x,bad),"character")
  expect_error(segmentCohortCycles(f$x,f$cycles,assay="absent"),"Missing selected assay")
  expect_error(segmentCohortCycles(f$x,f$cycles,assay=NA_character_),"single nonempty")
})

test_that("clock and stream schema errors cannot silently substitute recordings", {
  f <- cohort_cycle_fixture()
  f$x@subjects[[2]]@sessions[[1]]@clock$offsets <- c(emg=.25)
  expect_error(segmentCohortCycles(f$x,f$cycles),"explicit finite clock offset")
  f <- cohort_cycle_fixture()
  names(f$x@subjects[[2]]@sessions[[1]]@streams) <- c("emg","force")
  expect_error(segmentCohortCycles(f$x,f$cycles),"Stream names differ")
  f <- cohort_cycle_fixture()
  f$x@subjects[[2]]@sessions[[1]] <- f$x@subjects[[1]]@sessions[[1]]@streams[[1]]
  expect_error(segmentCohortCycles(f$x,f$cycles),"MultiPhysioExperiment")
  f <- cohort_cycle_fixture()
  mr <- f$x@subjects[[2]]@sessions[[1]]
  mr@streams <- mr@streams[2:1]
  f$x@subjects[[2]]@sessions[[1]] <- mr
  y <- summarizeCycleFeatures(segmentCohortCycles(f$x,f$cycles),colMeans)
  expect_equal(unname(y$blocks$emg[5,1]),200+19/40)
})


test_that("incomplete errors identify the original cohort row and context", {
  f <- cohort_cycle_fixture(); f$cycles$end_time[7] <- NA_real_
  expect_error(segmentCohortCycles(f$x,f$cycles),
               "row 7 \\(P2/followup/T1\\) in emg: missing_boundary", fixed = FALSE)
})
