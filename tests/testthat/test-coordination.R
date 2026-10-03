# Inter-joint coordination: CRP, vector coding, coordination variability,
# verified on synthetic signals with known coordination.

test_that("CRP is ~0 for in-phase and ~constant for a 90-degree offset", {
  t <- seq(0, 2 * pi, length.out = 201)
  # identical signals -> in-phase -> CRP ~ 0, MARP ~ 0
  cin <- continuousRelativePhase(sin(t), sin(t))
  expect_s3_class(cin, "crp_result")
  expect_lt(cin$marp, 1)
  expect_lt(max(abs(cin$crp)), 2)
  # sin vs cos (90 deg phase-shifted) -> CRP ~ constant 90 deg
  coff <- continuousRelativePhase(sin(t), cos(t))
  mid <- coff$crp[50:150]                              # ignore endpoint effects
  expect_equal(median(abs(mid)), 90, tolerance = 5)
  expect_lt(sd(mid), 5)                                # roughly constant
})

test_that("vector coding classifies the canonical coordination patterns", {
  t <- seq(0, 2 * pi, length.out = 201); s <- sin(t)
  # angle2 == angle1 : 45 deg coupling -> all in-phase
  expect_equal(unname(vectorCoding(s, s)$proportions["in_phase"]), 1)
  # angle2 == -angle1 : anti-phase
  expect_equal(unname(vectorCoding(s, -s)$proportions["anti_phase"]), 1)
  # angle2 constant : only angle1 moves -> proximal-phase dominant
  vc <- vectorCoding(s, rep(0, length(s)))
  expect_equal(unname(vc$proportions["proximal"]), 1)
  # angle1 constant : only angle2 moves -> distal-phase dominant
  vc2 <- vectorCoding(rep(0, length(s)), s)
  expect_equal(unname(vc2$proportions["distal"]), 1)
})

test_that("coordination variability is zero for identical cycles and rises with jitter", {
  t <- seq(0, 2 * pi, length.out = 60)
  base <- sin(t)
  same <- matrix(base, nrow = 6, ncol = length(t), byrow = TRUE)
  expect_equal(coordinationVariability(same, same, "crp")$mean_variability, 0,
               tolerance = 1e-8)
  expect_equal(coordinationVariability(same, same, "vector_coding")$mean_variability,
               0, tolerance = 1e-6)

  set.seed(1)
  # sin (joint 1) vs cos (joint 2); joint 2 gets low vs high cycle-to-cycle noise
  jit1    <- t(replicate(8, base   + rnorm(length(t), 0, 0.02)))
  cos_low <- t(replicate(8, cos(t) + rnorm(length(t), 0, 0.02)))
  cos_hi  <- t(replicate(8, cos(t) + rnorm(length(t), 0, 0.25)))
  v_low <- coordinationVariability(jit1, cos_low, "crp")$mean_variability
  v_hi  <- coordinationVariability(jit1, cos_hi,  "crp")$mean_variability
  expect_gt(v_hi, v_low)                               # more jitter -> more variable
  expect_gt(v_low, 0)
})

test_that("coordination functions validate their inputs", {
  expect_error(continuousRelativePhase(1:5, 1:6), "equal-length")
  expect_error(vectorCoding(1:2, 1:3), "equal-length")
  expect_error(coordinationVariability(matrix(1, 1, 5), matrix(1, 1, 5)),
               ">= 2 rows")
})
