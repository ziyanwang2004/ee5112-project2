# EE5112 Project 2 — Tasks 1–5

MATLAB **R2023b** 共同基线，交接给成员 C 继续 Task 4、5。Task 1 使用原始 KINOVA Gen3 场景；Task 2 改为 UR5；Task 3 在相同 UR5 问题中将规划正运动学替换为自主实现的 PoE。

Task 1–3 原始交付和实测数值见 [验证记录](docs/VALIDATION.md)。Task 4–5 新增实现与固定实验协议见 [方法说明](docs/TASK45_METHODS.md)，运行命令见 [复现指南](docs/TASK45_RUNBOOK.md)。原始 `final_r2023b` 结果独立保留。

## 运行

需要 MATLAB R2023b 和 Robotics System Toolbox；`sEDT_3d` 使用 Image Processing Toolbox 的 `bwdist`。采样通过 `randn`/`chol` 实现，无需 `mvnrnd`。运行时须具有可用的 MATLAB 授权，仓库不包含 MATLAB 软件或账号资料。

在 MATLAB 中将当前目录切换到本仓库的 `matlab` 文件夹：

```matlab
results = run_all_tasks('all', true);  % 顺序运行任务 1/2/3，显示图和动画
% 或分别运行：
r1 = KINOVA_STOMP_Path_Planning;       % 原题要求的 Task 1 主入口
results = run_all_tasks('task2', true);
results = run_all_tasks('task3', true);
```

新运行写入 `artifacts/local_runs/<时间戳>/`，不会覆盖提交的结果。该目录默认由 Git 忽略，需要保留的新实验可另选目录或明确加入 Git。

查看、验证、重新导出随仓库提交的最终实验：

```matlab
runRoot = fullfile(pwd, '..', 'artifacts', 'runs', 'final_r2023b');
addpath tests
summary = verify_task123(runRoot);  % 数值、端点、限位、逐轮随机过程回放
export_run_process(runRoot);       % 重绘 PNG/FIG、重导 AVI，并检查帧数及 PoE 调用链
```

`run_AB_memberB('all',true)` 保留为只运行 Task 2/3 的兼容入口。不要使用 `addpath(genpath(...))` 把原始模板也加入路径；只需进入 `matlab`。

## 文件位置

| 路径 | 内容 |
| --- | --- |
| `matlab/` | 三个任务共用的可运行源代码、PoE、球包络、体素距离场和测试 |
| `artifacts/runs/final_r2023b/Task1/` | KINOVA 原场景最终结果及完整迭代记录 |
| `artifacts/runs/final_r2023b/Task2/` | UR5 + MATLAB 内置 FK 对照结果 |
| `artifacts/runs/final_r2023b/Task3/` | UR5 + PoE、精度、耗时和调用链证据 |
| `docs/HANDOFF_MEMBER_C.md` | 成员 C 接手指南、Task 4/5 扩展点 |
| `docs/METHODS.md` | 算法改动、体素距离及 twist 推导，供后期报告/PPT 使用 |
| `provenance/` | 收到的 RAR/原始模板、输入核对和本次改动追踪 |
| `docs/MEDIA_MANIFEST.csv` | 图片、视频、MAT 数据等的路径、大小和 SHA-256 |

Task 1 固定终点实际网格距障碍约 **6.90 mm**，小于原模板中声明的 1 cm 安全距离；保守球包络还会在终点误报重叠。因此 Task 1 保留原始起终位姿及方块，以加密 MATLAB 实际碰撞网格检查验收。Task 2/3 同时要求 35 mm 保守体素球包络余量和实际网格无碰撞。具体检查密度和适用边界见验证记录。

Task 4–5 已完成代码、四条开发演示、50 次正式运行和独立复核。[冻结配置](artifacts/runs/task45_final/frozen_config.json)采用姿态投影、λ=1000、噪声 0.55 rad，演示种子 5113。**正式 Task 4 为 20/20，Task 5 为 0/20；罚项消融为 0/10。** 投影组全部满足 5° 方向检查，但全部因自碰撞未通过完整验收，当前 Task 5 尚不具备稳定规划能力。

四条开发演示全部通过验收；54 条演示/正式轨迹共回放 5,492 个检查点。另有一次技术中断的 288 个检查点完整保留，回放及重试前缀逐元素一致；完成的名义实验为 50 次，全部观察尝试为 51 次。原 Task 1–3 证据未覆盖。

## Task 4–5 结果索引

| 材料 | 位置 |
| --- | --- |
| 完整英文结果、失败分析与贡献 | [TASK45_RESULTS.md](docs/TASK45_RESULTS.md) |
| 英文方法与实验协议 | [TASK45_METHODS.md](docs/TASK45_METHODS.md) |
| 4 页英文报告 | [task45_report.pdf](artifacts/runs/task45_final/delivery/task45_report.pdf) |
| 4 页可编辑英文展示 | [task45_slides.pptx](artifacts/runs/task45_final/delivery/task45_slides.pptx) |
| 展示 PDF / 中文讲解备注 | [PDF](artifacts/runs/task45_final/delivery/task45_slides.pdf) / [备注](artifacts/runs/task45_final/delivery/task45_speaker_notes_zh.md) |
| 50 条正式记录及统计 | [CSV](artifacts/runs/task45_final/formal/all_runs.csv) / [JSON](artifacts/runs/task45_final/formal/study_summary.json) |
| 演示 PNG、FIG、六段动画 | [主场景](artifacts/runs/task45_final/demos/exports/main/) / [变体](artifacts/runs/task45_final/demos/exports/variant/) |
| 独立复核 / 中断回放 | [轨迹复核](artifacts/runs/task45_final/independent_audit.json) / [中断回放](artifacts/runs/task45_final/recovery_audit.json) |
| 尝试次数与后处理修复记录 | [尝试统计](artifacts/runs/task45_final/attempt_accounting.json) / [修复记录](artifacts/runs/task45_final/provenance/postprocessing_patch.json) |
| 文件校验清单 | [TASK45_FILES_SHA256.csv](docs/TASK45_FILES_SHA256.csv) |

## Task 4–5 运行

在仓库根目录执行：

```matlab
addpath matlab
results = run_task45('all','all',5113,false); % 新目录；使用冻结配置
audit = verify_task45(fullfile(pwd,'artifacts','runs','task45_final')); % 只读复核
```

正式批处理入口为 `run_task45_benchmark`；完整参数、保存格式和导出命令见[复现指南](docs/TASK45_RUNBOOK.md)。本机须显式使用 `D:\Program Files\MATLAB\bin\matlab.exe`，终端中的 `matlab` 仍可能指向 R2023a。
