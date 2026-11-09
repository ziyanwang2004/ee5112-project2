# Task 4-5 results

Frozen mode: **projected**, lambda 1000, noise 0.55 rad; 61 waypoints, 64 rollouts, 200 iterations per restart, 3 restarts, 300 s planner budget.

Fixed stagnation restart: 10 consecutive rounds with improvement below 1e-7, following at least ten iterations. Diagnostic pilot runs preceding this implementation fix are preserved separately and excluded from formal inference.

Formal study: 50 completed nominal cases, seeds 5120-5129. All completed planning failures are included in denominators. Runtime summaries include completed failures; quality summaries include successful runs only.

| Scene / mode | Success | Planner median (s) | Successful max-tilt median (deg) | Successful min-clearance median (mm) |
| --- | ---: | ---: | ---: | ---: |
| main_none | 10/10 | 9.45 | 108.37 | 48.35 |
| main_projected | 0/10 | 149.18 | - | - |
| variant_none | 10/10 | 8.58 | 117.24 | 49.85 |
| variant_projected | 0/10 | 140.08 | - | - |
| main_penalty | 0/10 | 276.21 | - | - |

### Technical interruption accounting

The table covers 50 completed nominal cases, including all completed planning failures. An additional 1 interrupted technical attempt is archived, giving 51 observed attempts. Complete-case full success is 20/50; observed full-output success across all attempts is 20/51. The interrupted attempt had no final output and is not classified as a proven optimizer failure.

The interruption occurred during main-scene penalty ablation, seed 5122. Its 288 checkpoint files were preserved with hashes. The same nominal seed was repeated from the original colliding initialization with unchanged frozen parameters. That condition therefore has ten completed cases plus one interrupted attempt; both complete-case and all-attempt denominators are explicit. Runtime statistics use completed cases with measured times; the partial attempt has only a censored lower bound. See `attempt_accounting.json`, `recovery_audit.json`, and `technical_interruptions/`.


## Development selection

These development seeds (5112-5114) are excluded from formal statistics. Counts below are common A/B successes against the selected Task 4 profile.

| Task 5 mode | Weight | Main paired successes | Variant paired successes |
| --- | ---: | ---: | ---: |
| penalty | 200 | 0/3 | 0/3 |
| penalty | 1000 | 0/3 | 0/3 |
| penalty | 5000 | 0/3 | 0/3 |
| penalty | 20000 | 0/3 | 0/3 |
| projected | 1000 | 3/3 | 2/3 |

## Paired comparison

main: n=0 common successful seeds. Paired quality and planning-time comparisons are unavailable.

variant: n=0 common successful seeds. Paired quality and planning-time comparisons are unavailable.

## Demonstrations

| Scene | Task | Seed | Minimum conservative gap (mm) | Minimum mesh gap (mm) | Maximum tilt (deg) | Dense states |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| main | 4 | 5113 | 39.892 | 126.120 | 106.994 | 453 |
| main | 5 | 5113 | 55.674 | 123.439 | 0.528 | 519 |
| variant | 4 | 5113 | 43.327 | 126.529 | 106.994 | 453 |
| variant | 5 | 5113 | 35.338 | 116.675 | 0.868 | 573 |

## Failure analysis

Across all 20 constrained formal trajectories, including failures, 20 meet the 5-degree upright check, 20 fail self-collision checks, and 0 pass the complete acceptance gate. Uprightness alone is not planning success.

main_none: 0 failed runs. No failed acceptance gates. Labels can overlap.

main_projected: 10 failed runs. self_collision: 10 Labels can overlap.

variant_none: 0 failed runs. No failed acceptance gates. Labels can overlap.

variant_projected: 10 failed runs. self_collision: 10 Labels can overlap.

main_penalty: 10 failed runs. proxy_margin: 6, orientation: 10, self_collision: 10 Labels can overlap.

Success requires all acceptance gates, irrespective of objective reduction. The saved failed trajectory is retained for diagnosis. Optimizer stagnation, finite random exploration, and the difference between waypoint costs and dense path checks can prevent success within the budget. The recorded labels identify violated checks; they do not by themselves prove an optimizer failure mechanism.

Self collision is an acceptance gate but has no explicit penalty in the reused objective. Consequently, low obstacle/smoothness cost can coexist with a self collision. Restarts can explore another branch; acceptance thresholds are unchanged.

## Validation and interpretation

The independent read-only audit recomputed acceptance for 54 saved runs and replayed 5492 iteration checkpoints. All audit checks passed. A correctly recorded unsuccessful experiment passes the integrity audit while remaining a planning failure.

Paths were checked with at most .0125 rad change in any joint between dense states. This is discrete verification. The tool-y direction represents uprightness; no grasped payload, dynamics, physical trajectory timing, or continuous collision certificate is included. Ten formal seeds per scene provide a limited empirical sample. Different orientation-weighted objective totals are not a valid cross-condition performance comparison.

The inherited restart convention uses nominal seed + restart - 1. Adjacent nominal runs can reuse random streams and are not guaranteed statistically independent. Results are descriptive; no significance tests or independence-based confidence intervals are claimed.

The common robot, scenes, endpoints, initialization, sampling settings and budgets were frozen before formal seeds were used. The constraint mechanism is the A/B intervention. Projection, when selected, changes the samples after the same raw random draws and adds computation; equal seeds do not imply identical realized disturbances or equal work per iteration.

## Contribution and evidence

Member C implemented Task 4-5 scenes, axis-direction cost and optional PoE projection, the unified acceptance hook, independent validator/replay, paired experiment drivers, and integration figures, animations, report and slides. The PoE model, conservative robot envelopes and original STOMP stages are reused from the Task 1-3 handoff.

See [method](TASK45_METHODS.md) and [reproduction commands](TASK45_RUNBOOK.md). Raw formal metrics: `../artifacts/runs/task45_final/formal/all_runs.csv`; per-run MAT, JSON and dense validation CSV files are stored alongside each run. Demo media: `../artifacts/runs/task45_final/demos/exports/`. Each row can be traced to scenario, task and seed.

MATLAB source fingerprint: `8a8fa3e036dc4d4c7124efefa9957d61b536b6180a6cfea87cac9d7429dcee23`. Baseline commit: `9490df569bc1b16b4d1c7e3c6ef8d375a153251c`. The fingerprint covers the new uncommitted MATLAB sources.

## Postprocessing correction

After all 50 planning results were saved, an empty common-success set exposed a MATLAB column-vector iteration bug in aggregation. The aggregation loop was corrected and the benchmark guard was updated to accept this exact audited postprocessing fingerprint. Original versions of both files were preserved; the other 69 MATLAB source files are unchanged. No planning parameters or raw results were changed for this repair. The original experimental fingerprint above remains the identity of every saved formal run.

Approved postprocessing fingerprint: `af8bac795e4e8149125c6a3084a83a2514cec55ee95ba715a4181bfed2345977`. See `provenance/postprocessing_patch.json` and `provenance/pre_postprocessing_fix/`.
