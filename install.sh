#!/usr/bin/env bash
# install.sh — WSL の Ubuntu 24.04 に、Mac と同じ開発環境を作る
#
#   ./install.sh              すべての手順を順に実行する（何度実行してもよい）
#   ./install.sh <手順>...    指定した手順だけ実行する（例: ./install.sh docker asdf）
#   ./install.sh --list       手順の一覧
#
# 秘密情報（.env.local）はこのリポジトリに入れない。Mac で ./secrets.sh export、WSL で ./secrets.sh import。
set -euo pipefail

DOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECTS="$HOME/projects"
PC="$PROJECTS/policy-cloud"

POLICY_CLOUD_REPO="${POLICY_CLOUD_REPO:-PoliPoliTeam/policy-cloud}"
DEVTOOLS_REPO="${DEVTOOLS_REPO:-watanabetatsumi/policy-cloud-devtools}"
HARNESS_REPO="${HARNESS_REPO:-watanabetatsumi/my-product-harness}"

ASDF_VERSION="0.18.1"   # Mac と同じ
WTP_VERSION="2.10.3"    # Mac と同じ
TFLINT_VERSION="0.61.0" # Mac と同じ

STEPS=(preflight apt gh docker asdf uv wtp tflint gcloud zsh dotfiles github claude codex projects vscode schedule doctor)

step() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  \033[33m⚠ %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
arch() { case "$(uname -m)" in x86_64) echo amd64 ;; aarch64|arm64) echo arm64 ;; *) uname -m ;; esac; }
link() {   # link <リポジトリ内のパス> <置き場所>。既存のファイルは .bak に退避する
  local src="$DOT/$1" dst=$2
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"; info "既存の $dst を退避しました"; fi
  ln -sfn "$src" "$dst"; info "$dst → $1"
}
asdf_env() { export PATH="$HOME/.local/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"; }

# ---------------------------------------------------------------- 手順

