<#
.SYNOPSIS
  Little Grand Hotel — bütün test paketini çalıştırır ve tek bir karar verir.

.DESCRIPTION
  Testler tek tek de çalıştırılabilir, ama elle çalıştırmanın iki tuzağı var ve
  ikisi de bu projede gerçekten yaşandı:

    1) Bir GDScript çalışma zamanı hatası `_ready()` coroutine'ini sessizce
       öldürür; sahne yine de 0 ile çıkabilir. `tests/tutorial_check` tam olarak
       böyle, 2026-08-12'den 2026-08-20'ye kadar YEŞİL görünerek bozuk kaldı.
       Bu yüzden burada çıkış kodu YETMEZ: çıktıda `SCRIPT ERROR` / `FAIL` /
       `BAŞARISIZ` aranır ve her testin kendi bitiş satırının gerçekten
       basıldığı doğrulanır.

    2) Sahne hiç yüklenemezse (ör. ayrıştırma hatası) süreç ASILIR — her testin
       kendi zaman aşımı var.

  Pencere gerektiren testler (arayüz ağacı --headless modda düzen hesaplamaz)
  ayrı işaretlidir; -Headless ile yalnızca headless olanlar koşulur (CI için).

.PARAMETER Filter
  Yalnızca adı bu deseni içeren testleri çalıştırır (ör. -Filter cloud).

.PARAMETER Headless
  Pencere gerektiren testleri atlar.

.PARAMETER Godot
  Godot çalıştırılabilirinin yolu.

.EXAMPLE
  pwsh tests/run_all.ps1
  pwsh tests/run_all.ps1 -Headless
  pwsh tests/run_all.ps1 -Filter save
#>
param(
    [string]$Filter = "",
    [switch]$Headless,
    [string]$Godot = "tools\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (-not (Test-Path $Godot)) {
    Write-Host "Godot bulunamadı: $Godot" -ForegroundColor Red
    exit 2
}

# name    : rapor adı
# target  : --script hedefi ya da sahne yolu
# mode    : script | scene
# window  : $true ise pencere gerekir (headless çalışmaz)
# timeout : saniye
# success : testin GERÇEKTEN bittiğini gösteren satır. Her testin kendi sözü
#           var; ortak bir kalıp varsaymak "yarıda öldü" ile "farklı yazdı"yı
#           birbirine karıştırır.
# noisy   : $true ise SCRIPT ERROR beklenen çıktıdır (fuzz kasten bozuk veri
#           besliyor, cloud_api_check kasten bozuk JSON yazıyor).
# verdict : $false ise test bir geçti/kaldı kararı BASMIYOR, yalnızca gözlem
#           satırları yazıyor. Bunlar PASS sayılmaz, RAPOR diye işaretlenir —
#           sessizce yeşil görünen test istemiyoruz.
$tests = @(
    @{ name = "sim_check";        target = "res://tests/sim_check.gd";                mode = "script"; window = $false; timeout = 120; success = "TÜM TESTLER GEÇTİ" },
    @{ name = "data_check";       target = "res://tests/data_check.tscn";             mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "economy_api";      target = "res://tests/economy_api_check.tscn";      mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "sfx_check";        target = "res://tests/sfx_check.tscn";              mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "migration_check";  target = "res://tests/migration_check.tscn";        mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "fuzz_attack";      target = "res://tests/fuzz_attack.tscn";            mode = "scene";  window = $false; timeout = 300; success = "FUZZ_DONE";        noisy = $true },
    @{ name = "cloud_save_check"; target = "res://tests/cloud_save_check.tscn";       mode = "scene";  window = $false; timeout = 120; success = "CLOUD_SAVE_DONE" },
    @{ name = "cloud_api_check";  target = "res://tests/cloud_api_check.tscn";        mode = "scene";  window = $false; timeout = 120; success = "TÜM TESTLER GEÇTİ"; noisy = $true },
    @{ name = "ads_check";        target = "res://tests/ads_check.tscn";              mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "iap_check";        target = "res://tests/iap_check.tscn";              mode = "scene";  window = $false; timeout = 90;  success = "TÜM TESTLER GEÇTİ" },
    @{ name = "i18n_check";       target = "res://tests/i18n_check.tscn";             mode = "scene";  window = $false; timeout = 120; success = "all checks passed" },
    @{ name = "google_signin";    target = "res://tests/google_signin_check.tscn";    mode = "scene";  window = $false; timeout = 90;  success = "SONUC:" },
    @{ name = "store_compliance"; target = "res://tests/store_compliance_check.tscn"; mode = "scene";  window = $false; timeout = 90;  verdict = $false },
    @{ name = "unlink_check";     target = "res://tests/unlink_check.tscn";           mode = "scene";  window = $false; timeout = 90;  verdict = $false },
    @{ name = "tutorial_check";   target = "res://tests/tutorial_check.tscn";         mode = "scene";  window = $true;  timeout = 120; success = "TÜM TESTLER GEÇTİ" },
    @{ name = "ui_check";         target = "res://tests/ui_check.tscn";               mode = "scene";  window = $true;  timeout = 240; success = "TÜM TESTLER GEÇTİ" },
    @{ name = "scroll_check";     target = "res://tests/scroll_check.tscn";           mode = "scene";  window = $true;  timeout = 180; success = "TÜM TESTLER GEÇTİ" }
)

