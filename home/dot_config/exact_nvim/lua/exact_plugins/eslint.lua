return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      eslint = {
        on_new_config = function(config, new_root_dir)
          -- Help eslint find the correct workspace folder
          config.settings.workspaceFolder = {
            uri = vim.uri_from_fname(new_root_dir),
            name = vim.fn.fnamemodify(new_root_dir, ":t"),
          }
        end,
      },
    },
  },
}
