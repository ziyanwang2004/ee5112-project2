# V5: adaptive STOMP sampling and input-energy ablation

Experimental comparison of five sampling strategies on three mounted-workcell cases. V1-V4 remain frozen.


Formal fine successes: adaptive 13/15; fixed75 15/15; energy control 15/15. Read per-case outcomes and conditional paired comparisons before choosing a strategy. V5 is an experimental study, not an automatic replacement for the established course demonstration.

[Results](docs/TASK45_V5_RESULTS.md) | [Protocol](docs/TASK45_V5_PROTOCOL.md) | [Chinese method explanation](docs/TASK45_V5_METHODS_ZH.md)

All five benchmark arms are Task 5 strategies with the upright constraint enabled. The course Task 4-versus-Task 5 unconstrained/constrained demonstration remains in [V3](README_TASK45_V3.md); use `show_project_demo('all','v3')` from scripts.

From the repository root:

```matlab
addpath('scripts')
show_task45_v5('benchmark')
show_task45_v5('energy')
show_task45_v5('demo')
```

Fresh planning in a fresh MATLAB R2023b session:

```matlab
addpath('scripts')
newRunRoot = fullfile(pwd,'artifacts','local_runs','my_v5_run');
r = run_task45_v5('task5','endpoints','adaptive',5700,newRunRoot);
audit = verify_task45_v5(newRunRoot);
```

Shipped development demonstrations contain complete replay inputs. Formal raw input/iteration/refinement archives remain local; formal trajectories, dense profiles, frozen settings and audit receipts are in Git.

Full saved sampling/update replay of the two shipped demonstrations:

```matlab
audit = verify_task45_v5(fullfile(pwd,'artifacts','runs','task45_v5','demos'));
```

Fresh final-path validation of the compact Git formal results, without raw rollout files:

```matlab
addpath('scripts')
audit = verify_task45_v5_paths(fullfile(pwd,'artifacts','runs','task45_v5','formal'));
```

This reconstructs geometry and checks nominal/finer path acceptance. Full random-sample/update replay is separate and uses the shipped demonstrations or the complete local raw archive.

`py -3.12 scripts/verify_task45_v5_manifest.py` verifies the Git inventory. Add `--full` only with the complete local raw archive.

Wall-clock stopping can change fresh iteration counts across machines. Replay checks saved RNG and actual projected perturbations. Energy matching is before nonlinear projection, not post-projection variance matching.
