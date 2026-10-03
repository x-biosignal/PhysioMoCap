# Upper-limb ADL reach assessment (adlReachTask).

test_that("a single smooth reach is one movement unit with finite smoothness", {
  fs <- 100; tt <- seq(0, 1, 1 / fs)
  v <- 30 * (tt^2) * (1 - tt)^2                    # minimum-jerk bell
  r <- adlReachTask(v, fs, task = "drinking")
  expect_s3_class(r, "adl_reach_task")
  expect_equal(r$icf_code, "d560")                 # drinking
  expect_equal(r$movement_units, 1L)               # single transport
  expect_true(is.finite(r$sparc))
  expect_gt(r$movement_time, 0)
})

test_that("a fragmented reach has more submovements and worse smoothness", {
  fs <- 100
  bell <- function(n) { u <- seq(0, 1, length.out = n); 30 * u^2 * (1 - u)^2 }
  smooth <- bell(101)
  frag <- c(bell(40), bell(40), bell(40))          # three submovements
  rs <- adlReachTask(smooth, fs, task = "feeding")
  rf <- adlReachTask(frag, fs, task = "feeding")
  expect_equal(rs$icf_code, "d550")                # eating
  expect_gt(rf$movement_units, rs$movement_units)  # more fragmented
  expect_lt(rf$sparc, rs$sparc)                    # SPARC more negative = rougher
})

test_that("ADL task maps to the correct ICF code", {
  fs <- 100; v <- 30 * (seq(0, 1, 1 / fs)^2) * (1 - seq(0, 1, 1 / fs))^2
  expect_equal(adlReachTask(v, fs, "reaching")$icf_code, "d445")
  expect_equal(adlReachTask(v, fs, "dressing")$icf_code, "d540")
  expect_equal(adlReachTask(v, fs, "grooming")$icf_code, "d520")
})

test_that("adlReachTask validates sampling rate", {
  expect_error(adlReachTask(rnorm(50), -1), "positive number")
})
