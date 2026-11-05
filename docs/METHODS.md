# 实现与过程说明

本文件保留算法与几何细节，供组员理解、继续开发及后期报告/PPT 使用。最终实验结果见 `VALIDATION.md`。

## Task 1 原始场景

`KINOVA_STOMP_Path_Planning.m` 加载 `kinovaGen3`，末端 `EndEffector_Link`，保持原模板两个任务空间位姿：

```matlab
taskInit  = trvec2tform([.4 0 .2])   * axang2tform([0 1 0 pi]);
taskFinal = trvec2tform([.35 .55 .35])* axang2tform([0 1 0 pi]);
```

IK 权重为六个 1，禁用随机重启，起点以 home 为初值，终点以起点为初值，然后按原模板 `wrapToPi`。方块中心 `[.4 .46 .26]`，边长 0.16 m。规划期间两个关节端点保持不变。KINOVA 连续关节仅为随机探索设置 ±2π 的有限区间，原始物理无界限位单独保存在 MAT 中；其余关节保留物理限位。

原终点 MATLAB 网格最小间距约 6.90 mm，无法同时保持原始位姿并实现 1 cm 硬余量。固定起终点的球包络/体素距离误报还会使代理代价无法下降为零。Task 1 采用 `acceptanceMode='mesh'`：代理代价引导优化，最终以实际 MATLAB 网格加密检查无障碍碰撞验收，并如实保留代理余量不满足的状态。

## Task 2 的 UR5 对照场景

UR5 的 qStart=`[-.9;-.85;1.25;-1.95;-pi/2;0]`，qGoal 只将第一关节变为 `+.9`。0.16 m 方块中心取线性初始路径中点的 wrist_1 原点，场景由加载模型确定。端点通过保守代理余量检查，初始路径必须发生实际网格碰撞，避免使用平凡无碰撞初始化。

Task 2 使用内置 `getTransform` 为每个 body 求位姿；Task 3 仅替换规划 FK 后端，其余初值、随机数、几何、代价和更新一致。两者均以 35 mm 保守体素球包络余量和独立 MATLAB 网格无碰撞共同验收。

## STOMP 补全与明确的改动

保留原文件名和调用链，`sEDT_3d.m`、`stompUpdateTheta.m` 与收到的模板字节一致。其他函数的补全及适配见 `provenance/baseline_diff.patch`。

- 使用 41 路点，32 个成对反向扰动 rollout，固定随机种子 5112；每次最多 100 轮、最多 3 次重启。
- 按原模板构造二阶差分矩阵 A，取自由内点列后 R=AᵀA；用线性求解获得 R⁻¹，沿列归一化后形成 M。协方差按 R⁻¹ 的最大对角元归一化，以噪声标准差设置 rad² 尺度。
- 端点不采样。样本投影到关节限位后，概率更新使用实际投影后的扰动。
- 每路点对局部 rollout 代价做指数归一化，代价相同给均匀概率。按概率加权扰动并经 M 平滑，限制更新幅度，尝试 1、0.5、0.25 步长。
- 更新只接受总代价下降；当加权组合不如某个单独 rollout 时，显式采用降低总代价的最佳 rollout。这个回退属于实现改动，不是原始 STOMP 定理的额外保证。
- 原模板要求的速度加权障碍代价之外，增加静止穿透平方惩罚，避免球速度为零时穿透没有代价。完整代价为 `3000*sum_t[sum_s(hinge_s*speed_s)+20*sum_s(hinge_s^2)]*dt + 0.5*sum(diff(q,2)^2)`，其中 `hinge=max(margin-gap,0)`，dt=1/(N−1)。姿态回调默认关闭。
- 工作空间速度由固定 body 局部球样本的中心差分得到，端点使用单边差分。平滑代价包含固定端点，而非把端点当作零值。

## 体素与几何

