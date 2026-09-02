library(testthat)
library(PhysioMoCap)

# --- helpers ------------------------------------------------------------------

.lorenz_x <- function(n, dt = 0.01, transient = 500) {
  s <- 10; r <- 28; b <- 8 / 3
  N <- n + transient
  X <- matrix(0, N, 3)
  X[1, ] <- c(1, 1, 1)
  f <- function(v) c(s * (v[2] - v[1]),
                     v[1] * (r - v[3]) - v[2],
                     v[1] * v[2] - b * v[3])
  for (i in 2:N) {
    v <- X[i - 1, ]
    k1 <- f(v); k2 <- f(v + dt / 2 * k1)
    k3 <- f(v + dt / 2 * k2); k4 <- f(v + dt * k3)
    X[i, ] <- v + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
  }
  X[(transient + 1):N, 1]
}

# --- sample entropy ----------------------------------------------------------

test_that("sample entropy is near zero for a sine and high for white noise", {
  set.seed(1)
  sine <- sin(seq(0, 40 * pi, length.out = 1000))
  noise <- stats::rnorm(1000)
  se_sine <- sampleEntropy(sine)
  se_noise <- sampleEntropy(noise)
  expect_lt(se_sine, 0.5)                       # regular signal -> low
  expect_gt(se_noise, se_sine)
  # published white-noise SampEn (m = 2, r = 0.2*sd) is ~2.2
  expect_gt(se_noise, 1.9)
  expect_lt(se_noise, 2.5)
})

test_that("sampleEntropy honours m, r and normalize, and validates input", {
  set.seed(2)
  x <- stats::rnorm(500)
  expect_true(sampleEntropy(x, m = 3) > 0)
  # a larger tolerance finds more matches -> lower entropy
  expect_lt(sampleEntropy(x, r = 0.5), sampleEntropy(x, r = 0.1))
  expect_error(sampleEntropy(1:3), "length >= m")
  expect_error(sampleEntropy(rep(1, 100)), "constant series")
})

# --- largest Lyapunov exponent -----------------------------------------------

test_that("maxLyapunovExponent recovers the Lorenz exponent (~0.906)", {
  L <- .lorenz_x(2000)
  ly <- maxLyapunovExponent(L, sampling_rate = 100)
  expect_s3_class(ly, "lyapunov_exponent")
  expect_gt(ly$lambda, 0.5)
  expect_lt(ly$lambda, 1.4)
})

test_that("maxLyapunovExponent is near zero for a periodic signal", {
  sine <- sin(seq(0, 60 * pi, length.out = 3000))
  ly <- maxLyapunovExponent(sine, sampling_rate = 100)
  expect_lt(abs(ly$lambda), 0.2)
  # a chaotic signal is far more divergent than a periodic one
  expect_gt(maxLyapunovExponent(.lorenz_x(1500), sampling_rate = 100)$lambda,
            ly$lambda)
})

# --- harmonic ratio ----------------------------------------------------------

test_that("harmonic ratio is high for a clean (even-harmonic) stride signal", {
  t <- seq(0, 1, length.out = 201)[-201]
  clean <- cos(2 * 2 * pi * t)                  # step frequency = 2nd harmonic
  mixed <- clean + 0.8 * cos(2 * pi * t)        # add odd (asymmetric) content
  hr_clean <- harmonicRatio(clean, direction = "AP")
  hr_mixed <- harmonicRatio(mixed, direction = "AP")
  expect_s3_class(hr_clean, "harmonic_ratio")
  expect_gt(hr_clean$ratio, 40)
  expect_gt(hr_clean$ratio, hr_mixed$ratio)
})

test_that("harmonic ratio flips even/odd for the ML direction", {
  t <- seq(0, 1, length.out = 201)[-201]
  even <- cos(2 * 2 * pi * t)
  # AP uses even/odd (high for `even`); ML uses odd/even (low for `even`)
  expect_gt(harmonicRatio(even, direction = "AP")$ratio, 40)
  expect_lt(harmonicRatio(even, direction = "ML")$ratio, 0.1)
})

# --- time-delay embedding ----------------------------------------------------

test_that("timeDelayEmbed reconstructs a sine in two dimensions", {
  x <- sin(seq(0, 40 * pi, length.out = 1000))
  emb <- timeDelayEmbed(x)
  expect_s3_class(emb, "time_delay_embedding")
  expect_equal(emb$dim, 2)                      # a sine lives on a 2-D circle
  expect_gt(emb$delay, 0)
  expect_equal(ncol(emb$embedded), emb$dim)
})

test_that("timeDelayEmbed accepts explicit delay and dimension", {
  x <- sin(seq(0, 40 * pi, length.out = 500))
  emb <- timeDelayEmbed(x, delay = 5, dim = 3)
  expect_equal(emb$delay, 5)
  expect_equal(emb$dim, 3)
  expect_equal(nrow(emb$embedded), 500 - 2 * 5)
  expect_error(timeDelayEmbed(1:5), "length >= 10")
})

# --- local dynamic stability -------------------------------------------------

test_that("localDynamicStability returns short- and long-term divergence", {
  L <- .lorenz_x(2000)
  lds <- localDynamicStability(L, stride_samples = 70, sampling_rate = 100)
  expect_s3_class(lds, "local_dynamic_stability")
  expect_gt(lds$lambda_short, 0)                # unstable (chaotic) -> divergent
  expect_true(is.finite(lds$lambda_long))
  expect_error(localDynamicStability(L, stride_samples = 1), ">= 2")
})

# --- print methods -----------------------------------------------------------

test_that("print methods work", {
  x <- sin(seq(0, 40 * pi, length.out = 500))
  expect_output(print(timeDelayEmbed(x, delay = 5, dim = 3)),
                "time_delay_embedding")
  expect_output(print(maxLyapunovExponent(x, sampling_rate = 100)),
                "lyapunov_exponent")
  expect_output(print(harmonicRatio(cos(2 * 2 * pi * seq(0, 1, length.out = 100)))),
                "harmonic_ratio")
})

# --- regression tests for adversarial-review findings (WS4-12) ----------------

test_that("an oversized Theiler window errors instead of fabricating neighbours", {
  sine <- sin(seq(0, 40 * pi, length.out = 500))
  expect_error(
    maxLyapunovExponent(sine, sampling_rate = 100, mean_period = 1000),
    "Theiler window too large")
})

test_that("a short series with a large auto delay embeds instead of aborting", {
  set.seed(42)
  xs <- sin(seq(0, 5 * 2 * pi, length.out = 90)) + 0.1 * stats::rnorm(90)
  emb <- timeDelayEmbed(xs)
  expect_s3_class(emb, "time_delay_embedding")
  expect_gte(emb$dim, 1)
  expect_true(is.finite(maxLyapunovExponent(xs, sampling_rate = 100)$lambda))
})

test_that("sampleEntropy rejects a non-positive template length", {
  expect_error(sampleEntropy(stats::rnorm(100), m = 0), "positive integer")
})

test_that("a constant series gives a clear error, not a cryptic cut() failure", {
  expect_error(timeDelayEmbed(rep(1, 100)), "constant")
})

test_that("maxLyapunovExponent rejects a non-positive max_steps", {
  sine <- sin(seq(0, 40 * pi, length.out = 500))
  expect_error(maxLyapunovExponent(sine, sampling_rate = 100, max_steps = -5),
               "max_steps")
})
