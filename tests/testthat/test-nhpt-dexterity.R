# Instrumented Nine-Hole-Peg dexterity (nhptDexterity).

bell <- function(n) { u <- seq(0, 1, length.out = n); 30 * u^2 * (1 - u)^2 }

test_that("nine evenly spaced transports are detected with low variability", {
  fs <- 100
  v <- unlist(replicate(9, c(bell(40), numeric(20)), simplify = FALSE))
  r <- nhptDexterity(v, fs)
  expect_s3_class(r, "nhpt_dexterity")
  expect_equal(r$icf_code, "d440")
  expect_equal(r$n_transports, 9L)
  expect_lt(r$cv_interval, 0.05)                       # evenly spaced
  expect_gt(r$transport_rate, 0)
})

test_that("irregular spacing raises the interval CV", {
  fs <- 100
  even <- unlist(lapply(rep(20, 8), function(g) c(bell(40), numeric(g))))
  gaps <- c(5, 60, 10, 80, 15, 40, 5, 70)
  irr <- unlist(Map(function(g) c(bell(40), numeric(g)), gaps))
  expect_gt(nhptDexterity(irr, fs)$cv_interval,
            nhptDexterity(even, fs)$cv_interval)
})

test_that("nhptDexterity validates sampling rate", {
  expect_error(nhptDexterity(rnorm(50), 0), "positive number")
})
