# 输入、复用与开发过程

`received_baseline/` 完整保留用户交来的 RAR 及其 13 个 MATLAB 文件。核对后，这 13 个文件与最初项目模板逐字节相同，仍包含待补位置；用户确认以该 RAR 作为共同基线。`input_comparison.csv` 保留当时的 SHA-256 对照。

最终可运行版本位于仓库根目录 `matlab/`。原始 `sEDT_3d.m` 和 `stompUpdateTheta.m` 保留字节一致；其余补全与适配的逐文件状态在 `file_mapping.csv`，代码差异在 `baseline_diff.patch`。原可视化脚本的作用由最终入口及绘图函数承担，原文件保留在收到的模板目录。

`task1_development/` 保存原场景 IK、实际网格和球包络诊断的脚本/日志，说明为何 Task 1 采用实际网格验收。这些是本次完成 Task 1 时的探索记录；最终权威结果为 `artifacts/runs/final_r2023b`。本次最终 30 个迭代检查点均可用提交的源代码回放。

`SOURCE_SHA256.csv` 记录最终经过验证的 `matlab/` 全部文件。以前交付的独立版和 AB 整合版仍保留在原本地交付文件夹；本仓库使用统一后的最终 Tasks 1/2/3 代码，未混入旧 PDF 报告或过时的待验证结论。
