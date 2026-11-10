# Self-aware STOMP upgrade (V2)

This source tree is isolated from the frozen V1 implementation and results.
Read `../../docs/TASK5_V1_FAILURE_ANALYSIS.md` for the evidence and rationale.

The original `../../matlab` tree must remain unchanged. Add **this** `matlab`
folder first on the MATLAB path in a fresh R2023b process before invoking V2
functions. Drivers in `../../scripts` use explicit absolute paths.

Single-run and read-only verification entries (fresh MATLAB process):

```matlab
addpath('scripts');
r = run_task45_v2('all','all',5150,false,'D:\new_empty_run_root');
audit = verify_task45_v2('D:\new_empty_run_root');
summary = run_task45_v2_benchmark('D:\another_empty_root'); % 50 fresh runs
```

Current development command from the repository root:

```powershell
& 'D:\Program Files\MATLAB\bin\matlab.exe' -batch "run('scripts/test_task45_v2.m'); run('scripts/run_task45_v2_development.m');"
```

The driver refuses to overwrite existing run folders. Completed runs are
skipped on restart; incomplete attempts require an explicitly archived
receipt before a new attempt. All runs start from the original colliding
straight interpolation with the same world/pose acceptance requirements.

The new self penalty and actual self-collision rejection apply to both
Task 4 and Task 5. Task 5 additionally uses the unchanged direction
projection and orientation weight of 1000. The original V1 formal seeds
are known failure cases, not new holdout data.

Use the public entries in `scripts` whose names contain `_v2`. The copied
V1 `run_task45`, `develop_task45`, and `run_task45_benchmark` files are
compatibility snapshots and do not select the V2 protocol. Use the explicit
V2 scripts and V2 frozen configuration.