# Çıktıda görülürse test başarısız sayılır (çıkış kodu 0 olsa bile).
$failurePatterns = @("SCRIPT ERROR", "  FAIL ", "TEST BAŞARISIZ", "Parse Error")

$results = @()
$logDir = Join-Path ([System.IO.Path]::GetTempPath()) "lgh-tests"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

foreach ($t in $tests) {
    if ($Filter -and ($t.name -notlike "*$Filter*")) { continue }
    if ($Headless -and $t.window) {
        $results += [pscustomobject]@{ Name = $t.name; Status = "SKIP"; Checks = 0; Reason = "pencere gerekiyor" }
        Write-Host ("{0,-18} {1,-8}" -f $t.name, "SKIP") -ForegroundColor DarkGray
        continue
    }

    $argList = @()
    if (-not $t.window) { $argList += "--headless" }
    $argList += @("--path", ".")
    if ($t.mode -eq "script") { $argList += @("--script", $t.target) } else { $argList += $t.target }

    $log = Join-Path $logDir "$($t.name).log"
    $proc = Start-Process -FilePath $Godot -ArgumentList $argList -PassThru -NoNewWindow `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    $finished = $proc.WaitForExit($t.timeout * 1000)
    if (-not $finished) {
        try { $proc.Kill() } catch {}
        $results += [pscustomobject]@{ Name = $t.name; Status = "TIMEOUT"; Checks = 0; Reason = "$($t.timeout) sn doldu" }
        Write-Host ("{0,-18} {1,-8}" -f $t.name, "TIMEOUT") -ForegroundColor Red
        continue
    }
    $exit = $proc.ExitCode

    $out = ""
    if (Test-Path $log) { $out += (Get-Content $log -Raw) }
    if (Test-Path "$log.err") { $out += (Get-Content "$log.err" -Raw) }
    if ($null -eq $out) { $out = "" }

    $bad = @()
    foreach ($p in $failurePatterns) {
        if ($p -eq "SCRIPT ERROR" -and $t.noisy) { continue }
        if ($out -like "*$p*") { $bad += $p }
    }

    $sawSuccess = $true
    if ($t.ContainsKey("success")) { $sawSuccess = $out -like "*$($t.success)*" }

    # Kontrol sayısı: önce testin kendi bildirdiği sayı, yoksa OK satırları.
    $checks = 0
    if ($out -match "TÜM TESTLER GEÇTİ \((\d+)") { $checks = [int]$Matches[1] }
    elseif ($out -match "SONUÇ: (\d+) kontrol") { $checks = [int]$Matches[1] }
    elseif ($out -match "SONUC: (\d+) gecti") { $checks = [int]$Matches[1] }
    elseif ($out -match "SONUÇ: (\d+) senaryo") { $checks = [int]$Matches[1] }
    elseif ($out -match "(\d+) rows in") { $checks = [int]$Matches[1] }
    if ($checks -eq 0) {
        $okCount = ([regex]::Matches($out, "(?m)^\s+OK\s")).Count
        if ($okCount -gt 0) { $checks = $okCount }
    }

    $status = "PASS"
    $reason = ""
    if ($exit -ne 0) { $status = "FAIL"; $reason = "çıkış kodu $exit" }
    elseif ($bad.Count -gt 0) { $status = "FAIL"; $reason = "çıktıda: " + ($bad -join ", ") }
    elseif (-not $sawSuccess) { $status = "FAIL"; $reason = "bitiş satırı basılmadı (yarıda öldü)" }
    elseif ($t.ContainsKey("verdict") -and -not $t.verdict) {
        $status = "REPORT"; $reason = "geçti/kaldı kararı basmıyor — çıktısı elle okunmalı"
    }

    $color = switch ($status) { "PASS" { "Green" } "REPORT" { "Yellow" } default { "Red" } }
    Write-Host ("{0,-18} {1,-8} {2,5} kontrol {3}" -f $t.name, $status, $checks, $reason) -ForegroundColor $color
    $results += [pscustomobject]@{ Name = $t.name; Status = $status; Checks = $checks; Reason = $reason }
}

Write-Host ""
Write-Host ("=" * 72)
$pass = ($results | Where-Object Status -eq "PASS").Count
$report = ($results | Where-Object Status -eq "REPORT").Count
$fail = ($results | Where-Object { $_.Status -eq "FAIL" -or $_.Status -eq "TIMEOUT" }).Count
$skip = ($results | Where-Object Status -eq "SKIP").Count
$total = ($results | Measure-Object -Property Checks -Sum).Sum
Write-Host ("{0} geçti, {1} başarısız, {2} rapor, {3} atlandı — toplam {4} kontrol" -f $pass, $fail, $report, $skip, $total)
Write-Host ("Günlükler: {0}" -f $logDir)
if ($report -gt 0) {
    Write-Host "RAPOR: bu testler kendi kararını basmıyor, çıktıları elle okunmalı." -ForegroundColor Yellow
}

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Başarısız olanlar:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAIL" -or $_.Status -eq "TIMEOUT" } | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $_.Reason) -ForegroundColor Red
    }
    exit 1
}
exit 0
