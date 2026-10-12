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

# コンテナ内で pg_dumpall→gzip をファイルに書き出し、docker cp で取り出す。
# （PowerShell のパイプ経由だと gzip バイナリが壊れ、5.1 では Set-Content -Encoding Byte も
#   文字列パイプを受け取れず失敗するため、コンテナ側で完結させるこの方式を使う）
docker exec $container sh -c "pg_dumpall --clean --if-exists --username=$dbUser | gzip > /tmp/immich-db.sql.gz"
if ($LASTEXITCODE -ne 0) { throw "pg_dumpall に失敗した（コンテナ名/ユーザー名を確認）。" }
docker cp "$container`:/tmp/immich-db.sql.gz" $outFile
docker exec $container rm -f /tmp/immich-db.sql.gz

if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -eq 0) {
    throw "ダンプの取り出しに失敗した: $outFile"
}

$sizeMB = [math]::Round((Get-Item $outFile).Length / 1MB, 1)
Write-Host "[backup] saved: $outFile ($sizeMB MB)"

# 古い世代を削除
$olds = Get-ChildItem $backupDir -Filter 'immich-db-*.sql.gz' |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $keep
foreach ($f in $olds) { Remove-Item $f.FullName -Force; Write-Host "[backup] pruned: $($f.Name)" }

Write-Host "[backup] done."
