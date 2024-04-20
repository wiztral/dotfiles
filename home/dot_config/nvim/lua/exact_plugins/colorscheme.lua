return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      integrations = {
        neotree = true,
      },
      color_overrides = {
        mocha = {
          surface2 = '#4F4F5F',
          surface1 = '#282836',
          surface0 = '#15151F',
          base = '#0B0B12',
          mantle = '#06060A',
          crust = '#020203',
        },
      },
    }
  end,
  init = function()
    vim.cmd.colorscheme 'catppuccin'
  end,
}
