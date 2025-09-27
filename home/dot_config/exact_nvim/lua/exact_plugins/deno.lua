return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      denols = {
        enabled = true,
        root_dir = require("lspconfig").util.root_pattern({ "deno.json", "deno.jsonc" }),
      },
    },
  },
}
