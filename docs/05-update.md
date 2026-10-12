# 05. アップデート

immich は活発なβ。**破壊的変更が入ることがある**ので、更新は「release notes を読む → ダンプ → 上げる」を必ずこの順で行う。
自動更新（`release` タグで毎回最新）に頼らず、**動作確認済みのタグに固定**して運用する。

## 更新前チェック（必須）

1. **[Release Notes](https://github.com/immich-app/immich/releases) を読む。**
   特に **Breaking Changes** と、DB/Redis のイメージタグ変更の有無を確認する。
2. 公式 [`example.env`](https://github.com/immich-app/immich/releases/latest) と自分の `.env` を突き合わせ、
   **`DB_IMAGE` / `REDIS_IMAGE` が変わっていないか**を確認する。
   変わっていれば先に `.env` を手で更新しておく（勝手に上がらないよう固定しているため）。
3. 大型アップデート前は写真実体（`UPLOAD_LOCATION` / `EXTERNAL_LIBRARY`）のコピーも最新化しておくと安心。

## 通常の更新

```powershell
cd <repoのパス>\immich-base

# タグを上げて更新（.env の IMMICH_VERSION を書き換えてから pull→再作成）
.\scripts\update-immich.ps1 -Version v1.120.0

# タグ据え置きで再pullだけしたいとき（release 運用など）
.\scripts\update-immich.ps1
```

`update-immich.ps1` がやること:

| 手順 | 内容 |
|---|---|
| ① タグ書換 | `-Version` 指定時のみ `.env` の `IMMICH_VERSION` を置換（確認プロンプトあり） |
| ② DBダンプ | 更新前に `backup-db.ps1` を自動実行（`-SkipBackup` で省略可・非推奨） |
| ③ pull | `docker compose pull` で新イメージ取得 |
| ④ 再作成 | `docker compose up -d` でコンテナを作り直す |
| ⑤ ヘルス確認 | `http://localhost:2283/api/server/ping` が返るまで最大120秒待つ |
| ⑥ 後片付け | 稼働バージョン表示。`-Prune` 指定時は未使用イメージを削除 |

### よく使うオプション

```powershell
.\scripts\update-immich.ps1 -Version v1.120.0 -Prune   # 更新後に古いイメージも掃除
.\scripts\update-immich.ps1 -SkipBackup                # 緊急時のみ。ダンプを飛ばす
```

## 更新後の確認

```powershell
docker compose ps                       # 全サービスが healthy / running か
docker compose logs -f immich-server    # エラーが出ていないか（Ctrl+C で抜ける）
```

- Web（`http://localhost:2283`）にログインできるか
- 写真・アルバム・顔が表示されるか
- スマホアプリから接続できるか（Tailscale 経由含む）

## ロールバック（更新がうまくいかないとき）

immich は「DBスキーマが新バージョンで更新される」ため、**イメージを戻すだけでは不整合になることがある。**
確実なのは「旧タグのイメージ ＋ 更新前のDBダンプ」をセットで戻すこと。

```powershell
# 1. .env の IMMICH_VERSION を更新前のタグに戻す
notepad .env

# 2. 更新直前に取ったダンプでDBを復元（破壊的操作・確認あり）
.\scripts\restore-db.ps1 -DumpPath C:\immich\backups\immich-db-YYYYMMDD-HHmmss.sql.gz
```

> `update-immich.ps1` は手順②で必ずダンプを取るので、直近のダンプが `BACKUP_DIR` にある。
> どのダンプが更新直前かは `BACKUP_DIR` のタイムスタンプで判断する。

詳しい復元手順は [docs/03-backup-restore.md](03-backup-restore.md) を参照。

## トラブル時の調べ方

```powershell
docker compose logs immich-server       # サーバのログ
docker compose logs database            # DBのログ（マイグレーション失敗など）
docker compose ps                       # コンテナ状態
```

- DB のマイグレーション失敗 → ログに出たエラーを release notes / GitHub issues で確認
- それでも直らない → ロールバック（上記）して、原因が分かるまで旧版で運用する

### 再起動直後に immich_server が再起動を繰り返す

`docker compose restart` や PC 再起動の直後、サーバログに
`PostgresError: the database system is starting up`（コード 57P03）が出て
`immich_server` が crash ループすることがある。

- 原因: Postgres が**クラッシュリカバリ中**（`automatic recovery in progress` → `redo`）で、
  まだ接続を受け付けられないのにサーバが先に繋ぎにいくため。データ破損ではない。
- 対処: Postgres が `database system is ready to accept connections` を出すまで**待つ**
  （数十秒〜数分。`restart: always` なので基本は自動復旧する）。
  待っても戻らなければ DB が healthy になってからサーバだけ入れ直す。

```powershell
docker compose logs database --tail 20     # "ready to accept connections" を確認
docker compose restart immich-server       # DB が ready になってから
```

> 非グレースフルな停止（`restart`・電源断）はこのリカバリを招きやすい。
> 通常停止は `docker compose stop` / `down`（グレースフル）を使うと起きにくい。
