## 问题复盘
- GUI点击“转换”出现 WinForms 未处理异常提示“The pipeline has been stopped”。
- 可能成因：
  - 解析阶段对引号/续行符处理不够稳健，遇到不匹配引号或特殊引号导致异常。
  - 事件线程未被统一异常捕获，WinForms抛出线程异常弹窗。
  - 运行按钮使用 `Invoke-Expression` 使管道终止时出现该提示。

## 修复方案
### 1. 输入归一化增强
- 在 `Normalize-CurlText` 增加：
  - 统一替换智能引号与全角引号：`‘’“”「」『』` → `'"'`。
  - 删除行尾续行符：`\ + CRLF` 直接拼接为单行，不插入空格，避免 JSON 断行偏差。
  - 保留正文中的反引号，仅处理 URL 周围的 POSIX 反引号移除。

### 2. 解析器健壮化
- 保留当前逐字符分词器，但做两点改进：
  - 未闭合引号时，直接吞到文本末尾，不抛异常；允许多行 `--data` JSON。
  - 支持 `--data`/`-d` 后紧跟的单引号和双引号内容跨行抓取；保留原始换行。
- 额外兼容：若未显式 `--url`，但首 token 为 `curl` 后紧跟 URL，自动识别。

### 3. GUI异常处理
- 全局设置 WinForms 异常为捕获模式：`[System.Windows.Forms.Application]::SetUnhandledExceptionMode('CatchException')`。
- 注册 `AppDomain.CurrentDomain.UnhandledException` 与 `Application.ThreadException` 事件，将错误写入底部输出框而非弹窗。
- 在按钮事件中加入 `$ErrorActionPreference = 'Stop'`，确保 try/catch 生效。

### 4. 执行方式优化
- 将“运行测试”由 `Invoke-Expression` 改为 `& ([scriptblock]::Create($tbOut.Text))`，并捕获输出与错误，避免管道终止提示。

### 5. 验证
- 使用你截图中的 curl（包含中文内容）粘贴到 GUI，点击“转换”无弹窗；生成的 PowerShell 语句含中文正常显示。
- 点击“运行测试”返回 JSON（或错误信息）展示在底部输出框，无黑窗（通过 `start.vbs`）。

## 影响与回滚
- 仅增强解析与异常处理，不影响已有功能；若解析不符合预期我将保留回滚点，按需调整匹配规则。