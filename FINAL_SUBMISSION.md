# 最终代码交接与合并指南

本文件是 2026-11-10 的整合入口，不替代已冻结的历史报告或实验清单。

## 只合并哪个分支

**只合并 `codex/task45-v5-adaptive-ablation` 到 `main`。** 远端三个分支的提交为线性包含关系：

```text
main 9490df5  Task 1–3 baseline
  -> V3 0205586  Task 4–5 and mounted workcell
  -> V4 4eabf4c  feasible refinement and tangent sampling
  -> V5 fea847b  adaptive sampling and energy-control ablation
  -> presentation and integration handoff
```

V4 相对 V3 增加 2 个提交，V5 实验提交相对 V4 增加 7 个提交。V5 已包含 V1/V2/V3/V4 的代码与保留结果。V3 到 V5 的 `matlab/`、V2/V3 源码和 V3/Task 1–3 实验文件没有差异，不需要再把三条分支分别合并，也不要把各版本的同名函数复制覆盖到同一目录。

合并时优先使用 **Create a merge commit**，保留已记录的提交身份和追溯关系。不要在审阅前删除旧分支；合并后可保留为历史检查点。合并只整合代码和材料，不等于向课程提交。

## “最新分支”和“主展示算法”是两件事

| 内容 | 采用什么 |
| --- | --- |
| 最终代码与证据集合 | V5 分支的全部内容 |
| Task 1–3 | 原始 `matlab/` 基线与 `artifacts/runs/final_r2023b/` |
| Task 4/5 课程主展示 | V3 安装工作台，两组各 20/20 |
| 扩展算法分析 | V4 四组消融、V5 五组跨三种情形的实验 |
| 扩展比较基线 | fixed75；adaptive 保持实验选项 |
| 最新成员 C 汇报 | `deliverables/task45_20261110/` |

V5 不是“课程 Task 5 失败了”：其扩展正式实验有 71/75 成功，4 次失败均未达到 35 mm 保守余量；课程主线 V3 的 Task 4 与 Task 5 均为 20/20。V4/V5 中的 baseline、ambient 本身都是有直立约束的 Task 5 组，不能拿来冒充 Task 4。

## 快速展示和新规划

要求 MATLAB R2023b、Robotics System Toolbox、Image Processing Toolbox，以及可用的 MATLAB 授权。

在仓库根目录：

```matlab
addpath('scripts')
show_project_demo('all','v3')
show_task45_v4('benchmark')
show_task45_v5('benchmark')
```

课程现场优先回放保存结果。重新规划时使用新输出目录，并在不同版本之间启动新的 MATLAB 会话：

```matlab
% Session 1: Task 1–3, from the repository root
addpath('matlab')
r123 = run_all_tasks('all',false);
```

```matlab
% Session 2: course Task 4/5, from the repository root
addpath('scripts')
r45 = run_task45_v3('all',5300);
```

V4/V5 的新实验入口及参数见各自 README。不要使用旧 V1 的 `run_task45` 代替当前课程展示，不要 `addpath(genpath(pwd))` 混入模板、快照和多个版本。新规划仍可能失败，应保留失败及其诊断，不能保证每次实时运行都重现保存的成功演示。

## GitHub 包包含什么

包含原 Task 1–3、各版本源代码、冻结配置、最终路径和统计、验证器、审计回执、可编辑图、演示输入/完整回放、动画及报告材料。V5 正式 compact 结果可独立从保存路径重新验收：

```matlab
addpath('scripts')
audit = verify_task45_v5_paths(fullfile(pwd,'artifacts','runs','task45_v5','formal'));
```

Git 不包含所有正式实验的完整 input/iterations/refinement 原始档案。它们保留在本机，不能把“未上传大档案”等同于“算法代码漏交”。compact 最终路径复核与随机采样/更新全回放是两种不同检查。Git 中保留了可做全回放的开发演示。

检查 Git 交付清单：

```powershell
py -3.12 -X utf8 scripts/verify_task45_v3_manifest.py
py -3.12 -X utf8 scripts/verify_task45_v4_manifest.py
py -3.12 -X utf8 scripts/verify_task45_v5_manifest.py
```

没有完整本机档案时，不要添加 `--full`。原 Task 1–3 Linux 存档在 Windows 上的逐位回放可能有舍入差异；本机新运行能做严格回放。详见已保留的跨平台记录。

## 队友需要整合什么

1. 代码：审阅并合并这一个 V5 PR，保留版本目录和冻结证据，合并后用上述展示与 compact 检查确认路径正确。
2. PPT：提供 Task 1–3 的可编辑 PPTX、关键图/视频和口述稿；将成员 C 的 4 页主讲加入全组约 7 分钟展示。16 页完整版只供参考和问答，后 12 页默认隐藏。
3. 报告：统一覆盖五个任务的 PDF，解释 twist 的来源、STOMP 的具体实现、约束、实验与限制；成员 C 英文小节可直接作为整合基础。
4. 贡献：按实际工作填写三人姓名和贡献，不按 Git 提交作者推断每个人的全部工作。
5. 提交：最后统一一个课程 ZIP。组号、文件命名、Canvas 时段和实际上传须由全组确认；原说明截止为 2026-11-12 16:00（新加坡时间）。

最新汇报文件见 [汇报索引](README_TASK45_PRESENTATION.md)。本机额外打包的 `task45_20261110_bundle.zip` 不再作为重复二进制文件纳入 Git；仓库内的 PPTX、MP4、PDF、Markdown 和源文件均可单独下载。

## 历史入口与校验

根 `README.md`、`GIT_SNAPSHOT.md`、旧完成度审计和 V1 失败记录保持原文，以免破坏既有冻结清单。它们的日期与结论只对应当时状态。当前 GitHub 导航为 `.github/README.md`，当前整合说明为本文件；不再将旧 V1 的 0/20 当成当前 Task 5 状态。

Task 1 原终点真实网格间距约 6.90 mm，不能宣称符合 1 cm 硬余量。Task 4/5 的 35 mm 代理余量和 5° 倾角是自定工程标准；所有成功声明限定于离散加密几何验收，没有连续碰撞、载荷动力学或实机执行保证。
