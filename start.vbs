Set sh = CreateObject("WScript.Shell")
cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & CreateObject("Scripting.FileSystemObject").GetAbsolutePathName("tools\curl2ps.ps1") & """"
sh.Run cmd, 0, False
