# PhysioMoCap ![PhysioMoCap logo](reference/figures/logo.png)

**Motion Capture and Biomechanics Analysis for PhysioExperiment
Objects**

PhysioMoCap provides a comprehensive motion capture, pose estimation,
and biomechanical analysis toolkit built on the `PhysioExperiment` data
model. With 177 exported functions – the largest package in the
PhysioExperiment ecosystem – it covers the full analysis pipeline from
file I/O through kinematics, kinetics, gait analysis, movement
variability, EMG integration, and clinical statistics. PhysioMoCap
supports optical motion capture (C3D, Venus3D), markerless pose
estimation (OpenPose, DeepLabCut, MediaPipe, OpenCap), skeletal
animation formats (BVH, ASF/AMC), OpenSim musculoskeletal modeling, and
standardized datasets (GaitRec).

## Installation

You can install PhysioMoCap from
[r-universe](https://x-biosignal.r-universe.dev):

``` r

install.packages("PhysioMoCap",
  repos = c("https://x-biosignal.r-universe.dev", "https://cloud.r-project.org"))
```

Or install the development version from GitHub:

``` r

# install.packages("remotes")
remotes::install_github("x-biosignal/PhysioMoCap")
```

## Quick Start

``` r

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

Read data from all major motion capture, pose estimation, and
biomechanics formats through a unified interface:

**Optical motion capture:** -
[`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md)
– C3D binary format (marker positions, analog data, force plates) -
[`readVenus3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readVenus3D.md)
– Venus3D optical tracking system -
[`readMoCapCSV()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapCSV.md)
– generic CSV with configurable column mapping

**Markerless pose estimation:** -
[`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md)
– OpenPose JSON keypoint output -
[`readDeepLabCut()`](https://x-biosignal.github.io/PhysioMoCap/reference/readDeepLabCut.md)
– DeepLabCut HDF5/CSV pose estimation -
[`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md)
– MediaPipe holistic/pose landmarks -
[`readOpenCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenCap.md)
– OpenCap cloud-based markerless capture

**Skeletal animation:** -
[`readBVH()`](https://x-biosignal.github.io/PhysioMoCap/reference/readBVH.md)
– BioVision Hierarchy motion files -
[`readASF()`](https://x-biosignal.github.io/PhysioMoCap/reference/readASF.md)
/
[`readAMC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readAMC.md)
– Acclaim skeleton and motion data

