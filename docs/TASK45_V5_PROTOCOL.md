# V5 adaptive sampling and energy-control protocol

V1-V4 remain frozen. This is an experimental iteration, not a promise to beat
V4 or a new course-task completion claim. All arms retain the same orientation,
world/self-collision checks and feasible-only quality refinement.

## Questions and arms

The five arms are `ambient`, `energy_control`, `fixed50`, `fixed75`, `adaptive`.
All use 61 nodes, 64 primary rollouts, the frozen 0.55 rad noise schedule,
200 iterations/restart, three restarts and the same 300 s planner target.
Refinement retains 32 rollouts, 0.10 rad noise, at most 20 iterations and a
45 s target within the total target. Wall-clock limits are checked between
iterations; actual overruns and trace-writing time are retained.

- `ambient`: ambient Gaussian innovations followed by nonlinear projection.
- `energy_control`: same innovations, with the selected 75% of samples scaled
  to the **same post-limit, pre-nonlinear-projection squared perturbation norm**
  as their counterfactual 75% tangent counterparts. Scaling is per rollout,
  does not increase its amplitude, and preserves limits and fixed endpoints.
- `fixed50`, `fixed75`: fixed 50% or 75% tangent / remaining ambient pairs.
- `adaptive`: starts each restart at 50%. A deterministic controller compares
  the mean best quartile of finite primary rollout costs in tangent and
  ambient groups. It applies an EWMA (old weight 0.5), a normalized advantage
  deadband of 0.02 and 0.25 fraction steps, bounded to [0.25,0.75]. Three stalled
  iterations force 25% tangent exploration. It adds no random draws or FK calls.
  Refinement uses fixed 50%, making `fixed50` the no-feedback ablation.

Energy matching does **not** match covariance or post-projection variance.
Both pre- and post-projection energies, actual perturbations, projection work,
controller states and RNG states are saved. No speed claim is based solely on
the energy control, which computes a counterfactual tangent map.

## Scenarios and separation

Three independently saved scenarios: the original mounted `workcell`, the
same obstacles with a changed upright `endpoints` pair, and a `layout` with
original endpoints but a shifted/wider rack, inward equipment and rear guard.
Scene definitions in `memberC.scenarioData` drive every collision object,
voxel field and rendering. A geometry-only preflight requires feasible fixed
endpoints, a colliding straight initialization, no initial self collision and
a separate feasible witness. Geometry preflight revisions are retained. The
witness is forbidden as a planner initialization, restart or output.

Development seeds: 5700-5701, five arms x three scenarios = 30 runs. One
controller design is tested; there is no parameter grid. Code defects may be
repaired before freeze, with interrupted/obsolete attempts retained separately.
Freeze requires unit checks, V4 fixed-sampler replay compatibility, geometry
preflight, at least one adaptive and fixed75 success in each scenario, and one
common successful workcell demonstration seed. A failed gate is reported.

Formal seeds: **5800-5804**, five arms x three scenarios = **75 runs**, accessed
only after source/options/driver hashes are frozen. Two workers split seeds;
arm order rotates by seed and scenario. No formal-result-driven tuning.

## Fixed-state sampling ablation

Before formal planning, 30 paired batches use three scenarios, two central
paths (colliding linear and geometry witness), and seeds 5760-5764. Each batch
uses the same Gaussian draws for ambient, energy control and fixed75 sampling.
It checks per-rollout pre-projection energy equality and compares projection
work and actual post-projection RMS. This is a sampling diagnostic, not
planning success evidence. The witness is not passed to the optimizer.

## Acceptance and analysis

Exact endpoints, joint limits, 35 mm conservative world clearance, zero actual
unpermitted world/self collisions, tool above table and maximum tilt <=5 deg.
Nominal acceptance uses 0.0125 rad joint increments. Independent final checks
use 0.00625 rad; any nominal success that fails the finer check is counted as a
study failure, with both labels and diagnostics retained. Validation is discrete.

Report all runs and failure labels, first-feasible and total times, first/final
secondary quality, length, smoothness, clearance, tilt, projection work,
energies and controller behavior. Quality comparisons use common successful
case/seed pairs with n shown. Report each scenario separately; any pooled
summary is descriptive over these cases, not a universal reliability estimate.
Adaptive vs fixed50 isolates search feedback; adaptive vs fixed75 compares
complete sampler choices. Fixed75 vs energy control addresses input energy
while retaining the explicit post-projection caveat.

The secondary score remains joint length + 5*smoothness + the fixed soft
45 mm clearance preference. Successful refinement cannot regress its own
incumbent. First-solution quality is reported separately, since time-limited
refinement may complete different iteration counts on different machines.

All raw formal checkpoints remain local. Git includes configs, trajectories,
profiles, complete audit receipts, fixed-state probe replay and copied
development demonstrations. Previous release manifests remain unchanged.
