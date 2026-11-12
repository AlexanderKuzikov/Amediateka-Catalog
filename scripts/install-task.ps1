$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vbs = Join-Path $root 'scripts\monthly-hidden.vbs'
if (-not (Test-Path $vbs)) { throw "Не найден $vbs" }

$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('"' + $vbs + '"')
$trigger = New-ScheduledTaskTrigger -Daily -At '10:17'
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'Amediateka Catalog Monthly Build' -Action $action -Trigger $trigger -Settings $settings -Description 'Ежемесячное обновление каталога Amediateka: ежедневная проверка, обновление раз в месяц. Запуск без окна, лог в logs/monthly.log.' -Force | Out-Null
Write-Output 'Задача зарегистрирована: Amediateka Catalog Monthly Build (проверка ежедневно в 10:17, обновление раз в месяц, без окна).'
