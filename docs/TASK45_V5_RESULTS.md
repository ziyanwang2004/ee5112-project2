# V5 adaptive sampling and energy-control results

All 75 reserved-seed cases are retained. Study success requires nominal success and the independent 0.00625 rad final check.

Q = joint path length + 5*smoothness + the fixed soft 45 mm clearance preference. Lower Q is better under this definition; individual components can trade off. First Q measures the primary-search output before refinement.

| Scenario | Arm | Success | Median total planner time (s), all runs | Median first quality, successes | Median final quality, successes |
| --- | --- | ---: | ---: | ---: | ---: |
| workcell | ambient | 4/5 | 192.92 | 9.42 | 9.07 |
| workcell | energy_control | 5/5 | 105.71 | 9.12 | 8.70 |
| workcell | fixed50 | 5/5 | 151.12 | 9.67 | 9.39 |
| workcell | fixed75 | 5/5 | 90.80 | 9.17 | 8.83 |
| workcell | adaptive | 4/5 | 149.72 | 9.41 | 9.16 |
| endpoints | ambient | 5/5 | 98.03 | 9.13 | 8.81 |
| endpoints | energy_control | 5/5 | 92.24 | 9.09 | 8.67 |
| endpoints | fixed50 | 4/5 | 173.35 | 9.47 | 9.02 |
| endpoints | fixed75 | 5/5 | 86.45 | 9.82 | 9.57 |
| endpoints | adaptive | 4/5 | 98.86 | 9.70 | 9.38 |
| layout | ambient | 5/5 | 89.38 | 8.52 | 8.09 |
| layout | energy_control | 5/5 | 91.83 | 10.11 | 9.70 |
| layout | fixed50 | 5/5 | 102.86 | 8.81 | 8.38 |
| layout | fixed75 | 5/5 | 98.70 | 8.61 | 8.20 |
| layout | adaptive | 5/5 | 97.73 | 8.18 | 7.79 |

## Overall trade-off

These are descriptive counts over three cases with five seeds each. Quality is conditional on success.

| Arm | Fine success | Median total time (s), all cases | Median final Q, successes |
| --- | ---: | ---: | ---: |
| ambient | 14/15 | 103.57 | 8.64 |
| energy_control | 15/15 | 92.94 | 8.78 |
| fixed50 | 14/15 | 151.12 | 9.04 |
| fixed75 | 15/15 | 90.80 | 9.03 |
| adaptive | 13/15 | 98.86 | 8.39 |

## Finer acceptance of successful paths

| Arm | Lowest conservative gap (mm) | Largest tilt (deg) | Lowest tool height (mm) |
| --- | ---: | ---: | ---: |
| ambient | 35.92 | 2.577 | 280.16 |
| energy_control | 36.70 | 1.946 | 204.61 |
| fixed50 | 35.05 | 2.334 | 253.23 |
| fixed75 | 35.02 | 1.440 | 158.88 |
| adaptive | 36.01 | 0.950 | 282.12 |

All 71 successful final paths pass the actual world/self-collision checks at 0.00625 rad joint increments. These remain discrete checks, not a continuous or physical execution guarantee.

The adaptive strategy is not promoted as the default: it has fewer fine successes than fixed75 in this study. Conditional quality gains cannot compensate for missing paths without an explicit application trade-off. Keep fixed75 as the established comparison baseline and retain adaptive as an experimental option. This small study does not prove a universal reliability ranking.

## Retained formal failures

- endpoints / adaptive / seed 5801: proxy_margin; planner time 301.49 s; fine gap 33.53 mm; tilt 0.858 deg.
  Applied mean tangent fraction 0.448, with 41 changes between consecutive iterations within restarts.
- endpoints / fixed50 / seed 5800: proxy_margin; planner time 277.87 s; fine gap 34.22 mm; tilt 0.083 deg.
- workcell / adaptive / seed 5801: proxy_margin; planner time 282.90 s; fine gap 30.42 mm; tilt 0.511 deg.
  Applied mean tangent fraction 0.573, with 32 changes between consecutive iterations within restarts.
- workcell / ambient / seed 5800: proxy_margin; planner time 302.91 s; fine gap 30.13 mm; tilt 0.152 deg.

The feedback controller ranks rollout objective values, not final dense feasibility. A lower soft objective does not ensure crossing the hard 35 mm threshold. This is a mechanism-level limitation and a possible explanation for the adaptive failures, not a demonstrated causal attribution from this study.

## Highest-score successful paths

The five largest final Q values among successful paths are retained below, including long or rough feasible paths.

