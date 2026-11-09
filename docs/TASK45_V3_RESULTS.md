# V3 mounted-workcell results

This is a separate third scene with new upright endpoints. V1 and V2 remain unchanged. All 40 formal runs use reserved seeds 5400-5419; development uses 5300-5302. No holdout retuning or reference-path initialization was used.

| Condition | Success | Median planner time (s) | Worst tilt (deg) | Minimum proxy gap (mm) | Minimum tool height (mm) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Task 4 | 20/20 | 30.42 | 169.591 | 35.41 | 273.1 |
| Task 5 | 20/20 | 68.19 | 0.997 | 35.23 | 280.9 |

The success denominator includes every formal run. Timings include failures if any. Tilt, proxy gap and height above are extrema over successful paths at the extra 0.00625 rad check. There were no failed formal runs in this study.

## Scene and mounting contact

A fixed 0.18 x 0.18 x 0.20 m pedestal raises the UR5 base to world z=0.20 m. The table top is z=0; its forbidden volume spans the full sub-table voxel workspace. A central rack, two equipment boxes and a rear guard define the transfer region. Only the fixed pedestal/table contact is permitted. Every UR5 link and the tool remain subject to world and self-collision checks. The pedestal is included in the actual robot self-collision model and optimization self proxy.

The common straight initialization has 92/181 colliding world states at 0.0125 rad sampling and no self collisions. Both endpoints pass. The geometric existence witness is kept separate and never supplied to the planner.

## Planner and acceptance

Both conditions retain V2 self-collision costs and in-loop actual mesh rejection. Task 5 adds lambda=1000 orientation cost and the PoE direction projector. Tool y must align with world +z; yaw is free. The selected first development profile uses 61 waypoints, 64 rollouts, noise 0.55 rad, 200 iterations per restart, up to 3 restarts and a 300 s target checked between iterations, including trace writes. The last iteration may exceed that target. Two workers split seeds by parity and alternate A/B order. Runtime is descriptive for this execution setup.

Acceptance preserves exact endpoints and joint limits, requires 35 mm conservative UR5 sphere clearance, zero unpermitted actual world collisions, zero actual self collisions and tool above the table. Task 5 additionally requires tilt <=5 degrees. All successful formal paths also pass 0.00625 rad joint-increment validation. This is discrete validation, not a continuous collision proof.

## Pairing and scope

Common successful pairs: n=20. The median paired planner-time difference Task 5 minus Task 4 is 37.19 s. No comparison of differently weighted objective totals is used to claim performance.

For a condition with 20/20 successes, the exact two-sided 95% binomial lower bound is 83.16%, under independent Bernoulli trials in this fixed scene. The paired conditions and earlier scenes are not pooled into a universal reliability estimate.

The earlier V2 scenes lacked a ground obstacle: 7/20 projected formal paths put the tool below base z=0. V3 directly addresses that scene-design limitation with an explicit installation and table. Different endpoints and seeds prevent a causal cross-version speed or quality claim. There is still no payload geometry, dynamics or execution-time model.

## Independent evidence

The formal audit independently reconstructs the robot and scene, checks all 40 final paths and replays 804 optimizer checkpoints. The two demonstrations replay 20 checkpoints. Fine per-state CSV profiles are under `verification/fine_profiles/`. All prior release checksums remain independently checkable.

A separate NumPy Rodrigues/PoE calculation using the original Task 3 screws and a 0.20 m mounting translation matches all 46,798 fine states: maximum tool-position difference 1.70e-15 m and tilt difference 2.00e-13 degrees. This cross-check concerns FK and orientation; it is not another collision checker.

Frozen MATLAB source fingerprint: `706012af20ab4dfda4b995858a25ef723cad55ef39dd648e2d75caed17b2585a`. A Git checkpoint occurred while formal workers were running. Each run preserves its actual commit; `git_checkpoint.json` documents the transition without a MATLAB source or parameter change.

## Reproduction and contribution

From the repository root in a fresh MATLAB session:

```matlab
addpath('scripts')
show_project_demo('all','v3')
% Fresh planning into a new output directory:
r = run_task45_v3('all',5300,newRunRoot);
audit = verify_task45_v3(newRunRoot);
```

Member C adds the new scene, mount model/contact policy, table-height acceptance, held-out paired study, fine validation, replay and delivery materials. The Task 1-3 PoE, sphere envelopes and STOMP stages are reused; the V2 constraint and self-collision mechanism are retained.

[Protocol](TASK45_V3_PROTOCOL.md) | [Report](../artifacts/runs/task45_v3/delivery/task45_v3_report.pdf) | [Slides](../artifacts/runs/task45_v3/delivery/task45_v3_slides.pptx)
