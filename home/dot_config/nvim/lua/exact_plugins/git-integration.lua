return {
  {
    'tpope/vim-fugitive',
  },
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup {
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        },
        on_attach = function(bufnr)
          local gitsigns = require 'gitsigns'

          local function map(mode, keys, func, desc, opts)
            opts = opts or {}
            opts.buffer = bufnr
            opts.desc = desc
            vim.keymap.set(mode, keys, func, opts)
          end

          -- Navigation
          map('n', ']c', function()
            if vim.wo.diff then
              vim.cmd.normal { ']c', bang = true }
            else
              gitsigns.nav_hunk 'next'
            end
          end, 'Go to next [C]hange')

          map('n', '[c', function()
            if vim.wo.diff then
              vim.cmd.normal { '[c', bang = true }
            else
              gitsigns.nav_hunk 'prev'
            end
          end, 'Go to previous [C]hange')

          -- Actions
          map('n', '<leader>hp', gitsigns.preview_hunk, 'Show [H]unk [P]review')
          map('n', '<leader>hf', function()
            gitsigns.preview_hunk()
            gitsigns.preview_hunk()
          end, '[H]unk preview [F]ocus')
        end,
      }
    end,
  },
}
