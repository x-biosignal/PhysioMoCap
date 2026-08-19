#!/usr/bin/env Rscript
# Golden-fixture generator for PhysioMoCap (WSF-08).
#
# Captures INDEPENDENT reference values for the movement-quality smoothness
# kernels in R/quality-smoothness.R:
#   - sparc()            Spectral Arc Length (Balasubramanian et al. 2015)
#   - dimensionlessJerk() / ldlj()   jerk-based smoothness
#
# Every reference here is computed WITHOUT calling the package function:
#   * SPARC  -> the published Balasubramanian "smoothness" algorithm, reimplemented
#               inline (both frequency bounds adaptive, per the authors' reference
#               Python `sparc()`), evaluated on fixed synthetic speed profiles.
#   * DLJ    -> the CLOSED-FORM continuous dimensionless jerk from the analytic
#               definition (integral of squared jerk), computed by hand for two
#               profiles with known analytic values.
#
# Run from the repo root, e.g.:
#   _R_CHECK_FORCE_SUGGESTS_=false Rscript -e '
#     devtools::load_all("physio-ecosystem/PhysioCore", quiet = TRUE);
#     devtools::load_all("physio-ecosystem/PhysioMoCap", quiet = TRUE);
#     source("physio-ecosystem/PhysioMoCap/data-raw/golden.R")'
#
# Deterministic: all inputs are analytic (fixed seed set for good measure); rerunning
# reproduces byte-identical _golden/*.rds.

set.seed(20260711)

## --- locate helper + golden dir (independent of testthat's test_path) -------
pkg_dir <- local({
  # data-raw/golden.R lives at <pkg>/data-raw/golden.R
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg) == 1 && nzchar(file_arg)) {
    return(normalizePath(dirname(dirname(file_arg))))
  }
  # sourced interactively: fall back to the known monorepo path
  cand <- file.path("physio-ecosystem", "PhysioMoCap")
  if (dir.exists(cand)) return(normalizePath(cand))
  normalizePath(".")
})
golden_dir <- file.path(pkg_dir, "tests", "testthat", "_golden")
source(file.path(pkg_dir, "tests", "testthat", "helper-golden.R"))

## ---------------------------------------------------------------------------
## Deterministic input builders (SHARED with the test file; keep in sync).
## ---------------------------------------------------------------------------

# Minimum-jerk speed profile on tau in [0,1]: v = 30 tau^2 - 60 tau^3 + 30 tau^4.
mj_speed <- function(n) {
  tau <- seq(0, 1, length.out = n)
  30 * tau^2 - 60 * tau^3 + 30 * tau^4
}

# Mid-band (Gabor-like) speed profile: dominant energy away from DC so the SPARC
# adaptive LOWER bound is exercised (not just the upper cutoff).
midband_speed <- function(n) {
  tau <- seq(0, 1, length.out = n)
  sin(2 * pi * 4 * tau) * exp(-((tau - 0.5)^2) / 0.02)
}

# Quadratic speed profile v(t) = a t^2 on t in [0, (n-1)/fs].
quad_speed <- function(n, fs, a = 3.0) {
  t <- seq(0, (n - 1) / fs, length.out = n)
  a * t^2
}

## ---------------------------------------------------------------------------
## INDEPENDENT reference: published SPARC (Balasubramanian et al. 2015).
## Reimplemented from the authors' reference `sparc()` (github smoothness pkg):
##   nfft = 2^(ceil(log2(N)) + padlevel)
##   Mf   = |FFT(zero-padded)| / max ; f = arange(0, fs, fs/nfft)  (length nfft)
##   keep f <= fc ; adaptive window = indices [first, last] with Mf >= amp_th
##   SAL  = -sum sqrt((diff(f)/(f[last]-f[first]))^2 + diff(Mf)^2)
## This is algebraically identical to the package's half-spectrum form (same df
## spacing fs/nfft, same Mf on [0,fc]); any mismatch would surface a bug.
## ---------------------------------------------------------------------------
sparc_ref <- function(movement, fs, padlevel = 4, fc = 10.0, amp_th = 0.05) {
  movement <- as.numeric(movement)
  N <- length(movement)
  nfft <- 2^(ceiling(log2(N)) + padlevel)
  Mf <- abs(fft(c(movement, rep(0, nfft - N))))
  Mf <- Mf / max(Mf)
  f <- seq(0, by = fs / nfft, length.out = nfft)      # arange(0, fs, fs/nfft)
  keep <- which(f <= fc)
  f_sel <- f[keep]
  Mf_sel <- Mf[keep]
  above <- which(Mf_sel >= amp_th)
  rng <- above[1]:above[length(above)]                # both bounds adaptive
  f_sel <- f_sel[rng]
  Mf_sel <- Mf_sel[rng]
  -sum(sqrt((diff(f_sel) / (f_sel[length(f_sel)] - f_sel[1]))^2 + diff(Mf_sel)^2))
}

