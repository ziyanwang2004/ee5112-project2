# 备份页中文备注与来源

正常主讲使用前4页。完整PPT的第5–16页默认隐藏，供答辩时按页号跳转。

## 第1页：Task 4: a mounted UR5 workcell

主讲约35秒。For Task 4, I built a more challenging UR5 workcell on top of our team's STOMP and PoE implementation. The robot stands on a twenty-centimetre pedestal above a table. A central rack, two equipment boxes and a rear guard obstruct the transfer. Both endpoints are valid, but the shared straight joint-space initialization collides at ninety-two of one hundred and eighty-one checked states. The feasible reference path was kept separate and never used to initialize the planner.
中文：展示非平凡初值。五个环境体积包括桌面；安装底座属于机器人模型。参考路径仅用于可行性证明。

依据：docs/TASK45_V3_RESULTS.md; artifacts/runs/task45_v3/geometry_probe.json; demos/exports/workcell/initial_and_planned.fig

## 第2页：Task 5: upright tool direction

主讲约45秒，包含10秒视频。For Task 5, I keep the same scene, endpoints and base planning settings. The tool's y-axis must follow the world's positive z-axis, while yaw remains free. I add an orientation penalty and use a damped Jacobian projection to correct sampled waypoints and proposed updates. Projection only corrects orientation, so I also add self-collision costs and reject invalid candidates. Final acceptance checks the dense path for joint limits, unchanged endpoints, world and self collisions, and a thirty-five-millimetre conservative clearance. Task 5 additionally requires at most five degrees of tilt.
中文：单击视频。投影不保证碰撞可行，端点、限位、世界和自碰撞仍需独立验收。5度和35毫米为自定标准。

依据：upgrades/task45_v3/matlab/+memberC/projectTrajectory.m; directionJacobian.m; validatePath.m; V3 demo Task5 seed5300

## 第3页：Same problem, different tool orientation

主讲约35秒，包含10秒视频。This paired demonstration uses the same development seed. The blue Task 4 path avoids obstacles but allows the tool to tilt. The green Task 5 path also avoids obstacles and remains upright. The maximum tilt in this demonstration changes from about one hundred and twenty degrees to less than one degree. Both videos show normalized path progress, rather than physical execution time. This is a visual example; the next slide summarizes all held-out runs.
中文：演示种子5300在开发阶段确定。这里的最大角不是正式样本最坏值。两边的播放进度同步不代表机器人执行速度。

依据：artifacts/runs/task45_v3/demos/workcell/Task4/seed_5300/summary.json; Task5/seed_5300/summary.json; paired_motion.avi

## 第4页：Held-out results and contribution

主讲约45秒。We then froze the configuration and evaluated twenty held-out paired seeds. Both tasks succeeded in all twenty runs. The worst Task 5 tilt was about zero point nine nine seven degrees, with at least thirty-five point two three millimetres of conservative clearance. The upright condition required more computation. My contribution includes the workcell, upright projection, self-collision handling and independent replay validation. I also evaluated feasible refinement and tangent sampling. The later adaptive sampler had fewer successes, so I kept it experimental. These results are dense geometric checks, without payload dynamics or a continuous collision guarantee.
中文：正式种子5400–5419，开发5300–5302。时间包含写盘，双进程共享机器。Q只在相同定义内比较。额外加密极值用于本表。

依据：V3 formal/study_summary.json; fine_validation.json; formal_audit.json; docs/TASK45_V3_RESULTS.md

## 第5页：Project overview: Tasks 1 to 5

备份。五项任务的递进关系：功能补全、换机器人、换FK、换复杂场景、加方向约束。具体三人姓名按组内确认填写，不能从函数名推断所有贡献归属。

依据：../EE5112_Project-2_AY26-27.pdf pp.1–2; docs/HANDOFF_MEMBER_C.md; docs/METHODS.md

## 第6页：STOMP iteration in this implementation

备份。先解释Θ为6×61。采样具有路点相关性，概率逐路点归一化，限位/投影后重新计算实际扰动。候选比验收通过还差一步，不能只凭总代价下降声明成功。

