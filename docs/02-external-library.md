# 02. 既存写真（約1TB）の取り込み — External Library

既存のフォルダ構成を**壊さず・動かさず**に immich から見せる方式。
ファイルは元の場所（RAID）のまま。immich はメタデータ・サムネイル・ML結果だけを持つ。
最悪 immich をやめても写真はそのまま残る＝後戻り可能。

## 前提

- `.env` の `EXTERNAL_LIBRARY` が既存写真フォルダを指している（例 `E:/Photos`）
- compose で `/mnt/external:ro`（読み取り専用）としてマウント済み

## 登録手順

1. immich Web → 管理者 → **Administration → External Libraries**
2. **Create Library** → オーナーを選択
3. **Import Path** に、コンテナ内パス `/mnt/external` を追加
   （Windows の `E:/Photos` が compose により `/mnt/external` にマウントされている）
4. **Scan** を実行

## 取り込み中の注意

- 初回スキャン＋サムネイル生成＋顔認識＋CLIPインデックスは**重い**。
  1TB規模なら数時間〜数日を見込む（常時稼働の利点を活かす）。GPUがあると桁違いに速い → [04-gpu-accel.md](04-gpu-accel.md)
- スキャン中は **RAID(USB) が熱・切断で外れないか**を監視。外れると External Library は「見えない＝一部消えた」ように表示される（ファイル自体は無事）。
- EXIF の日付欠損があると並びが乱れる。スポットチェックする。

## 運用

- 元フォルダに写真を追加したら、再度 **Scan**（または定期スキャンを設定）
- 読み取り専用なので、immich から編集・削除しても**元ファイルは変更されない**
- 今後スマホから増える写真は External ではなく通常アップロード（`UPLOAD_LOCATION`）に入る。
  「既存＝External、新規＝アップロード」のハイブリッドが基本。
