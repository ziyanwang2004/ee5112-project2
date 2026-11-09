# V3: mounted UR5 workcell

The separate third scenario adds a real installation plane and a forbidden
sub-table volume, and uses a new upright endpoint pair. The UR5 is mounted
0.20 m above the z=0 table on a fixed pedestal. Only the pedestal/table
contact pair is allowed. Every UR5 link and the tool remain subject to the
original 35 mm proxy clearance, actual collision and self-collision gates.

Protocol: `../../docs/TASK45_V3_PROTOCOL.md`. The geometric witness is a
feasibility proof only. It is not supplied to the optimizer.

Use fresh MATLAB R2023b processes when switching between the V1/V2/V3 source
trees. Do not use `addpath(genpath(repo))`, because historical snapshots have
the same function names.

From the repository root:

```matlab
addpath('scripts')
r = run_task45_v3('all',5300,'D:\new_empty_v3_output');
audit = verify_task45_v3('D:\new_empty_v3_output');
```

For the saved five-task demonstration, use:

```matlab
addpath('scripts')
show_project_demo('all','v3')
```

The saved-demo command is available after formal auditing and export finish.
`show_project_demo('all','v2')` remains available throughout development.

The copied legacy V1 orchestration (`run_task45`, `develop_task45`,
`run_task45_benchmark`) is retained as source history. The public V3 entries
are the explicitly named `_v3` scripts above.
