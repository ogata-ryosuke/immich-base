# 01. 外部アクセス（Tailscale）

無料・ポート開放なし・HTTPS付きで、スマホアプリから自宅 immich に繋ぐ。
Tailscale の通信は WireGuard で常に暗号化される。

## 手順

1. **PCに Tailscale** … https://tailscale.com/download/windows を入れてサインイン
   （Windowsサービスとして常駐＝起動時に自動接続。24時間運用向き）
2. **スマホに Tailscale** … 同じアカウントでログイン
3. **疎通確認（最小構成）** … アプリのサーバURLに `http://<PCのTailscale IP>:2283`
   ```powershell
   tailscale ip -4      # PC の 100.x.y.z を確認
   tailscale status
   ```

## HTTPS 化（仕上げ）

1. 管理コンソール https://login.tailscale.com/admin/dns で
   **MagicDNS** と **HTTPS Certificates** を有効化
2. PCの管理者 PowerShell で:
   ```powershell
   tailscale serve --bg 2283      # https://<host>.<tailnet>.ts.net → localhost:2283
   tailscale serve status
   ```
3. アプリのサーバURLを `https://immich-pc.taro.ts.net`（自分のマシン名/tailnet名）に変更
4. immich 管理画面 → 設定の External Domain に同URLを入れておくと共有リンクが安定
   （`.env` の `IMMICH_SERVER_URL` にも控えておく）

## よくある詰まり

- 繋がらない → PCがスリープしていないか / Docker が起動しているか（`docker compose ps`）
- 家族に使わせる → 家族の端末にも Tailscale を入れて tailnet に招待
- serve を止める → `tailscale serve --https=443 off`
