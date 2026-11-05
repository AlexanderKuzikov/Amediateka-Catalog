$ErrorActionPreference = "Stop"
Write-Output "Collecting data..."

$baseUrl = "https://api.amediateka.tech/gateway/v1/cms/content/series?limit=20&offset=0&ordering=-last_publish_date&platform=amediaWeb"
$allSeries = @()
$url = $baseUrl
$page = 0

while ($url) {
    Write-Output "Page $page..."
    $wc = New-Object System.Net.WebClient
    $bytes = $wc.DownloadData($url)
    $jsonText = [System.Text.Encoding]::UTF8.GetString($bytes)
    $resp = $jsonText | ConvertFrom-Json
    $allSeries += $resp.results
    $url = $resp.next
    $page++
}

Write-Output "Total: $($allSeries.Count)"

# Read template with explicit UTF-8
Write-Output "Reading template..."
$template = Get-Content "D:\GitHub\template.html" -Raw -Encoding UTF8
if (-not $template) { throw "Template not found" }

# Collect genres & years
$allGenres = @{}
$allYears = @{}
$rowsHtml = ""

foreach ($s in $allSeries) {
    $title = $s.title
    $desc = if ($s.shortDescription) { $s.shortDescription } else { "" }
    $poster = if ($s.assets.productPoster) { $s.assets.productPoster -replace "{SIZE}", "400x600" } else { "" }
    $webUrl = "https://www.amediateka.ru$($s.webUrl)"
    
    $genreTags = ""
    if ($s.genres) {
        $tags = @()
        foreach ($g in $s.genres) { $tags += "<span class='genre-tag'>$($g.name)</span>"; $allGenres[$g.name] = $true }
        $genreTags = $tags -join ""
    }
    
    $year = if ($s.premierYear) { "$($s.premierYear)" } else { "" }
    if ($year) { $allYears[$year] = $true }
    
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $fmt = { param($v) [string]::Format($inv, "{0:F1}", [double]$v) }
    $ratingAm = if ($s.ratingAmediateka) { "<span class='rating rating-am'>$( & $fmt $s.ratingAmediateka )</span>" } else { "<span class='rating rating-am'>-</span>" }
    if ($s.ratingImdb) { $ratingImdb = "<span class='rating rating-imdb'>$( & $fmt $s.ratingImdb )</span>" } else { $ratingImdb = "<span class='rating-na'>-</span>" }
    if ($s.ratingKinopoisk) { $ratingKp = "<span class='rating rating-kp'>$( & $fmt $s.ratingKinopoisk )</span>" } else { $ratingKp = "<span class='rating-na'>-</span>" }
    
    $seasons = if ($s.seasons) { "$($s.seasons)" } else { "-" }
    $imgTag = if ($poster) { "<img src='$poster' alt='$title' loading='lazy'>" } else { "" }
    $descBlock = if ($desc) { "<span class='desc-text'>$desc</span>" } else { "" }
    
    $genreList = if ($s.genres) { (($s.genres | ForEach-Object { $_.name }) -join '|') } else { '' }
    $rowsHtml += @"
<tr data-genres='$genreList'>
  <td class='title-col'><div class='title-wrap'>$imgTag<div class='title-info'><a href='$webUrl' target='_blank'>$title</a>$descBlock</div></div></td>
  <td class='genre-col'>$genreTags</td>
  <td class='year-col'>$year</td>
  <td class='rating-col'>$ratingAm</td>
  <td class='rating-col'>$ratingImdb</td>
  <td class='rating-col'>$ratingKp</td>
  <td class='seasons-col'>$seasons</td>
</tr>
"@
}

$genreCheckboxes = ($allGenres.Keys | Sort-Object | ForEach-Object { "<label><input type='checkbox' value='$_'> $_</label>" }) -join "`n"
$yearOpts = ($allYears.Keys | Sort-Object -Descending | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"

# Replace placeholders
$html = $template -replace "__COUNT__", "$($allSeries.Count)"
$html = $html -replace "__GENRES_CHECKBOXES__", $genreCheckboxes
$html = $html -replace "__YEARS__", $yearOpts
$html = $html -replace "__ROWS__", $rowsHtml

# Write with UTF-8 BOM (PowerShell-friendly)
$html | Out-File "D:\GitHub\amediateka_catalog_v3.html" -Encoding UTF8
Write-Output "=== DONE ==="
$bytes = [System.IO.File]::ReadAllBytes("D:\GitHub\amediateka_catalog_v3.html")
Write-Output "$($allSeries.Count) series, $($bytes.Length) bytes written to amediateka_catalog_v3.html"
