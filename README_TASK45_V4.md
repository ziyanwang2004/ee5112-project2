# Task 4-5 V4: anytime refinement and tangent-aware sampling

V4 implements both algorithm changes in an isolated source tree. V1/V2/V3 remain preserved.

| Variant | Refinement | Tangent mixture | Formal Task 5 success |
| --- | --- | --- | ---: |
| baseline | no | no | 10/10 |
| anytime | yes | no | 10/10 |
| tangent | no | 75% | 10/10 |
| combined | yes | 75% | 10/10 |

Formal seeds are 5600-5609 on the fixed mounted workcell, separate from development 5500-5502. Refinement reduces a fixed secondary score while preserving all feasibility gates. It uses additional computation within the same total target; successful implementation alone does not establish a universal speed or quality improvement.

```matlab
addpath('scripts')
show_task45_v4('combined')
show_task45_v4('anytime')
show_task45_v4('benchmark')
```

Read-only replay of the four shipped demonstrations (fresh MATLAB session):

```matlab
addpath('scripts')
audit = verify_task45_v4(fullfile(pwd,'artifacts','runs','task45_v4','demos'));
```

Fresh planning and complete replay, in a fresh MATLAB R2023b session:

```matlab
addpath('scripts')
newRunRoot = fullfile(pwd,'artifacts','local_runs','my_task45_v4_run');
r = run_task45_v4('task5','combined',5500,newRunRoot);
audit = verify_task45_v4(newRunRoot);
```

[Full results](docs/TASK45_V4_RESULTS.md) | [Protocol](docs/TASK45_V4_PROTOCOL.md) | [Source](upgrades/task45_v4/README.md)

Git handoff verification: `py -3.12 scripts/verify_task45_v4_manifest.py`. Add `--full` only with the complete local raw archive. Formal raw iteration/refinement checkpoints and inputs remain local; the four copied development demonstrations include replay inputs.

The ordinary console RESULT iteration count refers to the primary search. Saved summaries additionally report refinement and total iteration counts. Primary-search objective and secondary quality score are different quantities.

Wall-clock stopping means fresh planning can finish after a different number of iterations on another machine. Archived RNG/checkpoints support replay of the saved run.
