# Task 4-5 implementation and experimental protocol

This extension uses the UR5 PoE model and conservative sphere envelopes from Task 3. The original Task 1-3 evidence remains in `artifacts/runs/final_r2023b/`. New experiments never use that directory as an output destination.

## Scenes and initialization

Both tasks use `qStart = [-1.4; -.85; 1.25; -.4; -pi/2; 0]` and `qGoal = [1.4; -.85; 1.25; -.4; -pi/2; 0]` radians. The initial path is joint-space linear interpolation. Endpoints are immutable. The scene anchor is the world position of `wrist_1_link` at the midpoint configuration, computed from the loaded model at full precision.

| Obstacle | Offset from anchor (m) | Half dimensions (m) |
| --- | --- | --- |
| Central block | `[0, 0, 0]` | `[.08, .08, .08]` |
| Left pillar | `[-.18, -.22, .02]` | `[.06, .06, .18]` |
| Right pillar | `[-.18, .22, .08]` | `[.06, .06, .18]` |

The variant shifts the left pillar by +.04 m in y and the right pillar by -.04 m in y, and increases the right pillar's half height to .20 m. The scene's single `boxes` array supplies the voxel map, analytic distances, independent collision objects, and rendered obstacles.

Every run independently checks endpoint feasibility and actual collision of the linear initialization before optimization. A separate geometric feasibility witness was checked during scene design; its waypoints are absent from the optimizer and are never used to seed or restart STOMP.

## STOMP and the upright constraint

The original named sampling, cost, probability, perturbation, and smoothing functions are reused. A default-off validation callback in `helperSTOMP.m` selects the Task 4-5 extension. With no callback, the legacy implementation executes unchanged. Restarts always begin from the same colliding straight path, with RNG seed `seed + restart - 1`.

A fixed stagnation rule starts the next restart after ten consecutive rounds with objective improvement below the inherited 1e-7 threshold, following at least ten iterations. Acceptance is checked before restarting. This policy was added before the renewed development protocol because diagnostic pilot runs exhausted the entire time budget in a single infeasible local minimum. Those pilot records, including an interrupted run, remain separate and are not formal experiments. The renewed development and both formal conditions use the same rule; noise values, weight order, clearance gates, and maximum budgets remain as specified.

Task 4 disables orientation cost. Task 5 adds the path-parameter integral approximation

`J_orientation = lambda * sum_t norm(R(q_t)*e_y - e_z, 1) / (N-1)`.

Endpoint terms vanish because the fixed endpoints are upright. The angular diagnostic is `atan2(norm(cross(y,z)), dot(y,z))`, giving 0 degrees at alignment and 180 degrees at reversal. Rotation about the upright axis remains unconstrained; this is an axis-direction constraint, not full orientation locking.

Penalty weights are tested in the fixed order 200, 1000, 5000, 20000. If none passes the paired development gate, the authorized engineering extension projects sampled interior waypoints and proposed updates onto the upright manifold. It uses the PoE direction Jacobian, damped least squares (damping 1e-3), at most 20 iterations per waypoint, at most .15 rad per joint per step, and an internal 1-degree target. Near reversal, a deterministic orthogonal axis supplies an escape tangent. Endpoints are excluded from projection. Joint limits are enforced, and failed projected candidates receive zero acceptance probability. Projection introduces no additional random draws. The projection mode fixes lambda at 1000.

The direction Jacobian's columns are `omega_world_j cross y_tool`, with each axis transformed using its PoE ancestor product. Tests compare it with central finite differences. Projection is an extension to this STOMP implementation and does not imply a convergence guarantee for constrained STOMP.

## Unified acceptance

Acceptance requires exact input endpoints, joint limits, at least 35 mm conservative voxel/sphere clearance, no obstacle collision, and no self collision (adjacent parent pairs skipped by MATLAB). Task 5 additionally requires at most 5 degrees of tool-y tilt. The final piecewise linear path is subdivided until every joint increment is at most .0125 rad. These are discrete dense checks, not continuous-time collision or constraint certificates. No carried object, grasp, dynamics, torque, or execution-time parameterization is modeled.

The same validator controls early stopping and feasible candidate retention. A feasible candidate has priority over any infeasible candidate of lower objective value. Failure runs save the best cost candidate and explicit failed gates. Final acceptance recomputes all checks, including MATLAB's loaded collision geometry. The read-only independent verifier rebuilds the model, scene, and distance field, validates saved trajectories, and replays RNG draws, projected disturbances, probabilities, and accepted updates. It also verifies that each saved output occurs among the optimizer's accepted states or unchanged initialization.

