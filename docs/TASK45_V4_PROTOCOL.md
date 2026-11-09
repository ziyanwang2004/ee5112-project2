# V4 algorithm evaluation protocol

V3 remains frozen. V4 implements two independent changes on the same mounted
workcell and endpoints: feasible-path quality refinement and tangent-aware
sampling. This study does not add a scene or relax acceptance.

Four Task 5 arms form a 2 x 2 comparison: `baseline` (V3 search), `anytime`
(Euclidean search plus refinement), `tangent` (mixed tangent search, first
feasible stop), and `combined` (both). Tangent sampling uses the same Gaussian
draws as baseline; 75% of antithetic pairs are mapped through the direction
Jacobian null space and 25% retain ambient exploration. All samples and
candidate updates still undergo nonlinear orientation projection and limits.
Task 4 ignores tangent mapping because it has no direction constraint.

Primary search retains the V3 settings and objective: 61 nodes, 64 rollouts,
noise 0.55 rad, 200 iterations/restart, 3 restarts, lambda=1000 for Task 5,
and the 300 s planning target including trace writes. Limit checks occur
between iterations; small final-iteration overruns are recorded.

Anytime refinement starts only from a fully validated feasible incumbent.
It uses at most 20 iterations, 32 rollouts, noise 0.10 rad, maximum component
update 0.10 rad, and at most 45 s within the shared 300 s total target.
Every accepted refinement must strictly improve the fixed secondary score
and pass the unchanged dense validator. Rejected proposals cannot overwrite
the incumbent. The secondary score is joint path length + 5 times the
second-difference smoothness + 5000 times the normalized squared deficit
below a 45 mm proxy-clearance preference. The hard proxy threshold stays
35 mm. All three components and the ordinary search objective are saved
separately; scores from the two optimization phases are not interchangeable.

Development seeds: 5500-5502. Formal seeds reserved until freeze: 5600-5609,
four Task 5 arms per seed (40 runs). One known Task 4/5 seed 5300 additionally
checks baseline compatibility with archived V3, and Task 4 refinement is
checked separately. Code/parameters may be repaired during development;
formal failures are retained and no holdout-driven tuning is permitted.
The freeze gate requires the combined arm to pass at least 2/3 development
seeds, baseline compatibility to pass, no loss of an existing feasible
incumbent during refinement, and at least one common successful demo seed.
Baseline failures are valid comparison outcomes, not grounds to remove a
seed or require every arm to achieve the combined arm's success rate.

Report success, first-feasible and total planner time, joint/tool length,
smoothness, clearance, maximum tilt, refinement acceptance and projection
statistics. Paired quality comparisons use common successful seeds, with n
shown. First and final feasible paths receive independent dense validation;
all successful final paths get the extra 0.00625 rad check. Replay includes
raw RNG, mixed tangent disturbances, projection, probability/update and both
phase acceptance chains. Preserve V1/V2/V3 complete-release manifests.
