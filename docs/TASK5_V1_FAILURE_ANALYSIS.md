# Task 5 V1 failure diagnosis and V2 development

V1 is preserved at `artifacts/runs/task45_final/`. Its formal projected
Task 5 result is **0/20**, whereas Task 4 is **20/20**. This is an actual
planning failure, not a report-generation error.

## What failed

All 20 projected Task 5 paths pass the orientation requirement: their maximum
direction errors range from **0.462354 to 0.962676 degrees**, below 5 degrees.
Their minimum conservative world clearances range from **38.3377 to 69.1783 mm**,
above 35 mm. They also pass endpoint, joint-limit and actual world-collision
checks. **Every path fails the independent self-collision check.**

`scripts/diagnose_task5_v1.m` rechecks up to three representative colliding
states in each failed path using MATLAB R2023b's loaded collision geometry,
`Exhaustive='on'` and `SkippedSelfCollisions='parent'`. Pair names come from
the NaN entries of the separation matrix, as confirmed by the installed
collision-checker implementation. These samples identify forearm/wrist
collisions in many runs, and also base/upper-arm and shoulder/arm/wrist
collisions in some runs. Sampling these states does not enumerate every pair
over the whole path. The full-path self-collision state counts were already
saved by the original dense validator.

The machine-readable diagnosis is
`artifacts/runs/task45_v2/diagnosis/raw_probe_evidence/v1_collision_diagnosis.json`.
For example, main seed 5120 has **84 colliding states out of 502**; its
representative pair is `forearm_link / wrist_3_link`.

## Causes established from source and saved traces

1. **The optimizer cannot see self-collision.** V1 `matlab/stompTrajCost.m`
   contains world-obstacle, smoothness and orientation costs, with no
   self-collision cost. Self-collision is checked after candidate acceptance
   by `+memberC/validatePath.m` and `+memberB/checkMatlabPath.m`.
2. **Orientation projection has no geometry objective.**
   `+memberC/projectTrajectory.m` solves the direction error using damped
   least squares. A configuration can be perfectly upright while its wrist
   intersects its forearm. Increasing the orientation weight cannot address
   this missing objective.
3. **Candidate acceptance is cost-first.** In `+memberC/plan.m`, proposals
   and individual rollouts replace the current path only if their total
   cost decreases. Dense feasibility is checked only later. Retaining an
   already discovered feasible incumbent does not help a feasible candidate
   discarded before validation.
4. **Restarts react to objective stagnation, not feasibility.** Continued
   decreases of the incomplete cost can consume the planning budget while
   the path remains self-colliding.
5. **The development estimate was weak and correlated.** Three development
   seeds were insufficient evidence of generalization. V1 uses
   `seed + restart - 1`, so neighboring nominal runs reuse restart random
   streams. This explains some repeated trajectories and reduces the
   independence of the nominal trials. It does not invalidate the recorded
   deterministic failures, but success counts should remain descriptive.

## Implemented V2 changes

V2 source is isolated at `upgrades/task45_v2/matlab/`; V1 source and evidence
are not edited. V2 outputs use `artifacts/runs/task45_v2/`.

- Add a self-collision penalty for non-parent body pairs, using capsules
  fitted around each installed collision mesh through the public collision
  visualization API. The capsule cost is a guide; it can conservatively
  overlap where actual meshes are separated. Only the independent actual
  collision checker decides success.
- Apply the new self-collision objective to both Task 4 and Task 5 so a new
  paired comparison uses the same base objective.
- Use disjoint restart seeds `seed + 100000*(restart-1)` for the selected
  experiment seed ranges.
- Reject proposed updates and fallback rollouts that actually self-collide
  at waypoints or a 0.05 rad interpolated mesh check. The final mesh check
  remains at 0.0125 rad. This hard filter operates during optimization.
- Validate promising proposals before cost-only rejection and prefer any
  fully feasible proposal, even if its objective is higher.
- Cap each pair's soft clearance target at the smaller endpoint capsule
  clearance. Some enclosing capsules overlap at the independently verified
  fixed endpoints; the floor prevents these conservative overlaps from
  creating impossible soft targets. Actual mesh acceptance is unchanged.

A preliminary capsule-cost-only pilot was deliberately stopped after its
saved first-restart path still self-collided. Its traces, exact source
snapshot and cancellation receipt remain under
`artifacts/runs/task45_v2/development/capsule_60000/`. It is an abandoned
development pilot, not a completed formal trial. The strengthened pilot is
saved separately under `development/self_filter_60000/`.

World clearance (35 mm), maximum tilt (5 degrees), endpoints, limits, and
final dense joint step (0.0125 rad) remain unchanged. The optimizer still
starts from the colliding straight joint interpolation; no feasible witness
path is used as an initializer or output.

Fresh development seeds are **5150–5152**. Both scenes passed all three
paired development seeds: Task 4 **6/6**, Task 5 **6/6**. Independent
validation and complete random/update replay passed for all 12 paths,
covering **125 optimizer checkpoints**. Task 5 development maximum tilts
range from **0.7942 to 4.5782 degrees** and minimum conservative clearances
from **40.6896 to 65.4987 mm**. These development successes are not included
in formal success rates.

V2 was frozen with source fingerprint
`cfb2c25020cbda97ca72310b4dc253f10bbffa3137f1a99d4448fefb68ff857d`.
New holdout seeds **5200–5209** are used only after that freeze. The failed V1
seeds 5120–5129 may be used only as known regression/stress cases, not as
fresh holdouts. No V2 success rate is claimed before saved paths are
independently revalidated and optimizer updates replayed.

## Fresh formal repair validation

V2 projected Task 5 passes **20/20** fresh formal cases. All 20 cases are retained, including any failures. The upright check passes 20/20 and the self-collision gate fails 0/20.

The independent formal audit covers 50 runs and 1991 fully replayed optimizer checkpoints. Full A/B and ablation counts are in [V2 results](TASK45_V2_RESULTS.md).

![Representative V1 collision and a V2 path state](../artifacts/runs/task45_v2/diagnosis/self_collision_comparison.png)
