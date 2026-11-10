# Task 4-5 V2 结果与复现

旧版 README 和 V1 证据保持冻结。最新结果从此页进入。

| 场景 / 条件 | 正式成功数 |
| --- | ---: |
| main / Task 4 | 10/10 |
| main / Task 5 | 10/10 |
| main / penalty only | 0/10 |
| variant / Task 4 | 10/10 |
| variant / Task 5 | 10/10 |

正式种子为 5200–5209，开发种子不进入上述统计。所有正式失败均计入分母。penalty only 是去掉姿态投影、保留 λ=1000 罚项的消融组。

[英文报告](artifacts/runs/task45_v2/delivery/task45_v2_report.pdf) · [可编辑展示材料](artifacts/runs/task45_v2/delivery/task45_v2_slides.pptx) · [展示材料 PDF](artifacts/runs/task45_v2/delivery/task45_v2_slides.pdf)

[V1 失败原因](docs/TASK5_V1_FAILURE_ANALYSIS.md) · [完整结果与统计口径](docs/TASK45_V2_RESULTS.md) · [源代码与复现说明](upgrades/task45_v2/README.md)

```powershell
& 'D:\Program Files\MATLAB\bin\matlab.exe' -batch "addpath scripts; r=run_task45_v2('all','all',5150,false,'D:\new_empty_run_root'); audit=verify_task45_v2('D:\new_empty_run_root');"
```

完整 50 次重跑使用 `addpath scripts; run_task45_v2_benchmark(newRunRoot)`，必须提供新的输出目录。原始正式研究使用两进程；该入口顺序运行，因此运行时间仅在同一执行方式内比较。

动画和可编辑 FIG 位于 `artifacts/runs/task45_v2/demos/exports/`。检查属于离散加密验证，动画横轴为路径进度。
