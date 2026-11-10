# 本地实验文件与 Git

2026-11-09：Source Control 中大量未跟踪文件来自逐轮实验检查点、开发试验、日志和图像复核副本。它们继续保留在原路径。代码、正式最终轨迹、统计、演示和交付材料分批提交。

运行 `py -3.12 scripts/configure_local_artifacts.py` 可在当前仓库的 `.git/info/exclude` 中写入明确的本地排除规则。脚本保留其他已有规则，不修改全局配置或冻结的根 `.gitignore`；已跟踪文件发生修改时仍然正常显示。

排除范围包括：

- `artifacts/audits/` 中未跟踪的本机复核副本和中间文件。已提交的审计 JSON 仍受版本控制。
- V1 开发、诊断、演示、正式逐轮记录和技术中断档案。历史配置、汇总及交付材料已提交。
- V2/V3 的正式 `iterations/` 和 `input_checkpoint.mat`、开发记录、顶层运行日志以及交付材料的复核图片。
- V3 的实时 worker 进度文件。最终统计、轨迹、演示、复核结论和交付文件完成后另行提交。

完整匹配模式以脚本中的 `PATTERNS` 为准。`git status --ignored` 可查看被排除的目录；`git add -f -- <明确路径>` 可按需归档其中的文件。取消本地排除时，删除 `.git/info/exclude` 中两个 `EE5112 retained local experiment archives` 标记之间的区块即可。

这些规则用于整理本机文件列表，不表示原始证据可以删除。完整逐轮回放需要本地原始档案；精简 Git 快照的边界见 [GIT_SNAPSHOT.md](../GIT_SNAPSHOT.md)。旧版本完整发布清单及 QA 记录继续保持原始内容。