| Scenario / arm / seed | First Q | Final Q | Joint length (rad) | Smoothness |
| --- | ---: | ---: | ---: | ---: |
| workcell / fixed50 / 5800 | 97.09 | 88.96 | 18.17 | 14.16 |
| layout / fixed50 / 5800 | 30.76 | 30.62 | 12.54 | 3.62 |
| endpoints / ambient / 5802 | 20.90 | 19.53 | 13.37 | 1.23 |
| layout / ambient / 5802 | 14.40 | 14.06 | 10.41 | 0.73 |
| endpoints / adaptive / 5800 | 13.74 | 13.43 | 10.63 | 0.56 |

The largest-score successful path has a maximum adjacent waypoint change of 2.537 rad. Joint 5 contributes 85.7% of its second-difference smoothness term. This motivates local path repair or additional search as future work. It is not a measured speed or acceleration, since no execution timing is modeled.

Separate development study: 28/30 fine successes. Retained development failures:

- workcell / ambient / seed 5701: proxy_margin.
- workcell / fixed75 / seed 5701: proxy_margin.

## Paired contrasts

Positive percentages mean the second arm has a lower fixed secondary score. Only common successful case/seed pairs enter quality comparisons.

| Scenario | Contrast | n | Median first-score reduction (%) | Median final-score reduction (%) | Final wins/ties/losses |
| --- | --- | ---: | ---: | ---: | --- |
| workcell | ambient to fixed75 | 4 | 0.34 | -0.64 | 2/0/2 |
| workcell | energy_control to fixed75 | 5 | -0.58 | -0.31 | 2/0/3 |
| workcell | fixed50 to adaptive | 4 | 11.75 | 12.48 | 3/0/1 |
| workcell | fixed75 to adaptive | 4 | 7.70 | 7.97 | 3/0/1 |
| endpoints | ambient to fixed75 | 5 | -3.36 | -3.12 | 2/0/3 |
| endpoints | energy_control to fixed75 | 5 | -7.63 | -7.09 | 1/0/4 |
| endpoints | fixed50 to adaptive | 3 | -6.23 | -8.42 | 1/0/2 |
| endpoints | fixed75 to adaptive | 4 | 2.53 | 2.38 | 2/0/2 |
| layout | ambient to fixed75 | 5 | -0.23 | 1.51 | 3/0/2 |
| layout | energy_control to fixed75 | 5 | 11.68 | 10.19 | 4/0/1 |
| layout | fixed50 to adaptive | 5 | 0.74 | 1.07 | 3/0/2 |
| layout | fixed75 to adaptive | 5 | 3.49 | 2.83 | 4/0/1 |
| all_cases | ambient to fixed75 | 14 | -1.27 | -0.80 | 7/0/7 |
| all_cases | energy_control to fixed75 | 15 | -0.58 | -0.31 | 7/0/8 |
| all_cases | fixed50 to adaptive | 12 | 4.62 | 4.68 | 7/0/5 |
| all_cases | fixed75 to adaptive | 13 | 5.02 | 4.60 | 9/0/4 |

## Matched-input-energy diagnostic

Thirty fixed-state paired batches / 90 sampler calls. Maximum absolute pre-projection energy mismatch: 3.55e-14 rad^2.

| Sampler | Median pre-projection RMS (rad) | Median post-projection RMS (rad) | Median corrections / sampled waypoint |
| --- | ---: | ---: | ---: |
| ambient | 0.3761 | 0.3417 | 2.6578 |
| energy_control | 0.3371 | 0.3051 | 2.3019 |
| fixed75 | 0.3371 | 0.3273 | 0.7119 |

Fixed75 vs energy control: median paired projection-correction reduction 68.04% (n=30).

The same five Gaussian innovation streams are reused across six central paths. The 30 paired batches are not 30 independent seeds, and overlapping plotted values are expected. These upright central paths share similar direction-constraint structure, limiting generalization to arbitrary central orientations.

This control matches scalar squared norm after limits and before nonlinear projection. It does not match covariance or post-projection variance. The probes use linear and geometric-witness central paths solely for sampling diagnostics. Neither witness nor probe output initializes the planner.

## Controller and interpretation

- workcell: median mean search fraction 0.57; median fraction changes 5.00.
- endpoints: median mean search fraction 0.56; median fraction changes 3.00.
- layout: median mean search fraction 0.63; median fraction changes 5.00.

Adaptive vs fixed50 isolates primary-search feedback; both refine at fixed50. Fixed75 vs energy control contrasts directions at matched input energy. All arms use the same primary objective, safety gates and refinement score.

Refinement is guaranteed to improve its own feasible incumbent, not another sampler's first path. Both first and final scores are reported. Runtime includes writes and is descriptive for shared two-worker execution; the energy control includes counterfactual-projector work.

No V4 formal seeds were reused for tuning. Five seeds per case are a small sample. No cross-version causal speed/quality claim or continuous collision guarantee is made.

Independent formal audit: 75 paths, 3005 sampling/update checkpoints, final step 0.00625 rad.

[Protocol](TASK45_V5_PROTOCOL.md). All prior releases remain preserved.
