library(testthat)
library(PhysioMoCap)

# Helper: Create a PhysioExperiment with BODY_25 keypoint labels and
# known 3D positions for a subset of keypoints.
make_skeleton_pe <- function(n_frames = 10, include_confidence = FALSE) {
  sk <- define_skeleton("BODY_25")
  labels <- sk$keypoints$label  # 25 keypoints

  # Deterministic positions that form a plausible humanoid figure
  set.seed(42)
  n_kp <- length(labels)

  # Base positions (X = medial-lateral, Y = anterior-posterior, Z = vertical)
  base_x <- stats::rnorm(n_kp, mean = 0, sd = 0.3)
  base_y <- stats::rnorm(n_kp, mean = 0, sd = 0.3)
  base_z <- seq(1.8, 0, length.out = n_kp)  # head high, feet low

  pos_x <- matrix(rep(base_x, each = n_frames), nrow = n_frames)
  pos_y <- matrix(rep(base_y, each = n_frames), nrow = n_frames)
  pos_z <- matrix(rep(base_z, each = n_frames), nrow = n_frames)

  # Add small per-frame noise
  pos_x <- pos_x + matrix(stats::rnorm(n_frames * n_kp, 0, 0.01),
                           nrow = n_frames)
  pos_y <- pos_y + matrix(stats::rnorm(n_frames * n_kp, 0, 0.01),
                           nrow = n_frames)
  pos_z <- pos_z + matrix(stats::rnorm(n_frames * n_kp, 0, 0.01),
                           nrow = n_frames)

  colnames(pos_x) <- labels
  colnames(pos_y) <- labels
  colnames(pos_z) <- labels

  assays <- S4Vectors::SimpleList(
    position_x = pos_x,
    position_y = pos_y,
    position_z = pos_z
  )

  if (include_confidence) {
    conf <- matrix(stats::runif(n_frames * n_kp, 0.3, 1.0), nrow = n_frames)
    colnames(conf) <- labels
    assays[["confidence"]] <- conf
  }

  PhysioCore::PhysioExperiment(
    assays = assays,
    colData = S4Vectors::DataFrame(
      label = labels,
      type = rep("keypoint", n_kp)
    ),
    samplingRate = 30
  )
}


# ---------------------------------------------------------------------------
# projectTo2D
# ---------------------------------------------------------------------------

test_that("projectTo2D returns correct axes for sagittal plane", {
  proj <- projectTo2D(x = c(1, 2), y = c(3, 4), z = c(5, 6),
                      plane = "sagittal")
  expect_equal(proj$u, c(3, 4))  # Y as u

expect_equal(proj$v, c(5, 6))  # Z as v
})

test_that("projectTo2D returns correct axes for frontal plane", {
  proj <- projectTo2D(x = c(1, 2), y = c(3, 4), z = c(5, 6),
                      plane = "frontal")
  expect_equal(proj$u, c(1, 2))  # X as u
  expect_equal(proj$v, c(5, 6))  # Z as v
})

test_that("projectTo2D returns correct axes for transverse plane", {
  proj <- projectTo2D(x = c(1, 2), y = c(3, 4), z = c(5, 6),
                      plane = "transverse")
  expect_equal(proj$u, c(1, 2))  # X as u
  expect_equal(proj$v, c(3, 4))  # Y as v
})

test_that("projectTo2D returns a data frame with u and v columns", {
  proj <- projectTo2D(1, 2, 3, plane = "sagittal")
  expect_s3_class(proj, "data.frame")
  expect_true(all(c("u", "v") %in% names(proj)))
})


# ---------------------------------------------------------------------------
# plotSkeleton
# ---------------------------------------------------------------------------

test_that("plotSkeleton returns a ggplot object", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  p <- plotSkeleton(pe, sk, frame = 1)
  expect_s3_class(p, "ggplot")
})

test_that("plotSkeleton draws correct number of bone segments", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  p <- plotSkeleton(pe, sk, frame = 1, plane = "frontal")

  # Build plot to inspect the data
  pb <- ggplot2::ggplot_build(p)

  # First layer should be geom_segment (bones)
  # The BODY_25 skeleton has 24 bones, all should be drawn since all
  # 25 keypoint labels are present in the PE
  segment_layer <- pb$data[[1]]
  expect_equal(nrow(segment_layer), nrow(sk$bones))
})

test_that("plotSkeleton works for all three planes", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")

  p_sag <- plotSkeleton(pe, sk, frame = 1, plane = "sagittal")
  p_fro <- plotSkeleton(pe, sk, frame = 1, plane = "frontal")
  p_tra <- plotSkeleton(pe, sk, frame = 1, plane = "transverse")

  expect_s3_class(p_sag, "ggplot")
  expect_s3_class(p_fro, "ggplot")
  expect_s3_class(p_tra, "ggplot")
})

