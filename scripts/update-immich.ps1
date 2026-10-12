# immich を安全にアップデートする。
# 使い方:
#   .\scripts\update-immich.ps1                 # .env の IMMICH_VERSION のまま pull → 再作成
#   .\scripts\update-immich.ps1 -Version v1.xxx # .env の IMMICH_VERSION を書き換えてから更新
#   .\scripts\update-immich.ps1 -SkipBackup     # DBダンプを省略（非推奨）
#
# やること: ①DBダンプ ②（指定時）タグ書換 ③pull ④再作成 ⑤ヘルス確認 ⑥古いイメージ掃除
#
# ★ 事前に必ず Release Notes を読むこと。DB/Redis のイメージタグが変わる版は
#   先に example.env と突き合わせて .env の DB_IMAGE / REDIS_IMAGE も更新しておく。
#   https://github.com/immich-app/immich/releases
# 詳細な手順・ロールバックは docs/05-update.md を参照。

param(
    [string]$Version,          # 例: v1.120.0 （省略時は .env の現値のまま）
    [switch]$SkipBackup,       # DBダンプを省略（緊急時のみ）
    [switch]$Prune             # 更新後に未使用イメージを掃除（docker image prune -f）
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile  = Join-Path $repoRoot '.env'
if (-not (Test-Path $envFile)) { throw ".env が見つからない: $envFile" }

# .env を読み込む（他スクリプトと同じ方式）
$envMap = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') { $envMap[$Matches[1]] = $Matches[2].Trim() }
}

$current = $envMap['IMMICH_VERSION']
Write-Host "[update] 現在の IMMICH_VERSION = $current" -ForegroundColor Cyan

# --- ① タグ書き換え（-Version 指定時のみ）-----------------------------------
if ($Version) {
    Write-Host "[update] IMMICH_VERSION を '$current' -> '$Version' に書き換える。" -ForegroundColor Yellow
    $ans = Read-Host "Release Notes を確認済みで続行するなら 'yes' と入力"
    if ($ans -ne 'yes') { Write-Host '中止した。'; exit 1 }

    # IMMICH_VERSION= の行だけを置換（コメント行はそのまま）
    $lines = Get-Content $envFile
    $hit = $false
    $lines = $lines | ForEach-Object {
        if ($_ -match '^\s*IMMICH_VERSION\s*=') { $hit = $true; "IMMICH_VERSION=$Version" } else { $_ }
    }
    if (-not $hit) { throw ".env に IMMICH_VERSION= の行が無い。手動で確認すること。" }
    Set-Content -Path $envFile -Value $lines -Encoding UTF8
    Write-Host "[update] .env を更新した。"
}

Push-Location $repoRoot
try {
    # --- ② 更新前にDBダンプ -------------------------------------------------
    if ($SkipBackup) {
        Write-Host "[update] -SkipBackup 指定のためDBダンプを省略した（非推奨）。" -ForegroundColor Yellow
    } else {
        Write-Host "[update] 更新前にDBをダンプする..."
        & (Join-Path $PSScriptRoot 'backup-db.ps1')
    }

    # --- ③ イメージ取得 -----------------------------------------------------
    Write-Host "[update] docker compose pull ..." -ForegroundColor Cyan
    docker compose pull
    if ($LASTEXITCODE -ne 0) { throw "docker compose pull に失敗した。" }

    # --- ④ 再作成（新イメージでコンテナを作り直す）--------------------------
    Write-Host "[update] docker compose up -d ..." -ForegroundColor Cyan
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose up に失敗した。" }

    # --- ⑤ ヘルス確認 -------------------------------------------------------
    Write-Host "[update] サーバの起動を待つ（最大120秒）..."
    $ok = $false
    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:2283/api/server/ping' -TimeoutSec 5
            if ($r.StatusCode -eq 200) { $ok = $true; break }
        } catch { }   # まだ起動中。リトライ
    }
    if ($ok) {
        Write-Host "[update] サーバ応答OK (http://localhost:2283)" -ForegroundColor Green
    } else {
        Write-Host "[update] 120秒以内に応答しなかった。'docker compose logs -f immich-server' で確認すること。" -ForegroundColor Yellow
    }

    # 稼働中イメージのバージョンを表示
    docker compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'

    # --- ⑥ 後片付け ---------------------------------------------------------
    if ($Prune) {
        Write-Host "[update] 未使用イメージを掃除する..."
        docker image prune -f | Out-Null
    } else {
        Write-Host "[update] 古いイメージが残っている。問題なければ 'docker image prune -f' で掃除可。"
    }

    Write-Host "[update] 完了。不具合があれば docs/05-update.md のロールバック手順へ。" -ForegroundColor Green
}
finally {
    Pop-Location
}
