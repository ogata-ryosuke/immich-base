# backup-db.ps1 を Windows タスクスケジューラに日次登録する。
# 管理者 PowerShell で実行:  .\scripts\register-backup-task.ps1
# 既定は毎日 03:30。時刻は -At で変更可。

param(
    [string]$At = '03:30',
    [string]$TaskName = 'immich-db-backup'
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'backup-db.ps1'

$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -DontStopOnIdleEnd -RunOnlyIfNetworkAvailable:$false
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force

Write-Host "登録した: タスク '$TaskName' 毎日 $At" -ForegroundColor Green
Write-Host "手動実行テスト:  Start-ScheduledTask -TaskName $TaskName"
