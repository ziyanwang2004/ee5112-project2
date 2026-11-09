# Git checkpoint — 2026-11-09

This branch preserves the Task 4–5 implementation, the completed V2 results and the V3 mounted-workcell extension. The initial checkpoint `91890e9` was made while the V3 study was running; the follow-up adds its audited results. This remains a development handoff, not the final group submission package.

## Where to start

- [V3 instructions and results](README_TASK45_V3.md): the mounted-workcell extension and current demonstration.
- [V2 instructions and results](README_TASK45_V2.md): the original two-scene improved study.
- [Whole-project demo guide](docs/PROJECT_DEMO_GUIDE_ZH.md): replay Tasks 1–5 without replanning.
- [Whole-project completion audit](docs/PROJECT_COMPLETION_AUDIT_20261109.md): requirements, verification evidence and remaining group integration work.
- [V3 protocol](docs/TASK45_V3_PROTOCOL.md): the additional mounted robot, tabletop, new endpoints and held-out study.

In MATLAB R2023b, from the repository root:

```matlab
addpath('scripts')
show_project_demo('all','v3')
```

The original `README.md` and V1 records remain historical evidence. V2 passed 20/20 formal Task 4 runs and 20/20 projected Task 5 runs; its penalty-only ablation passed 0/10. V3 adds a separately reported scene with a table and fixed mounting pedestal. Its final counts and audit scope are in `README_TASK45_V3.md` and `delivery_checks.json`. These studies describe the recorded scenes and seeds, not general reliability.

## What this Git checkpoint includes

- Original Task 1–3 tracked files, Task 4–5 MATLAB implementation, separate V2/V3 source trees, scripts and documentation.
- V2 frozen configuration and source snapshot, all saved demonstration inputs/checkpoints/exports, all 50 formal final trajectories, per-run summaries and aggregate results, independent audit receipts, final report, editable slides and Chinese notes.
- V1 historical configuration, aggregate results, audit receipts and final delivery documents.
- V3 frozen configuration, source snapshot, geometry/development audit receipts and protocol; all 40 formal final trajectories and summaries; the two full demonstration traces; fine verification profiles, independent audit receipts, figures, three animations, report and four editable slides with Chinese notes.

## What remains in the full local archive

Large formal per-iteration checkpoints and input checkpoints, V1 demonstration traces, development/pilot archives, interruption records, visual review intermediates and machine-specific audit copies are retained locally and omitted from Git. No experiment files are deleted. Full raw formal replay requires that archive; saved V2 and V3 demonstration replay data is included here.

`docs/TASK45_FILES_SHA256.csv` and `docs/TASK45_V2_FILES_SHA256.csv` describe the **complete local releases**. Their historical hashes and full-release QA receipts are preserved unchanged. They are not inventories of this smaller Git checkpoint: a fresh checkout will report missing entries if the complete-release manifest checker is run without the omitted archive. Individual included files can still be checked against those manifests.

V3 supplies two explicit lists: `docs/TASK45_V3_FILES_SHA256.csv` for the complete local release and `docs/TASK45_V3_GIT_FILES_SHA256.csv` for the Git handoff. Run `py -3.12 scripts/verify_task45_v3_manifest.py` for the Git list, or add `--full` for the complete archive. Only Markdown in the Git list permits CRLF/LF checkout normalization; executable source and experiment data require exact bytes.

The script `scripts/configure_local_artifacts.py` installs local exclusions for retained raw archives without changing frozen evidence. See [the local artifact policy](docs/LOCAL_ARTIFACT_POLICY.md).

V3 uses the source fingerprint stored in `artifacts/runs/task45_v3/frozen_config.json` as its executable-source identity. Making this Git checkpoint does not change those frozen MATLAB files or experiment settings. Runs record their actual Git HEAD separately, so runs started before and after this commit may name different commits.

The final group report, combined presentation, contribution table and course submission ZIP still require group integration as described in the completion audit.
