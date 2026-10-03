cycle_fixture <- function() {
  stream <- function(fs) list(data=cbind(level=rep(c(2,4),each=fs),
                                        ramp=(0:(2*fs-1))/fs),
    sampling_rate=fs,start_time=10,participant_id="P1",trial_id="T1")
  list(streams=list(emg=stream(20),motion=stream(10)),
       cycles=data.frame(participant_id="P1",trial_id="T1",side="L",
          cycle_id=c("C1","C2"),start_time=10:11,end_time=11:12))
}

test_that("repeated cycles use native times and never duplicate the shared boundary", {
  f <- cycle_fixture(); z <- segmentMultimodalCycles(f$streams,f$cycles)
  expect_identical(z$cycles,f$cycles)
  expect_true(all(z$complete_cycles))
  expect_equal(z$status$n_samples,c(20,20,10,10))
  expect_equal(z$segments$emg[[1]]$sample_index,1:20)
  expect_equal(z$segments$emg[[2]]$sample_index,21:40)
  expect_equal(z$segments$motion[[2]]$sample_index,11:20)
  expect_equal(z$segments$motion[[2]]$time,11+(0:9)/10)
  expect_length(intersect(z$segments$emg[[1]]$sample_index,
                          z$segments$emg[[2]]$sample_index),0)
  y <- summarizeCycleFeatures(z,colMeans)
  expect_equal(y$blocks$emg[,"level"],c(2,4))
  expect_equal(unname(y$blocks$emg[,"ramp"]),c(.475,1.475),tolerance=1e-12)
  expect_equal(unname(y$blocks$motion[,"ramp"]),c(.45,1.45),tolerance=1e-12)
  expect_identical(y$keys$emg,y$keys$motion)
  expect_identical(y$observations,f$cycles)
  expect_length(y$excluded_cycles,0)
})

test_that("left/right labels and input ordering survive extraction and features", {
  f <- cycle_fixture()
  f$cycles$side <- c("R","L"); f$cycles$cycle_id <- "C1"
  f$cycles <- f$cycles[2:1,]
  z <- segmentMultimodalCycles(f$streams,f$cycles)
  y <- summarizeCycleFeatures(z,colMeans)
  expect_identical(y$keys$emg$side,c("L","R"))
  expect_equal(unname(y$blocks$emg[,"level"]),c(4,2))
  expect_identical(y$keys$emg$participant_id,c("P1","P1"))
})

test_that("incomplete modalities require explicit diagnostic and exclusion policies", {
  f <- cycle_fixture(); f$streams$motion$data <- f$streams$motion$data[1:15,]
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"out_of_range")
  z <- segmentMultimodalCycles(f$streams,f$cycles,incomplete="retain")
  expect_identical(z$complete_cycles,c(TRUE,FALSE))
  expect_null(z$segments$motion[[2]])
  expect_equal(nrow(z$segments$emg[[2]]$data),20)
  expect_equal(z$status$reason,c("ok","ok","ok","out_of_range"))
  expect_error(summarizeCycleFeatures(z,colMeans),"Incomplete cycles")
  y <- summarizeCycleFeatures(z,colMeans,incomplete="exclude")
  expect_equal(y$excluded_cycles,2L)
  expect_equal(vapply(y$blocks,nrow,integer(1)),c(emg=1L,motion=1L))
  expect_identical(y$status,z$status)
  expect_identical(y$keys$emg$cycle_id,"C1")
})

test_that("boundary failures and internal nonfinite samples have explicit reasons", {
  f <- cycle_fixture(); f$cycles$end_time[2] <- NA_real_
  z <- segmentMultimodalCycles(f$streams,f$cycles,"retain")
  expect_equal(z$status$reason,c("ok","missing_boundary","ok","missing_boundary"))
  f$cycles$end_time[2] <- 10
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"invalid_interval")
  f <- cycle_fixture(); f$streams$emg$data[4,1] <- NA
  z <- segmentMultimodalCycles(f$streams,f$cycles,"retain")
  expect_identical(z$complete_cycles,c(FALSE,TRUE))
  expect_equal(z$status$reason[1],"nonfinite_data")
  expect_null(z$segments$emg[[1]])
  f$cycles$end_time <- NA_real_
  expect_error(summarizeCycleFeatures(segmentMultimodalCycles(f$streams,f$cycles,"retain"),
              colMeans,incomplete="exclude"),"No complete")
})

test_that("duplicate keys and wrong recording identity fail before segmentation", {
  f <- cycle_fixture(); f$cycles$cycle_id <- "C1"
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"Duplicate")
  f <- cycle_fixture(); f$streams$motion$trial_id <- "T2"
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"same participant and trial")
  f <- cycle_fixture(); f$cycles$participant_id[2] <- "P2"
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"does not match")
  f <- cycle_fixture(); f$streams$emg$sampling_rate <- Inf
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"Invalid recording")
  f <- cycle_fixture(); f$streams$emg$start_time <- 1e20
  expect_error(segmentMultimodalCycles(f$streams,f$cycles),"not representable")
})

test_that("small intervals and decimal endpoints obey half-open semantics", {
  f <- cycle_fixture()
  for(nm in names(f$streams)) f$streams[[nm]]$start_time <- .1
  f$cycles$start_time <- c(.2,.201); f$cycles$end_time <- c(.4,.202)
  z <- segmentMultimodalCycles(f$streams,f$cycles,"retain")
  expect_equal(z$segments$motion[[1]]$sample_index,2:3)
  expect_equal(z$status$reason,c("ok","no_samples","ok","no_samples"))
})

test_that("feature schemas are validated and reconciled by name", {
  f <- cycle_fixture(); z <- segmentMultimodalCycles(f$streams,f$cycles)
  fun <- function(x) {v <- colMeans(x); if (v[1]>3) rev(v) else v}
  expect_equal(summarizeCycleFeatures(z,fun)$blocks,summarizeCycleFeatures(z,colMeans)$blocks)
  expect_error(summarizeCycleFeatures(z,function(x) unname(colMeans(x))),"uniquely named")
  expect_error(summarizeCycleFeatures(z,function(x)c(a=NA_real_)),"finite real")
  expect_error(summarizeCycleFeatures(z,function(x) if(mean(x[,1])>3)c(b=1) else c(a=1)),"names differ")
})


test_that("different modality feature functions retain the same observation keys", {
  f <- cycle_fixture(); z <- segmentMultimodalCycles(f$streams,f$cycles)
  y <- summarizeCycleFeatures(z,list(motion=colMeans,
               emg=function(x)c(rms=sqrt(mean(x[,"level"]^2)))))
  expect_equal(unname(y$blocks$emg[,"rms"]),c(2,4))
  expect_identical(colnames(y$blocks$motion),c("level","ramp"))
  expect_identical(y$keys$emg,y$keys$motion)
  expect_equal(y$cycle_rows,1:2)
  expect_error(summarizeCycleFeatures(z,list(other=colMeans,emg=colMeans)),"each modality")
})
