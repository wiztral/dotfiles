return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      eslint = {
        settings = {
          -- helps eslint find the eslintrc when it's placed in a subfolder instead of the cwd root
          workingDirectories = { mode = "location" },
        },
        -- on_new_config = function(config, new_root_dir)
        --   -- Help eslint find the correct workspace folder
        --   config.settings.workspaceFolder = {
        --     uri = vim.uri_from_fname(new_root_dir),
        --     name = vim.fn.fnamemodify(new_root_dir, ":t"),
        --   }
        -- end,
      },
    },
  },
}
