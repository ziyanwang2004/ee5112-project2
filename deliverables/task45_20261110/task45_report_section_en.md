# Tasks 4–5: constrained UR5 planning and algorithm extensions

## Scope and contribution

Tasks 1–3 supply the STOMP stages, UR5 model, robot envelopes and cached Product of Exponentials (PoE) forward kinematics. Member C extends that baseline with multi-obstacle environments, an upright tool constraint, self-collision treatment, explicit acceptance rules, paired experiments and independent replay validation. Later studies examine feasible-path refinement, tangent sampling, input-energy control and adaptive sampling. These additions are engineering extensions of STOMP, without a new convergence or global-optimality guarantee.

## Task 4: a nontrivial mounted workcell

The main course demonstration uses the V3 workcell. A fixed 0.18×0.18×0.20 m pedestal raises the UR5 base 0.20 m above a table. Five axis-aligned environment volumes represent the table, central rack, two equipment boxes and rear guard. Only the fixed pedestal/table contact is permitted. Every moving link and the tool remain subject to world and self-collision checking. The pedestal also participates in the robot self-collision model.

Both conditions use the same endpoints, in radians:

```text
q_start = [-1.10, -1.05, 1.35, -0.30, -pi/2, 0]^T
q_goal  = [ 1.05, -0.75, 1.10, -0.35, -pi/2, 0]^T
```

The endpoints are upright and feasible. The shared straight joint-space initialization collides with the environment at 92/181 states sampled with a 0.0125 rad maximum joint increment. It has no initial self collisions. A separate geometric witness establishes existence of a feasible route but never initializes, restarts or supplies the output of the optimizer. Task 4 disables orientation costs and projection while retaining world/self-collision treatment.

## Task 5: upright direction and feasibility

Let y(q)=R(q)e_y be the tool y-axis expressed in the world frame, with target e_z=[0,0,1]^T. The direction error is acos(clamp(y(q)^T e_z,-1,1)). Rotation about this axis remains free. The orientation objective is lambda times the sum of ||y(q_t)-e_z||_1, weighted by normalized path spacing. The frozen projected configuration uses lambda=1000.

Penalty-only development did not meet the predefined acceptance target within the allocated tuning budget, so the implementation adds a deterministic damped Jacobian projection. For each internal waypoint, the direction Jacobian has columns omega_i cross y for revolute joints. The correction is J_y^T (J_y J_y^T+mu²I)^(-1)(e_z-y), with mu=0.001, at most 20 corrections, a 0.15 rad component step cap and a 1° internal tolerance. A deterministic orthogonal axis handles nearly antipodal directions. Endpoints remain unchanged and limits apply after correction. Projection failures receive no acceptance probability. Probabilities and updates use the actual corrected perturbations.

Projection alone can introduce self collisions. The earlier V1 projected formal group had 0/20 successes despite meeting its tilt and external-clearance checks. V2 therefore added enclosing-capsule self-collision costs, actual self-collision rejection during candidate acceptance, feasibility-first incumbent handling and separated restart streams. Those mechanisms remain active in V3. They do not replace final mesh checks.

Acceptance requires exact endpoints, limits, at least 35 mm conservative voxel/sphere clearance, no unpermitted actual world collisions, no actual self collisions and a tool above the table. Task 5 additionally requires maximum tilt ≤5°. The 35 mm and 5° thresholds are our declared engineering criteria. Final successful paths receive an additional check with joint increments ≤0.00625 rad. All statements concern discrete geometric validation.

## Frozen paired evaluation

V3 uses 61 waypoints, 64 rollouts, 0.55 rad noise, at most 200 iterations per restart, up to three restarts and a 300 s planning target including trace writes. Time limits apply between iterations. Development seeds are 5300–5302. After freezing parameters, seeds 5400–5419 evaluate 20 paired conditions. The base settings, scene, endpoints, initialization and seed match across Task 4 and Task 5. Direction projection changes the realized paths and perturbations.

| Condition | Success | Median planner time (s) | Worst fine tilt (deg) | Minimum fine proxy gap (mm) | Minimum fine tool height (mm) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Task 4 | 20/20 | 30.42 | 169.591 | 35.41 | 273.1 |
| Task 5 | 20/20 | 68.19 | 0.997 | 35.23 | 280.9 |

Every formal run enters the success denominator. The extrema above use the extra fine checks. The median paired time difference, Task 5 minus Task 4, is 37.19 s. Two workers share the machine and timings include writes, so they describe this execution setup. Differently weighted primary objectives are not compared as a performance measure. The independent audit reconstructs geometry, checks 40 final paths and replays 804 optimizer checkpoints. Two development demonstrations replay another 20 checkpoints. An independent NumPy PoE calculation matches tool positions and directions over 46,798 fine states, but is not an independent collision engine.

For 20 successes in 20 independent Bernoulli trials in one fixed scene, the exact two-sided 95% binomial lower bound is 83.16%. This observation does not establish universal reliability.

## V4: feasible refinement and tangent sampling

