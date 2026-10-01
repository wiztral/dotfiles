Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Start GlazeWM at logon via a shortcut in the user's Startup folder.
$target = "$HOME\scoop\apps\glazewm\current\glazewm.exe"
if (-not (Test-Path $target)) {
    Write-Output "GlazeWM not found at $target, skipping startup shortcut."
    return
}

$shortcutPath = Join-Path ([Environment]::GetFolderPath("Startup")) "GlazeWM.lnk"
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcutPath)
$shortcut.TargetPath = $target
$shortcut.WorkingDirectory = Split-Path $target
$shortcut.Save()
Write-Output "Created $shortcutPath"
