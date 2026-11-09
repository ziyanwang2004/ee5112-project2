# Task 4-5 V2 results

V1 remains frozen at `artifacts/runs/task45_final/`. V2 is a separate study.

V2 uses new formal seeds 5200-5209. All 50 completed cases, including failures, enter statistics.

| Scene / mode | Success | Median planner time (s) | Median max tilt, successes (deg) | Median gap, successes (mm) |
| --- | ---: | ---: | ---: | ---: |
| main / Task 4 | 10/10 | 30.53 | 126.55 | 45.73 |
| main / Task 5 | 10/10 | 52.46 | 0.93 | 49.17 |
| main / penalty only | 0/10 | 301.48 | - | - |
| variant / Task 4 | 10/10 | 29.83 | 134.52 | 50.26 |
| variant / Task 5 | 10/10 | 48.44 | 0.95 | 63.05 |

Projected Task 5: 20/20 full success, 20/20 upright, 0/20 self-collision failures.

## Method and validation

Both conditions use the same self-collision penalty and in-loop actual mesh rejection. Task 5 adds the orientation penalty and PoE direction projection. The final acceptance conditions remain unchanged.

The added costs are `J_self = 60000 sum_t sum_(i,j) max(0, tau_ij - d_ij(q_t))^2 Delta s` and `J_ori = 1000 sum_t ||R(q_t)e_y - e_z||_1 Delta s`. Here d is the enclosing-capsule gap, and tau is min(0.005 m, d(qStart), d(qGoal)) for each non-parent pair. The projector uses a 1 degree internal target, damping 1e-3, at most 20 steps per waypoint and a 0.15 rad component step cap.

The 300 s planner target is checked between iterations and includes trace writes. A final iteration can extend past the target. Actual elapsed times, including these small overruns, enter the statistics.

The capsule target for a body pair is the smaller of 5 mm and its two fixed-endpoint capsule gaps. Some enclosing capsules overlap at actual collision-free endpoints. This soft target prevents impossible proxy targets and never relaxes actual mesh checks.

Restart seeds use seed + 100000*(restart-1). The selected nominal seed ranges do not reuse the same restart seed. Two local MATLAB worker processes divide the fixed seeds by parity. No significance test or cross-version speed claim is made.

Independent audit: 50 formal runs, 1991 replayed checkpoints, 256 independently recomputed costs.

Source fingerprint: `cfb2c25020cbda97ca72310b4dc253f10bbffa3137f1a99d4448fefb68ff857d`. Base commit: `9490df569bc1b16b4d1c7e3c6ef8d375a153251c`. The fingerprint identifies the uncommitted source used for this study.

## Paired results

main: n=10 common successful seeds [5200, 5201, 5202, 5203, 5204, 5205, 5206, 5207, 5208, 5209]. Median paired time difference B minus A: 19.03 s. Median max tilt A/B: 126.55/0.93 deg.
variant: n=10 common successful seeds [5200, 5201, 5202, 5203, 5204, 5205, 5206, 5207, 5208, 5209]. Median paired time difference B minus A: 19.04 s. Median max tilt A/B: 134.52/0.95 deg.

## Failures

- main_none: none.
- main_projected: none.
- main_penalty: proxy_margin=1, orientation=10.
- variant_none: none.
- variant_projected: none.

Failure labels may overlap. Quality comparisons use common successful seeds only. Different weighted objective totals are not a performance comparison.

## Evidence and scope

The incomplete capsule-only development pilot is retained with a cancellation receipt and source snapshot. It was abandoned before freezing and is excluded from the fresh formal study. Every completed formal failure remains in the denominator.

V1 failure causes and representative body pairs: `docs/TASK5_V1_FAILURE_ANALYSIS.md`. V2 frozen parameters and exact driver hashes: `artifacts/runs/task45_v2/frozen_config.json`.

Checks are discrete interpolated collision checks at a per-joint step of 0.0125 rad. There is no continuous collision guarantee, payload, dynamics model or physical timing model. Animations use normalized path progress.

Reproduce individual runs with `addpath scripts; run_task45_v2(...)`; revalidate read-only with `verify_task45_v2(runRoot)`. The preserved source snapshot and complete raw inputs, random states, actual projected disturbances and accepted updates are under the V2 release directory.