## Fixed development and formal study

Development seeds are 5112-5114. The initial common settings are 61 waypoints, 64 rollouts, 200 iterations per restart, three restarts, .55 rad noise, and 300 seconds of planner wall time including per-iteration evidence writes. The wall limit is checked between iterations; one iteration or validation can overrun the limit, and measured time is retained. If either scene has fewer than two successes, the next noise values are .35 and .80 rad. If necessary, a final approved profile uses 81 waypoints, 96 rollouts, 300 iterations, three restarts, .55 rad noise, and 600 seconds. Clearance gates are never relaxed.

Task 4 must have at least two of three successful development seeds in each scene. A Task 5 configuration must have at least two common successful A/B seeds in each scene. Select the first eligible noise profile and smallest eligible weight. If projected mode also fails, stop before formal experiments and retain diagnostics. The demo seed is the smallest development seed that succeeds for all four scene/task combinations.

After freezing, use seeds 5120-5129 for 40 formal runs (two scenes x two tasks x ten seeds). Projected mode adds ten main-scene penalty-only ablations. The source fingerprint, complete options, environment, scene, endpoints, and seed accompany every run. The formal driver rejects changed MATLAB sources. Existing complete runs may be resumed only with matching identity; existing incomplete run folders are preserved and require diagnosis.

All formal runs enter success-rate and runtime statistics. Failures may carry multiple failure labels. Trajectory quality summaries include successful runs only and state their sample sizes; paired comparisons use only common successful seeds. The path-weighted mean tilt integrates against the actual saved normalized parameter, rather than averaging unequally spaced dense states. Joint length is the sum of joint-space segment norms; tool length uses dense Cartesian samples; smoothness is half the summed squared joint second differences. Objective totals with different orientation weights are not used to claim performance superiority.

The inherited restart convention can reuse a random stream across adjacent nominal seeds: for example, seed 5120's second restart and seed 5121's first restart both use 5121. Nominal runs are therefore not guaranteed statistically independent. The study reports descriptive counts and paired sample sizes, without significance tests or independence-based confidence claims. Development restart seeds (at most 5116) remain separate from the formal seed range.

Technical interruptions are preserved separately from completed planning failures. A retry uses the same frozen seed, parameters and initialization. Reports show both completed nominal-case denominators and all observed-attempt denominators, including interrupted attempts without final output. An interrupted attempt's partial runtime is censored and is not substituted for a completed planner duration. The archived checkpoint prefix is independently replayed and compared with overlapping retry checkpoints.

After all 50 outputs had been saved, aggregation failed when an empty common-success intersection had shape 0-by-1: MATLAB attempted one loop iteration with an empty column. The postprocessing loop now iterates over a row vector. The benchmark source guard additionally accepts one exact approved postprocessing fingerprint. Both original source files were preserved and hashed; the other 69 MATLAB files, every raw planning result, and the frozen parameters remain unchanged. `provenance/postprocessing_patch.json` records this repair separately from the original experiment fingerprint. Regression fixtures cover zero pairs and a column-shaped input containing two pairs. No planning runs were repeated for this correction.

## Evidence and portability

Demonstrations retain complete rollout trajectories and actual disturbances. Formal runs retain RNG states, covariance, probabilities, accepted updates, per-round trajectories, costs, diagnostics, and actual projected disturbances. Raw unprojected draws can be regenerated without storing every rollout. Saved media use piecewise linear joint interpolation, 150 frames, 15 fps; the exporter decodes each animation and verifies its frame count. The progress label is normalized path parameter, not physical execution time.

The teammate's Linux archive has identical random states when replayed on Windows, but BLAS roundoff caused a maximum 8.14e-14 sample/noise difference. Its original strict replay code and evidence were preserved. A fresh Windows baseline passed the original strict tests and replay. Regression after the new hook separately compares Task 1-3 trajectories and complete cost/acceptance histories bit for bit.

Git's Windows checkout converts some archived CSV/TXT/JSON files to CRLF. Their original LF-normalized content hashes are checked separately from exact binary hashes. This checkout difference predates the Task 4-5 edits; the original result directory is never rewritten by this extension.

## Member C contribution

Member C adds the multi-obstacle scenes, upright objective and optional projection, unified acceptance, independent replay and verification, fixed paired development/formal experiment drivers, new figures and animations, and Task 4-5 integration material. The PoE backend, robot envelopes, distance-field implementation, and original STOMP stage functions are credited to the Task 1-3 handoff. The additional validation and projection logic does not replace that baseline contribution.