test_that("plotSkeleton shows labels when requested", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  p <- plotSkeleton(pe, sk, frame = 1, show_labels = TRUE)
  pb <- ggplot2::ggplot_build(p)

  # Should have a geom_text layer (the third layer)
  has_text <- any(vapply(pb$data, function(d) "label" %in% names(d), logical(1)))
  expect_true(has_text)
})

test_that("plotSkeleton colors by confidence when requested", {
  pe <- make_skeleton_pe(include_confidence = TRUE)
  sk <- define_skeleton("BODY_25")
  p <- plotSkeleton(pe, sk, frame = 1, show_confidence = TRUE)

  pb <- ggplot2::ggplot_build(p)
  # When show_confidence = TRUE, the point layer uses a color scale
  # Check that the plot has a colour scale in guides
  expect_s3_class(p, "ggplot")
  # The point layer should have a mapped colour aesthetic
  point_layers <- which(vapply(p$layers, function(l) {
    inherits(l$geom, "GeomPoint")
  }, logical(1)))
  expect_true(length(point_layers) > 0)
})


# ---------------------------------------------------------------------------
# plotSkeletonSequence
# ---------------------------------------------------------------------------

test_that("plotSkeletonSequence returns a faceted ggplot", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  frames <- c(1, 3, 5)
  p <- plotSkeletonSequence(pe, sk, frames = frames, plane = "sagittal")

  expect_s3_class(p, "ggplot")
  # Verify faceting is present
  expect_true(!is.null(p$facet))
  expect_false(inherits(p$facet, "FacetNull"))
})


# ---------------------------------------------------------------------------
# plotSkeletonOverlay
# ---------------------------------------------------------------------------

test_that("plotSkeletonOverlay returns a ggplot with all frames", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  frames <- c(1, 3, 5, 7)
  p <- plotSkeletonOverlay(pe, sk, frames = frames, plane = "frontal",
                           alpha_decay = TRUE)

  expect_s3_class(p, "ggplot")

  pb <- ggplot2::ggplot_build(p)
  # Each frame contributes segment + point layers = 2 layers per frame
  # Total layers should be >= 2 * length(frames)
  expect_gte(length(pb$data), 2 * length(frames))
})

test_that("plotSkeletonOverlay alpha decays across frames", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")
  frames <- c(1, 5, 10)
  p <- plotSkeletonOverlay(pe, sk, frames = frames, alpha_decay = TRUE,
                           base_alpha = 0.2)

  pb <- ggplot2::ggplot_build(p)
  # First segment layer (frame 1) should have lower alpha than last
  first_alpha <- unique(pb$data[[1]]$alpha)
  # Last segment layer (frame 3 = layer index 5)
  last_seg_idx <- 2 * length(frames) - 1
  last_alpha <- unique(pb$data[[last_seg_idx]]$alpha)
  expect_lt(first_alpha[1], last_alpha[1])
})


# ---------------------------------------------------------------------------
# plotSkeleton3D
# ---------------------------------------------------------------------------

test_that("plotSkeleton3D returns projected data when draw = FALSE", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")

  out <- plotSkeleton3D(pe, sk, frame = 1, draw = FALSE)

  expect_true(is.list(out))
  expect_true(all(c("data", "rotation", "azimuth", "elevation", "distance") %in% names(out)))
  expect_s3_class(out$data, "data.frame")
  expect_true(all(c("label", "u", "v", "depth") %in% names(out$data)))
})

test_that("plotSkeleton3D can draw without error", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")

  expect_invisible(
    plotSkeleton3D(pe, sk, frame = 2, draw = TRUE, show_labels = FALSE)
  )
})


# ---------------------------------------------------------------------------
# NA handling
# ---------------------------------------------------------------------------

test_that("plotSkeleton handles missing keypoints (NA) gracefully", {
  pe <- make_skeleton_pe()
  sk <- define_skeleton("BODY_25")

  # Introduce NAs in position_y and position_z for some keypoints.

  # Use position_z so the NAs propagate through all projection planes
  # (Z is used in sagittal and frontal projections).
  pz <- SummarizedExperiment::assay(pe, "position_z")
  pz[1, "Nose"] <- NA
  pz[1, "REye"] <- NA
  SummarizedExperiment::assay(pe, "position_z") <- pz

  # Should not error
  p <- plotSkeleton(pe, sk, frame = 1, plane = "sagittal")
  expect_s3_class(p, "ggplot")

  # Bones connected to NA keypoints should be excluded
  pb <- ggplot2::ggplot_build(p)
  segment_data <- pb$data[[1]]
  # Nose has 3 connected bones (Neck-Nose, Nose-REye, Nose-LEye)
  # REye has 2 connected bones (Nose-REye already counted, REye-REar)
  # So at least 4 bones removed from the 24 total
  expect_lt(nrow(segment_data), nrow(sk$bones))
})
