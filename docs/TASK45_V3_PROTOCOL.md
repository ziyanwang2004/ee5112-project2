# V3 mounted-workcell evaluation protocol

This is a separate third scenario and a new endpoint pair. V1 and V2 remain
frozen. The purpose is to test the existing self-aware planner under a
physically meaningful installation and a forbidden sub-table volume.

## Geometry

The UR5 base is 0.20 m above a world-frame z=0 table on a fixed 0.18 m square
pedestal. The pedestal is a fixed robot body. Only the pedestal/table pair
may contact. Its bottom is asserted to lie at z=0. No UR5 link or tool is
exempt from floor, obstacle, or self-collision checking. The pedestal is
included in actual self-collision checks and the optimization's self proxy.
The table fills the whole sub-table voxel workspace. Every UR5 sphere still
requires 35 mm conservative clearance; the fixed pedestal has its declared
mounting contact instead of that world-proxy margin.

The scene contains a 0.65 m central rack, two floor-mounted equipment boxes,
and a 0.70 m rear guard. All planning, rendering and actual collision objects
come from one saved box array. Workspace bounds are [-1,1] x [-1,1] x [-0.4,1.6] m.

The new upright endpoints are:

```matlab
qStart = [-1.10; -1.05; 1.35; -0.30; -pi/2; 0];
qGoal  = [ 1.05; -0.75; 1.10; -0.35; -pi/2; 0];
```

The scene probe verifies endpoints, the colliding straight initialization,
and a geometric existence witness. The witness is prohibited as an optimizer
initialization, restart or output. Every optimizer run starts from the
straight joint interpolation and the public verifier checks that fact.

## Development and freeze

Development seeds are **5300-5302**, paired between Tasks 4 and 5.
The first profile retains V2's 61 waypoints, 64 rollouts, 200 iterations per
restart, 3 restarts, noise 0.55 rad, and 300 s planner target including trace
writes. Time is checked between iterations, so a final iteration may finish
slightly after the target. All actual times are retained.

The ordered fallback profiles change only noise to 0.35 and then 0.80 rad.
The first profile with at least 2/3 common A/B successes is selected. If none
passes, try one extension with 81 waypoints, 96 rollouts, 300 iterations per
restart, 3 restarts, noise 0.55 rad, and 600 s target. If that also fails,
retain all diagnostics and stop before accessing reserved formal seeds.

Task 4 has no orientation objective. Task 5 retains lambda=1000 and the V2
direction projection. Both retain the same self-collision objective and
candidate mesh self-collision filter. No new postprocessing, payload model
or dynamics feature is added by this experiment.

Before formal trials, freeze the chosen parameters, all MATLAB source
hashes, script hashes, and the smallest common successful demo seed.

## Reserved formal evaluation

Use **5400-5419**, not accessed during development: 20 seeds x 2 conditions
= **40 formal runs** in the new workcell. Pair the same seed, endpoints,
initialization, geometry and base budget; alternate condition order across
seeds. Two workers split seeds by parity. All failures remain in denominators.
This scenario is reported separately from the earlier V2 scenes and is not
pooled into a universal success rate. Further adaptation after viewing the
holdout results would require another separately named study and new seeds.

Success requires exact endpoints, joint limits, at least 35 mm conservative
UR5 clearance, no actual nonpermitted world collision, no self collision,
tool above the table, and maximum Task 5 tilt <=5 degrees. Final validation
uses <=0.0125 rad joint increments. All successful formal paths additionally
receive a 0.00625 rad verification. All are discrete checks.

## Evidence

Save configurations, model, actual projected disturbances, RNG states,
accepted updates, trajectories, per-state diagnostics, failure labels,
timings, paired statistics, editable figures and 150-frame/15-fps animations.
Independently recreate the mounted robot and scene to verify paths, replay
all optimizer checkpoints and confirm that the mounting exception does not
permit a moving link or the tool to penetrate the table. Preserve all prior
V1/V2 release hashes.
