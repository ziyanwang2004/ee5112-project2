# Task 4–5 主讲稿与排练说明

英文幻灯片配中文理解备注。主讲 4 页，目标约 3 分钟，包含两次各 10 秒的视频；可根据队友剩余时间压到约 2 分 40 秒。其余页只在问答时使用。个人姓名、组号由全组统一添加。

## 第 1 页：Task 4 场景（约 35 秒）

**English script**

For Task 4, I built a more challenging UR5 workcell on top of our team's STOMP and PoE implementation. The robot stands on a twenty-centimetre pedestal above a table. A central rack, two equipment boxes and a rear guard obstruct the transfer. Both endpoints are valid, but the shared straight joint-space initialization collides at ninety-two of one hundred and eighty-one checked states. The feasible reference path was kept separate and never used to initialize the planner.

**中文理解**

先接住队友的内容：他们完成了机器人、STOMP 基础和 PoE。我做的是把它放进更实际、更难的搬运环境。桌面是不能穿过去的真实障碍，底座用于合理安装机器人。五个环境体积是桌面、中央架、左右设备、后方挡板；安装底座属于固定机器人模型，不能把它错算成第六个普通障碍。

指着三幅图讲“初始碰撞、Task 4 成功绕行、Task 5 直立绕行”。92/181 是公共直线初值的碰撞计数，不是规划成功率。不要说我们用参考路径帮优化器绕过障碍。

## 第 2 页：Task 5 方法（约 45 秒，含 10 秒视频）

**English script**

For Task 5, I keep the same scene, endpoints and base planning settings. The tool's y-axis must follow the world's positive z-axis, while yaw remains free. I add an orientation penalty and use a damped Jacobian projection to correct sampled waypoints and proposed updates. Projection only corrects orientation, so I also add self-collision costs and reject invalid candidates. Final acceptance checks the dense path for joint limits, unchanged endpoints, world and self collisions, and a thirty-five-millimetre conservative clearance. Task 5 additionally requires at most five degrees of tilt.

**操作**

单击右侧视频一次，播放 10 秒。在播放过程中指出末端方向标记。视频没有杯子实体，不要说“我们已经验证杯子不洒”；用“这对应题目中搬运一杯咖啡的方向要求”。

**中文理解**

只约束一个方向，而不是固定整个旋转矩阵。直立轴周围的转动可以保留，机器人更容易找到避障解。软罚项提供搜索方向，投影把候选拉回直立方向附近；最后的加密验收才决定是否成功。端点直立不代表中间关节插值始终直立。

## 第 3 页：Task 4/5 视频对照（约 35 秒，含 10 秒视频）

**English script**

This paired demonstration uses the same development seed. The blue Task 4 path avoids obstacles but allows the tool to tilt. The green Task 5 path also avoids obstacles and remains upright. The maximum tilt in this demonstration changes from about one hundred and twenty degrees to less than one degree. Both videos show normalized path progress, rather than physical execution time. This is a visual example; the next slide summarizes all held-out runs.

**操作**

单击并排视频一次。在中间进度处指出蓝色工具方向会翻转，绿色方向保持向上。不要因左右同时播放而说两种方法有相同实机速度。120.29° 与 0.930° 是演示种子 5300 的数据；它们不同于正式实验所有路径的最坏值。

## 第 4 页：正式结果、贡献与边界（约 45 秒）

**English script**

We then froze the configuration and evaluated twenty held-out paired seeds. Both tasks succeeded in all twenty runs. The worst Task 5 tilt was about zero point nine nine seven degrees, with at least thirty-five point two three millimetres of conservative clearance. The upright condition required more computation. My contribution includes the workcell, upright projection, self-collision handling and independent replay validation. I also evaluated feasible refinement and tangent sampling. The later adaptive sampler had fewer successes, so I kept it experimental. These results are dense geometric checks, without payload dynamics or a continuous collision guarantee.

**中文理解**

20/20 对应固定 V3 场景，不是“所有场景成功率 100%”。30.42 s 和 68.19 s 是该次双进程运行中各组规划时间中位数，包含记录写盘。不要把不同权重的原始总代价作为 Task 4/5 性能优劣证据。

主讲到此结束。若时间紧，将扩展算法一句压缩为 “Additional ablations are in the backup slides.” 不要把 V4/V5 当成未加直立约束的 Task 4 对照。

## 被问到 V5 失败时的 30 秒英文回答

Four of seventy-five V5 runs missed our hard thirty-five-millimetre conservative clearance threshold. Their tilt errors were already below one degree. The adaptive controller ranks soft rollout costs, which need not predict dense feasibility. That is a plausible mechanism, rather than a proven cause. Fixed seventy-five-percent tangent sampling passed fifteen out of fifteen cases, while adaptive sampling passed thirteen. I therefore retain the fixed strategy and report the failed runs.

## 被问到 STOMP 时的 30 秒英文回答

STOMP optimizes an entire joint trajectory. It samples temporally correlated perturbations around the current path, evaluates their costs, gives lower-cost perturbations larger probabilities, and smooths the weighted update. It repeats this process while keeping the endpoints fixed. Our extensions add upright projection, self-collision handling and explicit feasibility gates. The optimizer proposes a path; independent dense validation decides whether we call it successful.

## 被问到个人贡献时的 20 秒英文回答

I reused my teammates' STOMP stages, PoE model and robot envelopes. I designed the multi-obstacle scenes, implemented the upright constraint and self-collision extensions, built the paired experiments and independent verifier, and evaluated feasible refinement, tangent sampling and the adaptive ablation. The original Task 1 to 3 evidence remains unchanged.

## 排练和现场操作

1. 先各练一次不播视频和正常播视频的版本。以全组约 7 分钟为上限，预留换人时间。
2. 使用 `task45_main.pptx` 并入全组，只保留这 4 页为正常播放页。`task45_full.pptx` 的额外页用于答辩。
3. 使用桌面 PowerPoint，F5 放映后单击视频。第一次播放需给解码器少量准备时间。网页预览和 PDF 不保证视频功能。
4. 随身保存 `media/paired_motion.mp4` 与静态 PDF；PPT 播放受设备策略影响时直接播放同源 MP4。
5. 不在现场重新跑 40/75 次实验。MATLAB 保存结果的展示入口在 README；重新规划可能抽到失败路径，也占用时间。
6. 讲结果时先报场景和样本数，再报成功数，最后解释代价、速度与边界。不要只挑成功视频。

## 术语读法

STOMP：直接读 stomp。PoE：读 P-O-E。UR5：读 U-R-five。Rollout：一次扰动候选轨迹。Tangent：切空间方向。Clearance：间距或余量。Feasible：通过全部验收的可行路径。Yaw：绕直立轴的转动。Held-out seeds：冻结参数之后使用的未参与调参的种子。
