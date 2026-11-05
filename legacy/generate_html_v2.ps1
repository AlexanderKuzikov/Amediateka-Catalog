$ErrorActionPreference = "Stop"
Write-Output "=== Collecting data (UTF-8 safe) ==="

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
    Write-Output "  +$($resp.results.Count) = $($allSeries.Count)"
}

Write-Output "=== Total: $($allSeries.Count) ==="

# Collect genres and years
$allGenres = @{}
$allYears = @{}
$rows = @()

foreach ($s in $allSeries) {
    $title = $s.title
    $desc = if ($s.shortDescription) { $s.shortDescription } else { "" }
    $poster = if ($s.assets.productPoster) { $s.assets.productPoster -replace "{SIZE}", "150x225" } else { "" }
    $webUrl = "https://www.amediateka.ru$($s.webUrl)"
    
    $genreNames = @()
    if ($s.genres) {
        foreach ($g in $s.genres) { $genreNames += $g.name; $allGenres[$g.name] = $true }
    }
    
    $year = if ($s.premierYear) { "$($s.premierYear)" } else { "" }
    if ($year) { $allYears[$year] = $true }
    
    $ratingAm = if ($s.ratingAmediateka) { "{0:F1}" -f [double]$s.ratingAmediateka } else { "-" }
    $ratingImdbVal = if ($s.ratingImdb) { "{0:F1}" -f [double]$s.ratingImdb } else { $null }
    $ratingKpVal = if ($s.ratingKinopoisk) { "{0:F1}" -f [double]$s.ratingKinopoisk } else { $null }
    $seasons = if ($s.seasons) { "$($s.seasons)" } else { "-" }
    
    $rows += @{
        title = $title
        desc = $desc
        poster = $poster
        webUrl = $webUrl
        genreNames = $genreNames
        year = $year
        ratingAm = $ratingAm
        ratingImdb = $ratingImdbVal
        ratingKp = $ratingKpVal
        seasons = $seasons
    }
}

Write-Output "Generating HTML..."

# Build rows HTML with proper escaping
$rowsHtml = ""
foreach ($r in $rows) {
    $imgTag = if ($r.poster) { "<img src='$($r.poster)' alt='$($r.title)' loading='lazy'>" } else { "" }
    $descTag = if ($r.desc) { "<span class='desc-text'>$($r.desc)</span>" } else { "" }
    $genreTags = ($r.genreNames | ForEach-Object { "<span class='genre-tag'>$_</span>" }) -join ""
    
    $ratingImdbHtml = if ($r.ratingImdb) { "<span class='rating rating-imdb'>$($r.ratingImdb)</span>" } else { "<span class='rating-na'>-</span>" }
    $ratingKpHtml = if ($r.ratingKp) { "<span class='rating rating-kp'>$($r.ratingKp)</span>" } else { "<span class='rating-na'>-</span>" }
    
    $rowsHtml += @"
<tr>
  <td class='poster-col'>$imgTag</td>
  <td class='title-col'><a href='$($r.webUrl)' target='_blank'>$($r.title)</a>$descTag</td>
  <td class='genre-col'>$genreTags</td>
  <td class='year-col'>$($r.year)</td>
  <td class='rating-col'><span class='rating rating-am'>$($r.ratingAm)</span></td>
  <td class='rating-col'>$ratingImdbHtml</td>
  <td class='rating-col'>$ratingKpHtml</td>
  <td class='seasons-col'>$($r.seasons)</td>
</tr>
"@
}

