return {
  "neovim/nvim-lspconfig",
  opts = {
    setup = {
      tailwindcss = function(_, opts)
        opts.settings = {
          tailwindCSS = {
            classFunctions = { "tw", "clsx", "tw\\.[a-z-]+", "cva", "cn" },
          },
        }
      end,
    },
  },
}
