$ErrorActionPreference = "Stop"
$baseUrl = "https://api.amediateka.tech/gateway/v1/cms/content/series?limit=20&offset=0&ordering=-last_publish_date&platform=amediaWeb"
$allSeries = @()
$url = $baseUrl
$page = 0

while ($url -ne $null) {
    Write-Output "Fetching page $page..."
    $resp = Invoke-RestMethod -Uri $url -Method Get
    $allSeries += $resp.results
    $url = $resp.next
    $page++
    Write-Output "  Got $($resp.results.Count) series, total: $($allSeries.Count)"
}

Write-Output "=== TOTAL: $($allSeries.Count) series ==="
$allSeries | ConvertTo-Json -Depth 10 | Out-File "D:\GitHub\amediateka_series.json" -Encoding utf8
Write-Output "Saved to D:\GitHub\amediateka_series.json"
