utils::globalVariables(c("ba_mean", "ba_diff", "lwr", "upr"))

#' Bland-Altman agreement plot
#'
#' Draws the Bland-Altman difference-vs-mean scatter that
#' \code{\link[PhysioCore]{blandAltman}} only computes: the bias (mean
#' difference), the upper/lower limits of agreement (LoA), and shaded confidence
#' bands for the bias and each LoA. The numerics come from \code{blandAltman()}
#' so the plotted reference lines are single-sourced and cannot drift from the
#' computed statistics.
#'
#' @param x,y Numeric vectors of paired measurements (two methods, or two time
#'   points). Must be the same length with at least 2 pairs (validated by
#'   \code{blandAltman()}).
#' @param confidence Confidence level for the limits of agreement and the shaded
#'   confidence bands (default 0.95).
#' @param proportional_bias Logical. If \code{TRUE}, model the bias and LoA as
#'   linear in the mean (Bland-Altman regression): the bias line is the OLS fit
#'   of the difference on the mean with a shaded fitted-line confidence band, and
#'   the LoA are the fit \eqn{\pm z \cdot s_{resid}}. Use when the difference
#'   scales with magnitude. Requires at least 3 pairs (the regression residual
#'   variance is undefined at n = 2). Default \code{FALSE} (constant bias/LoA).
#' @param units Optional measurement unit appended to the axis labels.
#' @param colorblind Logical; if \code{TRUE} (default) use the ecosystem
#'   colorblind-safe palette (\code{\link[PhysioCore]{physioPalette}}).
#' @return A \code{ggplot} object.
#' @references Bland JM, Altman DG (1986). Statistical methods for assessing
#'   agreement between two methods of clinical measurement. \emph{Lancet},
#'   327(8476), 307-310. \doi{10.1016/S0140-6736(86)90837-8}
#' @seealso [PhysioCore::blandAltman()] for the underlying statistics.
#' @examples
#' \donttest{
#' set.seed(1)
#' m1 <- rnorm(30, 50, 10)
#' m2 <- m1 + rnorm(30, 0, 3)
#' plotBlandAltman(m1, m2)
#' plotBlandAltman(m1, m2, proportional_bias = TRUE, units = "deg")
#' }
#' @importFrom ggplot2 ggplot aes geom_point geom_hline geom_abline geom_line
#'   geom_ribbon annotate labs theme_minimal
#' @export
plotBlandAltman <- function(x, y, confidence = 0.95, proportional_bias = FALSE,
                            units = NULL, colorblind = TRUE) {
  ba <- blandAltman(x, y, confidence = confidence)  # validates x/y/confidence
  m <- (x + y) / 2
  d <- x - y
  n <- length(d)
  df <- data.frame(ba_mean = m, ba_diff = d)

  z <- stats::qnorm(1 - (1 - confidence) / 2)
  t_crit <- stats::qt(1 - (1 - confidence) / 2, df = n - 1)

  if (colorblind) {
    pal <- PhysioCore::physioPalette(8)
    bias_col <- pal[6L]   # Okabe-Ito blue
    loa_col <- pal[7L]    # Okabe-Ito vermilion
  } else {
    bias_col <- "blue"
    loa_col <- "red"
  }
  pt_col <- "grey30"

  p <- ggplot2::ggplot(df, ggplot2::aes(x = ba_mean, y = ba_diff)) +
    ggplot2::geom_point(color = pt_col, alpha = 0.8)

  if (!proportional_bias) {
    # CI of each LoA (Bland & Altman 1986/1999):
    #   var(LoA) = sd_diff^2 * (1/n + z^2 / (2(n-1)))
    se_loa <- ba$sd_diff * sqrt(1 / n + z^2 / (2 * (n - 1)))
    hw_loa <- t_crit * se_loa
    p <- p +
      ggplot2::annotate("rect", xmin = -Inf, xmax = Inf,
                        ymin = ba$ci_bias[1L], ymax = ba$ci_bias[2L],
                        fill = bias_col, alpha = 0.15) +
      ggplot2::annotate("rect", xmin = -Inf, xmax = Inf,
                        ymin = ba$lower_loa - hw_loa,
                        ymax = ba$lower_loa + hw_loa,
                        fill = loa_col, alpha = 0.12) +
      ggplot2::annotate("rect", xmin = -Inf, xmax = Inf,
                        ymin = ba$upper_loa - hw_loa,
                        ymax = ba$upper_loa + hw_loa,
                        fill = loa_col, alpha = 0.12) +
      ggplot2::geom_hline(yintercept = ba$bias, color = bias_col,
                          linewidth = 0.7) +
      ggplot2::geom_hline(yintercept = ba$lower_loa, color = loa_col,
                          linetype = "dashed") +
      ggplot2::geom_hline(yintercept = ba$upper_loa, color = loa_col,
                          linetype = "dashed")
  } else {
    if (n < 3L) {
      stop("proportional_bias = TRUE requires at least 3 pairs; the residual ",
           "variance of the difference-on-mean regression is undefined at ",
           "n = 2.", call. = FALSE)
    }
    fit <- stats::lm(ba_diff ~ ba_mean, data = df)
    co <- stats::coef(fit)
    sigma <- summary(fit)$sigma
    # the fitted-line (mean-response) CI uses the regression residual df (n-2),
    # not the constant-mode SD-of-differences df (n-1)
    t_reg <- stats::qt(1 - (1 - confidence) / 2, df = n - 2)
    grid <- data.frame(ba_mean = seq(min(m), max(m), length.out = 100L))
    pr <- stats::predict(fit, newdata = grid, se.fit = TRUE)
    grid$lwr <- pr$fit - t_reg * pr$se.fit
    grid$upr <- pr$fit + t_reg * pr$se.fit
    p <- p +
      ggplot2::geom_ribbon(data = grid,
                           ggplot2::aes(x = ba_mean, ymin = lwr, ymax = upr),
                           inherit.aes = FALSE, fill = bias_col, alpha = 0.15) +
      ggplot2::geom_abline(intercept = co[[1L]], slope = co[[2L]],
                           color = bias_col, linewidth = 0.7) +
      ggplot2::geom_abline(intercept = co[[1L]] + z * sigma, slope = co[[2L]],
                           color = loa_col, linetype = "dashed") +
      ggplot2::geom_abline(intercept = co[[1L]] - z * sigma, slope = co[[2L]],
                           color = loa_col, linetype = "dashed")
  }

  xlab <- "Mean of the two methods"
  ylab <- "Difference (x - y)"
  if (!is.null(units)) {
    xlab <- sprintf("%s (%s)", xlab, units)
    ylab <- sprintf("%s (%s)", ylab, units)
  }
  p + ggplot2::labs(x = xlab, y = ylab, title = "Bland-Altman agreement") +
    ggplot2::theme_minimal()
}
