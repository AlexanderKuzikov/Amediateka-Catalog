$ErrorActionPreference = "Stop"
Write-Output "Reading JSON..."
$json = [System.IO.File]::ReadAllText("D:\GitHub\amediateka_series.json", [System.Text.Encoding]::UTF8)
$series = $json | ConvertFrom-Json
Write-Output "Loaded $($series.Count) series"

$allGenres = @{}
$allYears = @{}
$sb = New-Object System.Text.StringBuilder

$null = $sb.AppendLine(@'
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Каталог сериалов Amediateka</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d0d12;color:#e0e0e0}
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
th{position:sticky;top:108px;background:#1a1a2e;padding:10px 8px;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:0.5px;color:#888;border-bottom:2px solid #2a2a3e;cursor:pointer;user-select:none;white-space:nowrap;z-index:50}
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
.hidden{display:none !important}
.no-results{text-align:center;padding:40px;color:#666;font-size:16px}
@media(max-width:768px){.container{padding:8px}td,th{padding:5px 3px;font-size:11px}.poster-col{width:40px;min-width:40px}.poster-col img{width:32px;height:48px}.title-col{min-width:120px}.genre-col{min-width:100px}}
</style>
</head>
<body>
<div class="header">
<h1>&#128250; Каталог сериалов Amediateka</h1>
<p>Всего сериалов: <span id="totalCount">SERIES_COUNT</span> &middot; данные на 18 июля 2026</p>
</div>
<div class="container">
<div class="controls">
<input type="text" id="searchInput" placeholder="Поиск по названию, жанру, описанию..." oninput="filterTable()">
<select id="genreFilter" onchange="filterTable()"><option value="">Все жанры</option>GENRE_OPTIONS</select>
<select id="yearFilter" onchange="filterTable()"><option value="">Все годы</option>YEAR_OPTIONS</select>
<select id="sortSelect" onchange="applySort()">
<option value="year-desc">По году &#8595;</option>
<option value="year-asc">По году &#8593;</option>
<option value="ratingAm-desc">По рейтингу Amediateka &#8595;</option>
<option value="ratingAm-asc">По рейтингу Amediateka &#8593;</option>
<option value="ratingImdb-desc">По рейтингу IMDB &#8595;</option>
<option value="ratingKp-desc">По рейтингу Кинопоиск &#8595;</option>
<option value="title-asc">По названию А→Я</option>
<option value="title-desc">По названию Я→А</option>
<option value="seasons-desc">По сезонам &#8595;</option>
</select>
<button id="resetBtn" onclick="resetFilters()">Сброс</button>
</div>
<div class="stats-bar"><span id="stats">Показано: <b>SERIES_COUNT</b> из SERIES_COUNT</span><span>Нажми на заголовок столбца для сортировки</span></div>
<div class="table-wrap">
<table id="seriesTable">
<thead>
<tr>
<th class="poster-col"></th>
<th data-col="title" onclick="sortBy('title')">Название</th>
<th data-col="genre" onclick="sortBy('genre')">Жанры</th>
<th data-col="year" onclick="sortBy('year')" class="sorted">Год</th>
<th data-col="ratingAm" onclick="sortBy('ratingAm')">Amediateka</th>
<th data-col="ratingImdb" onclick="sortBy('ratingImdb')">IMDB</th>
<th data-col="ratingKp" onclick="sortBy('ratingKp')">Кинопоиск</th>
<th data-col="seasons" onclick="sortBy('seasons')">Сезонов</th>
</tr>
</thead>
<tbody id="tableBody">
'@)

# Generate table rows
$index = 0
foreach ($s in $series) {
    $index++
    $title = $s.title -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
    $desc = ""
    if ($s.shortDescription) {
        $desc = $s.shortDescription -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
    }
    
    $poster = ""
    if ($s.assets.productPoster) {
        $poster = $s.assets.productPoster -replace '{SIZE}', '150x225'
    }
    
    $webUrl = "https://www.amediateka.ru$($s.webUrl)"
    
    $genreTags = ""
    if ($s.genres) {
        $tags = @()
        foreach ($g in $s.genres) {
            $gn = $g.name -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
            $tags += "<span class='genre-tag'>$gn</span>"
            $allGenres[$g.name] = $true
        }
        $genreTags = $tags -join ''
    }
    
    $year = if ($s.premierYear) { $s.premierYear } else { "" }
    if ($year) { $allYears[$year] = $true }
    
    $ratingAm = if ($s.ratingAmediateka) { [double]$s.ratingAmediateka } else { 0 }
    $ratingAmStr = if ($ratingAm -gt 0) { "{0:F1}" -f $ratingAm } else { "&mdash;" }
    
    $ratingImdbStr = "&mdash;"
    if ($s.ratingImdb) {
        $r = [double]$s.ratingImdb
        $ratingImdbStr = "<span class='rating rating-imdb'>{0:F1}</span>" -f $r
    } else {
        $ratingImdbStr = "<span class='rating-na'>&mdash;</span>"
    }
    
    $ratingKpStr = "&mdash;"
    if ($s.ratingKinopoisk) {
        $r = [double]$s.ratingKinopoisk
        $ratingKpStr = "<span class='rating rating-kp'>{0:F1}</span>" -f $r
    } else {
        $ratingKpStr = "<span class='rating-na'>&mdash;</span>"
    }
    
    $seasons = if ($s.seasons) { $s.seasons } else { "&mdash;" }
    
    $imgTag = ""
    if ($poster) {
        $imgTag = "<img src='$poster' alt='$title' loading='lazy'>"
    }
    
    $descBlock = ""
    if ($desc) {
        $descBlock = "<span class='desc-text'>$desc</span>"
    }
    
    $null = $sb.AppendLine("<tr>")
    $null = $sb.AppendLine("  <td class='poster-col'>$imgTag</td>")
    $null = $sb.AppendLine("  <td class='title-col'><a href='$webUrl' target='_blank'>$title</a>$descBlock</td>")
    $null = $sb.AppendLine("  <td class='genre-col'>$genreTags</td>")
    $null = $sb.AppendLine("  <td class='year-col'>$year</td>")
    $null = $sb.AppendLine("  <td class='rating-col'><span class='rating rating-am'>$ratingAmStr</span></td>")
    $null = $sb.AppendLine("  <td class='rating-col'>$ratingImdbStr</td>")
    $null = $sb.AppendLine("  <td class='rating-col'>$ratingKpStr</td>")
    $null = $sb.AppendLine("  <td class='seasons-col'>$seasons</td>")
    $null = $sb.AppendLine("</tr>")
}

# Footer
$null = $sb.AppendLine(@'
</tbody>
</table>
</div>
</div>

<script>
let currentSort = { col: 'year', dir: 'desc' };

function filterTable() {
    const search = document.getElementById('searchInput').value.toLowerCase();
    const genre = document.getElementById('genreFilter').value;
    const year = document.getElementById('yearFilter').value;
    const rows = document.querySelectorAll('#tableBody tr');
    let visible = 0;
    rows.forEach(function(row) {
        const text = row.textContent.toLowerCase();
        const genres = row.querySelector('.genre-col') ? row.querySelector('.genre-col').textContent : '';
        const yearCell = row.querySelector('.year-col') ? row.querySelector('.year-col').textContent : '';
        const matchSearch = !search || text.includes(search);
        const matchGenre = !genre || genres.includes(genre);
        const matchYear = !year || yearCell === year;
        if (matchSearch && matchGenre && matchYear) {
            row.classList.remove('hidden');
            visible++;
        } else {
            row.classList.add('hidden');
        }
    });
    document.getElementById('stats').innerHTML = 'Показано: <b>' + visible + '</b> из ' + rows.length;
}

function resetFilters() {
    document.getElementById('searchInput').value = '';
    document.getElementById('genreFilter').value = '';
    document.getElementById('yearFilter').value = '';
    document.getElementById('sortSelect').value = 'year-desc';
    currentSort = { col: 'year', dir: 'desc' };
    applySort();
    filterTable();
}

function sortBy(col) {
    if (currentSort.col === col) {
        currentSort.dir = currentSort.dir === 'asc' ? 'desc' : 'asc';
    } else {
        currentSort.col = col;
        currentSort.dir = 'desc';
    }
    document.getElementById('sortSelect').value = col + '-' + currentSort.dir;
    applySort();
    document.querySelectorAll('th').forEach(function(th) { th.classList.remove('sorted'); });
    var th = document.querySelector('th[data-col="' + col + '"]');
    if (th) th.classList.add('sorted');
}

function applySort() {
    var val = document.getElementById('sortSelect').value;
    var parts = val.split('-');
    var col = parts[0];
    var dir = parts[1];
    currentSort = { col: col, dir: dir };
    var tbody = document.getElementById('tableBody');
    var rows = Array.from(tbody.querySelectorAll('tr'));
    rows.sort(function(a, b) {
        var aVal, bVal;
        switch(col) {
            case 'title':
                aVal = (a.querySelector('.title-col a') ? a.querySelector('.title-col a').textContent : '');
                bVal = (b.querySelector('.title-col a') ? b.querySelector('.title-col a').textContent : '');
                return dir === 'asc' ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
            case 'year':
                aVal = parseInt(a.querySelector('.year-col') ? a.querySelector('.year-col').textContent : 0) || 0;
                bVal = parseInt(b.querySelector('.year-col') ? b.querySelector('.year-col').textContent : 0) || 0;
                break;
            case 'ratingAm':
                aVal = parseFloat(a.querySelector('.rating-am') ? a.querySelector('.rating-am').textContent : '-1') || -1;
                bVal = parseFloat(b.querySelector('.rating-am') ? b.querySelector('.rating-am').textContent : '-1') || -1;
                break;
            case 'ratingImdb':
                aVal = parseFloat(a.querySelector('.rating-imdb') ? a.querySelector('.rating-imdb').textContent : '-1') || -1;
                bVal = parseFloat(b.querySelector('.rating-imdb') ? b.querySelector('.rating-imdb').textContent : '-1') || -1;
                break;
            case 'ratingKp':
                aVal = parseFloat(a.querySelector('.rating-kp') ? a.querySelector('.rating-kp').textContent : '-1') || -1;
                bVal = parseFloat(b.querySelector('.rating-kp') ? b.querySelector('.rating-kp').textContent : '-1') || -1;
                break;
            case 'seasons':
                aVal = parseInt(a.querySelector('.seasons-col') ? a.querySelector('.seasons-col').textContent : 0) || 0;
                bVal = parseInt(b.querySelector('.seasons-col') ? b.querySelector('.seasons-col').textContent : 0) || 0;
                break;
            default: return 0;
        }
        if (dir === 'asc') return aVal > bVal ? 1 : -1;
        return aVal < bVal ? 1 : -1;
    });
    rows.forEach(function(row) { tbody.appendChild(row); });
    filterTable();
}

window.addEventListener('load', function() {
    filterTable();
    var th = document.querySelector('th[data-col="year"]');
    if (th) th.classList.add('sorted');
});
</script>
</body>
</html>
'@)

# Replace placeholders
$html = $sb.ToString()
$genreOpts = ($allGenres.Keys | Sort-Object | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
$yearOpts = ($allYears.Keys | Sort-Object -Descending | ForEach-Object { "<option value='$_'>$_</option>" }) -join "`n"
$html = $html -replace 'GENRE_OPTIONS', $genreOpts
$html = $html -replace 'YEAR_OPTIONS', $yearOpts
$html = $html -replace 'SERIES_COUNT', $series.Count

[System.IO.File]::WriteAllText("D:\GitHub\amediateka_catalog.html", $html, [System.Text.Encoding]::UTF8)
Write-Output "Generated: D:\GitHub\amediateka_catalog.html"
$len = $html.Length
Write-Output "Size: $([math]::Round($len/1KB)) KB"
