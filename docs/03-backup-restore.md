# 03. バックアップと復元

**RAID も immich もバックアップではない。** 誤削除・ランサムウェア・世代管理は守れない。
守る対象は2つ。両方揃って初めて復元できる。

| 対象 | 中身 | バックアップ方法 |
|---|---|---|
| **Postgres DB** | 顔・アルバム・共有・検索インデックス等のメタデータ | `backup-db.ps1`（日次ダンプ） |
| **写真の実体** | `UPLOAD_LOCATION` と `EXTERNAL_LIBRARY` のファイル | 別の物理ディスク or クラウドへコピー |

## DB バックアップ

```powershell
# 手動
.\scripts\backup-db.ps1

# 日次自動（管理者PowerShellで一度だけ登録。既定 03:30）
.\scripts\register-backup-task.ps1
Start-ScheduledTask -TaskName immich-db-backup   # 動作テスト
```

- 保存先・保持世代数は `.env` の `BACKUP_DIR` / `BACKUP_KEEP`
- `BACKUP_DIR` は**写真を置くRAIDとは別**の場所が望ましい（同時に失わないため）
- 可能ならダンプをクラウド同期フォルダ（OneDrive等）に置いてオフサイト化＝3-2-1

## 写真実体のバックアップ

- `UPLOAD_LOCATION`（新規アップロード）と `EXTERNAL_LIBRARY`（既存写真）を
  別ディスク/クラウドへ定期コピー（robocopy のミラー等）

```powershell
robocopy E:\immich\upload F:\backup\immich\upload /MIR /R:2 /W:5 /LOG+:F:\backup\robocopy.log
robocopy E:\Photos        F:\backup\Photos        /MIR /R:2 /W:5 /LOG+:F:\backup\robocopy.log
```

## 復元

**必ず「DBダンプ」と「写真実体」をセットで戻す。** 実体だけ戻してもメタは復元できない。

```powershell
# 1. 写真実体を元パスへ戻す（robocopy 等）
# 2. DB を復元（破壊的操作。確認プロンプトあり）
.\scripts\restore-db.ps1 -DumpPath C:\immich\backups\immich-db-YYYYMMDD-HHmmss.sql.gz
```

## 復元リハーサル（重要）

**一度も戻せていないバックアップはバックアップではない。**
構築直後に、ダンプから `restore-db.ps1` で戻せることを1回確認してから本運用に入る。

## アップグレード前の儀式

更新は専用スクリプトが更新前に自動でダンプを取る。手順は [docs/05-update.md](05-update.md) を参照。

```powershell
.\scripts\update-immich.ps1 -Version v1.120.0   # ダンプ→pull→再作成→ヘルス確認
```