体素地图延续原模板占据栅格 → `sEDT_3d` 路线。范围 `[-1,1]^3`，立方体素边长 0.02 m。数组维度明确为 x、y、z，并测试非立方数组以防 x/y 混用。中心距 EDT 插值后扣除一个体素对角线 `sqrt(3)*0.02` 的保守修正；地图外按实体边界处理。优化用体素距离，验证同时记录球与解析方块的间距，以及 MATLAB 实际网格间距。

球体是 body 局部坐标中的固定包络，不能用相邻关节位置粗略连线代替完整 link 几何。UR5 使用公开上游碰撞网格拟合的数值球，KINOVA 用 R2023b `show(...,'Collisions','on')` 公共图形 patch 顶点拟合，生成脚本为 `buildKinovaSpheres`。没有打包原始 STL/DAE。方法和许可证见 `matlab/data/PROVENANCE.md`。

每个凸网格由 PCA 主轴圆柱包围，以轴向间距 h 的球覆盖圆柱。球半径为 `sqrt(rho^2+(h/2)^2)+padding`，rho 为最大横向距离。这覆盖圆柱内连续区域，仍可能因包络偏大产生误报。KINOVA 间距上限 0.015 m、padding=0；UR5 间距上限 0.035 m、padding=0.003 m。固定基座离演示方块较远，未包含在优化球集合中，最终 MATLAB 检查仍使用加载模型的完整碰撞几何。

## Task 3 的 space twist 与 PoE

约定 `S=[omega;v]`，统一相对于 `robot.BaseName`，配置变量顺序按 moving joint 名映射，固定关节不占变量。零位姿使用 q=0，不用非零的 home 替代。

初始化一次读取 `JointToParentTransform`、`ChildToJointTransform`、局部轴与父子关系。设父 body 的零位姿为 Z，则 joint 前置零位姿 `Tj=Z*JointToParentTransform`，body 零位姿 `Mb=Tj*ChildToJointTransform`。局部轴经 Tj 的旋转变换得到世界轴 a，p=Tj 的平移：

```text
转动关节：S = [a; -cross(a,p)]
移动关节：S = [0; 0; 0; a]
T_body(q) = exp([S_ancestor1]q1) ... exp([S_ancestork]qk) * Mb
```

固定前置 body、末端 fixed offset 和 side branch 均保留。每任务导出实际加载模型的 screw 矩阵、末端 M、关节映射及完整 PoE 缓存，不用手抄近似数值作为权威模型。

`twistExp` 使用转动/移动关节的闭式指数，不在规划循环调用通用 `expm`；`1−cos(q)` 用 `2*sin(q/2)^2`，小角度 `q−sin(q)` 用 Taylor 展开。W、W² 在初始化缓存。每配置每活动关节只算一次指数，body 遍历复用父节点前缀积，避免从基座重复连乘。

精度比较覆盖 200 配置的所有 bodies；另有含固定前置旋转、非平凡 child offset、移动关节和固定侧枝的数值测试。计时预热后做 5 轮相同的 200 配置、所有 body 位姿工作量，报告中位数。`getTransform` 在 Task 3 的独立参考/碰撞验证和显示中允许出现；规划代价的 profile 单独断言其不存在。

## 记录与可复现性

每轮 MAT 保存更新前后 q、全部 rollout、实际噪声、样本总代价与局部代价、归一化概率、原始/平滑更新、接受类型与样本号、R/M/协方差及前后 RNG 状态。`replay_saved_process` 可逐位复现样本、随机数状态、概率和接受更新。`input_checkpoint.mat` 保存地图、模型和选项；`planning_result.mat` 保存初始及最终路径、各项验证和所有接受轨迹。

计时是该电脑单次运行，规划时间包含逐轮 MAT 写盘，不等于严格纯算法运行时间，也不代表其他机器或所有场景的加速比。加密检查限制每关节步长 0.025 rad，但不构成连续碰撞证明。当前任务没有时间参数化或动力学约束。

算法背景：Kalakrishnan 等，STOMP，ICRA 2011，DOI 10.1109/ICRA.2011.5980280；Lynch 与 Park，Modern Robotics，第 4 章。代码为本工作包的实现，没有复制 Modern Robotics 源码。
