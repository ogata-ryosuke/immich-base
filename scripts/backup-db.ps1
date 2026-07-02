# immich Postgres の論理バックアップ（pg_dumpall を gzip 圧縮して保存）
# 使い方:  .\scripts\backup-db.ps1
# 定期実行の登録:  .\scripts\register-backup-task.ps1
#
# 注意: これは「メタデータ（顔・アルバム・検索インデックス等）」のバックアップ。
#       写真の実体は UPLOAD_LOCATION / EXTERNAL_LIBRARY を別途コピーすること。

$ErrorActionPreference = 'Stop'

# .env を読み込む（リポジトリ直下）
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile  = Join-Path $repoRoot '.env'
if (-not (Test-Path $envFile)) { throw ".env が見つからない: $envFile" }

$envMap = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#') { return }
    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)$') { $envMap[$Matches[1]] = $Matches[2].Trim() }
}

$dbUser    = $envMap['DB_USERNAME']
$backupDir = $envMap['BACKUP_DIR']
$keep      = [int]($envMap['BACKUP_KEEP'] | ForEach-Object { if ($_) { $_ } else { 14 } })
$container = 'immich_postgres'

if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $backupDir "immich-db-$stamp.sql.gz"

Write-Host "[backup] dumping immich database..."

# コンテナ内で pg_dumpall→gzip を完結させ、docker cp で取り出す
# （PowerShell のストリーム経由だと gzip バイナリが壊れるため、この方式にする）
docker exec $container sh -c "pg_dumpall --clean --if-exists --username=$dbUser | gzip" `
    | Set-Content -Path $outFile -Encoding Byte 2>$null

# Set-Content -Encoding Byte が使えない環境向けフォールバック（安全策）
if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -eq 0) {
    docker exec $container sh -c "pg_dumpall --clean --if-exists --username=$dbUser | gzip > /tmp/immich-db.sql.gz"
    docker cp "$container`:/tmp/immich-db.sql.gz" $outFile
    docker exec $container rm -f /tmp/immich-db.sql.gz
}

$sizeMB = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
Write-Host "[backup] saved: $outFile ($sizeMB MB)"

# 古い世代を削除
$olds = Get-ChildItem $backupDir -Filter 'immich-db-*.sql.gz' |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $keep
foreach ($f in $olds) { Remove-Item $f.FullName -Force; Write-Host "[backup] pruned: $($f.Name)" }

Write-Host "[backup] done."
