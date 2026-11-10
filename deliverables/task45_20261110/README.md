# Task 4–5 汇报包（2026-11-10）

这份材料以已冻结的 V3 作为课程 Task 4/5 对照，以 V4/V5 作为算法扩展。没有重新调参，也没有覆盖历史结果。

## 先打开什么

1. `task45_main.pptx`：4 页英文主讲页，视频已经嵌入，建议约 3 分钟；直接并入全组约 7 分钟的展示。
2. `task45_full.pptx`：相同 4 页加答辩备份页；附中文备注、数据来源和可编辑统计表。
3. `speaker_script_zh_en.md` / `.pdf`：英文口述稿、中文逐页理解、视频操作和时间安排。
4. `project_understanding_zh.md` / `.pdf`：完整项目理解稿，覆盖 Task 1–5、关键公式、代码调用、各轮迭代与答辩。
5. `task45_report_section_en.md` / `.pdf`：可交给队友整合的英文报告小节。

`task45_full.pdf` 是静态备份，不能播放视频。`media/` 中有同源 MP4，PPT 视频播放不便时可独立播放。`evidence/` 保存本次使用的原始图、数据摘要、图源和路径索引。可编辑 MATLAB FIG 仍在原版本目录。

## 结论口径

- V3：同一安装工作台、端点和种子，Task 4 与 Task 5 分别 20/20 成功。Task 5 最坏倾角约 0.997°，加密验证阈值为 5°。
- V4：四组各 10/10。联合扩展相对基线的配对 Q 降幅中位数 15.36%，但 3 个种子更差，并增加总计算时间。
- V5：75 次中 71 次通过。fixed75 为 15/15，adaptive 为 13/15。4 次失败均未达到 35 mm 保守余量，不能删掉。
- V5 自适应相对 fixed75 的 4.60% Q 改善仅基于 13 个共同成功配对，不能替代成功率比较。
- 目前停止新增算法版本，保留 fixed75 作为扩展比较基线，adaptive 保持实验选项。
- 35 mm 与 5° 是我们的工程验收标准。验证为离散加密检查，没有连续碰撞、载荷、动力学或实机执行保证。

## 使用和整合

在桌面 PowerPoint 中打开 PPTX，按 F5 放映。主讲第 2、3 页的视频单击后播放，每段 10 秒；第 3 页为 Task 4/5 并排对照。视频进度是归一化路径进度，不代表机器人执行时间。不要把 PDF 当作含视频的演示版本。

本机双击 PPTX 默认可能打开 WPS；请用“打开方式 → PowerPoint”。本次已实际检查 PowerPoint 放映中的两个主讲视频。完整 PPT 的第 5–16 页默认隐藏，答辩时可在左侧选择该页后“从当前幻灯片开始”放映。

若要看 MATLAB 全项目，在仓库根目录执行：

```matlab
addpath('scripts')
show_project_demo('all','v3')
show_task45_v4('benchmark')
show_task45_v5('benchmark')
```

本包只完成成员 C 的汇报材料和全项目理解辅助。全组仍须确定组号、三人姓名/贡献、统一总报告和约 7 分钟总展示，按原项目说明于 2026-11-12 16:00（新加坡时间）提交一个 ZIP。个人/分组 Canvas 时段未在本包中核验。

## 可追溯与重建

本次整理所依据的提交为 `fea847b684e1c777fe9715a13a9a6fae08f2919c`。`source/build_delivery.py` 使用本机 PowerPoint COM 构建和导出，使用 FFmpeg 将原始 MJPEG AVI 转成 H.264 MP4。`source/check_delivery.py` 检查嵌入媒体、页数、关键数值、解码和文件清单。构建不修改冻结实验文件。

需要重建时，在仓库根目录运行（已有结果应先另存）：

```powershell
py -3.12 -X utf8 deliverables/task45_20261110/source/build_delivery.py
py -3.12 -X utf8 deliverables/task45_20261110/source/repair_layout.py
py -3.12 -X utf8 deliverables/task45_20261110/source/check_delivery.py
```

`backup_notes_zh.md` 导出了全部 16 页的中文备注与证据路径。`FILES_SHA256.csv` 对最终文件逐个记录校验值。本机整包 ZIP 位于本文件夹旁边；GitHub 仅提交目录内的单独文件，ZIP 为本地方便交接的重复档案。

运行构建前应在新目录保留旧版汇报包。没有用户提供的学校 PPT 模板，本包采用白底、深蓝文字，实验 Task 4 为蓝色、Task 5 为绿色。