V4 separates first-feasible search from quality improvement. Refinement accepts a candidate only when it satisfies all unchanged dense gates and reduces the common secondary score Q = L_q + 5S + 5000/(N−1) sum_t max(0,0.045−g_t)². Here L_q is joint path length, S is half the summed squared second difference, and g_t is node proxy clearance in metres. The 45 mm preference is soft, whereas 35 mm remains a hard threshold. Refinement uses at most 20 iterations and a 45 s target inside the overall planning budget. It preserves or improves its own feasible incumbent.

Tangent sampling projects a Gaussian perturbation with P=I−BB^T, where B contains the significant right singular vectors of J_y. The default mixture uses 75% tangent and 25% ambient antithetic samples, followed by the same nonlinear direction correction. A fixed 10-seed four-arm evaluation isolates baseline, refinement, tangent sampling and their combination. All four arms already have Task 5 upright constraints.

| Arm | Success | Median total planning time (s) | Median final Q among successes |
| --- | ---: | ---: | ---: |
| baseline | 10/10 | 49.96 | 10.15 |
| anytime | 10/10 | 94.94 | 9.88 |
| tangent | 10/10 | 39.88 | 9.76 |
| combined | 10/10 | 89.12 | 9.39 |

Baseline-to-combined paired Q reduction has median 15.36%, with seven wins and three losses. The paired total-time increase has median 37.77 s. Refinement improves its own score by median 3.60% for anytime and 3.71% for combined. Tangent sampling reduces projection corrections per sampled waypoint by paired median 75.15%, while changing both direction and magnitude. These results do not show unconditional speed or quality gains. All 40 paths and 1,365 checkpoints receive independent audits.

## V5: energy control and adaptive ablation

V5 adds new endpoint and obstacle-layout cases alongside the mounted workcell. Five reserved seeds per case compare ambient, input-energy control, fixed50, fixed75 and adaptive sampling: 75 formal runs. Every arm retains the same feasibility rules and feasible refinement. Adaptive primary search changes the tangent fraction between 25% and 75% using smoothed best-quartile rollout-cost feedback. Its refinement stays fixed50, making fixed50 the direct feedback-disabled control.

| Arm | Fine success | Median total planning time (s), all runs | Median Q, successes |
| --- | ---: | ---: | ---: |
| ambient | 14/15 | 103.57 | 8.64 |
| energy_control | 15/15 | 92.94 | 8.78 |
| fixed50 | 14/15 | 151.12 | 9.04 |
| fixed75 | 15/15 | 90.80 | 9.03 |
| adaptive | 13/15 | 98.86 | 8.39 |

Four retained failures miss the 35 mm conservative threshold, with minimum gaps 30.13, 30.42, 34.22 and 33.53 mm. Their maximum tilt stays below 1°. The adaptive controller ranks soft objective values rather than dense feasibility. That mismatch is a plausible mechanism, not a causal conclusion established by this experiment. Conditional on common success, adaptive reduces final Q relative to fixed75 by paired median 4.60% (n=13), but loses two successful cases. Adaptive is therefore retained as experimental, and fixed75 remains the comparison baseline. Five seeds per case do not establish a universal ranking.

The input-energy control matches scalar perturbation norm after limits and before nonlinear projection. It does not match covariance or post-projection variance. Thirty fixed-state paired batches reuse five innovation streams over six central paths. Fixed75 reduces projection corrections relative to this control by paired median 68.04%. This demonstrates less projection work in those probes, not a guaranteed planning gain. In formal planning, the fixed75-versus-energy-control paired Q reduction is −0.31% (n=15), with seven wins and eight losses.

The formal audit verifies 75 paths and replays 3,005 sampling/update checkpoints. All 71 successful paths pass the finer check. High-score feasible paths are retained, including one with Q=88.96 and a maximum adjacent joint change of 2.537 rad. Without execution timing, that change is not a measured velocity or acceleration.

## Limitations and next work

The results cover specified geometric scenes and finite random seeds. Validation is discrete rather than a continuous collision proof. The model does not include a cup or payload mesh, liquid dynamics, torque, time parameterization or hardware execution. Shared-machine timings include trace I/O. V4/V5 alter search strategies and sample sets, preventing causal cross-version speed claims.

For the course submission, the implementation and experiments are sufficient to demonstrate Tasks 4–5 and justified extensions. Further algorithm development is deferred while the group integrates its report, individual contributions and approximately seven-minute presentation. Future research could prioritize feasibility-aware feedback, local repair near low-clearance segments and joint-branch handling before expanding physical execution claims.

## Evidence sources

Project requirements: EE5112_Project-2_AY26-27.pdf, pp. 1–3. Implementation and teammate handoff: docs/METHODS.md and docs/HANDOFF_MEMBER_C.md. Frozen results: docs/TASK45_V3_RESULTS.md, docs/TASK45_V4_RESULTS.md and docs/TASK45_V5_RESULTS.md, with their versioned JSON, CSV, audit and checksum files. Figures and videos in this bundle derive from the saved V3 development seed 5300. Base repository commit: fea847b684e1c777fe9715a13a9a6fae08f2919c.
