param([switch]$Force)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$dataFile = Join-Path $root 'data\series.json'
$need = $true
if (Test-Path $dataFile) {
  try {
    $json = Get-Content $dataFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $updated = [datetimeoffset]::Parse($json.updatedAt).LocalDateTime
    $now = Get-Date
    $need = ($updated.Year -ne $now.Year) -or ($updated.Month -ne $now.Month)
  } catch { $need = $true }
}

if (-not $Force -and -not $need) {
  Write-Output 'Данные уже обновлены в этом месяце.'
  exit 0
}

node scripts/fetch.mjs
if ($LASTEXITCODE -ne 0) { throw 'fetch failed' }

node scripts/build.mjs
if ($LASTEXITCODE -ne 0) { throw 'build failed' }

git add data dist
if (git diff --cached --quiet) {
  Write-Output 'Изменений нет.'
  exit 0
}

$date = Get-Date -Format 'yyyy-MM-dd'
git commit -m "Обновить каталог: $date"
git pull --rebase origin main
git push origin main
