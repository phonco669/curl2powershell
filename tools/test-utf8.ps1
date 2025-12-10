$code = & "$PSScriptRoot/curl2ps.ps1" -InputFile "$PSScriptRoot/sample.curl"
if ($code -match '在这里填写测试问题') { Write-Output 'OK' } else { Write-Output 'FAIL' }
