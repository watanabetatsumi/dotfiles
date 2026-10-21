-- ペインの移動（Ctrl+h/j/k/l）
--   Neovim の分割の中を移動し、端まで来たら外側のペインに移る。
--   herdr の中なら herdr のペインへ（herdr-nvim-nav）、tmux の中なら tmux のペインへ（vim-tmux-navigator）。
--   キーの割り当ては herdr-nvim-nav が受け持つ。vim-tmux-navigator は tmux のときの移動先としてだけ使う。
--   herdr 側にも同じキーの設定が要る（~/.config/herdr/config.toml の herdr-nvim-nav.*）。
return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
    init = function()
      vim.g.tmux_navigator_no_mappings = 1 -- キーは herdr-nvim-nav が割り当てる
    end,
  },
  {
    "aimdevlee/herdr-nvim-nav",
    commit = "ec047fd6d8d0269d54a34e9405af28d8aad4c8f0", -- 中身を確認した版に固定（2026-10-21）
    event = "VeryLazy",
    dependencies = { "christoomey/vim-tmux-navigator" },
    config = function()
      require("herdr-nvim-nav").setup()
    end,
  },
}
