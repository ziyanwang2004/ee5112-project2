# EE5112 Project 2 — Tasks 1 / 2 / 3

MATLAB **R2023b** 共同基线，交接给成员 C 继续 Task 4、5。Task 1 使用原始 KINOVA Gen3 场景；Task 2 改为 UR5；Task 3 在相同 UR5 问题中将规划正运动学替换为自主实现的 PoE。

本次保留源代码、逐轮过程、验证数据、可编辑 MATLAB 图和动画，暂不生成 PDF 报告或 PPT。完成状态与实测数值见 [验证记录](docs/VALIDATION.md)。

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

Task 4、5 尚未完成。`constraintFcn` 只是留给成员 C 的代价接口，不能作为姿态约束已实现或通过验证的证据。
