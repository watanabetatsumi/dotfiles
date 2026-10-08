# dotfiles

Mac で使っている開発環境を、WSL の Ubuntu 24.04 に写すためのリポジトリ。

**公開リポジトリなので、トークン・`.env.local`・メールアドレスは入れない。** 秘密情報は `secrets.sh` で暗号化して、別の経路で運ぶ。

## 新しい WSL を作る

```bash
# 1. Windows の PowerShell で Ubuntu 24.04 を入れる
wsl --install -d Ubuntu-24.04

# 2. Ubuntu の中で
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/watanabetatsumi/dotfiles.git
cd dotfiles && ./install.sh
```

途中で systemd を有効にしたときは、PowerShell で `wsl --shutdown` してから Ubuntu を開き直し、もう一度 `./install.sh` を実行する。
何度実行してもよい。1つだけやり直すときは `./install.sh docker` のように手順を指定する（一覧: `./install.sh --list`）。

### 秘密情報を運ぶ

```bash
# Mac で（パスフレーズを聞かれる）
./secrets.sh export                     # → ~/Desktop/policy-cloud-secrets.enc

# WSL で（Windows 側に置いたファイルは /mnt/c/Users/<名前>/... で見える）
./secrets.sh import /mnt/c/Users/<名前>/Downloads/policy-cloud-secrets.enc
```

展開したら `.enc` ファイルは消す。パスフレーズはファイルと別の経路で伝える。

## Mac の設定を変えたら

```bash
./capture.sh && git diff    # 今の Mac の設定を取り込む。差分を見てからコミット
```

## install.sh がすること

| 手順 | 内容 |
|---|---|
| `preflight` | Ubuntu 24.04・WSL の確認。WSL で systemd が無効なら有効にする |
| `apt` | `packages/apt.txt`（Mac の Homebrew で入れていたものの Ubuntu 版）。`batcat`・`fdfind` を `bat`・`fd` でも呼べるようにする |
| `gh` / `docker` | GitHub CLI と Docker Engine（公式の apt リポジトリ）。Docker Desktop は使わない |
| `asdf` | asdf 0.18.1 と、`tool-versions` の Node.js・Python・Terraform |
| `uv` / `wtp` / `tflint` / `gcloud` | それぞれ公式の配布物から |
| `zsh` / `dotfiles` | oh-my-zsh、`~/.zshrc`・`~/.gitconfig` のリンク、git のメールアドレス（`~/.gitconfig.local`） |
| `github` | `gh auth login`（ブラウザでログイン） |
| `claude` / `codex` | Claude Code と Codex CLI、設定と skill、各エージェントの `AGENTS.md` |
| `projects` | `~/projects/my-product-harness`（skill をリンク）、`~/projects/policy-cloud/{main,worktree,devtools}` |
| `vscode` | `vscode/extensions.txt` の拡張機能（Windows 側の VS Code に WSL 拡張を入れてから） |
| `schedule` | 毎週月曜 9:00 の worktree 整理（systemd のユーザータイマー） |
| `doctor` | 入ったかの確認と、残りの手作業 |

## 中身

| 場所 | 置き先 | 備考 |
|---|---|---|
| `zsh/zshrc` | `~/.zshrc` | Mac / Linux 共通。マシン固有の設定は `~/.zshrc.local` |
| `git/gitconfig` | `~/.gitconfig` | メールアドレスは `~/.gitconfig.local` |
| `tool-versions` | `~/.tool-versions` | asdf のグローバルなバージョン |
| `claude/settings.json` | `~/.claude/settings.json` | 無いときだけコピー。Orca などが書き込む hooks・statusLine は含めない |
| `claude/skills/` | `~/.claude/skills/` | my-product-harness 以外の skill。`react-best-practice` は Vercel の MIT ライセンス |
| `agents/` | `~/.codex/AGENTS.md`・`~/.dsh/AGENTS.md` | policy-cloud の devtools への導線 |
| `policy-cloud/` | `~/projects/policy-cloud/` | 親フォルダの `CLAUDE.md`・`AGENTS.md`、`main/.wtp.yml` |
| `vscode/extensions.txt` | | `code --list-extensions` |

## Mac から写さないもの

Raycast、Docker Desktop、Claude デスクトップアプリ（Linux 版なし）、launchd の設定、フォント（Windows Terminal 側で入れる）。
