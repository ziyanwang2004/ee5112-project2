# Task 4-5 V3：桌面安装场景

新场景正式实验：Task 4 **20/20**，Task 5 **20/20**。正式种子 5400-5419，开发种子 5300-5302；两组采用同一端点、碰撞初始化和基础预算。

额外 0.00625 rad 加密复核中，Task 5 最大倾角 **0.997°**，最小保守间距 **35.23 mm**，工具距桌面最小高度 **280.9 mm**。

机器人通过固定底座安装在桌面上；只允许固定底座接触桌面，所有 UR5 连杆和工具均参与碰撞检查。这解决了原场景没有地面限制的不足。V1/V2 历史记录继续保留。

```matlab
addpath('scripts')
show_project_demo('all','v3')
```

[完整结果与边界](docs/TASK45_V3_RESULTS.md) · [英文报告](artifacts/runs/task45_v3/delivery/task45_v3_report.pdf) · [可编辑展示](artifacts/runs/task45_v3/delivery/task45_v3_slides.pptx) · [中文备注](artifacts/runs/task45_v3/delivery/task45_v3_speaker_notes_zh.md)

[完整项目演示指南](docs/PROJECT_DEMO_GUIDE_ZH.md) · [Git 快照与本地原始档案](GIT_SNAPSHOT.md)

结果只对应已记录的场景与种子；验证是离散加密检查，尚不包含载荷、动力学或实机执行。
