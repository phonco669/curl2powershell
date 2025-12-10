param(
  [string]$InputFile,
  [string]$InputString
)

[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ResPath = Join-Path $PSScriptRoot 'locale/zh.json'
$RES = $null
if (Test-Path -LiteralPath $ResPath) {
  $RES = Get-Content -Raw -LiteralPath $ResPath -Encoding UTF8 | ConvertFrom-Json
}
if (-not $RES) {
  $RES = [pscustomobject]@{
    title = 'curl -> PowerShell'
    pasteCurl = 'Paste curl command'
    convert = 'Convert'
    copy = 'Copy'
    run = 'Run Test'
    outputTitle = 'Generated PowerShell code'
    convertFail = 'Convert failed: '
    runDone = 'Executed. See console or text box.'
    runFail = 'Run failed: '
    psQueryDefault = 'Enter your test question'
  }
}

function Normalize-CurlText {
  param([string]$t)
  $t = $t -replace "`r`n", "`n"
  $t = $t -replace "`r", "`n"
  $t = [regex]::Replace($t, "\\\\\s*(\r?\n)", "")
  $t = $t -replace "[\u2018\u2019\uFF07]", "'"
  $t = $t -replace "[\u201C\u201D\uFF02]", '"'
  $t = $t.Replace(([char]0x60).ToString(), "")
  $t = $t.Trim()
  return $t
}

function Parse-CurlCommand {
  param([string]$text)
  $t = Normalize-CurlText $text
  $chars = $t.ToCharArray()
  $len = $chars.Length
  $i = 0
  $tokens = New-Object System.Collections.Generic.List[string]
  while ($i -lt $len) {
    while ($i -lt $len -and [char]::IsWhiteSpace($chars[$i])) { $i++ }
    if ($i -ge $len) { break }
    $c = $chars[$i]
    if ($c -eq '"' -or $c -eq "'") {
      $q = $c
      $i++
      $start = $i
      while ($i -lt $len -and $chars[$i] -ne $q) { $i++ }
      $val = $t.Substring($start, $i - $start)
      $tokens.Add($val)
      if ($i -lt $len) { $i++ }
    } else {
      $start = $i
      while ($i -lt $len -and -not [char]::IsWhiteSpace($chars[$i])) { $i++ }
      $val = $t.Substring($start, $i - $start)
      $tokens.Add($val)
    }
  }
  $method = ""
  $url = ""
  $headers = @{}
  $data = ""
  for ($j = 0; $j -lt $tokens.Count; $j++) {
    $tok = $tokens[$j]
    switch -Regex ($tok) {
      '^--request$' { if ($j+1 -lt $tokens.Count) { $method = $tokens[$j+1].ToUpper(); $j++ } }
      '^-X$' { if ($j+1 -lt $tokens.Count) { $method = $tokens[$j+1].ToUpper(); $j++ } }
      '^--url$' { if ($j+1 -lt $tokens.Count) { $url = $tokens[$j+1]; $j++ } }
      '^https?://.+' { if (-not $url) { $url = $tok } }
      '^--header$' { if ($j+1 -lt $tokens.Count) { $kv = $tokens[$j+1]; $j++; $ix = $kv.IndexOf(':'); if ($ix -ge 0) { $k = $kv.Substring(0,$ix).Trim(); $v = $kv.Substring($ix+1).Trim(); $headers[$k] = $v } } }
      '^-H$' { if ($j+1 -lt $tokens.Count) { $kv = $tokens[$j+1]; $j++; $ix = $kv.IndexOf(':'); if ($ix -ge 0) { $k = $kv.Substring(0,$ix).Trim(); $v = $kv.Substring($ix+1).Trim(); $headers[$k] = $v } } }
      '^--data(?:-raw|-binary)?$' { if ($j+1 -lt $tokens.Count) { $data = $tokens[$j+1]; $j++ } }
      '^-d$' { if ($j+1 -lt $tokens.Count) { $data = $tokens[$j+1]; $j++ } }
    }
  }
  if (-not $method) { if ($data) { $method = "POST" } else { $method = "GET" } }
  $contentType = ""
  if ($headers.ContainsKey("Content-Type")) { $contentType = $headers["Content-Type"] }
  elseif ($data) { if ($data.Trim().StartsWith("{")) { $contentType = "application/json" } else { $contentType = "application/x-www-form-urlencoded" } }
  [pscustomobject]@{ Method = $method; Url = $url; Headers = $headers; Body = $data; ContentType = $contentType }
}

function Build-PSInvoke {
  param($spec)
  $sb = New-Object System.Text.StringBuilder
  if ($spec.Body -and $spec.Body.Contains("{{query}}")) {
    [void]$sb.AppendLine("$" + "query = '" + $RES.psQueryDefault + "'")
  }
  [void]$sb.AppendLine("$" + "headers = @{")
  foreach ($k in $spec.Headers.Keys) {
    $v = $spec.Headers[$k].Replace("'", "''")
    [void]$sb.AppendLine("  '$k' = '$v'")
  }
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("$" + "method = '" + $spec.Method + "'")
  [void]$sb.AppendLine("$" + "uri = '" + $spec.Url + "'")
  $hasBody = [string]::IsNullOrEmpty($spec.Body) -eq $false
  if ($hasBody) {
    $bodyText = $spec.Body
    [void]$sb.AppendLine('$' + 'body = @"')
    [void]$sb.AppendLine($bodyText)
    [void]$sb.AppendLine('"@')
    if ($spec.Body.Contains("{{query}}")) {
      [void]$sb.AppendLine("$" + "body = $" + "body.Replace('{{query}}', $" + "query)")
    }
  }
  $cmd = "Invoke-RestMethod -Uri $" + "uri -Method $" + "method"
  if ($spec.Headers.Count -gt 0) { $cmd += " -Headers $" + "headers" }
  if ($spec.ContentType) { $cmd += " -ContentType '" + $spec.ContentType + "'" }
  if ($hasBody) { $cmd += " -Body $" + "body" }
  [void]$sb.AppendLine("$" + "response = " + $cmd)
  [void]$sb.AppendLine("$" + "response | ConvertTo-Json -Depth 10")
  $sb.ToString()
}

function Show-GUI {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $RES.title
  $form.StartPosition = "CenterScreen"
  $form.Size = New-Object System.Drawing.Size(900,950)
  $labelIn = New-Object System.Windows.Forms.Label
  $labelIn.Text = $RES.pasteCurl
  $labelIn.Location = New-Object System.Drawing.Point(10,10)
  $labelIn.AutoSize = $true
  $tbIn = New-Object System.Windows.Forms.TextBox
  $tbIn.Multiline = $true
  $tbIn.ScrollBars = "Vertical"
  $tbIn.Font = New-Object System.Drawing.Font("Microsoft YaHei UI",10)
  $tbIn.Size = New-Object System.Drawing.Size(860,240)
  $tbIn.Location = New-Object System.Drawing.Point(10,30)
  $btnConvert = New-Object System.Windows.Forms.Button
  $btnConvert.Text = $RES.convert
  $btnConvert.Size = New-Object System.Drawing.Size(80,32)
  $btnConvert.Location = New-Object System.Drawing.Point(10,280)
  $btnCopy = New-Object System.Windows.Forms.Button
  $btnCopy.Text = $RES.copy
  $btnCopy.Size = New-Object System.Drawing.Size(80,32)
  $btnCopy.Location = New-Object System.Drawing.Point(100,280)
  $btnRun = New-Object System.Windows.Forms.Button
  $btnRun.Text = $RES.run
  $btnRun.Size = New-Object System.Drawing.Size(100,32)
  $btnRun.Location = New-Object System.Drawing.Point(190,280)
  $labelOut = New-Object System.Windows.Forms.Label
  $labelOut.Text = $RES.outputTitle
  $labelOut.Location = New-Object System.Drawing.Point(10,320)
  $labelOut.AutoSize = $true
  $tbOut = New-Object System.Windows.Forms.TextBox
  $tbOut.Multiline = $true
  $tbOut.ScrollBars = "Vertical"
  $tbOut.ReadOnly = $true
  $tbOut.Font = New-Object System.Drawing.Font("Microsoft YaHei UI",10)
  $tbOut.Size = New-Object System.Drawing.Size(860,240)
  $tbOut.Location = New-Object System.Drawing.Point(10,340)
  $labelResult = New-Object System.Windows.Forms.Label
  $labelResult.Text = $RES.resultTitle
  $labelResult.Location = New-Object System.Drawing.Point(10,590)
  $labelResult.AutoSize = $true
  $tbResult = New-Object System.Windows.Forms.TextBox
  $tbResult.Multiline = $true
  $tbResult.ScrollBars = "Vertical"
  $tbResult.ReadOnly = $true
  $tbResult.Font = New-Object System.Drawing.Font("Microsoft YaHei UI",10)
  $tbResult.Size = New-Object System.Drawing.Size(860,240)
  $tbResult.Location = New-Object System.Drawing.Point(10,610)
  $form.Controls.AddRange(@($labelIn,$tbIn,$btnConvert,$btnCopy,$btnRun,$labelOut,$tbOut,$labelResult,$tbResult))
  $btnConvert.Add_Click({
    try {
      $spec = Parse-CurlCommand $tbIn.Text
      $code = Build-PSInvoke $spec
      $tbOut.Text = $code
    } catch {
      $tbOut.Text = $RES.convertFail + $_.Exception.Message
    }
  })
  $btnCopy.Add_Click({
    if ($tbOut.Text) { [System.Windows.Forms.Clipboard]::SetText($tbOut.Text) }
  })
  $btnRun.Add_Click({
    try {
      if (-not $tbOut.Text) {
        $spec = Parse-CurlCommand $tbIn.Text
        $tbOut.Text = Build-PSInvoke $spec
      }
      $ErrorActionPreference = 'Stop'
      $output = & ([scriptblock]::Create($tbOut.Text)) 2>&1 | Out-String
      $tbResult.Text = $output
    } catch {
      $tbResult.Text = $RES.runFail + $_.Exception.Message
    }
  })
  $form.ShowDialog() | Out-Null
}

if ($InputFile -or $InputString) {
  $src = $InputString
  if ($InputFile) { $src = Get-Content -Raw -LiteralPath $InputFile -Encoding UTF8 }
  $spec = Parse-CurlCommand $src
  $code = Build-PSInvoke $spec
  Write-Output $code
} else {
  Show-GUI
}

