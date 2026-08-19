"""Generate an OpenSim gait2392 inverse-dynamics reference for PhysioMoCap's
inverseDynamicsRNE() cross-validation (WSCB-12).

Source: opensim-org/opensim-models @ d9b05d4, Pipelines/Gait2392_Simbody
        (scaled model subject01_simbody.osim, trial subject01_walk1).
OpenSim 4.6. Everything self-consistent: the same 6 Hz-filtered kinematics
drive both the OpenSim ID moments (the reference) and the sagittal joint-centre
positions fed to the RNE. Right leg, sagittal (ground X = anterior, Y = vertical).
"""
import json
import numpy as np
import opensim as osim

WD = "/tmp/wscb12"
MODEL = f"{WD}/subject01_simbody.osim"
IK = f"{WD}/subject01_walk1_ik.mot"
GRF = f"{WD}/subject01_walk1_grf.mot"
EXTLOADS = f"{WD}/subject01_walk1_grf.xml"
T0, T1 = 0.40, 1.60
CUTOFF = 6.0

# ---- 1. Run OpenSim Inverse Dynamics (genuine reference moments) -----------
model = osim.Model(MODEL)
model.initSystem()

idtool = osim.InverseDynamicsTool()
idtool.setModel(model)
idtool.setModelFileName(MODEL)
idtool.setCoordinatesFileName(IK)
idtool.setLowpassCutoffFrequency(CUTOFF)
idtool.setStartTime(T0)
idtool.setEndTime(T1)
idtool.setExternalLoadsFileName(EXTLOADS)
excl = osim.ArrayStr(); excl.append("muscles")
idtool.setExcludedForces(excl)
idtool.setResultsDir(WD)
idtool.setOutputGenForceFileName("myID.sto")
ok = idtool.run()
print("ID run ok:", ok)

idt = osim.TimeSeriesTable(f"{WD}/myID.sto")
idtime = np.array(idt.getIndependentColumn())
def idcol(name):
    return np.array(idt.getDependentColumn(name).to_numpy())
ref_hip = idcol("hip_flexion_r_moment")
ref_knee = idcol("knee_angle_r_moment")
ref_ankle = idcol("ankle_angle_r_moment")

# cross-check against the checked-in reference output
try:
    reft = osim.TimeSeriesTable(f"{WD}/InverseDynamicsOutput.sto")
    rt = np.array(reft.getIndependentColumn())
    rh = np.array(reft.getDependentColumn("hip_flexion_r_moment").to_numpy())
    chk = np.interp(idtime, rt, rh)
    denom = np.max(np.abs(ref_hip)) + 1e-9
    print("hip moment vs checked-in reference: max norm diff =",
          float(np.max(np.abs(chk - ref_hip)) / denom))
except Exception as e:
    print("checked-in cross-check skipped:", e)

# ---- 2. Filtered kinematics -> sagittal joint centres over [T0,T1] ---------
# Load coordinates, low-pass at 6 Hz (matching ID), convert deg->rad.
store = osim.Storage(IK)
store.pad(50)
store.lowpassIIR(CUTOFF)
model.getSimbodyEngine().convertDegreesToRadians(store)

state = model.initSystem()
coords = model.getCoordinateSet()
ncoord = coords.getSize()
labels = store.getColumnLabels()  # ArrayStr incl. 'time'

# map coordinate name -> storage column index (0-based within data row)
col_of = {}
for i in range(ncoord):
    nm = coords.get(i).getName()
    idx = labels.findIndex(nm)  # 1-based incl time; data index = idx-1
    if idx > 0:
        col_of[nm] = idx - 1

T = idtime[(idtime >= T0) & (idtime <= T1)]
NCOL = labels.getSize() - 1  # number of data columns (excl. time)

def sample_coords(t):
    ar = osim.ArrayDouble()
    ar.setSize(NCOL)
    store.getDataAtTime(t, NCOL, ar)
    return [ar.get(k) for k in range(ar.getSize())]

def joint_centre(jname):
    return model.getJointSet().get(jname).getChildFrame().getPositionInGround(state)

hipC = model.getJointSet().get("hip_r")
mk_toe = model.getMarkerSet().get("R.Toe.Tip")

J = {k: [] for k in ("hip_x","hip_y","knee_x","knee_y",
                     "ankle_x","ankle_y","toe_x","toe_y")}
