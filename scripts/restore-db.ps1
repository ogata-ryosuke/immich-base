# immich Postgres をダンプから復元する。
# 使い方:  .\scripts\restore-db.ps1 -DumpPath C:\immich\backups\immich-db-YYYYMMDD-HHmmss.sql.gz
#
# ★ 復元は既存DBを破棄して入れ替える破壊的操作。実行前に現在のDBもダンプしておくこと。
# 手順の詳細は docs/03-backup-restore.md を参照。

param(
    [Parameter(Mandatory = $true)]
    [string]$DumpPath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $DumpPath)) { throw "ダンプが見つからない: $DumpPath" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile  = Join-Path $repoRoot '.env'
$envMap = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') { $envMap[$Matches[1]] = $Matches[2].Trim() }
}
$dbUser    = $envMap['DB_USERNAME']
$container = 'immich_postgres'

Write-Host "この操作は現在の immich DB を破棄して '$DumpPath' で置き換える。" -ForegroundColor Yellow
$ans = Read-Host "続行するには 'yes' と入力"
if ($ans -ne 'yes') { Write-Host '中止した。'; exit 1 }

Push-Location $repoRoot
try {
    # DB以外を止め、DBボリュームを作り直す
    docker compose down -v
    docker compose pull
    docker compose create
    docker compose start database
    Start-Sleep -Seconds 15   # DB 初期化待ち

    # ダンプを流し込む
    docker cp $DumpPath "$container`:/tmp/restore.sql.gz"
    docker exec $container sh -c "gunzip < /tmp/restore.sql.gz | psql --username=$dbUser --dbname=postgres"
    docker exec $container rm -f /tmp/restore.sql.gz

    # 全サービス起動
    docker compose up -d
    Write-Host "[restore] 完了。http://localhost:2283 で確認。" -ForegroundColor Green
}
finally {
    Pop-Location
}
