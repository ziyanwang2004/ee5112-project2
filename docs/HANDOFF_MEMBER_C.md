# 成员 C 接手指南

这是 Tasks 1/2/3 的可运行共同基线。继续 Task 4/5 时，按题目使用 **UR5**，并在正式提交前把你新增的场景、姿态结果整合到同一套代码和组内报告。

## 先复现

1. 安装/使用 MATLAB **R2023b**，具备 Robotics System Toolbox 与 Image Processing Toolbox，完成本人授权登录。
2. 当前目录切到 `matlab`，运行 `run_all_tasks('all',true)`。只需要 UR5 时运行 `run_AB_memberB('all',true)`。
3. 已跑好的结果在 `artifacts/runs/final_r2023b`。不重规划也可 `addpath tests; verify_task123(runRoot)` 回放全部迭代。
4. 用分支保存你自己的改动，并为 Task 4/5 指定新的输出文件夹；不要覆盖 `final_r2023b`。MAT 文件中的旧机器路径只是运行元数据，源程序不依赖这些路径。

## 核心调用链与接口

```text
KINOVA_STOMP_Path_Planning / UR5_STOMP_Path_Planning
  -> helperSTOMP
     -> stompSamples
     -> stompTrajCost
        -> updateJointsWorldPosition
        -> stompRobotSphere
        -> stompObstacleCost
     -> stompUpdateProb -> stompDTheta -> stompUpdateTheta
```

`helperSTOMP`、`helperCreateObstaclesUR5` 是沿用原模板风格的脚本，需要入口构造的工作区变量，不要单独运行。`stompTrajCost` 前四个参数保留原式，额外传入缓存的 `context`。包内同名 `memberB.updateJointsWorldPosition` 是 PoE 工具接口；根目录版本是原模板的兼容适配层。

```matlab
robot = loadrobot('universalUR5','DataFormat','column');
model = memberB.buildPoeModel(robot,'tool0'); % 初始化一次
[Tall,Tee] = memberB.poeFK(model,q);         % q 为 6×1，单位 rad
[X,Tj,Tee] = memberB.updateJointsWorldPosition(model,q);
```

所有位姿和 twist 都相对于 `robot.BaseName`，UR5 为 `world`。`Tall(:,:,b)` 的 b 对应 `model.bodyNames`；固定关节不占 q 的元素。不要用 body 索引代替关节索引。PoE 的零配置是 q=0，与 `homeConfiguration` 区分。

## Task 4：复杂场景

`sharedDefaults.m` 提供 qStart/qGoal、采样数、噪声、迭代上限、碰撞余量等。`memberB.makeScene.m` 当前在初始路径中点 wrist_1 处生成一个 0.16 m 方块。可在你新增的 Task 4 入口/场景函数中改动配置和障碍。

场景格式为 `scene.boxes = [cx cy cz hx hy hz; ...]`，后面三列是**半尺寸**。`makeVoxelWorld(scene.boxes,c)`、解析球包络验证、绘图与实际网格验证均按这些行构造障碍，当前支持与坐标轴平行的多个长方体。旋转障碍或其他形状还需同步扩展这些环节。

最小修改路线：复制 UR5 入口为 Task 4 专用入口，另写场景构建脚本替换其中 `helperCreateObstaclesUR5`，其余 STOMP 链继续共用。先验证固定起终点可行，再证明初始线性路径确实碰撞；保留最终加密网格检查和逐轮记录。

原 UR5 入口已经检查两个端点的保守余量，并断言初始路径必须发生实际网格碰撞。任务更难时可能需要增加探索或重启次数；不能只用“代价下降”判定成功。

## Task 5：姿态约束

在自己的新入口中设置 `c.constraintFcn`。该回调接收 `(q,Tee)` 并返回有限、非负的标量；权重在回调内定义。例如下面只演示“工具 y 轴指向世界 z 轴”的惩罚：

```matlab
c.constraintFcn = @(q,Tee) 200*sum(abs(Tee(1:3,2)-[0;0;1]));
```

`stompTrajCost` 在所有离散路点把它乘归一化 dt 后加入局部代价。该接口是**软惩罚**，不自动构成严格姿态约束；现有成功门槛只检查避障。因此你还需要：

- 调整并固定满足目标方向的起终点，确认 IK 可达及无碰撞。
- 在同一场景、同一起终点、同一随机条件下比较关闭与开启姿态惩罚。
- 对加密轨迹计算方向误差角：`acos(clamp(dot(Tee(1:3,2),[0;0;1]),-1,1))`，明确阈值并加入最终验收。
- 保留方向误差曲线、配置叠加图及前后动画；不能仅凭代价项存在就宣称全程保持直立。

## 已有结果和边界

Tasks 1/2/3 已在 R2023b Update 11 实测。具体数值在 `VALIDATION.md`，机器可读数据在 `verification_summary.json`。每个任务的 `iterations/*.mat` 保存全部 rollout、实际扰动、局部代价、概率、平滑更新和随机数状态。

Task 1 的原始终点距方块约 6.90 mm，因此只以实际网格无碰撞验收，保守球包络的负间距是已知误报。不要把这个 Task 1 特殊处理搬到更难的 UR5 场景来掩盖实际碰撞。

本次三条最终路径的加密检查均无自碰撞，但算法遵循原模板，没有加入自碰撞优化代价。检查是每关节步长不超过 0.025 rad 的离散验证，不是连续碰撞证明，也不含速度、加速度、力矩或真实硬件安全保证。

## 后期报告/PPT 素材

每任务目录提供 `planning_summary.png/.fig`、`robot_midpoint_comparison.png/.fig`、`robot_final_pose.png`、`iteration_001_rollouts.png/.fig`、`iteration_001_cost_probability.png/.fig`、`voxel_vs_exact_clearance.png/.fig` 和 AVI。比较图实际选择了初始路径的一个碰撞状态，并在相同路径参数展示优化结果，文件名为兼容旧版本保留了 midpoint。

Task 3 另有 `space_screws.csv`、`M_end_effector.csv`、`joint_mapping.txt`、`fk_accuracy.csv`、`fk_benchmark.csv` 和 `poe_cost_call_chain.txt`。用这些实际数据说明 twist 来源、精度和效率；本次没有生成新的 PDF 或 PPT。
