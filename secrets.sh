#!/usr/bin/env bash
# secrets.sh — .env.local を暗号化して別のマシンに運ぶ（このリポジトリには入れない）
#
#   ./secrets.sh export            Mac で実行。~/Desktop/policy-cloud-secrets.enc を作る（パスフレーズを聞く）
#   ./secrets.sh import <ファイル>  WSL で実行。~/projects/policy-cloud/main に展開する
#
# 運び方の例: Windows 側のフォルダにコピー → WSL から /mnt/c/Users/<名前>/Downloads/... を指定。
# 展開したら、運んだ .enc ファイルは消す。
set -euo pipefail

# パスフレーズは対話で聞く。SECRETS_PASSPHRASE があればそれを使う（自動化・テスト用）
pass_opt=(); [[ -n "${SECRETS_PASSPHRASE:-}" ]] && pass_opt=(-pass env:SECRETS_PASSPHRASE)

MAIN="${PC_MAIN:-$HOME/projects/policy-cloud/main}"
FILES=(
  policy-cloud-front/.env.local
  policy-cloud-server/.env.local
  policy-cloud-server/frontend/.env.local
)

case "${1:-}" in
  export)
    out="${2:-$HOME/Desktop/policy-cloud-secrets.enc}"
    (cd "$MAIN" && for f in "${FILES[@]}"; do [[ -f "$f" ]] || { echo "ありません: $MAIN/$f" >&2; exit 1; }; done)
    # main の .env.local は main の DB を指す（worktree 用に書き換えられた POSTGRES_DB は運ばない）
    tar -C "$MAIN" -czf - "${FILES[@]}" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt ${pass_opt[@]+"${pass_opt[@]}"} -out "$out"
    chmod 600 "$out"
    echo "✅ $out を作りました（${#FILES[@]} ファイル）。パスフレーズは別の経路で伝えてください" ;;
  import)
    in="${2:?使い方: ./secrets.sh import <ファイル>}"
    [[ -d "$MAIN" ]] || { echo "$MAIN がありません。先に ./install.sh projects を実行してください" >&2; exit 1; }
    for f in "${FILES[@]}"; do [[ -f "$MAIN/$f" ]] && cp "$MAIN/$f" "$MAIN/$f.bak.$(date +%Y%m%d%H%M%S)"; done
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 ${pass_opt[@]+"${pass_opt[@]}"} -in "$in" | tar -C "$MAIN" -xzf -
    for f in "${FILES[@]}"; do chmod 600 "$MAIN/$f"; done
    echo "✅ ${#FILES[@]} ファイルを $MAIN に展開しました。運んだ $in は消してください" ;;
  *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
