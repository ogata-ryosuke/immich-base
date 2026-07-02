# 04. GPU で ML / トランスコードを高速化（NVIDIA）

ゲーミングPCの NVIDIA GPU を使うと、顔認識・CLIP検索インデックス生成・動画トランスコードが
CPU比で桁違いに速くなる。1TB取り込み前に有効化しておくと待ち時間が大幅に減る。

## 前提

1. 最新の NVIDIA ドライバ
2. Docker Desktop (WSL2) の GPU サポート
   （WSL2 は近年の NVIDIA ドライバで CUDA パススルー対応。追加の Toolkit 導入は基本不要）
3. 動作確認:
   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
   ```
   GPU が一覧表示されれば OK。

## 公式 hwaccel ファイルを取得

immich は GPU 設定を別ファイルで提供している。ピンした `IMMICH_VERSION` と同じタグから取得:

```powershell
# 例: v1.xxx.x に置換
curl -L -o hwaccel.ml.yml          https://github.com/immich-app/immich/releases/download/<TAG>/hwaccel.ml.yml
curl -L -o hwaccel.transcoding.yml https://github.com/immich-app/immich/releases/download/<TAG>/hwaccel.transcoding.yml
```

（この2ファイルは `.gitignore` 済み＝各自の環境で管理）

## docker-compose.yml のコメントを外す

- **ML(CUDA)** … `immich-machine-learning` の `extends` を有効化し `service: cuda`
- **トランスコード(NVENC)** … `immich-server` の `extends` を有効化し `service: nvenc`

```yaml
  immich-machine-learning:
    extends:
      file: hwaccel.ml.yml
      service: cuda
```

反映:

```powershell
docker compose up -d
```

## 注意

- **ゲームとGPUを取り合う**。フルスクリーンゲーム中はML処理が詰まる/競合しうる。
  取り込みの初回大量処理は、ゲームをしない時間帯に回すと良い。
- うまく動かない時はまず CPU 構成（`extends` をコメントアウト）に戻して切り分ける。
