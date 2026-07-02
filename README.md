# immich-base

自宅 Windows デスクトップで [immich](https://github.com/immich-app/immich) を
24時間運用するための構成一式。GitHub に置き、Windows 側で `git clone` して使う。

- **DB / Redis** … 内蔵SSD（安定・高速。ここが壊れると全メタデータを失う）
- **写真アップロード先 / 既存写真ライブラリ** … 外付けRAID（大容量）
- **外部アクセス** … Tailscale（無料・ポート開放なし・HTTPS）
- **バックアップ** … Postgres 日次ダンプ ＋ 写真実体の別コピー

> immich は活発なβ。**アップグレード前に必ず [Release Notes](https://github.com/immich-app/immich/releases) を読む**こと。

---

## 前提（Windows 側で一度だけ）

1. **Docker Desktop** をインストールし、WSL2 バックエンドを有効化。起動時自動起動をON。
2. **電源プラン**：スリープ・休止を「なし」に（ディスプレイのみオフは可）。
3. **Windows Update**：アクティブ時間設定・自動再起動の抑制。
4. **外付けRAID に固定ドライブレター**を割り当て（例では `E:`）。
5. Docker Desktop の設定で、使用するドライブ（`C:` と `E:`）が **File Sharing** に含まれていることを確認。

## セットアップ手順

```powershell
# 1. clone
git clone https://github.com/<you>/immich-base.git
cd immich-base

# 2. 環境ファイルを作成して編集（パス・パスワード・バージョン）
copy example.env .env
notepad .env

# 3. 必要フォルダを作成（.env のパスに合わせる）
mkdir C:\immich\postgres
mkdir E:\immich\upload

# 4. 起動
docker compose up -d

# 5. 初回のみ Web で管理者を作成
#    http://localhost:2283
```

起動後：

- **外部/スマホからのアクセス** → [docs/01-tailscale.md](docs/01-tailscale.md)
- **既存1TBの取り込み** → [docs/02-external-library.md](docs/02-external-library.md)
- **バックアップ設定（必須）** → [docs/03-backup-restore.md](docs/03-backup-restore.md)
- **GPUでML高速化** → [docs/04-gpu-accel.md](docs/04-gpu-accel.md)

## 更新

```powershell
notepad .env                # IMMICH_VERSION を新しいタグに（release notes 確認後）
.\scripts\backup-db.ps1     # 更新前に必ずDBダンプ
docker compose pull
docker compose up -d
```

## 構成ファイル

| ファイル | 役割 |
|---|---|
| `docker-compose.yml` | immich 本体（server / ML / postgres / redis） |
| `example.env` | 環境変数のテンプレート（コピーして `.env` に） |
| `scripts/backup-db.ps1` | Postgres の日次ダンプ |
| `scripts/restore-db.ps1` | ダンプからの復元 |
| `scripts/register-backup-task.ps1` | バックアップをタスクスケジューラに登録 |
| `docs/` | 手順書 |
