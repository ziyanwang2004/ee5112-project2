# V4 algorithm results

All 40 reserved-seed runs and all failures are included.

| Arm | Success | Median total planner time (s) | Median first feasible time, successes (s) | Median final quality, successes | Median within-run quality reduction (%) |
| --- | ---: | ---: | ---: | ---: | ---: |
| baseline | 10/10 | 49.96 | 49.62 | 10.15 | 0.00 |
| anytime | 10/10 | 94.94 | 48.47 | 9.88 | 3.60 |
| tangent | 10/10 | 39.88 | 39.54 | 9.76 | 0.00 |
| combined | 10/10 | 89.12 | 41.00 | 9.39 | 3.71 |

Separate development audit: 10/12 runs succeeded. Development failures were retained:

- anytime, seed_5501: proxy_margin.
- baseline, seed_5501: proxy_margin.

## Finer acceptance check

| Arm | Lowest conservative clearance (mm) | Largest tilt (deg) | Lowest tool height (mm) |
| --- | ---: | ---: | ---: |
| baseline | 35.57 | 1.43 | 194.97 |
| anytime | 35.35 | 1.50 | 178.34 |
| tangent | 35.14 | 0.93 | 252.83 |
| combined | 36.08 | 0.85 | 240.32 |

Secondary score = joint length + 5*smoothness + soft 45 mm clearance preference. Lower score is better only under this shared definition. It is distinct from the primary search objective.

Quality summaries use successful runs and comparisons below use common successful seeds only.

- baseline -> anytime: n=10; median paired quality reduction 3.60% (B wins/ties/losses 10/0/0); median paired total-time difference 45.94 s.
- baseline -> tangent: n=10; median paired quality reduction 8.44% (B wins/ties/losses 7/0/3); median paired total-time difference -10.80 s.
- tangent -> combined: n=10; median paired quality reduction 3.71% (B wins/ties/losses 10/0/0); median paired total-time difference 47.76 s.
- anytime -> combined: n=10; median paired quality reduction 10.97% (B wins/ties/losses 6/0/4); median paired total-time difference -6.87 s.
- baseline -> combined: n=10; median paired quality reduction 15.36% (B wins/ties/losses 7/0/3); median paired total-time difference 37.77 s.

## Refinement components

- anytime: within-run median joint-length reduction 3.73%; smoothness reduction 0.32%. Negative means an increase; components can trade off under the fixed score.
- combined: within-run median joint-length reduction 4.10%; smoothness reduction 0.34%. Negative means an increase; components can trade off under the fixed score.

## Tangent sampling diagnostics

| Arm | Median correction steps / sampled waypoint | Median actual disturbance RMS (rad) |
| --- | ---: | ---: |
| baseline | 2.50 | 0.33 |
| anytime | 2.50 | 0.33 |
| tangent | 0.63 | 0.31 |
| combined | 0.63 | 0.31 |

baseline -> tangent: n=10; median paired reduction in correction steps per sampled waypoint 75.15%.

anytime -> combined: n=10; median paired reduction in correction steps per sampled waypoint 75.15%.

## Cases where combined has a higher score than baseline

| Seed | Score increase (%) | Joint-length contribution | 5*smoothness contribution | Clearance contribution |
| --- | ---: | ---: | ---: | ---: |
| 5600 | 17.02 | 1.1030 | 0.2507 | -0.0024 |
| 5606 | 2.15 | -0.1500 | 0.3593 | -0.0071 |
| 5609 | 1.19 | 0.2177 | -0.1099 | 0.0037 |

Tangent sampling can find a different first feasible path. Refinement guarantees improvement relative to its own incumbent; it does not guarantee beating the ambient-search baseline. The component differences above explain the score increase without discarding these seeds.

The four arms isolate refinement and tangent sampling. Refinement is additional computation within the same 300 s target, with a 45 s refinement target and at most 20 iterations. Budgets are checked between iterations, so a final iteration can overrun the time target. The 0.10 rad update cap applies before nonlinear orientation correction. Compare first-feasible time separately from total time. Every accepted refinement improves its own incumbent score and passes unchanged dense validation. No universal speed, optimality or reliability claim is made.

Tangent mapping changes effective disturbance magnitude as well as direction. Actual disturbances are retained and summarized; this four-arm study has no additional variance-matched ambient ablation.

Independent audit: 40 paths, 1365 search/refinement checkpoints; finer final validation at 0.00625 rad.

Independent NumPy checks additionally reproduce tool tilt, tool-path length and minimum height at every saved nominal dense state. They do not independently check mesh collision.

[Protocol](TASK45_V4_PROTOCOL.md). V1/V2/V3 source and evidence remain preserved.
