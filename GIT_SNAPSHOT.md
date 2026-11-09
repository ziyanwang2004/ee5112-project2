# Git checkpoint — 2026-11-09

This branch preserves the Task 4–5 implementation and the completed V2 results while the V3 mounted-workcell study is running. It is a local development checkpoint, not the final group submission package.

## Where to start

- [V2 instructions and results](README_TASK45_V2.md): completed Task 4–5 work.
- [Whole-project demo guide](docs/PROJECT_DEMO_GUIDE_ZH.md): replay Tasks 1–5 without replanning.
- [Whole-project completion audit](docs/PROJECT_COMPLETION_AUDIT_20261109.md): requirements, verification evidence and remaining group integration work.
- [V3 protocol](docs/TASK45_V3_PROTOCOL.md): the additional mounted robot, tabletop, new endpoints and held-out study.

In MATLAB R2023b, from the repository root:

```matlab
addpath('scripts')
show_project_demo('all','v2')
```

The original `README.md` and V1 records remain historical evidence. V2 is the completed improved release: Task 4 passed 20/20 formal runs, projected Task 5 passed 20/20, and the penalty-only ablation passed 0/10. These are results for the recorded scenes and seeds, not a general reliability guarantee. V3 formal results are pending at this checkpoint.

## What this Git checkpoint includes

- Original Task 1–3 tracked files, Task 4–5 MATLAB implementation, separate V2/V3 source trees, scripts and documentation.
- V2 frozen configuration and source snapshot, all saved demonstration inputs/checkpoints/exports, all 50 formal final trajectories, per-run summaries and aggregate results, independent audit receipts, final report, editable slides and Chinese notes.
- V1 historical configuration, aggregate results, audit receipts and final delivery documents.
- V3 frozen configuration, source snapshot, geometry/development audit receipts and experiment protocol. The formal experiment is still running.

## What remains in the full local archive

Large formal per-iteration checkpoints and input checkpoints, V1 demonstration traces, development/pilot archives, interruption records, visual review intermediates, machine-specific audit copies and ongoing V3 results are retained locally and omitted from this checkpoint. No experiment files are deleted. Full raw formal replay requires that archive; the saved V2 demonstration replay data is included here.

`docs/TASK45_FILES_SHA256.csv` and `docs/TASK45_V2_FILES_SHA256.csv` describe the **complete local releases**. Their historical hashes and full-release QA receipts are preserved unchanged. They are not inventories of this smaller Git checkpoint: a fresh checkout will report missing entries if the complete-release manifest checker is run without the omitted archive. Individual included files can still be checked against those manifests.

V3 uses the source fingerprint stored in `artifacts/runs/task45_v3/frozen_config.json` as its executable-source identity. Making this Git checkpoint does not change those frozen MATLAB files or experiment settings. Runs record their actual Git HEAD separately, so runs started before and after this commit may name different commits.

The final group report, combined presentation, contribution table and course submission ZIP still require group integration as described in the completion audit.