## ---------------------------------------------------------------------------
## Capture goldens.
## ---------------------------------------------------------------------------

# 1) SPARC on the minimum-jerk profile. Exact algorithmic reference.
n_mj <- 200L
fs_mj <- 200
ref_sparc_mj <- sparc_ref(mj_speed(n_mj), fs = fs_mj)
write_golden(
  ref_sparc_mj, "sparc_minjerk",
  source = paste0(
    "Balasubramanian et al. (2015) J NeuroEng Rehabil 12:112 spectral-arc-length; ",
    "reference algorithm reimplemented inline (authors' `sparc`, both bounds adaptive) ",
    "on 30 tau^2 - 60 tau^3 + 30 tau^4, n=200, fs=200. Algebraically exact vs package."),
  tol = 1e-8, dir = golden_dir
)

# 2) SPARC on a mid-band profile (exercises the adaptive LOWER bound).
n_mb <- 200L
fs_mb <- 200
ref_sparc_mb <- sparc_ref(midband_speed(n_mb), fs = fs_mb)
write_golden(
  ref_sparc_mb, "sparc_midband",
  source = paste0(
    "Balasubramanian et al. (2015) spectral-arc-length reference algorithm ",
    "reimplemented inline on a Gabor speed profile sin(2 pi 4 tau) exp(-(tau-0.5)^2/0.02), ",
    "n=200, fs=200; exercises the adaptive lower frequency bound. Exact vs package."),
  tol = 1e-8, dir = golden_dir
)

# 3) Dimensionless jerk on a QUADRATIC speed profile.
#    Analytic continuous value: for v(t)=a t^2, v''=2a (const), so
#    DLJ = (T^3/v_peak^2) INT_0^T (2a)^2 dt = 4 a^2 T^4 / (a^2 T^4) = 4  (exact, any a,T).
#    The package uses forward finite differences + rectangle-rule integration,
#    giving 4*(n-2)/(n-1); at n=20001 this is 3.9998 -> converges to the analytic 4.
#    Golden = the INDEPENDENT analytic value 4; tol covers the O(1/n) FD error.
ref_dlj_quad <- 4.0
write_golden(
  ref_dlj_quad, "dlj_quadratic",
  source = paste0(
    "Analytic continuous dimensionless jerk for a quadratic speed profile v(t)=a t^2: ",
    "v''=2a => DLJ = (T^3/v_peak^2) INT (2a)^2 dt = 4 exactly (independent of a,T). ",
    "Package uses forward-difference jerk + rectangle-rule integral => 4*(n-2)/(n-1); ",
    "tol=1e-3 covers the O(1/n) finite-difference/quadrature convergence (n=20001, err 5e-5)."),
  tol = 1e-3, dir = golden_dir
)

# 4) LDLJ on the minimum-jerk profile.
#    Analytic continuous DLJ for v = 30 tau^2 - 60 tau^3 + 30 tau^4 (tau=t/T):
#    d2v/dt2 = (1/T^2)(60 - 360 tau + 360 tau^2);
#    INT_0^T (d2v/dt2)^2 dt = (1/T^3) INT_0^1 (60-360u+360u^2)^2 du = 720/T^3;
#    v_peak = v(0.5) = 1.875;  DLJ = (T^3/1.875^2)(720/T^3) = 720/1.875^2 = 204.8 (exact).
#    LDLJ = -log(204.8). Package FD value at n=20001 = -log(204.7488) -> converges.
ref_ldlj_mj <- -log(720 / 1.875^2)   # = -log(204.8)
write_golden(
  ref_ldlj_mj, "ldlj_minjerk",
  source = paste0(
    "Analytic continuous LDLJ for the minimum-jerk speed profile ",
    "30 tau^2 - 60 tau^3 + 30 tau^4: DLJ = INT_0^1 (60-360u+360u^2)^2 du / v_peak^2 ",
    "= 720/1.875^2 = 204.8 exactly; LDLJ = -log(204.8). Package uses forward-difference ",
    "jerk + rectangle integral; tol=1e-3 covers the O(1/n) convergence (n=20001, err 2.5e-4)."),
  tol = 1e-3, dir = golden_dir
)

cat("Wrote goldens to", golden_dir, "\n")
cat(sprintf("  sparc_minjerk = %.10f\n", ref_sparc_mj))
cat(sprintf("  sparc_midband = %.10f\n", ref_sparc_mb))
cat(sprintf("  dlj_quadratic = %.10f\n", ref_dlj_quad))
cat(sprintf("  ldlj_minjerk  = %.10f\n", ref_ldlj_mj))