# Build genre options
$genreOpts = ($allGenres.Keys | Sort-Object | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
$yearOpts = ($allYears.Keys | Sort-Object -Descending | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"

# Read template from separate file to avoid quoting issues
$template = @'
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Каталог сериалов Amediateka</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0d0d12;color:#e0e0e0}
.header{background:linear-gradient(135deg,#1a1a2e 0%,#16213e 50%,#0f3460 100%);padding:30px 20px;text-align:center;border-bottom:1px solid #2a2a3e;position:sticky;top:0;z-index:100}
.header h1{font-size:26px;font-weight:700;color:#fff;margin-bottom:6px}
.header p{color:#888;font-size:13px}
.container{max-width:1500px;margin:0 auto;padding:16px}
.controls{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:14px;align-items:center;background:#151520;padding:12px 16px;border-radius:12px;border:1px solid #222}
.controls input,.controls select{padding:8px 12px;border-radius:8px;border:1px solid #333;background:#1e1e2e;color:#e0e0e0;font-size:13px}
.controls input:focus,.controls select:focus{outline:none;border-color:#4a9eff}
.controls input{flex:1;min-width:180px}
.stats-bar{color:#666;font-size:13px;padding:6px 0 10px 0;display:flex;justify-content:space-between}
#resetBtn{padding:8px 16px;border-radius:8px;border:none;background:#4a9eff;color:#fff;font-size:13px;cursor:pointer}
#resetBtn:hover{background:#3a8eef}
.table-wrap{overflow-x:auto;border-radius:12px;border:1px solid #1e1e2e;background:#111118}
table{width:100%;border-collapse:collapse;min-width:800px}
th{position:sticky;top:108px;background:#1a1a2e;padding:10px 8px;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:#888;border-bottom:2px solid #2a2a3e;cursor:pointer;user-select:none;white-space:nowrap;z-index:50}
th:hover{color:#4a9eff}
th.sorted{color:#4a9eff}
td{padding:8px;border-bottom:1px solid #191925;font-size:13px;vertical-align:middle}
tr:hover td{background:rgba(74,158,255,0.04)}
.poster-col{width:60px;min-width:60px;text-align:center}
.poster-col img{width:45px;height:67px;object-fit:cover;border-radius:4px;display:block}
.title-col{font-weight:600;color:#fff;min-width:200px}
.title-col a{color:#4a9eff;text-decoration:none;font-size:14px}
.title-col a:hover{text-decoration:underline}
.desc-text{font-size:11px;color:#777;font-weight:400;display:block;margin-top:2px;max-width:350px;line-height:1.3}
.genre-col{min-width:160px}
.genre-tag{display:inline-block;padding:2px 7px;border-radius:8px;font-size:10px;background:rgba(74,158,255,0.12);color:#5aaeff;margin:1px;white-space:nowrap}
.rating{font-weight:700;font-size:14px}
.rating-col{text-align:center;min-width:55px}
.rating-am{color:#4a9eff}
.rating-imdb{color:#f5c518}
.rating-kp{color:#ff6600}
.rating-na{color:#444;font-size:12px}
.year-col{color:#aaa;text-align:center;min-width:50px}
.seasons-col{color:#888;text-align:center;min-width:45px}
.hidden{display:none!important}
@media(max-width:768px){.container{padding:8px}td,th{padding:5px 3px;font-size:11px}.poster-col{width:40px;min-width:40px}.poster-col img{width:32px;height:48px}.title-col{min-width:120px}.genre-col{min-width:100px}}
</style>
</head>
<body>
<div class="header">
<h1>&#128250; Каталог сериалов Amediateka</h1>
<p>Всего сериалов: <span id="totalCount">__COUNT__</span> &middot; данные на 18 июля 2026</p>
</div>
<div class="container">
<div class="controls">
<input type="text" id="searchInput" placeholder="Поиск по названию, жанру, описанию..." oninput="filterTable()">
<select id="genreFilter" onchange="filterTable()"><option value="">Все жанры</option>__GENRES__</select>
<select id="yearFilter" onchange="filterTable()"><option value="">Все годы</option>__YEARS__</select>
<select id="sortSelect" onchange="applySort()">
<option value="year-desc">По году &darr;</option>
<option value="year-asc">По году &uarr;</option>
<option value="ratingAm-desc">По рейтингу Amediateka &darr;</option>
<option value="ratingAm-asc">По рейтингу Amediateka &uarr;</option>
<option value="ratingImdb-desc">По рейтингу IMDB &darr;</option>
<option value="ratingKp-desc">По рейтингу Кинопоиск &darr;</option>
<option value="title-asc">По названию А-Я</option>
<option value="title-desc">По названию Я-А</option>
<option value="seasons-desc">По сезонам &darr;</option>
</select>
<button id="resetBtn" onclick="resetFilters()">Сброс</button>
</div>
<div class="stats-bar"><span id="stats">Показано: <b>__COUNT__</b> из __COUNT__</span><span>Нажми на заголовок столбца для сортировки</span></div>
<div class="table-wrap">
<table id="seriesTable">
<thead><tr>
<th class="poster-col"></th>
<th data-col="title" onclick="sortBy('title')">Название</th>
<th data-col="genre" onclick="sortBy('genre')">Жанры</th>
<th data-col="year" onclick="sortBy('year')" class="sorted">Год</th>
<th data-col="ratingAm" onclick="sortBy('ratingAm')">Amediateka</th>
<th data-col="ratingImdb" onclick="sortBy('ratingImdb')">IMDB</th>
<th data-col="ratingKp" onclick="sortBy('ratingKp')">Кинопоиск</th>
<th data-col="seasons" onclick="sortBy('seasons')">Сезонов</th>
</tr></thead>
<tbody id="tableBody">
__ROWS__
</tbody>
</table>
</div>
</div>
<script>
var cs={col:"year",dir:"desc"};
function ft(){var s=document.getElementById("searchInput").value.toLowerCase(),g=document.getElementById("genreFilter").value,y=document.getElementById("yearFilter").value,rows=document.querySelectorAll("#tableBody tr"),v=0;rows.forEach(function(r){var t=r.textContent.toLowerCase(),gc=(r.querySelector(".genre-col")||{}).textContent||"",yc=(r.querySelector(".year-col")||{}).textContent||"";if((!s||t.indexOf(s)>=0)&&(!g||gc.indexOf(g)>=0)&&(!y||yc==y)){r.classList.remove("hidden");v++}else r.classList.add("hidden")});document.getElementById("stats").innerHTML="Показано: <b>"+v+"</b> из "+rows.length}
function rf(){document.getElementById("searchInput").value="";document.getElementById("genreFilter").value="";document.getElementById("yearFilter").value="";document.getElementById("sortSelect").value="year-desc";cs={col:"year",dir:"desc"};as();ft()}
function sb(col){if(cs.col===col)cs.dir=cs.dir==="asc"?"desc":"asc";else{cs.col=col;cs.dir="desc"}document.getElementById("sortSelect").value=col+"-"+cs.dir;as();document.querySelectorAll("th").forEach(function(t){t.classList.remove("sorted")});var h=document.querySelector('th[data-col="'+col+'"]');if(h)h.classList.add("sorted")}
function as(){var v=document.getElementById("sortSelect").value,p=v.split("-"),col=p[0],dir=p[1];cs={col:col,dir:dir};var tb=document.getElementById("tableBody"),rows=Array.from(tb.querySelectorAll("tr"));rows.sort(function(a,b){var av,bv;switch(col){case"title":av=(a.querySelector(".title-col a")||{}).textContent||"";bv=(b.querySelector(".title-col a")||{}).textContent||"";return dir==="asc"?av.localeCompare(bv):bv.localeCompare(av);case"year":av=parseInt((a.querySelector(".year-col")||{}).textContent)||0;bv=parseInt((b.querySelector(".year-col")||{}).textContent)||0;break;case"ratingAm":av=parseFloat((a.querySelector(".rating-am")||{}).textContent)||-1;bv=parseFloat((b.querySelector(".rating-am")||{}).textContent)||-1;break;case"ratingImdb":av=parseFloat((a.querySelector(".rating-imdb")||{}).textContent)||-1;bv=parseFloat((b.querySelector(".rating-imdb")||{}).textContent)||-1;break;case"ratingKp":av=parseFloat((a.querySelector(".rating-kp")||{}).textContent)||-1;bv=parseFloat((b.querySelector(".rating-kp")||{}).textContent)||-1;break;case"seasons":av=parseInt((a.querySelector(".seasons-col")||{}).textContent)||0;bv=parseInt((b.querySelector(".seasons-col")||{}).textContent)||0;break;default:return 0}if(dir==="asc")return av>bv?1:-1;return av<bv?1:-1});rows.forEach(function(r){tb.appendChild(r)});ft()}
window.addEventListener("load",function(){ft();var h=document.querySelector('th[data-col="year"]');if(h)h.classList.add("sorted")});
</script>
</body>
</html>
'@

# Replace placeholders
$html = $template -replace '__COUNT__', "$($allSeries.Count)"
$html = $html -replace '__GENRES__', $genreOpts
$html = $html -replace '__YEARS__', $yearOpts
$html = $html -replace '__ROWS__', $rowsHtml

# Write UTF-8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("D:\GitHub\amediateka_catalog_v2.html", $html, $utf8NoBom)
Write-Output "=== DONE ==="
Write-Output "$($allSeries.Count) series written to D:\GitHub\amediateka_catalog_v2.html"
$bytes = [System.IO.File]::ReadAllBytes("D:\GitHub\amediateka_catalog_v2.html")
Write-Output "File: $($bytes.Length) bytes"