do_preflight() {
  step "前提の確認"
  [[ "$(uname -s)" == Linux ]] || { echo "このスクリプトは Ubuntu（WSL）用です。Mac では ./capture.sh を使ってください" >&2; exit 1; }
  . /etc/os-release
  [[ "$ID" == ubuntu ]] || warn "Ubuntu 以外（$PRETTY_NAME）では未確認です"
  [[ "$VERSION_ID" == 24.04 ]] || warn "Ubuntu 24.04 以外（$VERSION_ID）では未確認です"
  if is_wsl; then
    info "WSL を検出しました"
    [[ "$PWD" == /mnt/* ]] && warn "Windows 側のフォルダ（/mnt/c など）は遅いので、~/projects などで作業してください"
    if ! grep -qE '^\s*systemd\s*=\s*true' /etc/wsl.conf 2>/dev/null; then
      warn "WSL で systemd が有効になっていません（Docker と毎週の自動整理に必要）。有効にします"
      printf '[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
      warn "Windows の PowerShell で 'wsl --shutdown' を実行し、Ubuntu を開き直してから、もう一度 ./install.sh を実行してください"
      exit 0
    fi
  fi
  sudo -v
}

do_apt() {
  step "apt のパッケージ（packages/apt.txt）"
  sudo apt-get update -qq
  sed -e 's/#.*//' -e '/^\s*$/d' "$DOT/packages/apt.txt" | xargs sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq
  # Ubuntu ではコマンド名が違うものを、Mac と同じ名前でも呼べるようにする
  mkdir -p "$HOME/.local/bin"
  have batcat && ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  have fdfind && ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  info "完了"
}

do_gh() {
  step "GitHub CLI（gh）"
  if have gh; then info "インストール済み: $(gh --version | head -n1)"; return; fi
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq gh
}

do_docker() {
  step "Docker Engine（WSL の中で動かす。Docker Desktop は不要）"
  if ! have docker; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    info "インストール済み: $(docker --version)"
  fi
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "docker グループに追加しました。sudo なしで使うには、ターミナルを開き直してください"
  fi
  have systemctl && sudo systemctl enable --now docker >/dev/null 2>&1 || true
}

do_asdf() {
  step "asdf $ASDF_VERSION と、Node.js・Python・Terraform（tool-versions）"
  asdf_env
  if ! have asdf || [[ "$(asdf --version 2>/dev/null)" != *"$ASDF_VERSION"* ]]; then
    curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v$ASDF_VERSION/asdf-v$ASDF_VERSION-linux-$(arch).tar.gz" |
      tar -xz -C "$HOME/.local/bin" asdf
  fi
  link tool-versions "$HOME/.tool-versions"
  local plugin
  for plugin in $(awk '{print $1}' "$DOT/tool-versions"); do
    asdf plugin list 2>/dev/null | grep -qx "$plugin" || asdf plugin add "$plugin"
  done
  (cd "$HOME" && asdf install)
  asdf current 2>/dev/null | sed 's/^/  /' || true
}

do_uv() {
  step "uv（バックエンドの Python）"
  if have uv || [[ -x "$HOME/.local/bin/uv" ]]; then info "インストール済み"; return; fi
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

do_wtp() {
  step "wtp $WTP_VERSION"
  if have wtp && [[ "$(wtp --version)" == *"$WTP_VERSION"* ]]; then info "インストール済み"; return; fi
  local a; a=$(arch); [[ "$a" == amd64 ]] && a=x86_64
  local deb; deb=$(mktemp --suffix=.deb)
  curl -fsSL -o "$deb" "https://github.com/satococoa/wtp/releases/download/v$WTP_VERSION/wtp_${WTP_VERSION}_linux_${a}.deb"
  sudo apt-get install -y -qq "$deb"; rm -f "$deb"
}

do_tflint() {
  step "tflint"
  if have tflint && [[ "$(tflint --version | head -n1)" == *"$TFLINT_VERSION"* ]]; then info "インストール済み"; return; fi
  local zip; zip=$(mktemp --suffix=.zip)
  curl -fsSL -o "$zip" "https://github.com/terraform-linters/tflint/releases/download/v$TFLINT_VERSION/tflint_linux_$(arch).zip"
  mkdir -p "$HOME/.local/bin" && unzip -o -q "$zip" tflint -d "$HOME/.local/bin" && rm -f "$zip"
}

do_gcloud() {
  step "Google Cloud CLI"
  if have gcloud; then info "インストール済み"; return; fi
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" |
    sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq google-cloud-cli
  info "ログインは後で: gcloud auth login && gcloud auth application-default login"
}

do_zsh() {
  step "zsh と oh-my-zsh"
  [[ -d "$HOME/.oh-my-zsh" ]] || RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
    sudo chsh -s "$(command -v zsh)" "$USER" && info "ログインシェルを zsh にしました（次に開いたターミナルから）"
  fi
}

do_dotfiles() {
  step "設定ファイルのリンク"
  link zsh/zshrc "$HOME/.zshrc"
  link git/gitconfig "$HOME/.gitconfig"
  if ! git config -f "$HOME/.gitconfig.local" user.email >/dev/null 2>&1; then
    local email="${GIT_EMAIL:-}"
    [[ -z "$email" ]] && { read -r -p "  git のメールアドレス: " email </dev/tty 2>/dev/null || true; }
    if [[ -n "$email" ]]; then git config -f "$HOME/.gitconfig.local" user.email "$email"
    else warn "メールアドレスが未設定です: git config -f ~/.gitconfig.local user.email <アドレス>"; fi
  fi
  info "git: $(git config user.name) <$(git config user.email 2>/dev/null || echo 未設定)>"
}

do_github() {
  step "GitHub へのログイン"
  if gh auth status >/dev/null 2>&1; then info "ログイン済み"; else gh auth login --git-protocol https --web; fi
  gh auth setup-git
}

do_claude() {
  step "Claude Code"
  asdf_env
  have claude || curl -fsSL https://claude.ai/install.sh | bash
  mkdir -p "$HOME/.claude/skills"
  # settings.json はツール（Orca など）が書き足すのでリンクにせず、無いときだけコピーする
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    info "~/.claude/settings.json は既にあるので上書きしません（差分: diff ~/.claude/settings.json $DOT/claude/settings.json）"
  else
    cp "$DOT/claude/settings.json" "$HOME/.claude/settings.json"; info "~/.claude/settings.json をコピーしました"
  fi
  local s
  for s in "$DOT/claude/skills"/*/; do link "claude/skills/$(basename "$s")" "$HOME/.claude/skills/$(basename "$s")"; done
  info "my-product-harness の skill は projects の手順でリンクします"
}

do_codex() {
  step "Codex CLI と、各エージェントの AGENTS.md"
  asdf_env
  have codex || npm install -g @openai/codex
  link agents/codex/AGENTS.md "$HOME/.codex/AGENTS.md"
  link agents/dsh/AGENTS.md "$HOME/.dsh/AGENTS.md"
}

clone() {   # clone <owner/name> <置き場所>
  if [[ -d "$2/.git" || -f "$2/.git" ]]; then info "clone 済み: $2"; return; fi
  mkdir -p "$(dirname "$2")"; gh repo clone "$1" "$2"
}

do_projects() {
  step "リポジトリ（~/projects）"
  asdf_env
  # 本・記事のメモと skill
  clone "$HARNESS_REPO" "$PROJECTS/my-product-harness"
  local s
  for s in "$PROJECTS/my-product-harness/skills"/*/; do
    ln -sfn "${s%/}" "$HOME/.claude/skills/$(basename "$s")"
  done
  info "my-product-harness の skill をリンクしました"

  # policy-cloud: main / worktree / devtools の3つを並べる
  clone "$POLICY_CLOUD_REPO" "$PC/main"
  mkdir -p "$PC/worktree"
  if gh repo view "$DEVTOOLS_REPO" >/dev/null 2>&1; then clone "$DEVTOOLS_REPO" "$PC/devtools"
  else warn "$DEVTOOLS_REPO が見つかりません。Mac の ~/projects/policy-cloud/devtools を push してから、もう一度実行してください"
  fi
  cp "$DOT/policy-cloud/wtp.yml" "$PC/main/.wtp.yml"          # 個人の設定（main では git 管理外）
  link policy-cloud/CLAUDE.md "$PC/CLAUDE.md"
  link policy-cloud/AGENTS.md "$PC/AGENTS.md"
  (cd "$PC/main" && asdf install nodejs && asdf install terraform) || warn "main の .tool-versions のインストールに失敗しました"
}

do_vscode() {
  step "VS Code の拡張機能"
  if ! have code; then
    warn "code コマンドがありません。Windows 側に VS Code を入れ、拡張機能『WSL』を入れてから、WSL で 'code .' を一度実行してください"
    return
  fi
  local ext installed; installed=$(code --list-extensions 2>/dev/null)
  while read -r ext; do
    [[ -z "$ext" ]] && continue
    grep -qix "$ext" <<<"$installed" || code --install-extension "$ext" >/dev/null 2>&1 || warn "入れられませんでした: $ext"
  done <"$DOT/vscode/extensions.txt"
  info "完了（WSL 側に入る拡張機能です）"
}

do_schedule() {
  step "毎週の worktree 整理（systemd のユーザータイマー）"
  if [[ -x "$PC/devtools/bin/wta" ]]; then (cd "$PC/main" && "$PC/devtools/bin/wta" schedule install)
  else warn "devtools が無いので飛ばしました"
  fi
}

do_doctor() {
  step "確認"
  asdf_env
  local c
  for c in git gh docker asdf node python uv wtp fzf rg fd bat tmux psql claude codex code; do
    local flag=--version; [[ "$c" == tmux ]] && flag=-V
    if have "$c"; then printf '  ✅ %-7s %s\n' "$c" "$("$c" $flag 2>/dev/null | head -n1)"; else printf '  ❌ %s\n' "$c"; fi
  done
  docker info >/dev/null 2>&1 && info "✅ docker デーモン" || warn "docker デーモンに接続できません（ターミナルを開き直すか、sudo systemctl start docker）"
  cat <<EOF

  残りの手作業:
    1. Mac で ./secrets.sh export → できたファイルを WSL に運び、./secrets.sh import <ファイル>
    2. cd $PC/main && make deps-install && make docker-up && ~/projects/policy-cloud/devtools/bin/mk db-init
    3. gcloud auth login / gcloud auth application-default login（必要なら）
    4. Windows Terminal のフォントに JetBrainsMono Nerd Font を設定（Windows 側で入れる）
EOF
}

# ---------------------------------------------------------------- 実行

if [[ "${1:-}" == --list ]]; then printf '%s\n' "${STEPS[@]}"; exit 0; fi
selected=("$@"); [[ ${#selected[@]} -eq 0 ]] && selected=("${STEPS[@]}")
[[ " ${selected[*]} " == *" preflight "* ]] || do_preflight
for s in "${selected[@]}"; do
  declare -F "do_$s" >/dev/null || { echo "不明な手順: $s（./install.sh --list）" >&2; exit 1; }
  "do_$s"
done
