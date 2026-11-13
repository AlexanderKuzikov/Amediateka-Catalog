# Деплой каталога на VPS sat (135.106.192.125).
# Кладёт dist/amediateka_catalog.html в /var/www/sites/amediateka/public/index.html
# и проверяет отдачу по https://amediateka.135.106.192.125.nip.io/
$ErrorActionPreference = 'Stop'

$file = Join-Path $PSScriptRoot '..\dist\amediateka_catalog.html'
$server = 'deploy@135.106.192.125'
$root = '/var/www/sites/amediateka/public'

scp -o BatchMode=yes $file "${server}:/tmp/amediateka_catalog.html"
ssh -o BatchMode=yes $server "sudo install -o deploy -g www-data -m 644 /tmp/amediateka_catalog.html $root/index.html; sudo ln -f $root/index.html $root/amediateka_catalog.html; rm /tmp/amediateka_catalog.html"

$code = curl.exe -s -o NUL -w "%{http_code}" 'https://amediateka.135.106.192.125.nip.io/'
if ($code -ne '200') { throw "проверка не прошла: HTTP $code" }
"deployed: HTTP $code"