**OpenSim musculoskeletal modeling:** -
[`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md)
– marker coordinate files -
[`readMOT()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMOT.md)
– motion/force data files -
[`readSTO()`](https://x-biosignal.github.io/PhysioMoCap/reference/readSTO.md)
– storage files (IK, ID, muscle analysis results) -
[`readOpenSimOutputs()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenSimOutputs.md)
– batch read all OpenSim tool outputs

**Standardized datasets:** -
[`readGaitRec()`](https://x-biosignal.github.io/PhysioMoCap/reference/readGaitRec.md)
– GaitRec clinical gait database

**Auto-detection:** -
[`readMoCapAuto()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMoCapAuto.md)
– automatically detect format and call the appropriate reader

### Skeleton and Kinematics

Define skeletal models and compute joint-level kinematics:

- [`define_skeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/define_skeleton.md)
  /
  [`SkeletonModel()`](https://x-biosignal.github.io/PhysioMoCap/reference/SkeletonModel.md)
  – create custom skeletal topology with segment definitions
- [`get_bone_connections()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_bone_connections.md),
  [`get_limb_pairs()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_limb_pairs.md),
  [`get_segment_lengths()`](https://x-biosignal.github.io/PhysioMoCap/reference/get_segment_lengths.md)
  – query skeleton structure
- [`calculateJointAngles()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateJointAngles.md)
  – 3D joint angles from marker positions
- [`vectorAngle()`](https://x-biosignal.github.io/PhysioMoCap/reference/vectorAngle.md)
  – angle between arbitrary 3D vectors
- [`estimateOrientation()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateOrientation.md)
  – orientation estimation from IMU or marker data
- [`quaternionToEuler()`](https://x-biosignal.github.io/PhysioMoCap/reference/quaternionToEuler.md)
  /
  [`eulerToQuaternion()`](https://x-biosignal.github.io/PhysioMoCap/reference/eulerToQuaternion.md)
  – rotation representation conversion
- [`calibrateIMU()`](https://x-biosignal.github.io/PhysioMoCap/reference/calibrateIMU.md)
  – IMU sensor calibration

### Gap Handling

Detect and fill missing marker data in optical tracking recordings:

- [`detectGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectGaps.md)
  – identify gaps (missing frames) per marker
- [`fillGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGaps.md)
  – gap filling with configurable method
- [`fillGapsLinear()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsLinear.md)
  – linear interpolation for short gaps
- [`fillGapsSpline()`](https://x-biosignal.github.io/PhysioMoCap/reference/fillGapsSpline.md)
  – cubic spline interpolation for longer gaps
- [`reportGaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/reportGaps.md)
  – summary statistics of gap distribution

### Marker Tracking

Automated marker labeling and swap correction for optical systems:

- [`trackMarkers()`](https://x-biosignal.github.io/PhysioMoCap/reference/trackMarkers.md)
  – frame-to-frame marker assignment using the Hungarian algorithm
- [`detectSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectSwaps.md)
  – identify marker label swaps between frames
- [`correctSwaps()`](https://x-biosignal.github.io/PhysioMoCap/reference/correctSwaps.md)
  – automatically correct detected label swaps

### Signal Processing

General-purpose signal processing adapted for motion data:

- [`filterSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterSignals.md)
  – apply filters to PhysioExperiment assay data
- [`butterworthFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/butterworthFilter.md)
  – Butterworth IIR filter (low/high/bandpass)
- [`savgolFilter()`](https://x-biosignal.github.io/PhysioMoCap/reference/savgolFilter.md)
  – Savitzky-Golay smoothing filter
- [`differentiate()`](https://x-biosignal.github.io/PhysioMoCap/reference/differentiate.md)
  – numerical differentiation (central differences)
- [`computeVelocity()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeVelocity.md)
  /
  [`computeAcceleration()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeAcceleration.md)
  /
  [`computeJerk()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJerk.md)
  /
  [`computeSpeed()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeSpeed.md)
  – kinematic derivatives
- [`resampleSignal()`](https://x-biosignal.github.io/PhysioMoCap/reference/resampleSignal.md)
  /
  [`resampleVector()`](https://x-biosignal.github.io/PhysioMoCap/reference/resampleVector.md)
  – change sampling rate via interpolation
- [`movingAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/movingAverage.md)
  – moving average smoothing

### Biomechanics

Center of mass, segment inertia, and gravity compensation:

- [`calculateCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOM.md)
  – whole-body center of mass from segment model
- [`calculateSegmentCOM()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateSegmentCOM.md)
  – segment-level center of mass
- [`estimateSegmentInertia()`](https://x-biosignal.github.io/PhysioMoCap/reference/estimateSegmentInertia.md)
  – inertial parameters from anthropometric tables
- [`segmentParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentParameters.md)
  – segment mass, length, and COM location
- [`removeGravity()`](https://x-biosignal.github.io/PhysioMoCap/reference/removeGravity.md)
  – subtract gravitational component from accelerometer data

### Phase and Event Analysis

Event detection and movement phase segmentation with pre-built task
schemas:

- [`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md)
  – automatic event detection from kinematic signals
- [`manualEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/manualEvents.md)
  – define events from known timestamps
- [`Event()`](https://x-biosignal.github.io/PhysioMoCap/reference/Event.md)
  /
  [`Phase()`](https://x-biosignal.github.io/PhysioMoCap/reference/Phase.md)
  – event and phase constructors
- [`getEvent()`](https://x-biosignal.github.io/PhysioMoCap/reference/getEvent.md)
  /
  [`getEventNames()`](https://x-biosignal.github.io/PhysioMoCap/reference/getEventNames.md)
  – query detected events
- [`segmentPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/segmentPhases.md)
  – segment continuous data into movement phases
- [`extractPhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractPhase.md)
  – extract data within a specific phase
- [`getPhase()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhase.md)
  /
  [`getPhaseNames()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseNames.md)
  /
  [`getPhaseData()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseData.md)
  /
  [`getPhaseColors()`](https://x-biosignal.github.io/PhysioMoCap/reference/getPhaseColors.md)
  – phase accessors
- [`hasValidPhases()`](https://x-biosignal.github.io/PhysioMoCap/reference/hasValidPhases.md)
  – validate phase segmentation
- [`phaseTiming()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseTiming.md)
  /
  [`phaseDurations()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseDurations.md)
  /
  [`phaseRatios()`](https://x-biosignal.github.io/PhysioMoCap/reference/phaseRatios.md)
  – temporal characteristics of phases

**Pre-built task schemas:** -
[`TaskSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/TaskSchema.md)
/
[`validateSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateSchema.md)
/
[`getSchema()`](https://x-biosignal.github.io/PhysioMoCap/reference/getSchema.md)
/
[`listSchemas()`](https://x-biosignal.github.io/PhysioMoCap/reference/listSchemas.md)
– schema management -
[`schema_gait()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_gait.md)
– walking (heel strike, toe off, stance, swing) -
[`schema_running()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_running.md)
– running (flight phase, contact phase) -
[`schema_jump()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_jump.md)
– vertical/horizontal jump (takeoff, flight, landing) -
[`schema_cycling()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_cycling.md)
– pedaling (top dead center, power phase, recovery) -
[`schema_balance()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_balance.md)
– postural balance (quiet stance, perturbation, recovery) -
[`schema_cutting()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_cutting.md)
– cutting maneuvers (approach, plant, push-off) -
[`schema_throw()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_throw.md)
– throwing (wind-up, acceleration, release, follow-through)

### Movement Analysis

Variability, similarity, and dimensionality reduction for movement
waveforms:

- [`normalizeMovement()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeMovement.md)
  – time-normalize waveforms to percentage of cycle
- [`normalizedTimeAxis()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizedTimeAxis.md)
  – generate normalized time vector
- [`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md)
  – dynamic time warping distance between waveforms
- [`dtwDistanceMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistanceMatrix.md)
  – pairwise DTW distance matrix
- [`dtwWarp()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwWarp.md)
  – compute optimal warping path
- [`dtwAverage()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwAverage.md)
  – DTW barycenter averaging
- [`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md)
  – hierarchical clustering of movement patterns
- [`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md)
  – principal component analysis of waveform ensembles
- [`extractWaveformFeatures()`](https://x-biosignal.github.io/PhysioMoCap/reference/extractWaveformFeatures.md)
  – extract amplitude, timing, and shape features
- [`waveformUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformUMAP.md)
  – UMAP dimensionality reduction for movement patterns
- [`waveformTSNE()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformTSNE.md)
  – t-SNE dimensionality reduction
- [`combineTrials()`](https://x-biosignal.github.io/PhysioMoCap/reference/combineTrials.md)
  – combine multiple trials into an ensemble
- [`batchNormalize()`](https://x-biosignal.github.io/PhysioMoCap/reference/batchNormalize.md)
  – batch normalization across trials

### Gait Analysis

Spatiotemporal gait parameters and symmetry assessment:

- [`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md)
  – cadence, stride length, walking speed, stance/swing ratio
- [`summarizeGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/summarizeGaitParameters.md)
  – aggregate parameters across multiple cycles
- [`calculateStepSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateStepSymmetry.md)
  – step length and timing symmetry
- [`symmetryIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/symmetryIndex.md)
  – Robinson symmetry index and related metrics

### Force Plate Kinetics

Ground reaction force analysis and contact detection:

- [`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md)
  /
  [`analyzeForcePlatePE()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlatePE.md)
  – comprehensive force plate analysis
- [`detectForcePlateContacts()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectForcePlateContacts.md)
  – threshold-based contact detection
- [`filterGRF()`](https://x-biosignal.github.io/PhysioMoCap/reference/filterGRF.md)
  – low-pass filter for ground reaction force data
- [`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md)
  – center of pressure calculation
- [`computeLoadingRate()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeLoadingRate.md)
  – vertical GRF loading rate
- [`computeImpulse()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeImpulse.md)
  – impulse (time integral of GRF)

### Inverse Dynamics

Joint moment and power estimation from kinematics and kinetics:

- [`inverseDynamics2D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics2D.md)
  – planar (sagittal plane) inverse dynamics
- [`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md)
  – full 3D inverse dynamics
- [`computeJointPower()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeJointPower.md)
  – joint power from moment and angular velocity

### EMG Integration

Electromyography processing and synchronization with motion data:

- [`normalizeEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeEMG.md)
  – amplitude normalization (MVC, peak, mean)
- [`rectifyEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/rectifyEMG.md)
  – full-wave rectification
- [`computeRMSEnvelope()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeRMSEnvelope.md)
  – root mean square envelope
- [`processEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/processEMG.md)
  – combined rectification + envelope pipeline
- [`alignEMGtoMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/alignEMGtoMoCap.md)
  – temporal alignment of EMG to motion capture data
- [`integrateEMGMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/integrateEMGMoCap.md)
  – unified EMG-MoCap analysis
- [`synchronizeSignals()`](https://x-biosignal.github.io/PhysioMoCap/reference/synchronizeSignals.md)
  – general-purpose signal synchronization

### Clinical Statistics

Reliability and agreement metrics commonly used in rehabilitation
research:

- [`icc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/icc.html)
  – intraclass correlation coefficient (ICC) for inter-rater/test-retest
  reliability
- [`sem()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/sem.html)
  – standard error of measurement
- [`mdc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/mdc.html)
  – minimal detectable change
- [`blandAltman()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/blandAltman.html)
  – Bland-Altman limits of agreement analysis
- [`cohensD()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/cohensD.html)
  – Cohen’s d effect size
- [`etaSquared()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/etaSquared.html)
  – eta-squared effect size for ANOVA designs

### OpenSim Integration

Interface for OpenSim musculoskeletal simulation workflows:

- [`create_schema_from_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/create_schema_from_opensim.md)
  – derive task schemas from OpenSim motion files
- [`batch_analyze_opensim()`](https://x-biosignal.github.io/PhysioMoCap/reference/batch_analyze_opensim.md)
  – batch processing of OpenSim results
- [`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md)
  – run OpenSim tools (IK, ID, SO, RRA, CMC) from R

### Visualization

Biomechanics-specific plotting functions:

- [`plotSkeleton()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton.md)
  /
  [`plotSkeleton3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeleton3D.md)
  – 2D and 3D stick figure visualization
- [`plotSkeletonOverlay()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonOverlay.md)
  /
  [`plotSkeletonSequence()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSkeletonSequence.md)
  – multi-frame skeleton display
- [`plotTrajectory()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotTrajectory.md)
  – marker trajectory over time
- [`plotCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotCycle.md)
  /
  [`plotGaitCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGaitCycle.md)
  – ensemble-averaged cycle plots with variability bands
- [`plotMultiPanel()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotMultiPanel.md)
  – multi-channel panel plots (kinematics, kinetics, EMG)
- [`plotSpaghetti()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSpaghetti.md)
  – overlaid individual trials (spaghetti plot)
- [`plotPhasePortrait()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPhasePortrait.md)
  – phase plane plots (position vs. velocity)
- [`plotPhaseDurations()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPhaseDurations.md)
  – phase timing bar charts
- [`plotSymmetry()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotSymmetry.md)
  – symmetry radar/bar plots
- [`plotDTW()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotDTW.md)
  – DTW alignment visualization
- [`plotFPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotFPCA.md)
  – functional PCA component plots
- [`plotPCAScatter()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAScatter.md)
  /
  [`plotPCAVariance()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotPCAVariance.md)
  – PCA results visualization
- [`plotUMAP()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotUMAP.md)
  – UMAP embedding scatter plots
- [`plotWaveformComparison()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotWaveformComparison.md)
  – side-by-side waveform comparison
- [`plotGroupComparison()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGroupComparison.md)
  – group-level statistical comparison plots
- [`plotCorrelationMatrix()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotCorrelationMatrix.md)
  – correlation heatmaps
- [`plotEffectSizeForest()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotEffectSizeForest.md)
  – forest plots for effect sizes

### Benchmarking and Validation

Tools for validating analysis pipelines against reference data:

- [`createBenchmarkExample()`](https://x-biosignal.github.io/PhysioMoCap/reference/createBenchmarkExample.md)
  – generate synthetic benchmark datasets
- [`runBenchmarkSuite()`](https://x-biosignal.github.io/PhysioMoCap/reference/runBenchmarkSuite.md)
  – run full benchmark pipeline
- [`benchmarkAgreement()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkAgreement.md)
  – compute agreement metrics against gold standard
- [`benchmarkManifestTemplate()`](https://x-biosignal.github.io/PhysioMoCap/reference/benchmarkManifestTemplate.md)
  /
  [`writeBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/writeBenchmarkManifest.md)
  /
  [`validateBenchmarkManifest()`](https://x-biosignal.github.io/PhysioMoCap/reference/validateBenchmarkManifest.md)
  – manage benchmark data manifests
- [`defaultBenchmarkThresholds()`](https://x-biosignal.github.io/PhysioMoCap/reference/defaultBenchmarkThresholds.md)
  – standard thresholds for biomechanics validation

### Onboarding

Helpers for new users to explore the package without external data:

- [`quickStartMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/quickStartMoCap.md)
  – generate a complete worked example with simulated data
- [`assessMoCapReadiness()`](https://x-biosignal.github.io/PhysioMoCap/reference/assessMoCapReadiness.md)
  – check data readiness for downstream analysis
- [`demoMoCapData()`](https://x-biosignal.github.io/PhysioMoCap/reference/demoMoCapData.md)
  – create demonstration PhysioExperiment objects

## Use Cases

| Application | Key Functions |
|----|----|
| Clinical gait analysis | [`readC3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/readC3D.md), [`detectEvents()`](https://x-biosignal.github.io/PhysioMoCap/reference/detectEvents.md), [`calculateGaitParameters()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateGaitParameters.md), [`plotGaitCycle()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotGaitCycle.md) |
| Markerless pose tracking | [`readOpenPose()`](https://x-biosignal.github.io/PhysioMoCap/reference/readOpenPose.md), [`readDeepLabCut()`](https://x-biosignal.github.io/PhysioMoCap/reference/readDeepLabCut.md), [`readMediaPipe()`](https://x-biosignal.github.io/PhysioMoCap/reference/readMediaPipe.md) |
| Running biomechanics | [`schema_running()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_running.md), [`analyzeForcePlate()`](https://x-biosignal.github.io/PhysioMoCap/reference/analyzeForcePlate.md), [`computeLoadingRate()`](https://x-biosignal.github.io/PhysioMoCap/reference/computeLoadingRate.md) |
| Movement variability | [`dtwDistance()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwDistance.md), [`dtwClustering()`](https://x-biosignal.github.io/PhysioMoCap/reference/dtwClustering.md), [`waveformPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/waveformPCA.md), [`fPCA()`](https://x-biosignal.github.io/PhysioMoCap/reference/fPCA.md) |
| Musculoskeletal modeling | [`readTRC()`](https://x-biosignal.github.io/PhysioMoCap/reference/readTRC.md), [`run_opensim_toolchain()`](https://x-biosignal.github.io/PhysioMoCap/reference/run_opensim_toolchain.md), [`inverseDynamics3D()`](https://x-biosignal.github.io/PhysioMoCap/reference/inverseDynamics3D.md) |
| Rehabilitation assessment | [`icc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/icc.html), [`sem()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/sem.html), [`mdc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/mdc.html), [`blandAltman()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/blandAltman.html), [`symmetryIndex()`](https://x-biosignal.github.io/PhysioMoCap/reference/symmetryIndex.md) |
| EMG-MoCap integration | [`normalizeEMG()`](https://x-biosignal.github.io/PhysioMoCap/reference/normalizeEMG.md), [`alignEMGtoMoCap()`](https://x-biosignal.github.io/PhysioMoCap/reference/alignEMGtoMoCap.md), [`plotMultiPanel()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotMultiPanel.md) |
| Balance/postural control | [`schema_balance()`](https://x-biosignal.github.io/PhysioMoCap/reference/schema_balance.md), [`calculateCOP()`](https://x-biosignal.github.io/PhysioMoCap/reference/calculateCOP.md), [`plotTrajectory()`](https://x-biosignal.github.io/PhysioMoCap/reference/plotTrajectory.md) |

## Dependencies

- **R** (\>= 4.2)
- **PhysioCore** – core data structures and accessors
- **ggplot2** – visualization
- **jsonlite** – JSON parsing (OpenPose, MediaPipe)
- **SummarizedExperiment**, **S4Vectors** – Bioconductor infrastructure
- **stats**, **utils**, **rlang**, **scales** – base R and tidyverse
  utilities

Optional (in Suggests):

- **signal** – additional DSP functions
- **c3dr** – C3D binary format parsing
- **rhdf5** – HDF5 support (DeepLabCut)
- **uwot** – UMAP dimensionality reduction
- **Rtsne** – t-SNE dimensionality reduction
- **httr** – HTTP requests (OpenCap cloud API)
- **PhysioIO** – extended file I/O capabilities

## PhysioExperiment Ecosystem

PhysioMoCap is part of the PhysioExperiment ecosystem, a suite of R
packages for multi-modal physiological signal analysis:

| Package | Description |
|----|----|
| [PhysioCore](https://github.com/x-biosignal/PhysioCore) | Core data structures and accessors |
| [PhysioIO](https://github.com/x-biosignal/PhysioIO) | File I/O (EDF, HDF5, BIDS, CSV, MAT) |
| [PhysioPreprocess](https://github.com/x-biosignal/PhysioPreprocess) | Preprocessing (filters, ICA, resampling) |
| [PhysioAnalysis](https://github.com/x-biosignal/PhysioAnalysis) | Analysis and visualization |
| [PhysioCrossModal](https://github.com/x-biosignal/PhysioCrossModal) | Cross-modal coupling and connectivity |
| **PhysioMoCap** | Motion capture and biomechanics |

Visit the [r-universe page](https://x-biosignal.r-universe.dev) to
browse all available packages.

## License

MIT License. See
[LICENSE](https://x-biosignal.github.io/PhysioMoCap/LICENSE) for
details.

## Author

Yusuke Matsui

## Governance & support

Part of the [Physio ecosystem](https://x-biosignal.r-universe.dev).
Community and policy documents live in the umbrella repository:

- [Code of
  Conduct](https://github.com/x-biosignal/PhysioExperiment/blob/main/CODE_OF_CONDUCT.md)
- [Contributing](https://github.com/x-biosignal/PhysioExperiment/blob/main/CONTRIBUTING.md)
- [Governance](https://github.com/x-biosignal/PhysioExperiment/blob/main/GOVERNANCE.md)
- [Support](https://github.com/x-biosignal/PhysioExperiment/blob/main/SUPPORT.md)
- [Security
  policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/SECURITY.md)
- [Deprecation & lifecycle
  policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/DEPRECATION.md)
