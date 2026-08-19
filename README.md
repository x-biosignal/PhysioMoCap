# PhysioMoCap <img src="man/figures/logo.png" align="right" height="139" alt="PhysioMoCap logo" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/x-biosignal/PhysioMoCap/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/x-biosignal/PhysioMoCap/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/PhysioMoCap)](https://CRAN.R-project.org/package=PhysioMoCap)
[![r-universe](https://x-biosignal.r-universe.dev/badges/PhysioMoCap)](https://x-biosignal.r-universe.dev/PhysioMoCap)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

**Motion Capture and Biomechanics Analysis for PhysioExperiment Objects**

PhysioMoCap provides a comprehensive motion capture, pose estimation, and biomechanical analysis toolkit built on the `PhysioExperiment` data model. With 177 exported functions -- the largest package in the PhysioExperiment ecosystem -- it covers the full analysis pipeline from file I/O through kinematics, kinetics, gait analysis, movement variability, EMG integration, and clinical statistics. PhysioMoCap supports optical motion capture (C3D, Venus3D), markerless pose estimation (OpenPose, DeepLabCut, MediaPipe, OpenCap), skeletal animation formats (BVH, ASF/AMC), OpenSim musculoskeletal modeling, and standardized datasets (GaitRec).

## Installation

You can install PhysioMoCap from [r-universe](https://x-biosignal.r-universe.dev):

```r
install.packages("PhysioMoCap",
  repos = c("https://x-biosignal.r-universe.dev", "https://cloud.r-project.org"))
```

Or install the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("x-biosignal/PhysioMoCap")
```

## Quick Start

```r
library(PhysioMoCap)

# Read a C3D motion capture file
pe <- readC3D("walking_trial.c3d")

# Inspect the data
pe
samplingRate(pe)    # e.g., 120 Hz
channelNames(pe)   # marker names

# Detect gait events (heel strikes, toe offs)
events <- detectEvents(pe, schema = schema_gait())

# Segment into gait cycles
phases <- segmentPhases(pe, events, schema = schema_gait())

# Compute gait parameters (speed, cadence, step length, symmetry)
gait <- calculateGaitParameters(pe, events)
gait

# Visualize the gait cycle
plotGaitCycle(pe, events, channels = c("L_Ankle_y", "R_Ankle_y"))
```

## Features

### File I/O

Read data from all major motion capture, pose estimation, and biomechanics formats through a unified interface:

**Optical motion capture:**
- `readC3D()` -- C3D binary format (marker positions, analog data, force plates)
- `readVenus3D()` -- Venus3D optical tracking system
- `readMoCapCSV()` -- generic CSV with configurable column mapping

**Markerless pose estimation:**
- `readOpenPose()` -- OpenPose JSON keypoint output
- `readDeepLabCut()` -- DeepLabCut HDF5/CSV pose estimation
- `readMediaPipe()` -- MediaPipe holistic/pose landmarks
- `readOpenCap()` -- OpenCap cloud-based markerless capture

**Skeletal animation:**
- `readBVH()` -- BioVision Hierarchy motion files
- `readASF()` / `readAMC()` -- Acclaim skeleton and motion data

**OpenSim musculoskeletal modeling:**
- `readTRC()` -- marker coordinate files
- `readMOT()` -- motion/force data files
- `readSTO()` -- storage files (IK, ID, muscle analysis results)
- `readOpenSimOutputs()` -- batch read all OpenSim tool outputs

**Standardized datasets:**
- `readGaitRec()` -- GaitRec clinical gait database

**Auto-detection:**
- `readMoCapAuto()` -- automatically detect format and call the appropriate reader

### Skeleton and Kinematics

Define skeletal models and compute joint-level kinematics:

- `define_skeleton()` / `SkeletonModel()` -- create custom skeletal topology with segment definitions
- `get_bone_connections()`, `get_limb_pairs()`, `get_segment_lengths()` -- query skeleton structure
- `calculateJointAngles()` -- 3D joint angles from marker positions
- `vectorAngle()` -- angle between arbitrary 3D vectors
- `estimateOrientation()` -- orientation estimation from IMU or marker data
- `quaternionToEuler()` / `eulerToQuaternion()` -- rotation representation conversion
- `calibrateIMU()` -- IMU sensor calibration

### Gap Handling

Detect and fill missing marker data in optical tracking recordings:

- `detectGaps()` -- identify gaps (missing frames) per marker
- `fillGaps()` -- gap filling with configurable method
- `fillGapsLinear()` -- linear interpolation for short gaps
- `fillGapsSpline()` -- cubic spline interpolation for longer gaps
- `reportGaps()` -- summary statistics of gap distribution

### Marker Tracking

Automated marker labeling and swap correction for optical systems:

- `trackMarkers()` -- frame-to-frame marker assignment using the Hungarian algorithm
- `detectSwaps()` -- identify marker label swaps between frames
- `correctSwaps()` -- automatically correct detected label swaps

### Signal Processing

General-purpose signal processing adapted for motion data:

- `filterSignals()` -- apply filters to PhysioExperiment assay data
- `butterworthFilter()` -- Butterworth IIR filter (low/high/bandpass)
- `savgolFilter()` -- Savitzky-Golay smoothing filter
- `differentiate()` -- numerical differentiation (central differences)
- `computeVelocity()` / `computeAcceleration()` / `computeJerk()` / `computeSpeed()` -- kinematic derivatives
- `resampleSignal()` / `resampleVector()` -- change sampling rate via interpolation
- `movingAverage()` -- moving average smoothing

### Biomechanics

Center of mass, segment inertia, and gravity compensation:

- `calculateCOM()` -- whole-body center of mass from segment model
- `calculateSegmentCOM()` -- segment-level center of mass
- `estimateSegmentInertia()` -- inertial parameters from anthropometric tables
- `segmentParameters()` -- segment mass, length, and COM location
- `removeGravity()` -- subtract gravitational component from accelerometer data

### Phase and Event Analysis

Event detection and movement phase segmentation with pre-built task schemas:

- `detectEvents()` -- automatic event detection from kinematic signals
- `manualEvents()` -- define events from known timestamps
- `Event()` / `Phase()` -- event and phase constructors
- `getEvent()` / `getEventNames()` -- query detected events
- `segmentPhases()` -- segment continuous data into movement phases
- `extractPhase()` -- extract data within a specific phase
- `getPhase()` / `getPhaseNames()` / `getPhaseData()` / `getPhaseColors()` -- phase accessors
- `hasValidPhases()` -- validate phase segmentation
- `phaseTiming()` / `phaseDurations()` / `phaseRatios()` -- temporal characteristics of phases

**Pre-built task schemas:**
- `TaskSchema()` / `validateSchema()` / `getSchema()` / `listSchemas()` -- schema management
- `schema_gait()` -- walking (heel strike, toe off, stance, swing)
- `schema_running()` -- running (flight phase, contact phase)
- `schema_jump()` -- vertical/horizontal jump (takeoff, flight, landing)
- `schema_cycling()` -- pedaling (top dead center, power phase, recovery)
- `schema_balance()` -- postural balance (quiet stance, perturbation, recovery)
- `schema_cutting()` -- cutting maneuvers (approach, plant, push-off)
- `schema_throw()` -- throwing (wind-up, acceleration, release, follow-through)

### Movement Analysis

Variability, similarity, and dimensionality reduction for movement waveforms:

- `normalizeMovement()` -- time-normalize waveforms to percentage of cycle
- `normalizedTimeAxis()` -- generate normalized time vector
- `dtwDistance()` -- dynamic time warping distance between waveforms
- `dtwDistanceMatrix()` -- pairwise DTW distance matrix
- `dtwWarp()` -- compute optimal warping path
- `dtwAverage()` -- DTW barycenter averaging
- `dtwClustering()` -- hierarchical clustering of movement patterns
- `waveformPCA()` -- principal component analysis of waveform ensembles
- `extractWaveformFeatures()` -- extract amplitude, timing, and shape features
- `waveformUMAP()` -- UMAP dimensionality reduction for movement patterns
- `waveformTSNE()` -- t-SNE dimensionality reduction
- `combineTrials()` -- combine multiple trials into an ensemble
- `batchNormalize()` -- batch normalization across trials

### Gait Analysis

Spatiotemporal gait parameters and symmetry assessment:

- `calculateGaitParameters()` -- cadence, stride length, walking speed, stance/swing ratio
- `summarizeGaitParameters()` -- aggregate parameters across multiple cycles
- `calculateStepSymmetry()` -- step length and timing symmetry
- `symmetryIndex()` -- Robinson symmetry index and related metrics

### Force Plate Kinetics

Ground reaction force analysis and contact detection:

- `analyzeForcePlate()` / `analyzeForcePlatePE()` -- comprehensive force plate analysis
- `detectForcePlateContacts()` -- threshold-based contact detection
- `filterGRF()` -- low-pass filter for ground reaction force data
- `calculateCOP()` -- center of pressure calculation
- `computeLoadingRate()` -- vertical GRF loading rate
- `computeImpulse()` -- impulse (time integral of GRF)

### Inverse Dynamics

Joint moment and power estimation from kinematics and kinetics:

- `inverseDynamics2D()` -- planar (sagittal plane) inverse dynamics
- `inverseDynamics3D()` -- full 3D inverse dynamics
- `computeJointPower()` -- joint power from moment and angular velocity

### EMG Integration

Electromyography processing and synchronization with motion data:

- `normalizeEMG()` -- amplitude normalization (MVC, peak, mean)
- `rectifyEMG()` -- full-wave rectification
- `computeRMSEnvelope()` -- root mean square envelope
- `processEMG()` -- combined rectification + envelope pipeline
- `alignEMGtoMoCap()` -- temporal alignment of EMG to motion capture data
- `integrateEMGMoCap()` -- unified EMG-MoCap analysis
- `synchronizeSignals()` -- general-purpose signal synchronization

### Clinical Statistics

Reliability and agreement metrics commonly used in rehabilitation research:

- `icc()` -- intraclass correlation coefficient (ICC) for inter-rater/test-retest reliability
- `sem()` -- standard error of measurement
- `mdc()` -- minimal detectable change
- `blandAltman()` -- Bland-Altman limits of agreement analysis
- `cohensD()` -- Cohen's d effect size
- `etaSquared()` -- eta-squared effect size for ANOVA designs

### OpenSim Integration

Interface for OpenSim musculoskeletal simulation workflows:

- `create_schema_from_opensim()` -- derive task schemas from OpenSim motion files
- `batch_analyze_opensim()` -- batch processing of OpenSim results
- `run_opensim_toolchain()` -- run OpenSim tools (IK, ID, SO, RRA, CMC) from R

### Visualization

Biomechanics-specific plotting functions:

- `plotSkeleton()` / `plotSkeleton3D()` -- 2D and 3D stick figure visualization
- `plotSkeletonOverlay()` / `plotSkeletonSequence()` -- multi-frame skeleton display
- `plotTrajectory()` -- marker trajectory over time
- `plotCycle()` / `plotGaitCycle()` -- ensemble-averaged cycle plots with variability bands
- `plotMultiPanel()` -- multi-channel panel plots (kinematics, kinetics, EMG)
- `plotSpaghetti()` -- overlaid individual trials (spaghetti plot)
- `plotPhasePortrait()` -- phase plane plots (position vs. velocity)
- `plotPhaseDurations()` -- phase timing bar charts
- `plotSymmetry()` -- symmetry radar/bar plots
- `plotDTW()` -- DTW alignment visualization
- `plotFPCA()` -- functional PCA component plots
- `plotPCAScatter()` / `plotPCAVariance()` -- PCA results visualization
- `plotUMAP()` -- UMAP embedding scatter plots
- `plotWaveformComparison()` -- side-by-side waveform comparison
- `plotGroupComparison()` -- group-level statistical comparison plots
- `plotCorrelationMatrix()` -- correlation heatmaps
- `plotEffectSizeForest()` -- forest plots for effect sizes

### Benchmarking and Validation

Tools for validating analysis pipelines against reference data:

- `createBenchmarkExample()` -- generate synthetic benchmark datasets
- `runBenchmarkSuite()` -- run full benchmark pipeline
- `benchmarkAgreement()` -- compute agreement metrics against gold standard
- `benchmarkManifestTemplate()` / `writeBenchmarkManifest()` / `validateBenchmarkManifest()` -- manage benchmark data manifests
- `defaultBenchmarkThresholds()` -- standard thresholds for biomechanics validation

### Onboarding

Helpers for new users to explore the package without external data:

- `quickStartMoCap()` -- generate a complete worked example with simulated data
- `assessMoCapReadiness()` -- check data readiness for downstream analysis
- `demoMoCapData()` -- create demonstration PhysioExperiment objects

## Use Cases

| Application | Key Functions |
|-------------|---------------|
| Clinical gait analysis | `readC3D()`, `detectEvents()`, `calculateGaitParameters()`, `plotGaitCycle()` |
| Markerless pose tracking | `readOpenPose()`, `readDeepLabCut()`, `readMediaPipe()` |
| Running biomechanics | `schema_running()`, `analyzeForcePlate()`, `computeLoadingRate()` |
| Movement variability | `dtwDistance()`, `dtwClustering()`, `waveformPCA()`, `fPCA()` |
| Musculoskeletal modeling | `readTRC()`, `run_opensim_toolchain()`, `inverseDynamics3D()` |
| Rehabilitation assessment | `icc()`, `sem()`, `mdc()`, `blandAltman()`, `symmetryIndex()` |
| EMG-MoCap integration | `normalizeEMG()`, `alignEMGtoMoCap()`, `plotMultiPanel()` |
| Balance/postural control | `schema_balance()`, `calculateCOP()`, `plotTrajectory()` |

## Dependencies

- **R** (>= 4.2)
- **PhysioCore** -- core data structures and accessors
- **ggplot2** -- visualization
- **jsonlite** -- JSON parsing (OpenPose, MediaPipe)
- **SummarizedExperiment**, **S4Vectors** -- Bioconductor infrastructure
- **stats**, **utils**, **rlang**, **scales** -- base R and tidyverse utilities

Optional (in Suggests):

- **signal** -- additional DSP functions
- **c3dr** -- C3D binary format parsing
- **rhdf5** -- HDF5 support (DeepLabCut)
- **uwot** -- UMAP dimensionality reduction
- **Rtsne** -- t-SNE dimensionality reduction
- **httr** -- HTTP requests (OpenCap cloud API)
- **PhysioIO** -- extended file I/O capabilities

## PhysioExperiment Ecosystem

PhysioMoCap is part of the PhysioExperiment ecosystem, a suite of R packages for multi-modal physiological signal analysis:

| Package | Description |
|---------|-------------|
| [PhysioCore](https://github.com/x-biosignal/PhysioCore) | Core data structures and accessors |
| [PhysioIO](https://github.com/x-biosignal/PhysioIO) | File I/O (EDF, HDF5, BIDS, CSV, MAT) |
| [PhysioPreprocess](https://github.com/x-biosignal/PhysioPreprocess) | Preprocessing (filters, ICA, resampling) |
| [PhysioAnalysis](https://github.com/x-biosignal/PhysioAnalysis) | Analysis and visualization |
| [PhysioCrossModal](https://github.com/x-biosignal/PhysioCrossModal) | Cross-modal coupling and connectivity |
| **PhysioMoCap** | Motion capture and biomechanics |

Visit the [r-universe page](https://x-biosignal.r-universe.dev) to browse all available packages.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

Yusuke Matsui

## Governance & support

Part of the [Physio ecosystem](https://x-biosignal.r-universe.dev). Community and
policy documents live in the umbrella repository:

- [Code of Conduct](https://github.com/x-biosignal/PhysioExperiment/blob/main/CODE_OF_CONDUCT.md)
- [Contributing](https://github.com/x-biosignal/PhysioExperiment/blob/main/CONTRIBUTING.md)
- [Governance](https://github.com/x-biosignal/PhysioExperiment/blob/main/GOVERNANCE.md)
- [Support](https://github.com/x-biosignal/PhysioExperiment/blob/main/SUPPORT.md)
- [Security policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/SECURITY.md)
- [Deprecation & lifecycle policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/DEPRECATION.md)
