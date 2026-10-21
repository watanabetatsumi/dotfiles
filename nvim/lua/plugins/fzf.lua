return {
  {
    "ibhagwan/fzf-lua",
    enabled = false,
  },

  {
    "folke/snacks.nvim",
    keys = {
      { "<D-p>", function() Snacks.picker.files() end, desc = "Find files" },
      { "<D-S-f>", function() Snacks.picker.grep() end, desc = "Search in files" },
      { "<D-S-p>", function() Snacks.picker.commands() end, desc = "Command palette" },
      { "<D-S-o>", function() Snacks.picker.symbols() end, desc = "Go to symbol" },
      { "<D-t>", function() Snacks.picker.workspace_symbols() end, desc = "Workspace symbols" },
      { "<D-S-m>", function() Snacks.picker.diagnostics() end, desc = "Problems" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find files" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "Live grep" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fr", function() Snacks.picker.oldfiles() end, desc = "Recent files" },
      { "<leader>fd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>fs", function() Snacks.picker.symbols() end, desc = "Document symbols" },
      { "<leader>fw", function() Snacks.picker.workspace_symbols() end, desc = "Workspace symbols" },
    },
  },
}
