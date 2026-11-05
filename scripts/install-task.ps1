$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'scripts\monthly.ps1'
if (-not (Test-Path $script)) { throw "Не найден $script" }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $script + '"')
$trigger = New-ScheduledTaskTrigger -Daily -At '10:17'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'Amediateka Catalog Monthly Build' -Action $action -Trigger $trigger -Settings $settings -Description 'Ежемесячное обновление каталога Amediateka: ежедневная проверка, обновление раз в месяц.' -Force | Out-Null
Write-Output 'Задача зарегистрирована: Amediateka Catalog Monthly Build (проверка ежедневно в 10:17, обновление раз в месяц).'
