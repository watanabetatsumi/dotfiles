#!/usr/bin/env bash
# capture.sh — いま使っている Mac の設定を、このリポジトリに取り込む
#
# Mac で設定を変えたら実行して、差分を確認してからコミットする。
#   ./capture.sh && git diff
#
# 取り込まないもの（このリポジトリは公開なので）:
#   - .env.local・トークン・認証情報（→ ./secrets.sh で暗号化して別途運ぶ）
#   - git のメールアドレス（→ ~/.gitconfig.local。install.sh が聞く）
#   - ツールが自動で書き込む設定（Orca の hooks / statusLine、claude.ai から同期される skill）
set -euo pipefail

DOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PC="$HOME/projects/policy-cloud"
HARNESS_SKILLS="$HOME/projects/my-product-harness/skills"

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
copy() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "  $2"; }

step "Claude Code の設定（hooks・statusLine は除く）"
mkdir -p "$DOT/claude" "$DOT/vscode"
python3 -I - "$HOME/.claude/settings.json" "$DOT/claude/settings.json" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
for k in ("hooks", "statusLine"):   # Orca などのツールが書き込むもの。各マシンでツールが入れ直す
    d.pop(k, None)
json.dump(d, open(dst, "w"), ensure_ascii=False, indent=2)
open(dst, "a").write("\n")
print("  " + dst)
PY

step "Claude Code の skill（my-product-harness へのリンク以外）"
rm -rf "$DOT/claude/skills"; mkdir -p "$DOT/claude/skills"
for s in "$HOME/.claude/skills"/*; do
  name=$(basename "$s")
  [[ "$name" == synced ]] && continue                      # claude.ai から同期されるもの
  if [[ -L "$s" ]]; then
    [[ "$(readlink "$s")" == "$HARNESS_SKILLS/"* ]] && continue   # install.sh が my-product-harness から張り直す
  fi
  cp -R "$s" "$DOT/claude/skills/$name"; echo "  claude/skills/$name"
done

step "Codex・dsh の AGENTS.md"
[[ -f "$HOME/.codex/AGENTS.md" ]] && copy "$HOME/.codex/AGENTS.md" "$DOT/agents/codex/AGENTS.md"
[[ -f "$HOME/.dsh/AGENTS.md" ]] && copy "$HOME/.dsh/AGENTS.md" "$DOT/agents/dsh/AGENTS.md"

step "policy-cloud の作業フォルダの設定"
copy "$PC/CLAUDE.md" "$DOT/policy-cloud/CLAUDE.md"
copy "$PC/AGENTS.md" "$DOT/policy-cloud/AGENTS.md"
copy "$PC/main/.wtp.yml" "$DOT/policy-cloud/wtp.yml"

step "asdf のグローバルなバージョン"
copy "$HOME/.tool-versions" "$DOT/tool-versions"

step "VS Code の拡張機能"
if command -v code >/dev/null 2>&1; then
  code --list-extensions | sort >"$DOT/vscode/extensions.txt"; echo "  vscode/extensions.txt"
fi

step "完了。差分を確認してからコミットしてください"
git -C "$DOT" status --short
