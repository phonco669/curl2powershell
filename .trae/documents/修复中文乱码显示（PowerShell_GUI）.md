## 问题与目标
- 问题：生成的 PowerShell 测试语句中中文显示为乱码（控制台与GUI）。
- 目标：保证脚本、控制台输出、GUI文本框、读取示例文件在 UTF-8 下正确显示中文。

## 修改点
- 设置脚本运行时编码（tools/curl2ps.ps1:1-4 之后）
  - 添加：`[Console]::InputEncoding = [System.Text.Encoding]::UTF8`
  - 添加：`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
  - 添加：`$OutputEncoding = [System.Text.Encoding]::UTF8`
- 读取文件时指定编码（tools/curl2ps.ps1:186）
  - 将 `Get-Content -Raw -LiteralPath $InputFile` 改为 `Get-Content -Raw -LiteralPath $InputFile -Encoding UTF8`
- GUI字体替换为中文友好字体（tools/curl2ps.ps1:130, 153）
  - 将 `System.Drawing.Font("Consolas",10)` 替换为 `System.Drawing.Font("Microsoft YaHei UI",10)`（微软雅黑 UI），保证中文显示。
- 批处理一键启动时设置控制台代码页（start.bat）
  - 在调用 PowerShell 前添加：`chcp 65001 > nul`

## 验证方案
- 命令行验证：运行 `tools\curl2ps.ps1 -InputFile tools\sample.curl`，确认输出中的 `$query = '在这里填写测试问题'` 正常显示。
- GUI验证：通过 `start.bat` 打开界面，粘贴示例 curl，点击“转换”，确认中文正常显示；点击“运行测试”，观察返回 JSON 中中文是否正常。
- 兼容性检查：PowerShell 7+与Windows PowerShell 5.1均通过上述设置解决中文编码问题。

## 预期影响
- 不改变业务逻辑，仅提升中文显示与请求体中文内容的可靠性。
- 若本机缺少“Microsoft YaHei UI”，可回退为系统默认字体（我可在实现时做降级处理）。

## 下一步
- 我将按上述修改点更新文件并执行本地验证；如需同时将运行结果追加到 GUI 输出框，顺带加入结果展示以便快速查看。