for t in T:
    vals = sample_coords(t)
    for nm, dc in col_of.items():
        c = coords.get(nm)
        if not c.get_locked():
            c.setValue(state, vals[dc], False)
    model.assemble(state)
    model.realizePosition(state)
    hip = joint_centre("hip_r"); knee = joint_centre("knee_r")
    ank = joint_centre("ankle_r"); toe = mk_toe.getLocationInGround(state)
    J["hip_x"].append(hip.get(0));   J["hip_y"].append(hip.get(1))
    J["knee_x"].append(knee.get(0)); J["knee_y"].append(knee.get(1))
    J["ankle_x"].append(ank.get(0)); J["ankle_y"].append(ank.get(1))
    J["toe_x"].append(toe.get(0));   J["toe_y"].append(toe.get(1))

# ---- 3. Constant segment inertia (thigh/shank/foot) from the model ---------
s0 = model.initSystem()
model.realizePosition(s0)
def bcom(bname):
    b = model.getBodySet().get(bname)
    p = b.findStationLocationInGround(s0, b.getMassCenter())
    return np.array([p.get(0), p.get(1)]), b.getMass(), b.getInertia().getMoments().get(2)
def jc(jname):
    p = model.getJointSet().get(jname).getChildFrame().getPositionInGround(s0)
    return np.array([p.get(0), p.get(1)])

hip0, knee0, ank0 = jc("hip_r"), jc("knee_r"), jc("ankle_r")
toe0 = np.array([model.getMarkerSet().get("R.Toe.Tip").getLocationInGround(s0).get(k)
                 for k in (0, 1)])

def seg_props(prox, dist, com, mass, izz):
    axis = dist - prox
    L = float(np.linalg.norm(axis))
    frac = float(np.dot(com - prox, axis) / (L * L))
    return L, frac

fem_com, fem_m, fem_izz = bcom("femur_r")
tib_com, tib_m, tib_izz = bcom("tibia_r")
# combined foot = talus + calcn + toes
foot_bodies = [bcom(b) for b in ("talus_r", "calcn_r", "toes_r")]
foot_m = sum(b[1] for b in foot_bodies)
foot_com = sum(b[1] * b[0] for b in foot_bodies) / foot_m
foot_izz = sum(b[2] + b[1] * float(np.sum((b[0] - foot_com) ** 2))
               for b in foot_bodies)

Lth, fth = seg_props(hip0, knee0, fem_com, fem_m, fem_izz)
Lsh, fsh = seg_props(knee0, ank0, tib_com, tib_m, tib_izz)
Lft, fft = seg_props(ank0, toe0, foot_com, foot_m, foot_izz)

inertia = [
    {"segment": "foot",  "length": Lft, "mass": foot_m, "com_proximal_fraction": fft, "inertia": foot_izz},
    {"segment": "shank", "length": Lsh, "mass": tib_m,  "com_proximal_fraction": fsh, "inertia": tib_izz},
    {"segment": "thigh", "length": Lth, "mass": fem_m,  "com_proximal_fraction": fth, "inertia": fem_izz},
]
print("inertia:", json.dumps(inertia, indent=0))

# ---- 4. Right-leg GRF interpolated to T ------------------------------------
gt = osim.TimeSeriesTable(GRF)
gtime = np.array(gt.getIndependentColumn())
def gcol(name):
    return np.array(gt.getDependentColumn(name).to_numpy())
grf = {
    "fx": np.interp(T, gtime, gcol("ground_force_vx")),
    "fy": np.interp(T, gtime, gcol("ground_force_vy")),
    "cop_x": np.interp(T, gtime, gcol("ground_force_px")),
    "cop_y": np.interp(T, gtime, gcol("ground_force_py")),
}

# ---- 5. Write outputs ------------------------------------------------------
fs = float(1.0 / np.median(np.diff(T)))
def wcsv(path, cols):
    keys = list(cols.keys())
    arr = np.column_stack([np.asarray(cols[k], float) for k in keys])
    np.savetxt(path, arr, delimiter=",", header=",".join(keys), comments="")

wcsv(f"{WD}/joints.csv", J)
wcsv(f"{WD}/grf.csv", grf)
wcsv(f"{WD}/reference.csv",
     {"time": T, "hip_moment": ref_hip[(idtime>=T0)&(idtime<=T1)],
      "knee_moment": ref_knee[(idtime>=T0)&(idtime<=T1)],
      "ankle_moment": ref_ankle[(idtime>=T0)&(idtime<=T1)]})
with open(f"{WD}/inertia.json", "w") as f:
    json.dump(inertia, f)
with open(f"{WD}/meta.json", "w") as f:
    json.dump({"sampling_rate": fs, "n": int(len(T)),
               "t0": float(T[0]), "t1": float(T[-1])}, f)
print(f"n frames={len(T)}  fs={fs:.3f} Hz  T=[{T[0]:.3f},{T[-1]:.3f}]")
print("done")
