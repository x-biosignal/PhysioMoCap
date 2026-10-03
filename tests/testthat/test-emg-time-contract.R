test_that("known origins map a ramp to the physical target clock", {
  # f(t)=2*t+3 measured at 4 Hz from time 10 through 12 seconds.
  x <- 2 * (10 + (0:8)/4) + 3
  actual <- alignEMGtoMoCap(x, 4, 3, 2, emg_start_time=10,
                           mocap_start_time=10.5, outside="error")
  expect_equal(as.numeric(actual), c(24,25,26), tolerance=1e-12)
  shifted <- alignEMGtoMoCap(x, 4, 3, 2, emg_start_time=110,
                            mocap_start_time=110.5, outside="error")
  expect_identical(actual, shifted)
})

test_that("support policy distinguishes unavailable data from endpoint filling", {
  x <- c(10,11,12)
  na <- alignEMGtoMoCap(x, 1, 5, 1, emg_start_time=1, outside="NA")
  expect_equal(as.numeric(na), c(NA,10,11,12,NA))
  expect_error(alignEMGtoMoCap(x,1,5,1,emg_start_time=1,outside="error"), "outside finite")
  expect_equal(as.numeric(alignEMGtoMoCap(x,1,5,1,emg_start_time=1)), c(10,10,11,12,12))
  expect_true(all(is.na(alignEMGtoMoCap(x,1,3,1,mocap_start_time=10,outside="NA"))))
  expect_error(alignEMGtoMoCap(x,1,3,1,mocap_start_time=10,outside="error"), "outside finite")
  # Compatibility: old default grids and endpoint extension.
  expect_equal(as.numeric(alignEMGtoMoCap(x,1,5,1)), c(10,11,12,12,12))
})

test_that("finite support is channel-specific and strict mode refuses empty support", {
  x <- cbind(a=c(0,1,2,3), b=c(NA,1,2,NA))
  z <- alignEMGtoMoCap(x,1,4,1,outside="NA")
  expect_equal(z,x)
  expect_error(alignEMGtoMoCap(x,1,4,1,outside="error"), "channel 2")
  expect_error(alignEMGtoMoCap(c(NA,1,NA),1,3,1,outside="error"), "Fewer than two")
  expect_true(all(is.na(alignEMGtoMoCap(c(NA,1,NA),1,3,1,outside="NA"))))
  # The contract does not claim to reject internal gaps.
  expect_equal(as.numeric(alignEMGtoMoCap(c(0,NA,2),1,3,1,outside="error")), 0:2)
})

test_that("invalid clock metadata is rejected before interpolation", {
  for (value in list(NA_real_,Inf,0,-1))
    expect_error(alignEMGtoMoCap(1:3,value,3,1), "finite positive")
  for (value in list(NA_real_,Inf,2.5))
    expect_error(alignEMGtoMoCap(1:3,1,value,1), "finite integer")
  expect_error(alignEMGtoMoCap(1:3,1,3,1,emg_start_time=Inf), "finite scalar")
  expect_error(alignEMGtoMoCap(1:3,1,3,1,mocap_start_time=NA_real_), "finite scalar")
  expect_error(alignEMGtoMoCap(1:3,1e-320,3,1), "Time grids")
})

test_that("integration propagates time origins and support policy through both paths", {
  mocap <- matrix(0,5,1)
  raw <- integrateEMGMoCap(mocap, 1:3, 1, 1, process=FALSE,
                          emg_start_time=11, mocap_start_time=10, outside="NA")
  expect_equal(raw$combined$time, 10:14)
  expect_equal(as.numeric(raw$emg_aligned), c(NA,1,2,3,NA))
  expect_equal(raw$combined$emg_V1, c(NA,1,2,3,NA))
  expect_error(integrateEMGMoCap(mocap,1:3,1,1,process=FALSE,
               emg_start_time=11,mocap_start_time=10,outside="error"), "outside finite")
  # Constant amplitude: RMS is 2 throughout supported interior, independent oracle.
  out <- integrateEMGMoCap(matrix(0,401,1), rep(2,4001),100,2000,NULL,TRUE,
          NULL,filter_method="moving_average",
          emg_start_time=11,mocap_start_time=10,outside="NA")
  expect_true(all(is.na(out$combined$emg_V1[c(1:100,302:401)])))
  expect_equal(out$combined$emg_V1[151:251], rep(2,101), tolerance=1e-12)
  expect_equal(out$combined$time[c(1,401)], c(10,14))
  expect_error(integrateEMGMoCap(matrix(0,401,1),rep(2,4001),100,2000,
          bandpass=NULL,filter_method="moving_average",
          emg_start_time=11,mocap_start_time=10,outside="error"), "outside finite")
})


test_that("roundoff at an endpoint is not mistaken for a missing interval", {
  z <- alignEMGtoMoCap(1:4,10,3,10,emg_start_time=.1,
                       mocap_start_time=.2,outside="error")
  expect_equal(as.numeric(z),2:4,tolerance=1e-12)
  expect_error(alignEMGtoMoCap(1:4,10,3,10,emg_start_time=.1,
                   mocap_start_time=.2+1e-8,outside="error"), "outside finite")
  expect_error(alignEMGtoMoCap(1:4,10,3,10,emg_start_time=1e20,
                   mocap_start_time=1e20,outside="error"), "numeric precision")
  expect_error(alignEMGtoMoCap(numeric(),10,3,10), "at least one")
})


test_that("processing cannot reintroduce unsupported raw endpoints in NA mode", {
  out <- integrateEMGMoCap(matrix(0,201,1), c(rep(NA_real_,100),rep(2,3901)),
           100,2000,bandpass=NULL,filter_method="moving_average",outside="NA")
  expect_true(all(is.na(out$combined$emg_V1[1:5])))
  expect_equal(out$combined$emg_V1[51:151],rep(2,101),tolerance=1e-12)
})
