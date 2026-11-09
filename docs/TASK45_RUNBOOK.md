# Task 4-5 reproduction

Use **MATLAB R2023b Update 11** on this machine:

```powershell
& 'D:\Program Files\MATLAB\bin\matlab.exe' -batch "addpath('matlab'); addpath('matlab/tests'); test_task45"
```

The terminal command `matlab` can still resolve to R2023a. Use the explicit executable above. Required toolboxes are Robotics System Toolbox and Image Processing Toolbox. New results use new directories; completed results are never silently overwritten.

From the repository root, a single default run is:

```matlab
addpath matlab
r = run_task45('all','main',5112,false);
```

`whichTask` supports `task4`, `task5`, `all`; scenes support `main`, `variant`, `all`. Before freezing this uses the default penalty configuration. Once `artifacts/runs/task45_final/frozen_config.mat` exists, the entry point uses the frozen settings.

Execute the predeclared development protocol, then the formal study:

Development is for a new study directory without an existing frozen `task45_final` output. With the published frozen results already present, use the single-run reproduction and read-only verification commands instead; the development driver refuses to replace a frozen study.

```matlab
frozen = develop_task45;  % separate local development directory
summary = run_task45_benchmark;  % requires a passing frozen configuration
```

To resume completed runs, supply the same development/formal output root. A matching MATLAB source fingerprint is required. An incomplete existing folder is intentionally preserved for diagnosis, rather than overwritten or silently counted as a completed experiment.

Independently verify and export a frozen study:

```matlab
root = fullfile(pwd,'artifacts','runs','task45_final');
audit = verify_task45(root);       % read-only, including failed formal runs
memberC.writeJSON(fullfile(root,'independent_audit.json'),audit);
media = export_task45(fullfile(root,'demos'),true);
```

The exporter accepts one saved Task 4/5 pair per scene, so pass `demos`, not the full root containing all formal seeds. A one-task export creates its individual summary without requiring the other task. Every plot has an editable FIG and PNG. Videos use 150 frames at 15 fps, with normalized path progress.

On this Windows machine, after development has frozen a configuration, the complete sequential delivery pipeline is also available:

```powershell
powershell.exe -NoProfile -File scripts/finish_task45.ps1
```

It archives development summaries and baseline receipts, exports and decodes demonstration media, runs or resumes the formal study, independently verifies every saved run, then builds the English report and four editable English slides with Chinese notes. The report builder requires Python 3.12 with ReportLab, PyMuPDF, Pillow, pywin32, and installed Microsoft PowerPoint. The user explicitly chose PowerPoint COM as the fallback because this environment lacks the presentation skill's artifact-tool runtime. Formal planning runs execute sequentially; media export completes before their timing measurements begin. Failed or interrupted output folders are retained for diagnosis.

The Task 1-3 entry point remains:

```matlab
run_all_tasks('all',false,newBaselineRoot);
addpath matlab/tests
verify_task123(newBaselineRoot);
```

The old verifier writes summaries; use a copy when checking the teammate's frozen archive. The Task 4-5 verifier is read-only by default. Local baseline and development evidence is under ignored `artifacts/local_runs/`; final evidence has its own tracked `artifacts/runs/task45_final/` directory only after the development gate passes.

## Interrupted execution

An incomplete main-scene penalty ablation for seed 5122 was discovered with no active MATLAB process and no final result. Its 288 checkpoint files were moved intact into `technical_interruptions/`, with a per-file hash receipt; the exact interruption cause is unknown. The completed 42 runs were retained. Recovery repeats the same nominal seed from the original colliding initialization and uses the unchanged frozen MATLAB sources and parameters.

`scripts/resume_task45.ps1` resumes complete nominal results, runs remaining cases, then independently verifies the study and replays the interrupted prefix using `scripts/audit_task45_interruption.m`. An incomplete run directory must first be preserved with a receipt; the runner deliberately refuses to overwrite it. Completed planning failures remain in all nominal success denominators. The interrupted attempt is additionally counted in attempt accounting, with its partial time treated as censored. `attempt_accounting.json` reports completed nominal cases and all observed attempts separately.

The published source includes an audited postprocessing repair for zero common-success samples. The planning source identity stored in raw results remains the original frozen identity; `provenance/postprocessing_patch.json` approves the exact updated aggregation/runner fingerprint. The benchmark accepts only these two recorded fingerprints. Original pre-fix files are retained under `provenance/pre_postprocessing_fix/`; other MATLAB source changes are still rejected.