依据：matlab/stompSamples.m; stompUpdateProb.m; stompDTheta.m; stompUpdateTheta.m; upgrades/task45_v3/matlab/+memberC/plan.m

## 第7页：PoE forward kinematics

备份。a与p必须统一到空间坐标；q=0的M不同于非零home。固定body不占活动关节变量。原机器22.85倍，本机Windows27.22倍，不能混用。规划代价PoE链不含getTransform，但独立验证/显示可使用MATLAB模型。

依据：docs/METHODS.md; docs/VALIDATION.md; artifacts/runs/final_r2023b/Task3/fk_accuracy.csv; fk_benchmark.csv

## 第8页：Direction constraint and projection

备份。单方向通常为2个独立约束，yaw自由。反向时使用确定性正交修正。投影只改内部点，保持限位；失败候选不参与接受。投影后的路径仍需世界/自碰撞检查。

依据：upgrades/task45_v3/matlab/+memberC/directionJacobian.m; projectTrajectory.m; validatePath.m

## 第9页：What changed across the iterations

备份。V1不是姿态失败而是自碰撞。V3补足桌面与安装合理性。V4/V5的baseline与ambient本身已是Task5约束组。旧版本和失败继续保留。

依据：docs/TASK5_V1_FAILURE_ANALYSIS.md; docs/TASK45_V2_RESULTS.md; TASK45_V3_RESULTS.md; TASK45_V4_RESULTS.md; TASK45_V5_RESULTS.md

## 第10页：V4: refinement and tangent sampling

备份。四组都是Task5。anytime只优化自己的可行incumbent，Q严格下降且每次通过验收。75%切空间+25%普通采样仍经过非线性投影。15.36%为十个配对比例中位数，不是两组中位数相除。

依据：docs/TASK45_V4_RESULTS.md; artifacts/runs/task45_v4/study_summary.json; upgrades/task45_v4/matlab/+memberC/qualityCost.m

## 第11页：V5: three cases, five sampling strategies

备份。冻结后5800–5804，每场景每组5次。Q只对共同成功配对比较。adaptive与fixed50的对照才隔离反馈，二者refinement都固定50%。n=5很小，不能确立普遍可靠性排名。

依据：docs/TASK45_V5_RESULTS.md; artifacts/runs/task45_v5/study_summary.json; formal/**/summary.json

## 第12页：Four V5 failures miss the clearance gate

备份。直接失败分类均proxy_margin，与V1的self_collision不同。有限预算/局部非凸搜索是机制背景，不能声称控制器震荡已被证明导致失败，也不能把保守余量失败直接说成实际撞障碍。

依据：docs/TASK45_V5_RESULTS.md; V5 formalFailures; formal_audit.json

## 第13页：Energy control isolates a sampling effect

备份。这不是等协方差/投影后等方差。最大标量能量差3.55e-14 rad²。修正步数少不自动等于整体规划更快或更优。正式fixed75相对energy_control配对Q中位数-0.31%，7胜8负。

依据：docs/TASK45_V5_METHODS_ZH.md; V5 sampling_ablation.json; sampling_ablation_audit.json; study_summary.json

## 第14页：Demo profiles from the saved dense paths

备份。这里是演示路径的nominal dense CSV，正式表使用额外fine check。原始数据完整保存在图表内嵌工作簿，横轴为归一化路径进度。红线分别为5度/35毫米门槛。

依据：artifacts/runs/task45_v3/demos/workcell/Task4/seed_5300/dense_validation.csv; Task5/seed_5300/dense_validation.csv

## 第15页：Task 4 standalone motion

备份。单独播放Task4。通过碰撞验收并不代表保持直立。该图不含执行时间或杯子模型。

依据：V3 demos/workcell/Task4/seed_5300/summary.json; task4_motion.avi

## 第16页：Evidence, contribution and remaining limits

备份。NumPy验证FK而非碰撞。Git compact正式数据只支持最终路径复核，完整formal随机记录在本机。保留所有失败和旧版本。下一步优先完成全组报告/贡献/总时长整合，不再启动算法版本。

依据：V3/V4/V5 formal_audit.json; fine_validation.json; README_TASK45_V5.md; docs/TASK45_V5_RESULTS.md
