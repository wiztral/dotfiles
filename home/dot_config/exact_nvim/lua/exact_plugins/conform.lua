return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters = opts.formatters or {}

    local existing = opts.formatters.prettier or {}

    opts.formatters.prettier = vim.tbl_deep_extend("force", existing, {
      command = "prettier",
      args = { "--stdin-filepath", "$FILENAME" },
      stdin = true,
    })
  end,
}
