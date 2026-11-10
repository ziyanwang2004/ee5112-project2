# EE5112 Project 2 — Tasks 1–5

**Current integration candidate: `codex/task45-v5-adaptive-ablation`.** This branch contains the complete V3 and V4 history as well as V5. Merge this branch once into `main`; the earlier two branches do not require separate merges.

## Start here

- [Final code handoff and merge guide](../FINAL_SUBMISSION.md)
- [Task 4–5 presentation, videos and scripts](../README_TASK45_PRESENTATION.md)
- [Whole-project MATLAB demonstration](../docs/PROJECT_DEMO_GUIDE_ZH.md)
- [Task 1–3 methods](../docs/METHODS.md) and [original validation](../docs/VALIDATION.md)

In MATLAB R2023b, from the repository root:

```matlab
addpath('scripts')
show_project_demo('all','v3')
```

This shows the saved Task 1–3 baseline and the mounted-workcell Task 4/5 comparison. It does not replan or overwrite results. Do not add the entire repository with `genpath` because the preserved versions contain functions with the same names.

## Which algorithm version to present

| Role | Version | Recorded result |
| --- | --- | --- |
| Course Task 4 vs Task 5 comparison | [V3](../README_TASK45_V3.md) | Task 4: 20/20; Task 5: 20/20 |
| Feasible refinement and tangent sampling | [V4](../README_TASK45_V4.md) | Four Task 5 arms: 10/10 each |
| Energy control and adaptive ablation | [V5](../README_TASK45_V5.md) | Fixed75: 15/15; adaptive: 13/15 |

The V5 branch is the latest source-and-evidence integration candidate. The adaptive algorithm is an experimental option, not the default course demonstration. All V4/V5 arms already enforce the Task 5 upright constraint. Recorded failures remain in the statistics. Verification is discrete geometry validation, without payload dynamics or hardware execution guarantees.

## Current presentation handoff

- [Four-slide main presentation with embedded video](../deliverables/task45_20261110/task45_main.pptx)
- [Sixteen-slide presentation including backup material](../deliverables/task45_20261110/task45_full.pptx)
- [Chinese project understanding manuscript](../deliverables/task45_20261110/project_understanding_zh.pdf)
- [English speaking script and Chinese notes](../deliverables/task45_20261110/speaker_script_zh_en.pdf)
- [English report section](../deliverables/task45_20261110/task45_report_section_en.pdf)

Use desktop PowerPoint to play embedded videos. The group still needs to integrate the Task 1–3 slides, combined report, actual member contributions and final course ZIP. These Task 4–5 materials are not the complete group submission.

## Historical evidence

The root [README](../README.md), original result folders and older audits remain preserved as dated evidence. Some describe earlier Task 5 failures and are not current release instructions. Git contains compact formal results and full shipped demonstration traces; full formal per-iteration archives remain local. See [the handoff guide](../FINAL_SUBMISSION.md) before running archive-only verification.
