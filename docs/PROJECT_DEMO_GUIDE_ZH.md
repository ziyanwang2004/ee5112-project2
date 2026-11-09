# MATLAB 完整项目展示

建议使用 MATLAB R2023b Update 11。展示保存结果不会重新优化，不会修改冻结数据。

## 1. 打开五任务展示窗口

在 MATLAB 命令窗口粘贴：

```matlab
cd('D:\Users\NUS-courses\EE5112_Project_2\ee5112-project2')
addpath('scripts')
show_project_demo('all')
```

默认选择已经完成交付校验的最新版本。V3 完成交付校验前，默认使用 V2。
需要固定版本时：

```matlab
show_project_demo('all','v2')
show_project_demo('all','v3')  % V3 动画和图导出完成后可用
```

窗口包含 Task 1–5 五个标签页：

- **Play motion**：在 MATLAB 视频播放器中播放该任务的已保存动画，可暂停和逐帧查看。
- **Initial vs planned**：查看初始碰撞与规划结果。
- **Print saved metrics**：在命令窗口打印保存结果的碰撞、间距和姿态指标。
- Task 3 的 **PoE screws / accuracy / timing**：查看空间轴、M、精度和原机器计时数据。
- Task 4/5 的 **Play Task 4 vs Task 5**：播放并排对照动画。

Task 1–3 来自原冻结基线。V2 的 Task 4–5 默认显示 main 场景；V3 显示新增的
workcell 场景、20 cm 安装底座和 z=0 台面。动画表示归一化路径进度，不是执行时间。

也可只展示一个任务或 V2 的布局变体：

```matlab
show_project_demo('task1')
show_project_demo('task3')
show_project_demo('task5','v2','variant')
show_project_demo('task5','v3','workcell')
```

只检查展示文件是否齐全，不打开窗口：

```matlab
info = show_project_demo('check','v2');
```

## 2. 从 PowerShell 启动正确版本

终端的 `matlab` 可能仍指向旧版本。可使用明确路径启动桌面：

```powershell
& 'D:\Program Files\MATLAB\bin\matlab.exe' -desktop -r "cd('D:\Users\NUS-courses\EE5112_Project_2\ee5112-project2'); addpath('scripts'); show_project_demo('all');"
```

## 3. 需要重新规划时

下面会实际运行规划并写入新目录，耗时明显长于回放。V3 需要已有冻结配置。

```matlab
cd('D:\Users\NUS-courses\EE5112_Project_2\ee5112-project2')
runRoot = fullfile(pwd,'artifacts','local_runs', ...
    ['full_demo_',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
addpath('matlab')
r123 = run_all_tasks('all',true,fullfile(runRoot,'task123'));
addpath('scripts')
r45 = run_task45_v3('all',5300,fullfile(runRoot,'task45_v3'));
```

验证新运行：

```matlab
addpath('matlab/tests')
verify_task123(fullfile(runRoot,'task123'));
verify_task45_v3(fullfile(runRoot,'task45_v3'));
```

不要使用 `addpath(genpath(...))` 将整个仓库加入路径；原模板、多个版本和快照有同名函数。
原 Task 1–3 Linux 存档的逐位回放在 Windows 上存在舍入差异；本机新运行可以严格回放。
课程现场展示可优先使用已验证的保存结果，再解释代码和算法。
