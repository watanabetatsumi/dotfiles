return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      terminal = {},
      picker = {},
      dashboard = {
        enabled = not vim.g.is_ide,
        preset = {
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.oldfiles()" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
    },
    keys = {
      {
        "<D-`>",
        function()
          Snacks.terminal.toggle(nil, {
            env = { SNACKS_TERM = "bottom" },
            win = { position = "bottom", height = 0.3 },
          })
        end,
        mode = { "n", "t" },
        desc = "Bottom terminal",
      },
      {
        "<D-j>",
        function()
          Snacks.terminal.toggle(nil, {
            env = { SNACKS_TERM = "right" },
            win = { position = "right", width = 0.3 },
          })
        end,
        mode = { "n", "t" },
        desc = "Right terminal",
      },
      {
        "<D-S-j>",
        function()
          Snacks.terminal.toggle(nil, {
            env = { SNACKS_TERM = "float" },
            win = {
              position = "float",
              border = "rounded",
              width = 0.85,
              height = 0.8,
            },
          })
        end,
        mode = { "n", "t" },
        desc = "Floating terminal",
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

      local function ide_close_buf(bang)
        local bufnr = vim.api.nvim_get_current_buf()
        local bufs = vim.tbl_filter(function(b)
          return b ~= bufnr
            and vim.api.nvim_buf_is_valid(b)
            and vim.bo[b].buflisted
            and vim.bo[b].buftype == ""
        end, vim.api.nvim_list_bufs())

        if #bufs > 0 then
          vim.cmd("buffer " .. bufs[#bufs])
        else
          vim.cmd("enew")
        end

        vim.cmd("bdelete" .. (bang and "!" or "") .. " " .. bufnr)

        if #bufs == 0 then
          Snacks.dashboard.open()
        end
      end

      vim.api.nvim_create_user_command("SmartQ", function(o)
        if not vim.g.is_ide then
          vim.cmd("quit" .. (o.bang and "!" or ""))
        else
          ide_close_buf(o.bang)
        end
      end, { bang = true })

      vim.api.nvim_create_user_command("SmartWQ", function(o)
        vim.cmd("write")
        if not vim.g.is_ide then
          vim.cmd("quit" .. (o.bang and "!" or ""))
        else
          ide_close_buf(o.bang)
        end
      end, { bang = true })

      vim.cmd([[cnoreabbrev <expr> q getcmdtype() == ':' && getcmdline() ==# 'q' ? 'SmartQ' : 'q']])
      vim.cmd([[cnoreabbrev <expr> wq getcmdtype() == ':' && getcmdline() ==# 'wq' ? 'SmartWQ' : 'wq']])
    end,
  },
}
